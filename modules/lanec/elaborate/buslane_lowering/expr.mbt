///|
fn BuslaneLowerer::lower_expr(
  self : BuslaneLowerer,
  expression : @checked.CheckedExpr,
) -> @buslane.Expr {
  match expression {
    Literal(literal~, ..) => Literal(lower_literal(literal))
    Value(symbol~, ..) => Ref(self.value_id(symbol))
    CompilerIntrinsic(intrinsic~, type_~, ..) =>
      Ref(self.define_builtin_external(intrinsic, self.lower_type(type_)))
    ExternBinding(name~, signature~, type_~, ..) =>
      Ref(self.define_runtime_import(name, signature, self.lower_type(type_)))
    ErrorRecovery(_) =>
      abort("invalid checked expression reached Buslane lowering")
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) =>
      self.lower_function_literal(
        type_parameters, parameters, return_type, body,
      )
    GenericApplication(callee~, arguments~, ..) =>
      TypeApply(
        self.lower_expr(callee),
        arguments.map(fn(argument) { self.lower_generic_argument(argument) }),
      )
    Block(items~, result~, ..) => self.lower_items(items, 0, result)
    If(condition~, then_branch~, else_branch~, type_~, ..) =>
      self.lower_if(condition, then_branch, else_branch, type_)
    Match(scrutinee~, arms~, type_~, ..) =>
      self.lower_match(scrutinee, arms, type_)
    Call(callee~, arguments~, ..) =>
      Call(
        self.lower_expr(callee),
        arguments.map(fn(argument) { self.lower_expr(argument.value) }),
      )
    OperationCall(operation~, generic_witnesses~, arguments~, effect~, ..) =>
      Perform({
        operation: self.operation_id(operation),
        effect_arguments: self.perform_type_arguments(effect),
        hidden_witnesses: generic_witnesses.map(fn(witness) {
          self.lower_generic_argument(witness)
        }),
        payloads: arguments.map(fn(argument) { self.lower_expr(argument) }),
      })
    Handler(body~, handlers~, final_branch~, type_~, ..) =>
      self.lower_handler(body, handlers, final_branch, type_)
    Field(base~, field~, ..) => self.lower_field(base, field)
    StructLiteral(symbol~, generic_arguments~, type_witnesses~, fields~, ..) =>
      Construct({
        data_constructor: self.struct_constructor_id(symbol),
        type_arguments: generic_arguments.map(fn(argument) {
          self.lower_generic_argument(argument)
        }),
        hidden_witnesses: type_witnesses.map(fn(witness) {
          TypeArgument(self.lower_type(witness.type_))
        }),
        payloads: fields.map(fn(field) { self.lower_expr(field.value) }),
      })
    Variant(symbol~, generic_arguments~, arguments~, type_~, ..) =>
      Construct({
        data_constructor: self.data_constructor_id(symbol),
        type_arguments: self.nominal_type_arguments(type_),
        hidden_witnesses: generic_arguments.map(fn(argument) {
          self.lower_generic_argument(argument)
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
    ignore(self.define_type_parameter(parameter))
  }
  let lowered_type_parameters = type_parameters.map(fn(parameter) {
    self.type_parameter_id(parameter.id)
  })
  let function = @buslane.Expr::Function({
    parameters: parameters.map(fn(parameter) {
      self.define_value(
        parameter.symbol,
        parameter.name,
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
        let occurrence = match declaration.name {
          Some(name) => name
          None => "let"
        }
        let id = self.define_value(
          declaration.symbol,
          occurrence,
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
          declaration.name,
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
      Expression(expression) => {
        let unused = self.define_fresh_value(
          "sequence",
          Local,
          self.lower_type(expression.type_()),
        )
        Let(
          unused,
          self.lower_expr(expression),
          self.lower_items(items, index + 1, result),
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
  let binder = self.define_fresh_value(
    "condition",
    MatchBinder,
    Primitive(Bool),
  )
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
    "scrutinee",
    MatchBinder,
    self.lower_type(scrutinee.type_()),
  )
  let rows = arms.map(fn(arm) {
    self.define_pattern_binders(arm.pattern)
    { patterns: [arm.pattern], body: self.lower_expr(arm.body) }
  })
  self.lower_pattern_decision(
    [self.lower_expr(scrutinee)],
    [binder],
    rows,
    [scrutinee.type_()],
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
    "match",
    MatchBinder,
    self.lower_type(pattern.type_()),
  )
  self.lower_pattern_decision(
    [initializer],
    [binder],
    [{ patterns: [pattern], body }],
    [pattern.type_()],
    result_type,
  )
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
          arguments.map(fn(argument) { self.lower_generic_argument(argument) }),
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
    Double(literal) => Double(literal.value)
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
        arguments.map(fn(argument) { self.lower_generic_argument(argument) }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(parameter) { self.define_type_parameter(parameter) }),
        self.lower_type(body),
      )
    Parameter(parameter) => Parameter(self.type_parameter_id(parameter))
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) { self.lower_type(parameter) }),
        self.lower_type(result),
        self.lower_effect(effect),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(fn(parameter) { self.define_type_parameter(parameter) }),
        self.lower_type(body),
      )
  }
}

///|
fn BuslaneLowerer::lower_effect(
  self : BuslaneLowerer,
  effect : @types.Effect,
) -> @buslane.Effect {
  match effect {
    Empty => Empty
    Io => Io
    Singleton(symbol, arguments) =>
      Singleton(
        self.effect_id(symbol),
        arguments.map(fn(argument) { self.lower_generic_argument(argument) }),
      )
    Parameter(parameter) => Parameter(self.type_parameter_id(parameter))
    Union(effects) =>
      Union(effects.map(fn(effect) { self.lower_effect(effect) }))
  }
}

///|
fn BuslaneLowerer::lower_generic_argument(
  self : BuslaneLowerer,
  argument : @types.GenericArgument,
) -> @buslane.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(self.lower_type(type_))
    EffectArgument(effect) => EffectArgument(self.lower_effect(effect))
  }
}

///|
fn BuslaneLowerer::lower_type_parameter_argument(
  self : BuslaneLowerer,
  parameter : @types.TypeParameter,
) -> @buslane.GenericArgument {
  match parameter.kind {
    Effect => EffectArgument(Parameter(self.type_parameter_id(parameter.id)))
    Type | Function(_) =>
      TypeArgument(Parameter(self.type_parameter_id(parameter.id)))
  }
}

///|
fn BuslaneLowerer::perform_type_arguments(
  self : BuslaneLowerer,
  effect : @types.Effect,
) -> Array[@buslane.GenericArgument] {
  guard effect is Singleton(_, arguments) else {
    abort("checked effect operation call must carry singleton owner effect")
  }
  arguments.map(fn(argument) { self.lower_generic_argument(argument) })
}

///|
fn BuslaneLowerer::nominal_type_arguments(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> Array[@buslane.GenericArgument] {
  match type_.decompose_nominal() {
    Some((_, arguments)) =>
      arguments.map(fn(argument) { self.lower_generic_argument(argument) })
    None => []
  }
}

///|
fn buslane_nominal_type(
  symbol : @buslane.TypeId,
  arguments : Array[@buslane.GenericArgument],
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
    Double => Double
    Bool => Bool
    String => String
    Unit => Unit
  }
}

///|
fn lower_kind(kind : @types.Kind) -> @buslane.Kind {
  match kind {
    Type => Type
    Effect => Effect
    Function(parameters, result) =>
      Function(parameters.map(lower_kind), lower_kind(result))
  }
}
