///|
fn runtime_failure() -> Array[@wasm_types.Instruction] {
  [Unreachable]
}

///|
fn compile_runtime_function(
  role : WasmRuntimeFunctionRole,
  catalog : WasmFunctionCatalog,
  static_image : StaticImage,
  wasm_module : @wasm_types.Module,
) -> @wasm_types.FunctionCode {
  match role {
    Allocate =>
      {
        locals: [I32, I32, I32, I32, I32, I32, I32, I32],
        body: allocator_body(),
      }
    Free => { locals: [], body: free_body(), }
    RetainReference => { locals: [I32], body: retain_ref_body(), }
    ReleaseReference =>
      {
        locals: [I32],
        body: release_ref_body(
          catalog.runtime(Free),
          catalog.entry(catalog.runtime(ReleaseReference)).type_index,
        ),
      }
    ByteSequenceNew =>
      {
        locals: [I32],
        body: byte_sequence_new_body(
          catalog.runtime(Allocate),
          static_image.byte_sequence_layout_id,
        ),
      }
    RequireByteSequenceLayout =>
      {
        locals: [],
        body: require_byte_sequence_layout_body(
          static_image.byte_sequence_layout_id,
        ),
      }
    ByteSequenceEqual =>
      {
        locals: [I32, I32],
        body: byte_sequence_equal_body(
          catalog.runtime(RequireByteSequenceLayout),
        ),
      }
    ByteSequenceConcat =>
      {
        locals: [I32, I32, I32, I32],
        body: byte_sequence_concat_body(
          catalog.runtime(RequireByteSequenceLayout),
          catalog.runtime(ByteSequenceNew),
          catalog.runtime(ReleaseReference),
        ),
      }
    ByteSequenceSlice =>
      {
        locals: [I64, I32, I32, I32],
        body: byte_sequence_slice_body(
          catalog.runtime(RequireByteSequenceLayout),
          catalog.runtime(ByteSequenceNew),
          catalog.runtime(ReleaseReference),
        ),
      }
    ByteSequenceMake =>
      {
        locals: [I32, I32, I32],
        body: byte_sequence_make_body(catalog.runtime(ByteSequenceNew)),
      }
    ByteSequenceIndex =>
      {
        locals: [],
        body: byte_sequence_index_body(
          catalog.runtime(RequireByteSequenceLayout),
        ),
      }
    ByteSequenceGet =>
      {
        locals: [],
        body: byte_sequence_get_body(catalog.runtime(ByteSequenceIndex)),
      }
    ByteSequenceSet =>
      {
        locals: [I32, I32],
        body: byte_sequence_set_body(
          catalog.runtime(ByteSequenceNew),
          catalog.runtime(ByteSequenceIndex),
          catalog.runtime(ReleaseReference),
        ),
      }
    ByteSequenceIsValidUtf8 =>
      {
        locals: [I32, I32, I32, I32],
        body: byte_sequence_is_valid_utf8_body(
          catalog.runtime(RequireByteSequenceLayout),
        ),
      }
    ByteBufferMake =>
      {
        locals: [I32, I32],
        body: byte_buffer_make_body(
          catalog.runtime(Allocate),
          static_image.byte_buffer_layout_id,
        ),
      }
    RequireByteBufferLayout =>
      {
        locals: [],
        body: require_byte_buffer_layout_body(
          static_image.byte_buffer_layout_id,
        ),
      }
    ByteBufferWriteBytes =>
      {
        locals: [I32, I32],
        body: byte_buffer_write_bytes_body(
          catalog.runtime(RequireByteBufferLayout),
          catalog.runtime(RequireByteSequenceLayout),
        ),
      }
    ByteBufferWriteI32 =>
      {
        locals: [I32],
        body: byte_buffer_write_i32_body(
          catalog.runtime(RequireByteBufferLayout),
        ),
      }
    ByteBufferWriteAddress =>
      {
        locals: [I32],
        body: byte_buffer_write_address_body(
          catalog.runtime(RequireByteBufferLayout),
        ),
      }
    ByteBufferReadI32 =>
      {
        locals: [I32],
        body: byte_buffer_read_i32_body(
          catalog.runtime(RequireByteBufferLayout),
        ),
      }
    InstanceGlobalCleanup =>
      compile_global_cleanup_function(static_image, catalog, wasm_module)
  }
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
    If(Empty, runtime_failure(), []),
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
    If(Empty, runtime_failure(), []),
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
        If(Empty, runtime_failure(), []),
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
    If(Empty, runtime_failure(), []),
    LocalGet(0),
    LocalGet(1),
    I32Const(1),
    I32Add,
    I32Store(0, 2, 0L),
  ]
}

///|
fn release_ref_body(
  free_function : WasmFunctionHandle,
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
        free_function.call(),
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
  allocate_function : WasmFunctionHandle,
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
    If(Empty, runtime_failure(), []),
    LocalGet(1),
    allocate_function.call(),
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
fn byte_sequence_make_body(
  byte_sequence_new_function : WasmFunctionHandle,
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
    byte_sequence_new_function.call(),
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
  require_byte_sequence_layout_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_byte_sequence_layout_function.call(),
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
  byte_sequence_index_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    LocalGet(0),
    LocalGet(1),
    byte_sequence_index_function.call(),
    I32Add,
    I32Load8U(0, 0, 12L),
  ]
}

///|
fn byte_sequence_set_body(
  byte_sequence_new_function : WasmFunctionHandle,
  byte_sequence_index_function : WasmFunctionHandle,
  release_ref_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    LocalGet(1),
    byte_sequence_index_function.call(),
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
    byte_sequence_new_function.call(),
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
    release_ref_function.call(),
    LocalGet(4),
  ]
}

///|
fn byte_buffer_make_body(
  allocate_function : WasmFunctionHandle,
  layout_id : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(0),
    I32WrapI64,
    LocalSet(1),
    LocalGet(1),
    I64ExtendI32U,
    LocalGet(0),
    I64Ne,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32Const(19),
    I32Add,
    I32Const(-8),
    I32And,
    LocalTee(2),
    LocalGet(1),
    I32LtU,
    If(Empty, runtime_failure(), []),
    LocalGet(2),
    allocate_function.call(),
    LocalSet(2),
    LocalGet(2),
    I32Const(1),
    I32Store(0, 2, 0L),
    LocalGet(2),
    I32Const(layout_id),
    I32Store(0, 2, 4L),
    LocalGet(2),
    LocalGet(1),
    I32Store(0, 2, 8L),
    LocalGet(2),
    I32Const(12),
    I32Add,
    I32Const(0),
    LocalGet(1),
    MemoryFill(0),
    LocalGet(2),
  ]
}

///|
fn require_byte_buffer_layout_body(
  byte_buffer_layout_id : Int,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    I32Eqz,
    If(Empty, [Unreachable], []),
    LocalGet(0),
    I32Load(0, 2, 4L),
    I32Const(byte_buffer_layout_id),
    I32Ne,
    If(Empty, [Unreachable], []),
  ]
}

///|
fn byte_buffer_write_bytes_body(
  require_buffer : WasmFunctionHandle,
  require_bytes : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_buffer.call(),
    LocalGet(2),
    require_bytes.call(),
    LocalGet(1),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(2),
    I32Load(0, 2, 8L),
    LocalSet(3),
    LocalGet(3),
    LocalGet(0),
    I32Load(0, 2, 8L),
    I32GtU,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    LocalGet(0),
    I32Load(0, 2, 8L),
    LocalGet(3),
    I32Sub,
    I64ExtendI32U,
    I64GtU,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32WrapI64,
    LocalSet(4),
    LocalGet(0),
    I32Const(12),
    I32Add,
    LocalGet(4),
    I32Add,
    LocalGet(2),
    I32Const(12),
    I32Add,
    LocalGet(3),
    MemoryCopy(0, 0),
  ]
}

///|
fn byte_buffer_write_i32_body(
  require_buffer : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_buffer.call(),
    LocalGet(1),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I64Const(4L),
    I64Add,
    LocalGet(0),
    I32Load(0, 2, 8L),
    I64ExtendI32U,
    I64GtU,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32WrapI64,
    LocalSet(3),
    LocalGet(0),
    LocalGet(3),
    I32Add,
    LocalGet(2),
    I32Store(0, 2, 12L),
  ]
}

///|
fn byte_buffer_write_address_body(
  require_buffer : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_buffer.call(),
    LocalGet(2),
    require_buffer.call(),
    LocalGet(1),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I64Const(4L),
    I64Add,
    LocalGet(0),
    I32Load(0, 2, 8L),
    I64ExtendI32U,
    I64GtU,
    If(Empty, [Unreachable], []),
    LocalGet(3),
    LocalGet(2),
    I32Load(0, 2, 8L),
    I32GtU,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32WrapI64,
    LocalSet(4),
    LocalGet(0),
    LocalGet(4),
    I32Add,
    LocalGet(2),
    I32Const(12),
    I32Add,
    LocalGet(3),
    I32Add,
    I32Store(0, 2, 12L),
  ]
}

///|
fn byte_buffer_read_i32_body(
  require_buffer : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_buffer.call(),
    LocalGet(1),
    I64Const(0L),
    I64LtS,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I64Const(4L),
    I64Add,
    LocalGet(0),
    I32Load(0, 2, 8L),
    I64ExtendI32U,
    I64GtU,
    If(Empty, [Unreachable], []),
    LocalGet(1),
    I32WrapI64,
    LocalSet(2),
    LocalGet(0),
    LocalGet(2),
    I32Add,
    I32Load(0, 2, 12L),
  ]
}

///|
fn byte_sequence_equal_body(
  require_byte_sequence_layout_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_byte_sequence_layout_function.call(),
    LocalGet(1),
    require_byte_sequence_layout_function.call(),
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
  require_byte_sequence_layout_function : WasmFunctionHandle,
  byte_sequence_new_function : WasmFunctionHandle,
  release_ref_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_byte_sequence_layout_function.call(),
    LocalGet(1),
    require_byte_sequence_layout_function.call(),
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
    If(Empty, runtime_failure(), []),
    LocalGet(4),
    byte_sequence_new_function.call(),
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
    release_ref_function.call(),
    LocalGet(1),
    release_ref_function.call(),
    LocalGet(5),
  ]
}

///|
fn byte_sequence_slice_body(
  require_byte_sequence_layout_function : WasmFunctionHandle,
  byte_sequence_new_function : WasmFunctionHandle,
  release_ref_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_byte_sequence_layout_function.call(),
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
    byte_sequence_new_function.call(),
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
    release_ref_function.call(),
    LocalGet(6),
  ]
}

///|
fn byte_sequence_is_valid_utf8_body(
  require_byte_sequence_layout_function : WasmFunctionHandle,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(0),
    require_byte_sequence_layout_function.call(),
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
