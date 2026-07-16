///|
pub fn bytecode_image_to_disassembly(image : BytecodeImage) -> String {
  let lines = [
    "LoisVM bytecode",
    "entry: \{render_function(image.entry)}",
    "initializer: \{render_optional_function(image.initializer)}",
    "functions: \{image.functions.length()}",
    "globals: \{image.globals.length()}",
    "layouts: \{image.layouts.length()}",
    "object shapes: \{image.object_shapes.length()}",
    "constants: \{image.constants.length()}",
  ]
  lines.push("")
  for index, function in image.functions {
    lines.append(render_function_entry(index + 1, function))
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
      let value = @utf8.decode(constant) catch { _ => "<invalid ASCII>" }
      lines.push("  c\{index} = \{to_repr(value)}")
    }
    lines.push("")
  }
  lines.join("\n")
}

///|
fn render_function_entry(id : Int, entry : FunctionEntry) -> Array[String] {
  match entry {
    RuntimeImport(import_) =>
      [
        "function f\{id} = runtime_import(",
        "  symbol=\{to_repr(import_.symbol)},",
        "  abi_major=\{import_.abi_major},",
        "  user_arity=\{import_.user_arity}",
        ")",
      ]
    BytecodeBody(body) => {
      let lines = [
        "function f\{id}(",
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
fn render_instruction(instruction : Instruction) -> String {
  match instruction {
    Copy(destination, source) => unary_instruction("copy", destination, source)
    Move(destination, source) => unary_instruction("move", destination, source)
    RetainCopy(destination, source) =>
      unary_instruction("retain_copy", destination, source)
    Release(source) => "release \{render_slot(source)}"
    ConstInt(destination, value) =>
      "const_int \{render_slot(destination)}, \{value}"
    ConstDouble(destination, bits) =>
      "const_double \{render_slot(destination)}, bits=\{bits}"
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
    CallValue(callable, witnesses, arguments, destination) =>
      "call_value \{render_optional_destination(destination)}\{render_slot(callable)} witnesses=[\{render_slots(witnesses)}] arguments=[\{render_slots(arguments)}]"
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
    StringLength(destination, source) =>
      unary_instruction("string_length", destination, source)
    StringConcat(destination, left, right) =>
      binary_instruction("string_concat", destination, left, right)
    StringSlice(destination, source, start, length) =>
      "string_slice \{render_slot(destination)}, \{render_slot(source)}, \{render_slot(start)}, \{render_slot(length)}"
    StringEq(destination, left, right) =>
      binary_instruction("string_eq", destination, left, right)
    IntAdd(destination, left, right) =>
      binary_instruction("int_add", destination, left, right)
    IntSub(destination, left, right) =>
      binary_instruction("int_sub", destination, left, right)
    IntMul(destination, left, right) =>
      binary_instruction("int_mul", destination, left, right)
    IntNeg(destination, source) =>
      unary_instruction("int_neg", destination, source)
    IntDiv(destination, left, right) =>
      binary_instruction("int_div", destination, left, right)
    IntRem(destination, left, right) =>
      binary_instruction("int_rem", destination, left, right)
    IntAnd(destination, left, right) =>
      binary_instruction("int_and", destination, left, right)
    IntOr(destination, left, right) =>
      binary_instruction("int_or", destination, left, right)
    IntXor(destination, left, right) =>
      binary_instruction("int_xor", destination, left, right)
    IntNot(destination, source) =>
      unary_instruction("int_not", destination, source)
    IntShl(destination, left, right) =>
      binary_instruction("int_shl", destination, left, right)
    IntShrS(destination, left, right) =>
      binary_instruction("int_shr_s", destination, left, right)
    IntEq(destination, left, right) =>
      binary_instruction("int_eq", destination, left, right)
    IntNe(destination, left, right) =>
      binary_instruction("int_ne", destination, left, right)
    IntLt(destination, left, right) =>
      binary_instruction("int_lt", destination, left, right)
    IntLe(destination, left, right) =>
      binary_instruction("int_le", destination, left, right)
    IntGt(destination, left, right) =>
      binary_instruction("int_gt", destination, left, right)
    IntGe(destination, left, right) =>
      binary_instruction("int_ge", destination, left, right)
    BoolNot(destination, source) =>
      unary_instruction("bool_not", destination, source)
    BoolEq(destination, left, right) =>
      binary_instruction("bool_eq", destination, left, right)
    BoolNe(destination, left, right) =>
      binary_instruction("bool_ne", destination, left, right)
    DoubleAdd(destination, left, right) =>
      binary_instruction("double_add", destination, left, right)
    DoubleSub(destination, left, right) =>
      binary_instruction("double_sub", destination, left, right)
    DoubleMul(destination, left, right) =>
      binary_instruction("double_mul", destination, left, right)
    DoubleDiv(destination, left, right) =>
      binary_instruction("double_div", destination, left, right)
    DoubleNeg(destination, source) =>
      unary_instruction("double_neg", destination, source)
    DoubleEq(destination, left, right) =>
      binary_instruction("double_eq", destination, left, right)
    DoubleNe(destination, left, right) =>
      binary_instruction("double_ne", destination, left, right)
    DoubleLt(destination, left, right) =>
      binary_instruction("double_lt", destination, left, right)
    DoubleLe(destination, left, right) =>
      binary_instruction("double_le", destination, left, right)
    DoubleGt(destination, left, right) =>
      binary_instruction("double_gt", destination, left, right)
    DoubleGe(destination, left, right) =>
      binary_instruction("double_ge", destination, left, right)
    IntToDouble(destination, source) =>
      unary_instruction("int_to_double", destination, source)
    DoubleToInt(destination, source) =>
      unary_instruction("double_to_int", destination, source)
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
    TailCallValue(callable, witnesses, arguments) =>
      "tail_call_value \{render_slot(callable)} witnesses=[\{render_slots(witnesses)}] arguments=[\{render_slots(arguments)}]"
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
  "\{render_representation(metadata.representation)} + \{render_cleanup(metadata.cleanup)}\{companion}"
}

///|
fn render_global_metadata(metadata : GlobalMetadata) -> String {
  let companion = match metadata.erased_companion {
    Some(global) => ", companion=\{render_global(global)}"
    None => ""
  }
  "\{render_representation(metadata.representation)} + \{render_cleanup(metadata.cleanup)}\{companion}"
}

///|
fn render_representation(representation : Representation) -> String {
  match representation {
    I32 => "i32"
    I64 => "i64"
    F64 => "f64"
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
fn render_result(result : ResultRepresentation) -> String {
  match result {
    Unit => "unit"
    I32 => "i32"
    I64 => "i64"
    F64 => "f64"
  }
}

///|
fn render_layout_recipe(recipe : LayoutRecipe) -> String {
  match recipe {
    Unit => "unit"
    Bool => "bool"
    Int => "int"
    Double => "double"
    Callable => "callable"
    String => "string"
    Data(shape) => "data(\{render_shape(shape)})"
    Environment(shape) => "environment(\{render_shape(shape)})"
    Reference => "reference"
  }
}

///|
fn render_object_shape(shape : ObjectShape) -> String {
  match shape {
    Data(data) =>
      "data(tag=\{data.constructor_tag}, witnesses=\{data.stored_witness_count}, members=[\{data.members.map(render_member).join(", ")}])"
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
  "\{render_representation(schema.representation)} + \{render_cleanup(schema.cleanup)}\{witness}"
}
