///|
priv struct FunctionCompilationContext {
  function_id : Int
  locals : FunctionLocalPlan
  body : @physical.FunctionBody
  wasm_module : @wasm_types.Module
  static_image : StaticImage
  function_catalog : WasmFunctionCatalog
  expansions : Array[WasmExpansionScale]
}

///|
fn FunctionCompilationContext::compile_instruction(
  self : FunctionCompilationContext,
  instruction : @physical.Instruction,
) -> Array[@wasm_types.Instruction] {
  let compiled = compile_instruction(
    self.locals,
    self.body.slots,
    self.wasm_module,
    self.static_image,
    self.function_catalog,
    instruction,
  )
  self.record_expansion_count(
    PhysicalOpcode(physical_opcode_family(instruction)),
    wasm_instruction_array_size(compiled),
  )
  compiled
}

///|
fn FunctionCompilationContext::compile_terminator(
  self : FunctionCompilationContext,
  terminator : @physical.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  let compiled = compile_terminator(
    self.function_id,
    self.locals,
    self.wasm_module,
    self.static_image,
    self.function_catalog,
    terminator,
  )
  self.record_expansion_count(
    PhysicalOpcode(ControlTransfer),
    wasm_instruction_array_size(compiled),
  )
  compiled
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
