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
    expand_source(file).value_type_presentations,
    content=(
      #|[
      #|  {
      #|    loc: {
      #|      start_offset: 12,
      #|      end_offset: 74,
      #|      start_line: 2,
      #|      start_column: 1,
      #|      end_line: 4,
      #|      end_column: 2,
      #|    },
      #|    tuple_presentations: [{ path: [FunctionResult], item_count: 2 }],
      #|  },
      #|]
    ),
  )
}

///|
test "surface expansion records structural tuple presentation paths" {
  let result = @parser.parse_string(
    (
      #|module Test
      #|fn nested(value : (Int, (Bool, String))) -> (Basic.Data.Tuple.Tuple[Int, Bool], String) {
      #|  value
      #|}
      #|fn generic(value : Box[(Int, Bool)]) -> Int {
      #|  0
      #|}
      #|fn effectful() -> Unit ! { E[(Int, Bool)], F[(String, Bool)] } {
      #|  ()
      #|}
    ),
  )
  guard result.syntax() is Some(file) else { abort("expected parsed source") }
  debug_inspect(
    expand_source(file).value_type_presentations.map(fn(presentation) {
      presentation.tuple_presentations
    }),
    content=(
      #|[
      #|  [
      #|    { path: [FunctionParameter(0)], item_count: 3 },
      #|    { path: [FunctionResult], item_count: 2 },
      #|  ],
      #|  [
      #|    {
      #|      path: [FunctionParameter(0), TypeApplicationArgument(0)],
      #|      item_count: 2,
      #|    },
      #|  ],
      #|  [
      #|    {
      #|      path: [
      #|        FunctionEffect,
      #|        EffectUnionItem(0),
      #|        EffectTerm,
      #|        TypeApplicationArgument(0),
      #|      ],
      #|      item_count: 2,
      #|    },
      #|    {
      #|      path: [
      #|        FunctionEffect,
      #|        EffectUnionItem(1),
      #|        EffectTerm,
      #|        TypeApplicationArgument(0),
      #|      ],
      #|      item_count: 2,
      #|    },
      #|  ],
      #|]
    ),
  )
}
