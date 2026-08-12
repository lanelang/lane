///|
test "Wasm emission records identity and scale in one operation" {
  let module_ = {
    ..@wasm_types.Module::empty(),
    elems: [
      { mode: Active(0, [I32Const(0)]), type_: FuncRef, init: [[RefFunc(1)]] },
    ],
  }
  let emitter = WasmFunctionEmitter::new(module_)
  ignore(
    emitter.append_import(
      "host",
      "observe",
      0,
      InternalRuntimeImport(F32ToString),
    ),
  )
  ignore(
    emitter.append_defined(
      0,
      {
        locals: [I32, I64],
        body: [Block(Empty, [Nop, If(Empty, [I32Const(1)], [I32Const(0)])])],
      },
      EntryWrapper,
    ),
  )
  debug_inspect(
    (emitter.functions, emitter.scale()),
    content=(
      #|(
      #|  [
      #|    { index: 0, origin: InternalRuntimeImport(F32ToString) },
      #|    { index: 1, origin: EntryWrapper },
      #|  ],
      #|  {
      #|    imported_function_count: 1,
      #|    defined_function_count: 1,
      #|    instruction_count: 5,
      #|    local_count: 2,
      #|    table_entry_count: 1,
      #|    functions: [{ index: 1, instruction_count: 5, local_count: 2 }],
      #|  },
      #|)
    ),
  )
}
