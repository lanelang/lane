///|
pub(all) struct RuntimeImportSignature {
  symbol : String
  parameters : Array[@loisvm_runtime.PrimitiveKind]
  result : @loisvm_runtime.PrimitiveKind
} derive(Debug, Eq)

///|
pub fn RuntimeImportSignature::new(
  symbol~ : String,
  parameters~ : Array[@loisvm_runtime.PrimitiveKind],
  result~ : @loisvm_runtime.PrimitiveKind,
) -> RuntimeImportSignature {
  { symbol, parameters, result }
}

///|
fn RuntimeImportSignature::from_binding(
  binding : @loisvm_runtime.RuntimeBinding,
) -> RuntimeImportSignature {
  {
    symbol: binding.symbol(),
    parameters: binding.parameters(),
    result: binding.result(),
  }
}

///|
fn canonical_runtime_type(
  kind : @loisvm_runtime.PrimitiveKind,
) -> @wasm_types.ValueType? {
  match kind {
    Unit => None
    Bool => Some(I32)
    Int => Some(I64)
    Double => Some(F64)
    String => Some(I32)
  }
}

///|
fn physical_runtime_parameters(
  import_ : RuntimeImportSignature,
) -> Array[@wasm_types.ValueType] {
  let parameters : Array[@wasm_types.ValueType] = []
  for kind in import_.parameters {
    match kind {
      Unit => ()
      Bool => parameters.push(I32)
      Int => parameters.push(I64)
      Double => parameters.push(F64)
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
  import_ : RuntimeImportSignature,
) -> Array[@wasm_types.ValueType] {
  match canonical_runtime_type(import_.result) {
    Some(value_type) => [value_type]
    None => []
  }
}

///|
pub fn physical_runtime_parameters_for_binding(
  binding : @loisvm_runtime.RuntimeBinding,
) -> Array[@wasm_types.ValueType] {
  physical_runtime_parameters(RuntimeImportSignature::from_binding(binding))
}

///|
pub fn runtime_results_for_binding(
  binding : @loisvm_runtime.RuntimeBinding,
) -> Array[@wasm_types.ValueType] {
  runtime_results(RuntimeImportSignature::from_binding(binding))
}

///|
fn append_physical_runtime_import(
  wasm_module : @wasm_types.Module,
  import_ : RuntimeImportSignature,
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
  import_ : RuntimeImportSignature,
  physical_import_index : Int,
  runtime : RuntimeFunctions,
) -> Unit {
  let parameters : Array[@wasm_types.ValueType] = [I32]
  for kind in import_.parameters {
    if canonical_runtime_type(kind) is Some(value_type) {
      parameters.push(value_type)
    }
  }
  let results = runtime_results(import_)
  let instructions : Array[@wasm_types.Instruction] = []
  let string_parameters : Array[Int] = []
  let mut parameter_index = 1
  for kind in import_.parameters {
    match kind {
      Unit => ()
      Bool | Int | Double => {
        instructions.push(LocalGet(parameter_index))
        parameter_index += 1
      }
      String => {
        string_parameters.push(parameter_index)
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
  for string_parameter in string_parameters {
    instructions.push(LocalGet(string_parameter))
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
