///|
fn expanded_source(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string("module Test\n" + source)
  guard result.syntax() is Some(file) else { abort("expected parsed source") }
  expand_source(file).source
}

///|
test "surface expansion removes tuple and list sugar" {
  let source = expanded_source(
    (
      #|type Pair = (Int, Bool)
      #|fn make() -> (Basic.Data.List.List[Int], Int, Bool) {
      #|  ([1, 2], (1, true))
      #|}
      #|fn first(value : (Int, Bool, String)) -> Int {
      #|  match value {
      #|    (head, _, _) => head
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(source, width=120),
    content=(
      #|module Test
      #|
      #|type Pair = Basic.Data.Tuple.Tuple[Int, Bool]
      #|
      #|fn make() -> Basic.Data.Tuple.Tuple[Basic.Data.List.List[Int], Basic.Data.Tuple.Tuple[Int, Bool]] {
      #|  Basic.Data.Tuple.Tuple::tuple(
      #|    Basic.Data.List.List::cons(1, Basic.Data.List.List::cons(2, Basic.Data.List.List::empty())),
      #|    Basic.Data.Tuple.Tuple::tuple(1, true)
      #|  )
      #|}
      #|
      #|fn first(value : Basic.Data.Tuple.Tuple[Int, Basic.Data.Tuple.Tuple[Bool, String]]) -> Int {
      #|  match value {
      #|    Basic.Data.Tuple.Tuple::tuple(head, Basic.Data.Tuple.Tuple::tuple(_, _)) => head
      #|  }
      #|}
    ),
  )
}
