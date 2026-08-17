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
fn compile_runtime_import_adapter(
  import_ : @bytecode.RuntimeImport,
  abi : @bytecode.CallableAbi,
  physical_import : WasmFunctionHandle,
  catalog : WasmFunctionCatalog,
) -> @wasm_types.FunctionCode {
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
  instructions.push(physical_import.call())
  let locals : Array[@wasm_types.ValueType] = []
  if results is [result_type] {
    locals.push(result_type)
    instructions.push(LocalSet(parameters.length()))
  }
  for reference_parameter in reference_parameters {
    instructions.push(LocalGet(reference_parameter))
    instructions.push(catalog.runtime(ReleaseReference).call())
  }
  instructions.push(GlobalGet(failure_code_global_index))
  instructions.push(GlobalGet(runtime_import_failed_global_index))
  instructions.push(I32Or)
  instructions.push(If(Empty, [Throw(0)], []))
  if !results.is_empty() {
    instructions.push(LocalGet(parameters.length()))
  }
  { locals, body: instructions }
}
