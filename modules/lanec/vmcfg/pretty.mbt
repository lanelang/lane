///|
using @prettyprinter {text}

///|
pub impl @prettyprinter.Pretty for Image with fn pretty(image : Image) {
  text(image_to_disassembly(image))
}

///|
fn image_to_disassembly(image : Image) -> String {
  let lines = [
    "VM CFG",
    "entry: \{render_function(image.entry)}",
    "initializer: \{render_optional_function(image.initializer)}",
    "functions: \{image.functions.length()}",
    "globals: \{image.globals.length()}",
    "layouts: \{image.layouts.length()}",
    "object shapes: \{image.object_shapes.length()}",
    "constants: \{image.constants.length()}",
    "",
  ]
  lines.append(image_code_lines(image))
  lines.join("\n")
}

///|
pub fn image_to_code(image : Image) -> String {
  image_code_lines(image).join("\n")
}

///|
fn image_code_lines(image : Image) -> Array[String] {
  let lines : Array[String] = []
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
      let value = @utf8.decode(constant) catch { _ => "<invalid UTF-8>" }
      lines.push("  c\{index} = \{to_repr(value)}")
    }
    lines.push("")
  }
  lines
}

///|
fn render_function_entry(id : Int, entry : FunctionEntry) -> Array[String] {
  match entry {
    RuntimeImport(import_) => {
      let parameters = import_.parameters
        .map(render_runtime_value_kind)
        .join(", ")
      [
        "function f\{id} = runtime_import(",
        "  symbol=\{to_repr(import_.symbol)},",
        "  abi_major=\{import_.abi_major},",
        "  parameters=[\{parameters}],",
        "  result=\{render_runtime_value_kind(import_.result)}",
        ")",
      ]
    }
    Body(body) => {
      let lines = [
        "function f\{id}(",
        "  environment=\{render_optional_value(body.inputs.environment)},",
        "  witnesses=[\{render_values(body.inputs.witnesses)}],",
        "  parameters=[\{render_values(body.inputs.user_parameters)}]",
        ") -> \{render_result(body.result)} {",
        "  values:",
      ]
      if body.values.is_empty() {
        lines.push("    (none)")
      } else {
        for index, value in body.values {
          lines.push("    %v\{index}: \{render_value_metadata(value)}")
        }
      }
      for index, block in body.blocks {
        lines.push("  b\{index}([\{render_values(block.parameters)}]):")
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
    Release(source) => "release \{render_value(source)}"
    ConstInt(destination, value) =>
      "const_int \{render_value(destination)}, \{value}"
    ConstDouble(destination, bits) =>
      "const_double \{render_value(destination)}, bits=\{bits}"
    ConstBool(destination, value) =>
      "const_bool \{render_value(destination)}, \{value}"
    ConstLayout(destination, layout) =>
      "const_layout \{render_value(destination)}, \{render_layout(layout)}"
    ConstFunction(destination, function) =>
      "const_function \{render_value(destination)}, \{render_function(function)}"
    ConstString(destination, constant) =>
      "const_string \{render_value(destination)}, \{render_constant(constant)}"
    CallDirect(function, environment, witnesses, arguments, destination) =>
      "call_direct \{render_optional_destination(destination)}\{render_function(function)} env=\{render_optional_value(environment)} witnesses=[\{render_values(witnesses)}] arguments=[\{render_values(arguments)}]"
    CallValue(callable, witnesses, arguments, destination) =>
      "call_value \{render_optional_destination(destination)}\{render_value(callable)} witnesses=[\{render_values(witnesses)}] arguments=[\{render_values(arguments)}]"
    MakeData(destination, shape, layout, witnesses, fields) =>
      "make_data \{render_value(destination)}, \{render_shape(shape)}, \{render_layout_operand(layout)}, witnesses=[\{render_values(witnesses)}], fields=[\{render_values(fields)}]"
    LoadTag(destination, source) =>
      unary_instruction("load_tag", destination, source)
    LoadObjectWitness(destination, shape, object, ordinal) =>
      "load_object_witness \{render_value(destination)}, \{render_shape(shape)}, \{render_value(object)}, \{ordinal}"
    BorrowField(shape, source, index, result) =>
      "borrow_field \{render_projection_result(result)}, \{render_shape(shape)}, \{render_value(source)}, \{index}"
    ConsumeFields(shape, source, selections) =>
      "consume_fields \{render_shape(shape)}, \{render_value(source)}, [\{render_selections(selections)}]"
    MakeEnv(destination, shape, layout, witnesses, captures) =>
      "make_env \{render_value(destination)}, \{render_shape(shape)}, \{render_layout_operand(layout)}, witnesses=[\{render_values(witnesses)}], captures=[\{render_values(captures)}]"
    BorrowCapture(shape, source, index, result) =>
      "borrow_capture \{render_projection_result(result)}, \{render_shape(shape)}, \{render_value(source)}, \{index}"
    ConsumeCaptures(shape, source, selections) =>
      "consume_captures \{render_shape(shape)}, \{render_value(source)}, [\{render_selections(selections)}]"
    MakeClosure(destination, function, environment) =>
      "make_closure \{render_value(destination)}, \{render_function(function)}, \{render_value(environment)}"
    StringLength(destination, source) =>
      unary_instruction("string_length", destination, source)
    StringConcat(destination, left, right) =>
      binary_instruction("string_concat", destination, left, right)
    StringSlice(destination, source, start, length) =>
      "string_slice \{render_value(destination)}, \{render_value(source)}, \{render_value(start)}, \{render_value(length)}"
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
    EraseUnit(destination) => "erase_unit \{render_value(destination)}"
    UneraseUnit(source) => "unerase_unit \{render_value(source)}"
    InitGlobal(global, source) =>
      "init_global \{render_global(global)}, \{render_value(source)}"
    BorrowGlobal(destination, global) =>
      "borrow_global \{render_value(destination)}, \{render_global(global)}"
  }
}

///|
fn render_terminator(terminator : Terminator) -> String {
  match terminator {
    Jump(edge) => "jump \{render_edge(edge)}"
    BranchBool(condition, if_true, if_false) =>
      "branch_bool \{render_value(condition)}, \{render_edge(if_true)}, \{render_edge(if_false)}"
    SwitchTag(discriminator, cases, default) =>
      "switch_tag \{render_value(discriminator)}, cases=[\{cases.map(render_edge).join(", ")}], default=\{render_edge(default)}"
    Return(value) => "return \{render_optional_value(value)}"
    TailCallDirect(function, environment, witnesses, arguments) =>
      "tail_call_direct \{render_function(function)} env=\{render_optional_value(environment)} witnesses=[\{render_values(witnesses)}] arguments=[\{render_values(arguments)}]"
    TailCallValue(callable, witnesses, arguments) =>
      "tail_call_value \{render_value(callable)} witnesses=[\{render_values(witnesses)}] arguments=[\{render_values(arguments)}]"
    Unreachable => "unreachable"
  }
}

///|
fn unary_instruction(
  name : String,
  destination : ValueId,
  source : ValueId,
) -> String {
  "\{name} \{render_value(destination)}, \{render_value(source)}"
}

///|
fn binary_instruction(
  name : String,
  destination : ValueId,
  left : ValueId,
  right : ValueId,
) -> String {
  "\{name} \{render_value(destination)}, \{render_value(left)}, \{render_value(right)}"
}

///|
fn render_value(value : ValueId) -> String {
  "%v\{value.value}"
}

///|
fn render_values(values : Array[ValueId]) -> String {
  values.map(render_value).join(", ")
}

///|
fn render_optional_value(value : ValueId?) -> String {
  match value {
    Some(value) => render_value(value)
    None => "none"
  }
}

///|
fn render_optional_destination(value : ValueId?) -> String {
  match value {
    Some(value) => "\{render_value(value)} = "
    None => ""
  }
}

///|
fn render_function(function : @bytecode.FunctionId) -> String {
  "f\{function.value}"
}

///|
fn render_optional_function(function : @bytecode.FunctionId?) -> String {
  match function {
    Some(function) => render_function(function)
    None => "none"
  }
}

///|
fn render_global(global : @bytecode.GlobalId) -> String {
  "g\{global.value}"
}

///|
fn render_layout(layout : @bytecode.LayoutId) -> String {
  "l\{layout.value}"
}

///|
fn render_shape(shape : @bytecode.ObjectShapeId) -> String {
  "shape\{shape.value}"
}

///|
fn render_constant(constant : @bytecode.ConstantId) -> String {
  "c\{constant.value}"
}

///|
fn render_edge(edge : Edge) -> String {
  "b\{edge.target.value}([\{render_values(edge.arguments)}])"
}

///|
fn render_projection_result(result : ProjectionResult) -> String {
  match result.witness_destination {
    Some(witness) =>
      "(\{render_value(result.value_destination)}, \{render_value(witness)})"
    None => render_value(result.value_destination)
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
    Witness(value) => "witness(\{render_value(value)})"
  }
}

///|
fn render_value_metadata(metadata : ValueMetadata) -> String {
  let companion = match metadata.erased_companion {
    Some(value) => ", companion=\{render_value(value)}"
    None => ""
  }
  "\{render_representation(metadata.representation)} + \{render_cleanup(metadata.cleanup)} + \{render_ownership(metadata.ownership)}\{companion}"
}

///|
fn render_ownership(ownership : Ownership) -> String {
  match ownership {
    Trivial => "trivial"
    Owned => "owned"
    Borrowed => "borrowed"
  }
}

///|
fn render_global_metadata(metadata : @bytecode.GlobalMetadata) -> String {
  let companion = match metadata.erased_companion {
    Some(global) => ", companion=\{render_global(global)}"
    None => ""
  }
  "\{render_representation(metadata.representation)} + \{render_cleanup(metadata.cleanup)}\{companion}"
}

///|
fn render_representation(representation : @bytecode.Representation) -> String {
  match representation {
    I32 => "i32"
    I64 => "i64"
    F64 => "f64"
  }
}

///|
fn render_cleanup(cleanup : @bytecode.Cleanup) -> String {
  match cleanup {
    Trivial => "trivial"
    OwnedRef => "owned_ref"
    OwnedCallable => "owned_callable"
    OwnedErased => "owned_erased"
  }
}

///|
fn render_result(result : @bytecode.ResultRepresentation) -> String {
  match result {
    Unit => "unit"
    I32 => "i32"
    I64 => "i64"
    F64 => "f64"
  }
}

///|
fn render_runtime_value_kind(kind : @bytecode.RuntimeValueKind) -> String {
  match kind {
    Unit => "unit"
    Bool => "bool"
    Int => "int"
    Double => "double"
    String => "string"
    Opaque => "opaque"
  }
}

///|
fn render_layout_recipe(recipe : @bytecode.LayoutRecipe) -> String {
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
fn render_object_shape(shape : @bytecode.ObjectShape) -> String {
  match shape {
    Data(data) =>
      "data(tag=\{data.constructor_tag}, witnesses=\{data.stored_witness_count}, members=[\{data.members.map(render_member).join(", ")}])"
    Environment(environment) =>
      "environment(witnesses=\{environment.stored_witness_count}, members=[\{environment.members.map(render_member).join(", ")}])"
  }
}

///|
fn render_member(schema : @bytecode.MemberSchema) -> String {
  let witness = match schema.witness_ordinal {
    Some(ordinal) => ", witness=\{ordinal}"
    None => ""
  }
  "\{render_representation(schema.representation)} + \{render_cleanup(schema.cleanup)}\{witness}"
}
