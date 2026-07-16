///|
pub(all) suberror WasmCompileError {
  UnsupportedInstruction(function_id~ : Int, instruction~ : String)
  InvalidBlockTarget(function_id~ : Int, target~ : Int)
  InvalidEdgeArity(
    function_id~ : Int,
    target~ : Int,
    expected~ : Int,
    actual~ : Int
  )
  MissingStringLayout
  ValidationFailure(detail~ : String)
} derive(Debug, Eq)

///|
pub fn compile(
  image : @bytecode.BytecodeImage,
) -> Result[@wasm_types.Module, WasmCompileError] {
  match @compiler.compile(image) {
    Ok(wasm_module) => validate_compiled_module(wasm_module)
    Err(error) => Err(import_compile_error(error))
  }
}

///|
fn validate_compiled_module(
  wasm_module : @wasm_types.Module,
) -> Result[@wasm_types.Module, WasmCompileError] {
  @validator.validate_module(wasm_module) catch {
    error =>
      return Err(
        ValidationFailure(detail=@validator.format_validation_error(error)),
      )
  }
  Ok(wasm_module)
}

///|
fn import_compile_error(error : @compiler.WasmCompileError) -> WasmCompileError {
  match error {
    UnsupportedInstruction(function_id~, instruction~) =>
      UnsupportedInstruction(function_id~, instruction~)
    InvalidBlockTarget(function_id~, target~) =>
      InvalidBlockTarget(function_id~, target~)
    InvalidEdgeArity(function_id~, target~, expected~, actual~) =>
      InvalidEdgeArity(function_id~, target~, expected~, actual~)
    MissingStringLayout => MissingStringLayout
    ValidationFailure(detail~) => ValidationFailure(detail~)
  }
}
