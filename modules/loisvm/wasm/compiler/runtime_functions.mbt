///|
priv struct RuntimeFunctions {
  allocate : Int
  free : Int
  retain_ref : Int
  release_ref : Int
  byte_sequence_new : Int
  require_byte_sequence_layout : Int
  byte_sequence_equal : Int
  byte_sequence_concat : Int
  byte_sequence_slice : Int
  host_object_new : Int
  byte_sequence_make : Int
  byte_sequence_index : Int
  byte_sequence_get : Int
  byte_sequence_set : Int
  byte_sequence_is_valid_utf8 : Int
}

///|
let runtime_function_count = 15

///|
fn runtime_function_indices(first_index : Int) -> RuntimeFunctions {
  {
    allocate: first_index,
    free: first_index + 1,
    retain_ref: first_index + 2,
    release_ref: first_index + 3,
    byte_sequence_new: first_index + 4,
    require_byte_sequence_layout: first_index + 5,
    byte_sequence_equal: first_index + 6,
    byte_sequence_concat: first_index + 7,
    byte_sequence_slice: first_index + 8,
    host_object_new: first_index + 9,
    byte_sequence_make: first_index + 10,
    byte_sequence_index: first_index + 11,
    byte_sequence_get: first_index + 12,
    byte_sequence_set: first_index + 13,
    byte_sequence_is_valid_utf8: first_index + 14,
  }
}

///|
fn append_runtime_function(
  emitter : WasmFunctionEmitter,
  parameters : Array[@wasm_types.ValueType],
  results : Array[@wasm_types.ValueType],
  locals : Array[@wasm_types.ValueType],
  body : Array[@wasm_types.Instruction],
  origin : WasmFunctionOrigin,
) -> Unit {
  let type_index = intern_function_type(emitter.module_, parameters, results)
  ignore(emitter.append_defined(type_index, { locals, body }, origin))
}

///|
fn append_runtime_functions(
  emitter : WasmFunctionEmitter,
  static_image : StaticImage,
  functions : RuntimeFunctions,
) -> Unit {
  let destroy_type = intern_function_type(emitter.module_, [I32], [])
  append_runtime_function(
    emitter,
    [I32],
    [I32],
    [I32, I32, I32, I32, I32, I32, I32, I32],
    allocator_body(),
    RuntimeFunction(Allocate),
  )
  append_runtime_function(
    emitter,
    [I32],
    [],
    [],
    free_body(),
    RuntimeFunction(Free),
  )
  append_runtime_function(
    emitter,
    [I32],
    [],
    [I32],
    retain_ref_body(),
    RuntimeFunction(RetainReference),
  )
  append_runtime_function(
    emitter,
    [I32],
    [],
    [I32],
    release_ref_body(functions.free, destroy_type),
    RuntimeFunction(ReleaseReference),
  )
  append_runtime_function(
    emitter,
    [I32],
    [I32],
    [I32],
    byte_sequence_new_body(
      functions.allocate,
      static_image.byte_sequence_layout_id,
    ),
    RuntimeFunction(ByteSequenceNew),
  )
  append_runtime_function(
    emitter,
    [I32],
    [],
    [],
    require_byte_sequence_layout_body(static_image.byte_sequence_layout_id),
    RuntimeFunction(RequireByteSequenceLayout),
  )
  append_runtime_function(
    emitter,
    [I32, I32],
    [I32],
    [I32, I32],
    byte_sequence_equal_body(functions.require_byte_sequence_layout),
    RuntimeFunction(ByteSequenceEqual),
  )
  append_runtime_function(
    emitter,
    [I32, I32],
    [I32],
    [I32, I32, I32, I32],
    byte_sequence_concat_body(
      functions.require_byte_sequence_layout,
      functions.byte_sequence_new,
      functions.release_ref,
    ),
    RuntimeFunction(ByteSequenceConcat),
  )
  append_runtime_function(
    emitter,
    [I32, I64, I64],
    [I32],
    [I64, I32, I32, I32],
    byte_sequence_slice_body(
      functions.require_byte_sequence_layout,
      functions.byte_sequence_new,
      functions.release_ref,
    ),
    RuntimeFunction(ByteSequenceSlice),
  )
  append_runtime_function(
    emitter,
    [I64],
    [I32],
    [I32],
    host_object_new_body(functions.allocate, static_image.reference_layout_id),
    RuntimeFunction(HostObjectNew),
  )
  append_runtime_function(
    emitter,
    [I64, I32],
    [I32],
    [I32, I32, I32],
    byte_sequence_make_body(functions.byte_sequence_new),
    RuntimeFunction(ByteSequenceMake),
  )
  append_runtime_function(
    emitter,
    [I32, I64],
    [I32],
    [],
    byte_sequence_index_body(functions.require_byte_sequence_layout),
    RuntimeFunction(ByteSequenceIndex),
  )
  append_runtime_function(
    emitter,
    [I32, I64],
    [I32],
    [],
    byte_sequence_get_body(functions.byte_sequence_index),
    RuntimeFunction(ByteSequenceGet),
  )
  append_runtime_function(
    emitter,
    [I32, I64, I32],
    [I32],
    [I32, I32],
    byte_sequence_set_body(
      functions.byte_sequence_new,
      functions.byte_sequence_index,
      functions.release_ref,
    ),
    RuntimeFunction(ByteSequenceSet),
  )
  append_runtime_function(
    emitter,
    [I32],
    [I32],
    [I32, I32, I32, I32],
    byte_sequence_is_valid_utf8_body(functions.require_byte_sequence_layout),
    RuntimeFunction(ByteSequenceIsValidUtf8),
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
fn byte_sequence_new_body(
  allocate_index : Int,
  layout_id : Int,
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
    I32Const(layout_id),
    I32Store(0, 2, 4L),
    LocalGet(1),
    LocalGet(0),
    I32Store(0, 2, 8L),
    LocalGet(1),
  ]
}

///|
fn require_byte_sequence_layout_body(
  byte_sequence_layout_id : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Eqz,
    If(Empty, [Unreachable], []),
    LocalGet(0),
    I32Load(0, 2, 4L),
    I32Const(byte_sequence_layout_id),
    I32Ne,
    If(Empty, [Unreachable], []),
  ]
}

///|
fn host_object_new_body(
  allocate_index : Int,
  reference_layout_id : Int,
) -> Array[@wasm_types.Instruction] {
  [
    I32Const(16),
    Call(allocate_index),
    LocalSet(1),
    LocalGet(1),
    I32Const(1),
    I32Store(0, 2, 0L),
    LocalGet(1),
    I32Const(reference_layout_id),
    I32Store(0, 2, 4L),
    LocalGet(1),
    LocalGet(0),
    I64Store(0, 3, 8L),
    LocalGet(1),
  ]
}

///|
fn byte_sequence_make_body(
  byte_sequence_new_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(0),
    I32WrapI64,
    LocalSet(2),
    LocalGet(2),
    I64ExtendI32U,
    LocalGet(0),
    I64Ne,
    If(Empty, [Unreachable], []),
    LocalGet(2),
    Call(byte_sequence_new_index),
    LocalSet(3),
    I32Const(0),
    LocalSet(4),
    Block(Empty, [
      Loop(Empty, [
        LocalGet(4),
        LocalGet(2),
        I32GeU,
        BrIf(1),
        LocalGet(3),
        LocalGet(4),
        I32Add,
        LocalGet(1),
        I32Store8(0, 0, 12L),
        LocalGet(4),
        I32Const(1),
        I32Add,
        LocalSet(4),
        Br(0),
      ]),
    ]),
    LocalGet(3),
  ]
}

///|
fn byte_sequence_index_body(
  require_byte_sequence_layout_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    Call(require_byte_sequence_layout_index),
    LocalGet(1),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    LocalGet(0),
    I32Load(0, 2, 8L),
    I64ExtendI32U,
    I64LtU,
    I32Eqz,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32WrapI64,
  ]
}

///|
fn byte_sequence_get_body(
  byte_sequence_index_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    LocalGet(0),
    LocalGet(1),
    Call(byte_sequence_index_index),
    I32Add,
    I32Load8U(0, 0, 12L),
  ]
}

///|
fn byte_sequence_set_body(
  byte_sequence_new_index : Int,
  byte_sequence_index_index : Int,
  release_ref_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    LocalGet(1),
    Call(byte_sequence_index_index),
    LocalSet(3),
    LocalGet(0),
    I32Load(0, 2, 0L),
    I32Const(1),
    I32Eq,
    If(
      Empty,
      [
        LocalGet(0),
        LocalGet(3),
        I32Add,
        LocalGet(2),
        I32Store8(0, 0, 12L),
        LocalGet(0),
        Return,
      ],
      [],
    ),
    LocalGet(0),
    I32Load(0, 2, 8L),
    Call(byte_sequence_new_index),
    LocalSet(4),
    LocalGet(4),
    I32Const(12),
    I32Add,
    LocalGet(0),
    I32Const(12),
    I32Add,
    LocalGet(0),
    I32Load(0, 2, 8L),
    MemoryCopy(0, 0),
    LocalGet(4),
    LocalGet(3),
    I32Add,
    LocalGet(2),
    I32Store8(0, 0, 12L),
    LocalGet(0),
    Call(release_ref_index),
    LocalGet(4),
  ]
}

///|
fn byte_sequence_equal_body(
  require_byte_sequence_layout_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    Call(require_byte_sequence_layout_index),
    LocalGet(1),
    Call(require_byte_sequence_layout_index),
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
fn byte_sequence_concat_body(
  require_byte_sequence_layout_index : Int,
  byte_sequence_new_index : Int,
  release_ref_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    Call(require_byte_sequence_layout_index),
    LocalGet(1),
    Call(require_byte_sequence_layout_index),
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
    Call(byte_sequence_new_index),
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
fn byte_sequence_slice_body(
  require_byte_sequence_layout_index : Int,
  byte_sequence_new_index : Int,
  release_ref_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    Call(require_byte_sequence_layout_index),
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
    Call(byte_sequence_new_index),
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

///|
fn byte_sequence_is_valid_utf8_body(
  require_byte_sequence_layout_index : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    Call(require_byte_sequence_layout_index),
    LocalGet(0),
    I32Load(0, 2, 8L),
    LocalSet(1),
    I32Const(0),
    LocalSet(2),
    Block(Empty, [
      Loop(Empty, [
        LocalGet(2),
        LocalGet(1),
        I32GeU,
        BrIf(1),
        LocalGet(0),
        LocalGet(2),
        I32Add,
        I32Load8U(0, 0, 12L),
        LocalSet(3),
        LocalGet(3),
        I32Const(0x7F),
        I32GtU,
        I32Eqz,
        If(Empty, [LocalGet(2), I32Const(1), I32Add, LocalSet(2)], [
          LocalGet(3),
          I32Const(0xC2),
          I32GeU,
          LocalGet(3),
          I32Const(0xDF),
          I32GtU,
          I32Eqz,
          I32And,
          If(
            Empty,
            [
              LocalGet(2),
              I32Const(1),
              I32Add,
              LocalGet(1),
              I32GeU,
              If(Empty, [I32Const(0), Return], []),
              LocalGet(0),
              LocalGet(2),
              I32Add,
              I32Load8U(0, 0, 13L),
              LocalSet(4),
              LocalGet(4),
              I32Const(0x80),
              I32LtU,
              LocalGet(4),
              I32Const(0xBF),
              I32GtU,
              I32Or,
              If(Empty, [I32Const(0), Return], []),
              LocalGet(2),
              I32Const(2),
              I32Add,
              LocalSet(2),
            ],
            [
              LocalGet(3),
              I32Const(0xE0),
              I32GeU,
              LocalGet(3),
              I32Const(0xEF),
              I32GtU,
              I32Eqz,
              I32And,
              If(
                Empty,
                [
                  LocalGet(2),
                  I32Const(2),
                  I32Add,
                  LocalGet(1),
                  I32GeU,
                  If(Empty, [I32Const(0), Return], []),
                  LocalGet(0),
                  LocalGet(2),
                  I32Add,
                  I32Load8U(0, 0, 13L),
                  LocalSet(4),
                  LocalGet(4),
                  I32Const(0x80),
                  I32LtU,
                  LocalGet(4),
                  I32Const(0xBF),
                  I32GtU,
                  I32Or,
                  If(Empty, [I32Const(0), Return], []),
                  LocalGet(3),
                  I32Const(0xE0),
                  I32Eq,
                  LocalGet(4),
                  I32Const(0xA0),
                  I32LtU,
                  I32And,
                  LocalGet(3),
                  I32Const(0xED),
                  I32Eq,
                  LocalGet(4),
                  I32Const(0x9F),
                  I32GtU,
                  I32And,
                  I32Or,
                  If(Empty, [I32Const(0), Return], []),
                  LocalGet(0),
                  LocalGet(2),
                  I32Add,
                  I32Load8U(0, 0, 14L),
                  LocalSet(4),
                  LocalGet(4),
                  I32Const(0x80),
                  I32LtU,
                  LocalGet(4),
                  I32Const(0xBF),
                  I32GtU,
                  I32Or,
                  If(Empty, [I32Const(0), Return], []),
                  LocalGet(2),
                  I32Const(3),
                  I32Add,
                  LocalSet(2),
                ],
                [
                  LocalGet(3),
                  I32Const(0xF0),
                  I32GeU,
                  LocalGet(3),
                  I32Const(0xF4),
                  I32GtU,
                  I32Eqz,
                  I32And,
                  If(
                    Empty,
                    [
                      LocalGet(2),
                      I32Const(3),
                      I32Add,
                      LocalGet(1),
                      I32GeU,
                      If(Empty, [I32Const(0), Return], []),
                      LocalGet(0),
                      LocalGet(2),
                      I32Add,
                      I32Load8U(0, 0, 13L),
                      LocalSet(4),
                      LocalGet(4),
                      I32Const(0x80),
                      I32LtU,
                      LocalGet(4),
                      I32Const(0xBF),
                      I32GtU,
                      I32Or,
                      If(Empty, [I32Const(0), Return], []),
                      LocalGet(3),
                      I32Const(0xF0),
                      I32Eq,
                      LocalGet(4),
                      I32Const(0x90),
                      I32LtU,
                      I32And,
                      LocalGet(3),
                      I32Const(0xF4),
                      I32Eq,
                      LocalGet(4),
                      I32Const(0x8F),
                      I32GtU,
                      I32And,
                      I32Or,
                      If(Empty, [I32Const(0), Return], []),
                      LocalGet(0),
                      LocalGet(2),
                      I32Add,
                      I32Load8U(0, 0, 14L),
                      LocalSet(4),
                      LocalGet(4),
                      I32Const(0x80),
                      I32LtU,
                      LocalGet(4),
                      I32Const(0xBF),
                      I32GtU,
                      I32Or,
                      If(Empty, [I32Const(0), Return], []),
                      LocalGet(0),
                      LocalGet(2),
                      I32Add,
                      I32Load8U(0, 0, 15L),
                      LocalSet(4),
                      LocalGet(4),
                      I32Const(0x80),
                      I32LtU,
                      LocalGet(4),
                      I32Const(0xBF),
                      I32GtU,
                      I32Or,
                      If(Empty, [I32Const(0), Return], []),
                      LocalGet(2),
                      I32Const(4),
                      I32Add,
                      LocalSet(2),
                    ],
                    [I32Const(0), Return],
                  ),
                ],
              ),
            ],
          ),
        ]),
        Br(0),
      ]),
    ]),
    I32Const(1),
  ]
}
