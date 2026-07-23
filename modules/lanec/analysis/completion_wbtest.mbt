///|
fn complete_test_source_inputs(
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([root_source] + library_sources)
    is Some(snapshot) else {
    return []
  }
  snapshot.complete(source_id, line, column, trigger)
}

///|
fn analyze_test_sources(
  root : String,
  libraries : Array[String],
) -> AnalysisResult {
  let library_inputs : Array[@module_frontend.SourceInput] = []
  for index, source in libraries {
    library_inputs.push({ source_id: "<library:\{index}>", text: source })
  }
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources(
      [{ source_id: "<root>", text: root }] + library_inputs,
    )
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  snapshot.analysis()
}

///|
test "completion source indexes parser tokens and line positions" {
  let text = "module Main\r\nimport Lib\r\n\r\npub fn answer(seed : Int) -> Int {\r\n  ans\r\n}"
  let parsed = @module_frontend.parse_module_inputs(
    { source_id: "file:///Main.lane", text },
    [],
  )
  guard parsed.modules.get(0) is Some(input) else {
    abort("expected parsed completion source")
  }
  let source = CompletionSource::from_input(input)
  let cursor = source.offset(5, 6)
  assert_eq(cursor, 68)
  assert_eq(source.span(65, cursor), {
    start_offset: 65,
    end_offset: 68,
    start_line: 5,
    start_column: 3,
    end_line: 5,
    end_column: 6,
  })
  let import_cursor = source.offset(2, 11)
  assert_true(
    source.line_starts_with_import(2, source.token_count_before(import_cursor)),
  )
  assert_false(
    source.line_starts_with_import(
      3,
      source.token_count_before(source.offset(3, 1)),
    ),
  )
}

///|
test "completion returns top-level semantic entries" {
  let source =
    #|module Main
    #|
    #|pub fn answer(seed : Int) -> Int {
    #|  ans
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      4,
      6,
      Manual,
    ),
    content=(
      #|[
      #|  {
      #|    label: "answer",
      #|    kind: Function,
      #|    is_offered: false,
      #|    detail: Some("fn answer"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 50,
      #|          end_offset: 53,
      #|          start_line: 4,
      #|          start_column: 3,
      #|          end_line: 4,
      #|          end_column: 6,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:answer"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion renders external effects across semantic paths" {
  let imported_root =
    #|module Main
    #|
    #|import Lib
    #|
    #|pub fn run() -> Unit ! Lib.Runtime {
    #|  ()
    #|}
  let imported_lib =
    #|module Lib
    #|
    #|pub extern type Runtime : Effect
  let checked_source =
    #|module Main
    #|
    #|extern type Runtime : Effect
    #|
    #|pub fn run() -> Unit ! Runtime {
    #|  ()
    #|}
  let resolved_source =
    #|module Main
    #|
    #|extern type Runtime : Effect
    #|
    #|let broken : Missing = 0
    #|
    #|pub fn run() -> Unit ! Runtime {
    #|  ()
    #|}
  debug_inspect(
    [
      complete_test_source_inputs(
        { source_id: "file:///Main.lane", text: imported_root },
        [{ source_id: "file:///Lib.lane", text: imported_lib }],
        "file:///Main.lane",
        5,
        31,
        Manual,
      ).filter(entry => entry.label == "Runtime"),
      complete_test_source_inputs(
        { source_id: "file:///Main.lane", text: checked_source },
        [],
        "file:///Main.lane",
        5,
        27,
        Manual,
      ).filter(entry => entry.label == "Runtime"),
      complete_test_source_inputs(
        { source_id: "file:///Main.lane", text: resolved_source },
        [],
        "file:///Main.lane",
        7,
        27,
        Manual,
      ).filter(entry => entry.label == "Runtime"),
    ],
    content=(
      #|[
      #|  [
      #|    {
      #|      label: "Runtime",
      #|      kind: Effect,
      #|      is_offered: false,
      #|      detail: Some("extern type Runtime : Effect"),
      #|      documentation: None,
      #|      insert_text: None,
      #|      replace: Some(
      #|        {
      #|          source_id: "file:///Main.lane",
      #|          span: {
      #|            start_offset: 52,
      #|            end_offset: 55,
      #|            start_line: 5,
      #|            start_column: 28,
      #|            end_line: 5,
      #|            end_column: 31,
      #|          },
      #|        },
      #|      ),
      #|      sort_text: Some("32:Runtime"),
      #|    },
      #|  ],
      #|  [
      #|    {
      #|      label: "Runtime",
      #|      kind: Effect,
      #|      is_offered: false,
      #|      detail: Some("extern type Runtime : Effect"),
      #|      documentation: None,
      #|      insert_text: None,
      #|      replace: Some(
      #|        {
      #|          source_id: "file:///Main.lane",
      #|          span: {
      #|            start_offset: 66,
      #|            end_offset: 69,
      #|            start_line: 5,
      #|            start_column: 24,
      #|            end_line: 5,
      #|            end_column: 27,
      #|          },
      #|        },
      #|      ),
      #|      sort_text: Some("32:Runtime"),
      #|    },
      #|  ],
      #|  [
      #|    {
      #|      label: "Runtime",
      #|      kind: Effect,
      #|      is_offered: false,
      #|      detail: Some("extern type Runtime : Effect"),
      #|      documentation: None,
      #|      insert_text: None,
      #|      replace: Some(
      #|        {
      #|          source_id: "file:///Main.lane",
      #|          span: {
      #|            start_offset: 92,
      #|            end_offset: 95,
      #|            start_line: 7,
      #|            start_column: 24,
      #|            end_line: 7,
      #|            end_column: 27,
      #|          },
      #|        },
      #|      ),
      #|      sort_text: Some("32:Runtime"),
      #|    },
      #|  ],
      #|]
    ),
  )
}

///|
test "completion returns imported module surface entries" {
  let root =
    #|module Main
    #|
    #|import Lib
    #|
    #|pub fn use() -> Int {
    #|  Lib.answer()
    #|}
  let lib =
    #|module Lib
    #|
    #|pub effect Console {
    #|  read() -> Int
    #|}
    #|
    #|pub enum Option[A] {
    #|  none()
    #|  some(A)
    #|}
    #|
    #|pub fn answer() -> Int {
    #|  42
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: root },
      [{ source_id: "file:///Lib.lane", text: lib }],
      "file:///Main.lane",
      6,
      7,
      TriggerCharacter("."),
    ),
    content=(
      #|[
      #|  {
      #|    label: "answer",
      #|    kind: Function,
      #|    is_offered: false,
      #|    detail: Some("answer : () -> Int"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 53,
      #|          end_offset: 53,
      #|          start_line: 6,
      #|          start_column: 7,
      #|          end_line: 6,
      #|          end_column: 7,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:answer"),
      #|  },
      #|  {
      #|    label: "Option",
      #|    kind: Type,
      #|    is_offered: false,
      #|    detail: Some("enum Option"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 53,
      #|          end_offset: 53,
      #|          start_line: 6,
      #|          start_column: 7,
      #|          end_line: 6,
      #|          end_column: 7,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("30:Option"),
      #|  },
      #|  {
      #|    label: "Console",
      #|    kind: Effect,
      #|    is_offered: false,
      #|    detail: Some("effect Console"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 53,
      #|          end_offset: 53,
      #|          start_line: 6,
      #|          start_column: 7,
      #|          end_line: 6,
      #|          end_column: 7,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("32:Console"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion keeps offeredness orthogonal to semantic binding kind" {
  let source =
    #|module Main
    #|
    #|offer offered_value : Int = 1
    #|
    #|offer fn offered_function() -> Int {
    #|  1
    #|}
    #|
    #|pub fn use() -> Int {
    #|  off
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    10,
    6,
    Manual,
  )
  debug_inspect(
    entries.map(fn(entry) { (entry.label, entry.kind, entry.is_offered) }),
    content="[(\"offered_value\", Value, true), (\"offered_function\", Function, true)]",
  )
}

///|
test "module completion keeps offeredness orthogonal to interface value kind" {
  let root =
    #|module Main
    #|
    #|import Lib
    #|
    #|pub fn use() -> Int {
    #|  Lib.off
    #|}
  let library =
    #|module Lib
    #|
    #|pub offer offered_value : Int = 1
    #|
    #|pub offer fn offered_function() -> Int {
    #|  1
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: root },
    [{ source_id: "file:///Lib.lane", text: library }],
    "file:///Main.lane",
    6,
    10,
    Manual,
  )
  debug_inspect(
    entries.map(fn(entry) { (entry.label, entry.kind, entry.is_offered) }),
    content="[(\"offered_value\", Value, true), (\"offered_function\", Function, true)]",
  )
}

///|
test "completion uses importer revision symbol metadata" {
  let workspace = SemanticWorkspace::new()
  let source_a =
    #|module A
    #|
    #|pub fn[T] identity(value : T) -> T {
    #|  value
    #|}
  let source_b =
    #|module B
    #|
    #|import A
    #|
    #|pub fn use() -> Int {
    #|  A.identity(1)
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///A.lane", text: source_a },
      { source_id: "file:///B.lane", text: source_b },
    ])
    is Some(initial) else {
    abort("expected initial semantic snapshot")
  }
  let initial_entries = initial.complete(
    "file:///B.lane",
    6,
    5,
    TriggerCharacter("."),
  )
  debug_inspect(
    initial_entries
    .filter(fn(entry) { entry.label == "identity" })
    .map(fn(entry) { entry.detail }),
    content="[Some(\"identity : forall [T : Type]. (T) -> T\")]",
  )
  let revised_a =
    #|module A
    #|
    #|pub fn[T] identity(value : T) -> T {
    #|  let unchanged = value
    #|  unchanged
    #|}
  guard workspace.upsert_source({ source_id: "file:///A.lane", text: revised_a })
    is Some(revised) else {
    abort("expected revised semantic snapshot")
  }
  let revised_entries = revised.complete(
    "file:///B.lane",
    6,
    5,
    TriggerCharacter("."),
  )
  debug_inspect(
    revised_entries
    .filter(fn(entry) { entry.label == "identity" })
    .map(fn(entry) { entry.detail }),
    content="[Some(\"identity : forall [T : Type]. (T) -> T\")]",
  )
}

///|
test "imported completion preserves authored tuple signature presentation" {
  let root =
    #|module Main
    #|
    #|import A
    #|
    #|pub fn use() -> (Int, Bool) {
    #|  A.sugared(1)
    #|}
  let library =
    #|module A
    #|
    #|import Basic.Data.Tuple
    #|
    #|pub fn sugared(value : Int) -> (Int, Bool) {
    #|  (value, true)
    #|}
    #|
    #|pub fn explicit(value : Int) -> Basic.Data.Tuple.Tuple[Int, Bool] {
    #|  Basic.Data.Tuple.Tuple::tuple(value, true)
    #|}
  let tuple =
    #|module Basic.Data.Tuple
    #|
    #|pub enum Tuple[A, B] {
    #|  tuple(A, B)
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: root },
    [
      { source_id: "file:///A.lane", text: library },
      { source_id: "file:///Tuple.lane", text: tuple },
    ],
    "file:///Main.lane",
    6,
    5,
    TriggerCharacter("."),
  )
  debug_inspect(
    entries
    .filter(fn(entry) { entry.label == "sugared" || entry.label == "explicit" })
    .map(fn(entry) { (entry.label, entry.detail) }),
    content=(
      #|[
      #|  ("sugared", Some("sugared : (Int) -> (Int, Bool)")),
      #|  ("explicit", Some("explicit : (Int) -> Tuple[Int, Bool]")),
      #|]
    ),
  )
}

///|
test "completion returns owner members after double colon" {
  let source =
    #|module Main
    #|
    #|effect Console {
    #|  read() -> Int
    #|  write(Int) -> Unit
    #|}
    #|
    #|enum Option[A] {
    #|  none()
    #|  some(A)
    #|}
    #|
    #|pub fn use() -> Option[Int] {
    #|  Option::some(1)
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      14,
      11,
      TriggerCharacter(":"),
    ),
    content=(
      #|[
      #|  {
      #|    label: "none",
      #|    kind: Variant,
      #|    is_offered: false,
      #|    detail: Some("variant Option::none"),
      #|    documentation: None,
      #|    insert_text: Some("none()"),
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 149,
      #|          end_offset: 149,
      #|          start_line: 14,
      #|          start_column: 11,
      #|          end_line: 14,
      #|          end_column: 11,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:none"),
      #|  },
      #|  {
      #|    label: "some",
      #|    kind: Variant,
      #|    is_offered: false,
      #|    detail: Some("variant Option::some"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 149,
      #|          end_offset: 149,
      #|          start_line: 14,
      #|          start_column: 11,
      #|          end_line: 14,
      #|          end_column: 11,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:some"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion inserts parens for imported payloadless owner variants" {
  let root =
    #|module Main
    #|
    #|import Lib
    #|
    #|pub fn use() -> Lib.Option[Int] {
    #|  Lib.Option::none()
    #|}
  let lib =
    #|module Lib
    #|
    #|pub enum Option[A] {
    #|  none()
    #|  some(A)
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: root },
      [{ source_id: "file:///Lib.lane", text: lib }],
      "file:///Main.lane",
      6,
      15,
      TriggerCharacter(":"),
    ),
    content=(
      #|[
      #|  {
      #|    label: "none",
      #|    kind: Variant,
      #|    is_offered: false,
      #|    detail: Some("variant Lib.Option::none"),
      #|    documentation: None,
      #|    insert_text: Some("none()"),
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 73,
      #|          end_offset: 73,
      #|          start_line: 6,
      #|          start_column: 15,
      #|          end_line: 6,
      #|          end_column: 15,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:none"),
      #|  },
      #|  {
      #|    label: "some",
      #|    kind: Variant,
      #|    is_offered: false,
      #|    detail: Some("variant Lib.Option::some"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 73,
      #|          end_offset: 73,
      #|          start_line: 6,
      #|          start_column: 15,
      #|          end_line: 6,
      #|          end_column: 15,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:some"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion inserts parens for payloadless variants with resolved fallback" {
  let source =
    #|module Main
    #|
    #|enum Option[A] {
    #|  none()
    #|  some(A)
    #|}
    #|
    #|let broken : Missing = 0
    #|
    #|pub fn use() -> Option[Int] {
    #|  Option::none()
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      11,
      11,
      TriggerCharacter(":"),
    ),
    content=(
      #|[
      #|  {
      #|    label: "none",
      #|    kind: Variant,
      #|    is_offered: false,
      #|    detail: Some("variant Option::none"),
      #|    documentation: None,
      #|    insert_text: Some("none()"),
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 118,
      #|          end_offset: 118,
      #|          start_line: 11,
      #|          start_column: 11,
      #|          end_line: 11,
      #|          end_column: 11,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:none"),
      #|  },
      #|  {
      #|    label: "some",
      #|    kind: Variant,
      #|    is_offered: false,
      #|    detail: Some("variant Option::some"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 118,
      #|          end_offset: 118,
      #|          start_line: 11,
      #|          start_column: 11,
      #|          end_line: 11,
      #|          end_column: 11,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:some"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion returns imported owner operations after double colon" {
  let root =
    #|module Main
    #|
    #|import Lib
    #|
    #|pub fn use() -> Int ! Lib.Console {
    #|  Lib.Console::read()
    #|}
  let lib =
    #|module Lib
    #|
    #|pub effect Console {
    #|  read() -> Int
    #|  write(Int) -> Unit
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: root },
      [{ source_id: "file:///Lib.lane", text: lib }],
      "file:///Main.lane",
      6,
      16,
      TriggerCharacter(":"),
    ),
    content=(
      #|[
      #|  {
      #|    label: "read",
      #|    kind: Operation,
      #|    is_offered: false,
      #|    detail: Some("Console::read() -> Int"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 76,
      #|          end_offset: 76,
      #|          start_line: 6,
      #|          start_column: 16,
      #|          end_line: 6,
      #|          end_column: 16,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:read"),
      #|  },
      #|  {
      #|    label: "write",
      #|    kind: Operation,
      #|    is_offered: false,
      #|    detail: Some("Console::write(Int) -> Unit"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 76,
      #|          end_offset: 76,
      #|          start_line: 6,
      #|          start_column: 16,
      #|          end_line: 6,
      #|          end_column: 16,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:write"),
      #|  },
      #|]
    ),
  )
}

///|
test "local operation completion uses signature detail" {
  let source =
    #|module Main
    #|
    #|pub effect Prompt {
    #|  choose[A](A, A) -> A
    #|}
    #|
    #|pub fn use() -> Int ! Prompt {
    #|  Prompt::choose![Int](1, 2)
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    8,
    11,
    TriggerCharacter(":"),
  )
  debug_inspect(
    entries
    .filter(fn(entry) { entry.kind == Operation })
    .map(fn(entry) { (entry.label, entry.detail) }),
    content="[(\"choose\", Some(\"Prompt::choose[A : Type](A, A) -> A\"))]",
  )
}

///|
test "imported operation completion includes type parameters" {
  let root =
    #|module Main
    #|
    #|import Lib
    #|
    #|pub fn use() -> Int ! Lib.Prompt {
    #|  Lib.Prompt::choose![Int](1, 2)
    #|}
  let lib =
    #|module Lib
    #|
    #|pub effect Prompt {
    #|  choose[A](A, A) -> A
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: root },
    [{ source_id: "file:///Lib.lane", text: lib }],
    "file:///Main.lane",
    6,
    15,
    TriggerCharacter(":"),
  )
  debug_inspect(
    entries
    .filter(fn(entry) { entry.kind == Operation })
    .map(fn(entry) { (entry.label, entry.detail) }),
    content="[(\"choose\", Some(\"Prompt::choose[A : Type](A, A) -> A\"))]",
  )
}

///|
test "completion returns known module paths in import declarations" {
  let root =
    #|module Main
    #|
    #|import Lib
  let lib =
    #|module Lib
    #|
    #|pub fn answer() -> Int {
    #|  42
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: root },
      [{ source_id: "file:///Lib.lane", text: lib }],
      "file:///Main.lane",
      3,
      9,
      Manual,
    ),
    content=(
      #|[
      #|  {
      #|    label: "Lib",
      #|    kind: Module,
      #|    is_offered: false,
      #|    detail: Some("module Lib"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 20,
      #|          end_offset: 21,
      #|          start_line: 3,
      #|          start_column: 8,
      #|          end_line: 3,
      #|          end_column: 9,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("10:Lib"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion filters candidates by type and effect positions" {
  let source =
    #|module Main
    #|
    #|pub struct Thing {
    #|  value : Int
    #|}
    #|
    #|pub effect Console {
    #|  log(String) -> Unit
    #|}
    #|
    #|pub fn make() -> Int {
    #|  0
    #|}
    #|
    #|pub let item : Thing = Thing::{ value: 1 }
    #|
    #|pub fn run() -> Unit ! Console {
    #|  ()
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      15,
      19,
      Manual,
    ),
    content=(
      #|[
      #|  {
      #|    label: "Thing",
      #|    kind: Type,
      #|    is_offered: false,
      #|    detail: Some("struct Thing"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 140,
      #|          end_offset: 143,
      #|          start_line: 15,
      #|          start_column: 16,
      #|          end_line: 15,
      #|          end_column: 19,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("30:Thing"),
      #|  },
      #|]
    ),
  )
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      17,
      27,
      Manual,
    ),
    content=(
      #|[
      #|  {
      #|    label: "Console",
      #|    kind: Effect,
      #|    is_offered: false,
      #|    detail: Some("effect Console"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 192,
      #|          end_offset: 195,
      #|          start_line: 17,
      #|          start_column: 24,
      #|          end_line: 17,
      #|          end_column: 27,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("32:Console"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion classifies same-line function bodies as value space" {
  let source =
    #|module Main
    #|
    #|pub fn make() -> Int { 1 }
    #|pub fn use() -> Int { ma }
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    4,
    25,
    Manual,
  )
  debug_inspect(
    entries.map(fn(entry) { (entry.label, entry.kind) }),
    content="[(\"make\", Function)]",
  )
}

///|
test "completion classifies struct field initializers as value space" {
  let source =
    #|module Main
    #|
    #|pub struct Thing {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub let item : Thing = Thing::{ value: ma }
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    9,
    42,
    Manual,
  )
  debug_inspect(
    entries.map(fn(entry) { (entry.label, entry.kind) }),
    content="[(\"make\", Function)]",
  )
}

///|
test "completion classifies type alias bodies as type space" {
  let source =
    #|module Main
    #|
    #|pub struct make_type {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub type Alias = ma
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    9,
    20,
    Manual,
  )
  debug_inspect(
    entries.map(fn(entry) { (entry.label, entry.kind) }),
    content="[(\"make_type\", Type)]",
  )
}

///|
test "completion classifies pattern owners as type space" {
  let source =
    #|module Main
    #|
    #|pub struct make_type {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub fn use(item : make_type) -> Int {
    #|  match item {
    #|    ma::{ value } => value
    #|  }
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    11,
    7,
    Manual,
  )
  debug_inspect(
    entries.map(fn(entry) { (entry.label, entry.kind) }),
    content="[(\"make_type\", Type)]",
  )
}

///|
test "completion classifies an empty type annotation slot as type space" {
  let valid_source =
    #|module Main
    #|
    #|import Base
    #|
    #|pub struct Thing {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub let x : Thing = Thing::{ value: 1 }
  let edited_source =
    #|module Main
    #|
    #|import Base
    #|
    #|pub struct Thing {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub let x :
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      {
        source_id: "file:///Base.lane",
        text: "module Base\n\npub let base : Int = 0",
      },
      { source_id: "file:///Main.lane", text: valid_source },
    ])
    is Some(_) else {
    abort("expected initial semantic snapshot")
  }
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: edited_source,
    })
    is Some(snapshot) else {
    abort("expected edited semantic snapshot")
  }
  let entries = snapshot.complete("file:///Main.lane", 11, 12, Manual)
  debug_inspect(
    entries
    .filter(entry => entry.label == "Thing" || entry.label == "make")
    .map(entry => (entry.label, entry.kind)),
    content="[(\"Thing\", Type)]",
  )
}

///|
test "completion classifies an empty tuple type item as type space" {
  let valid_source =
    #|module Main
    #|
    #|pub struct Thing {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub type Pair = (Thing, Int)
  let edited_source =
    #|module Main
    #|
    #|pub struct Thing {
    #|  value : Int
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub type Pair = (Thing,
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: valid_source },
    ])
    is Some(_) else {
    abort("expected initial semantic snapshot")
  }
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: edited_source,
    })
    is Some(snapshot) else {
    abort("expected edited semantic snapshot")
  }
  let entries = snapshot.complete("file:///Main.lane", 9, 24, Manual)
  debug_inspect(
    entries
    .filter(entry => entry.label == "Thing" || entry.label == "make")
    .map(entry => (entry.label, entry.kind)),
    content="[(\"Thing\", Type)]",
  )
}

///|
test "completion classifies an empty effect annotation slot as effect space" {
  let valid_source =
    #|module Main
    #|
    #|pub effect Console {
    #|  log(String) -> Unit
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub fn run() -> Unit ! Console { () }
  let edited_source =
    #|module Main
    #|
    #|pub effect Console {
    #|  log(String) -> Unit
    #|}
    #|
    #|pub fn make() -> Int { 0 }
    #|
    #|pub fn run() -> Unit !
  let workspace = SemanticWorkspace::new()
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: valid_source },
    ])
    is Some(_) else {
    abort("expected initial semantic snapshot")
  }
  guard workspace.upsert_source({
      source_id: "file:///Main.lane",
      text: edited_source,
    })
    is Some(snapshot) else {
    abort("expected edited semantic snapshot")
  }
  let entries = snapshot.complete("file:///Main.lane", 9, 23, Manual)
  debug_inspect(
    entries
    .filter(entry => entry.label == "Console" || entry.label == "make")
    .map(entry => (entry.label, entry.kind)),
    content="[(\"Console\", Effect)]",
  )
}

///|
test "semantic definitions retain exact spans for repeated names" {
  let result = analyze_test_sources(
    (
      #|module Main
      #|
      #|pub fn same(same : Int) -> Int { same }
    ),
    [],
  )
  debug_inspect(
    result.definitions
    .filter(fn(definition) { definition.label == "same" })
    .map(fn(definition) { definition.location.span }),
    content=(
      #|[
      #|  {
      #|    start_offset: 20,
      #|    end_offset: 24,
      #|    start_line: 3,
      #|    start_column: 8,
      #|    end_line: 3,
      #|    end_column: 12,
      #|  },
      #|  {
      #|    start_offset: 25,
      #|    end_offset: 29,
      #|    start_line: 3,
      #|    start_column: 13,
      #|    end_line: 3,
      #|    end_column: 17,
      #|  },
      #|]
    ),
  )
}

///|
test "completion returns checked selector fields" {
  let source =
    #|module Main
    #|
    #|pub struct Point {
    #|  x : Int
    #|  y : Int
    #|}
    #|
    #|pub fn use(point : Point) -> Int {
    #|  point.x
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      9,
      9,
      TriggerCharacter("."),
    ),
    content=(
      #|[
      #|  {
      #|    label: "x",
      #|    kind: Field,
      #|    is_offered: false,
      #|    detail: Some("x : Int"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 98,
      #|          end_offset: 98,
      #|          start_line: 9,
      #|          start_column: 9,
      #|          end_line: 9,
      #|          end_column: 9,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:x"),
      #|  },
      #|  {
      #|    label: "y",
      #|    kind: Field,
      #|    is_offered: false,
      #|    detail: Some("y : Int"),
      #|    documentation: None,
      #|    insert_text: None,
      #|    replace: Some(
      #|      {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 98,
      #|          end_offset: 98,
      #|          start_line: 9,
      #|          start_column: 9,
      #|          end_line: 9,
      #|          end_column: 9,
      #|        },
      #|      },
      #|    ),
      #|    sort_text: Some("20:y"),
      #|  },
      #|]
    ),
  )
}

///|
test "completion returns empty for unsupported triggers and unavailable receivers" {
  let source =
    #|module Main
    #|
    #|pub fn use() -> Int {
    #|  missing.x
    #|}
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      2,
      1,
      TriggerCharacter("."),
    ),
    content="[]",
  )
  debug_inspect(
    complete_test_source_inputs(
      { source_id: "file:///Main.lane", text: source },
      [],
      "file:///Main.lane",
      4,
      11,
      TriggerCharacter("."),
    ),
    content="[]",
  )
}

///|
test "completion reads match binders from the semantic index" {
  let source =
    #|module Main
    #|
    #|pub enum Option {
    #|  none()
    #|  some(Int)
    #|}
    #|
    #|pub fn use(value : Option) -> Int {
    #|  match value {
    #|    Option::none() => 0
    #|    Option::some(item) => it
    #|  }
    #|}
  let entries = complete_test_source_inputs(
    { source_id: "file:///Main.lane", text: source },
    [],
    "file:///Main.lane",
    11,
    29,
    Manual,
  )
  debug_inspect(
    entries
    .filter(fn(entry) { entry.label == "item" })
    .map(fn(entry) { (entry.label, entry.kind, entry.detail) }),
    content="[(\"item\", Value, Some(\"pattern item\"))]",
  )
}
