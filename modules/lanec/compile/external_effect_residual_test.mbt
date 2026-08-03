///|
test "forwarded parameterized external effect elaborates" {
  assert_entry_elaborates(
    (
      #|module Main
      #|
      #|extern type Host[E : Effect] : Effect
      #|
      #|struct Runner {
      #|  run : [E : Effect](() -> Unit ! Host[E]) -> Unit ! Host[E]
      #|}
      #|
      #|fn[E : Effect] forward(
      #|  action : () -> Unit ! Host[E]
      #|) -> Unit ! Host[E] {
      #|  action()
      #|}
      #|
      #|pub fn answer() -> Unit {
      #|  let _runner : Runner = Runner::{ run: forward }
      #|  ()
      #|}
    ),
    "answer",
  )
}

///|
test "mixed algebraic and parameterized external effect elaborates" {
  assert_entry_elaborates(
    (
      #|module Main
      #|
      #|effect Local {
      #|  ping() -> Unit
      #|}
      #|
      #|extern type Host[E : Effect] : Effect
      #|
      #|struct Runner {
      #|  run : [E : Effect](() -> Unit ! { Local, Host[E] }) -> Unit ! { Local, Host[E] }
      #|}
      #|
      #|fn[E : Effect] forward(
      #|  action : () -> Unit ! { Local, Host[E] }
      #|) -> Unit ! { Local, Host[E] } {
      #|  action()
      #|}
      #|
      #|pub fn answer() -> Unit {
      #|  let _runner : Runner = Runner::{ run: forward }
      #|  ()
      #|}
    ),
    "answer",
  )
}

///|
test "nested parameterized external effect elaborates" {
  assert_entry_elaborates(
    (
      #|module Main
      #|
      #|extern type Inner[E : Effect] : Effect
      #|extern type Outer[E : Effect] : Effect
      #|
      #|struct Runner {
      #|  run : [E : Effect](() -> Unit ! Outer[Inner[E]]) -> Unit ! Outer[Inner[E]]
      #|}
      #|
      #|fn[E : Effect] forward(
      #|  action : () -> Unit ! Outer[Inner[E]]
      #|) -> Unit ! Outer[Inner[E]] {
      #|  action()
      #|}
      #|
      #|pub fn answer() -> Unit {
      #|  let _runner : Runner = Runner::{ run: forward }
      #|  ()
      #|}
    ),
    "answer",
  )
}
