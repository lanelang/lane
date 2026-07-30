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
  reference_layout_id : Int
  shape_layouts : Array[ShapeLayout]
  object_shapes : Array[@bytecode.ObjectShape]
  globals : Array[@bytecode.GlobalMetadata]
  wasm_function_offset : Int
  callable_table_indices : Array[Int]
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
fn representation_size(representation : @bytecode.Representation) -> Int {
  match representation {
    I32 | F32 => 4
    I64 | F64 => 8
  }
}

///|
fn representation_alignment(representation : @bytecode.Representation) -> Int {
  representation_size(representation)
}

///|
fn object_shape_layout(shape : @bytecode.ObjectShape) -> ShapeLayout {
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
  { size: align_up(offset, 8), witness_base, member_offsets }
}

///|
fn layout_rep_kind(layout : @bytecode.LayoutRecipe) -> Int {
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
  image : @bytecode.BytecodeImage,
  shape_layouts : Array[ShapeLayout],
  layout : @bytecode.LayoutRecipe,
  host_objects_enabled : Bool,
) -> Int? {
  match layout {
    Unit | Bool | I64 | I32 | Char | F64 | F32 | Callable | Byte => Some(0)
    Reference => Some(if host_objects_enabled { 16 } else { 0 })
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
  instruction : @bytecode.Instruction,
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
    | ByteSequenceIsValidUtf8(_, _) => true
    _ => false
  }
}

///|
fn image_requires_byte_sequence_layout(image : @bytecode.BytecodeImage) -> Bool {
  if !image.constants.is_empty() {
    return true
  }
  for function in image.functions {
    match function {
      RuntimeImport(import_) =>
        if import_.result == String ||
          import_.parameters.any(parameter => parameter == String) {
          return true
        }
      BytecodeBody(body) =>
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
  image : @bytecode.BytecodeImage,
  helper_functions : HelperFunctions,
  wasm_function_offset : Int,
  host_objects_enabled : Bool,
  callable_table_indices : Array[Int],
) -> StaticImage raise WasmCompileError {
  let writer = @bytecodec.ByteWriter::new()
  let shape_layouts = image.object_shapes.map(object_shape_layout)
  write_zeroes(writer, 8)
  let layout_table_base = writer.length()
  write_zeroes(writer, 32)
  let mut byte_sequence_layout_id = 0
  let mut reference_layout_id = 0
  for index, layout in image.layouts {
    if layout == ByteSequence {
      byte_sequence_layout_id = index + 1
    }
    if layout == Reference {
      reference_layout_id = index + 1
    }
    writer.write_u32_le_int(layout_rep_kind(layout))
    match
      layout_fixed_size(image, shape_layouts, layout, host_objects_enabled) {
      Some(size) => {
        writer.write_u32_le_int(1)
        writer.write_u32_le_int(size)
      }
      None => {
        writer.write_u32_le_int(2)
        writer.write_u32_le_int(helper_functions.byte_sequence_sizer_table)
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
          helper_functions.noop_erased_table
        Callable => helper_functions.retain_callable_table
        ByteSequence | Data(_) | Environment(_) | Reference =>
          helper_functions.retain_ref_erased_table
      },
    )
    writer.write_u32_le_int(
      match layout {
        Unit | Bool | I64 | I32 | Char | F64 | F32 | Byte =>
          helper_functions.noop_erased_table
        Callable => helper_functions.release_callable_table
        ByteSequence | Data(_) | Environment(_) | Reference =>
          helper_functions.release_ref_erased_table
      },
    )
    writer.write_u32_le_int(
      match layout {
        Data(shape) | Environment(shape) =>
          helper_functions.destroy_shape_table_base + shape.value
        Reference if host_objects_enabled =>
          helper_functions.destroy_host_object_table
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
        | Reference => helper_functions.destroy_noop_table
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
  pad_to(writer, 8)
  let global_table_base = writer.length()
  write_zeroes(writer, image.globals.length() * 16)
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
    reference_layout_id,
    shape_layouts,
    object_shapes: image.object_shapes,
    globals: image.globals,
    wasm_function_offset,
    callable_table_indices,
  }
}

///|
fn StaticImage::callable_table_index(
  self : StaticImage,
  function : @bytecode.FunctionId,
) -> Int {
  self.callable_table_indices[function.value - 1]
}
