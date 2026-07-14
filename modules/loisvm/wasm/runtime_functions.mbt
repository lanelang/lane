///|
priv struct RuntimeFunctions {
  allocate : Int
  free : Int
  retain_ref : Int
  release_ref : Int
  string_new : Int
  string_eq : Int
  string_concat : Int
  string_slice : Int
}

///|
fn runtime_function_indices(first_index : Int) -> RuntimeFunctions {
  {
    allocate: first_index,
    free: first_index + 1,
    retain_ref: first_index + 2,
    release_ref: first_index + 3,
    string_new: first_index + 4,
    string_eq: first_index + 5,
    string_concat: first_index + 6,
    string_slice: first_index + 7,
  }
}

///|
fn append_runtime_function(
  wasm_module : @wasm_types.Module,
  parameters : Array[@wasm_types.ValueType],
  results : Array[@wasm_types.ValueType],
  locals : Array[@wasm_types.ValueType],
  body : Array[@wasm_types.Instruction],
) -> Unit {
  wasm_module.funcs.push(intern_function_type(wasm_module, parameters, results))
  wasm_module.codes.push({ locals, body })
}

///|
fn append_runtime_functions(
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  functions : RuntimeFunctions,
) -> Unit {
  let destroy_type = intern_function_type(wasm_module, [I32], [])
  append_runtime_function(
    wasm_module,
    [I32],
    [I32],
    [I32, I32, I32, I32, I32, I32, I32, I32],
    allocator_body(),
  )
  append_runtime_function(wasm_module, [I32], [], [], free_body())
  append_runtime_function(wasm_module, [I32], [], [I32], retain_ref_body())
  append_runtime_function(
    wasm_module,
    [I32],
    [],
    [I32],
    release_ref_body(functions.free, destroy_type),
  )
  append_runtime_function(
    wasm_module,
    [I32],
    [I32],
    [I32],
    string_new_body(functions.allocate, static_image.string_layout_id),
  )
  append_runtime_function(
    wasm_module,
    [I32, I32],
    [I32],
    [I32, I32],
    string_eq_body(),
  )
  append_runtime_function(
    wasm_module,
    [I32, I32],
    [I32],
    [I32, I32, I32, I32],
    string_concat_body(functions.string_new, functions.release_ref),
  )
  append_runtime_function(
    wasm_module,
    [I32, I64, I64],
    [I32],
    [I64, I32, I32, I32],
    string_slice_body(functions.string_new, functions.release_ref),
  )
}

///|
fn allocator_body() -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Const(7),
    I32Add,
    I32Const(-8),
    I32And,
    LocalSet(1),
    GlobalGet(max_live_heap_bytes_global_index),
    I32Eqz,
    If(Empty, [], [
      GlobalGet(live_heap_bytes_global_index),
      LocalGet(1),
      I32Add,
      LocalSet(5),
      LocalGet(5),
      GlobalGet(live_heap_bytes_global_index),
      I32LtU,
      LocalGet(5),
      GlobalGet(max_live_heap_bytes_global_index),
      I32GtU,
      I32Or,
      If(Empty, [I32Const(2), GlobalSet(failure_code_global_index), Throw(0)], []),
    ]),
    I32Const(0),
    LocalSet(2),
    GlobalGet(free_list_head_global_index),
    LocalSet(3),
    Block(Empty, [
      Loop(Empty, [
        LocalGet(3),
        I32Eqz,
        BrIf(1),
        LocalGet(3),
        I32Const(16),
        I32Sub,
        I32Load(0, 2, 0L),
        LocalSet(4),
        LocalGet(4),
        LocalGet(1),
        I32GeU,
        If(
          Empty,
          [
            LocalGet(3),
            I32Const(8),
            I32Sub,
            I32Load(0, 2, 0L),
            LocalSet(5),
            LocalGet(2),
            I32Eqz,
            If(Empty, [LocalGet(5), GlobalSet(free_list_head_global_index)], [
              LocalGet(2),
              I32Const(8),
              I32Sub,
              LocalGet(5),
              I32Store(0, 2, 0L),
            ]),
            LocalGet(3),
            I32Const(12),
            I32Sub,
            LocalGet(1),
            I32Store(0, 2, 0L),
            GlobalGet(live_heap_bytes_global_index),
            LocalGet(1),
            I32Add,
            GlobalSet(live_heap_bytes_global_index),
            LocalGet(3),
            Return,
          ],
          [],
        ),
        LocalGet(3),
        LocalSet(2),
        LocalGet(3),
        I32Const(8),
        I32Sub,
        I32Load(0, 2, 0L),
        LocalSet(3),
        Br(0),
      ]),
    ]),
    GlobalGet(heap_cursor_global_index),
    LocalSet(6),
    LocalGet(6),
    I32Const(16),
    I32Add,
    LocalGet(1),
    I32Add,
    LocalSet(7),
    LocalGet(7),
    LocalGet(6),
    I32LtU,
    If(Empty, [I32Const(3), GlobalSet(failure_code_global_index), Throw(0)], []),
    LocalGet(7),
    MemorySize(0),
    I32Const(16),
    I32Shl,
    I32GtU,
    If(
      Empty,
      [
        LocalGet(7),
        MemorySize(0),
        I32Const(16),
        I32Shl,
        I32Sub,
        I32Const(65535),
        I32Add,
        I32Const(16),
        I32ShrU,
        MemoryGrow(0),
        I32Const(-1),
        I32Eq,
        If(
          Empty,
          [I32Const(3), GlobalSet(failure_code_global_index), Throw(0)],
          [],
        ),
      ],
      [],
    ),
    LocalGet(6),
    LocalGet(1),
    I32Store(0, 2, 0L),
    LocalGet(6),
    I32Const(4),
    I32Add,
    LocalGet(1),
    I32Store(0, 2, 0L),
    LocalGet(6),
    I32Const(8),
    I32Add,
    I32Const(0),
    I32Store(0, 2, 0L),
    LocalGet(7),
    GlobalSet(heap_cursor_global_index),
    GlobalGet(live_heap_bytes_global_index),
    LocalGet(1),
    I32Add,
    GlobalSet(live_heap_bytes_global_index),
    LocalGet(6),
    I32Const(16),
    I32Add,
  ]
}

///|
fn free_body() -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Eqz,
    If(Empty, [Return], []),
    GlobalGet(live_heap_bytes_global_index),
    LocalGet(0),
    I32Const(12),
    I32Sub,
    I32Load(0, 2, 0L),
    I32Sub,
    GlobalSet(live_heap_bytes_global_index),
    LocalGet(0),
    I32Const(8),
    I32Sub,
    GlobalGet(free_list_head_global_index),
    I32Store(0, 2, 0L),
    LocalGet(0),
    GlobalSet(free_list_head_global_index),
  ]
}

///|
fn retain_ref_body() -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Eqz,
    If(Empty, [Return], []),
    LocalGet(0),
    I32Load(0, 2, 0L),
    LocalSet(1),
    LocalGet(1),
    I32Const(-1),
    I32Eq,
    If(Empty, [Return], []),
    LocalGet(1),
    I32Const(-2),
    I32Eq,
    If(Empty, [I32Const(3), GlobalSet(failure_code_global_index), Throw(0)], []),
    LocalGet(0),
    LocalGet(1),
    I32Const(1),
    I32Add,
    I32Store(0, 2, 0L),
  ]
}

///|
fn release_ref_body(
  free_index : Int,
  destroy_type : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Eqz,
    If(Empty, [Return], []),
    LocalGet(0),
    I32Load(0, 2, 0L),
    LocalSet(1),
    LocalGet(1),
    I32Const(-1),
    I32Eq,
    If(Empty, [Return], []),
    LocalGet(1),
    I32Const(1),
    I32Eq,
    If(
      Empty,
      [
        LocalGet(0),
        LocalGet(0),
        I32Load(0, 2, 4L),
        I32Const(5),
        I32Shl,
        GlobalGet(layout_table_base_global_index),
        I32Add,
        I32Load(0, 2, 24L),
        CallIndirect(destroy_type, 0),
        LocalGet(0),
        Call(free_index),
        Return,
      ],
      [],
    ),
    LocalGet(0),
    LocalGet(1),
    I32Const(1),
    I32Sub,
    I32Store(0, 2, 0L),
  ]
}

///|
fn string_new_body(
  allocate_index : Int,
  string_layout_id : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Const(19),
    I32Add,
    I32Const(-8),
    I32And,
    LocalSet(1),
    LocalGet(1),
    LocalGet(0),
    I32LtU,
    If(Empty, [I32Const(3), GlobalSet(failure_code_global_index), Throw(0)], []),
    LocalGet(1),
    Call(allocate_index),
    LocalSet(1),
    LocalGet(1),
    I32Const(1),
    I32Store(0, 2, 0L),
    LocalGet(1),
    I32Const(string_layout_id),
    I32Store(0, 2, 4L),
    LocalGet(1),
    LocalGet(0),
    I32Store(0, 2, 8L),
    LocalGet(1),
  ]
}

///|
fn string_eq_body() -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    LocalGet(1),
    I32Eq,
    If(Empty, [I32Const(1), Return], []),
    LocalGet(0),
    I32Load(0, 2, 8L),
    LocalSet(2),
    LocalGet(2),
    LocalGet(1),
    I32Load(0, 2, 8L),
    I32Ne,
    If(Empty, [I32Const(0), Return], []),
    I32Const(0),
    LocalSet(3),
    Block(Empty, [
      Loop(Empty, [
        LocalGet(3),
        LocalGet(2),
        I32GeU,
        BrIf(1),
        LocalGet(0),
        LocalGet(3),
        I32Add,
        I32Load8U(0, 0, 12L),
        LocalGet(1),
        LocalGet(3),
        I32Add,
        I32Load8U(0, 0, 12L),
        I32Ne,
        If(Empty, [I32Const(0), Return], []),
        LocalGet(3),
        I32Const(1),
        I32Add,
        LocalSet(3),
        Br(0),
      ]),
    ]),
    I32Const(1),
  ]
}

///|
fn string_concat_body(
  string_new_index : Int,
  release_ref_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Load(0, 2, 8L),
    LocalSet(2),
    LocalGet(1),
    I32Load(0, 2, 8L),
    LocalSet(3),
    LocalGet(2),
    LocalGet(3),
    I32Add,
    LocalSet(4),
    LocalGet(4),
    LocalGet(2),
    I32LtU,
    If(Empty, [I32Const(3), GlobalSet(failure_code_global_index), Throw(0)], []),
    LocalGet(4),
    Call(string_new_index),
    LocalSet(5),
    LocalGet(5),
    I32Const(12),
    I32Add,
    LocalGet(0),
    I32Const(12),
    I32Add,
    LocalGet(2),
    MemoryCopy(0, 0),
    LocalGet(5),
    I32Const(12),
    I32Add,
    LocalGet(2),
    I32Add,
    LocalGet(1),
    I32Const(12),
    I32Add,
    LocalGet(3),
    MemoryCopy(0, 0),
    LocalGet(0),
    Call(release_ref_index),
    LocalGet(1),
    Call(release_ref_index),
    LocalGet(5),
  ]
}

///|
fn string_slice_body(
  string_new_index : Int,
  release_ref_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(1),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(2),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    LocalGet(2),
    I64Add,
    LocalSet(3),
    LocalGet(3),
    LocalGet(1),
    I64LtU,
    If(Empty, [Unreachable], []),
    LocalGet(0),
    I32Load(0, 2, 8L),
    I64ExtendI32U,
    LocalGet(3),
    I64LtU,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32WrapI64,
    LocalSet(4),
    LocalGet(2),
    I32WrapI64,
    LocalSet(5),
    LocalGet(5),
    Call(string_new_index),
    LocalSet(6),
    LocalGet(6),
    I32Const(12),
    I32Add,
    LocalGet(0),
    I32Const(12),
    I32Add,
    LocalGet(4),
    I32Add,
    LocalGet(5),
    MemoryCopy(0, 0),
    LocalGet(0),
    Call(release_ref_index),
    LocalGet(6),
  ]
}
