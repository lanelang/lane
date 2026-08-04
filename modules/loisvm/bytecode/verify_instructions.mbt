///|
fn BytecodeVerifier::verify_instruction(
  self : BytecodeVerifier,
  function : FunctionId,
  block : BlockId,
  index : Int,
  body : FunctionBody,
  instruction : Instruction,
) -> Unit raise BytecodeVerificationError {
  let site = BytecodeVerificationSite::Instruction(function, block, index)
  match instruction {
    Copy(destination, source) => {
      self.expect_same_shape(site, body, destination, source)
      let metadata = self.slot_metadata(site, body, destination)
      if metadata.cleanup != Trivial {
        self.fail(site, "Copy may only duplicate Trivial values")
      }
    }
    Move(destination, source) =>
      self.expect_same_shape(site, body, destination, source)
    RetainCopy(destination, source) => {
      let destination_metadata = self.slot_metadata(site, body, destination)
      let source_metadata = self.slot_metadata(site, body, source)
      if destination_metadata.cleanup == Trivial ||
        destination_metadata.representation != source_metadata.representation {
        self.fail(
          site, "RetainCopy requires a nontrivial compatible destination",
        )
      }
      if source_metadata.cleanup != Trivial &&
        source_metadata.cleanup != destination_metadata.cleanup {
        self.fail(
          site, "RetainCopy source and destination cleanup are incompatible",
        )
      }
    }
    Release(source) => ignore(self.slot_metadata(site, body, source))
    ConstI64(destination, _) =>
      self.expect_slot(site, body, destination, I64, Trivial)
    ConstI32(destination, _)
    | ConstChar(destination, _)
    | ConstBool(destination, _) =>
      self.expect_slot(site, body, destination, I32, Trivial)
    ConstF64(destination, _) =>
      self.expect_slot(site, body, destination, F64, Trivial)
    ConstF32(destination, _) =>
      self.expect_slot(site, body, destination, F32, Trivial)
    ConstLayout(destination, layout) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      ignore(self.layout_recipe(site, layout))
    }
    ConstFunction(destination, target) => {
      self.expect_slot(site, body, destination, I64, OwnedCallable)
      match self.function_entry(site, target) {
        BytecodeBody(target_body) =>
          if target_body.inputs.environment is Some(_) {
            self.fail(site, "ConstFunction target requires an environment")
          }
        RuntimeImport(_) => ()
      }
    }
    ConstString(destination, constant) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      ignore(self.constant(site, constant))
    }
    CallDirect(target, environment, witnesses, arguments, destination) =>
      self.verify_direct_call(
        site,
        body,
        target,
        environment,
        witnesses,
        arguments,
        destination,
        tail_result=None,
      )
    CallValue(callable, witnesses, arguments, destination) => {
      self.expect_slot(site, body, callable, I64, OwnedCallable)
      for witness in witnesses {
        self.expect_slot(site, body, witness, I32, Trivial)
      }
      for argument in arguments {
        ignore(self.slot_metadata(site, body, argument))
      }
      if destination is Some(destination) {
        ignore(self.slot_metadata(site, body, destination))
      }
    }
    MakeData(destination, shape, layout, witnesses, fields) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      guard self.object_shape(site, shape) is Data(data) else {
        self.fail(site, "MakeData requires a Data object shape")
      }
      self.verify_object_construction(
        site,
        body,
        shape,
        layout,
        witnesses,
        fields,
        data.stored_witness_count,
        data.members,
        environment=false,
      )
    }
    MakeEnv(destination, shape, layout, witnesses, captures) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      guard self.object_shape(site, shape) is Environment(environment_shape) else {
        self.fail(site, "MakeEnv requires an Environment object shape")
      }
      self.verify_object_construction(
        site,
        body,
        shape,
        layout,
        witnesses,
        captures,
        environment_shape.stored_witness_count,
        environment_shape.members,
        environment=true,
      )
    }
    LoadTag(destination, source) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_reference_operand(site, body, source)
    }
    LoadObjectWitness(destination, shape, source, ordinal) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_reference_operand(site, body, source)
      let witness_count = match self.object_shape(site, shape) {
        Data(data) => data.stored_witness_count
        Environment(environment) => environment.stored_witness_count
      }
      if ordinal < 0 || ordinal >= witness_count {
        self.fail(site, "object witness ordinal \{ordinal} is out of range")
      }
    }
    BorrowField(shape, source, field_index, result) => {
      guard self.object_shape(site, shape) is Data(data) else {
        self.fail(site, "BorrowField requires a Data object shape")
      }
      self.expect_reference_operand(site, body, source)
      self.verify_projection_result(
        site,
        body,
        field_index,
        result,
        data.members,
        consuming=false,
      )
    }
    BorrowCapture(shape, source, capture_index, result) => {
      guard self.object_shape(site, shape) is Environment(environment) else {
        self.fail(site, "BorrowCapture requires an Environment object shape")
      }
      self.expect_reference_operand(site, body, source)
      self.verify_projection_result(
        site,
        body,
        capture_index,
        result,
        environment.members,
        consuming=false,
      )
    }
    ConsumeFields(shape, source, selections) => {
      guard self.object_shape(site, shape) is Data(data) else {
        self.fail(site, "ConsumeFields requires a Data object shape")
      }
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.verify_projection_selections(site, body, selections, data.members)
    }
    ConsumeCaptures(shape, source, selections) => {
      guard self.object_shape(site, shape) is Environment(environment) else {
        self.fail(site, "ConsumeCaptures requires an Environment object shape")
      }
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.verify_projection_selections(
        site,
        body,
        selections,
        environment.members,
      )
    }
    MakeClosure(destination, target, environment) => {
      self.expect_slot(site, body, destination, I64, OwnedCallable)
      self.expect_slot(site, body, environment, I32, OwnedRef)
      match self.function_entry(site, target) {
        BytecodeBody(target_body) =>
          if target_body.inputs.environment is None {
            self.fail(site, "MakeClosure target does not accept an environment")
          }
        RuntimeImport(_) =>
          self.fail(site, "MakeClosure target must be a bytecode body")
      }
    }
    ByteToI64(destination, source) => {
      self.expect_slot(site, body, destination, I64, Trivial)
      self.expect_slot(site, body, source, I32, Trivial)
    }
    I64ToByte(destination, source) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_slot(site, body, source, I64, Trivial)
    }
    ByteSequenceMake(destination, length, fill) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, length, I64, Trivial)
      self.expect_slot(site, body, fill, I32, Trivial)
    }
    ByteSequenceLength(destination, source) => {
      self.expect_slot(site, body, destination, I64, Trivial)
      self.expect_reference_operand(site, body, source)
    }
    ByteSequenceGet(destination, source, index) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_reference_operand(site, body, source)
      self.expect_slot(site, body, index, I64, Trivial)
    }
    ByteSequenceSet(destination, source, index, value) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.expect_slot(site, body, index, I64, Trivial)
      self.expect_slot(site, body, value, I32, Trivial)
    }
    ByteSequenceEqual(destination, left, right) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_reference_operand(site, body, left)
      self.expect_reference_operand(site, body, right)
    }
    ByteSequenceConcat(destination, left, right) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, left, I32, OwnedRef)
      self.expect_slot(site, body, right, I32, OwnedRef)
    }
    ByteSequenceSlice(destination, source, start, length) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.expect_slot(site, body, start, I64, Trivial)
      self.expect_slot(site, body, length, I64, Trivial)
    }
    ByteSequenceIsValidUtf8(destination, source) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_reference_operand(site, body, source)
    }
    I32Add(destination, left, right)
    | I32Sub(destination, left, right)
    | I32Mul(destination, left, right)
    | I32Div(destination, left, right)
    | I32Rem(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I32, I32)
    I32Eq(destination, left, right) | I32Lt(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I32, I32)
    I32Neg(destination, source) =>
      self.verify_unary(site, body, destination, source, I32, I32)
    I32ToI64(destination, source) =>
      self.verify_unary(site, body, destination, source, I64, I32)
    I64ToI32(destination, source) =>
      self.verify_unary(site, body, destination, source, I32, I64)
    I64Add(destination, left, right)
    | I64Sub(destination, left, right)
    | I64Mul(destination, left, right)
    | I64Div(destination, left, right)
    | I64Rem(destination, left, right)
    | I64And(destination, left, right)
    | I64Or(destination, left, right)
    | I64Xor(destination, left, right)
    | I64Shl(destination, left, right)
    | I64ShrS(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I64, I64)
    I64Eq(destination, left, right)
    | I64Ne(destination, left, right)
    | I64Lt(destination, left, right)
    | I64Le(destination, left, right)
    | I64Gt(destination, left, right)
    | I64Ge(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I32, I64)
    I64Neg(destination, source) | I64Not(destination, source) =>
      self.verify_unary(site, body, destination, source, I64, I64)
    BoolNot(destination, source) =>
      self.verify_unary(site, body, destination, source, I32, I32)
    BoolEq(destination, left, right) | BoolNe(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I32, I32)
    F64Add(destination, left, right)
    | F64Sub(destination, left, right)
    | F64Mul(destination, left, right)
    | F64Div(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, F64, F64)
    F64Eq(destination, left, right)
    | F64Ne(destination, left, right)
    | F64Lt(destination, left, right)
    | F64Le(destination, left, right)
    | F64Gt(destination, left, right)
    | F64Ge(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I32, F64)
    F64Neg(destination, source) =>
      self.verify_unary(site, body, destination, source, F64, F64)
    I64ToF64(destination, source) =>
      self.verify_unary(site, body, destination, source, F64, I64)
    F64ToI64(destination, source) =>
      self.verify_unary(site, body, destination, source, I64, F64)
    F32Add(destination, left, right)
    | F32Sub(destination, left, right)
    | F32Mul(destination, left, right)
    | F32Div(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, F32, F32)
    F32Eq(destination, left, right)
    | F32Ne(destination, left, right)
    | F32Lt(destination, left, right)
    | F32Le(destination, left, right)
    | F32Gt(destination, left, right)
    | F32Ge(destination, left, right) =>
      self.verify_binary(site, body, destination, left, right, I32, F32)
    F32Neg(destination, source) =>
      self.verify_unary(site, body, destination, source, F32, F32)
    I64ToF32(destination, source) =>
      self.verify_unary(site, body, destination, source, F32, I64)
    F32ToI64(destination, source) =>
      self.verify_unary(site, body, destination, source, I64, F32)
    F32ToF64(destination, source) =>
      self.verify_unary(site, body, destination, source, F64, F32)
    F64ToF32(destination, source) =>
      self.verify_unary(site, body, destination, source, F32, F64)
    F32ToString(destination, source) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, F32, Trivial)
    }
    F64ToString(destination, source) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, F64, Trivial)
    }
    EraseI32(destination, source) =>
      self.verify_erasure(site, body, destination, source, I32)
    EraseI64(destination, source) =>
      self.verify_erasure(site, body, destination, source, I64)
    EraseF64(destination, source) =>
      self.verify_erasure(site, body, destination, source, F64)
    EraseF32(destination, source) =>
      self.verify_erasure(site, body, destination, source, F32)
    UneraseI32(destination, source) =>
      self.verify_unerasure(site, body, destination, source, I32)
    UneraseI64(destination, source) =>
      self.verify_unerasure(site, body, destination, source, I64)
    UneraseF64(destination, source) =>
      self.verify_unerasure(site, body, destination, source, F64)
    UneraseF32(destination, source) =>
      self.verify_unerasure(site, body, destination, source, F32)
    EraseUnit(destination) =>
      self.expect_slot(site, body, destination, I64, OwnedErased)
    UneraseUnit(source) =>
      self.expect_slot(site, body, source, I64, OwnedErased)
    InitGlobal(global, source) =>
      self.verify_init_global(site, body, global, source)
    BorrowGlobal(destination, global) =>
      self.verify_borrow_global(site, body, destination, global)
  }
}

///|
fn BytecodeVerifier::verify_unary(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  source : SlotId,
  destination_representation : Representation,
  source_representation : Representation,
) -> Unit raise BytecodeVerificationError {
  self.expect_slot(site, body, destination, destination_representation, Trivial)
  self.expect_slot(site, body, source, source_representation, Trivial)
}

///|
fn BytecodeVerifier::verify_binary(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  left : SlotId,
  right : SlotId,
  destination_representation : Representation,
  operand_representation : Representation,
) -> Unit raise BytecodeVerificationError {
  self.expect_slot(site, body, destination, destination_representation, Trivial)
  self.expect_slot(site, body, left, operand_representation, Trivial)
  self.expect_slot(site, body, right, operand_representation, Trivial)
}

///|
fn BytecodeVerifier::verify_erasure(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  source : SlotId,
  source_representation : Representation,
) -> Unit raise BytecodeVerificationError {
  self.expect_slot(site, body, destination, I64, OwnedErased)
  ignore(self.expect_representation(site, body, source, source_representation))
}

///|
fn BytecodeVerifier::verify_unerasure(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  source : SlotId,
  destination_representation : Representation,
) -> Unit raise BytecodeVerificationError {
  ignore(
    self.expect_representation(
      site, body, destination, destination_representation,
    ),
  )
  self.expect_slot(site, body, source, I64, OwnedErased)
}

///|
fn BytecodeVerifier::verify_direct_call(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  target : FunctionId,
  environment : SlotId?,
  witnesses : Array[SlotId],
  arguments : Array[SlotId],
  destination : SlotId?,
  tail_result~ : ResultRepresentation?,
) -> Unit raise BytecodeVerificationError {
  match self.function_entry(site, target) {
    BytecodeBody(target_body) => {
      match (target_body.inputs.environment, environment) {
        (None, None) => ()
        (Some(expected), Some(actual)) => {
          let expected_metadata = self.slot_metadata(
            site, target_body, expected,
          )
          let actual_metadata = self.slot_metadata(site, body, actual)
          if expected_metadata.representation != actual_metadata.representation ||
            expected_metadata.cleanup != actual_metadata.cleanup {
            self.fail(site, "direct-call environment has the wrong value shape")
          }
        }
        _ =>
          self.fail(
            site, "direct-call environment presence does not match target",
          )
      }
      self.verify_call_arguments(site, body, target_body, witnesses, arguments)
      self.verify_call_result(
        site,
        body,
        target_body.result,
        destination,
        tail_result~,
      )
    }
    RuntimeImport(import_) => {
      if environment is Some(_) || !witnesses.is_empty() {
        self.fail(
          site, "runtime import call cannot carry environment or witnesses",
        )
      }
      let parameter_shapes = import_.parameters.filter_map(runtime_value_shape)
      if arguments.length() != parameter_shapes.length() {
        self.fail(site, "runtime import call has the wrong argument count")
      }
      for index in 0..<arguments.length() {
        let (representation, cleanup) = parameter_shapes[index]
        self.expect_slot(site, body, arguments[index], representation, cleanup)
      }
      let result : ResultRepresentation = match
        runtime_value_shape(import_.result) {
        None => Unit
        Some((I32, _)) => I32
        Some((I64, _)) => I64
        Some((F64, _)) => F64
        Some((F32, _)) => F32
      }
      self.verify_call_result(site, body, result, destination, tail_result~)
      if tail_result is None &&
        destination is Some(destination) &&
        runtime_value_shape(import_.result) is Some((representation, cleanup)) {
        self.expect_slot(site, body, destination, representation, cleanup)
      }
    }
  }
}

///|
fn BytecodeVerifier::verify_call_arguments(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  caller : FunctionBody,
  callee : FunctionBody,
  witnesses : Array[SlotId],
  arguments : Array[SlotId],
) -> Unit raise BytecodeVerificationError {
  if witnesses.length() != callee.inputs.witnesses.length() {
    self.fail(site, "direct call has the wrong witness count")
  }
  if arguments.length() != callee.inputs.user_parameters.length() {
    self.fail(site, "direct call has the wrong user argument count")
  }
  for index in 0..<witnesses.length() {
    let expected = self.slot_metadata(
      site,
      callee,
      callee.inputs.witnesses[index],
    )
    let actual = self.slot_metadata(site, caller, witnesses[index])
    if expected.representation != actual.representation ||
      expected.cleanup != actual.cleanup {
      self.fail(site, "direct-call witness \{index} has the wrong value shape")
    }
  }
  for index in 0..<arguments.length() {
    let expected = self.slot_metadata(
      site,
      callee,
      callee.inputs.user_parameters[index],
    )
    let actual = self.slot_metadata(site, caller, arguments[index])
    if expected.representation != actual.representation ||
      expected.cleanup != actual.cleanup {
      self.fail(site, "direct-call argument \{index} has the wrong value shape")
    }
  }
}

///|
fn BytecodeVerifier::verify_call_result(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  caller : FunctionBody,
  result : ResultRepresentation,
  destination : SlotId?,
  tail_result~ : ResultRepresentation?,
) -> Unit raise BytecodeVerificationError {
  match tail_result {
    Some(expected) =>
      if result != expected {
        self.fail(site, "tail-call result representation does not match caller")
      }
    None =>
      match (result_representation(result), destination) {
        (None, None) => ()
        (Some(representation), Some(destination)) =>
          ignore(
            self.expect_representation(
              site, caller, destination, representation,
            ),
          )
        (None, Some(_)) =>
          self.fail(site, "Unit call must omit its destination")
        (Some(_), None) =>
          self.fail(site, "non-Unit call requires a destination")
      }
  }
}

///|
fn BytecodeVerifier::verify_object_construction(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  shape : ObjectShapeId,
  layout : LayoutOperand,
  witnesses : Array[SlotId],
  values : Array[SlotId],
  stored_witness_count : Int,
  members : Array[MemberSchema],
  environment~ : Bool,
) -> Unit raise BytecodeVerificationError {
  match layout {
    Immediate(layout) =>
      match (environment, self.layout_recipe(site, layout)) {
        (false, Data(actual)) | (true, Environment(actual)) =>
          if actual != shape {
            self.fail(site, "object layout references a different shape")
          }
        _ => self.fail(site, "object construction uses the wrong layout recipe")
      }
    Witness(witness) => self.expect_slot(site, body, witness, I32, Trivial)
  }
  if witnesses.length() != stored_witness_count {
    self.fail(site, "object construction has the wrong witness count")
  }
  for witness in witnesses {
    self.expect_slot(site, body, witness, I32, Trivial)
  }
  if values.length() != members.length() {
    self.fail(site, "object construction has the wrong member count")
  }
  for index in 0..<values.length() {
    let schema = members[index]
    self.expect_slot(
      site,
      body,
      values[index],
      schema.representation,
      schema.cleanup,
    )
  }
}

///|
fn BytecodeVerifier::verify_projection_result(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  member_index : Int,
  result : ProjectionResult,
  members : Array[MemberSchema],
  consuming~ : Bool,
) -> Unit raise BytecodeVerificationError {
  if member_index < 0 || member_index >= members.length() {
    self.fail(site, "object member index \{member_index} is out of range")
  }
  let schema = members[member_index]
  let expected_cleanup = if consuming || schema.cleanup is OwnedErased {
    schema.cleanup
  } else {
    Trivial
  }
  self.expect_slot(
    site,
    body,
    result.value_destination,
    schema.representation,
    expected_cleanup,
  )
  match (schema.cleanup, result.witness_destination) {
    (OwnedErased, Some(witness)) =>
      self.expect_slot(site, body, witness, I32, Trivial)
    (OwnedErased, None) =>
      self.fail(site, "OwnedErased projection requires a witness destination")
    (_, Some(_)) =>
      self.fail(site, "only OwnedErased projections have witness destinations")
    _ => ()
  }
}

///|
fn BytecodeVerifier::verify_projection_selections(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  selections : Array[ProjectionSelection],
  members : Array[MemberSchema],
) -> Unit raise BytecodeVerificationError {
  for index, selection in selections {
    self.verify_projection_result(
      site,
      body,
      selection.member_index,
      selection.result,
      members,
      consuming=true,
    )
    for previous in 0..<index {
      if selections[previous].member_index == selection.member_index {
        self.fail(site, "consume projection selects one member more than once")
      }
    }
  }
}

///|
fn BytecodeVerifier::verify_init_global(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  global : GlobalId,
  source : SlotId,
) -> Unit raise BytecodeVerificationError {
  let global_metadata = self.global_metadata(site, global)
  let source_metadata = self.slot_metadata(site, body, source)
  if self.image.globals.any(fn(metadata) {
      metadata.erased_companion == Some(global)
    }) {
    self.fail(site, "InitGlobal cannot target an erased companion global")
  }
  if global_metadata.representation != source_metadata.representation ||
    global_metadata.cleanup != source_metadata.cleanup {
    self.fail(site, "InitGlobal source has the wrong value shape")
  }
}

///|
fn BytecodeVerifier::verify_borrow_global(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  global : GlobalId,
) -> Unit raise BytecodeVerificationError {
  let global_metadata = self.global_metadata(site, global)
  let expected_cleanup = if global_metadata.cleanup is OwnedErased {
    OwnedErased
  } else {
    Trivial
  }
  self.expect_slot(
    site,
    body,
    destination,
    global_metadata.representation,
    expected_cleanup,
  )
}
