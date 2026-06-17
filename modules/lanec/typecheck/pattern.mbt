///|
priv struct PatternMatrix {
  rows : Array[@checked.CheckedPattern]
}

///|
fn PatternMatrix::PatternMatrix() -> PatternMatrix {
  { rows: [] }
}

///|
fn PatternMatrix::add(
  self : PatternMatrix,
  pattern : @checked.CheckedPattern,
) -> Unit {
  self.rows.push(pattern)
}

///|
fn SemanticChecker::check_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  // Match checking judgment:
  //
  //   Gamma |- scrutinee => S
  //   Gamma, binders(p_i : S) |- body_i <= Expected
  //   useful(p_i, previous_patterns)
  //   exhaustive(S, patterns)
  //
  // The scrutinee type is synthesized once, then every arm pattern is checked
  // against that type. Pattern binders extend only the copied arm scope. This
  // pass records the checked patterns needed by later ANF, but it does
  // not build a decision tree; the tree is an execution lowering concern.
  let scrutinee_type = self.synthesize_expr(scope, scrutinee)
  let matrix = PatternMatrix::PatternMatrix()
  for arm in arms {
    let arm_scope = scope.copy()
    let pattern = self.check_match_pattern(
      arm_scope,
      arm.pattern,
      scrutinee_type,
    )
    if !matrix.is_useful(self.declarations, pattern, scrutinee_type) {
      self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
    }
    matrix.add(pattern)
    self.check_expr(arm_scope, arm.body, expected)
  }
  if !matrix.is_exhaustive(self.declarations, scrutinee_type) {
    self.diagnostics.push({ kind: NonExhaustiveMatch(scrutinee_type), loc })
  }
}

///|
fn SemanticChecker::synthesize_match(
  self : SemanticChecker,
  scope : TypeScope,
  scrutinee : @desugar.DesugaredExpr,
  arms : Array[@desugar.DesugaredMatchArm],
  loc : SourceSpan,
) -> @types.Type {
  // Match synthesis judgment:
  //
  //   Gamma |- scrutinee => S
  //   Gamma, binders(p_i : S) |- body_i => T_i
  //   T_1 == ... == T_n
  //
  // Unlike checking mode, no result type is pushed into arm bodies. The first
  // arm establishes the synthesized result type, and later arms are required to
  // match it. Exhaustiveness and usefulness are still checked on the same
  // pattern matrix used by checking mode.
  let scrutinee_type = self.synthesize_expr(scope, scrutinee)
  let matrix = PatternMatrix::PatternMatrix()
  let mut result : @types.Type = Error
  let mut has_result = false
  for arm in arms {
    let arm_scope = scope.copy()
    let pattern = self.check_match_pattern(
      arm_scope,
      arm.pattern,
      scrutinee_type,
    )
    if !matrix.is_useful(self.declarations, pattern, scrutinee_type) {
      self.diagnostics.push({ kind: UnreachableMatchArm, loc: arm.loc })
    }
    matrix.add(pattern)
    let arm_type = self.synthesize_expr(arm_scope, arm.body)
    self.check_hidden_type_escape(
      pattern.opened_type_parameters(),
      arm_type,
      arm.body.loc(),
    )
    if has_result {
      self.expect_type(result, arm_type, arm.loc)
    } else {
      result = arm_type
      has_result = true
    }
  }
  if !has_result {
    self.diagnostics.push({ kind: CannotInferExpression("empty match"), loc })
  }
  if !matrix.is_exhaustive(self.declarations, scrutinee_type) {
    self.diagnostics.push({ kind: NonExhaustiveMatch(scrutinee_type), loc })
  }
  result
}

///|
fn SemanticChecker::check_match_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  pattern : @resolve.ResolvedPattern,
  expected : @types.Type,
) -> @checked.CheckedPattern {
  // Pattern checking judgment:
  //
  //   Gamma |- p <= T ~~> checked_p, Gamma'
  //
  // Patterns are checked against an already known scrutinee type. They do not
  // synthesize the scrutinee type and do not create non-local type variables.
  // The binder set is per-pattern and rejects repeated names before the arm
  // body is checked under the extended scope.
  let binders : Array[String] = []
  self.check_pattern(scope, pattern, expected, binders)
}

///|
fn SemanticChecker::check_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  pattern : @resolve.ResolvedPattern,
  expected : @types.Type,
  binders : Array[String],
) -> @checked.CheckedPattern {
  match pattern {
    Wildcard(loc) => Wildcard(type_=expected, loc~)
    Binding(name~, symbol~, loc~) => {
      if binders.contains(name) {
        self.diagnostics.push({ kind: DuplicatePatternBinder(name~), loc })
      } else {
        binders.push(name)
      }
      scope.bind(symbol, expected)
      Binding(name~, symbol~, type_=expected, loc~)
    }
    IntLiteral(raw, loc~) => {
      self.expect_type(expected, Primitive(Int), loc)
      Literal(
        literal=Int(self.check_int_literal(raw, loc)),
        type_=expected,
        loc~,
      )
    }
    StringLiteral(value, loc~) => {
      self.expect_type(expected, Primitive(String), loc)
      Literal(literal=String(value), type_=expected, loc~)
    }
    BoolLiteral(value, loc~) => {
      self.expect_type(expected, Primitive(Bool), loc)
      Literal(literal=Bool(value), type_=expected, loc~)
    }
    QualifiedVariant(
      type_name~,
      variant~,
      type_binders~,
      reference~,
      arguments~,
      loc~
    ) =>
      self.check_variant_pattern(
        scope, type_name, variant, type_binders, reference, arguments, expected,
        binders, loc,
      )
    Struct(type_name~, fields~, loc~) =>
      self.check_struct_pattern(
        scope, type_name, fields, expected, binders, loc,
      )
  }
}

///|
fn SemanticChecker::check_variant_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  variant : String,
  type_binders : Array[@resolve.ResolvedTypeParameter],
  reference : @resolve.ResolvedVariantReference,
  arguments : Array[@resolve.ResolvedPattern],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  match reference {
    Symbol(symbol) =>
      self.check_variant_symbol_pattern(
        scope, type_name, variant, symbol, type_binders, arguments, expected, binders,
        loc,
      )
    Ambiguous(name~, ..) => {
      self.report_ambiguous_variant_reference(name, loc)
      Wildcard(type_=Error, loc~)
    }
    Unresolved(type_name~, variant~) => {
      self.diagnostics.push({
        kind: CannotInferExpression(
          "unresolved variant " + type_name + "::" + variant,
        ),
        loc,
      })
      Wildcard(type_=Error, loc~)
    }
    UnresolvedUnqualified(name) => {
      self.diagnostics.push({
        kind: CannotInferExpression("unresolved variant " + name),
        loc,
      })
      Wildcard(type_=Error, loc~)
    }
  }
}

///|
fn SemanticChecker::check_variant_symbol_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  variant : String,
  symbol : VariantSymbolId,
  type_binders : Array[@resolve.ResolvedTypeParameter],
  arguments : Array[@resolve.ResolvedPattern],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  // Variant pattern rule:
  //
  //   Expected = E[A_1, ..., A_n]
  //   variant v belongs to E
  //   payload_i[v][A_1, ..., A_n] checks pattern_i
  //
  // Variant patterns are nominal. The variant symbol determines the owner enum,
  // and the expected enum application supplies the type arguments used to
  // substitute payload types.
  guard self.source.symbols.variant_metadata(symbol) is Some(metadata) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        "unknown variant " + type_name + "::" + variant,
      ),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard self.declarations.checked_enum(metadata.owner) is Some(declaration) else {
    self.diagnostics.push({
      kind: CannotInferExpression("unknown variant owner " + type_name),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  guard declaration.variant(symbol) is Some(variant_declaration) else {
    self.diagnostics.push({
      kind: CannotInferExpression(
        "unknown variant " + type_name + "::" + variant,
      ),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  let type_arguments = match expected {
    Nominal(owner, arguments) if owner == metadata.owner => arguments
    Error => []
    _ => {
      self.expect_type(
        expected,
        Nominal(
          metadata.owner,
          declaration.type_parameters.map(fn(parameter) {
            Parameter(parameter.id)
          }),
        ),
        loc,
      )
      []
    }
  }
  if variant_declaration.payload.length() != arguments.length() {
    self.diagnostics.push({
      kind: PatternArityMismatch(
        name=type_name + "::" + variant,
        expected=variant_declaration.payload.length(),
        actual=arguments.length(),
      ),
      loc,
    })
  }
  let substitution = variant_type_substitution(
    declaration.type_parameters,
    type_arguments,
  )
  if type_binders.length() != variant_declaration.type_parameters.length() {
    self.diagnostics.push({
      kind: TypeArgumentArityMismatch(
        name=type_name + "::" + variant,
        expected=variant_declaration.type_parameters.length(),
        actual=type_binders.length(),
      ),
      loc,
    })
  }
  let hidden_type_arguments = type_binders.map(fn(parameter) {
    @types.Type::Parameter(parameter.symbol)
  })
  let hidden_substitution = variant_type_substitution(
    variant_declaration.type_parameters,
    hidden_type_arguments,
  )
  let checked_arguments = []
  let length = if variant_declaration.payload.length() < arguments.length() {
    variant_declaration.payload.length()
  } else {
    arguments.length()
  }
  for index in 0..<length {
    checked_arguments.push(
      self.check_pattern(
        scope,
        arguments[index],
        variant_declaration.payload[index]
        .substitute(substitution)
        .substitute(hidden_substitution),
        binders,
      ),
    )
  }
  Variant(
    symbol~,
    type_arguments=hidden_type_arguments,
    arguments=checked_arguments,
    type_=expected,
    loc~,
  )
}

///|
fn SemanticChecker::check_struct_pattern(
  self : SemanticChecker,
  scope : TypeScope,
  type_name : String,
  fields : Array[@resolve.ResolvedStructPatternField],
  expected : @types.Type,
  binders : Array[String],
  loc : SourceSpan,
) -> @checked.CheckedPattern {
  // Struct pattern rule:
  //
  //   Expected = S[A_1, ..., A_n]
  //   every declared field of S appears exactly once
  //   field_i[S][A_1, ..., A_n] checks pattern_i
  //
  // Source field order is ignored after checking. The checked struct pattern is
  // emitted in declaration order so ANF and later execution lowering do
  // not depend on source spelling order.
  guard self.source.symbols.type_named(type_name) is Some(symbol) else {
    self.diagnostics.push({ kind: UnresolvedType(type_name), loc })
    return Wildcard(type_=Error, loc~)
  }
  let type_arguments = match expected {
    Nominal(owner, arguments) if owner == symbol => arguments
    Error => []
    _ => {
      self.expect_type(expected, Nominal(symbol, []), loc)
      []
    }
  }
  guard self.declarations.checked_struct(symbol) is Some(declaration) else {
    self.diagnostics.push({
      kind: NotAStruct(Nominal(symbol, type_arguments)),
      loc,
    })
    return Wildcard(type_=Error, loc~)
  }
  let seen = []
  for field in fields {
    if field is Value(name~, loc~, ..) {
      if seen.contains(name) {
        self.diagnostics.push({ kind: DuplicateField(name~), loc })
      } else {
        seen.push(name)
      }
      if self.source.symbols.field_named(symbol, name) is None {
        self.diagnostics.push({ kind: UnknownField(name~), loc })
      }
    }
  }
  let substitution = declaration.nominal_substitution(type_arguments)
  let type_member_result = self.check_struct_pattern_type_binders(
    declaration, fields, loc,
  )
  let existential_substitution = declaration.pattern_existential_substitution(
    type_member_result.binders,
  )
  let checked_fields = []
  for declaration_field in declaration.fields {
    match fields.find_by_name(declaration_field.name) {
      Some(field) => {
        guard field is Value(pattern~, loc~, ..) else { continue }
        let checked = self.check_pattern(
          scope,
          pattern,
          declaration_field.type_
          .substitute(substitution)
          .substitute(existential_substitution),
          binders,
        )
        let checked_field : @checked.CheckedStructPatternField = {
          symbol: declaration_field.symbol,
          name: declaration_field.name,
          pattern: checked,
          loc,
        }
        checked_fields.push(checked_field)
      }
      None =>
        self.diagnostics.push({
          kind: MissingField(name=declaration_field.name),
          loc,
        })
    }
  }
  Struct(
    symbol~,
    type_binders=type_member_result.binders,
    fields=checked_fields,
    type_=expected,
    loc~,
  )
}

///|
priv struct CheckedStructPatternTypeBinders {
  binders : Array[@checked.CheckedStructTypeBinder]
}

///|
fn SemanticChecker::check_struct_pattern_type_binders(
  self : SemanticChecker,
  declaration : CheckedStructDeclaration,
  fields : Array[@resolve.ResolvedStructPatternField],
  loc : SourceSpan,
) -> CheckedStructPatternTypeBinders {
  let binders : Array[@checked.CheckedStructTypeBinder] = []
  let used_field_indices : Array[Int] = []
  self.check_struct_pattern_type_binder_names(declaration, fields)
  for type_member in declaration.type_members {
    let mut found = false
    for index in 0..<fields.length() {
      let field = fields[index]
      if !used_field_indices.contains(index) {
        match field {
          TypeBinder(name~, type_parameter~, loc=field_loc) =>
            if name == type_member.name {
              used_field_indices.push(index)
              found = true
              binders.push({
                symbol: type_member.symbol,
                type_parameter: Some(
                  checked_type_parameter_with_kind(
                    type_parameter,
                    type_member.kind,
                  ),
                ),
                name: Some(name),
                loc: field_loc,
              })
            }
          TypeWildcard(type_parameter~, loc=field_loc) =>
            if !found {
              used_field_indices.push(index)
              found = true
              binders.push({
                symbol: type_member.symbol,
                type_parameter: Some(
                  checked_type_parameter_with_kind(
                    type_parameter,
                    type_member.kind,
                  ),
                ),
                name: None,
                loc: field_loc,
              })
            }
          _ => ()
        }
      }
    }
    if !found {
      self.diagnostics.push({
        kind: MissingTypeMember(name=type_member.name),
        loc,
      })
    }
  }
  { binders, }
}

///|
fn SemanticChecker::check_struct_pattern_type_binder_names(
  self : SemanticChecker,
  declaration : CheckedStructDeclaration,
  fields : Array[@resolve.ResolvedStructPatternField],
) -> Unit {
  let seen = []
  for field in fields {
    if field is TypeBinder(name~, loc~, ..) {
      if seen.contains(name) {
        self.diagnostics.push({ kind: DuplicateTypeMember(name~), loc })
      } else {
        seen.push(name)
      }
      if declaration.type_member_named(name) is None {
        self.diagnostics.push({ kind: UnknownTypeMember(name~), loc })
      }
    }
  }
}

///|
fn CheckedStructDeclaration::pattern_existential_substitution(
  self : CheckedStructDeclaration,
  binders : Array[@checked.CheckedStructTypeBinder],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for binder in binders {
    if binder.type_parameter is Some(parameter) &&
      self.type_member(binder.symbol) is Some(type_member) {
      substitution.insert(
        type_member.type_parameter.id,
        Parameter(parameter.id),
      )
    }
  }
  substitution
}

///|
fn Array::find_by_name(
  self : Array[@resolve.ResolvedStructPatternField],
  name : String,
) -> @resolve.ResolvedStructPatternField? {
  for field in self {
    if field is Value(name=field_name, ..) && field_name == name {
      return Some(field)
    }
  }
  None
}

///|
fn PatternMatrix::is_useful(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  pattern : @checked.CheckedPattern,
  type_ : @types.Type,
) -> Bool {
  // Usefulness judgment:
  //
  //   useful(matrix, p, T)
  //
  // The current implementation is the single-scrutinee slice of the standard
  // pattern-matrix algorithm. It is intentionally conservative for nested
  // payloads: a constructor pattern covers a previous constructor only when its
  // payload patterns are irrefutable or structurally identical.
  if self.is_exhaustive(declarations, type_) {
    return false
  }
  match pattern {
    Wildcard(..) | Binding(..) => true
    Literal(literal=Bool(value), ..) => !self.covers_bool_literal(value)
    Literal(literal=Int(literal), ..) => !self.covers_int_literal(literal.value)
    Literal(literal=String(value), ..) => !self.covers_string_literal(value)
    Literal(literal=Unit, ..) => true
    Variant(symbol~, arguments~, ..) =>
      !self.covers_variant(declarations, symbol, arguments)
    Struct(..) => true
  }
}

///|
fn PatternMatrix::is_exhaustive(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  type_ : @types.Type,
) -> Bool {
  // Exhaustiveness judgment:
  //
  //   exhaustive(matrix, T)
  //
  // Bool and Unit use their finite primitive inhabitant sets. Int and String
  // require an irrefutable fallback because their literal spaces are open in
  // v1. Nominal enums are exhaustive when every variant constructor is covered;
  // nominal structs need an irrefutable struct, wildcard, or binding pattern.
  if self.rows.any(fn(row) { pattern_is_irrefutable(declarations, row, type_) }) {
    true
  } else {
    match type_ {
      Error => true
      Primitive(Bool) =>
        self.covers_bool_literal(true) && self.covers_bool_literal(false)
      Primitive(Unit) | Primitive(Int) | Primitive(String) => false
      Nominal(symbol, _) =>
        match declarations.checked_enum(symbol) {
          Some(declaration) =>
            declaration.variants.all(fn(variant) {
              self.covers_variant_constructor(declarations, variant)
            })
          None => false
        }
      Parameter(_) | Function(_, _) | Forall(_, _) => false
    }
  }
}

///|
fn PatternMatrix::covers_bool_literal(
  self : PatternMatrix,
  value : Bool,
) -> Bool {
  self.rows.any(fn(row) {
    match row {
      Wildcard(..) | Binding(..) => true
      Literal(literal=Bool(row_value), ..) => row_value == value
      _ => false
    }
  })
}

///|
fn PatternMatrix::covers_int_literal(
  self : PatternMatrix,
  value : Int64,
) -> Bool {
  self.rows.any(fn(row) {
    match row {
      Wildcard(..) | Binding(..) => true
      Literal(literal=Int(row_literal), ..) => row_literal.value == value
      _ => false
    }
  })
}

///|
fn PatternMatrix::covers_string_literal(
  self : PatternMatrix,
  value : String,
) -> Bool {
  self.rows.any(fn(row) {
    match row {
      Wildcard(..) | Binding(..) => true
      Literal(literal=String(row_value), ..) => row_value == value
      _ => false
    }
  })
}

///|
fn PatternMatrix::covers_variant(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  symbol : VariantSymbolId,
  arguments : Array[@checked.CheckedPattern],
) -> Bool {
  self.rows.any(fn(row) {
    match row {
      Wildcard(..) | Binding(..) => true
      Variant(symbol=row_symbol, arguments=row_arguments, ..) =>
        row_symbol == symbol &&
        variant_arguments_cover(declarations, row_arguments, arguments)
      _ => false
    }
  })
}

///|
fn PatternMatrix::covers_variant_constructor(
  self : PatternMatrix,
  declarations : CheckedDeclarationEnvironment,
  variant : CheckedVariantDeclaration,
) -> Bool {
  self.rows.any(fn(row) {
    match row {
      Wildcard(..) | Binding(..) => true
      Variant(symbol~, arguments~, ..) =>
        symbol == variant.symbol &&
        variant_arguments_irrefutable(declarations, arguments)
      _ => false
    }
  })
}

///|
fn pattern_is_irrefutable(
  declarations : CheckedDeclarationEnvironment,
  pattern : @checked.CheckedPattern,
  type_ : @types.Type,
) -> Bool {
  match pattern {
    Wildcard(..) | Binding(..) => true
    Struct(fields~, ..) =>
      fields.all(fn(field) {
        pattern_is_irrefutable(
          declarations,
          field.pattern,
          field.pattern.type_(),
        )
      })
    Variant(symbol~, arguments~, ..) =>
      if type_ is Nominal(owner, _) &&
        declarations.checked_enum(owner) is Some(declaration) {
        declaration.variants.length() == 1 &&
        declaration.variants[0].symbol == symbol &&
        variant_arguments_irrefutable(declarations, arguments)
      } else {
        false
      }
    Literal(..) => false
  }
}

///|
fn variant_arguments_cover(
  declarations : CheckedDeclarationEnvironment,
  covered : Array[@checked.CheckedPattern],
  target : Array[@checked.CheckedPattern],
) -> Bool {
  if covered.length() != target.length() {
    return false
  }
  for index in 0..<covered.length() {
    if !pattern_is_irrefutable(
        declarations,
        covered[index],
        target[index].type_(),
      ) &&
      covered[index] != target[index] {
      return false
    }
  }
  true
}

///|
fn variant_arguments_irrefutable(
  declarations : CheckedDeclarationEnvironment,
  arguments : Array[@checked.CheckedPattern],
) -> Bool {
  arguments.all(fn(argument) {
    pattern_is_irrefutable(declarations, argument, argument.type_())
  })
}
