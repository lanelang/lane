///|
test "check reports unused local value binding as warning" {
  let result = successful_check_diagnostics(
    (
      #|module Test
      #|pub fn answer() -> I64 {
      #|  let used = 1
      #|  let unused = 2
      #|  let _ignored = 3
      #|  used
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 58,
      #|          end_offset: 64,
      #|          start_line: 4,
      #|          start_column: 7,
      #|          end_line: 4,
      #|          end_column: 13,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 58,
      #|            end_offset: 64,
      #|            start_line: 4,
      #|            start_column: 7,
      #|            end_line: 4,
      #|            end_column: 13,
      #|          },
      #|        ),
      #|        message: "`unused` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "compile modules keeps artifacts when unused local warning exists" {
  let result = successful_compile_modules_diagnostics(
    (
      #|module Test
      #|pub fn answer() -> I64 {
      #|  let unused = 1
      #|  0
      #|}
    ),
    [],
  )
  debug_inspect(
    result,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 43,
      #|          end_offset: 49,
      #|          start_line: 3,
      #|          start_column: 7,
      #|          end_line: 3,
      #|          end_column: 13,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 43,
      #|            end_offset: 49,
      #|            start_line: 3,
      #|            start_column: 7,
      #|            end_line: 3,
      #|            end_column: 13,
      #|          },
      #|        ),
      #|        message: "`unused` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "unused local offered function remains unused" {
  let result = successful_check_diagnostics(
    (
      #|module Test
      #|pub fn program() -> Unit {
      #|  offer fn unused() -> I64 {
      #|    42
      #|  };
      #|  ()
      #|}
    ),
  )
  guard result
    is [{ message: "unused local value binding", code: Some("W2001"), .. }] else {
    abort("expected one unused local value binding warning")
  }
}

///|
test "check reports unused private top-level declarations as warnings" {
  let result = successful_check_diagnostics(
    (
      #|module Test
      #|fn dead_function() -> I64 {
      #|  1
      #|}
      #|let dead_value : I64 = 2
      #|struct DeadStruct {
      #|  value : I64
      #|}
      #|enum DeadEnum {
      #|  dead()
      #|}
      #|effect DeadEffect {
      #|  dead() -> Unit
      #|}
      #|type DeadAlias = I64
      #|type DeadEffects = { DeadEffect }
      #|pub fn answer() -> I64 {
      #|  0
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 15,
      #|          end_offset: 28,
      #|          start_line: 2,
      #|          start_column: 4,
      #|          end_line: 2,
      #|          end_column: 17,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 15,
      #|            end_offset: 28,
      #|            start_line: 2,
      #|            start_column: 4,
      #|            end_line: 2,
      #|            end_column: 17,
      #|          },
      #|        ),
      #|        message: "private function `dead_function` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 50,
      #|          end_offset: 60,
      #|          start_line: 5,
      #|          start_column: 5,
      #|          end_line: 5,
      #|          end_column: 15,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 50,
      #|            end_offset: 60,
      #|            start_line: 5,
      #|            start_column: 5,
      #|            end_line: 5,
      #|            end_column: 15,
      #|          },
      #|        ),
      #|        message: "private value `dead_value` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 78,
      #|          end_offset: 88,
      #|          start_line: 6,
      #|          start_column: 8,
      #|          end_line: 6,
      #|          end_column: 18,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 78,
      #|            end_offset: 88,
      #|            start_line: 6,
      #|            start_column: 8,
      #|            end_line: 6,
      #|            end_column: 18,
      #|          },
      #|        ),
      #|        message: "private struct `DeadStruct` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 112,
      #|          end_offset: 120,
      #|          start_line: 9,
      #|          start_column: 6,
      #|          end_line: 9,
      #|          end_column: 14,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 112,
      #|            end_offset: 120,
      #|            start_line: 9,
      #|            start_column: 6,
      #|            end_line: 9,
      #|            end_column: 14,
      #|          },
      #|        ),
      #|        message: "private enum `DeadEnum` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 141,
      #|          end_offset: 151,
      #|          start_line: 12,
      #|          start_column: 8,
      #|          end_line: 12,
      #|          end_column: 18,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 141,
      #|            end_offset: 151,
      #|            start_line: 12,
      #|            start_column: 8,
      #|            end_line: 12,
      #|            end_column: 18,
      #|          },
      #|        ),
      #|        message: "private effect `DeadEffect` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 178,
      #|          end_offset: 187,
      #|          start_line: 15,
      #|          start_column: 6,
      #|          end_line: 15,
      #|          end_column: 15,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 178,
      #|            end_offset: 187,
      #|            start_line: 15,
      #|            start_column: 6,
      #|            end_line: 15,
      #|            end_column: 15,
      #|          },
      #|        ),
      #|        message: "private type alias `DeadAlias` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused private top-level declaration",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 199,
      #|          end_offset: 210,
      #|          start_line: 16,
      #|          start_column: 6,
      #|          end_line: 16,
      #|          end_column: 17,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2002"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 199,
      #|            end_offset: 210,
      #|            start_line: 16,
      #|            start_column: 6,
      #|            end_line: 16,
      #|            end_column: 17,
      #|          },
      #|        ),
      #|        message: "private effect alias `DeadEffects` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "check keeps reachable private top-level declarations quiet" {
  let result = successful_check_diagnostics(
    (
      #|module Test
      #|struct Box {
      #|  value : I64
      #|}
      #|enum Option {
      #|  some(Box)
      #|  none()
      #|}
      #|effect Console {
      #|  read() -> I64
      #|}
      #|type UI = { Console }
      #|type Task = { UI }
      #|fn helper(value : Option) -> I64 ! Task {
      #|  match value {
      #|    some(box) => {
      #|      let _read : I64 = Console::read!()
      #|      box.value
      #|    }
      #|    none() => 0
      #|  }
      #|}
      #|pub fn answer() -> I64 {
      #|  handle helper(Option::some(Box::{ value: 1 })) with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(result, content="[]")
}

///|
test "check reports unused generic parameters as warnings" {
  let result = successful_check_diagnostics(
    (
      #|module Test
      #|pub struct Box[A, B] {
      #|  value : A
      #|}
      #|pub effect Logger[E : Effect] {
      #|  log() -> Unit
      #|}
      #|pub effect Prompt {
      #|  choose[A, B](A) -> A
      #|}
      #|pub type Alias[A, B] = A
      #|pub fn[A] shadow(_f : [A](A) -> A) -> Unit {
      #|  ()
      #|}
      #|pub fn[A, B] id(value : A) -> A {
      #|  value
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused type parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 30,
      #|          end_offset: 31,
      #|          start_line: 2,
      #|          start_column: 19,
      #|          end_line: 2,
      #|          end_column: 20,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 30,
      #|            end_offset: 31,
      #|            start_line: 2,
      #|            start_column: 19,
      #|            end_line: 2,
      #|            end_column: 20,
      #|          },
      #|        ),
      #|        message: "`B` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused effect parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 67,
      #|          end_offset: 68,
      #|          start_line: 5,
      #|          start_column: 19,
      #|          end_line: 5,
      #|          end_column: 20,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 67,
      #|            end_offset: 68,
      #|            start_line: 5,
      #|            start_column: 19,
      #|            end_line: 5,
      #|            end_column: 20,
      #|          },
      #|        ),
      #|        message: "`E` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused type parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 131,
      #|          end_offset: 132,
      #|          start_line: 9,
      #|          start_column: 13,
      #|          end_line: 9,
      #|          end_column: 14,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 131,
      #|            end_offset: 132,
      #|            start_line: 9,
      #|            start_column: 13,
      #|            end_line: 9,
      #|            end_column: 14,
      #|          },
      #|        ),
      #|        message: "`B` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused type parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 162,
      #|          end_offset: 163,
      #|          start_line: 11,
      #|          start_column: 19,
      #|          end_line: 11,
      #|          end_column: 20,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 162,
      #|            end_offset: 163,
      #|            start_line: 11,
      #|            start_column: 19,
      #|            end_line: 11,
      #|            end_column: 20,
      #|          },
      #|        ),
      #|        message: "`B` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused type parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 162,
      #|          end_offset: 163,
      #|          start_line: 11,
      #|          start_column: 19,
      #|          end_line: 11,
      #|          end_column: 20,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 162,
      #|            end_offset: 163,
      #|            start_line: 11,
      #|            start_column: 19,
      #|            end_line: 11,
      #|            end_column: 20,
      #|          },
      #|        ),
      #|        message: "`B` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused type parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 176,
      #|          end_offset: 177,
      #|          start_line: 12,
      #|          start_column: 8,
      #|          end_line: 12,
      #|          end_column: 9,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 176,
      #|            end_offset: 177,
      #|            start_line: 12,
      #|            start_column: 8,
      #|            end_line: 12,
      #|            end_column: 9,
      #|          },
      #|        ),
      #|        message: "`A` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused type parameter",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 231,
      #|          end_offset: 232,
      #|          start_line: 15,
      #|          start_column: 11,
      #|          end_line: 15,
      #|          end_column: 12,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2003"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 231,
      #|            end_offset: 232,
      #|            start_line: 15,
      #|            start_column: 11,
      #|            end_line: 15,
      #|            end_column: 12,
      #|          },
      #|        ),
      #|        message: "`B` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "check keeps used generic parameters quiet" {
  let result = successful_check_diagnostics(
    (
      #|module Test
      #|pub struct Box[A] {
      #|  value : A
      #|}
      #|pub enum Option[A] {
      #|  some(A)
      #|  none()
      #|}
      #|pub effect Console[E : Effect] {
      #|  run(() -> Unit ! E) -> Unit
      #|}
      #|pub effect Prompt {
      #|  choose[A](A) -> A
      #|}
      #|pub type Task[E : Effect] = { Console[E], E }
      #|pub type Mapper[F : [Type] -> Type, A] = F[A]
      #|pub fn[A, E : Effect] keep(value : A, _body : () -> Unit ! E) -> A {
      #|  value
      #|}
    ),
  )
  debug_inspect(result, content="[]")
}

///|
test "check reports unused imports and opens as warnings" {
  let result = successful_check_sources_diagnostics(
    (
      #|module Main
      #|import UsedQualified
      #|import UnusedQualified
      #|import UnusedOpen.*
      #|import OpenLib.*
      #|import SelectiveLib.{ used, unused }
      #|
      #|pub fn answer() -> I64 {
      #|  let _qualified = UsedQualified.value
      #|  let _open = open_value
      #|  used
      #|}
    ),
    [
      (
        #|module UsedQualified
        #|pub let value : I64 = 1
      ),
      (
        #|module UnusedQualified
        #|pub let value : I64 = 2
      ),
      (
        #|module UnusedOpen
        #|pub let value : I64 = 3
      ),
      (
        #|module OpenLib
        #|pub let open_value : I64 = 4
      ),
      (
        #|module SelectiveLib
        #|pub let used : I64 = 5
        #|pub let unused : I64 = 6
      ),
    ],
  )
  debug_inspect(
    result.map(compiler_diagnostic_summary),
    content=(
      #|[
      #|  {
      #|    message: "unused import",
      #|    code: Some("W2004"),
      #|    labels: ["imported module `UnusedQualified` is never used"],
      #|  },
      #|  {
      #|    message: "unused open import",
      #|    code: Some("W2004"),
      #|    labels: ["open import `UnusedOpen.*` contributes no used names"],
      #|  },
      #|  {
      #|    message: "unused import item",
      #|    code: Some("W2004"),
      #|    labels: ["imported item `unused` from `SelectiveLib` is never used"],
      #|  },
      #|]
    ),
  )
}

///|
test "check reports payloadless variant without parentheses" {
  let result = check_source(
    (
      #|module Test
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|let value : Option[I64] = none
    ),
  )
  debug_inspect(
    result.diagnostics().map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["payloadless variant `none` must use empty parentheses"]
    ),
  )
}

///|
priv struct CompilerDiagnosticSummary {
  message : String
  code : String?
  labels : Array[String]
} derive(Debug)

///|
fn compiler_diagnostic_summary(
  diagnostic : @compiler_diag.CompilerDiagnostic,
) -> CompilerDiagnosticSummary {
  {
    message: diagnostic.message,
    code: diagnostic.code,
    labels: diagnostic.labels.map(fn(label) { label.message }),
  }
}
