///|
fn physical_runtime_parameters(
  import_ : @wasm_abi.ImportContract,
) -> Array[@wasm_types.ValueType] {
  import_.core_parameters().map(core_value_type)
}

///|
fn runtime_results(
  import_ : @wasm_abi.ImportContract,
) -> Array[@wasm_types.ValueType] {
  import_.core_results().map(core_value_type)
}

///|
pub fn physical_runtime_parameters_for_import(
  import_ : @wasm_abi.ImportContract,
) -> Array[@wasm_types.ValueType] {
  physical_runtime_parameters(import_)
}

///|
pub fn runtime_results_for_import(
  import_ : @wasm_abi.ImportContract,
) -> Array[@wasm_types.ValueType] {
  runtime_results(import_)
}

///|
fn compile_runtime_import_adapter(
  import_ : @wasm_abi.ImportContract,
  abi : @physical.CallableAbi,
  physical_import : WasmFunctionHandle,
) -> @wasm_types.FunctionCode {
  let parameters = wasm_callable_parameters(abi)
  let results = wasm_function_results(abi.result)
  let instructions : Array[@wasm_types.Instruction] = []
  let mut parameter_index = 1
  for kind in import_.parameters {
    match kind {
      ErasedUnit => ()
      Direct(_) | GuestAddress => {
        instructions.push(LocalGet(parameter_index))
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
  instructions.push(GlobalGet(failure_code_global_index))
  instructions.push(If(Empty, [Throw(0)], []))
  if !results.is_empty() {
    instructions.push(LocalGet(parameters.length()))
  }
  { locals, body: instructions, }
}

///|
fn core_value_type(type_ : @wasm_abi.CoreValueType) -> @wasm_types.ValueType {
  match type_ {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
  }
}
