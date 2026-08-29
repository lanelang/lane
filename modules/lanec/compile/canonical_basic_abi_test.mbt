///|
test "canonical Basic ABI rejects malformed tuple and list providers once" {
  let cases = [
    (
      (
        #|module Main
        #|import Basic.Data.Tuple
        #|pub let pair : (I64, Bool) = (1, true)
      ),
      (
        #|module Basic.Data.Tuple
        #|pub enum Tuple[A, B] {
        #|  tuple(B, A)
        #|}
      ),
      "Basic.Data.Tuple.Tuple",
      "the declaration must be `enum Tuple[A, B] { tuple(A, B) }`",
    ),
    (
      (
        #|module Main
        #|import Basic.Data.List
        #|pub let values : Basic.Data.List.List[I64] = [1, 2]
      ),
      (
        #|module Basic.Data.List
        #|pub enum List[T] {
        #|  empty()
        #|  cons(List[T], T)
        #|}
      ),
      "Basic.Data.List.List",
      "the declaration must be `enum List[T] { empty(); cons(T, List[T]) }`",
    ),
  ]
  for case in cases {
    let (root, provider, provider_name, reason) = case
    let outcome = check({
      root: { source_id: "main", text: root, },
      libraries: [{ source_id: "provider", text: provider, }],
    })
    guard outcome is Failed(failure) else {
      fail("malformed canonical Basic provider unexpectedly typechecked")
    }
    let diagnostics = failure.diagnostics()
    assert_eq(
      diagnostics.map(fn(diagnostic) {
        (
          diagnostic.code,
          diagnostic.message,
          diagnostic.labels.map(fn(label) { label.message }),
        )
      }),
      [
        (
          Some("E3039"),
          "invalid canonical Basic provider `\{provider_name}`",
          [reason],
        ),
      ],
    )
  }
}

///|
test "canonical Basic ABI reports one diagnostic for a missing syntax provider" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|pub let pair : (I64, Bool) = (1, true)
      ),
    },
    libraries: [],
  })
  guard outcome is Failed(failure) else {
    fail("missing canonical Tuple provider unexpectedly typechecked")
  }
  assert_eq(
    failure
    .diagnostics()
    .map(fn(diagnostic) { (diagnostic.code, diagnostic.message) }),
    [
      (
        Some("E3039"),
        "invalid canonical Basic provider `Basic.Data.Tuple.Tuple`",
      ),
    ],
  )
}

///|
test "canonical Basic ABI groups repeated demands at their first source occurrence" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|pub let first : (I64, Bool) = (1, true)
        #|pub let second : (String, F64) = ("lane", 2.0)
      ),
    },
    libraries: [],
  })
  guard outcome is Failed(failure) else {
    fail("missing canonical Tuple provider unexpectedly typechecked")
  }
  debug_inspect(
    failure.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("main"),
      #|    message: "invalid canonical Basic provider `Basic.Data.Tuple.Tuple`",
      #|    span: Some(
      #|      Source(
      #|        source_id="main",
      #|        span={
      #|          start_offset: 28,
      #|          end_offset: 39,
      #|          start_line: 2,
      #|          start_column: 17,
      #|          end_line: 2,
      #|          end_column: 28,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3039"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="main",
      #|          span={
      #|            start_offset: 28,
      #|            end_offset: 39,
      #|            start_line: 2,
      #|            start_column: 17,
      #|            end_line: 2,
      #|            end_column: 28,
      #|          },
      #|        ),
      #|        message: "the required public enum is missing",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["compiler-owned language features require the declared canonical Basic ABI"],
      #|    helps: ["provide the canonical Basic module and declaration with the required public shape"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "canonical Basic ABI diagnoses distinct providers in demand order" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|pub fn values() -> Unit {
        #|  let _values = [1, 2];
        #|  ()
        #|}
        #|pub fn pair() -> Unit {
        #|  let _pair = (1, true);
        #|  ()
        #|}
        #|pub fn more_values() -> Unit {
        #|  let _values = [3, 4];
        #|  ()
        #|}
      ),
    },
    libraries: [],
  })
  guard outcome is Failed(failure) else {
    fail("missing canonical providers unexpectedly typechecked")
  }
  debug_inspect(
    failure.diagnostics(),
    content=(
      #|[
      #|  {
      #|    source_id: Some("main"),
      #|    message: "invalid canonical Basic provider `Basic.Data.List.List`",
      #|    span: Some(
      #|      Source(
      #|        source_id="main",
      #|        span={
      #|          start_offset: 54,
      #|          end_offset: 60,
      #|          start_line: 3,
      #|          start_column: 17,
      #|          end_line: 3,
      #|          end_column: 23,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3039"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="main",
      #|          span={
      #|            start_offset: 54,
      #|            end_offset: 60,
      #|            start_line: 3,
      #|            start_column: 17,
      #|            end_line: 3,
      #|            end_column: 23,
      #|          },
      #|        ),
      #|        message: "the required public enum is missing",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["compiler-owned language features require the declared canonical Basic ABI"],
      #|    helps: ["provide the canonical Basic module and declaration with the required public shape"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("main"),
      #|    message: "invalid canonical Basic provider `Basic.Data.Tuple.Tuple`",
      #|    span: Some(
      #|      Source(
      #|        source_id="main",
      #|        span={
      #|          start_offset: 107,
      #|          end_offset: 116,
      #|          start_line: 7,
      #|          start_column: 15,
      #|          end_line: 7,
      #|          end_column: 24,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3039"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="main",
      #|          span={
      #|            start_offset: 107,
      #|            end_offset: 116,
      #|            start_line: 7,
      #|            start_column: 15,
      #|            end_line: 7,
      #|            end_column: 24,
      #|          },
      #|        ),
      #|        message: "the required public enum is missing",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["compiler-owned language features require the declared canonical Basic ABI"],
      #|    helps: ["provide the canonical Basic module and declaration with the required public shape"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "canonical Basic ABI resolves providers from the module input closure" {
  let outcome = check({
    root: {
      source_id: "main",
      text: (
        #|module Main
        #|import Facade.{ provided }
        #|pub let local : (I64, Bool) = (1, true)
        #|pub let imported : (I64, Bool) = provided
      ),
    },
    libraries: [
      {
        source_id: "tuple",
        text: (
          #|module Basic.Data.Tuple
          #|pub enum Tuple[A, B] {
          #|  tuple(A, B)
          #|}
        ),
      },
      {
        source_id: "facade",
        text: (
          #|module Facade
          #|import Basic.Data.Tuple.{ Tuple }
          #|pub let provided : Tuple[I64, Bool] = (1, true)
        ),
      },
    ],
  })
  assert_true(outcome is Succeeded(_))
}
