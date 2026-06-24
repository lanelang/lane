///|
fn loc() -> SourceSpan {
  SourceSpan::dummy()
}

///|
fn int_type() -> @types.Type {
  Primitive(Int)
}

///|
fn bool_type() -> @types.Type {
  Primitive(Bool)
}

///|
fn function_type(
  parameters : Array[@types.Type],
  result : @types.Type,
) -> @types.Type {
  Function(parameters, result)
}

///|
test "pretty prints checked source without surface-only syntax" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let x = registry.define_value("x", LocalBinding, loc())
  let increment = registry.define_value("increment", TopLevelFunction, loc())
  let answer = registry.define_value("answer", TopLevelValue, loc())
  let value = CheckedExpr::Value(
    name="x",
    symbol=x,
    type_=int_type(),
    loc=loc(),
  )
  let callee = CheckedExpr::Value(
    name="increment",
    symbol=increment,
    type_=function_type([int_type()], int_type()),
    loc=loc(),
  )
  let call = CheckedExpr::Call(
    callee~,
    arguments=[value],
    type_=int_type(),
    loc=loc(),
  )
  let source = CheckedSourceFile::{
    module_path: @syntax.ModulePath::{ components: ["Test"], loc: loc() },
    declarations: [
      Let({
        is_public: true,
        symbol: answer,
        name: Some("answer"),
        initializer: call,
        type_: int_type(),
        loc: loc(),
      }),
    ],
    loc: loc(),
  }
  inspect(
    @prettyprinter.render(source),
    content=(
      #|checked {
      #|  let answer#2 : Int = increment#1(x#0)
      #|}
    ),
  )
}

///|
test "pretty prints checked thunked short circuit call shape" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let op_and_symbol = registry.define_value("op_and", TopLevelValue, loc())
  let op_and_type = function_type(
    [bool_type(), function_type([], bool_type())],
    bool_type(),
  )
  let op_and = CheckedExpr::Value(
    name="op_and",
    symbol=op_and_symbol,
    type_=op_and_type,
    loc=loc(),
  )
  let left = CheckedExpr::Literal(
    literal=Bool(true),
    type_=bool_type(),
    loc=loc(),
  )
  let right = CheckedExpr::Literal(
    literal=Bool(false),
    type_=bool_type(),
    loc=loc(),
  )
  let thunk = CheckedExpr::FunctionLiteral(
    type_parameters=[],
    parameters=[],
    return_type=bool_type(),
    body=right,
    type_=function_type([], bool_type()),
    loc=loc(),
  )
  let call = CheckedExpr::Call(
    callee=op_and,
    arguments=[left, thunk],
    type_=bool_type(),
    loc=loc(),
  )
  inspect(
    @prettyprinter.render(call),
    content=(
      #|op_and#0(true, fn() -> Bool {
      #|  false
      #|}) : Bool
    ),
  )
}

///|
test "pretty prints checked match with resolved patterns" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let option = registry.define_type("Option", Enum, 1, loc())
  let box = registry.define_type("Box", Struct, 1, loc())
  let some = registry.define_variant(option, "some", 0, 1, loc())
  let field = registry.define_field(box, "value", 0, loc())
  let binder = registry.define_value("x", PatternBinder, loc())
  let scrutinee = registry.define_value("value", Parameter, loc())
  let box_int = @types.nominal_type(box, [int_type()])
  let option_box = @types.nominal_type(option, [box_int])
  let pattern = CheckedPattern::Variant(
    symbol=some,
    type_arguments=[],
    arguments=[
      Struct(
        symbol=box,
        type_binders=[],
        fields=[
          {
            symbol: field,
            name: "value",
            pattern: Binding(
              name="x",
              symbol=binder,
              type_=int_type(),
              loc=loc(),
            ),
            loc: loc(),
          },
        ],
        type_=box_int,
        loc=loc(),
      ),
    ],
    type_=option_box,
    loc=loc(),
  )
  let arm = CheckedMatchArm::{
    pattern,
    body: Value(name="x", symbol=binder, type_=int_type(), loc=loc()),
    loc: loc(),
  }
  let match_expr = CheckedExpr::Match(
    scrutinee=Value(name="value", symbol=scrutinee, type_=option_box, loc=loc()),
    arms=[arm],
    type_=int_type(),
    loc=loc(),
  )
  inspect(
    @prettyprinter.render(match_expr),
    content=(
      #|match value#1 {
      #|  variant#0(type#1::{
      #|    value#0: x#0
      #|  }) => x#0
      #|} : Int
    ),
  )
}
