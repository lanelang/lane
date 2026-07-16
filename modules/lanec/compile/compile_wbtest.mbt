///|
fn test_executable_program(
  program : @module_link.LinkedProgram,
) -> @executable.ExecutableProgram {
  match @executable.elaborate(program, program.entries[0]) {
    Ok(executable) => executable
    Err(error) =>
      abort("unexpected executable elaboration error: \{to_repr(error)}")
  }
}

///|
test "compile source records intrinsic and runtime import origins" {
  let result = compile_source(
    (
      #|module Test
      #|pub let int_add : (Int, Int) -> Int = builtin("%i64_add")
      #|let _host : (Int) -> Int = extern("lane.test.host")
      #|let _private_value : Int = 1
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    (
      result.externals.builtins.map(fn(external) { external.name }),
      result.externals.runtime_imports.map(fn(import_) { import_.symbol }),
    ),
    content=(
      #|(["%i64_add"], ["lane.test.host"])
    ),
  )
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="int_add",
  )
  guard result.program is Some(_) else { abort("expected Buslane program") }
}

///|
test "compile verifies handler around effectful function call" {
  let result = compile_source(
    (
      #|module Test
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|pub fn program() -> Int {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.program is Some(program) else {
    abort("expected Buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content="verify_result {}",
  )
}

///|
test "check reports unused local value binding as warning" {
  let result = check_source(
    (
      #|module Test
      #|pub fn answer() -> Int {
      #|  let used = 1
      #|  let unused = 2
      #|  let _ignored = 3
      #|  used
      #|}
    ),
  )
  guard result.source is Some(_) else { abort("expected checked source") }
  debug_inspect(
    result.diagnostics,
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
  let result = compile_modules(
    (
      #|module Test
      #|pub fn answer() -> Int {
      #|  let unused = 1
      #|  0
      #|}
    ),
    [],
  )
  guard result.modules is Some(_) else { abort("expected compiled modules") }
  debug_inspect(
    result.diagnostics,
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
test "check reports unused private top-level declarations as warnings" {
  let result = check_source(
    (
      #|module Test
      #|fn dead_function() -> Int {
      #|  1
      #|}
      #|let dead_value : Int = 2
      #|struct DeadStruct {
      #|  value : Int
      #|}
      #|enum DeadEnum {
      #|  dead()
      #|}
      #|effect DeadEffect {
      #|  dead() -> Unit
      #|}
      #|type DeadAlias = Int
      #|type DeadEffects = { DeadEffect }
      #|pub fn answer() -> Int {
      #|  0
      #|}
    ),
  )
  guard result.source is Some(_) else { abort("expected checked source") }
  debug_inspect(
    result.diagnostics,
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
  let result = check_source(
    (
      #|module Test
      #|struct Box {
      #|  value : Int
      #|}
      #|enum Option {
      #|  some(Box)
      #|  none()
      #|}
      #|effect Console {
      #|  read() -> Int
      #|}
      #|type UI = { Console }
      #|type Task = { UI }
      #|fn helper(value : Option) -> Int ! Task {
      #|  match value {
      #|    some(box) => {
      #|      let _read : Int = Console::read!()
      #|      box.value
      #|    }
      #|    none() => 0
      #|  }
      #|}
      #|pub fn answer() -> Int {
      #|  handle helper(Option::some(Box::{ value: 1 })) with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(_) else { abort("expected checked source") }
}

///|
test "check reports unused generic parameters as warnings" {
  let result = check_source(
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
    result.diagnostics,
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
      #|          start_offset: 71,
      #|          end_offset: 72,
      #|          start_line: 5,
      #|          start_column: 23,
      #|          end_line: 5,
      #|          end_column: 24,
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
      #|            start_offset: 71,
      #|            end_offset: 72,
      #|            start_line: 5,
      #|            start_column: 23,
      #|            end_line: 5,
      #|            end_column: 24,
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
  guard result.source is Some(_) else { abort("expected checked source") }
}

///|
test "check keeps used generic parameters quiet" {
  let result = check_source(
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
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(_) else { abort("expected checked source") }
}

///|
test "check reports unused imports and opens as warnings" {
  let result = check_sources(
    (
      #|module Main
      #|import UsedQualified
      #|import UnusedQualified
      #|import UnusedOpen.*
      #|import OpenLib.*
      #|import SelectiveLib.{ used, unused }
      #|
      #|pub fn answer() -> Int {
      #|  let _qualified = UsedQualified.value
      #|  let _open = open_value
      #|  used
      #|}
    ),
    [
      (
        #|module UsedQualified
        #|pub let value : Int = 1
      ),
      (
        #|module UnusedQualified
        #|pub let value : Int = 2
      ),
      (
        #|module UnusedOpen
        #|pub let value : Int = 3
      ),
      (
        #|module OpenLib
        #|pub let open_value : Int = 4
      ),
      (
        #|module SelectiveLib
        #|pub let used : Int = 5
        #|pub let unused : Int = 6
      ),
    ],
  )
  guard result.source is Some(_) else { abort("expected checked source") }
  debug_inspect(
    result.diagnostics.map(compiler_diagnostic_summary),
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
      #|let value : Option[Int] = none
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="payloadless variant `none` must use empty parentheses",
  )
}

///|
test "compile sources accepts explicit library modules" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources exposes only root public entries" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources accepts selective import with module dot syntax" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.{ value }
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources links only root reachable library modules" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
      (
        #|module Extra
        #|pub let extra : (Int, Int) -> Int = builtin("%i64_add")
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.externals.builtins.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile modules returns separate module objects and interfaces" {
  let result = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : Int
        #|}
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  inspect(modules.root_module_path_text, content="Main")
  inspect(
    modules.modules.map(fn(module_) { module_.module_path_text }).join(","),
    content="Lib,Main",
  )
  guard @module_compile.find_compiled_module(modules.modules, "Lib")
    is Some(lib) else {
    abort("expected Lib module")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Main")
    is Some(main) else {
    abort("expected Main module")
  }
  inspect(lib.interface.values.length(), content="1")
  inspect(lib.object.module_path_text, content="Lib")
  inspect(
    lib.object.exports.map(fn(item) { item.name }).join(","),
    content="Box,Box,Box.value,value",
  )
  inspect(
    main.object.imports
    .map(fn(item) { "\{item.module_path_text}::\{item.name}" })
    .join(","),
    content="Lib::Box,Lib::Box,Lib::Box.value,Lib::value",
  )
}

///|
test "link modules produces Buslane program from reachable module objects" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
      (
        #|module Extra
        #|pub let extra : (Int, Int) -> Int = builtin("%i64_add")
      ),
    ],
  )
  inspect(compiled.diagnostics.length(), content="0")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules(modules)
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(program.module_path_texts.join(","), content="Lib,Main")
  inspect(program.externals.builtins.length(), content="0")
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
  inspect(
    @prettyprinter.render(program.program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 : Int
      #|    value answer#1 : Int
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "link modules remaps effect operations through one identity" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub fn program() -> Int {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(42)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
    [
      (
        #|module Lib
        #|pub effect Console {
        #|  read() -> Int
        #|}
        #|pub fn read_int() -> Int ! Console {
        #|  Console::read!()
        #|}
      ),
    ],
  )
  assert_eq(compiled.diagnostics.length(), 0)
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules(modules)
  assert_eq(linked.diagnostics.length(), 0)
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(program.program.metadata.effects.length(), 1)
  assert_eq(program.program.metadata.operations.length(), 1)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "link modules remaps data constructors through one identity" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let main_flag : Flag = flag
    ),
    [
      (
        #|module Lib
        #|pub enum Flag {
        #|  on()
        #|}
        #|pub let flag : Flag = Flag::on()
      ),
    ],
  )
  assert_eq(compiled.diagnostics.length(), 0)
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules(modules)
  assert_eq(linked.diagnostics.length(), 0)
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(program.program.metadata.types.length(), 1)
  assert_eq(program.program.metadata.data_constructors.length(), 1)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "module artifacts roundtrip through binary, link, and bytecode" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub fn main() -> Unit {
      #|  answer()
      #|}
    ),
    [
      (
        #|module Lib
        #|let host_answer : () -> Unit = extern("lane.test.answer")
        #|pub fn answer() -> Unit {
        #|  host_answer()
        #|}
      ),
    ],
  )
  inspect(compiled.diagnostics.length(), content="0")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let decoded_modules : Array[@module_compile.CompiledModuleArtifact] = []
  for module_ in artifact.modules {
    let interface_binary = @artifact_binary.module_interface_artifact_to_binary(
      module_.interface,
    )
    let object_binary = @artifact_binary.module_object_artifact_to_binary(
      module_.object,
    )
    let interface = match
      @artifact_binary.parse_module_interface_artifact_binary(interface_binary) {
      Ok(interface) => interface
      Err(message) => abort(message)
    }
    let object = match
      @artifact_binary.parse_module_object_artifact_binary(object_binary) {
      Ok(object) => object
      Err(message) => abort(message)
    }
    decoded_modules.push({
      schema_version: module_.schema_version,
      module_path_text: module_.module_path_text,
      interface,
      object,
      module_fingerprint: module_.module_fingerprint,
      imported_interface_fingerprints: module_.imported_interface_fingerprints,
    })
  }
  let linked = @module_compile.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: decoded_modules,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  debug_inspect(
    (
      program.externals.builtins.map(fn(external) { external.name }),
      program.externals.runtime_imports.map(fn(import_) { import_.symbol }),
    ),
    content=(
      #|([], ["lane.test.answer"])
    ),
  )
  let executable = test_executable_program(program)
  let linked_artifact = match
    @artifact_binary.executable_to_loisvm_artifact(executable) {
    Ok(artifact) => artifact
    Err(error) => abort("unexpected LoisVM lowering error: \{to_repr(error)}")
  }
  let runtime_imports = linked_artifact.bytecode.functions.filter_map(fn(
    function,
  ) {
    match function {
      RuntimeImport(import_) => Some(import_)
      BytecodeBody(_) => None
    }
  })
  debug_inspect(
    runtime_imports,
    content=(
      #|[{ abi_major: 1, user_arity: 0, symbol: "lane.test.answer" }]
    ),
  )
  let linked_binary = @artifact_binary.linked_program_artifact_to_binary(
    linked_artifact,
  )
  inspect(byte_prefix_text(linked_binary, 8), content="76,65,78,69,65,82,84,0")
  let linked_decoded = match
    @artifact_binary.parse_linked_program_artifact_binary(linked_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  assert_eq(linked_decoded, linked_artifact)
  assert_eq(
    linked_decoded.schema_version,
    @module_compile.linked_program_artifact_schema_version,
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "effect aliases export through interface artifacts" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub fn program() -> Unit ! Lib.UI {
      #|  let ignored : Int = Console::read!()
      #|  Log::write!("ok")
      #|}
    ),
    [
      (
        #|module Lib
        #|pub effect Console {
        #|  read() -> Int
        #|}
        #|pub effect Log {
        #|  write(String) -> Unit
        #|}
        #|pub type UI = { Console, Log }
      ),
    ],
  )
  debug_inspect(
    compiled.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 67,
      #|          end_offset: 74,
      #|          start_line: 4,
      #|          start_column: 7,
      #|          end_line: 4,
      #|          end_column: 14,
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
      #|            start_offset: 67,
      #|            end_offset: 74,
      #|            start_line: 4,
      #|            start_column: 7,
      #|            end_line: 4,
      #|            end_column: 14,
      #|          },
      #|        ),
      #|        message: "`ignored` is never used",
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
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Lib")
    is Some(lib) else {
    abort("expected Lib")
  }
  let lib_artifact = lib.to_artifact()
  inspect(
    interface_alias_signatures(lib_artifact.interface.interface),
    content=(
      #|UI[]:Effect=effect:{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
  let interface_binary = @artifact_binary.module_interface_artifact_to_binary(
    lib_artifact.interface,
  )
  let decoded_binary = match
    @artifact_binary.parse_module_interface_artifact_binary(interface_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  inspect(
    interface_alias_signatures(decoded_binary.interface),
    content=(
      #|UI[]:Effect=effect:{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
  let inspect_text = match
    @artifact_binary.artifact_binary_to_inspect_text(interface_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(inspect_text),
    content=(
      #|Lane interface artifact
      #|module: Lib
      #|schema: 1
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|interface Lib:
      #|types:
      #|  (none)
      #|effects:
      #|  pub effect Console { read() -> Int }
      #|  pub effect Log { write(String) -> Unit }
      #|type aliases:
      #|  pub type UI : Effect = { Console, Log }
      #|values:
      #|  (none)
      #|
    ),
  )
}

///|
test "built-in Io roundtrips through typed artifacts" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let println : (String) -> Unit ! Io = extern("println")
      #|pub fn run(action : () -> Unit ! Io) -> Unit ! Io {
      #|  action()
      #|}
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifacts = modules.to_artifact()
  let module_ = artifacts.modules[0]
  let interface_binary = @artifact_binary.module_interface_artifact_to_binary(
    module_.interface,
  )
  let decoded_interface = match
    @artifact_binary.parse_module_interface_artifact_binary(interface_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  let object_binary = @artifact_binary.module_object_artifact_to_binary(
    module_.object,
  )
  let decoded_object = match
    @artifact_binary.parse_module_object_artifact_binary(object_binary) {
    Ok(artifact) => artifact
    Err(message) => abort(message)
  }
  debug_inspect(decoded_object == module_.object, content="true")
  inspect(
    decoded_interface.interface.values
    .map(value => {
      value.name + ": " + @prettyprinter.render(value.type_, width=100)
    })
    .join("\n"),
    content=(
      #|println: (String) -> Unit ! Io
      #|run: (() -> Unit ! Io) -> Unit ! Io
    ),
  )
  let object_text = match
    @artifact_binary.artifact_binary_to_inspect_text(object_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(object_text),
    content=(
      #|Lane object artifact
      #|module: Main
      #|schema: 8
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|object:
      #|imports:
      #|  (none)
      #|exports:
      #|  value println
      #|  value run
      #|public entries:
      #|  Main.println : (String) -> Unit ! Io
      #|  Main.run : (() -> Unit ! Io) -> Unit ! Io
      #|compiler intrinsics:
      #|  (none)
      #|runtime imports:
      #|  println : (String) -> Unit ! Io
      #|buslane:
      #|  buslane {
      #|    metadata {
      #|      value println#0 : (String) -> Unit ! Io
      #|      function run#1 : (() -> Unit ! Io) -> Unit ! Io
      #|      parameter action#2 : () -> Unit ! Io
      #|      external println#3 : (String) -> Unit ! Io
      #|    }
      #|    external value#3
      #|    letrec {
      #|      value#1 = fn(value#2) -> Unit {
      #|        value#2()
      #|      }
      #|    }
      #|    let value#0 = value#3
      #|  }
      #|
    ),
  )
}

///|
test "effect alias interface fingerprint tracks body changes" {
  let first_compiled = compile_modules(
    (
      #|module Lib
      #|pub effect Console {
      #|  read() -> Int
      #|}
      #|pub effect Log {
      #|  write(String) -> Unit
      #|}
      #|pub type UI = { Console }
    ),
    [],
  )
  let second_compiled = compile_modules(
    (
      #|module Lib
      #|pub effect Console {
      #|  read() -> Int
      #|}
      #|pub effect Log {
      #|  write(String) -> Unit
      #|}
      #|pub type UI = { Console, Log }
    ),
    [],
  )
  guard first_compiled.modules is Some(first_modules) else {
    abort("expected first modules")
  }
  guard second_compiled.modules is Some(second_modules) else {
    abort("expected second modules")
  }
  guard first_modules.modules.get(0) is Some(first_module) else {
    abort("expected first module")
  }
  guard second_modules.modules.get(0) is Some(second_module) else {
    abort("expected second module")
  }
  inspect(
    first_module.to_artifact().interface.interface_fingerprint ==
    second_module.to_artifact().interface.interface_fingerprint,
    content="false",
  )
}

///|
test "module artifact binary rejects wrong kind" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub fn main() -> Unit {
      #|  ()
      #|}
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let object_binary = @artifact_binary.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  inspect(byte_prefix_text(object_binary, 8), content="76,65,78,69,65,82,84,0")
  if @artifact_binary.parse_module_interface_artifact_binary(object_binary)
    is Err(message) {
    inspect(
      message,
      content="wrong artifact binary kind: expected interface, got object",
    )
  } else {
    abort("expected wrong artifact binary kind")
  }
  let invalid_magic = object_binary.to_array()
  invalid_magic[0] = b'X'
  if @artifact_binary.parse_module_object_artifact_binary(
      Bytes::from_array(invalid_magic),
    )
    is Err(message) {
    inspect(
      message,
      content="invalid artifact binary: expected Lane artifact magic at byte 0",
    )
  } else {
    abort("expected invalid artifact magic")
  }
  let linked = link_modules(modules)
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  let artifact = match
    @artifact_binary.executable_to_loisvm_artifact(
      test_executable_program(program),
    ) {
    Ok(artifact) => artifact
    Err(error) => abort("unexpected LoisVM lowering error: \{to_repr(error)}")
  }
  let program_binary = @artifact_binary.linked_program_artifact_to_binary(
    artifact,
  )
  if @artifact_binary.parse_module_object_artifact_binary(program_binary)
    is Err(message) {
    inspect(
      message,
      content="wrong artifact binary kind: expected object, got program",
    )
  } else {
    abort("expected program binary to fail object parsing")
  }
}

///|
test "missing import with mismatched interface artifact reports candidates" {
  let provider = compile_modules(
    (
      #|module builtins
      #|pub let read_int : Int = 0
    ),
    [],
  )
  debug_inspect(provider.diagnostics, content="[]")
  guard provider.modules is Some(provider_modules) else {
    abort("expected provider modules")
  }
  guard provider_modules.modules.get(0) is Some(provider_module) else {
    abort("expected provider module")
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Builtins.*
      #|pub let answer : Int = read_int
    ),
    [provider_module.to_interface_artifact()],
  )
  guard compiled.diagnostics.get(0) is Some(diagnostic) else {
    abort("expected missing import diagnostic")
  }
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("<root>"),
      #|  message: "missing imported module `Builtins`",
      #|  span: Some(
      #|    Source(
      #|      source_id="<root>",
      #|      span={
      #|        start_offset: 19,
      #|        end_offset: 27,
      #|        start_line: 2,
      #|        start_column: 8,
      #|        end_line: 2,
      #|        end_column: 16,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E4002"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 19,
      #|          end_offset: 27,
      #|          start_line: 2,
      #|          start_column: 8,
      #|          end_line: 2,
      #|          end_column: 16,
      #|        },
      #|      ),
      #|      message: "no explicit input provides this module",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: ["Lane only compiles explicitly provided source files and interface artifacts"],
      #|  helps: ["pass an input whose declared module is `Builtins`, or change the import to one of the listed modules"],
      #|  facts: [
      #|    {
      #|      name: "considered interface artifact",
      #|      value: "declares module `builtins`",
      #|      span: None,
      #|    },
      #|  ],
      #|  suggestions: [
      #|    {
      #|      message: "check the imported module name against the listed explicit inputs",
      #|      edits: [],
      #|      applicability: MaybeIncorrect,
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "module artifact binary inspect renders human readable summaries" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let interface_binary = @artifact_binary.module_interface_artifact_to_binary(
    module_.to_interface_artifact(),
  )
  let object_binary = @artifact_binary.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  let interface_text = match
    @artifact_binary.artifact_binary_to_inspect_text(interface_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  let object_text = match
    @artifact_binary.artifact_binary_to_inspect_text(object_binary) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  inspect(
    artifact_inspect_without_fingerprints(interface_text),
    content=(
      #|Lane interface artifact
      #|module: Main
      #|schema: 1
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|interface Main:
      #|types:
      #|  (none)
      #|effects:
      #|  (none)
      #|type aliases:
      #|  (none)
      #|values:
      #|  pub let answer : Int
      #|
    ),
  )
  inspect(
    artifact_inspect_without_fingerprints(object_text),
    content=(
      #|Lane object artifact
      #|module: Main
      #|schema: 8
      #|
      #|imported interfaces:
      #|  (none)
      #|
      #|object:
      #|imports:
      #|  (none)
      #|exports:
      #|  value answer
      #|public entries:
      #|  Main.answer : Int
      #|compiler intrinsics:
      #|  (none)
      #|runtime imports:
      #|  (none)
      #|buslane:
      #|  buslane {
      #|    metadata {
      #|      value answer#0 : Int
      #|    }
      #|    let value#0 = 42
      #|  }
      #|
    ),
  )
}

///|
test "duplicate imported top-level value from interface artifact reports artifact origin" {
  let lib_modules = compile_modules(
    (
      #|module Lib
      #|pub let answer : Int = 1
    ),
    [],
  )
  guard lib_modules.modules is Some(modules) else {
    abort("expected Lib module")
  }
  guard modules.modules.get(0) is Some(lib_module) else {
    abort("expected compiled Lib module")
  }
  let result = check_source_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = 2
    ),
    [lib_module.to_artifact().interface],
  )
  guard result.diagnostics.length() == 1 else {
    abort("expected one duplicate top-level value diagnostic")
  }
  let diagnostic = result.diagnostics[0]
  inspect(
    [
      diagnostic.message,
      "labels=\{diagnostic.labels.length()}",
      diagnostic.notes.join("|"),
    ].join("\n"),
    content=(
      #|conflicting top-level value `answer`
      #|labels=1
      #|a Lane module has one top-level value namespace|previous definition comes from module `Lib`
    ),
  )
}

///|
test "compile module interface preserves public effects across artifact import" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|pub let value : Int = 42
    ),
    [],
  )
  debug_inspect(lib_compiled.diagnostics, content="[]")
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let interface_binary = @artifact_binary.module_interface_artifact_to_binary(
    lib_artifact.interface,
  )
  let decoded = match
    @artifact_binary.parse_module_interface_artifact_binary(interface_binary) {
    Ok(interface) => interface
    Err(message) => abort(message)
  }
  inspect(
    interface_effect_signatures(decoded.interface),
    content="State[1]{get/0->tparam#0,put/1->Unit}",
  )
  let main_compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.{State}
      #|pub type IntState = { State[Int] }
      #|pub let answer : Int = 42
    ),
    [lib_artifact.interface],
  )
  debug_inspect(main_compiled.diagnostics, content="[]")
}

///|
fn interface_effect_signatures(
  interface : @module_interface.ModuleInterface,
) -> String {
  interface.effects
  .map(fn(effect) {
    let operations = effect.operations
      .map(fn(operation) {
        let result = @prettyprinter.render(operation.result.pretty(), width=100)
        "\{operation.name}/\{operation.payload.length()}->\{result}"
      })
      .join(",")
    "\{effect.name}[\{effect.type_parameters.length()}]{\{operations}}"
  })
  .join(";")
}

///|
fn interface_alias_signatures(
  interface : @module_interface.ModuleInterface,
) -> String {
  interface.type_aliases
  .map(fn(alias_) {
    let parameters = alias_.type_parameters
      .map(fn(parameter) {
        "\{parameter.name}:\{@prettyprinter.render(parameter.kind, width=100)}"
      })
      .join(",")
    "\{alias_.name}[\{parameters}]:\{@prettyprinter.render(alias_.kind, width=100)}=\{interface_alias_body_signature(alias_.body)}"
  })
  .join(";")
}

///|
fn interface_alias_body_signature(
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> String {
  match body {
    TypeBody(type_) => "type:" + @prettyprinter.render(type_, width=100)
    EffectBody(effect) => "effect:" + @prettyprinter.render(effect, width=100)
  }
}

///|
test "module object binary rejects obsolete schema seven artifact" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  let damaged = @artifact_binary.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  ).to_array()
  damaged[14] = b'\x07'
  damaged[15] = b'\x00'
  damaged[16] = b'\x00'
  damaged[17] = b'\x00'
  let parsed = @artifact_binary.parse_module_object_artifact_binary(
    Bytes::from_array(damaged),
  )
  guard parsed is Err(message) else {
    abort("expected old object schema failure")
  }
  inspect(message, content="unsupported object artifact schema version 7")
}

///|
test "link module artifacts orders reachable modules by imports" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  inspect(compiled.diagnostics.length(), content="0")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  guard find_artifact_module(artifact.modules, "Main") is Some(main) else {
    abort("expected Main artifact")
  }
  guard find_artifact_module(artifact.modules, "Lib") is Some(lib) else {
    abort("expected Lib artifact")
  }
  let linked = @module_compile.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: "Main",
    modules: [main, lib],
    reachable_module_path_texts: ["Main", "Lib"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    @prettyprinter.render(program.program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 : Int
      #|    value answer#1 : Int
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
}

///|
test "compile module with interface artifact then link object artifacts" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  inspect(lib_compiled.diagnostics.length(), content="0")
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let main_compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = box.value
    ),
    [lib_artifact.interface],
  )
  inspect(main_compiled.diagnostics.length(), content="0")
  guard main_compiled.modules is Some(main_modules) else {
    abort("expected main modules")
  }
  guard main_modules.modules.get(0) is Some(main_module) else {
    abort("expected Main module")
  }
  let main_artifact = main_module.to_artifact()
  let linked = @module_compile.link_module_object_artifacts([
    lib_artifact.object,
    main_artifact.object,
  ])
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(entry_display_name).join(","),
    content="Lib.box,Main.answer",
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "compile module freshens independently compiled interface symbols" {
  let left_compiled = compile_modules(
    (
      #|module Left
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let left : Box = Box::{ value: 1 }
    ),
    [],
  )
  inspect(left_compiled.diagnostics.length(), content="0")
  guard left_compiled.modules is Some(left_modules) else {
    abort("expected Left modules")
  }
  guard left_modules.modules.get(0) is Some(left_module) else {
    abort("expected Left module")
  }
  let left_artifact = left_module.to_artifact()
  let right_compiled = compile_modules(
    (
      #|module Right
      #|pub struct Box {
      #|  item : Int
      #|}
      #|pub let right : Box = Box::{ item: 2 }
    ),
    [],
  )
  inspect(right_compiled.diagnostics.length(), content="0")
  guard right_compiled.modules is Some(right_modules) else {
    abort("expected Right modules")
  }
  guard right_modules.modules.get(0) is Some(right_module) else {
    abort("expected Right module")
  }
  let right_artifact = right_module.to_artifact()
  let main_compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Left.*
      #|import Right.*
      #|pub fn answer() -> Int {
      #|  let _left = left.value
      #|  right.item
      #|}
    ),
    [left_artifact.interface, right_artifact.interface],
  )
  inspect(main_compiled.diagnostics.length(), content="0")
  guard main_compiled.modules is Some(main_modules) else {
    abort("expected Main modules")
  }
  guard main_modules.modules.get(0) is Some(main_module) else {
    abort("expected Main module")
  }
  let main_artifact = main_module.to_artifact()
  let linked = @module_compile.link_module_artifacts({
    schema_version: 1,
    root_module_path_text: "Main",
    modules: [left_artifact, right_artifact, main_artifact],
    reachable_module_path_texts: ["Left", "Right", "Main"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile module follows transitive interface dependencies without extra pollution" {
  let extra_compiled = compile_modules(
    (
      #|module Extra
      #|pub struct Noise {
      #|  value : Int
      #|}
    ),
    [],
  )
  inspect(extra_compiled.diagnostics.length(), content="0")
  guard extra_compiled.modules is Some(extra_modules) else {
    abort("expected Extra modules")
  }
  guard extra_modules.modules.get(0) is Some(extra_module) else {
    abort("expected Extra module")
  }
  let extra_artifact = extra_module.to_artifact()
  let a_compiled = compile_modules(
    (
      #|module A
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  inspect(a_compiled.diagnostics.length(), content="0")
  guard a_compiled.modules is Some(a_modules) else {
    abort("expected A modules")
  }
  guard a_modules.modules.get(0) is Some(a_module) else {
    abort("expected A module")
  }
  let a_artifact = a_module.to_artifact()
  let b_compiled = compile_module_with_interface_artifacts(
    (
      #|module B
      #|import A.*
      #|pub let forwarded : Box = box
    ),
    [extra_artifact.interface, a_artifact.interface],
  )
  inspect(b_compiled.diagnostics.length(), content="0")
  guard b_compiled.modules is Some(b_modules) else {
    abort("expected B modules")
  }
  guard b_modules.modules.get(0) is Some(b_module) else {
    abort("expected B module")
  }
  let b_artifact = b_module.to_artifact()
  let c_compiled = compile_module_with_interface_artifacts(
    (
      #|module C
      #|import B.*
      #|pub let answer : Int = forwarded.value
    ),
    [b_artifact.interface, a_artifact.interface],
  )
  inspect(c_compiled.diagnostics.length(), content="0")
  guard c_compiled.modules is Some(c_modules) else {
    abort("expected C modules")
  }
  guard c_modules.modules.get(0) is Some(c_module) else {
    abort("expected C module")
  }
  let c_artifact = c_module.to_artifact()
  let linked = @module_compile.link_module_artifacts({
    schema_version: 1,
    root_module_path_text: "C",
    modules: [c_artifact, b_artifact, a_artifact],
    reachable_module_path_texts: ["C", "B", "A"],
  })
  inspect(linked.diagnostics.length(), content="0")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile module reports missing transitive interface dependency" {
  let a_compiled = compile_modules(
    (
      #|module A
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  guard a_compiled.modules is Some(a_modules) else {
    abort("expected A modules")
  }
  guard a_modules.modules.get(0) is Some(a_module) else {
    abort("expected A module")
  }
  let a_artifact = a_module.to_artifact()
  let b_compiled = compile_module_with_interface_artifacts(
    (
      #|module B
      #|import A.*
      #|pub let forwarded : Box = box
    ),
    [a_artifact.interface],
  )
  guard b_compiled.modules is Some(b_modules) else {
    abort("expected B modules")
  }
  guard b_modules.modules.get(0) is Some(b_module) else {
    abort("expected B module")
  }
  let b_artifact = b_module.to_artifact()
  let c_compiled = compile_module_with_interface_artifacts(
    (
      #|module C
      #|import B.*
      #|pub let answer : Int = forwarded.value
    ),
    [b_artifact.interface],
  )
  inspect(c_compiled.diagnostics.length(), content="1")
  inspect(
    c_compiled.diagnostics[0].message,
    content="missing imported module `A`",
  )
}

///|
test "compile module rejects interface artifact name mismatch" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let interface = lib_artifact.interface.interface
  let damaged_interface : @module_interface.ModuleInterface = {
    module_path: "Other",
    source_id: None,
    types: interface.types,
    effects: interface.effects,
    type_aliases: interface.type_aliases,
    values: interface.values,
    optimization_hints: interface.optimization_hints,
  }
  let damaged : @module_compile.ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: damaged_interface,
    interface_fingerprint: lib_artifact.interface.interface_fingerprint,
    module_fingerprint: lib_artifact.interface.module_fingerprint,
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [damaged],
  )
  inspect(compiled.diagnostics.length(), content="1")
  inspect(
    compiled.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "compile module rejects stale interface artifact fingerprint" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let damaged : @module_compile.ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: lib_artifact.interface.interface,
    interface_fingerprint: { value: "stale" },
    module_fingerprint: lib_artifact.interface.module_fingerprint,
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [damaged],
  )
  inspect(compiled.diagnostics.length(), content="1")
  inspect(
    compiled.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "compile module rejects stale interface artifact module fingerprint" {
  let lib_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let damaged : @module_compile.ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: lib_artifact.interface.interface,
    interface_fingerprint: lib_artifact.interface.interface_fingerprint,
    module_fingerprint: { value: "stale" },
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interface_artifacts(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [damaged],
  )
  inspect(compiled.diagnostics.length(), content="1")
  inspect(
    compiled.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "module object fingerprint changes on implementation-only changes" {
  let first_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 1
    ),
    [],
  )
  let second_compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 2
    ),
    [],
  )
  guard first_compiled.modules is Some(first_modules) else {
    abort("expected first modules")
  }
  guard second_compiled.modules is Some(second_modules) else {
    abort("expected second modules")
  }
  guard first_modules.modules.get(0) is Some(first_module) else {
    abort("expected first module")
  }
  guard second_modules.modules.get(0) is Some(second_module) else {
    abort("expected second module")
  }
  let first_artifact = first_module.to_artifact()
  let second_artifact = second_module.to_artifact()
  debug_inspect(
    [
      first_artifact.interface.interface_fingerprint ==
      second_artifact.interface.interface_fingerprint,
      first_artifact.module_fingerprint == second_artifact.module_fingerprint,
      first_artifact.object.object_fingerprint ==
      second_artifact.object.object_fingerprint,
    ],
    content="[true, true, false]",
  )
}

///|
test "link object artifacts rejects stale object fingerprint" {
  let compiled = compile_modules(
    (
      #|module Lib
      #|pub let value : Int = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected module")
  }
  let object = module_.to_object_artifact()
  let damaged : @module_compile.ModuleObjectArtifact = {
    schema_version: object.schema_version,
    module_path_text: object.module_path_text,
    interface_fingerprint: object.interface_fingerprint,
    metadata: object.metadata,
    terms: object.terms,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    module_fingerprint: object.module_fingerprint,
    object_fingerprint: { value: "stale" },
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
  let linked = @module_compile.link_module_object_artifacts([damaged])
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="invalid module object artifact",
  )
}

///|
test "link module artifacts rejects interface object fingerprint mismatch" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged = artifact.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let object : @module_compile.ModuleObjectArtifact = {
        schema_version: module_.object.schema_version,
        module_path_text: module_.object.module_path_text,
        interface_fingerprint: module_.object.interface_fingerprint,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        module_fingerprint: { value: "stale" },
        object_fingerprint: module_.object.object_fingerprint,
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @module_compile.CompiledModuleArtifact::{
        schema_version: module_.schema_version,
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        module_fingerprint: module_.module_fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = @module_compile.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="invalid compiled module artifact",
  )
}

///|
test "link module artifacts rejects interface object name mismatch" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged = artifact.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let interface : @module_compile.ModuleInterfaceArtifact = {
        schema_version: module_.interface.schema_version,
        module_path_text: "Other",
        interface: module_.interface.interface,
        interface_fingerprint: module_.interface.interface_fingerprint,
        module_fingerprint: module_.interface.module_fingerprint,
        imported_interface_fingerprints: module_.interface.imported_interface_fingerprints,
      }
      @module_compile.CompiledModuleArtifact::{
        schema_version: module_.schema_version,
        module_path_text: module_.module_path_text,
        interface,
        object: module_.object,
        module_fingerprint: module_.module_fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = @module_compile.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged,
    reachable_module_path_texts: artifact.reachable_module_path_texts,
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="invalid module interface artifact",
  )
}

///|
test "link modules rejects stale module object fingerprint" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let stale_modules = modules.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let object : @module_compile.ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        interface_fingerprint: module_.object.interface_fingerprint,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        fingerprint: module_.object.fingerprint,
        object_fingerprint: { value: "stale" },
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @module_compile.CompiledModule::{
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_modules({
    root_module_path_text: modules.root_module_path_text,
    modules: stale_modules,
    reachable_module_path_texts: modules.reachable_module_path_texts,
    diagnostics: [],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(linked.diagnostics[0].message, content="stale module object")
}

///|
test "link modules rejects stale imported reference fingerprint" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let damaged_modules = modules.modules.map(fn(module_) {
    if module_.module_path_text == "Main" {
      let imports : Array[@artifact_core.ModuleImportedReference] = module_.object.imports.map(fn(
          imported,
        ) {
          {
            module_path_text: imported.module_path_text,
            kind: imported.kind,
            name: imported.name,
            fingerprint: { value: "stale" },
            type_id: imported.type_id,
            data_constructor: imported.data_constructor,
            effect_id: imported.effect_id,
            operation: imported.operation,
            value: imported.value,
          }
        },
      )
      let object : @module_compile.ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        interface_fingerprint: module_.object.interface_fingerprint,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports,
        fingerprint: module_.object.fingerprint,
        object_fingerprint: @module_compile.module_object_fingerprint(
          module_.object.fingerprint,
          module_.object.interface_fingerprint,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          module_.object.exports,
          imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @module_compile.CompiledModule::{
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_modules({
    root_module_path_text: modules.root_module_path_text,
    modules: damaged_modules,
    reachable_module_path_texts: modules.reachable_module_path_texts,
    diagnostics: [],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(linked.diagnostics[0].message, content="stale imported reference")
}

///|
test "link modules rejects missing exported object value" {
  let compiled = compile_modules(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|pub let value : Int = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let damaged_modules = modules.modules.map(fn(module_) {
    if module_.module_path_text == "Lib" {
      let exports = []
      let object : @module_compile.ModuleObject = {
        module_path_text: module_.object.module_path_text,
        checked: module_.object.checked,
        interface_fingerprint: module_.object.interface_fingerprint,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports,
        imports: module_.object.imports,
        fingerprint: module_.object.fingerprint,
        object_fingerprint: @module_compile.module_object_fingerprint(
          module_.object.fingerprint,
          module_.object.interface_fingerprint,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          exports,
          module_.object.imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @module_compile.CompiledModule::{
        module_path_text: module_.module_path_text,
        interface: module_.interface,
        object,
        fingerprint: module_.fingerprint,
        imported_interface_fingerprints: module_.imported_interface_fingerprints,
      }
    } else {
      module_
    }
  })
  let linked = link_modules({
    root_module_path_text: modules.root_module_path_text,
    modules: damaged_modules,
    reachable_module_path_texts: modules.reachable_module_path_texts,
    diagnostics: [],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="object artifact does not satisfy its interface",
  )
}

///|
test "link modules rejects compiled artifact import cycle" {
  let compiled_a = compile_modules(
    (
      #|module A
      #|pub let a : Int = 1
    ),
    [],
  )
  let compiled_b = compile_modules(
    (
      #|module B
      #|pub let b : Int = 2
    ),
    [],
  )
  guard compiled_a.modules is Some(modules_a) else {
    abort("expected A modules")
  }
  guard compiled_b.modules is Some(modules_b) else {
    abort("expected B modules")
  }
  guard modules_a.modules.get(0) is Some(module_a) else {
    abort("expected A module")
  }
  guard modules_b.modules.get(0) is Some(module_b) else {
    abort("expected B module")
  }
  let module_a = module_with_imported_interfaces(module_a, [
    {
      module_path_text: "B",
      fingerprint: @module_compile.interface_fingerprint(module_b.interface),
    },
  ])
  let module_b = module_with_imported_interfaces(module_b, [
    {
      module_path_text: "A",
      fingerprint: @module_compile.interface_fingerprint(module_a.interface),
    },
  ])
  let linked = link_modules({
    root_module_path_text: "A",
    modules: [module_a, module_b],
    reachable_module_path_texts: ["A", "B"],
    diagnostics: [],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(linked.diagnostics[0].message, content="import cycle involving `A`")
}

///|
test "link modules rejects missing compiled artifact import" {
  let compiled = compile_modules(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else { abort("expected modules") }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected Main module")
  }
  let module_ = module_with_imported_interfaces(module_, [
    { module_path_text: "Missing", fingerprint: { value: "missing" } },
  ])
  let linked = link_modules({
    root_module_path_text: "Main",
    modules: [module_],
    reachable_module_path_texts: ["Main"],
    diagnostics: [],
  })
  inspect(linked.diagnostics.length(), content="1")
  inspect(
    linked.diagnostics[0].message,
    content="missing object artifact for `Missing`",
  )
}

///|
test "check sources does not expose private imported values" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = value
    ),
    [
      (
        #|module Lib
        #|let value : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find value `value`")
}

///|
test "check sources does not expose private imported types" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find type `Hidden`")
}

///|
test "check sources rejects private nominal type escape through public function" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = leak().value
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : Int
        #|}
        #|pub fn leak() -> Hidden {
        #|  Hidden::{ value: 42 }
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
  match result.diagnostics[0].span {
    Some(Source(span~, ..)) => {
      inspect(span.start_line, content="5")
      inspect(span.start_column, content="18")
      inspect(span.end_line, content="5")
      inspect(span.end_column, content="24")
    }
    Some(Local(_)) => abort("expected diagnostic span with source id")
    None => abort("expected diagnostic span")
  }
}

///|
test "check source rejects private nominal type escape through public let" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check source rejects private nominal type escape through public struct field" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub struct Box {
      #|  hidden : Hidden
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check source rejects private nominal type escape through public enum payload" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub enum Box {
      #|  boxed(Hidden)
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check source rejects private nominal type escape through public type alias" {
  let result = check_source(
    (
      #|module Test
      #|struct Hidden {
      #|  value : Int
      #|}
      #|pub type Exposed = Hidden
    ),
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="private type `Hidden` in public interface",
  )
}

///|
test "check sources exposes public imported nominal shape through public value" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Int = point().x
    ),
    [
      (
        #|module Lib
        #|pub struct Point {
        #|  x : Int
        #|}
        #|pub fn point() -> Point {
        #|  Point::{ x: 42 }
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "check sources rejects missing import" {
  let result = check_sources(
    (
      #|module Main
      #|import Missing
      #|pub let answer : Int = 42
    ),
    [],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="missing imported module `Missing`",
  )
}

///|
test "check sources resolves module qualified value access" {
  let result = compile_sources(
    (
      #|module Main
      #|import Core.Int
      #|pub let answer : Int = Core.Int.id(42)
    ),
    [
      (
        #|module Core.Int
        #|pub fn id(value : Int) -> Int {
        #|  value
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not import child module through parent module" {
  let result = check_sources(
    (
      #|module Main
      #|import Core
      #|pub let answer : Int = Core.Int.id(42)
    ),
    [
      (
        #|module Core
        #|pub let marker : Int = 0
      ),
      (
        #|module Core.Int
        #|pub fn id(value : Int) -> Int {
        #|  value
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="cannot find value `Core.Int.id`",
  )
}

///|
test "check sources resolves module qualified nominal type access" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Lib.Box = Lib.Box::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources resolves module qualified type alias access" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Lib.Answer = 42
    ),
    [
      (
        #|module Lib
        #|pub type Answer = Int
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources resolves module qualified variant expressions and patterns" {
  let result = compile_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Int = match Lib.Option::some(42) {
      #|  Lib.Option::some(value) => value
      #|  Lib.Option::none() => 0
      #|}
    ),
    [
      (
        #|module Lib
        #|pub enum Option {
        #|  some(Int)
        #|  none()
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not import child module qualified type through parent module" {
  let result = check_sources(
    (
      #|module Main
      #|import Core
      #|pub fn consume(value : Core.Int.Box) -> Int {
      #|  0
      #|}
    ),
    [
      (
        #|module Core
        #|pub let marker : Int = 0
      ),
      (
        #|module Core.Int
        #|pub struct Box {
        #|  value : Int
        #|}
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="cannot find type `Core.Int.Box`",
  )
}

///|
test "check sources rejects ambiguous module qualified field chain" {
  let result = check_sources(
    (
      #|module Main
      #|import core.int
      #|struct AddField {
      #|  add : Int
      #|}
      #|struct CoreBox {
      #|  int : AddField
      #|}
      #|let core : CoreBox = CoreBox::{ int: AddField::{ add: 1 } }
      #|pub let answer : Int = core.int.add
    ),
    [
      (
        #|module core.int
        #|pub let add : Int = 42
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="ambiguous module-qualified value `core.int.add`",
  )
}

///|
test "check sources rejects duplicate module input" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Main
        #|pub let value : Int = 1
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="duplicate module input `Main`",
  )
}

///|
test "import reachable source inputs ignore unrelated parse diagnostics" {
  let result = @module_frontend.import_reachable_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|import Lib.*
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|pub let value : Int = 42
        ),
      },
      {
        source_id: "file:///Unrelated.lane",
        text: (
          #|module Unrelated
          #|pub let broken : =
        ),
      },
    ],
  )
  match result {
    Ok(inputs) =>
      inspect(
        inputs.map(fn(input) { input.source_id }).join(","),
        content="file:///Main.lane,file:///Lib.lane",
      )
    Err(diagnostics) => {
      inspect(diagnostics.map(fn(diagnostic) { diagnostic.message }).join("\n"))
      fail("expected unrelated parse diagnostics to be ignored")
    }
  }
}

///|
test "import reachable analysis reports reachable parse diagnostics" {
  let result = @analysis.analyze_import_reachable_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|import Lib.*
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|pub let broken : =
        ),
      },
      {
        source_id: "file:///Unrelated.lane",
        text: (
          #|module Unrelated
          #|pub let also_broken : =
        ),
      },
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  debug_inspect(
    result.diagnostics[0].source_id,
    content=(
      #|Some("file:///Lib.lane")
    ),
  )
  inspect(result.diagnostics[0].message, content="unexpected token")
}

///|
test "check sources checks unimported library modules" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Extra
        #|pub let extra : Int = missing
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find value `missing`")
}

///|
test "check sources rejects unimported library import cycle" {
  let result = check_sources(
    (
      #|module Main
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module ExtraA
        #|import ExtraB
        #|pub let value : Int = 1
      ),
      (
        #|module ExtraB
        #|import ExtraA
        #|pub let value : Int = 2
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="import cycle involving `ExtraA`",
  )
}

///|
test "check sources rejects import cycle" {
  let result = check_sources(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Int = 42
    ),
    [
      (
        #|module Lib
        #|import Main
        #|pub let value : Int = 1
      ),
    ],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(
    result.diagnostics[0].message,
    content="import cycle involving `Main`",
  )
}

///|
test "analysis resolves same-file definition and hover" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : Int = 42
        #|
        #|pub let answer : Int = value
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected definition")
  }
  match result.hover_at("file:///Main.lane", 5, 24) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected hover")
  }
  match result.hover_at("file:///Main.lane", 3, 10) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected definition hover")
  }
  inspect(
    result.definition_at("file:///Main.lane", 5, 29) is None,
    content="true",
  )
}

///|
test "analysis traverses explicit generic application" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Box {
        #|  value : Int
        #|}
        #|
        #|pub fn[A] id(value : A) -> A {
        #|  value
        #|}
        #|
        #|pub let answer : Box = id[Box](Box::{ value: 1 })
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 11, 24) {
    Some(location) => inspect(location.span.start_line, content="7")
    None => abort("expected generic callee definition")
  }
  match result.hover_at("file:///Main.lane", 11, 24) {
    Some(hover) =>
      inspect(hover.contents, content="id : forall [A : Type]. (A) -> A")
    None => abort("expected generic callee hover")
  }
  match result.definition_at("file:///Main.lane", 11, 27) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected generic argument type definition")
  }
  debug_inspect(
    result.inlay_hints.map(fn(hint) { hint.label }),
    content=(
      #|["value="]
    ),
  )
}

///|
test "analysis resolves cross-module definition by source identity" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|import Lib.*
        #|
        #|pub let answer : Int = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|
          #|pub let value : Int = 42
        ),
      },
    ],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Lib.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected cross-module definition")
  }
}

///|
test "analysis resolves types fields and variants" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Point {
        #|  x : Int
        #|}
        #|
        #|pub enum Option {
        #|  some(Point)
        #|  none()
        #|}
        #|
        #|pub let point : Point = Point::{ x: 1 }
        #|
        #|pub let field_value : Int = point.x
        #|
        #|pub let wrapped : Option = some(point)
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 12, 18) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected type definition")
  }
  match result.definition_at("file:///Main.lane", 12, 26) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected struct literal type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 12, 32) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 38) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 39) is None,
    content="true",
  )
  match result.hover_at("file:///Main.lane", 3, 13) {
    Some(hover) => inspect(hover.contents, content="type Point : Type")
    None => abort("expected type definition hover")
  }
  match result.definition_at("file:///Main.lane", 14, 35) {
    Some(location) => inspect(location.span.start_line, content="4")
    None => abort("expected field definition")
  }
  match result.hover_at("file:///Main.lane", 4, 3) {
    Some(hover) => inspect(hover.contents, content="x : Int")
    None => abort("expected field definition hover")
  }
  match result.definition_at("file:///Main.lane", 16, 29) {
    Some(location) => inspect(location.span.start_line, content="8")
    None => abort("expected variant definition")
  }
  match result.hover_at("file:///Main.lane", 16, 29) {
    Some(hover) => inspect(hover.contents, content="some(Point)")
    None => abort("expected variant hover")
  }
}

///|
test "analysis hovers handler binders with checked types" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub effect Console {
        #|  read() -> Int
        #|}
        #|pub effect State {
        #|  get() -> Int
        #|}
        #|pub fn answer() -> Int ! State {
        #|  handle Console::read!() with {
        #|    Console::read(resume) => resume(0)
        #|  } final value {
        #|    let _state : Int = State::get!()
        #|    value
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.hover_at("file:///Main.lane", 11, 20) {
    Some(hover) =>
      inspect(hover.contents, content="resume : (Int) -> Int ! State")
    None => abort("expected resume binder hover")
  }
  match result.hover_at("file:///Main.lane", 11, 31) {
    Some(hover) =>
      inspect(hover.contents, content="resume : (Int) -> Int ! State")
    None => abort("expected resume reference hover")
  }
  match result.hover_at("file:///Main.lane", 12, 12) {
    Some(hover) => inspect(hover.contents, content="value : Int")
    None => abort("expected final binder hover")
  }
}

///|
test "analysis narrows struct pattern type references" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Point {
        #|  x : Int
        #|}
        #|
        #|pub fn get_x(point : Point) -> Int {
        #|  match point {
        #|    Point::{ x } => x
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  match result.definition_at("file:///Main.lane", 9, 6) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected pattern type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 9, 13) is None,
    content="true",
  )
}

///|
test "analysis keeps partial definitions when unrelated diagnostics exist" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : Int = 42
        #|
        #|pub let answer : Int = value
        #|
        #|pub let bad : Int = missing
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].message, content="cannot find value `missing`")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected partial definition")
  }
}

///|
test "analysis produces type inlay hints for inferred binders" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = seed
        #|  match local {
        #|    value => value
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 54,
      #|        end_offset: 59,
      #|        start_line: 4,
      #|        start_column: 7,
      #|        end_line: 4,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 87,
      #|        end_offset: 92,
      #|        start_line: 6,
      #|        start_column: 5,
      #|        end_line: 6,
      #|        end_column: 10,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis renders user-facing type names in type inlay hints" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum Option[T] {
        #|  some(T)
        #|  none()
        #|}
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let boxed = some(seed)
        #|  seed
        #|}
      ),
    },
    [],
  )
  inspect(
    result.diagnostics.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 97,
      #|        end_offset: 102,
      #|        start_line: 9,
      #|        start_column: 7,
      #|        end_line: 9,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Option[Int]",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis produces parameter name inlay hints for calls" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum Option {
        #|  some(Int, Bool)
        #|  none()
        #|}
        #|
        #|pub fn choose(left : Int, right : Int) -> Int {
        #|  left
        #|}
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = choose(seed, 1)
        #|  match some(local, true) {
        #|    some(value, flag) => value
        #|    none() => 0
        #|  }
        #|}
      ),
    },
    [],
  )
  inspect(
    result.diagnostics.length(),
    content=(
      #|2
    ),
  )
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 160,
      #|        end_offset: 165,
      #|        start_line: 13,
      #|        start_column: 7,
      #|        end_line: 13,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 175,
      #|        end_offset: 179,
      #|        start_line: 13,
      #|        start_column: 22,
      #|        end_line: 13,
      #|        end_column: 26,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "left=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 181,
      #|        end_offset: 182,
      #|        start_line: 13,
      #|        start_column: 28,
      #|        end_line: 13,
      #|        end_column: 29,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "right=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 221,
      #|        end_offset: 226,
      #|        start_line: 15,
      #|        start_column: 10,
      #|        end_line: 15,
      #|        end_column: 15,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 228,
      #|        end_offset: 232,
      #|        start_line: 15,
      #|        start_column: 17,
      #|        end_line: 15,
      #|        end_column: 21,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Bool",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis does not synthesize constructor parameter hints from payload types" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum List[A] {
        #|  nil()
        #|  cons(A, List[A])
        #|}
        #|
        #|pub fn answer(hd : Int, tl : List[Int]) -> List[Int] {
        #|  List::cons(hd, tl)
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(result.inlay_hints.length(), content="0")
}

///|
test "analysis keeps nested call parameter hints at distinct positions" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn append(left : Int, right : Int) -> Int {
        #|  left
        #|}
        #|
        #|pub fn apply(f : (Int) -> Int, value : Int) -> Int {
        #|  f(value)
        #|}
        #|
        #|pub fn inc(value : Int) -> Int {
        #|  value
        #|}
        #|
        #|pub let answer : Int = append(1, apply(inc, 2))
      ),
    },
    [],
  )
  inspect(
    result.diagnostics.length(),
    content=(
      #|1
    ),
  )
  assert_no_duplicate_parameter_hint_positions(result.inlay_hints)
}

///|
test "analysis anchors field argument parameter hint at argument start" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Box {
        #|  field : Int
        #|}
        #|
        #|pub fn take(arg : Int) -> Int {
        #|  arg
        #|}
        #|
        #|pub fn answer(value : Box) -> Int {
        #|  take(value.field)
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 131,
      #|        end_offset: 142,
      #|        start_line: 12,
      #|        start_column: 8,
      #|        end_line: 12,
      #|        end_column: 19,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "arg=",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis skips parameter name inlay hints for source operators" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn op_add(left : Int, right : Int) -> Int {
        #|  left
        #|}
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = seed + 1
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(
    result.diagnostics.length(),
    content=(
      #|1
    ),
  )
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 112,
      #|        end_offset: 117,
      #|        start_line: 8,
      #|        start_column: 7,
      #|        end_line: 8,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis produces implicit argument inlay hints for auto offers" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
        #|  op.add(a, b)
        #|}
        #|
        #|offer int_add_ops : Add[Int] = Add::{ add: fn(a : Int, b : Int) -> Int { builtin("%i64_add")(a, b) } }
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = seed + 1
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 275,
      #|        end_offset: 280,
      #|        start_line: 14,
      #|        start_column: 7,
      #|        end_line: 14,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 290,
      #|        end_offset: 291,
      #|        start_line: 14,
      #|        start_column: 22,
      #|        end_line: 14,
      #|        end_column: 23,
      #|      },
      #|    },
      #|    kind: ImplicitArgumentHint,
      #|    label: ", op=int_add_ops",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis combines implicit argument inlay hints at the call end" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub struct Eq[A] {
        #|  eq : (A, A) -> Bool
        #|}
        #|
        #|pub fn[A] choose(a : A, b : A, auto op : Add[A], auto eq : Eq[A]) -> A {
        #|  if eq.eq(a, b) {
        #|    op.add(a, b)
        #|  } else {
        #|    a
        #|  }
        #|}
        #|
        #|offer int_add_ops : Add[Int] = Add::{ add: fn(a : Int, b : Int) -> Int { builtin("%i64_add")(a, b) } }
        #|offer int_eq_ops : Eq[Int] = Eq::{ eq: fn(a : Int, b : Int) -> Bool { builtin("%i64_equal")(a, b) } }
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = choose(seed, 1)
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  inspect(
    implicit_inlay_hint_labels(result.inlay_hints).join("\n"),
    content=", op=int_add_ops, eq=int_eq_ops",
  )
}

///|
test "analysis does not mark explicit named auto arguments as implicit" {
  let result = @analysis.analyze_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
        #|  op.add(a, b)
        #|}
        #|
        #|let int_add_ops : Add[Int] = Add::{ add: fn(a : Int, b : Int) -> Int { builtin("%i64_add")(a, b) } }
        #|
        #|pub fn answer(seed : Int) -> Int {
        #|  let local = op_add(seed, 1, op=int_add_ops)
        #|  local
        #|}
      ),
    },
    [],
  )
  inspect(result.diagnostics.length(), content="0")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 273,
      #|        end_offset: 278,
      #|        start_line: 14,
      #|        start_column: 7,
      #|        end_line: 14,
      #|        end_column: 12,
      #|      },
      #|    },
      #|    kind: TypeHint,
      #|    label: ": Int",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 288,
      #|        end_offset: 292,
      #|        start_line: 14,
      #|        start_column: 22,
      #|        end_line: 14,
      #|        end_column: 26,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "a=",
      #|  },
      #|  {
      #|    location: {
      #|      source_id: "file:///Main.lane",
      #|      span: {
      #|        start_offset: 294,
      #|        end_offset: 295,
      #|        start_line: 14,
      #|        start_column: 28,
      #|        end_line: 14,
      #|        end_column: 29,
      #|      },
      #|    },
      #|    kind: ParameterHint,
      #|    label: "b=",
      #|  },
      #|]
    ),
  )
}

///|
fn find_artifact_module(
  modules : Array[@module_compile.CompiledModuleArtifact],
  module_path_text : String,
) -> @module_compile.CompiledModuleArtifact? {
  for module_ in modules {
    if module_.module_path_text == module_path_text {
      return Some(module_)
    }
  }
  None
}

///|
fn implicit_inlay_hint_labels(
  hints : Array[@analysis.InlayHintEntry],
) -> Array[String] {
  let labels = []
  for hint in hints {
    match hint.kind {
      ImplicitArgumentHint => labels.push(hint.label)
      _ => ()
    }
  }
  labels
}

///|
priv struct CompilerDiagnosticSummary {
  message : String
  code : String?
  labels : Array[String]
} derive(Debug)

///|
fn compiler_diagnostic_summary(
  diagnostic : CompilerDiagnostic,
) -> CompilerDiagnosticSummary {
  {
    message: diagnostic.message,
    code: diagnostic.code,
    labels: diagnostic.labels.map(fn(label) { label.message }),
  }
}

///|
fn assert_no_duplicate_parameter_hint_positions(
  hints : Array[@analysis.InlayHintEntry],
) -> Unit {
  let positions = []
  for hint in hints {
    guard hint.kind is ParameterHint else { continue }
    let position = "\{hint.location.source_id}:\{hint.location.span.start_line}:\{hint.location.span.start_column}"
    if positions.contains(position) {
      abort("duplicate parameter inlay hint position: \{position}")
    }
    positions.push(position)
  }
}

///|
fn byte_prefix_text(bytes : Bytes, count : Int) -> String {
  let values = []
  let length = if bytes.length() < count { bytes.length() } else { count }
  for index in 0..<length {
    values.push(bytes[index].to_int().to_string())
  }
  values.join(",")
}

///|
fn artifact_inspect_without_fingerprints(text : String) -> String {
  let lines = []
  for line in text.split("\n") {
    let line = line.to_owned()
    if !line.has_prefix("interface fingerprint:") &&
      !line.has_prefix("module fingerprint:") &&
      !line.has_prefix("object fingerprint:") {
      lines.push(line)
    }
  }
  lines.join("\n")
}

///|
fn entry_display_name(entry : @buslane_lowering.BuslaneEntry) -> String {
  "\{entry.module_path_text}.\{entry.name}"
}

///|
fn module_with_imported_interfaces(
  module_ : @module_compile.CompiledModule,
  imported : Array[@artifact_core.ImportedInterfaceFingerprint],
) -> @module_compile.CompiledModule {
  let object : @module_compile.ModuleObject = {
    module_path_text: module_.object.module_path_text,
    checked: module_.object.checked,
    interface_fingerprint: module_.object.interface_fingerprint,
    metadata: module_.object.metadata,
    terms: module_.object.terms,
    externals: module_.object.externals,
    entries: module_.object.entries,
    exports: module_.object.exports,
    imports: module_.object.imports,
    fingerprint: module_.object.fingerprint,
    object_fingerprint: @module_compile.module_object_fingerprint(
      module_.object.fingerprint,
      module_.object.interface_fingerprint,
      module_.object.metadata,
      module_.object.terms,
      module_.object.externals,
      module_.object.entries,
      module_.object.exports,
      module_.object.imports,
      imported,
    ),
    imported_interface_fingerprints: imported,
  }
  {
    module_path_text: module_.module_path_text,
    interface: module_.interface,
    object,
    fingerprint: module_.fingerprint,
    imported_interface_fingerprints: imported,
  }
}
