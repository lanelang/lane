///|
test "module object preserves numeric conversion intrinsics" {
  let compiled = compile_modules_for_test(
    (
      #|module NumericConversions
      #|
      #|pub let i64_to_f64 : (I64) -> F64 = builtin("%i64_to_f64")
      #|pub let f64_to_i64 : (F64) -> I64 = builtin("%f64_to_i64")
      #|pub let f32_to_string : (F32) -> String = builtin("%f32_to_string")
      #|pub let f64_to_string : (F64) -> String = builtin("%f64_to_string")
    ),
    [],
  )
  assert_eq(compiled.diagnostics, [])
  guard compiled.modules is Some(modules) && modules.modules is [module_] else {
    abort("expected one compiled module")
  }
  let binary = @artifact.module_object_artifact_to_binary(
    module_.to_object_artifact(),
  )
  let decoded = match @artifact.parse_module_object_artifact_binary(binary) {
    Ok(decoded) => decoded
    Err(message) => abort(message)
  }
  assert_eq(
    decoded.externals.builtins.map(external => external.intrinsic.name()),
    ["%i64_to_f64", "%f64_to_i64", "%f32_to_string", "%f64_to_string"],
  )
}
