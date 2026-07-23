///|
fn jit_function_import_count(module_ : @wasm_types.Module) -> Int {
  let mut count = 0
  for import_ in module_.imports {
    if import_.desc is Func(_) {
      count = count + 1
    }
  }
  count
}

///|
fn jit_function_name(
  module_ : @wasm_types.Module,
  function_index : Int,
) -> String {
  for export_ in module_.exports {
    if export_.desc is Func(index) && index == function_index {
      return export_.name
    }
  }
  "wasm_func_\{function_index}"
}

///|
fn jit_function_names(module_ : @wasm_types.Module) -> Array[String] {
  let function_count = jit_function_import_count(module_) +
    module_.funcs.length()
  Array::makei(function_count, function_index => {
    jit_function_name(module_, function_index)
  })
}

///|
fn jit_module_identity(
  module_ : @wasm_types.Module,
) -> @wasmoon_artifact.ModuleIdentity {
  let encoded = @wasm_encoder.encode(module_)
  @wasmoon_jit.artifact_module_identity(
    "loisvm-in-memory",
    Bytes::from_iter(encoded.iter().map(value => value.to_byte())),
    b"o2-direct-cancel",
  )
}

///|
fn jit_manifest(
  module_ : @wasm_types.Module,
) -> Result[@wasmoon_artifact.CompatibilityManifest, String] {
  let policy : @wasmoon_artifact.CompilationPolicy = {
    optimization_level: O2,
    code_model: Small,
    call_binding: DirectBody,
    cancellation_safepoints: true,
    debug_info: false,
  }
  let manifest = @wasmoon_jit.build_host_artifact_manifest(
    module_identity=jit_module_identity(module_),
    policy~,
  ) catch {
    error =>
      return Err(
        "Wasmoon JIT manifest construction failed: \{error.to_string()}",
      )
  }
  Ok(manifest)
}

///|
fn verify_jit_artifact(
  artifact : @wasmoon_artifact.Artifact,
) -> Result[@wasmoon_jit.LoadedArtifact, String] {
  let compatibility = @wasmoon_jit.artifact_compatibility(
    artifact.manifest,
    available_cpu_features=[],
    runtime_symbols=@wasmoon_jit.wasmoon_runtime_external_symbols(),
    data_symbols=[],
  )
  let loaded = @wasmoon_jit.verify_artifact(artifact, compatibility) catch {
    error =>
      return Err("Wasmoon JIT artifact verification failed: \{to_repr(error)}")
  }
  Ok(loaded)
}

///|
fn compile_wasm_module_for_jit(
  module_ : @wasm_types.Module,
) -> Result[@wasmoon_jit.LoadedArtifact, String] {
  let manifest = match jit_manifest(module_) {
    Ok(manifest) => manifest
    Err(detail) => return Err(detail)
  }
  let target = @wasmoon_jit.host_native_target() catch {
    error =>
      return Err(
        "Wasmoon JIT does not recognize the host target: \{error.to_string()}",
      )
  }
  let environment = @wasmoon.wasm_frontend_embedding_environment(
    cancellation_safepoints=true,
  )
  let translation = @wasm_frontend.translation_context_from_module(
    module_, environment,
  )
  let validation = @wasm_frontend.wasm_validation_context(translation)
  let canonical_type_indices = @wasm_types.compute_canonical_type_indices(
    module_.types,
    type_rec_groups=module_.type_rec_groups,
  )
  let imports : Array[@wasmoon_artifact.ImportIdentity] = []
  let functions : Array[@wasmoon_artifact.FunctionCode] = []
  let mut function_index = 0
  for import_ in module_.imports {
    if import_.desc is Func(type_index) {
      imports.push(
        @wasmoon_jit.wasm_import_identity(
          function_index,
          import_.mod_name,
          import_.name,
          module_.get_func_type(type_index),
        ),
      )
      function_index = function_index + 1
    }
  }
  for local_index, type_index in module_.funcs {
    let function_type = module_.get_func_type(type_index)
    let code = module_.codes[local_index]
    let function = @wasm_frontend.translate_function_body(
      translation,
      jit_function_name(module_, function_index),
      function_type,
      code.locals,
      code.body,
    )
    @milkir.optimize_with_level(function, @milkir.OptLevel::from_int(2))
    |> ignore
    let compiled = @wasmoon_jit.compile_wasm_body_artifact_function(
      function,
      validation,
      target,
      function_index~,
      signature=@wasmoon_jit.wasm_function_signature(function_type),
      use_subtype_indirect_check=false,
      canonical_type_indices~,
    ) catch {
      error =>
        return Err(
          "Wasmoon JIT compilation failed for `\{jit_function_name(module_, function_index)}`: \{error.to_string()}",
        )
    }
    functions.push(compiled)
    function_index = function_index + 1
  }
  verify_jit_artifact({ manifest, imports, functions })
}
