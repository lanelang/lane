///|
test "completion returns top-level semantic entries" {
  let source =
    #|module Main
    #|
    #|pub fn answer(seed : Int) -> Int {
    #|  ans
    #|}
  debug_inspect(
    complete_source_inputs(
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
      complete_source_inputs(
        { source_id: "file:///Main.lane", text: imported_root },
        [{ source_id: "file:///Lib.lane", text: imported_lib }],
        "file:///Main.lane",
        5,
        31,
        Manual,
      ).filter(entry => entry.label == "Runtime"),
      complete_source_inputs(
        { source_id: "file:///Main.lane", text: checked_source },
        [],
        "file:///Main.lane",
        5,
        27,
        Manual,
      ).filter(entry => entry.label == "Runtime"),
      complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
    complete_source_inputs(
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
