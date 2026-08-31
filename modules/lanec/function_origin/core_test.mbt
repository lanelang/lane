///|
test "function origins follow object identity rather than structural equality" {
  let source : @buslane.FunctionExpr = {
    parameters: [],
    result_type: Primitive(Unit),
    body: Literal(Unit),
  }
  let independent : @buslane.FunctionExpr = {
    parameters: [],
    result_type: Primitive(Unit),
    body: Literal(Unit),
  }
  let rebuilt : @buslane.FunctionExpr = {
    parameters: [],
    result_type: Primitive(Unit),
    body: Literal(Unit),
  }
  let catalog = @function_origin.FunctionOriginCatalog::new()
  assert_true(catalog.record(source, SourceWritten))
  assert_true(catalog.record(independent, HandlerElaboration))
  assert_true(catalog.transfer(source, rebuilt))
  assert_eq(
    (
      catalog.origin(source),
      catalog.origin(independent),
      catalog.origin(rebuilt),
    ),
    (Some(SourceWritten), Some(HandlerElaboration), Some(SourceWritten)),
  )
}

///|
test "function origin snapshots isolate later extensions" {
  let source : @buslane.FunctionExpr = {
    parameters: [],
    result_type: Primitive(Unit),
    body: Literal(Unit),
  }
  let added : @buslane.FunctionExpr = {
    parameters: [],
    result_type: Primitive(I64),
    body: Literal(I64(42L)),
  }
  let original = @function_origin.FunctionOriginCatalog::new()
  assert_true(original.record(source, SourceWritten))
  let snapshot = original.snapshot()
  assert_true(snapshot.record(added, SelectiveCps))
  assert_eq(
    (original.origin(added), snapshot.origin(added)),
    (None, Some(SelectiveCps)),
  )
}

///|
test "Buslane snapshots explicitly transfer function origin identities" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Unit), Empty),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Literal(Unit),
        }),
      ),
    ],
  }
  let catalog = @function_origin.FunctionOriginCatalog::uniform(
    source,
    SourceWritten,
  )
  let (verified, certification_clones) = source
    .certify_with_function_clones()
    .unwrap()
  assert_true(catalog.transfer_clones(certification_clones[:]))
  let (snapshot, access_clones) = verified.program_with_function_clones()
  assert_true(catalog.transfer_clones(access_clones[:]))
  guard snapshot.terms[0] is Let(_, Function(function)) else {
    fail("expected a snapshotted function")
  }
  assert_eq(catalog.origin(function), Some(SourceWritten))
}
