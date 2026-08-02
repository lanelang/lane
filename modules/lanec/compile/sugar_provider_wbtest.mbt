///|
test "compile tuple and list sugar through fixed qualified providers" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Basic.Data.Tuple
      #|import Basic.Data.List
      #|pub fn make() -> (I64, Bool, String) {
      #|  (1, true, "lane")
      #|}
      #|pub fn first(value : (I64, Bool, String)) -> I64 {
      #|  let (head, _, _) = value
      #|  head
      #|}
      #|pub fn numbers() -> Basic.Data.List.List[I64] {
      #|  [1, 2, 3]
      #|}
    ),
    [
      (
        #|module Basic.Data.Tuple
        #|pub enum Tuple[A, B] {
        #|  tuple(A, B)
        #|}
      ),
      (
        #|module Basic.Data.List
        #|pub enum List[A] {
        #|  empty()
        #|  cons(A, List[A])
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="make,first,numbers",
  )
}

///|
test "generic effect inference reaches function literals inside list sugar" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Basic.Data.List.{ List }
      #|pub effect Read {
      #|  read() -> Unit
      #|}
      #|pub effect Write {
      #|  write() -> Unit
      #|}
      #|fn[E : Effect] run_all(_tests : List[() -> Unit ! E]) -> Unit ! E {
      #|  ()
      #|}
      #|pub fn pure_use() -> Unit {
      #|  run_all([fn() { () }])
      #|}
      #|pub fn read_use() -> Unit ! Read {
      #|  run_all([fn() { Read::read!() }])
      #|}
      #|pub fn joined_use() -> Unit ! { Read, Write } {
      #|  run_all([fn() { Read::read!() }, fn() { Write::write!() }])
      #|}
    ),
    [
      (
        #|module Basic.Data.List
        #|pub enum List[A] {
        #|  empty()
        #|  cons(A, List[A])
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "nested function literal does not infer an unground callback shape" {
  let diagnostic = single_check_sources_diagnostic(
    (
      #|module Main
      #|import Basic.Data.List.{ List }
      #|fn[A, E : Effect] run_all(_tests : List[(A) -> A ! E]) -> Unit {
      #|  ()
      #|}
      #|pub fn use() -> Unit {
      #|  run_all([fn(value) { value }])
      #|}
    ),
    [
      (
        #|module Basic.Data.List
        #|pub enum List[A] {
        #|  empty()
        #|  cons(A, List[A])
        #|}
      ),
    ],
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "cannot infer generic arguments for `run_all`",
  )
}

///|
test "a sugar provider resolves its own fully qualified nominal expansion" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Basic.Data.List.*
      #|pub let number : List[I64] = singleton(1)
    ),
    [
      (
        #|module Basic.Data.List
        #|pub enum List[A] {
        #|  empty()
        #|  cons(A, List[A])
        #|}
        #|pub fn[A] singleton(value : A) -> List[A] {
        #|  [value]
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "self-qualified namespace excludes imported declarations" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Lib.{ Box }
      #|pub let value : Main.Box[I64] = Main.Box::box(1)
    ),
    [
      (
        #|module Lib
        #|pub enum Box[A] {
        #|  box(A)
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find type `Main.Box`", "cannot find variant `Main.Box::box`"]
    ),
  )
}

///|
test "self-qualified namespace includes local type declarations" {
  let result = check_source_for_test(
    (
      #|module Main
      #|pub enum Box[A] {
      #|  box(A)
      #|}
      #|pub effect Ask[A] {
      #|  read() -> A
      #|}
      #|pub let boxed : Main.Box[I64] = Main.Box::box(1)
      #|pub fn value() -> I64 ! Main.Ask[I64] {
      #|  Main.Ask[I64]::read!()
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "tuple ABI module cannot borrow declarations from an open import" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Basic.Data.Tuple
      #|pub let pair : (I64, Bool) = (1, true)
    ),
    [
      (
        #|module Basic.Data.Tuple
        #|import Other.*
      ),
      (
        #|module Other
        #|pub enum Tuple[A, B] {
        #|  tuple(A, B)
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "cannot find type `Basic.Data.Tuple.Tuple`",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 51,
      #|          end_offset: 62,
      #|          start_line: 3,
      #|          start_column: 16,
      #|          end_line: 3,
      #|          end_column: 27,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E2000"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 51,
      #|            end_offset: 62,
      #|            start_line: 3,
      #|            start_column: 16,
      #|            end_line: 3,
      #|            end_column: 27,
      #|          },
      #|        ),
      #|        message: "no type named `Basic.Data.Tuple.Tuple` is visible here",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["Lane resolves type names from the current module and explicitly imported public types"],
      #|    helps: ["declare `Basic.Data.Tuple.Tuple`, import the module that exports it, or qualify the type as `Module.Basic.Data.Tuple.Tuple`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "cannot find variant `Basic.Data.Tuple.Tuple::tuple`",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 65,
      #|          end_offset: 74,
      #|          start_line: 3,
      #|          start_column: 30,
      #|          end_line: 3,
      #|          end_column: 39,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 65,
      #|            end_offset: 74,
      #|            start_line: 3,
      #|            start_column: 30,
      #|            end_line: 3,
      #|            end_column: 39,
      #|          },
      #|        ),
      #|        message: "this enum type does not expose a variant named `tuple`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["qualified variant lookup first resolves the enum type, then its variants"],
      #|    helps: ["check the variant spelling or use a variant declared by `Basic.Data.Tuple.Tuple`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "tuple and list sugar do not use unqualified fallback providers" {
  let tuple_result = check_source_for_test(
    (
      #|module Main
      #|pub let pair : (I64, Bool) = (1, true)
    ),
  )
  debug_inspect(
    tuple_result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|[
      #|  "cannot find type `Basic.Data.Tuple.Tuple`",
      #|  "cannot find variant `Basic.Data.Tuple.Tuple::tuple`",
      #|]
    ),
  )
  let list_result = check_source_for_test(
    (
      #|module Main
      #|enum LocalList[A] {
      #|  empty()
      #|  cons(A, LocalList[A])
      #|}
      #|pub let numbers : LocalList[I64] = [1, 2]
    ),
  )
  debug_inspect(
    list_result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "cannot find variant `Basic.Data.List.List::cons`",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 103,
      #|          end_offset: 109,
      #|          start_line: 6,
      #|          start_column: 36,
      #|          end_line: 6,
      #|          end_column: 42,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 103,
      #|            end_offset: 109,
      #|            start_line: 6,
      #|            start_column: 36,
      #|            end_line: 6,
      #|            end_column: 42,
      #|          },
      #|        ),
      #|        message: "this enum type does not expose a variant named `cons`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["qualified variant lookup first resolves the enum type, then its variants"],
      #|    helps: ["check the variant spelling or use a variant declared by `Basic.Data.List.List`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "cannot find variant `Basic.Data.List.List::empty`",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 103,
      #|          end_offset: 109,
      #|          start_line: 6,
      #|          start_column: 36,
      #|          end_line: 6,
      #|          end_column: 42,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 103,
      #|            end_offset: 109,
      #|            start_line: 6,
      #|            start_column: 36,
      #|            end_line: 6,
      #|            end_column: 42,
      #|          },
      #|        ),
      #|        message: "this enum type does not expose a variant named `empty`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["qualified variant lookup first resolves the enum type, then its variants"],
      #|    helps: ["check the variant spelling or use a variant declared by `Basic.Data.List.List`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "all import exposure forms provide canonical modules used by sugar" {
  for
    imports in [
      "import Basic.Data.Tuple\nimport Basic.Data.List", "import Basic.Data.Tuple.*\nimport Basic.Data.List.*",
      "import Basic.Data.Tuple.{ Tuple }\nimport Basic.Data.List.{ List }",
    ] {
    let result = check_sources_for_test(
      "module Main\n" +
      imports +
      (
        #|
        #|pub fn sugars() -> Unit {
        #|  let _pair = (1, true)
        #|  let _numbers = [1, 2]
        #|  ()
        #|}
      ),
      [
        (
          #|module Basic.Data.Tuple
          #|pub enum Tuple[A, B] {
          #|  tuple(A, B)
          #|}
        ),
        (
          #|module Basic.Data.List
          #|pub enum List[A] {
          #|  empty()
          #|  cons(A, List[A])
          #|}
        ),
      ],
    )
    debug_inspect(result.diagnostics, content="[]")
  }
}
