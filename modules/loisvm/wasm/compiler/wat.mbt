///|
pub fn module_to_wat(module_ : @wasm_types.Module) -> String {
  let builder = StringBuilder::StringBuilder()
  builder.write_string("(module\n")
  write_types(builder, module_)
  write_imports(builder, module_)
  write_tables(builder, module_)
  write_memories(builder, module_)
  write_globals(builder, module_)
  write_tags(builder, module_)
  write_exports(builder, module_)
  write_start(builder, module_)
  write_elements(builder, module_)
  write_functions(builder, module_)
  write_data_segments(builder, module_)
  builder.write_string(")\n")
  builder.to_string()
}

///|
fn write_types(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  for index, subtype in module_.types {
    builder.write_string("  (type (;")
    builder.write_string(index.to_string())
    builder.write_string(";) ")
    write_subtype(builder, subtype)
    builder.write_string(")\n")
  }
}

///|
fn write_subtype(
  builder : StringBuilder,
  subtype : @wasm_types.SubType,
) -> Unit {
  if !subtype.final_ || !subtype.supertypes.is_empty() {
    builder.write_string("(sub")
    if !subtype.final_ {
      builder.write_string(" open")
    }
    for supertype in subtype.supertypes {
      builder.write_string(" ")
      builder.write_string(supertype.to_string())
    }
    builder.write_string(" ")
  }
  match subtype.composite {
    Func(function) => write_function_type(builder, function)
    Struct(struct_) => {
      builder.write_string("(struct")
      for field in struct_.fields {
        builder.write_string(" (field ")
        if field.mutable {
          builder.write_string("(mut ")
        }
        write_storage_type(builder, field.storage_type)
        if field.mutable {
          builder.write_string(")")
        }
        builder.write_string(")")
      }
      builder.write_string(")")
    }
    Array(array) => {
      builder.write_string("(array ")
      if array.element.mutable {
        builder.write_string("(mut ")
      }
      write_storage_type(builder, array.element.storage_type)
      if array.element.mutable {
        builder.write_string(")")
      }
      builder.write_string(")")
    }
  }
  if !subtype.final_ || !subtype.supertypes.is_empty() {
    builder.write_string(")")
  }
}

///|
fn write_function_type(
  builder : StringBuilder,
  function : @wasm_types.FuncType,
) -> Unit {
  builder.write_string("(func")
  write_value_types(builder, "param", function.params)
  write_value_types(builder, "result", function.results)
  builder.write_string(")")
}

///|
fn write_value_types(
  builder : StringBuilder,
  label : String,
  types : Array[@wasm_types.ValueType],
) -> Unit {
  if types.is_empty() {
    return
  }
  builder.write_string(" (")
  builder.write_string(label)
  for type_ in types {
    builder.write_string(" ")
    write_value_type(builder, type_)
  }
  builder.write_string(")")
}

///|
fn write_storage_type(
  builder : StringBuilder,
  storage : @wasm_types.StorageType,
) -> Unit {
  match storage {
    Val(type_) => write_value_type(builder, type_)
    Packed(I8) => builder.write_string("i8")
    Packed(I16) => builder.write_string("i16")
  }
}

///|
fn write_imports(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  for import_ in module_.imports {
    builder.write_string("  (import ")
    write_quoted(builder, import_.mod_name)
    builder.write_string(" ")
    write_quoted(builder, import_.name)
    builder.write_string(" ")
    write_import_desc(builder, import_.desc)
    builder.write_string(")\n")
  }
}

///|
fn write_import_desc(
  builder : StringBuilder,
  desc : @wasm_types.ImportDesc,
) -> Unit {
  match desc {
    Func(type_index) => {
      builder.write_string("(func (type ")
      builder.write_string(type_index.to_string())
      builder.write_string("))")
    }
    Table(table) => {
      builder.write_string("(table ")
      write_limits(builder, table.limits)
      builder.write_string(" ")
      write_value_type(builder, table.elem_type)
      builder.write_string(")")
    }
    Memory(memory) => {
      builder.write_string("(memory ")
      write_limits(builder, memory.limits)
      builder.write_string(")")
    }
    Global(global) => {
      builder.write_string("(global ")
      write_global_type(builder, global)
      builder.write_string(")")
    }
    Tag(type_index) => {
      builder.write_string("(tag (type ")
      builder.write_string(type_index.to_string())
      builder.write_string("))")
    }
  }
}

///|
fn write_tables(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  for index, table in module_.tables {
    builder.write_string("  (table (;")
    builder.write_string(index.to_string())
    builder.write_string(";) ")
    write_limits(builder, table.type_.limits)
    builder.write_string(" ")
    write_value_type(builder, table.type_.elem_type)
    if table.init is Some(initializer) {
      builder.write_string(" (")
      write_instructions_inline(builder, initializer)
      builder.write_string(")")
    }
    builder.write_string(")\n")
  }
}

///|
fn write_memories(
  builder : StringBuilder,
  module_ : @wasm_types.Module,
) -> Unit {
  for index, memory in module_.memories {
    builder.write_string("  (memory (;")
    builder.write_string(index.to_string())
    builder.write_string(";) ")
    write_limits(builder, memory.limits)
    builder.write_string(")\n")
  }
}

///|
fn write_globals(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  for index, global in module_.globals {
    builder.write_string("  (global (;")
    builder.write_string(index.to_string())
    builder.write_string(";) ")
    write_global_type(builder, global.type_)
    builder.write_string(" (")
    write_instructions_inline(builder, global.init)
    builder.write_string("))\n")
  }
}

///|
fn write_tags(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  for index, tag in module_.tags {
    builder.write_string("  (tag (;")
    builder.write_string(index.to_string())
    builder.write_string(";) (type ")
    builder.write_string(tag.type_idx.to_string())
    builder.write_string("))\n")
  }
}

///|
fn write_exports(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  for export_ in module_.exports {
    builder.write_string("  (export ")
    write_quoted(builder, export_.name)
    builder.write_string(" ")
    match export_.desc {
      Func(index) => write_indexed_desc(builder, "func", index)
      Table(index) => write_indexed_desc(builder, "table", index)
      Memory(index) => write_indexed_desc(builder, "memory", index)
      Global(index) => write_indexed_desc(builder, "global", index)
      Tag(index) => write_indexed_desc(builder, "tag", index)
    }
    builder.write_string(")\n")
  }
}

///|
fn write_indexed_desc(
  builder : StringBuilder,
  name : String,
  index : Int,
) -> Unit {
  builder.write_string("(")
  builder.write_string(name)
  builder.write_string(" ")
  builder.write_string(index.to_string())
  builder.write_string(")")
}

///|
fn write_start(builder : StringBuilder, module_ : @wasm_types.Module) -> Unit {
  if module_.start is Some(index) {
    builder.write_string("  (start ")
    builder.write_string(index.to_string())
    builder.write_string(")\n")
  }
}

///|
fn write_elements(
  builder : StringBuilder,
  module_ : @wasm_types.Module,
) -> Unit {
  for index, element in module_.elems {
    builder.write_string("  (elem (;")
    builder.write_string(index.to_string())
    builder.write_string(";) ")
    match element.mode {
      Passive => ()
      Declarative => builder.write_string("declare ")
      Active(table_index, offset) => {
        if table_index != 0 {
          builder.write_string("(table ")
          builder.write_string(table_index.to_string())
          builder.write_string(") ")
        }
        builder.write_string("(")
        write_instructions_inline(builder, offset)
        builder.write_string(") ")
      }
    }
    write_value_type(builder, element.type_)
    for initializer in element.init {
      builder.write_string(" (")
      write_instructions_inline(builder, initializer)
      builder.write_string(")")
    }
    builder.write_string(")\n")
  }
}

///|
fn write_functions(
  builder : StringBuilder,
  module_ : @wasm_types.Module,
) -> Unit {
  let mut imported_function_count = 0
  for import_ in module_.imports {
    if import_.desc is Func(_) {
      imported_function_count += 1
    }
  }
  for index, code in module_.codes {
    let function_index = imported_function_count + index
    let type_index = module_.funcs[index]
    builder.write_string("  (func (;")
    builder.write_string(function_index.to_string())
    builder.write_string(";) (type ")
    builder.write_string(type_index.to_string())
    builder.write_string(")")
    if type_index < module_.types.length() &&
      module_.types[type_index].composite is Func(function_type) {
      write_value_types(builder, "param", function_type.params)
      write_value_types(builder, "result", function_type.results)
    }
    builder.write_string("\n")
    write_locals(builder, code.locals)
    write_instructions(builder, code.body, 2)
    builder.write_string("  )\n")
  }
}

///|
fn write_locals(
  builder : StringBuilder,
  locals : Array[@wasm_types.ValueType],
) -> Unit {
  if locals.is_empty() {
    return
  }
  builder.write_string("    (local")
  for local_type in locals {
    builder.write_string(" ")
    write_value_type(builder, local_type)
  }
  builder.write_string(")\n")
}

///|
fn write_data_segments(
  builder : StringBuilder,
  module_ : @wasm_types.Module,
) -> Unit {
  for index, data in module_.datas {
    builder.write_string("  (data (;")
    builder.write_string(index.to_string())
    builder.write_string(";) ")
    if data.memory_idx != 0 {
      builder.write_string("(memory ")
      builder.write_string(data.memory_idx.to_string())
      builder.write_string(") ")
    }
    if !data.offset.is_empty() {
      builder.write_string("(")
      write_instructions_inline(builder, data.offset)
      builder.write_string(") ")
    }
    write_escaped_bytes(builder, data.init)
    builder.write_string(")\n")
  }
}

///|
fn write_instructions(
  builder : StringBuilder,
  instructions : Array[@wasm_types.Instruction],
  indent : Int,
) -> Unit {
  for instruction in instructions {
    write_indent(builder, indent)
    match instruction {
      Block(type_, body) => {
        builder.write_string("block")
        write_block_type(builder, type_)
        builder.write_string("\n")
        write_instructions(builder, body, indent + 1)
        write_indent(builder, indent)
        builder.write_string("end\n")
      }
      Loop(type_, body) => {
        builder.write_string("loop")
        write_block_type(builder, type_)
        builder.write_string("\n")
        write_instructions(builder, body, indent + 1)
        write_indent(builder, indent)
        builder.write_string("end\n")
      }
      If(type_, then_body, else_body) => {
        builder.write_string("if")
        write_block_type(builder, type_)
        builder.write_string("\n")
        write_instructions(builder, then_body, indent + 1)
        if !else_body.is_empty() {
          write_indent(builder, indent)
          builder.write_string("else\n")
          write_instructions(builder, else_body, indent + 1)
        }
        write_indent(builder, indent)
        builder.write_string("end\n")
      }
      TryTable(type_, handlers, body) => {
        builder.write_string("try_table")
        write_block_type(builder, type_)
        for handler in handlers {
          builder.write_string(" ")
          write_catch_handler(builder, handler)
        }
        builder.write_string("\n")
        write_instructions(builder, body, indent + 1)
        write_indent(builder, indent)
        builder.write_string("end\n")
      }
      _ => {
        write_instruction(builder, instruction)
        builder.write_string("\n")
      }
    }
  }
}

///|
fn write_instructions_inline(
  builder : StringBuilder,
  instructions : Array[@wasm_types.Instruction],
) -> Unit {
  for index, instruction in instructions {
    if index > 0 {
      builder.write_string(" ")
    }
    write_instruction(builder, instruction)
  }
}

///|
fn write_instruction(
  builder : StringBuilder,
  instruction : @wasm_types.Instruction,
) -> Unit {
  match instruction {
    Unreachable => builder.write_string("unreachable")
    Br(index) => write_named_index(builder, "br", index)
    BrIf(index) => write_named_index(builder, "br_if", index)
    BrTable(indices, default) => {
      builder.write_string("br_table")
      for index in indices {
        builder.write_string(" ")
        builder.write_string(index.to_string())
      }
      builder.write_string(" ")
      builder.write_string(default.to_string())
    }
    Return => builder.write_string("return")
    Call(index) => write_named_index(builder, "call", index)
    CallIndirect(type_index, table_index) => {
      builder.write_string("call_indirect (type ")
      builder.write_string(type_index.to_string())
      builder.write_string(")")
      if table_index != 0 {
        builder.write_string(" (table ")
        builder.write_string(table_index.to_string())
        builder.write_string(")")
      }
    }
    ReturnCall(index) => write_named_index(builder, "return_call", index)
    ReturnCallIndirect(type_index, table_index) => {
      builder.write_string("return_call_indirect (type ")
      builder.write_string(type_index.to_string())
      builder.write_string(")")
      if table_index != 0 {
        builder.write_string(" (table ")
        builder.write_string(table_index.to_string())
        builder.write_string(")")
      }
    }
    Throw(index) => write_named_index(builder, "throw", index)
    LocalGet(index) => write_named_index(builder, "local.get", index)
    LocalSet(index) => write_named_index(builder, "local.set", index)
    GlobalGet(index) => write_named_index(builder, "global.get", index)
    GlobalSet(index) => write_named_index(builder, "global.set", index)
    I32Load(memory, align, offset) =>
      write_memory_instruction(builder, "i32.load", memory, align, offset, 2)
    I64Load(memory, align, offset) =>
      write_memory_instruction(builder, "i64.load", memory, align, offset, 3)
    F64Load(memory, align, offset) =>
      write_memory_instruction(builder, "f64.load", memory, align, offset, 3)
    I32Load8U(memory, align, offset) =>
      write_memory_instruction(builder, "i32.load8_u", memory, align, offset, 0)
    I32Store(memory, align, offset) =>
      write_memory_instruction(builder, "i32.store", memory, align, offset, 2)
    I64Store(memory, align, offset) =>
      write_memory_instruction(builder, "i64.store", memory, align, offset, 3)
    F64Store(memory, align, offset) =>
      write_memory_instruction(builder, "f64.store", memory, align, offset, 3)
    MemorySize(memory) => write_optional_index(builder, "memory.size", memory)
    MemoryGrow(memory) => write_optional_index(builder, "memory.grow", memory)
    MemoryCopy(destination, source) => {
      builder.write_string("memory.copy")
      if destination != 0 || source != 0 {
        builder.write_string(" ")
        builder.write_string(destination.to_string())
        builder.write_string(" ")
        builder.write_string(source.to_string())
      }
    }
    RefNull(type_) => {
      builder.write_string("ref.null ")
      write_heap_type(builder, type_)
    }
    RefFunc(index) => write_named_index(builder, "ref.func", index)
    I32Const(value) =>
      write_named_value(builder, "i32.const", value.to_string())
    I64Const(value) =>
      write_named_value(builder, "i64.const", value.to_string())
    F64Const(value) =>
      write_named_value(builder, "f64.const", value.to_string())
    I32Eqz => builder.write_string("i32.eqz")
    I32Eq => builder.write_string("i32.eq")
    I32Ne => builder.write_string("i32.ne")
    I32LtU => builder.write_string("i32.lt_u")
    I32GtU => builder.write_string("i32.gt_u")
    I32GeU => builder.write_string("i32.ge_u")
    I32Add => builder.write_string("i32.add")
    I32Sub => builder.write_string("i32.sub")
    I32And => builder.write_string("i32.and")
    I32Or => builder.write_string("i32.or")
    I32Shl => builder.write_string("i32.shl")
    I32ShrU => builder.write_string("i32.shr_u")
    I64Eq => builder.write_string("i64.eq")
    I64Ne => builder.write_string("i64.ne")
    I64LtS => builder.write_string("i64.lt_s")
    I64LtU => builder.write_string("i64.lt_u")
    I64GtS => builder.write_string("i64.gt_s")
    I64LeS => builder.write_string("i64.le_s")
    I64GeS => builder.write_string("i64.ge_s")
    I64Add => builder.write_string("i64.add")
    I64Sub => builder.write_string("i64.sub")
    I64Mul => builder.write_string("i64.mul")
    I64DivS => builder.write_string("i64.div_s")
    I64RemS => builder.write_string("i64.rem_s")
    I64And => builder.write_string("i64.and")
    I64Or => builder.write_string("i64.or")
    I64Xor => builder.write_string("i64.xor")
    I64Shl => builder.write_string("i64.shl")
    I64ShrS => builder.write_string("i64.shr_s")
    I64ShrU => builder.write_string("i64.shr_u")
    F64Eq => builder.write_string("f64.eq")
    F64Ne => builder.write_string("f64.ne")
    F64Lt => builder.write_string("f64.lt")
    F64Gt => builder.write_string("f64.gt")
    F64Le => builder.write_string("f64.le")
    F64Ge => builder.write_string("f64.ge")
    F64Neg => builder.write_string("f64.neg")
    F64Add => builder.write_string("f64.add")
    F64Sub => builder.write_string("f64.sub")
    F64Mul => builder.write_string("f64.mul")
    F64Div => builder.write_string("f64.div")
    I32WrapI64 => builder.write_string("i32.wrap_i64")
    I64ExtendI32U => builder.write_string("i64.extend_i32_u")
    I64TruncF64S => builder.write_string("i64.trunc_f64_s")
    F64ConvertI64S => builder.write_string("f64.convert_i64_s")
    I64ReinterpretF64 => builder.write_string("i64.reinterpret_f64")
    F64ReinterpretI64 => builder.write_string("f64.reinterpret_i64")
    unsupported => {
      builder.write_string("(; unsupported ")
      builder.write_string(to_repr(unsupported).to_string())
      builder.write_string(" ;)")
    }
  }
}

///|
fn write_heap_type(
  builder : StringBuilder,
  type_ : @wasm_types.ValueType,
) -> Unit {
  match type_ {
    FuncRef | RefFunc => builder.write_string("func")
    ExternRef | RefExtern => builder.write_string("extern")
    AnyRef | RefAny => builder.write_string("any")
    ExnRef => builder.write_string("exn")
    RefEq | RefNullEq => builder.write_string("eq")
    RefI31 | RefNullI31 => builder.write_string("i31")
    RefFuncTyped(index) | RefNullFuncTyped(index) =>
      builder.write_string(index.to_string())
    RefStruct(index) | RefNullStruct(index) =>
      builder.write_string(index.to_string())
    RefArray(index) | RefNullArray(index) =>
      builder.write_string(index.to_string())
    RefStructAbs | StructRef => builder.write_string("struct")
    RefArrayAbs | ArrayRef => builder.write_string("array")
    RefNone | NullRef => builder.write_string("none")
    NullFuncRef => builder.write_string("nofunc")
    NullExternRef => builder.write_string("noextern")
    NullExnRef => builder.write_string("noexn")
    _ => write_value_type(builder, type_)
  }
}

///|
fn write_catch_handler(
  builder : StringBuilder,
  handler : @wasm_types.CatchHandler,
) -> Unit {
  match handler {
    Catch(tag, label) => write_catch(builder, "catch", Some(tag), label)
    CatchRef(tag, label) => write_catch(builder, "catch_ref", Some(tag), label)
    CatchAll(label) => write_catch(builder, "catch_all", None, label)
    CatchAllRef(label) => write_catch(builder, "catch_all_ref", None, label)
  }
}

///|
fn write_catch(
  builder : StringBuilder,
  name : String,
  tag : Int?,
  label : Int,
) -> Unit {
  builder.write_string("(")
  builder.write_string(name)
  if tag is Some(tag) {
    builder.write_string(" ")
    builder.write_string(tag.to_string())
  }
  builder.write_string(" ")
  builder.write_string(label.to_string())
  builder.write_string(")")
}

///|
fn write_block_type(
  builder : StringBuilder,
  type_ : @wasm_types.BlockType,
) -> Unit {
  match type_ {
    Empty => ()
    Value(value) => write_value_types(builder, "result", [value])
    MultiValue(values) => write_value_types(builder, "result", values)
    InlineType(parameters, results) => {
      write_value_types(builder, "param", parameters)
      write_value_types(builder, "result", results)
    }
    TypeIndex(index) => {
      builder.write_string(" (type ")
      builder.write_string(index.to_string())
      builder.write_string(")")
    }
  }
}

///|
fn write_value_type(
  builder : StringBuilder,
  type_ : @wasm_types.ValueType,
) -> Unit {
  match type_ {
    I32 => builder.write_string("i32")
    I64 => builder.write_string("i64")
    F32 => builder.write_string("f32")
    F64 => builder.write_string("f64")
    V128 => builder.write_string("v128")
    FuncRef => builder.write_string("funcref")
    ExternRef => builder.write_string("externref")
    RefFunc => builder.write_string("(ref func)")
    RefExtern => builder.write_string("(ref extern)")
    RefFuncTyped(index) => write_ref_type(builder, false, index.to_string())
    RefNullFuncTyped(index) => write_ref_type(builder, true, index.to_string())
    AnyRef => builder.write_string("anyref")
    ExnRef => builder.write_string("exnref")
    NullRef => builder.write_string("nullref")
    NullFuncRef => builder.write_string("nullfuncref")
    NullExnRef => builder.write_string("nullexnref")
    NullExternRef => builder.write_string("nullexternref")
    StructRef => builder.write_string("structref")
    ArrayRef => builder.write_string("arrayref")
    RefStruct(index) => write_ref_type(builder, false, index.to_string())
    RefNullStruct(index) => write_ref_type(builder, true, index.to_string())
    RefArray(index) => write_ref_type(builder, false, index.to_string())
    RefNullArray(index) => write_ref_type(builder, true, index.to_string())
    RefAny => write_ref_type(builder, false, "any")
    RefEq => write_ref_type(builder, false, "eq")
    RefNullEq => write_ref_type(builder, true, "eq")
    RefI31 => write_ref_type(builder, false, "i31")
    RefNullI31 => write_ref_type(builder, true, "i31")
    RefStructAbs => write_ref_type(builder, false, "struct")
    RefArrayAbs => write_ref_type(builder, false, "array")
    RefNone => write_ref_type(builder, false, "none")
  }
}

///|
fn write_ref_type(
  builder : StringBuilder,
  nullable : Bool,
  heap_type : String,
) -> Unit {
  builder.write_string("(ref ")
  if nullable {
    builder.write_string("null ")
  }
  builder.write_string(heap_type)
  builder.write_string(")")
}

///|
fn write_limits(builder : StringBuilder, limits : @wasm_types.Limits) -> Unit {
  builder.write_string(limits.min.to_string())
  if limits.max is Some(max) {
    builder.write_string(" ")
    builder.write_string(max.to_string())
  }
}

///|
fn write_global_type(
  builder : StringBuilder,
  global : @wasm_types.GlobalType,
) -> Unit {
  if global.mutable {
    builder.write_string("(mut ")
    write_value_type(builder, global.value_type)
    builder.write_string(")")
  } else {
    write_value_type(builder, global.value_type)
  }
}

///|
fn write_memory_instruction(
  builder : StringBuilder,
  name : String,
  memory : Int,
  align : Int,
  offset : Int64,
  natural_align : Int,
) -> Unit {
  builder.write_string(name)
  if memory != 0 {
    builder.write_string(" ")
    builder.write_string(memory.to_string())
  }
  if offset != 0L {
    builder.write_string(" offset=")
    builder.write_string(offset.to_string())
  }
  if align != natural_align {
    builder.write_string(" align=")
    builder.write_string((1 << align).to_string())
  }
}

///|
fn write_named_index(
  builder : StringBuilder,
  name : String,
  index : Int,
) -> Unit {
  write_named_value(builder, name, index.to_string())
}

///|
fn write_optional_index(
  builder : StringBuilder,
  name : String,
  index : Int,
) -> Unit {
  builder.write_string(name)
  if index != 0 {
    builder.write_string(" ")
    builder.write_string(index.to_string())
  }
}

///|
fn write_named_value(
  builder : StringBuilder,
  name : String,
  value : String,
) -> Unit {
  builder.write_string(name)
  builder.write_string(" ")
  builder.write_string(value)
}

///|
fn write_indent(builder : StringBuilder, indent : Int) -> Unit {
  for _ in 0..<indent {
    builder.write_string("  ")
  }
}

///|
fn write_quoted(builder : StringBuilder, value : String) -> Unit {
  builder.write_char('"')
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.write_char('"')
}

///|
fn write_escaped_bytes(builder : StringBuilder, bytes : Bytes) -> Unit {
  builder.write_char('"')
  let hex = "0123456789abcdef"
  for byte in bytes {
    let value = byte.to_int()
    if value >= 32 && value < 127 && value != 0x22 && value != 0x5C {
      builder.write_char(value.unsafe_to_char())
    } else {
      builder.write_char('\\')
      builder.write_char(hex[(value >> 4) & 0xF].to_int().unsafe_to_char())
      builder.write_char(hex[value & 0xF].to_int().unsafe_to_char())
    }
  }
  builder.write_char('"')
}
