///|
fn BuslaneLowerer::lower_pattern_decision(
  self : BuslaneLowerer,
  scrutinees : Array[@buslane.Expr],
  binders : Array[@buslane.ValueId],
  rows : Array[LowerPatternRow],
  types : Array[@types.Type],
  result_type : @buslane.Type,
) -> @buslane.Expr {
  if types.is_empty() {
    guard rows.get(0) is Some(row) else { abort("empty pattern decision") }
    return row.body
  }
  guard scrutinees.get(0) is Some(scrutinee) else {
    abort("missing pattern scrutinee")
  }
  guard binders.get(0) is Some(binder) else { abort("missing pattern binder") }
  guard types.get(0) is Some(type_) else { abort("missing pattern type") }
  let constructors = self.lower_first_column_signatures(rows)
  if constructors.is_empty() {
    return self.lower_pattern_decision(
      buslane_expr_tail(scrutinees),
      buslane_value_tail(binders),
      self.lower_default_rows(rows, binder),
      lower_type_tail(types),
      result_type,
    )
  }
  let alternatives = constructors.map(fn(signature) {
    self.lower_constructor_decision_alternative(
      signature, scrutinees, binders, rows, types, result_type,
    )
  })
  if !self.lower_constructor_set_complete(type_, constructors) {
    let default_rows = self.lower_default_rows(rows, binder)
    if !default_rows.is_empty() {
      alternatives.push({
        alt_constructor: Default,
        type_binders: [],
        value_binders: [],
        body: self.lower_pattern_decision(
          buslane_expr_tail(scrutinees),
          buslane_value_tail(binders),
          default_rows,
          lower_type_tail(types),
          result_type,
        ),
      })
    }
  }
  Match({ scrutinee, binder, result_type, alternatives })
}

///|
fn BuslaneLowerer::lower_constructor_decision_alternative(
  self : BuslaneLowerer,
  signature : LowerConstructorSignature,
  scrutinees : Array[@buslane.Expr],
  binders : Array[@buslane.ValueId],
  rows : Array[LowerPatternRow],
  types : Array[@types.Type],
  result_type : @buslane.Type,
) -> @buslane.Alternative {
  guard binders.get(0) is Some(binder) else {
    abort("missing constructor binder")
  }
  let value_binders = signature.argument_types.map(fn(type_) {
    self.define_fresh_value("payload", MatchBinder, self.lower_type(type_))
  })
  let payload_refs = value_binders.map(fn(value) { @buslane.Expr::Ref(value) })
  {
    alt_constructor: signature.alt_constructor,
    type_binders: signature.type_binders,
    value_binders,
    body: self.lower_pattern_decision(
      buslane_expr_concat(payload_refs, buslane_expr_tail(scrutinees)),
      buslane_value_concat(value_binders, buslane_value_tail(binders)),
      self.lower_specialized_rows(rows, binder, signature),
      lower_type_concat(signature.argument_types, lower_type_tail(types)),
      result_type,
    ),
  }
}

///|
fn BuslaneLowerer::lower_first_column_signatures(
  self : BuslaneLowerer,
  rows : Array[LowerPatternRow],
) -> Array[LowerConstructorSignature] {
  let signatures = []
  for row in rows {
    guard row.patterns.get(0) is Some(pattern) else { continue }
    guard self.lower_signature_for_pattern(pattern) is Some(signature) else {
      continue
    }
    if !lower_signature_contains(signatures, signature.alt_constructor) {
      signatures.push(signature)
    }
  }
  signatures
}

///|
fn BuslaneLowerer::lower_specialized_rows(
  self : BuslaneLowerer,
  rows : Array[LowerPatternRow],
  binder : @buslane.ValueId,
  signature : LowerConstructorSignature,
) -> Array[LowerPatternRow] {
  let specialized = []
  for row in rows {
    if self.lower_specialized_row(row, binder, signature) is Some(row) {
      specialized.push(row)
    }
  }
  specialized
}

///|
fn BuslaneLowerer::lower_specialized_row(
  self : BuslaneLowerer,
  row : LowerPatternRow,
  binder : @buslane.ValueId,
  signature : LowerConstructorSignature,
) -> LowerPatternRow? {
  guard row.patterns.get(0) is Some(head) else { return None }
  let tail = checked_pattern_tail(row.patterns)
  match head {
    Wildcard(..) =>
      Some({
        patterns: checked_pattern_concat(
          wildcard_checked_patterns(signature.argument_types),
          tail,
        ),
        body: row.body,
      })
    Binding(..) =>
      Some({
        patterns: checked_pattern_concat(
          wildcard_checked_patterns(signature.argument_types),
          tail,
        ),
        body: self.lower_bind_whole_pattern(head, binder, row.body),
      })
    _ if self.lower_signature_for_pattern(head) is Some(head_signature) &&
      head_signature.alt_constructor == signature.alt_constructor =>
      Some({
        patterns: checked_pattern_concat(
          lower_constructor_arguments_for_pattern(head),
          tail,
        ),
        body: row.body,
      })
    _ => None
  }
}

///|
fn BuslaneLowerer::lower_default_rows(
  self : BuslaneLowerer,
  rows : Array[LowerPatternRow],
  binder : @buslane.ValueId,
) -> Array[LowerPatternRow] {
  let default_rows = []
  for row in rows {
    guard row.patterns.get(0) is Some(pattern) else { continue }
    if pattern is Wildcard(..) {
      default_rows.push({
        patterns: checked_pattern_tail(row.patterns),
        body: row.body,
      })
    } else if pattern is Binding(..) {
      default_rows.push({
        patterns: checked_pattern_tail(row.patterns),
        body: self.lower_bind_whole_pattern(pattern, binder, row.body),
      })
    }
  }
  default_rows
}

///|
fn BuslaneLowerer::lower_bind_whole_pattern(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
  binder : @buslane.ValueId,
  body : @buslane.Expr,
) -> @buslane.Expr {
  if pattern is Binding(symbol~, ..) && self.value_id(symbol) != binder {
    Let(self.value_id(symbol), Ref(binder), body)
  } else {
    body
  }
}

///|
fn BuslaneLowerer::lower_signature_for_pattern(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
) -> LowerConstructorSignature? {
  match pattern {
    Wildcard(..) | Binding(..) => None
    Literal(literal~, ..) =>
      Some({
        alt_constructor: Literal(lower_literal(literal)),
        argument_types: [],
        type_binders: [],
      })
    Variant(symbol~, generic_arguments~, arguments~, ..) => {
      let data_constructor = self.data_constructor_id(symbol)
      Some({
        alt_constructor: DataCon(data_constructor),
        argument_types: arguments.map(fn(argument) { argument.type_() }),
        type_binders: self.lower_pattern_type_binders(
          data_constructor, generic_arguments,
        ),
      })
    }
    Struct(symbol~, type_binders~, fields~, ..) => {
      let lowered_type_binders : Array[@buslane.TypeParameterId] = []
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          lowered_type_binders.push(self.define_type_parameter(parameter))
        }
      }
      Some({
        alt_constructor: DataCon(self.struct_constructor_id(symbol)),
        argument_types: fields.map(fn(field) { field.pattern.type_() }),
        type_binders: lowered_type_binders,
      })
    }
  }
}

///|
fn lower_constructor_arguments_for_pattern(
  pattern : @checked.CheckedPattern,
) -> Array[@checked.CheckedPattern] {
  match pattern {
    Variant(arguments~, ..) => arguments
    Struct(fields~, ..) => fields.map(fn(field) { field.pattern })
    _ => []
  }
}

///|
fn BuslaneLowerer::lower_constructor_set_complete(
  self : BuslaneLowerer,
  type_ : @types.Type,
  constructors : Array[LowerConstructorSignature],
) -> Bool {
  if self.complete_alt_constructors_for_type(type_) is Some(complete) {
    !complete.is_empty() &&
    complete.all(fn(alt_constructor) {
      lower_signature_contains(constructors, alt_constructor)
    })
  } else {
    false
  }
}

///|
fn BuslaneLowerer::complete_alt_constructors_for_type(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> Array[@buslane.AltCon]? {
  if decompose_checked_nominal(type_) is Some((symbol, _)) {
    if self.metadata.type_info(self.type_id(symbol)) is Some(info) {
      return Some(
        info.constructors.map(fn(data_constructor) { DataCon(data_constructor) }),
      )
    }
    return None
  }
  match type_ {
    Error => Some([])
    Primitive(Bool) => Some([Literal(Bool(false)), Literal(Bool(true))])
    Primitive(Unit) => Some([Literal(Unit)])
    Primitive(Int) | Primitive(Double) | Primitive(String) => None
    _ => None
  }
}

///|
fn lower_signature_contains(
  signatures : Array[LowerConstructorSignature],
  alt_constructor : @buslane.AltCon,
) -> Bool {
  signatures.any(fn(signature) { signature.alt_constructor == alt_constructor })
}

///|
fn wildcard_checked_patterns(
  types : Array[@types.Type],
) -> Array[@checked.CheckedPattern] {
  types.map(fn(type_) { Wildcard(type_~, loc=@basic.SourceSpan::dummy()) })
}

///|
fn checked_pattern_tail(
  patterns : Array[@checked.CheckedPattern],
) -> Array[@checked.CheckedPattern] {
  let tail = []
  for index in 1..<patterns.length() {
    tail.push(patterns[index])
  }
  tail
}

///|
fn checked_pattern_concat(
  head : Array[@checked.CheckedPattern],
  tail : Array[@checked.CheckedPattern],
) -> Array[@checked.CheckedPattern] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn lower_type_tail(types : Array[@types.Type]) -> Array[@types.Type] {
  let tail = []
  for index in 1..<types.length() {
    tail.push(types[index])
  }
  tail
}

///|
fn lower_type_concat(
  head : Array[@types.Type],
  tail : Array[@types.Type],
) -> Array[@types.Type] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn buslane_expr_tail(
  expressions : Array[@buslane.Expr],
) -> Array[@buslane.Expr] {
  let tail = []
  for index in 1..<expressions.length() {
    tail.push(expressions[index])
  }
  tail
}

///|
fn buslane_expr_concat(
  head : Array[@buslane.Expr],
  tail : Array[@buslane.Expr],
) -> Array[@buslane.Expr] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn buslane_value_tail(
  values : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let tail = []
  for index in 1..<values.length() {
    tail.push(values[index])
  }
  tail
}

///|
fn buslane_value_concat(
  head : Array[@buslane.ValueId],
  tail : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn BuslaneLowerer::lower_pattern_type_binders(
  self : BuslaneLowerer,
  data_constructor : @buslane.DataConId,
  generic_arguments : Array[@types.GenericArgument],
) -> Array[@buslane.TypeParameterId] {
  let lowered : Array[@buslane.TypeParameterId] = []
  let hidden_parameters = match
    self.metadata.data_constructor_info(data_constructor) {
    Some(info) => info.hidden_type_parameters
    None => []
  }
  for index in 0..<generic_arguments.length() {
    let argument = generic_arguments[index]
    let parameter = match argument {
      TypeArgument(Parameter(parameter))
      | EffectArgument(Parameter(parameter)) => Some(parameter)
      _ => None
    }
    if parameter is Some(parameter) {
      let kind = match hidden_parameters.get(index) {
        Some(hidden) =>
          match self.metadata.type_parameter_info(hidden) {
            Some(info) => info.kind
            None => Type
          }
        None => Type
      }
      lowered.push(
        self.define_type_parameter_with_kind(parameter, "hidden_\{index}", kind),
      )
    }
  }
  lowered
}

///|
fn BuslaneLowerer::define_pattern_binders(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(..) | Literal(..) => ()
    Binding(name~, symbol~, type_~, ..) =>
      ignore(
        self.define_value(symbol, name, MatchBinder, self.lower_type(type_)),
      )
    Variant(symbol~, generic_arguments~, arguments~, ..) => {
      ignore(
        self.lower_pattern_type_binders(
          self.data_constructor_id(symbol),
          generic_arguments,
        ),
      )
      for argument in arguments {
        self.define_pattern_binders(argument)
      }
    }
    Struct(type_binders~, fields~, ..) => {
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          ignore(self.define_type_parameter(parameter))
        }
      }
      for field in fields {
        self.define_pattern_binders(field.pattern)
      }
    }
  }
}
