///|
test "typecheck builds checked builtin from direct expected type" {
  let expression = expect_checked_let_initializer(
    (
      #|let i64_add : (I64, I64) -> I64 = builtin("%i64_add")
    ),
    "i64_add",
    Function([Primitive(I64), Primitive(I64)], Primitive(I64), Empty),
  )
  inspect(
    @prettyprinter.render(expression),
    content=(
      #|builtin("%i64_add") : (I64, I64) -> I64
    ),
  )
}

///|
test "typecheck builds checked builtin call from expected result" {
  let expression = expect_checked_let_initializer(
    (
      #|let sum : I64 = builtin("%i64_add")(1, 2)
    ),
    "sum",
    Primitive(I64),
  )
  inspect(
    @prettyprinter.render(expression),
    content=(
      #|builtin("%i64_add")(1, 2) : I64
    ),
  )
}

///|
test "typecheck builtin primitive operation fragment" {
  let result = expect_checked_source_result(
    (
      #|struct Add[T] {
      #|  add : (T, T) -> T
      #|}
      #|
      #|fn[T] op_add(a : T, b : T, auto op : Add[T]) -> T {
      #|  op.add(a, b)
      #|}
      #|
      #|fn i64_add(a : I64, b : I64) -> I64 {
      #|  builtin("%i64_add")(a, b)
      #|}
      #|
      #|offer i64_add_ops : Add[I64] = Add::{ add: i64_add }
      #|
      #|let sum : I64 = op_add(1, 2)
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(_) else {
    abort("expected checked builtin fragment")
  }
}

///|
test "typecheck parses checked int literal as i64 value" {
  let expression = expect_checked_let_initializer(
    (
      #|let answer : I64 = 042
    ),
    "answer",
    Primitive(I64),
  )
  guard expression is Literal(literal=I64(literal), ..) else {
    abort("expected checked int literal")
  }
  @test.assert_eq(literal.raw, "042")
  @test.assert_eq(literal.value, 42L)
}

///|
test "typecheck reports out of range int literal" {
  let result = expect_typecheck_result(
    (
      #|let bad : I64 = 9223372036854775808
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[invalid_i64_literal 9223372036854775808 @ 2:17-2:36]
    ),
  )
}

///|
test "typecheck inserts contextual auto argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let answer : I64 = 1 + 2
    ),
    "answer",
    Primitive(I64),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_add#0[I64](1, 2, i64_add_ops#1) : I64
    ),
  )
}

///|
test "typecheck accepts explicit named contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let custom_add : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let answer : I64 = op_add(1, 2, op=custom_add)
    ),
    "answer",
    Primitive(I64),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_add#0[I64](1, 2, custom_add#1) : I64
    ),
  )
}

///|
test "typecheck offer value declaration supplies contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let answer : I64 = 1 + 2
    ),
    "answer",
    Primitive(I64),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_add#0[I64](1, 2, i64_add_ops#1) : I64
    ),
  )
}

///|
test "typecheck offered function supplies contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|fn call(auto provider : () -> I64) -> I64 {
      #|  provider()
      #|}
      #|offer fn provide() -> I64 {
      #|  42
      #|}
      #|let answer : I64 = call()
    ),
    "answer",
    Primitive(I64),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|call#0(provide#1) : I64
    ),
  )
}

///|
test "typecheck inner offered function shadows same-named outer offer" {
  let result = expect_typecheck_result(
    (
      #|fn consume(auto provider : () -> I64) -> I64 {
      #|  provider()
      #|}
      #|offer fn provider() -> I64 {
      #|  1
      #|}
      #|let answer : I64 = {
      #|  offer fn provider() -> I64 {
      #|    2
      #|  }
      #|  consume()
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "contextual offers do not share a fallback name" {
  let offers = ContextualOfferScope()
  offers.bind(
    contextual_offer(
      { index: 0 },
      "first",
      Primitive(I64),
      None,
      @basic.SourceSpan::dummy(),
    ),
  )
  offers.bind(
    contextual_offer(
      { index: 1 },
      "second",
      Primitive(Bool),
      None,
      @basic.SourceSpan::dummy(),
    ),
  )
  let visible : Array[ContextualOffer] = []
  offers.each_visible(fn(offer) { visible.push(offer) })
  debug_inspect(
    visible.map(fn(offer) { (offer.name, offer.symbol) }),
    content="[(\"first\", { index: 0 }), (\"second\", { index: 1 })]",
  )
}

///|
test "typecheck inner ordinary binding hides same-named outer offer" {
  let result = expect_typecheck_result(
    (
      #|fn consume(auto provider : () -> I64) -> I64 {
      #|  provider()
      #|}
      #|offer fn provider() -> I64 {
      #|  1
      #|}
      #|let answer : I64 = {
      #|  fn provider() -> I64 {
      #|    2
      #|  }
      #|  consume()
      #|}
    ),
  )
  guard result.diagnostics
    is [{ kind: MissingContextualOffer(expected~, ..), .. }] else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  assert_eq(expected, Function([], Primitive(I64), Empty))
}

///|
test "typecheck applies offer shadowing before contextual type matching" {
  let result = expect_typecheck_result(
    (
      #|fn consume(auto provider : () -> I64) -> I64 {
      #|  provider()
      #|}
      #|offer fn provider() -> I64 {
      #|  1
      #|}
      #|let answer : I64 = {
      #|  offer fn provider() -> Bool {
      #|    true
      #|  }
      #|  consume()
      #|}
    ),
  )
  guard result.diagnostics
    is [{ kind: MissingContextualOffer(expected~, ..), .. }] else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  assert_eq(expected, Function([], Primitive(I64), Empty))
}

///|
test "typecheck restores outer offer after leaving lexical scope" {
  let result = expect_typecheck_result(
    (
      #|fn consume_int(auto provider : () -> I64) -> I64 {
      #|  provider()
      #|}
      #|fn consume_bool(auto provider : () -> Bool) -> Bool {
      #|  provider()
      #|}
      #|offer fn provider() -> I64 {
      #|  1
      #|}
      #|let answer : I64 = {
      #|  let inner : Bool = {
      #|    offer fn provider() -> Bool {
      #|      true
      #|    }
      #|    consume_bool()
      #|  }
      #|  consume_int()
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck offered function follows recursive and ordered scopes" {
  let result = expect_typecheck_result(
    (
      #|fn accept_top(auto provider : () -> I64) -> Unit {
      #|  ()
      #|}
      #|fn before() -> Unit {
      #|  accept_top()
      #|}
      #|offer fn provide() -> I64 {
      #|  accept_top()
      #|  42
      #|}
      #|fn accept_local(auto transform : (I64) -> I64) -> Unit {
      #|  ()
      #|}
      #|let answer : I64 = {
      #|  offer fn local(value : I64) -> I64 {
      #|    accept_local()
      #|    value
      #|  }
      #|  accept_local()
      #|  local(42)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck does not specialize a generic offered function" {
  let result = expect_typecheck_result(
    (
      #|fn use_mono(auto transform : (I64) -> I64) -> I64 {
      #|  transform(1)
      #|}
      #|offer fn[A] identity(value : A) -> A {
      #|  value
      #|}
      #|let answer : I64 = use_mono()
    ),
  )
  guard result.diagnostics
    is [{ kind: MissingContextualOffer(expected~, ..), .. }] else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  assert_eq(expected, Function([Primitive(I64)], Primitive(I64), Empty))
}

///|
test "typecheck matches a generic offered function by its forall type" {
  let result = expect_typecheck_result(
    (
      #|fn use_poly(auto transform : [A](A) -> A) -> I64 {
      #|  transform[I64](1)
      #|}
      #|offer fn[A] identity(value : A) -> A {
      #|  value
      #|}
      #|let answer : I64 = use_poly()
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck auto offer parameter is visible in function body" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|fn[A] twice(x : A, auto offer op : Add[A]) -> A {
      #|  x + x
      #|}
      #|offer i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let answer : I64 = twice(1)
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Add#0[A#0 : Type] {
      #|        add#0 : (tparam#0, tparam#0) -> tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      add#0 : (tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : forall [tparam#1 A : Type]. (tparam#1, tparam#1, type#0[tparam#1]) -> tparam#1
      #|    fn twice#1 : forall [tparam#2 A : Type]. (tparam#2, type#0[tparam#2]) -> tparam#2
      #|    let i64_add_ops#2 : type#0[I64]
      #|    let answer#3 : I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck compare offer does not derive equal offer" {
  let result = expect_typecheck_result(
    (
      #|struct Equal[A] {
      #|  equal : (A, A) -> Bool
      #|}
      #|struct Compare[A] {
      #|  equal_impl : Equal[A]
      #|}
      #|fn[A] op_equal(a : A, b : A, auto op : Equal[A]) -> Bool {
      #|  op.equal(a, b)
      #|}
      #|offer i64_compare_ops : Compare[I64] = Compare::{ equal_impl: Equal::{ equal: fn(a : I64, b : I64) -> Bool { builtin("%i64_equal")(a, b) } } }
      #|let answer : Bool = 1 == 2
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_contextual_offer type#0[I64] auto_parameter=op @ 12:21-12:27]
    ),
  )
}

///|
test "typecheck local offer value declaration supplies contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let answer : I64 = {
      #|  offer i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|  1 + 2
      #|}
    ),
    "answer",
    Primitive(I64),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|{
      #|  let i64_add_ops#5 : type#0[I64] = type#0[I64]::{
      #|    add#0: fn(a#6 : I64, b#7 : I64) -> I64 {
      #|      builtin("%i64_add")(a#6, b#7)
      #|    }
      #|  }
      #|  op_add#0[I64](1, 2, i64_add_ops#5)
      #|} : I64
    ),
  )
}

///|
test "typecheck reports missing contextual offer" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let answer : I64 = 1 + 2
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Add#0[A#0 : Type] {
      #|        add#0 : (tparam#0, tparam#0) -> tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      add#0 : (tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : forall [tparam#1 A : Type]. (tparam#1, tparam#1, type#0[tparam#1]) -> tparam#1
      #|    let answer#1 : I64
      #|  }
      #|  diagnostics {
      #|    missing_contextual_offer type#0[I64] auto_parameter=op @ 8:20-8:25
      #|  }
      #|}
    ),
  )
}

///|
test "typecheck reports ambiguous contextual offer" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer add_a : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|offer add_b : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_sub")(a, b) } }
      #|let answer : I64 = 1 + 2
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Add#0[A#0 : Type] {
      #|        add#0 : (tparam#0, tparam#0) -> tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      add#0 : (tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : forall [tparam#1 A : Type]. (tparam#1, tparam#1, type#0[tparam#1]) -> tparam#1
      #|    let add_a#1 : type#0[I64]
      #|    let add_b#2 : type#0[I64]
      #|    let answer#3 : I64
      #|  }
      #|  diagnostics {
      #|    ambiguous_contextual_offer type#0[I64] auto_parameter=op candidates=[add_a, add_b] @ 10:20-10:25
      #|  }
      #|}
    ),
  )
}

///|
test "typecheck reports non-trailing auto parameter" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn bad(a : I64, auto op : Add[I64], b : I64) -> I64 {
      #|  a
      #|}
      #|let answer : I64 = bad(1, 2)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[auto_parameters_must_be_trailing @ 8:20-8:29]
    ),
  )
}

///|
test "typecheck reports positional auto argument" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let custom : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let answer : I64 = op_add(1, 2, custom)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[auto_argument_must_be_named @ 9:33-9:39]
    ),
  )
}

///|
test "typecheck reports duplicate named contextual argument" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let custom : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
      #|let answer : I64 = op_add(1, 2, op=custom, op=custom)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[duplicate_named_argument op @ 9:44-9:53]
    ),
  )
}

///|
test "typecheck reports invalid named argument for ordinary call" {
  let result = expect_typecheck_result(
    (
      #|fn id(value : I64) -> I64 {
      #|  value
      #|}
      #|let answer : I64 = id(value=1)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[invalid_named_argument value @ 5:23-5:30]
    ),
  )
}

///|
test "typecheck local bindings are sequential and local functions see prior scope" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> I64 {
      #|  {
      #|    let base = 1
      #|    fn local(value : I64) -> I64 {
      #|      base
      #|    }
      #|    local(2)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck local function can call itself after declaration" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> I64 {
      #|  {
      #|    fn loop(value : I64) -> I64 {
      #|      loop(value)
      #|    }
      #|    loop(1)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports local function forward reference" {
  let file = expect_parse_ok(
    (
      #|fn use() -> I64 {
      #|  {
      #|    let result = local(1)
      #|    fn local(value : I64) -> I64 {
      #|      value
      #|    }
      #|    result
      #|  }
      #|}
    ),
  )
  let resolution = @resolve.resolve_source_file_result(file)
  debug_inspect(
    resolution.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: UnresolvedValue("local"),
      #|    loc: {
      #|      start_offset: 51,
      #|      end_offset: 59,
      #|      start_line: 4,
      #|      start_column: 18,
      #|      end_line: 4,
      #|      end_column: 26,
      #|    },
      #|  },
      #|]
    ),
  )
  let result = typecheck_source_file(resolution.source)
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unresolved_value local @ 4:18-4:23, internal_typecheck_failure checked call callee @ 4:18-4:23]
    ),
  )
}

///|
test "typecheck local generic function after declaration" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> I64 {
      #|  {
      #|    fn[A] id(value : A) -> A {
      #|      value
      #|    }
      #|    id(1)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck direct binary operator alias" {
  let result = expect_typecheck_result(
    (
      #|fn op_add(a : I64, b : I64) -> I64 {
      #|  a
      #|}
      #|fn use() -> I64 {
      #|  1 + 2
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : (I64, I64) -> I64
      #|    fn use#1 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck direct binary operator result mismatch" {
  let result = expect_typecheck_result(
    (
      #|fn op_add(a : I64, b : I64) -> Bool {
      #|  true
      #|}
      #|fn use() -> I64 {
      #|  1 + 2
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=I64 actual=Bool @ 6:3-6:8]
    ),
  )
}

///|
test "typecheck direct unary operator alias" {
  let result = expect_typecheck_result(
    (
      #|fn op_neg(value : I64) -> I64 {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  -1
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_neg#0 : (I64) -> I64
      #|    fn use#1 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck function literal parameters from expected function type" {
  let result = expect_typecheck_result(
    (
      #|fn apply(callback : (I64) -> I64) -> I64 {
      #|  callback(1)
      #|}
      #|fn use() -> I64 {
      #|  apply(fn(value) {
      #|    value
      #|  })
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn apply#0 : ((I64) -> I64) -> I64
      #|    fn use#1 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck checked function literal parameters from expected function type" {
  let result = expect_checked_source_result(
    (
      #|let id : (I64) -> I64 = fn(value) {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    let id#0 : (I64) -> I64 = fn(value#2 : I64) -> I64 {
      #|      value#2
      #|    }
      #|    fn use#1() -> I64 {
      #|      id#0(1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck pipeline expression as first argument call" {
  let result = expect_typecheck_result(
    (
      #|fn first(a : I64, b : I64) -> I64 {
      #|  a
      #|}
      #|fn use() -> I64 {
      #|  1 |> first(2)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn first#0 : (I64, I64) -> I64
      #|    fn use#1 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck pipeline expression into function literal" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> I64 {
      #|  1 |> fn(value : I64) {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck generic function literal parameters from expected forall type" {
  let result = expect_typecheck_result(
    (
      #|let id : [A](A) -> A = fn[A](value) {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#1 : () -> I64
      #|    let id#0 : forall [tparam#0 A : Type]. (tparam#0) -> tparam#0
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck checked generic function literal parameters from expected forall type" {
  let result = expect_checked_source_result(
    (
      #|let id : [A](A) -> A = fn[A](value) {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    let id#0 : forall [tparam#0 A : Type]. (tparam#0) -> tparam#0 = fn[A#1 : Type](value#2 : tparam#1) -> tparam#1 {
      #|      value#2
      #|    }
      #|    fn use#1() -> I64 {
      #|      id#0[I64](1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck generic function literal binder kinds against expected forall" {
  let result = expect_typecheck_result(
    (
      #|let action : [E : Effect]() -> Unit ! E = fn[T]() {
      #|  ()
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Effect, actual=Type),
      #|    loc: {
      #|      start_offset: 57,
      #|      end_offset: 58,
      #|      start_line: 2,
      #|      start_column: 46,
      #|      end_line: 2,
      #|      end_column: 47,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck reports generic function literal arity mismatch" {
  let result = expect_typecheck_result(
    (
      #|let id : [A](A) -> A = fn(value) {
      #|  value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[application_arity_mismatch generic function arity @ 2:24-4:2]
    ),
  )
}

///|
test "typecheck reports generic literal against non-generic function type" {
  let result = expect_typecheck_result(
    (
      #|let id : (I64) -> I64 = fn[A](value : A) -> A {
      #|  value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[application_arity_mismatch generic function arity @ 2:25-4:2]
    ),
  )
}

///|
test "typecheck synthesizes direct generic call from argument type" {
  let result = expect_typecheck_result(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn id#0 : forall [tparam#0 A : Type]. (tparam#0) -> tparam#0
      #|    fn use#1 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck accepts sequential unit expressions" {
  let result = expect_checked_source_result(
    (
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|fn main() -> Unit {
      #|  print("hello");
      #|  print("world")
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(source) else { abort("expected checked source") }
  guard source.declarations[1] is Function(declaration) &&
    declaration.body is Block(items=[Expression(Call(..))], result=Call(..), ..) else {
    abort("expected checked sequential expression")
  }
}

///|
test "typecheck elaborates an omitted else to a zero-width Unit branch" {
  let result = expect_checked_source_result(
    (
      #|fn run(flag : Bool) -> Unit {
      #|  if flag {
      #|    ()
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(source) &&
    source.declarations[0] is Function(declaration) &&
    declaration.body
    is Block(
      result=If(
        else_branch=Literal(literal=Unit, loc=else_loc, ..),
        loc=if_loc,
        ..
      ),
      ..
    ) else {
    abort("expected checked if with a synthetic Unit else branch")
  }
  assert_eq(if_loc.end_offset, else_loc.start_offset)
  assert_eq(else_loc.start_offset, else_loc.end_offset)
}

///|
test "typecheck rejects a value-producing if without else" {
  let result = expect_checked_source_result(
    (
      #|fn choose(flag : Bool) -> I64 {
      #|  if flag {
      #|    1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[else-omitting conditional requires Unit, found I64 @ 4:5-4:6]
    ),
  )
}

///|
test "typecheck aggregates omitted-else mismatches across nested checking" {
  let result = expect_checked_source_result(
    (
      #|fn choose(flag : Bool, branch : Bool) -> I64 {
      #|  if flag {
      #|    match branch {
      #|      true => 1
      #|      false => ()
      #|    }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[else-omitting conditional requires Unit, found I64 @ 5:15-5:16]
    ),
  )
}

///|
test "typecheck propagates an omitted-else mismatch through nested conditionals" {
  let result = expect_checked_source_result(
    (
      #|fn choose(first : Bool, second : Bool) -> I64 {
      #|  if first {
      #|    if second {
      #|      1
      #|    }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[else-omitting conditional requires Unit, found I64 @ 5:7-5:8]
    ),
  )
}

///|
test "typecheck reports the surrounding mismatch for a well-typed omitted else" {
  let result = expect_checked_source_result(
    (
      #|fn choose(flag : Bool) -> I64 {
      #|  if flag {
      #|    ()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=I64 actual=Unit @ 3:3-5:4]
    ),
  )
}

///|
test "typecheck retains then-branch effects when else is omitted" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  log() -> Unit
      #|}
      #|fn run(flag : Bool) -> Unit ! Console {
      #|  if flag {
      #|    Console::log!()
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  assert_true(checked_function_effect(result, "run") is Singleton(_, _))
}

///|
test "typecheck allows declarations between sequential unit expressions" {
  let result = expect_checked_source_result(
    (
      #|fn mark() -> Unit {
      #|  ()
      #|}
      #|fn build() -> I64 {
      #|  mark();
      #|  let answer : I64 = 42
      #|  mark();
      #|  answer
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(source) else { abort("expected checked source") }
  guard source.declarations[1] is Function(declaration) &&
    declaration.body
    is Block(items=[Expression(_), Let(_), Expression(_)], result=Value(..), ..) else {
    abort("expected interleaved sequential expressions")
  }
}

///|
test "typecheck rejects non-unit sequential expressions across separators" {
  for
    source in [
      (
        #|fn bad() -> I64 {
        #|  1;
        #|  2
        #|}
      ),
      (
        #|fn bad() -> I64 {
        #|  1
        #|  2
        #|}
      ),
    ] {
    let result = expect_checked_source_result(source)
    debug_inspect(
      result.diagnostics,
      content=(
        #|[
        #|  {
        #|    kind: TypeMismatch(expected=Primitive(Unit), actual=Primitive(I64)),
        #|    loc: {
        #|      start_offset: 32,
        #|      end_offset: 33,
        #|      start_line: 3,
        #|      start_column: 3,
        #|      end_line: 3,
        #|      end_column: 4,
        #|    },
        #|  },
        #|]
      ),
    )
  }
}
