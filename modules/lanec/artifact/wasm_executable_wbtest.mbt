///|
test "compiler-produced Wasm must validate before becoming an artifact" {
  let invalid = @wasm_types.Module::empty()
  invalid.exports.push({ name: "missing", desc: Func(0), })
  match certify_wasm_module(invalid) {
    Err(EncodedModuleInvalid(_)) => ()
    Err(error) => abort("unexpected certification failure: \{Repr(error)}")
    Ok(_) => abort("invalid compiler-produced Wasm was certified")
  }
}
