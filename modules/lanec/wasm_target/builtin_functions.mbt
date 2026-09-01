///|
fn float_text_capacity() -> Int {
  32
}

///|
let guest_float_stack_global_index = 6

///|
fn relocate_guest_float_instructions(
  instructions : Array[@wasm_types.Instruction],
  catalog : WasmFunctionCatalog,
) -> Array[@wasm_types.Instruction] {
  instructions.map(instruction => {
    relocate_guest_float_instruction(instruction, catalog)
  })
}

///|
fn relocate_guest_float_instruction(
  instruction : @wasm_types.Instruction,
  catalog : WasmFunctionCatalog,
) -> @wasm_types.Instruction {
  match instruction {
    Block(type_, body) =>
      Block(type_, relocate_guest_float_instructions(body, catalog))
    Loop(type_, body) =>
      Loop(type_, relocate_guest_float_instructions(body, catalog))
    If(type_, consequent, alternate) =>
      If(
        type_,
        relocate_guest_float_instructions(consequent, catalog),
        relocate_guest_float_instructions(alternate, catalog),
      )
    TryTable(type_, handlers, body) =>
      TryTable(
        type_,
        handlers,
        relocate_guest_float_instructions(body, catalog),
      )
    Call(index) => Call(catalog.builtin(builtin_function_order()[index]).index)
    ReturnCall(index) =>
      ReturnCall(catalog.builtin(builtin_function_order()[index]).index)
    GlobalGet(0) => GlobalGet(guest_float_stack_global_index)
    GlobalSet(0) => GlobalSet(guest_float_stack_global_index)
    _ => instruction
  }
}

///|
fn compile_builtin_function(
  role : WasmBuiltinFunctionRole,
  catalog : WasmFunctionCatalog,
) -> @wasm_types.FunctionCode {
  let index = builtin_function_order().search(role).unwrap()
  let code = guest_float_codes()[index]
  { ..code, body: relocate_guest_float_instructions(code.body, catalog), }
}
