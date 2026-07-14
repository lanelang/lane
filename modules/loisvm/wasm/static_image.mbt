///|
priv struct StaticImage {
  bytes : Bytes
  layout_table_base : Int
  global_table_base : Int
  heap_base : Int
  constant_refs : Array[Int]
  singleton_refs : Array[Int]
  singleton_layout_ids : Array[Int]
  string_layout_id : Int
  shape_layouts : Array[ShapeLayout]
  object_shapes : Array[@bytecode.ObjectShape]
  globals : Array[@bytecode.GlobalMetadata]
  wasm_function_offset : Int
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
    I32 => 4
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
    Int => 3
    Double => 4
    Callable => 5
    String => 6
    Data(_) => 7
    Environment(_) => 8
    Reference => 9
  }
}

///|
fn layout_fixed_size(
  image : @bytecode.BytecodeImage,
  shape_layouts : Array[ShapeLayout],
  layout : @bytecode.LayoutRecipe,
) -> Int? {
  match layout {
    Unit | Bool | Int | Double | Callable | Reference => Some(0)
    String => None
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
fn build_static_image(
  image : @bytecode.BytecodeImage,
  helper_functions : HelperFunctions,
  wasm_function_offset : Int,
) -> StaticImage raise WasmCompileError {
  let writer = @bytecodec.ByteWriter::new()
  let shape_layouts = image.object_shapes.map(object_shape_layout)
  write_zeroes(writer, 8)
  let layout_table_base = writer.length()
  write_zeroes(writer, 32)
  let mut string_layout_id = 0
  for index, layout in image.layouts {
    if layout == String {
      string_layout_id = index + 1
    }
    writer.write_u32_le(layout_rep_kind(layout))
    match layout_fixed_size(image, shape_layouts, layout) {
      Some(size) => {
        writer.write_u32_le(1)
        writer.write_u32_le(size)
      }
      None => {
        writer.write_u32_le(2)
        writer.write_u32_le(helper_functions.string_sizer_table)
      }
    }
    writer.write_u32_le(
      match layout {
        Unit | Bool | Int | Double | Callable => 1
        String | Data(_) | Environment(_) | Reference => 8
      },
    )
    writer.write_u32_le(
      match layout {
        Unit | Bool | Int | Double => helper_functions.noop_erased_table
        Callable => helper_functions.retain_callable_table
        String | Data(_) | Environment(_) | Reference =>
          helper_functions.retain_ref_erased_table
      },
    )
    writer.write_u32_le(
      match layout {
        Unit | Bool | Int | Double => helper_functions.noop_erased_table
        Callable => helper_functions.release_callable_table
        String | Data(_) | Environment(_) | Reference =>
          helper_functions.release_ref_erased_table
      },
    )
    writer.write_u32_le(
      match layout {
        Data(shape) | Environment(shape) =>
          helper_functions.destroy_shape_table_base + shape.value
        Unit | Bool | Int | Double | Callable | String | Reference =>
          helper_functions.destroy_noop_table
      },
    )
    writer.write_u32_le(0)
  }
  if !image.constants.is_empty() && string_layout_id == 0 {
    raise MissingStringLayout
  }
  let constant_refs : Array[Int] = []
  for constant in image.constants {
    pad_to(writer, 8)
    constant_refs.push(writer.length())
    writer.write_u32_le(-1)
    writer.write_u32_le(string_layout_id)
    writer.write_u32_le(constant.length())
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
        writer.write_u32_le(-1)
        writer.write_u32_le(layout_id)
        writer.write_u32_le(data.constructor_tag)
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
    string_layout_id,
    shape_layouts,
    object_shapes: image.object_shapes,
    globals: image.globals,
    wasm_function_offset,
  }
}
