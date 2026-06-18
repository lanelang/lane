///|
priv struct TypeMapEntry {
  source : @symbol.TypeSymbolId
  target : @buslane.TypeId
}

///|
priv struct TypeParameterMapEntry {
  source : @symbol.TypeParameterId
  target : @buslane.TypeParameterId
}

///|
priv struct ValueMapEntry {
  source : @symbol.ValueSymbolId
  target : @buslane.ValueId
}

///|
priv struct DataConMapEntry {
  source : @symbol.VariantSymbolId
  target : @buslane.DataConId
}

///|
priv struct StructConMapEntry {
  source : @symbol.TypeSymbolId
  target : @buslane.DataConId
}

///|
priv struct FieldSelectorMapEntry {
  source : @symbol.FieldSymbolId
  target : @buslane.ValueId
}

///|
priv struct BuslaneLowerer {
  metadata : @buslane.MetadataRegistry
  type_symbols : Array[TypeMapEntry]
  type_parameters : Array[TypeParameterMapEntry]
  values : Array[ValueMapEntry]
  data_constructors : Array[DataConMapEntry]
  struct_constructors : Array[StructConMapEntry]
  field_selectors : Array[FieldSelectorMapEntry]
  selector_terms : Array[@buslane.TopTerm]
  external_terms : Array[@buslane.TopTerm]
  builtin_externals : Array[BuslaneBuiltinExternal]
  entries : Array[BuslaneEntry]
}

///|
fn BuslaneLowerer::BuslaneLowerer() -> BuslaneLowerer {
  {
    metadata: MetadataRegistry(),
    type_symbols: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    struct_constructors: [],
    field_selectors: [],
    selector_terms: [],
    external_terms: [],
    builtin_externals: [],
    entries: [],
  }
}

///|
/// Lowers Checked Source into the Buslane Core Language.
pub fn lower_checked_source_file_to_buslane(
  source : @checked.CheckedSourceFile,
) -> @buslane.Program {
  lower_checked_source_file_to_buslane_result(source).program
}

///|
/// Lowers Checked Source into Buslane and returns compiler-owned side tables.
pub fn lower_checked_source_file_to_buslane_result(
  source : @checked.CheckedSourceFile,
) -> BuslaneLowerResult {
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  lowerer.collect_type_headers(source)
  lowerer.collect_data_constructors(source)
  lowerer.collect_field_selectors(source)
  lowerer.collect_top_values(source)
  let terms = lowerer.lower_top_terms(source)
  {
    program: {
      metadata: lowerer.metadata,
      terms: lowerer.external_terms + terms,
    },
    externals: { builtins: lowerer.builtin_externals },
    entries: lowerer.entries,
  }
}

///|
fn BuslaneLowerer::collect_type_headers(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => self.collect_struct_header(declaration)
      Enum(declaration) => self.collect_enum_header(declaration)
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::add_entry(
  self : BuslaneLowerer,
  name : String,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> Unit {
  self.entries.push({ name, value, type_ })
}

///|
fn BuslaneLowerer::collect_struct_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter.id)
  })
  for type_member in declaration.type_members {
    ignore(self.define_type_parameter(type_member.type_parameter.id))
  }
  let target = self.metadata.define_type(parameters)
  self.type_symbols.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_enum_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEnumDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter.id)
  })
  for variant in declaration.variants {
    for parameter in variant.type_parameters {
      ignore(self.define_type_parameter(parameter.id))
    }
  }
  let target = self.metadata.define_type(parameters)
  self.type_symbols.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_data_constructors(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => self.collect_struct_constructor(declaration)
      Enum(declaration) => self.collect_enum_constructors(declaration)
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::collect_struct_constructor(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Unit {
  let owner = self.type_id(declaration.symbol)
  let hidden_type_parameters = declaration.type_members.map(fn(type_member) {
    self.define_type_parameter(type_member.type_parameter.id)
  })
  let payload_types = declaration.fields.map(fn(field) {
    self.lower_type(field.type_)
  })
  let target = self.metadata.define_data_constructor(
    owner, hidden_type_parameters, payload_types,
  )
  self.struct_constructors.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_enum_constructors(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEnumDeclaration,
) -> Unit {
  let owner = self.type_id(declaration.symbol)
  for variant in declaration.variants {
    let hidden_type_parameters = variant.type_parameters.map(fn(parameter) {
      self.define_type_parameter(parameter.id)
    })
    let payload_types = variant.payload.map(fn(type_) { self.lower_type(type_) })
    let target = self.metadata.define_data_constructor(
      owner, hidden_type_parameters, payload_types,
    )
    self.data_constructors.push({ source: variant.symbol, target })
  }
}

///|
fn BuslaneLowerer::collect_field_selectors(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    if declaration is Struct(declaration) {
      for index in 0..<declaration.fields.length() {
        self.collect_field_selector(declaration, index)
      }
    }
  }
}

///|
fn BuslaneLowerer::collect_field_selector(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field_index : Int,
) -> Unit {
  let field = declaration.fields[field_index]
  let type_parameters = self.selector_type_parameters(declaration)
  let selector_type = self.selector_type(declaration, field)
  let selector = self.metadata.define_value(Function, selector_type)
  self.field_selectors.push({ source: field.symbol, target: selector })
  self.selector_terms.push(
    Let(selector, self.selector_body(declaration, field_index, type_parameters)),
  )
}

///|
fn BuslaneLowerer::selector_type_parameters(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Array[@buslane.TypeParameterId] {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter.id)
  })
  for type_member in declaration.type_members {
    parameters.push(self.define_type_parameter(type_member.type_parameter.id))
  }
  parameters
}

///|
fn BuslaneLowerer::selector_type(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field : @checked.CheckedFieldDeclaration,
) -> @buslane.Type {
  let function = @buslane.Type::Function(
    [self.selector_receiver_type(declaration)],
    self.lower_type(field.type_),
  )
  let type_parameters = self.selector_type_parameters(declaration)
  if type_parameters.is_empty() {
    function
  } else {
    Forall(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::selector_receiver_type(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> @buslane.Type {
  buslane_nominal_type(
    self.type_id(declaration.symbol),
    declaration.type_parameters.map(fn(parameter) {
      Parameter(self.type_parameter_id(parameter.id))
    }),
  )
}

///|
fn BuslaneLowerer::selector_body(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field_index : Int,
  type_parameters : Array[@buslane.TypeParameterId],
) -> @buslane.Expr {
  let receiver_type = self.selector_receiver_type(declaration)
  let receiver = self.metadata.define_value(Parameter, receiver_type)
  let result_type = self.lower_type(declaration.fields[field_index].type_)
  let match_binder = self.metadata.define_value(MatchBinder, receiver_type)
  let value_binders = declaration.fields.map(fn(field) {
    self.metadata.define_value(MatchBinder, self.lower_type(field.type_))
  })
  let function = @buslane.Expr::Function({
    parameters: [receiver],
    result_type,
    body: Match({
      scrutinee: Ref(receiver),
      binder: match_binder,
      result_type,
      alternatives: [
        {
          alt_constructor: DataCon(
            self.struct_constructor_id(declaration.symbol),
          ),
          type_binders: declaration.type_members.map(fn(type_member) {
            self.type_parameter_id(type_member.type_parameter.id)
          }),
          value_binders,
          body: Ref(value_binders[field_index]),
        },
      ],
    }),
  })
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::collect_top_values(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Function(declaration) => {
        for parameter in declaration.type_parameters {
          ignore(self.define_type_parameter(parameter.id))
        }
        let type_ = self.lower_type(declaration.type_)
        let value = self.define_value(declaration.symbol, Function, type_)
        self.add_entry(declaration.name, value, type_)
      }
      Let(declaration) => {
        let type_ = self.lower_type(declaration.type_)
        let value = self.define_value(declaration.symbol, Value, type_)
        if declaration.name is Some(name) {
          self.add_entry(name, value, type_)
        }
      }
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::lower_top_terms(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Array[@buslane.TopTerm] {
  let terms : Array[@buslane.TopTerm] = []
  for selector in self.selector_terms {
    terms.push(selector)
  }
  let recursive_functions : Array[@buslane.RecursiveBinding] = []
  for declaration in source.declarations {
    if declaration is Function(function) {
      recursive_functions.push(self.lower_recursive_function(function))
    }
  }
  if !recursive_functions.is_empty() {
    terms.push(LetRec(recursive_functions))
  }
  for declaration in source.declarations {
    if declaration is Let(declaration) {
      terms.push(
        Let(
          self.value_id(declaration.symbol),
          self.lower_expr(declaration.initializer),
        ),
      )
    }
  }
  terms
}

///|
fn BuslaneLowerer::lower_recursive_function(
  self : BuslaneLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> @buslane.RecursiveBinding {
  {
    id: self.value_id(declaration.symbol),
    rhs: self.lower_function_declaration(declaration),
  }
}

///|
fn BuslaneLowerer::lower_function_declaration(
  self : BuslaneLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> @buslane.Expr {
  for parameter in declaration.type_parameters {
    ignore(self.define_type_parameter(parameter.id))
  }
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.type_parameter_id(parameter.id)
  })
  let function = @buslane.Expr::Function({
    parameters: declaration.parameters.map(fn(parameter) {
      self.define_value(
        parameter.symbol,
        Parameter,
        self.lower_type(parameter.type_),
      )
    }),
    result_type: self.lower_type(declaration.return_type),
    body: self.lower_expr(declaration.body),
  })
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::lower_expr(
  self : BuslaneLowerer,
  expression : @checked.CheckedExpr,
) -> @buslane.Expr {
  match expression {
    Literal(literal~, ..) => Literal(lower_literal(literal))
    Value(symbol~, ..) => Ref(self.value_id(symbol))
    UnsafeBuiltin(name~, type_~, ..) =>
      Ref(self.define_builtin_external(name, self.lower_type(type_)))
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) =>
      self.lower_function_literal(
        type_parameters, parameters, return_type, body,
      )
    TypeApplication(callee~, arguments~, ..) =>
      TypeApply(
        self.lower_expr(callee),
        arguments.map(fn(argument) { self.lower_type(argument) }),
      )
    Block(items~, result~, ..) => self.lower_items(items, 0, result)
    If(condition~, then_branch~, else_branch~, type_~, ..) =>
      self.lower_if(condition, then_branch, else_branch, type_)
    Match(scrutinee~, arms~, type_~, ..) =>
      self.lower_match(scrutinee, arms, type_)
    Call(callee~, arguments~, ..) =>
      Call(
        self.lower_expr(callee),
        arguments.map(fn(argument) { self.lower_expr(argument) }),
      )
    Field(base~, field~, ..) => self.lower_field(base, field)
    StructLiteral(symbol~, type_arguments~, type_witnesses~, fields~, ..) =>
      Construct({
        data_constructor: self.struct_constructor_id(symbol),
        type_arguments: type_arguments.map(fn(argument) {
          self.lower_type(argument)
        }),
        hidden_witnesses: type_witnesses.map(fn(witness) {
          self.lower_type(witness.type_)
        }),
        payloads: fields.map(fn(field) { self.lower_expr(field.value) }),
      })
    Variant(symbol~, type_arguments~, arguments~, type_~, ..) =>
      Construct({
        data_constructor: self.data_constructor_id(symbol),
        type_arguments: self.nominal_type_arguments(type_),
        hidden_witnesses: type_arguments.map(fn(argument) {
          self.lower_type(argument)
        }),
        payloads: arguments.map(fn(argument) { self.lower_expr(argument) }),
      })
  }
}

///|
fn BuslaneLowerer::lower_function_literal(
  self : BuslaneLowerer,
  type_parameters : Array[@types.TypeParameter],
  parameters : Array[@checked.CheckedValueParameter],
  return_type : @types.Type,
  body : @checked.CheckedExpr,
) -> @buslane.Expr {
  for parameter in type_parameters {
    ignore(self.define_type_parameter(parameter.id))
  }
  let lowered_type_parameters = type_parameters.map(fn(parameter) {
    self.type_parameter_id(parameter.id)
  })
  let function = @buslane.Expr::Function({
    parameters: parameters.map(fn(parameter) {
      self.define_value(
        parameter.symbol,
        Local,
        self.lower_type(parameter.type_),
      )
    }),
    result_type: self.lower_type(return_type),
    body: self.lower_expr(body),
  })
  if lowered_type_parameters.is_empty() {
    function
  } else {
    TypeLambda(lowered_type_parameters, function)
  }
}

///|
fn BuslaneLowerer::lower_items(
  self : BuslaneLowerer,
  items : Array[@checked.CheckedLocalItem],
  index : Int,
  result : @checked.CheckedExpr,
) -> @buslane.Expr {
  if index >= items.length() {
    self.lower_expr(result)
  } else {
    match items[index] {
      Let(declaration) => {
        let id = self.define_value(
          declaration.symbol,
          Local,
          self.lower_type(declaration.type_),
        )
        Let(
          id,
          self.lower_expr(declaration.initializer),
          self.lower_items(items, index + 1, result),
        )
      }
      Function(declaration) => {
        let id = self.define_value(
          declaration.symbol,
          Local,
          self.lower_type(declaration.type_),
        )
        LetRec(
          [{ id, rhs: self.lower_function_declaration(declaration) }],
          self.lower_items(items, index + 1, result),
        )
      }
      PatternLet(declaration) => {
        self.define_pattern_binders(declaration.pattern)
        let initializer = self.lower_expr(declaration.initializer)
        let result_type = self.lower_type(result.type_())
        let body = self.lower_items(items, index + 1, result)
        self.lower_pattern_as_match(
          declaration.pattern,
          initializer,
          body,
          result_type,
        )
      }
    }
  }
}

///|
fn BuslaneLowerer::lower_if(
  self : BuslaneLowerer,
  condition : @checked.CheckedExpr,
  then_branch : @checked.CheckedExpr,
  else_branch : @checked.CheckedExpr,
  result_type : @types.Type,
) -> @buslane.Expr {
  let binder = self.define_fresh_value(MatchBinder, Primitive(Bool))
  Match({
    scrutinee: self.lower_expr(condition),
    binder,
    result_type: self.lower_type(result_type),
    alternatives: [
      {
        alt_constructor: Literal(Bool(true)),
        type_binders: [],
        value_binders: [],
        body: self.lower_expr(then_branch),
      },
      {
        alt_constructor: Literal(Bool(false)),
        type_binders: [],
        value_binders: [],
        body: self.lower_expr(else_branch),
      },
    ],
  })
}

///|
fn BuslaneLowerer::lower_match(
  self : BuslaneLowerer,
  scrutinee : @checked.CheckedExpr,
  arms : Array[@checked.CheckedMatchArm],
  result_type : @types.Type,
) -> @buslane.Expr {
  let binder = self.define_fresh_value(
    MatchBinder,
    self.lower_type(scrutinee.type_()),
  )
  Match({
    scrutinee: self.lower_expr(scrutinee),
    binder,
    result_type: self.lower_type(result_type),
    alternatives: arms.map(fn(arm) {
      self.lower_match_arm(arm, binder, result_type)
    }),
  })
}

///|
fn BuslaneLowerer::lower_match_arm(
  self : BuslaneLowerer,
  arm : @checked.CheckedMatchArm,
  match_binder : @buslane.ValueId,
  result_type : @types.Type,
) -> @buslane.Alternative {
  self.define_pattern_binders(arm.pattern)
  self.lower_pattern_alternative(
    arm.pattern,
    match_binder,
    self.lower_expr(arm.body),
    self.lower_type(result_type),
  )
}

///|
fn BuslaneLowerer::lower_pattern_as_match(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
  initializer : @buslane.Expr,
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Expr {
  self.define_pattern_binders(pattern)
  let binder = self.define_fresh_value(
    MatchBinder,
    self.lower_type(pattern.type_()),
  )
  Match({
    scrutinee: initializer,
    binder,
    result_type,
    alternatives: [
      self.lower_pattern_alternative(pattern, binder, body, result_type),
    ],
  })
}

///|
fn BuslaneLowerer::lower_pattern_alternative(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
  match_binder : @buslane.ValueId,
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Alternative {
  match pattern {
    Wildcard(..) =>
      { alt_constructor: Default, type_binders: [], value_binders: [], body }
    Binding(symbol~, ..) =>
      {
        alt_constructor: Default,
        type_binders: [],
        value_binders: [],
        body: Let(self.value_id(symbol), Ref(match_binder), body),
      }
    Literal(literal~, ..) =>
      {
        alt_constructor: Literal(lower_literal(literal)),
        type_binders: [],
        value_binders: [],
        body,
      }
    Variant(symbol~, arguments~, ..) =>
      self.lower_data_pattern_alternative(
        self.data_constructor_id(symbol),
        [],
        arguments,
        body,
        result_type,
      )
    Struct(symbol~, type_binders~, fields~, ..) =>
      self.lower_struct_pattern_alternative(
        symbol, type_binders, fields, body, result_type,
      )
  }
}

///|
fn BuslaneLowerer::lower_data_pattern_alternative(
  self : BuslaneLowerer,
  data_constructor : @buslane.DataConId,
  type_binders : Array[@buslane.TypeParameterId],
  patterns : Array[@checked.CheckedPattern],
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Alternative {
  let value_binders = patterns.map(fn(pattern) {
    self.value_binder_for_payload(pattern)
  })
  let lowered_body = self.lower_nested_payload_patterns(
    patterns, value_binders, 0, body, result_type,
  )
  {
    alt_constructor: DataCon(data_constructor),
    type_binders,
    value_binders,
    body: lowered_body,
  }
}

///|
fn BuslaneLowerer::lower_struct_pattern_alternative(
  self : BuslaneLowerer,
  symbol : @symbol.TypeSymbolId,
  type_binders : Array[@checked.CheckedStructTypeBinder],
  fields : Array[@checked.CheckedStructPatternField],
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Alternative {
  let lowered_type_binders : Array[@buslane.TypeParameterId] = []
  for binder in type_binders {
    if binder.type_parameter is Some(parameter) {
      lowered_type_binders.push(self.define_type_parameter(parameter.id))
    }
  }
  let patterns = fields.map(fn(field) { field.pattern })
  self.lower_data_pattern_alternative(
    self.struct_constructor_id(symbol),
    lowered_type_binders,
    patterns,
    body,
    result_type,
  )
}

///|
fn BuslaneLowerer::lower_nested_payload_patterns(
  self : BuslaneLowerer,
  patterns : Array[@checked.CheckedPattern],
  value_binders : Array[@buslane.ValueId],
  index : Int,
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Expr {
  if index >= patterns.length() {
    body
  } else {
    let next = self.lower_nested_payload_patterns(
      patterns,
      value_binders,
      index + 1,
      body,
      result_type,
    )
    self.lower_payload_pattern(
      patterns[index],
      value_binders[index],
      next,
      result_type,
    )
  }
}

///|
fn BuslaneLowerer::lower_payload_pattern(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
  binder : @buslane.ValueId,
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Expr {
  match pattern {
    Wildcard(..) => body
    Binding(symbol~, ..) =>
      if self.value_id(symbol) == binder {
        body
      } else {
        Let(self.value_id(symbol), Ref(binder), body)
      }
    _ =>
      Match({
        scrutinee: Ref(binder),
        binder,
        result_type,
        alternatives: [
          self.lower_pattern_alternative(pattern, binder, body, result_type),
        ],
      })
  }
}

///|
fn BuslaneLowerer::value_binder_for_payload(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
) -> @buslane.ValueId {
  match pattern {
    Binding(symbol~, ..) => self.value_id(symbol)
    _ => self.define_fresh_value(MatchBinder, self.lower_type(pattern.type_()))
  }
}

///|
fn BuslaneLowerer::define_pattern_binders(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(..) | Literal(..) => ()
    Binding(symbol~, type_~, ..) =>
      ignore(self.define_value(symbol, MatchBinder, self.lower_type(type_)))
    Variant(arguments~, ..) =>
      for argument in arguments {
        self.define_pattern_binders(argument)
      }
    Struct(type_binders~, fields~, ..) => {
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          ignore(self.define_type_parameter(parameter.id))
        }
      }
      for field in fields {
        self.define_pattern_binders(field.pattern)
      }
    }
  }
}

///|
fn BuslaneLowerer::lower_field(
  self : BuslaneLowerer,
  base : @checked.CheckedExpr,
  field : @symbol.FieldSymbolId,
) -> @buslane.Expr {
  let selector : @buslane.Expr = Ref(self.field_selector_id(field))
  let callee = match base.type_().decompose_nominal() {
    Some((_, arguments)) =>
      if arguments.is_empty() {
        selector
      } else {
        TypeApply(
          selector,
          arguments.map(fn(argument) { self.lower_type(argument) }),
        )
      }
    _ => selector
  }
  Call(callee, [self.lower_expr(base)])
}

///|
fn lower_literal(literal : @checked.CheckedLiteral) -> @buslane.Literal {
  match literal {
    Int(literal) => Int(literal.value)
    String(value) => String(value)
    Bool(value) => Bool(value)
    Unit => Unit
  }
}

///|
fn BuslaneLowerer::lower_type(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> @buslane.Type {
  match type_ {
    Error => Primitive(Unit)
    Primitive(primitive) => Primitive(lower_primitive_type(primitive))
    Constructor(symbol) => Constructor(self.type_id(symbol))
    Apply(callee, arguments) =>
      Apply(
        self.lower_type(callee),
        arguments.map(fn(argument) { self.lower_type(argument) }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(parameter) {
          self.define_type_parameter(parameter.id)
        }),
        self.lower_type(body),
      )
    Parameter(parameter) => Parameter(self.type_parameter_id(parameter))
    Function(parameters, result) =>
      Function(
        parameters.map(fn(parameter) { self.lower_type(parameter) }),
        self.lower_type(result),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(fn(parameter) {
          self.define_type_parameter(parameter.id)
        }),
        self.lower_type(body),
      )
  }
}

///|
fn BuslaneLowerer::nominal_type_arguments(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> Array[@buslane.Type] {
  match type_.decompose_nominal() {
    Some((_, arguments)) =>
      arguments.map(fn(argument) { self.lower_type(argument) })
    None => []
  }
}

///|
fn buslane_nominal_type(
  symbol : @buslane.TypeId,
  arguments : Array[@buslane.Type],
) -> @buslane.Type {
  if arguments.is_empty() {
    Constructor(symbol)
  } else {
    Apply(Constructor(symbol), arguments)
  }
}

///|
fn lower_primitive_type(
  primitive : @types.PrimitiveType,
) -> @buslane.PrimitiveType {
  match primitive {
    Int => Int
    Bool => Bool
    String => String
    Unit => Unit
  }
}

///|
fn BuslaneLowerer::define_external(
  self : BuslaneLowerer,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  let id = self.metadata.define_value(External, type_)
  self.external_terms.push(External(id))
  id
}

///|
fn BuslaneLowerer::define_builtin_external(
  self : BuslaneLowerer,
  name : String,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  let value = self.define_external(type_)
  self.builtin_externals.push({ value, name, type_ })
  value
}

///|
fn BuslaneLowerer::define_fresh_value(
  self : BuslaneLowerer,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  self.metadata.define_value(kind, type_)
}

///|
fn BuslaneLowerer::define_value(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  for entry in self.values {
    if entry.source == source {
      return entry.target
    }
  }
  let target = self.metadata.define_value(kind, type_)
  self.values.push({ source, target })
  target
}

///|
fn BuslaneLowerer::define_type_parameter(
  self : BuslaneLowerer,
  source : @symbol.TypeParameterId,
) -> @buslane.TypeParameterId {
  for entry in self.type_parameters {
    if entry.source == source {
      return entry.target
    }
  }
  let target = self.metadata.define_type_parameter(Type)
  self.type_parameters.push({ source, target })
  target
}

///|
fn BuslaneLowerer::type_id(
  self : BuslaneLowerer,
  source : @symbol.TypeSymbolId,
) -> @buslane.TypeId {
  for entry in self.type_symbols {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane type id")
}

///|
fn BuslaneLowerer::type_parameter_id(
  self : BuslaneLowerer,
  source : @symbol.TypeParameterId,
) -> @buslane.TypeParameterId {
  self.define_type_parameter(source)
}

///|
fn BuslaneLowerer::value_id(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
) -> @buslane.ValueId {
  for entry in self.values {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane value id")
}

///|
fn BuslaneLowerer::data_constructor_id(
  self : BuslaneLowerer,
  source : @symbol.VariantSymbolId,
) -> @buslane.DataConId {
  for entry in self.data_constructors {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane data constructor id")
}

///|
fn BuslaneLowerer::struct_constructor_id(
  self : BuslaneLowerer,
  source : @symbol.TypeSymbolId,
) -> @buslane.DataConId {
  for entry in self.struct_constructors {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane struct constructor id")
}

///|
fn BuslaneLowerer::field_selector_id(
  self : BuslaneLowerer,
  source : @symbol.FieldSymbolId,
) -> @buslane.ValueId {
  for entry in self.field_selectors {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane field selector id")
}
