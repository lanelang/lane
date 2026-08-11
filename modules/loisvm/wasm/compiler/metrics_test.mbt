///|
test "Wasm module scale counts nested instructions and stage-local functions" {
  let module_ = {
    ..@wasm_types.Module::empty(),
    imports: [{ mod_name: "host", name: "observe", desc: Func(0) }],
    funcs: [0],
    codes: [
      {
        locals: [I32, I64],
        body: [Block(Empty, [Nop, If(Empty, [I32Const(1)], [I32Const(0)])])],
      },
    ],
    elems: [
      { mode: Active(0, [I32Const(0)]), type_: FuncRef, init: [[RefFunc(1)]] },
    ],
  }
  debug_inspect(
    measure_module(module_),
    content=(
      #|{
      #|  imported_function_count: 1,
      #|  defined_function_count: 1,
      #|  instruction_count: 5,
      #|  local_count: 2,
      #|  table_entry_count: 1,
      #|  functions: [{ index: 1, instruction_count: 5, local_count: 2 }],
      #|}
    ),
  )
}
