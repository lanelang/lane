///|
test "Wasm module text exposes sections and structured instructions" {
  let module_ = {
    ..@wasm_types.Module::empty(),
    types: [@wasm_types.SubType::from_func({ params: [], results: [] })],
    type_rec_groups: [0],
    funcs: [0],
    tables: [
      {
        type_: {
          elem_type: FuncRef,
          limits: { min: 1L, max: Some(1L) },
          is_table64: false,
        },
        init: Some([RefNull(FuncRef)]),
      },
    ],
    memories: [
      {
        limits: { min: 1L, max: Some(2L) },
        is_memory64: false,
        page_size_log2: 16,
      },
    ],
    globals: [
      { type_: { value_type: I32, mutable: true }, init: [I32Const(0)] },
    ],
    exports: [
      { name: "run", desc: Func(0) },
      { name: "memory", desc: Memory(0) },
    ],
    elems: [
      { mode: Active(0, [I32Const(0)]), type_: FuncRef, init: [[RefFunc(0)]] },
    ],
    codes: [
      {
        locals: [I32],
        body: [
          Block(Empty, [TryTable(Empty, [Catch(0, 0)], [Throw(0)]), Unreachable]),
        ],
      },
    ],
    datas: [{ memory_idx: 0, offset: [I32Const(0)], init: b"Lane" }],
    tags: [{ type_idx: 0 }],
  }
  inspect(
    module_to_wat(module_),
    content=(
      #|(module
      #|  (type (;0;) (func))
      #|  (table (;0;) 1 1 funcref (ref.null func))
      #|  (memory (;0;) 1 2)
      #|  (global (;0;) (mut i32) (i32.const 0))
      #|  (tag (;0;) (type 0))
      #|  (export "run" (func 0))
      #|  (export "memory" (memory 0))
      #|  (elem (;0;) (i32.const 0) funcref (ref.func 0))
      #|  (func (;0;) (type 0)
      #|    (local i32)
      #|    block
      #|      try_table (catch 0 0)
      #|        throw 0
      #|      end
      #|      unreachable
      #|    end
      #|  )
      #|  (data (;0;) (i32.const 0) "Lane")
      #|)
      #|
    ),
  )
}
