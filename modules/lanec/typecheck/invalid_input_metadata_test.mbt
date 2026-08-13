///|
fn resolved_source_with_errors(source : String) -> @resolve.ResolveResult {
  let parsed = @parser.parse_string(source)
  guard parsed.syntax() is Some(syntax) else { abort("expected source syntax") }
  @resolve.resolve_source_file_result(syntax)
}

///|
test "typecheck rejects unresolved values as invalid input metadata" {
  let resolved = resolved_source_with_errors(
    (
      #|module Test
      #|pub fn answer() -> I64 {
      #|  missing
      #|}
    ),
  )
  assert_false(resolved.diagnostics.is_empty())
  guard @typecheck.typecheck_source_file(resolved.source)
    is Err(InvalidInputMetadata([UnresolvedValue(name="missing", ..)])) else {
    fail("expected unresolved value metadata to be rejected")
  }
}

///|
test "declaration typecheck rejects unresolved types as invalid input metadata" {
  let resolved = resolved_source_with_errors(
    (
      #|module Test
      #|pub struct Bad {
      #|  value : Missing
      #|}
    ),
  )
  assert_false(resolved.diagnostics.is_empty())
  guard @typecheck.typecheck_declarations(resolved.source)
    is Err(InvalidInputMetadata([UnresolvedType(name="Missing", ..)])) else {
    fail("expected unresolved type metadata to be rejected")
  }
}
