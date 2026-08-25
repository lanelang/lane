///|
using @types {
  type Effect,
  type Kind,
  type PrimitiveType,
  type Type,
  type TypeParameter,
  type TypeSubstitution,
}

///|
using @symbol {type EffectSymbolId, type TypeSymbolId}

///|
fn test_symbols() -> (TypeSymbolId, TypeParameter, TypeParameter) {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let loc = @basic.SourceSpan::dummy()
  let option = registry.define_type("Option", Struct, 1, loc)
  let a = registry.define_type_parameter("A", loc)
  let b = registry.define_type_parameter("B", loc)
  (option, { id: a, name: "A", kind: Type, }, { id: b, name: "B", kind: Type, })
}

///|
fn assert_type_equal(actual : Type, expected : Type) -> Unit {
  if actual != expected {
    abort(
      "expected equal types\nactual:\n" +
      @prettyprinter.render(actual, width=100) +
      "\nexpected:\n" +
      @prettyprinter.render(expected, width=100),
    )
  }
}

///|
test "numeric primitive lookup uses the new source names exclusively" {
  assert_eq(
    [
      PrimitiveType::from_name("I64"),
      PrimitiveType::from_name("I32"),
      PrimitiveType::from_name("F64"),
      PrimitiveType::from_name("Int"),
      PrimitiveType::from_name("S32"),
      PrimitiveType::from_name("Double"),
    ],
    [Some(I64), Some(I32), Some(F64), None, None, None],
  )
}

///|
test "pretty prints checked type objects" {
  let (option, a, _) = test_symbols()
  let type_ = Type::Forall(
    [a],
    Function(
      [nominal_type(option, [Parameter(a.id)]), Primitive(I64)],
      Parameter(a.id),
      Empty,
    ),
  )
  inspect(
    @prettyprinter.render(type_),
    content=(
      #|forall [tparam#0 A : Type]. (type#0[tparam#0], I64) -> tparam#0
    ),
  )
}

///|
test "pretty prints arrow kinds" {
  inspect(
    @prettyprinter.render(Kind::Function([Type], Type)),
    content="[Type] -> Type",
  )
}

///|
test "substitutes free type parameters but not forall-bound parameters" {
  let (_, a, b) = test_symbols()
  let substitution = TypeSubstitution::single(a.id, Primitive(I64))
  let free = Type::Function([Parameter(a.id)], Parameter(b.id), Empty)
  let bound = Type::Forall(
    [a],
    Function([Parameter(a.id)], Parameter(b.id), Empty),
  )
  inspect(
    @prettyprinter.render(free.substitute(substitution)),
    content="(I64) -> tparam#1",
  )
  inspect(
    @prettyprinter.render(bound.substitute(substitution)),
    content="forall [tparam#0 A : Type]. (tparam#0) -> tparam#1",
  )
}

///|
test "forall equality is alpha-equivalent" {
  let (_, a, b) = test_symbols()
  let left = Type::Forall(
    [a],
    Function([Parameter(a.id)], Parameter(a.id), Empty),
  )
  let right = Type::Forall(
    [b],
    Function([Parameter(b.id)], Parameter(b.id), Empty),
  )
  let free_mismatch = Type::Forall(
    [a],
    Function([Parameter(a.id)], Parameter(b.id), Empty),
  )
  assert_true(left.alpha_equal(right))
  assert_type_equal(left, right)
  assert_false(left.alpha_equal(free_mismatch))
  assert_false(left == free_mismatch)
}

///|
test "pretty prints effectful function type" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let console = registry.define_effect("Console", 0, @basic.SourceSpan::dummy())
  let type_ = Type::Function([], Primitive(Unit), Singleton(console, []))
  inspect(@prettyprinter.render(type_), content="() -> Unit ! effect#0")
}

///|
test "built-in effect atoms canonicalize independently" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let parameter_id = registry.define_type_parameter(
    "E",
    @basic.SourceSpan::dummy(),
  )
  let parameter = TypeParameter::{ id: parameter_id, name: "E", kind: Effect, }
  let effect = Effect::Union([
    Builtin(Io),
    Builtin(Panic),
    Empty,
    Builtin(Io),
    Parameter(parameter.id),
  ])
  assert_eq(
    effect.canonicalize(),
    Union([Builtin(Io), Builtin(Panic), Parameter(parameter.id)]),
  )
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert_effect(parameter.id, Builtin(Io))
  assert_eq(
    effect.substitute(substitution).canonicalize(),
    Union([Builtin(Io), Builtin(Panic)]),
  )
  assert_false(Effect::Builtin(Io) == Empty)
  assert_false(Effect::Builtin(Io) == Builtin(Panic))
}

///|
test "effect containment is independent from effect equality" {
  let first = EffectSymbolId::{ index: 0, }
  let second = EffectSymbolId::{ index: 1, }
  let narrow = Effect::Singleton(first, [])
  let wide = Effect::Union([Singleton(first, []), Singleton(second, [])])
  assert_true(Effect::Empty.alpha_subeffect_of(narrow))
  assert_true(narrow.alpha_subeffect_of(wide))
  assert_false(wide.alpha_subeffect_of(narrow))
  assert_false(narrow.alpha_equal(wide))
}

///|
test "decompose nominal evaluates type-level computation" {
  let (option, parameter, _) = test_symbols()
  let type_ = Type::Apply(TypeLambda([parameter], Parameter(parameter.id)), [
    TypeArgument(Constructor(option)),
  ])
  assert_eq(type_.decompose_nominal(), Some((option, [])))
}
