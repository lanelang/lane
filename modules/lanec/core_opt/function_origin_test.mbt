///|
test "origin-preserving optimization rejects an unowned function" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(
    @core_opt.optimize_preserving_function_origins(
      { program, entry, roots: [], },
      @function_origin.FunctionOriginCatalog::new(),
    ),
    Err(MissingFunctionOriginCompilerDefect),
  )
}
