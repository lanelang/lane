///|
pub(all) struct WasmFunctionScale {
  index : Int
  instruction_count : Int
  local_count : Int
} derive(Debug, Eq)

///|
pub(all) struct WasmModuleScale {
  imported_function_count : Int
  defined_function_count : Int
  instruction_count : Int
  local_count : Int
  table_entry_count : Int
  functions : Array[WasmFunctionScale]
} derive(Debug, Eq)

///|
/// Aggregates scale facts recorded by the Wasm function-emission owner.
fn WasmFunctionEmitter::scale(self : WasmFunctionEmitter) -> WasmModuleScale {
  let functions = self.function_scales
  {
    imported_function_count: self.imported_function_count,
    defined_function_count: functions.length(),
    instruction_count: functions.fold(init=0, fn(total, function) {
      total + function.instruction_count
    }),
    local_count: functions.fold(init=0, fn(total, function) {
      total + function.local_count
    }),
    table_entry_count: self.module_.elems.fold(init=0, fn(total, element) {
      total + element.init.length()
    }),
    functions,
  }
}

///|
fn wasm_instruction_array_size(
  instructions : Array[@wasm_types.Instruction],
) -> Int {
  instructions.fold(init=0, fn(total, instruction) {
    total + wasm_instruction_size(instruction)
  })
}

///|
fn wasm_instruction_size(instruction : @wasm_types.Instruction) -> Int {
  match instruction {
    Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
      1 + wasm_instruction_array_size(body)
    If(_, consequent, alternate) =>
      1 +
      wasm_instruction_array_size(consequent) +
      wasm_instruction_array_size(alternate)
    _ => 1
  }
}
