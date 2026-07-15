///|
test "unknown compiler intrinsic does not fall through to host linkage" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_ = @buslane.Type::Function([], Primitive(Unit), Empty)
  let value = metadata.define_value("unknown", External, type_)
  let program : @buslane.Program = { metadata, terms: [External(value)] }
  let result : Result[Unit, @buslane_interpreter.BuslaneRuntimeError] = try {
    ignore(
      @buslane_interpreter.evaluate_buslane_program(
        program,
        standard_external_runtime({
          builtins: [{ value, name: "lane.test.unknown", type_ }],
          runtime_imports: [],
        }),
      ),
    )
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_eq(
    result,
    Err(
      @buslane_interpreter.external_failure(
        value, "unsupported compiler intrinsic `lane.test.unknown`",
      ),
    ),
  )
}
