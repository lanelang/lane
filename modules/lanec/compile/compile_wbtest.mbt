///|
fn mini_prelude() -> String {
  (
    #|struct Add[T] {
    #|  add : (T, T) -> T
    #|}
    #|
    #|fn[T] op_add(a : T, b : T, auto op : Add[T]) -> T {
    #|  op.add(a, b)
    #|}
    #|
    #|fn int_add(a : Int, b : Int) -> Int {
    #|  builtin("%i64_add")(a, b)
    #|}
    #|
    #|offer int_add_ops : Add[Int] = Add::{ add: int_add }
  )
}

///|
test "compile with prelude records builtin externals and entries" {
  let result = compile_with_prelude(
    mini_prelude(),
    (
      #|let answer : Int = 1 + 2
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.externals.builtins.length(), content="1")
  inspect(result.externals.builtins[0].name, content="%i64_add")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="op_add,int_add,int_add_ops,answer",
  )
  guard result.program is Some(_) else { abort("expected Buslane program") }
}

///|
test "check reports payloadless variant call" {
  let result = check_with_prelude(
    "",
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|let value : Option[Int] = none()
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="payloadless_variant_call none",
  )
}
