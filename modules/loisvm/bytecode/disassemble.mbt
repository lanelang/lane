///|
using @prettyprinter {text}

///|
pub impl @prettyprinter.Pretty for BytecodeImage with fn pretty(
  image : BytecodeImage,
) {
  text(bytecode_image_to_disassembly(image))
}

///|
pub fn bytecode_image_to_disassembly(image : BytecodeImage) -> String {
  let lines = [
    "LoisVM bytecode",
    "entry: \{render_function(image.entry)}",
    "initializer: \{render_optional_function(image.initializer)}",
    "callable ABIs: \{image.callable_abis.length()}",
    "functions: \{image.functions.length()}",
    "globals: \{image.globals.length()}",
    "layouts: \{image.layouts.length()}",
    "object shapes: \{image.object_shapes.length()}",
    "constants: \{image.constants.length()}",
  ]
  lines.push("")
  lines.append(bytecode_image_code_lines(image))
  lines.join("\n")
}

///|
pub fn bytecode_image_to_code(image : BytecodeImage) -> String {
  bytecode_image_code_lines(image).join("\n")
}

///|
fn bytecode_image_code_lines(image : BytecodeImage) -> Array[String] {
  let lines : Array[String] = []
  for index, function in image.functions {
    lines.append(
      render_function_entry(
        index + 1,
        function,
        render_function_callable_abi(image, function),
      ),
    )
    lines.push("")
  }
  if !image.callable_abis.is_empty() {
    lines.push("callable ABI table:")
    for index, abi in image.callable_abis {
      lines.push("  abi\{index} = \{render_callable_abi(abi)}")
    }
    lines.push("")
  }
  if !image.globals.is_empty() {
    lines.push("instance global table:")
    for index, global in image.globals {
      lines.push("  g\{index} = \{render_global_metadata(global)}")
    }
    lines.push("")
  }
  if !image.layouts.is_empty() {
    lines.push("layout table:")
    for index, layout in image.layouts {
      lines.push("  l\{index + 1} = \{render_layout_recipe(layout)}")
    }
    lines.push("")
  }
  if !image.object_shapes.is_empty() {
    lines.push("object shape table:")
    for index, shape in image.object_shapes {
      lines.push("  shape\{index} = \{render_object_shape(shape)}")
    }
    lines.push("")
  }
  if !image.constants.is_empty() {
    lines.push("constant table:")
    for index, constant in image.constants {
      let value = @utf8.decode(constant) catch { _ => "<invalid UTF-8>" }
      lines.push("  c\{index} = \{Repr(value)}")
    }
    lines.push("")
  }
  lines
}

///|
fn render_function_entry(
  id : Int,
  entry : FunctionEntry,
  abi : String,
) -> Array[String] {
  match entry {
    RuntimeImport(import_) => {
      let parameters = import_.parameters
        .map(render_runtime_value_kind)
        .join(", ")
      [
        "function f\{id} abi=\{abi} = runtime_import(",
        "  symbol=\{Repr(import_.symbol)},",
        "  abi_major=\{import_.abi_major},",
        "  parameters=[\{parameters}],",
        "  result=\{render_runtime_value_kind(import_.result)}",
        ")",
      ]
    }
    BytecodeBody(body) => {
      let lines = [
        "function f\{id} abi=\{abi}(",
        "  environment=\{render_optional_slot(body.inputs.environment)},",
        "  witnesses=[\{render_slots(body.inputs.witnesses)}],",
        "  parameters=[\{render_slots(body.inputs.user_parameters)}]",
        ") -> \{render_result(body.result)} {",
        "  slots:",
      ]
      if body.slots.is_empty() {
        lines.push("    (none)")
      } else {
        for index, slot in body.slots {
          lines.push("    %\{index}: \{render_slot_metadata(slot)}")
        }
      }
      for index, block in body.blocks {
        lines.push("  b\{index}([\{render_slots(block.parameters)}]):")
        for instruction in block.instructions {
          lines.push("    \{render_instruction(instruction)}")
        }
        lines.push("    \{render_terminator(block.terminator)}")
      }
      lines.push("}")
      lines
    }
  }
}

///|
fn render_function_callable_abi(
  image : BytecodeImage,
  entry : FunctionEntry,
) -> String {
  guard entry.callable_abi() is Some(expected) else { return "<invalid>" }
  for index, abi in image.callable_abis {
    if abi == expected {
      return "abi\{index}"
    }
  }
  "<missing>"
}

///|
fn render_callable_abi(abi : CallableAbi) -> String {
  let render_operand = fn(operand : ValueAbi) {
    "\{render_representation(operand.representation)} + \{render_cleanup(operand.cleanup)} + \{Repr(operand.kind)}"
  }
  let parameters = abi.parameters.map(render_operand).join(", ")
  let witnesses = abi.witnesses.map(render_operand).join(", ")
  "fn(witnesses=[\{witnesses}], parameters=[\{parameters}]) -> \{render_result(abi.result)}"
}

///|
fn render_runtime_value_kind(kind : RuntimeValueKind) -> String {
  match kind {
    Unit => "unit"
    Bool => "bool"
    I64 => "i64"
    F64 => "f64"
    F32 => "f32"
    String => "string"
    Opaque => "opaque"
  }
}

///|
fn render_instruction(instruction : Instruction) -> String {
  match instruction {
    Copy(destination, source) => unary_instruction("copy", destination, source)
    Move(destination, source) => unary_instruction("move", destination, source)
    RetainCopy(destination, source) =>
      unary_instruction("retain_copy", destination, source)
    Release(source) => "release \{render_slot(source)}"
    ConstI64(destination, value) =>
      "const_i64 \{render_slot(destination)}, \{value}"
    ConstI32(destination, value) =>
      "const_i32 \{render_slot(destination)}, \{value}"
    ConstChar(destination, value) =>
      "const_char \{render_slot(destination)}, \{value}"
    ConstF64(destination, bits) =>
      "const_f64 \{render_slot(destination)}, bits=\{bits}"
    ConstF32(destination, bits) =>
      "const_f32 \{render_slot(destination)}, bits=\{bits}"
    ConstBool(destination, value) =>
      "const_bool \{render_slot(destination)}, \{value}"
    ConstLayout(destination, layout) =>
      "const_layout \{render_slot(destination)}, \{render_layout(layout)}"
    ConstFunction(destination, function) =>
      "const_function \{render_slot(destination)}, \{render_function(function)}"
    ConstString(destination, constant) =>
      "const_string \{render_slot(destination)}, \{render_constant(constant)}"
    CallDirect(function, environment, witnesses, arguments, destination) =>
      "call_direct \{render_optional_destination(destination)}\{render_function(function)} env=\{render_optional_slot(environment)} witnesses=[\{render_slots(witnesses)}] arguments=[\{render_slots(arguments)}]"
    CallValue(callable, abi, witnesses, arguments, destination) =>
      "call_value \{render_optional_destination(destination)}\{render_slot(callable)} abi=abi\{abi.value} witnesses=[\{render_slots(witnesses)}] arguments=[\{render_slots(arguments)}]"
    MakeData(destination, shape, layout, witnesses, fields) =>
      "make_data \{render_slot(destination)}, \{render_shape(shape)}, \{render_layout_operand(layout)}, witnesses=[\{render_slots(witnesses)}], fields=[\{render_slots(fields)}]"
    LoadTag(destination, source) =>
      unary_instruction("load_tag", destination, source)
    LoadObjectWitness(destination, shape, object, ordinal) =>
      "load_object_witness \{render_slot(destination)}, \{render_shape(shape)}, \{render_slot(object)}, \{ordinal}"
    BorrowField(shape, source, index, result) =>
      "borrow_field \{render_projection_result(result)}, \{render_shape(shape)}, \{render_slot(source)}, \{index}"
    ConsumeFields(shape, source, selections) =>
      "consume_fields \{render_shape(shape)}, \{render_slot(source)}, [\{render_selections(selections)}]"
    MakeEnv(destination, shape, layout, witnesses, captures) =>
      "make_env \{render_slot(destination)}, \{render_shape(shape)}, \{render_layout_operand(layout)}, witnesses=[\{render_slots(witnesses)}], captures=[\{render_slots(captures)}]"
    BorrowCapture(shape, source, index, result) =>
      "borrow_capture \{render_projection_result(result)}, \{render_shape(shape)}, \{render_slot(source)}, \{index}"
    ConsumeCaptures(shape, source, selections) =>
      "consume_captures \{render_shape(shape)}, \{render_slot(source)}, [\{render_selections(selections)}]"
    MakeClosure(destination, function, environment) =>
      "make_closure \{render_slot(destination)}, \{render_function(function)}, \{render_slot(environment)}"
    ByteToI64(destination, source) =>
      unary_instruction("byte_to_i64", destination, source)
    I64ToByte(destination, source) =>
      unary_instruction("i64_to_byte", destination, source)
    ByteSequenceMake(destination, length, fill) =>
      binary_instruction("byte_sequence_make", destination, length, fill)
    ByteSequenceLength(destination, source) =>
      unary_instruction("byte_sequence_length", destination, source)
    ByteSequenceGet(destination, source, index) =>
      binary_instruction("byte_sequence_get", destination, source, index)
    ByteSequenceSet(destination, source, index, value) =>
      "byte_sequence_set \{render_slot(destination)}, \{render_slot(source)}, \{render_slot(index)}, \{render_slot(value)}"
    ByteSequenceEqual(destination, left, right) =>
      binary_instruction("byte_sequence_equal", destination, left, right)
    ByteSequenceConcat(destination, left, right) =>
      binary_instruction("byte_sequence_concat", destination, left, right)
    ByteSequenceSlice(destination, source, start, length) =>
      "byte_sequence_slice \{render_slot(destination)}, \{render_slot(source)}, \{render_slot(start)}, \{render_slot(length)}"
    ByteSequenceIsValidUtf8(destination, source) =>
      unary_instruction("byte_sequence_is_valid_utf8", destination, source)
    I32Add(destination, left, right) =>
      binary_instruction("i32_add", destination, left, right)
    I32Sub(destination, left, right) =>
      binary_instruction("i32_sub", destination, left, right)
    I32Mul(destination, left, right) =>
      binary_instruction("i32_mul", destination, left, right)
    I32Neg(destination, source) =>
      unary_instruction("i32_neg", destination, source)
    I32Div(destination, left, right) =>
      binary_instruction("i32_div", destination, left, right)
    I32Rem(destination, left, right) =>
      binary_instruction("i32_rem", destination, left, right)
    I32Eq(destination, left, right) =>
      binary_instruction("i32_eq", destination, left, right)
    I32Lt(destination, left, right) =>
      binary_instruction("i32_lt", destination, left, right)
    I32ToI64(destination, source) =>
      unary_instruction("i32_to_i64", destination, source)
    I64ToI32(destination, source) =>
      unary_instruction("i64_to_i32", destination, source)
    I64Add(destination, left, right) =>
      binary_instruction("i64_add", destination, left, right)
    I64Sub(destination, left, right) =>
      binary_instruction("i64_sub", destination, left, right)
    I64Mul(destination, left, right) =>
      binary_instruction("i64_mul", destination, left, right)
    I64Neg(destination, source) =>
      unary_instruction("i64_neg", destination, source)
    I64Div(destination, left, right) =>
      binary_instruction("i64_div", destination, left, right)
    I64Rem(destination, left, right) =>
      binary_instruction("i64_rem", destination, left, right)
    I64And(destination, left, right) =>
      binary_instruction("i64_and", destination, left, right)
    I64Or(destination, left, right) =>
      binary_instruction("i64_or", destination, left, right)
    I64Xor(destination, left, right) =>
      binary_instruction("i64_xor", destination, left, right)
    I64Not(destination, source) =>
      unary_instruction("i64_not", destination, source)
    I64Shl(destination, left, right) =>
      binary_instruction("i64_shl", destination, left, right)
    I64ShrS(destination, left, right) =>
      binary_instruction("i64_shr_s", destination, left, right)
    I64Eq(destination, left, right) =>
      binary_instruction("i64_eq", destination, left, right)
    I64Ne(destination, left, right) =>
      binary_instruction("i64_ne", destination, left, right)
    I64Lt(destination, left, right) =>
      binary_instruction("i64_lt", destination, left, right)
    I64Le(destination, left, right) =>
      binary_instruction("i64_le", destination, left, right)
    I64Gt(destination, left, right) =>
      binary_instruction("i64_gt", destination, left, right)
    I64Ge(destination, left, right) =>
      binary_instruction("i64_ge", destination, left, right)
    BoolNot(destination, source) =>
      unary_instruction("bool_not", destination, source)
    BoolEq(destination, left, right) =>
      binary_instruction("bool_eq", destination, left, right)
    BoolNe(destination, left, right) =>
      binary_instruction("bool_ne", destination, left, right)
    F64Add(destination, left, right) =>
      binary_instruction("f64_add", destination, left, right)
    F64Sub(destination, left, right) =>
      binary_instruction("f64_sub", destination, left, right)
    F64Mul(destination, left, right) =>
      binary_instruction("f64_mul", destination, left, right)
    F64Div(destination, left, right) =>
      binary_instruction("f64_div", destination, left, right)
    F64Neg(destination, source) =>
      unary_instruction("f64_neg", destination, source)
    F64Eq(destination, left, right) =>
      binary_instruction("f64_eq", destination, left, right)
    F64Ne(destination, left, right) =>
      binary_instruction("f64_ne", destination, left, right)
    F64Lt(destination, left, right) =>
      binary_instruction("f64_lt", destination, left, right)
    F64Le(destination, left, right) =>
      binary_instruction("f64_le", destination, left, right)
    F64Gt(destination, left, right) =>
      binary_instruction("f64_gt", destination, left, right)
    F64Ge(destination, left, right) =>
      binary_instruction("f64_ge", destination, left, right)
    I64ToF64(destination, source) =>
      unary_instruction("i64_to_f64", destination, source)
    F64ToI64(destination, source) =>
      unary_instruction("f64_to_i64", destination, source)
    F32Add(destination, left, right) =>
      binary_instruction("f32_add", destination, left, right)
    F32Sub(destination, left, right) =>
      binary_instruction("f32_sub", destination, left, right)
    F32Mul(destination, left, right) =>
      binary_instruction("f32_mul", destination, left, right)
    F32Div(destination, left, right) =>
      binary_instruction("f32_div", destination, left, right)
    F32Neg(destination, source) =>
      unary_instruction("f32_neg", destination, source)
    F32Eq(destination, left, right) =>
      binary_instruction("f32_eq", destination, left, right)
    F32Ne(destination, left, right) =>
      binary_instruction("f32_ne", destination, left, right)
    F32Lt(destination, left, right) =>
      binary_instruction("f32_lt", destination, left, right)
    F32Le(destination, left, right) =>
      binary_instruction("f32_le", destination, left, right)
    F32Gt(destination, left, right) =>
      binary_instruction("f32_gt", destination, left, right)
    F32Ge(destination, left, right) =>
      binary_instruction("f32_ge", destination, left, right)
    I64ToF32(destination, source) =>
      unary_instruction("i64_to_f32", destination, source)
    F32ToI64(destination, source) =>
      unary_instruction("f32_to_i64", destination, source)
    F32ToF64(destination, source) =>
      unary_instruction("f32_to_f64", destination, source)
    F64ToF32(destination, source) =>
      unary_instruction("f64_to_f32", destination, source)
    F32ToString(destination, source) =>
      unary_instruction("f32_to_string", destination, source)
    F64ToString(destination, source) =>
      unary_instruction("f64_to_string", destination, source)
    EraseI32(destination, source) =>
      unary_instruction("erase_i32", destination, source)
    UneraseI32(destination, source) =>
      unary_instruction("unerase_i32", destination, source)
    EraseI64(destination, source) =>
      unary_instruction("erase_i64", destination, source)
    UneraseI64(destination, source) =>
      unary_instruction("unerase_i64", destination, source)
    EraseF64(destination, source) =>
      unary_instruction("erase_f64", destination, source)
    UneraseF64(destination, source) =>
      unary_instruction("unerase_f64", destination, source)
    EraseF32(destination, source) =>
      unary_instruction("erase_f32", destination, source)
    UneraseF32(destination, source) =>
      unary_instruction("unerase_f32", destination, source)
    EraseUnit(destination) => "erase_unit \{render_slot(destination)}"
    UneraseUnit(source) => "unerase_unit \{render_slot(source)}"
    InitGlobal(global, source) =>
      "init_global \{render_global(global)}, \{render_slot(source)}"
    BorrowGlobal(destination, global) =>
      "borrow_global \{render_slot(destination)}, \{render_global(global)}"
  }
}

///|
fn render_terminator(terminator : Terminator) -> String {
  match terminator {
    Jump(edge) => "jump \{render_edge(edge)}"
    BranchBool(condition, if_true, if_false) =>
      "branch_bool \{render_slot(condition)}, \{render_edge(if_true)}, \{render_edge(if_false)}"
    SwitchTag(discriminator, cases, default) =>
      "switch_tag \{render_slot(discriminator)}, cases=[\{cases.map(render_edge).join(", ")}], default=\{render_edge(default)}"
    Return(value) => "return \{render_optional_slot(value)}"
    TailCallDirect(function, environment, witnesses, arguments) =>
      "tail_call_direct \{render_function(function)} env=\{render_optional_slot(environment)} witnesses=[\{render_slots(witnesses)}] arguments=[\{render_slots(arguments)}]"
    TailCallValue(callable, abi, witnesses, arguments) =>
      "tail_call_value \{render_slot(callable)} abi=abi\{abi.value} witnesses=[\{render_slots(witnesses)}] arguments=[\{render_slots(arguments)}]"
    Unreachable => "unreachable"
  }
}

///|
fn unary_instruction(
  name : String,
  destination : SlotId,
  source : SlotId,
) -> String {
  "\{name} \{render_slot(destination)}, \{render_slot(source)}"
}

///|
fn binary_instruction(
  name : String,
  destination : SlotId,
  left : SlotId,
  right : SlotId,
) -> String {
  "\{name} \{render_slot(destination)}, \{render_slot(left)}, \{render_slot(right)}"
}

///|
fn render_slot(slot : SlotId) -> String {
  "%\{slot.value}"
}

///|
fn render_slots(slots : Array[SlotId]) -> String {
  slots.map(render_slot).join(", ")
}

///|
fn render_optional_slot(slot : SlotId?) -> String {
  match slot {
    Some(slot) => render_slot(slot)
    None => "none"
  }
}

///|
fn render_optional_destination(slot : SlotId?) -> String {
  match slot {
    Some(slot) => "\{render_slot(slot)} = "
    None => ""
  }
}

///|
fn render_function(function : FunctionId) -> String {
  "f\{function.value}"
}

///|
fn render_optional_function(function : FunctionId?) -> String {
  match function {
    Some(function) => render_function(function)
    None => "none"
  }
}

///|
fn render_global(global : GlobalId) -> String {
  "g\{global.value}"
}

///|
fn render_layout(layout : LayoutId) -> String {
  "l\{layout.value}"
}

///|
fn render_shape(shape : ObjectShapeId) -> String {
  "shape\{shape.value}"
}

///|
fn render_constant(constant : ConstantId) -> String {
  "c\{constant.value}"
}

///|
fn render_edge(edge : Edge) -> String {
  "b\{edge.target.value}([\{render_slots(edge.arguments)}])"
}

///|
fn render_projection_result(result : ProjectionResult) -> String {
  match result.witness_destination {
    Some(witness) =>
      "(\{render_slot(result.value_destination)}, \{render_slot(witness)})"
    None => render_slot(result.value_destination)
  }
}

///|
fn render_selections(selections : Array[ProjectionSelection]) -> String {
  selections
  .map(selection => {
    "\{selection.member_index}:\{render_projection_result(selection.result)}"
  })
  .join(", ")
}

///|
fn render_layout_operand(operand : LayoutOperand) -> String {
  match operand {
    Immediate(layout) => render_layout(layout)
    Witness(slot) => "witness(\{render_slot(slot)})"
  }
}

///|
fn render_slot_metadata(metadata : SlotMetadata) -> String {
  let companion = match metadata.erased_companion {
    Some(slot) => ", companion=\{render_slot(slot)}"
    None => ""
  }
  "\{render_representation(metadata.representation)} + \{render_cleanup(metadata.cleanup)} + \{Repr(metadata.kind)}\{companion}"
}

///|
fn render_global_metadata(metadata : GlobalMetadata) -> String {
  let companion = match metadata.erased_companion {
    Some(global) => ", companion=\{render_global(global)}"
    None => ""
  }
  "\{render_representation(metadata.representation)} + \{render_cleanup(metadata.cleanup)} + \{Repr(metadata.kind)}\{companion}"
}

///|
fn render_representation(representation : Representation) -> String {
  match representation {
    I32 => "i32"
    I64 => "i64"
    F64 => "f64"
    F32 => "f32"
  }
}

///|
fn render_cleanup(cleanup : Cleanup) -> String {
  match cleanup {
    Trivial => "trivial"
    OwnedRef => "owned_ref"
    OwnedCallable => "owned_callable"
    OwnedErased => "owned_erased"
  }
}

///|
fn render_result(result : ResultAbi) -> String {
  match result {
    Unit => "unit"
    Value(representation, cleanup, kind) =>
      "\{render_representation(representation)} + \{render_cleanup(cleanup)} + \{Repr(kind)}"
  }
}

///|
fn render_layout_recipe(recipe : LayoutRecipe) -> String {
  match recipe {
    Unit => "unit"
    Bool => "bool"
    I64 => "i64"
    I32 => "i32"
    Char => "char"
    F64 => "f64"
    F32 => "f32"
    Callable => "callable"
    ByteSequence => "byte_sequence"
    Data(shape) => "data(\{render_shape(shape)})"
    Environment(shape) => "environment(\{render_shape(shape)})"
    Reference => "reference"
    Byte => "byte"
  }
}

///|
fn render_object_shape(shape : ObjectShape) -> String {
  match shape {
    Data(data) =>
      "data(family=\{data.family.value}, tag=\{data.constructor_tag}, witnesses=\{data.stored_witness_count}, members=[\{data.members.map(render_member).join(", ")}])"
    Environment(environment) =>
      "environment(witnesses=\{environment.stored_witness_count}, members=[\{environment.members.map(render_member).join(", ")}])"
  }
}

///|
fn render_member(schema : MemberSchema) -> String {
  let witness = match schema.witness_ordinal {
    Some(ordinal) => ", witness=\{ordinal}"
    None => ""
  }
  "\{render_representation(schema.representation)} + \{render_cleanup(schema.cleanup)} + \{Repr(schema.kind)}\{witness}"
}
