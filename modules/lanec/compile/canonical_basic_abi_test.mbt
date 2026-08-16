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
      root: { source_id: "main", text: root },
      libraries: [{ source_id: "provider", text: provider }],
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
