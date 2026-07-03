///|
fn test_symbols() -> (TypeSymbolId, TypeParameter, TypeParameter) {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let loc = @basic.SourceSpan::dummy()
  let option = registry.define_type("Option", Struct, 1, loc)
  let a = registry.define_type_parameter("A", loc)
  let b = registry.define_type_parameter("B", loc)
  (option, { id: a, name: "A", kind: Type }, { id: b, name: "B", kind: Type })
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
test "pretty prints checked type objects" {
  let (option, a, _) = test_symbols()
  let type_ = Forall(
    [a],
    Function(
      [nominal_type(option, [Parameter(a.id)]), Primitive(Int)],
      Parameter(a.id),
      Empty,
    ),
  )
  inspect(
    @prettyprinter.render(type_),
    content=(
      #|forall [tparam#0 A : Type]. (type#0[tparam#0], Int) -> tparam#0
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
  let substitution = TypeSubstitution::single(a.id, Primitive(Int))
  let free = Type::Function([Parameter(a.id)], Parameter(b.id), Empty)
  let bound = Forall([a], Function([Parameter(a.id)], Parameter(b.id), Empty))
  inspect(
    @prettyprinter.render(free.substitute(substitution)),
    content="(Int) -> tparam#1",
  )
  inspect(
    @prettyprinter.render(bound.substitute(substitution)),
    content="forall [tparam#0 A : Type]. (tparam#0) -> tparam#1",
  )
}

///|
test "forall equality is alpha-equivalent" {
  let (_, a, b) = test_symbols()
  let left = Forall([a], Function([Parameter(a.id)], Parameter(a.id), Empty))
  let right = Forall([b], Function([Parameter(b.id)], Parameter(b.id), Empty))
  let free_mismatch = Forall(
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
