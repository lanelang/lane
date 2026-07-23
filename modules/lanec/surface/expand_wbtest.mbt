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

///|
test "surface expansion records authored sugar provenance" {
  let result = @parser.parse_string(
    (
      #|module Test
      #|type Pair = (Int, Bool)
      #|fn make() -> (Int, Bool) {
      #|  [(1, true)]
      #|}
      #|fn first(value : (Int, Bool)) -> Int {
      #|  match value {
      #|    (head, _) => head
      #|  }
      #|}
    ),
  )
  guard result.syntax() is Some(file) else { abort("expected parsed source") }
  debug_inspect(
    expand_source(file).presentations,
    content=(
      #|[
      #|  TupleType(
      #|    {
      #|      start_offset: 24,
      #|      end_offset: 35,
      #|      start_line: 2,
      #|      start_column: 13,
      #|      end_line: 2,
      #|      end_column: 24,
      #|    },
      #|  ),
      #|  ValueType(
      #|    loc={
      #|      start_offset: 36,
      #|      end_offset: 78,
      #|      start_line: 3,
      #|      start_column: 1,
      #|      end_line: 5,
      #|      end_column: 2,
      #|    },
      #|    text="() -> (Int, Bool)",
      #|  ),
      #|  TupleType(
      #|    {
      #|      start_offset: 49,
      #|      end_offset: 60,
      #|      start_line: 3,
      #|      start_column: 14,
      #|      end_line: 3,
      #|      end_column: 25,
      #|    },
      #|  ),
      #|  ListExpression(
      #|    {
      #|      start_offset: 65,
      #|      end_offset: 76,
      #|      start_line: 4,
      #|      start_column: 3,
      #|      end_line: 4,
      #|      end_column: 14,
      #|    },
      #|  ),
      #|  TupleExpression(
      #|    {
      #|      start_offset: 66,
      #|      end_offset: 75,
      #|      start_line: 4,
      #|      start_column: 4,
      #|      end_line: 4,
      #|      end_column: 13,
      #|    },
      #|  ),
      #|  ValueType(
      #|    loc={
      #|      start_offset: 79,
      #|      end_offset: 161,
      #|      start_line: 6,
      #|      start_column: 1,
      #|      end_line: 10,
      #|      end_column: 2,
      #|    },
      #|    text="((Int, Bool)) -> Int",
      #|  ),
      #|  TupleType(
      #|    {
      #|      start_offset: 96,
      #|      end_offset: 107,
      #|      start_line: 6,
      #|      start_column: 18,
      #|      end_line: 6,
      #|      end_column: 29,
      #|    },
      #|  ),
      #|  TuplePattern(
      #|    {
      #|      start_offset: 138,
      #|      end_offset: 147,
      #|      start_line: 8,
      #|      start_column: 5,
      #|      end_line: 8,
      #|      end_column: 14,
      #|    },
      #|  ),
      #|]
    ),
  )
}

///|
test "surface expansion records value signature presentation only for authored tuple sugar" {
  let result = @parser.parse_string(
    (
      #|module Test
      #|pub fn sugared(value : Int) -> (Int, Bool) {
      #|  (value, true)
      #|}
      #|pub fn explicit(value : Int) -> Basic.Data.Tuple.Tuple[Int, Bool] {
      #|  Basic.Data.Tuple.Tuple::tuple(value, true)
      #|}
    ),
  )
  guard result.syntax() is Some(file) else { abort("expected parsed source") }
  debug_inspect(
    expand_source(file).presentations.filter_map(fn(presentation) {
      match presentation {
        ValueType(loc~, text~) => Some((loc, text))
        _ => None
      }
    }),
    content=(
      #|[
      #|  (
      #|    {
      #|      start_offset: 12,
      #|      end_offset: 74,
      #|      start_line: 2,
      #|      start_column: 1,
      #|      end_line: 4,
      #|      end_column: 2,
      #|    },
      #|    "(Int) -> (Int, Bool)",
      #|  ),
      #|]
    ),
  )
}
