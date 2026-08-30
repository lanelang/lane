///|
priv struct StaticImage {
  bytes : Bytes
  layout_table_base : Int
  global_table_base : Int
  heap_base : Int
  constant_refs : Array[Int]
  singleton_refs : Array[Int]
  singleton_layout_ids : Array[Int]
  byte_sequence_layout_id : Int
  shape_layouts : Array[ShapeLayout]
  shape_layout_ids : Array[Int]
  object_shapes : Array[@physical.ObjectShape]
  globals : Array[@physical.GlobalMetadata]
  callable_abis : Array[@physical.CallableAbi]
  callable_target_abi_table_base : Int
  callable_table_size : Int
  global_lifecycle : @physical.GlobalLifecyclePlan
  global_cleanup_table_base : Int
}

///|
priv struct WasmRuntimeLayoutIds {
  byte_sequence : Int
  reference : Int
}

///|
fn wasm_runtime_layout_ids(
  image : @physical.PhysicalProgram,
) -> WasmRuntimeLayoutIds {
  let mut byte_sequence = 0
  let mut reference = 0
  for index, layout in image.layouts {
    if layout is ByteSequence {
      byte_sequence = index + 1
    }
    if layout is Reference {
      reference = index + 1
    }
  }
  { byte_sequence, reference, }
}

///|
priv struct ShapeLayout {
  size : Int
  witness_base : Int
  member_offsets : Array[Int]
}

///|
fn align_up(value : Int, alignment : Int) -> Int {
  (value + alignment - 1) & (0 - alignment)
}

///|
fn representation_size(representation : @physical.Representation) -> Int {
  match representation {
    I32 | F32 => 4
    I64 | F64 => 8
  }
}

///|
fn representation_alignment(representation : @physical.Representation) -> Int {
  representation_size(representation)
}

///|
fn object_shape_layout(shape : @physical.ObjectShape) -> ShapeLayout {
  let (witness_base, witness_count, members) = match shape {
    Data(shape) => (12, shape.stored_witness_count, shape.members)
    Environment(shape) => (8, shape.stored_witness_count, shape.members)
  }
  let mut offset = witness_base
  offset += witness_count * 4
  let member_offsets : Array[Int] = []
  for field_schema in members {
    offset = align_up(
      offset,
      representation_alignment(field_schema.representation),
    )
    member_offsets.push(offset)
    offset += representation_size(field_schema.representation)
  }
  { size: align_up(offset, 8), witness_base, member_offsets, }
}

///|
fn layout_rep_kind(layout : @physical.LayoutRecipe) -> Int {
  match layout {
    Unit => 1
    Bool => 2
    I64 => 3
    F64 => 4
    Callable => 5
    ByteSequence => 6
    Data(_) => 7
    Environment(_) => 8
    Reference => 9
    Byte => 10
    I32 => 12
    Char => 13
    F32 => 14
  }
}

///|
fn layout_fixed_size(
  image : @physical.PhysicalProgram,
  shape_layouts : Array[ShapeLayout],
  layout : @physical.LayoutRecipe,
) -> Int? {
  match layout {
    Unit | Bool | I64 | I32 | Char | F64 | F32 | Callable | Byte => Some(0)
    Reference => Some(0)
    ByteSequence => None
    Data(shape) | Environment(shape) => {
      ignore(image)
      Some(shape_layouts[shape.value].size)
    }
  }
}

///|
fn write_zeroes(writer : @bytecodec.ByteWriter, count : Int) -> Unit {
  for _ in 0..<count {
    writer.write_u8(0)
  }
}

///|
fn pad_to(writer : @bytecodec.ByteWriter, alignment : Int) -> Unit {
  write_zeroes(writer, align_up(writer.length(), alignment) - writer.length())
}

///|
fn instruction_requires_byte_sequence_layout(
  instruction : @physical.Instruction,
) -> Bool {
  match instruction {
    ConstString(_, _)
    | ByteSequenceMake(_, _, _)
    | ByteSequenceLength(_, _)
    | ByteSequenceGet(_, _, _)
    | ByteSequenceSet(_, _, _, _)
    | ByteSequenceEqual(_, _, _)
    | ByteSequenceConcat(_, _, _)
    | ByteSequenceSlice(_, _, _, _)
    | ByteSequenceIsValidUtf8(_, _)
    | ByteSequenceAddress(_, _, _)
    | ByteSequenceStoreAddress(_, _, _, _) => true
    _ => false
  }
}

///|
fn image_requires_byte_sequence_layout(
  image : @physical.PhysicalProgram,
) -> Bool {
  if !image.constants.is_empty() {
    return true
  }
  for function in image.functions {
    match function {
      RuntimeImport(_) => ()
      PhysicalBody(body) =>
        for block in body.blocks {
          if block.instructions.any(instruction_requires_byte_sequence_layout) {
            return true
          }
        }
    }
  }
  false
}

///|
fn build_static_image(
  image : @physical.PhysicalProgram,
  global_lifecycle : @physical.GlobalLifecyclePlan,
  function_catalog : WasmFunctionCatalog,
) -> StaticImage raise WasmCompileError {
  let writer = @bytecodec.ByteWriter::new()
  let shape_layouts = image.object_shapes.map(object_shape_layout)
  let shape_layout_ids = Array::make(image.object_shapes.length(), 0)
  write_zeroes(writer, 8)
  let layout_table_base = writer.length()
  write_zeroes(writer, 32)
  let byte_sequence_layout_id = function_catalog.runtime_layouts.byte_sequence
  for index, layout in image.layouts {
    match layout {
      Data(shape) | Environment(shape) =>
        shape_layout_ids[shape.value] = index + 1
      _ => ()
    }
    writer.write_u32_le_int(layout_rep_kind(layout))
    match layout_fixed_size(image, shape_layouts, layout) {
      Some(size) => {
        writer.write_u32_le_int(1)
        writer.write_u32_le_int(size)
      }
      None => {
        writer.write_u32_le_int(2)
        writer.write_u32_le_int(
          function_catalog.table_slot(
            function_catalog.helper(ByteSequenceSizer),
          ).index,
        )
      }
    }
    writer.write_u32_le_int(
      match layout {
        Unit | Bool | I64 | I32 | Char | F64 | F32 | Callable | Byte => 1
        ByteSequence | Data(_) | Environment(_) | Reference => 8
      },
    )
    writer.write_u32_le_int(
      match layout {
        Unit | Bool | I64 | I32 | Char | F64 | F32 | Byte =>
          function_catalog.table_slot(function_catalog.helper(NoopErased)).index
        Callable =>
          function_catalog.table_slot(function_catalog.helper(RetainCallable)).index
        ByteSequence | Data(_) | Environment(_) | Reference =>
          function_catalog.table_slot(
            function_catalog.helper(RetainReferenceErased),
          ).index
      },
    )
    writer.write_u32_le_int(
      match layout {
        Unit | Bool | I64 | I32 | Char | F64 | F32 | Byte =>
          function_catalog.table_slot(function_catalog.helper(NoopErased)).index
        Callable =>
          function_catalog.table_slot(function_catalog.helper(ReleaseCallable)).index
        ByteSequence | Data(_) | Environment(_) | Reference =>
          function_catalog.table_slot(
            function_catalog.helper(ReleaseReferenceErased),
          ).index
      },
    )
    writer.write_u32_le_int(
      match layout {
        Data(shape) | Environment(shape) =>
          function_catalog.table_slot(
            function_catalog.helper(DestroyShape(shape=shape.value)),
          ).index
        Unit
        | Bool
        | I64
        | I32
        | Char
        | F64
        | F32
        | Callable
        | ByteSequence
        | Byte
        | Reference =>
          function_catalog.table_slot(function_catalog.helper(DestroyNoop)).index
      },
    )
    writer.write_u32_le_int(0)
  }
  if image_requires_byte_sequence_layout(image) && byte_sequence_layout_id == 0 {
    raise MissingByteSequenceLayout
  }
  let constant_refs : Array[Int] = []
  for constant in image.constants {
    pad_to(writer, 8)
    constant_refs.push(writer.length())
    writer.write_i32_le(-1)
    writer.write_u32_le_int(byte_sequence_layout_id)
    writer.write_u32_le_int(constant.length())
    writer.write_raw_bytes(constant)
    pad_to(writer, 8)
  }
  let singleton_refs = Array::make(image.object_shapes.length(), 0)
  let singleton_layout_ids = Array::make(image.object_shapes.length(), 0)
  for shape_index, shape in image.object_shapes {
    if shape is Data(data) &&
      data.stored_witness_count == 0 &&
      data.members.is_empty() {
      let mut layout_id = 0
      for layout_index, layout in image.layouts {
        if layout is Data(layout_shape) && layout_shape.value == shape_index {
          layout_id = layout_index + 1
        }
      }
      if layout_id != 0 {
        pad_to(writer, 8)
        singleton_refs[shape_index] = writer.length()
        singleton_layout_ids[shape_index] = layout_id
        writer.write_i32_le(-1)
        writer.write_u32_le_int(layout_id)
        writer.write_u32_le_int(data.constructor_tag)
        pad_to(writer, 8)
      }
    }
  }
  let callable_table_size = function_catalog.callable_value_table_size()
  let mut callable_target_abi_table_base = 0
  if callable_table_size > 1 {
    pad_to(writer, 4)
    callable_target_abi_table_base = writer.length()
    let callable_target_abis = Array::make(callable_table_size, 0)
    for function_index, _ in image.functions {
      let function : @physical.FunctionId = { value: function_index + 1, }
      if function_catalog.image_table_slot(function) is Some(table_slot) {
        let abi = match image.function_callable_abi_id(function) {
          Some(abi) => abi
          None =>
            raise ValidationFailure(
              detail="callable table target has no canonical ABI",
            )
        }
        callable_target_abis[table_slot.index] = abi.value + 1
      }
    }
    for abi in callable_target_abis {
      writer.write_i32_le(abi)
    }
  }
  pad_to(writer, 8)
  let global_table_base = writer.length()
  write_zeroes(writer, image.globals.length() * 8)
  let global_cleanup_table_base = writer.length()
  for root in global_lifecycle.owned_roots {
    let cleanup_tag = match root.cleanup {
      OwnedRef => 1
      OwnedCallable => 2
      OwnedErased => 3
      Trivial => abort("owned root has trivial cleanup")
    }
    writer.write_i32_le((root.global.value << 2) | cleanup_tag)
  }
  pad_to(writer, 8)
  let heap_base = writer.length()
  {
    bytes: writer.to_bytes(),
    layout_table_base,
    global_table_base,
    heap_base,
    constant_refs,
    singleton_refs,
    singleton_layout_ids,
    byte_sequence_layout_id,
    shape_layouts,
    shape_layout_ids,
    object_shapes: image.object_shapes,
    globals: image.globals,
    callable_abis: image.callable_abis,
    callable_target_abi_table_base,
    callable_table_size,
    global_lifecycle,
    global_cleanup_table_base,
  }
}

///|
fn StaticImage::callable_abi(
  self : StaticImage,
  abi : @physical.CallableAbiId,
) -> @physical.CallableAbi {
  self.callable_abis[abi.value]
}
