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
fn jit_emit_target(
  target : @wasmoon_cwasm.TargetArch,
) -> Result[@machv_emit.EmitTarget, String] {
  match target {
    X86_64 => Ok(X64)
    AArch64 => Ok(AArch64)
    Unknown => Err("Wasmoon JIT does not recognize the host architecture")
  }
}

///|
fn jit_function_address_fixups(
  compiled : @wasmoon_jit.CompiledFunction,
) -> Result[Array[@wasmoon_cwasm.FuncAddrFixup], String] {
  let fixups : Array[@wasmoon_cwasm.FuncAddrFixup] = []
  for fixup in compiled.get_func_addr_fixups() {
    guard @wasmoon_jit.machv_reloc_target_to_cwasm_func_idx(fixup.target)
      is Some(function_index) else {
      return Err("Wasmoon JIT produced an unsupported function-address fixup")
    }
    fixups.push({
      offset: fixup.offset,
      func_idx: function_index,
      reg: fixup.reg,
    })
  }
  Ok(fixups)
}

///|
fn jit_call_fixups(
  compiled : @wasmoon_jit.CompiledFunction,
) -> Result[Array[@wasmoon_cwasm.CallFixup], String] {
  let fixups : Array[@wasmoon_cwasm.CallFixup] = []
  for fixup in compiled.get_call_fixups() {
    guard @wasmoon_jit.machv_reloc_target_to_cwasm_func_idx(fixup.target)
      is Some(function_index) else {
      return Err("Wasmoon JIT produced an unsupported direct-call fixup")
    }
    fixups.push({
      offset: fixup.offset,
      func_idx: function_index,
      veneer_offset: fixup.veneer_offset,
    })
  }
  Ok(fixups)
}

///|
fn jit_gc_safepoints(
  compiled : @wasmoon_jit.CompiledFunction,
) -> Array[@wasmoon_cwasm.GcSafepoint] {
  let safepoints : Array[@wasmoon_cwasm.GcSafepoint] = []
  for safepoint in compiled.get_gc_safepoints() {
    safepoints.push(
      GcSafepoint(
        safepoint.code_offset,
        safepoint.live_refs,
        safepoint.metadata,
      ),
    )
  }
  safepoints
}

///|
fn compile_wasm_module_for_jit(
  module_ : @wasm_types.Module,
) -> Result[@wasmoon_cwasm.PrecompiledModule, String] {
  let target = @wasmoon_jit.host_target_arch()
  let emit_target = match jit_emit_target(target) {
    Ok(target) => target
    Err(detail) => return Err(detail)
  }
  let precompiled = @wasmoon_cwasm.PrecompiledModule::PrecompiledModule(
    target,
    features=CompilationFeatures(cancellation_safepoints=true),
  )
  for import_ in module_.imports {
    if import_.desc is Func(type_index) {
      let function_type = module_.get_func_type(type_index)
      precompiled.add_import(
        import_.mod_name,
        import_.name,
        function_type.params.length(),
        function_type.results.length(),
      )
    }
  }
  let environment = @wasmoon.wasm_frontend_embedding_environment(
    cancellation_safepoints=true,
  )
  let import_count = jit_function_import_count(module_)
  for local_index, type_index in module_.funcs {
    let function_index = import_count + local_index
    let function_name = jit_function_name(module_, function_index)
    let plan = @wasmoon.plan_wasm_function_with_compiler_infra(
      environment,
      module_,
      local_index,
      emit_target,
      opt_level=2,
    ) catch {
      error =>
        return Err(
          "Wasmoon JIT compilation failed for `\{function_name}`: \{error.to_string()}",
        )
    }
    let compiled = @wasmoon_jit.CompiledFunction::CompiledFunction(
      function_name,
      plan.object,
      0,
    )
    let function_address_fixups = match jit_function_address_fixups(compiled) {
      Ok(fixups) => fixups
      Err(detail) => return Err(detail)
    }
    let call_fixups = match jit_call_fixups(compiled) {
      Ok(fixups) => fixups
      Err(detail) => return Err(detail)
    }
    let function_type = module_.get_func_type(type_index)
    precompiled.add_function(
      @wasmoon_jit.build_cwasm_entry_from_code(
        function_index,
        function_name,
        compiled.get_code(),
        compiled.frame_size,
        compiled.entry_offset,
        function_type.params.length(),
        function_type.results.length(),
        func_addr_fixups=function_address_fixups,
        call_fixups~,
        gc_safepoints=jit_gc_safepoints(compiled),
        gc_stackmap_blob=compiled.get_gc_stackmap_blob(),
      ),
    )
  }
  Ok(precompiled)
}
