///|
priv struct FunctionCompilationContext {
  function_id : Int
  locals : FunctionLocalPlan
  body : @physical.FunctionBody
  wasm_module : @wasm_types.Module
  static_image : StaticImage
  function_catalog : WasmFunctionCatalog
}

///|
fn FunctionCompilationContext::compile_instruction(
  self : FunctionCompilationContext,
  instruction : @physical.Instruction,
) -> Array[@wasm_types.Instruction] {
  compile_instruction(
    self.locals,
    self.body.slots,
    self.wasm_module,
    self.static_image,
    self.function_catalog,
    instruction,
  )
}

///|
fn FunctionCompilationContext::compile_terminator(
  self : FunctionCompilationContext,
  terminator : @physical.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  compile_terminator(
    self.function_id,
    self.locals,
    self.wasm_module,
    self.static_image,
    self.function_catalog,
    terminator,
  )
}

///|
fn FunctionCompilationContext::slot_local(
  self : FunctionCompilationContext,
  slot : @physical.SlotId,
) -> Int {
  self.locals.slot_local(slot)
}

///|
fn FunctionCompilationContext::transfer_local(
  self : FunctionCompilationContext,
  block : @physical.BlockId,
  parameter_index : Int,
) -> Int {
  self.locals.transfer_local(block, parameter_index)
}

///|
fn FunctionCompilationContext::dispatcher_state_local(
  self : FunctionCompilationContext,
) -> Int {
  self.locals.dispatcher_state_local()
}

///|
fn FunctionCompilationContext::mark_slot_dead(
  self : FunctionCompilationContext,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  self.locals.mark_slot_dead(slot)
}

///|
fn FunctionCompilationContext::mark_slot_live(
  self : FunctionCompilationContext,
  slot : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  self.locals.mark_slot_live(slot)
}
