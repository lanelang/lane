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
