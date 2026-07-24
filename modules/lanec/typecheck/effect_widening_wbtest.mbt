///|
test "typecheck accepts pure computation under an effect upper bound" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|fn pure() -> Int {
      #|  42
      #|}
      #|fn declared() -> Int ! Read {
      #|  42
      #|}
      #|fn consume(callback : () -> Int ! Read) -> Int ! Read {
      #|  callback()
      #|}
      #|fn use() -> Int ! Read {
      #|  let direct : () -> Int ! Read = pure
      #|  consume(direct)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck records function effect widening in checked expressions" {
  let expression = expect_checked_let_initializer(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|fn pure() -> Int {
      #|  42
      #|}
      #|let widened : () -> Int ! Read = pure
    ),
    "widened",
    Function([], Primitive(Int), Singleton({ index: 0 }, [])),
  )
  assert_true(
    expression
    is FunctionEffectWiden(
      value=Value(name="pure", type_=Function([], Primitive(Int), Empty), ..),
      ..
    ),
  )
}

///|
test "typecheck widens a narrower effect row" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|effect Write {
      #|  write(Int) -> Unit
      #|}
      #|fn read() -> Int ! Read {
      #|  Read::read!()
      #|}
      #|fn consume(callback : () -> Int ! { Read, Write }) -> Int ! { Read, Write } {
      #|  callback()
      #|}
      #|fn use() -> Int ! { Read, Write } {
      #|  consume(read)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck rejects function effect narrowing" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|fn wide() -> Unit ! { Read, Write } {
      #|  let _read : Unit = Read::read!()
      #|  Write::write!()
      #|}
      #|let narrow : () -> Unit ! Read = wide
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  type_mismatch expected=() -> Unit ! effect#0 actual=() -> Unit ! {effect#0, effect#1} @ 12:34-12:38
      #|]
    ),
  )
}

///|
test "function literal annotation remains its body effect bound" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|fn consume(callback : () -> Unit ! { Read, Write }) -> Unit {
      #|  ()
      #|}
      #|fn use() -> Unit {
      #|  consume(fn() -> Unit ! Read { Write::write!() })
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected=effect#0 actual=effect#1 @ 12:31-12:50]
    ),
  )
}

///|
test "generic effect inference accepts a narrower repeated constraint" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|fn effectful() -> Int ! Read {
      #|  Read::read!()
      #|}
      #|fn pure() -> Int {
      #|  42
      #|}
      #|fn[E : Effect] choose(
      #|  first : () -> Int ! E,
      #|  second : () -> Int ! E
      #|) -> Int ! E {
      #|  let _first : Int = first()
      #|  second()
      #|}
      #|fn use() -> Int ! Read {
      #|  choose(effectful, pure)
      #|}
      #|fn use_reverse() -> Int ! Read {
      #|  choose(pure, effectful)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck effect lower bounds and exact constraints are order independent" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|struct Carrier[E : Effect] {
      #|  value : Int
      #|}
      #|fn callback() -> Unit ! Read {
      #|  Read::read!()
      #|}
      #|fn[E : Effect] lower_first(
      #|  action : () -> Unit ! E,
      #|  carrier : Carrier[{ E }]
      #|) -> Unit {
      #|  ()
      #|}
      #|fn[E : Effect] exact_first(
      #|  carrier : Carrier[{ E }],
      #|  action : () -> Unit ! E
      #|) -> Unit {
      #|  ()
      #|}
      #|fn use(carrier : Carrier[{ Read, Write }]) -> Unit {
      #|  lower_first(callback, carrier)
      #|  exact_first(carrier, callback)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}
