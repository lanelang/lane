///|
test "function effect widening preserves checked expression contracts" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let location = SourceSpan::dummy()
  let parameter = registry.define_type_parameter("T", location)
  let target = registry.define_value("target", TopLevelFunction, location)
  let widened = registry.define_value("widened", TopLevelValue, location)
  let source_type = @types.Type::Function(
    [Parameter(parameter)],
    Parameter(parameter),
    Empty,
  )
  let widened_type = @types.Type::Function(
    [Parameter(parameter)],
    Parameter(parameter),
    Builtin(Io),
  )
  let value = CheckedExpr::Value(
    name="target",
    symbol=target,
    type_=source_type,
    loc=location,
  )
  let expression = CheckedExpr::FunctionEffectWiden(
    value~,
    type_=widened_type,
    loc=location,
  )

  let children = []
  expression.for_each_child_expr(fn(child) { children.push(child) })
  assert_eq(children, [value])

  let substitution = @types.TypeSubstitution::single(parameter, Primitive(I64))
  assert_eq(
    expression.substitute(substitution),
    FunctionEffectWiden(
      value=Value(
        name="target",
        symbol=target,
        type_=Function([Primitive(I64)], Primitive(I64), Empty),
        loc=location,
      ),
      type_=Function([Primitive(I64)], Primitive(I64), Builtin(Io)),
      loc=location,
    ),
  )

  let source = CheckedSourceFile::{
    module_path: { components: ["Test"], loc: location },
    declarations: [
      Let({
        is_public: false,
        is_offered: false,
        symbol: widened,
        name: "widened",
        name_loc: location,
        initializer: expression,
        type_: widened_type,
        loc: location,
      }),
    ],
    loc: location,
  }
  assert_eq(source.value_use_analysis(registry), {
    binders: [],
    references: [{ target, origin_binder: None, loc: location }],
  })
}
