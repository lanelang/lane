///|
fn dependency_failure_codes(
  root : @module_frontend.SourceInput,
  libraries : Array[@module_frontend.SourceInput],
) -> Array[(String?, String?)] {
  match check({ root, libraries, }) {
    Failed(failure) =>
      failure
      .diagnostics()
      .map(fn(diagnostic) { (diagnostic.source_id, diagnostic.code) })
    Succeeded(_, _) => abort("expected dependency checking to fail")
  }
}

///|
test "compile reports only reachable parse failures" {
  let root : @module_frontend.SourceInput = {
    source_id: "file:///Main.lane",
    text: "module Main\nimport Broken\npub let answer : I64 = 42",
  }
  let broken : @module_frontend.SourceInput = {
    source_id: "file:///Broken.lane",
    text: "module Broken\npub let value : =",
  }
  assert_eq(dependency_failure_codes(root, [broken]), [
    (Some("file:///Broken.lane"), Some("E1100")),
  ])
  guard check({
      root: {
        source_id: "file:///Independent.lane",
        text: "module Independent\npub let answer : I64 = 42",
      },
      libraries: [broken],
    })
    is Succeeded(_, warnings) else {
    fail("an unrelated invalid source must not block compilation")
  }
  assert_eq(warnings.diagnostics(), [])
}

///|
test "compile dependency failures have one stable classification" {
  assert_eq(
    dependency_failure_codes(
      {
        source_id: "file:///Missing.lane",
        text: "module MissingRoot\nimport Absent\npub let answer : I64 = 42",
      },
      [],
    ),
    [(Some("file:///Missing.lane"), Some("E4002"))],
  )
  assert_eq(
    dependency_failure_codes(
      {
        source_id: "file:///A.lane",
        text: "module A\nimport B\npub let a : I64 = 1",
      },
      [
        {
          source_id: "file:///B.lane",
          text: "module B\nimport A\npub let b : I64 = 2",
        },
      ],
    ),
    [(Some("file:///B.lane"), Some("E4003"))],
  )
  assert_eq(
    dependency_failure_codes(
      {
        source_id: "file:///Root.lane",
        text: "module Root\npub let answer : I64 = 42",
      },
      [
        {
          source_id: "file:///Duplicate.lane",
          text: "module Root\npub let duplicate : I64 = 1",
        },
      ],
    ),
    [(Some("file:///Duplicate.lane"), Some("E4001"))],
  )
}
