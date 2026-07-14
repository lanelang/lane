///|
priv struct FunctionCompilationContext {
  function_id : Int
  parameter_count : Int
  live_base : Int
  body : @bytecode.FunctionBody
  wasm_module : @wasm_types.Module
  static_image : StaticImage
  runtime_functions : RuntimeFunctions
}

///|
fn FunctionCompilationContext::compile_instruction(
  self : FunctionCompilationContext,
  instruction : @bytecode.Instruction,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  compile_instruction(
    self.function_id,
    self.parameter_count,
    self.live_base,
    self.body.slots,
    self.wasm_module,
    self.static_image,
    self.runtime_functions,
    instruction,
  )
}

///|
fn FunctionCompilationContext::compile_terminator(
  self : FunctionCompilationContext,
  terminator : @bytecode.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  compile_terminator(
    self.function_id,
    self.parameter_count,
    self.live_base,
    self.body.slots,
    self.body.result,
    self.wasm_module,
    self.static_image,
    terminator,
  )
}

///|
fn FunctionCompilationContext::slot_local(
  self : FunctionCompilationContext,
  slot : @bytecode.SlotId,
) -> Int {
  slot_local(self.parameter_count, slot)
}

///|
fn FunctionCompilationContext::transfer_local(
  self : FunctionCompilationContext,
  slot : @bytecode.SlotId,
) -> Int {
  transfer_local(self.parameter_count, self.body.slots.length(), slot)
}

///|
fn FunctionCompilationContext::mark_slot_dead(
  self : FunctionCompilationContext,
  slot : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  mark_slot_dead(self.live_base, self.body.slots, slot)
}

///|
fn FunctionCompilationContext::mark_slot_live(
  self : FunctionCompilationContext,
  slot : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  mark_slot_live(self.live_base, self.body.slots, slot)
}
