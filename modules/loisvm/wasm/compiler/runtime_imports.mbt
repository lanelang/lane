///|
priv struct InternalRuntimeImports {
  f32_to_string : Int?
  f64_to_string : Int?
  host_object_release : Int?
  count : Int
}

///|
fn internal_runtime_imports(
  image : @bytecode.BytecodeImage,
  host_objects_enabled : Bool,
) -> InternalRuntimeImports {
  let mut uses_f32 = false
  let mut uses_f64 = false
  for entry in image.functions {
    if entry is BytecodeBody(body) {
      for block in body.blocks {
        for instruction in block.instructions {
          match instruction {
            F32ToString(_, _) => uses_f32 = true
            F64ToString(_, _) => uses_f64 = true
            _ => ()
          }
        }
      }
    }
  }
  let mut count = 0
  let f32_to_string = if uses_f32 {
    let index = count
    count += 1
    Some(index)
  } else {
    None
  }
  let f64_to_string = if uses_f64 {
    let index = count
    count += 1
    Some(index)
  } else {
    None
  }
  let host_object_release = if host_objects_enabled {
    let index = count
    count += 1
    Some(index)
  } else {
    None
  }
  { f32_to_string, f64_to_string, host_object_release, count }
}

///|
fn append_internal_runtime_imports(
  wasm_module : @wasm_types.Module,
  imports : InternalRuntimeImports,
) -> Unit {
  if imports.f32_to_string is Some(_) {
    append_internal_runtime_import(wasm_module, @internal_abi.F32ToString)
  }
  if imports.f64_to_string is Some(_) {
    append_internal_runtime_import(wasm_module, @internal_abi.F64ToString)
  }
  if imports.host_object_release is Some(_) {
    append_internal_runtime_import(wasm_module, @internal_abi.HostObjectRelease)
  }
}

///|
fn append_internal_runtime_import(
  wasm_module : @wasm_types.Module,
  function : @internal_abi.InternalRuntimeFunction,
) -> Unit {
  let type_ = function.type_()
  let type_index = intern_function_type(
    wasm_module,
    type_.params,
    type_.results,
  )
  wasm_module.imports.push({
    mod_name: @internal_abi.module_name(),
    name: function.name(),
    desc: Func(type_index),
  })
}

///|
fn canonical_runtime_type(
  kind : @bytecode.RuntimeValueKind,
) -> @wasm_types.ValueType? {
  match kind {
    Unit => None
    Bool => Some(I32)
    I64 => Some(I64)
    F64 => Some(F64)
    F32 => Some(F32)
    String => Some(I32)
    Opaque => Some(I32)
  }
}

///|
fn physical_runtime_parameters(
  import_ : @bytecode.RuntimeImport,
) -> Array[@wasm_types.ValueType] {
  let parameters : Array[@wasm_types.ValueType] = []
  for kind in import_.parameters {
    match kind {
      Unit => ()
      Bool => parameters.push(I32)
      I64 => parameters.push(I64)
      F64 => parameters.push(F64)
      F32 => parameters.push(F32)
      Opaque => parameters.push(I64)
      String => {
        parameters.push(I32)
        parameters.push(I32)
      }
    }
  }
  parameters
}

///|
fn runtime_results(
  import_ : @bytecode.RuntimeImport,
) -> Array[@wasm_types.ValueType] {
  match canonical_runtime_type(import_.result) {
    Some(value_type) => [value_type]
    None => []
  }
}

///|
pub fn physical_runtime_parameters_for_import(
  import_ : @bytecode.RuntimeImport,
) -> Array[@wasm_types.ValueType] {
  physical_runtime_parameters(import_)
}

///|
pub fn runtime_results_for_import(
  import_ : @bytecode.RuntimeImport,
) -> Array[@wasm_types.ValueType] {
  runtime_results(import_)
}

///|
fn runtime_import_uses_host_objects(import_ : @bytecode.RuntimeImport) -> Bool {
  import_.result is Opaque || import_.parameters.any(kind => kind is Opaque)
}

///|
fn append_physical_runtime_import(
  wasm_module : @wasm_types.Module,
  import_ : @bytecode.RuntimeImport,
) -> Unit {
  let type_index = intern_function_type(
    wasm_module,
    physical_runtime_parameters(import_),
    runtime_results(import_),
  )
  wasm_module.imports.push({
    mod_name: "lane.runtime.v1",
    name: import_.symbol,
    desc: Func(type_index),
  })
}

///|
fn append_runtime_import_adapter(
  wasm_module : @wasm_types.Module,
  import_ : @bytecode.RuntimeImport,
  abi : @bytecode.CallableAbi,
  physical_import_index : Int,
  runtime : RuntimeFunctions,
) -> Unit {
  let parameters = wasm_callable_parameters(abi)
  let results = wasm_function_results(abi.result)
  let instructions : Array[@wasm_types.Instruction] = []
  let reference_parameters : Array[Int] = []
  let mut parameter_index = 1
  for kind in import_.parameters {
    match kind {
      Unit => ()
      Bool | I64 | F64 | F32 => {
        instructions.push(LocalGet(parameter_index))
        parameter_index += 1
      }
      Opaque => {
        reference_parameters.push(parameter_index)
        instructions.push(LocalGet(parameter_index))
        instructions.push(I64Load(0, 3, 8L))
        parameter_index += 1
      }
      String => {
        reference_parameters.push(parameter_index)
        instructions.push(LocalGet(parameter_index))
        instructions.push(I32Const(12))
        instructions.push(I32Add)
        instructions.push(LocalGet(parameter_index))
        instructions.push(I32Load(0, 2, 8L))
        parameter_index += 1
      }
    }
  }
  instructions.push(Call(physical_import_index))
  let locals : Array[@wasm_types.ValueType] = []
  if results is [result_type] {
    locals.push(result_type)
    instructions.push(LocalSet(parameters.length()))
  }
  for reference_parameter in reference_parameters {
    instructions.push(LocalGet(reference_parameter))
    instructions.push(Call(runtime.release_ref))
  }
  instructions.push(GlobalGet(failure_code_global_index))
  instructions.push(GlobalGet(runtime_import_failed_global_index))
  instructions.push(I32Or)
  instructions.push(If(Empty, [Throw(0)], []))
  if !results.is_empty() {
    instructions.push(LocalGet(parameters.length()))
  }
  append_runtime_function(
    wasm_module, parameters, results, locals, instructions,
  )
}
