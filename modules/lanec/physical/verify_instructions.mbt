///|
fn PhysicalProgramVerifier::verify_instruction(
  self : PhysicalProgramVerifier,
  function : FunctionId,
  block : BlockId,
  index : Int,
  body : FunctionBody,
  instruction : Instruction,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Instruction(function, block, index)
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
        destination_metadata.representation != source_metadata.representation ||
        destination_metadata.kind != source_metadata.kind {
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
      self.expect_value_shape(
        site,
        body,
        destination,
        I64,
        Trivial,
        ScalarValue,
      )
    ConstI32(destination, _) | ConstBool(destination, _) =>
      self.expect_value_shape(
        site,
        body,
        destination,
        I32,
        Trivial,
        ScalarValue,
      )
    ConstChar(destination, value) => {
      self.expect_value_shape(
        site,
        body,
        destination,
        I32,
        Trivial,
        ScalarValue,
      )
      if value.to_char() is None {
        self.fail(site, "Char constant \{value} is not a Unicode scalar value")
      }
    }
    ConstF64(destination, _) =>
      self.expect_value_shape(
        site,
        body,
        destination,
        F64,
        Trivial,
        ScalarValue,
      )
    ConstF32(destination, _) =>
      self.expect_value_shape(
        site,
        body,
        destination,
        F32,
        Trivial,
        ScalarValue,
      )
    ConstLayout(destination, layout) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_kind(site, body, destination, LayoutValue)
      ignore(self.layout_recipe(site, layout))
    }
    ConstFunction(destination, target) => {
      self.expect_slot(site, body, destination, I64, OwnedCallable)
      let destination_kind = self.slot_metadata(site, body, destination).kind
      self.expect_callable_kind(site, destination_kind)
      match self.function_entry(site, target) {
        PhysicalBody(target_body) => {
          if target_body.inputs.environment is Some(_) {
            self.fail(site, "ConstFunction target requires an environment")
          }
          self.verify_callable_kind_abi(
            site,
            destination_kind,
            self.function_callable_abi(site, target),
          )
        }
        RuntimeImport(_) =>
          if !(destination_kind is CallableValue) {
            self.fail(site, "runtime imports cannot be layout constructors")
          }
      }
    }
    ConstString(destination, constant) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_kind(site, body, destination, ByteSequenceValue)
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
    CallValue(callable, abi_id, witnesses, arguments, destination) => {
      self.expect_slot(site, body, callable, I64, OwnedCallable)
      let callable_kind = self.slot_metadata(site, body, callable).kind
      self.expect_callable_kind(site, callable_kind)
      let abi = self.callable_abi(site, abi_id)
      self.verify_callable_kind_abi(site, callable_kind, abi)
      self.verify_call_abi(
        site,
        body,
        abi,
        witnesses,
        arguments,
        destination,
        tail_result=None,
      )
    }
    MakeData(destination, shape, layout, witnesses, fields) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      guard self.object_shape(site, shape) is Data(data) else {
        self.fail(site, "MakeData requires a Data object shape")
      }
      self.expect_data_value(site, body, destination, Some(data.family))
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
      self.expect_kind(site, body, destination, EnvironmentValue(shape))
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
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_data_value(site, body, source, None)
      guard self.slot_metadata(site, body, source).kind is DataValue(family) else {
        self.fail(site, "LoadTag source lost its Data family")
      }
      self.require_data_family_layouts(site, family)
    }
    LoadObjectWitness(destination, shape, source, ordinal) => {
      ignore(self.object_layout_id(site, shape))
      self.expect_slot(site, body, destination, I32, Trivial)
      let witness_count = match self.object_shape(site, shape) {
        Data(data) => {
          self.expect_data_value(site, body, source, Some(data.family))
          data.stored_witness_count
        }
        Environment(environment) => {
          self.expect_kind(site, body, source, EnvironmentValue(shape))
          environment.stored_witness_count
        }
      }
      self.expect_kind(site, body, destination, LayoutValue)
      if ordinal < 0 || ordinal >= witness_count {
        self.fail(site, "object witness ordinal \{ordinal} is out of range")
      }
    }
    BorrowField(shape, source, field_index, result) => {
      ignore(self.object_layout_id(site, shape))
      guard self.object_shape(site, shape) is Data(data) else {
        self.fail(site, "BorrowField requires a Data object shape")
      }
      self.expect_data_value(site, body, source, Some(data.family))
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
      ignore(self.object_layout_id(site, shape))
      guard self.object_shape(site, shape) is Environment(environment) else {
        self.fail(site, "BorrowCapture requires an Environment object shape")
      }
      self.expect_kind(site, body, source, EnvironmentValue(shape))
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
      ignore(self.object_layout_id(site, shape))
      guard self.object_shape(site, shape) is Data(data) else {
        self.fail(site, "ConsumeFields requires a Data object shape")
      }
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.expect_data_value(site, body, source, Some(data.family))
      self.verify_projection_selections(site, body, selections, data.members)
    }
    ConsumeCaptures(shape, source, selections) => {
      ignore(self.object_layout_id(site, shape))
      guard self.object_shape(site, shape) is Environment(environment) else {
        self.fail(site, "ConsumeCaptures requires an Environment object shape")
      }
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.expect_kind(site, body, source, EnvironmentValue(shape))
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
      let destination_kind = self.slot_metadata(site, body, destination).kind
      self.expect_callable_kind(site, destination_kind)
      match self.function_entry(site, target) {
        PhysicalBody(target_body) => {
          if target_body.inputs.environment is None {
            self.fail(site, "MakeClosure target does not accept an environment")
          }
          guard target_body.inputs.environment is Some(target_environment) else {
            self.fail(site, "MakeClosure target does not accept an environment")
          }
          self.expect_kind(
            site,
            body,
            environment,
            target_body.slots[target_environment.value].kind,
          )
          self.verify_callable_kind_abi(
            site,
            destination_kind,
            self.function_callable_abi(site, target),
          )
        }
        RuntimeImport(_) =>
          self.fail(site, "MakeClosure target must be a physical body")
      }
    }
    ByteToI64(destination, source) => {
      self.expect_slot(site, body, destination, I64, Trivial)
      self.expect_slot(site, body, source, I32, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, source, ScalarValue)
    }
    I64ToByte(destination, source) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_slot(site, body, source, I64, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, source, ScalarValue)
    }
    ByteSequenceMake(destination, length, fill) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_kind(site, body, destination, ByteSequenceValue)
      self.expect_slot(site, body, length, I64, Trivial)
      self.expect_slot(site, body, fill, I32, Trivial)
      self.expect_kind(site, body, length, ScalarValue)
      self.expect_kind(site, body, fill, ScalarValue)
    }
    ByteSequenceLength(destination, source) => {
      self.expect_slot(site, body, destination, I64, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, source, ByteSequenceValue)
    }
    WasiFdWrite(destination, fd, bytes) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_slot(site, body, fd, I32, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, fd, ScalarValue)
      self.expect_slot(site, body, bytes, I32, OwnedRef)
      self.expect_kind(site, body, bytes, ByteSequenceValue)
    }
    ByteSequenceGet(destination, source, index) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, source, ByteSequenceValue)
      self.expect_slot(site, body, index, I64, Trivial)
      self.expect_kind(site, body, index, ScalarValue)
    }
    ByteSequenceSet(destination, source, index, value) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.expect_kind(site, body, destination, ByteSequenceValue)
      self.expect_kind(site, body, source, ByteSequenceValue)
      self.expect_slot(site, body, index, I64, Trivial)
      self.expect_slot(site, body, value, I32, Trivial)
      self.expect_kind(site, body, index, ScalarValue)
      self.expect_kind(site, body, value, ScalarValue)
    }
    ByteSequenceEqual(destination, left, right) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, left, ByteSequenceValue)
      self.expect_kind(site, body, right, ByteSequenceValue)
    }
    ByteSequenceConcat(destination, left, right) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, left, I32, OwnedRef)
      self.expect_slot(site, body, right, I32, OwnedRef)
      self.expect_kind(site, body, destination, ByteSequenceValue)
      self.expect_kind(site, body, left, ByteSequenceValue)
      self.expect_kind(site, body, right, ByteSequenceValue)
    }
    ByteSequenceSlice(destination, source, start, length) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, I32, OwnedRef)
      self.expect_kind(site, body, destination, ByteSequenceValue)
      self.expect_kind(site, body, source, ByteSequenceValue)
      self.expect_slot(site, body, start, I64, Trivial)
      self.expect_slot(site, body, length, I64, Trivial)
      self.expect_kind(site, body, start, ScalarValue)
      self.expect_kind(site, body, length, ScalarValue)
    }
    ByteSequenceIsValidUtf8(destination, source) => {
      self.expect_slot(site, body, destination, I32, Trivial)
      self.expect_kind(site, body, destination, ScalarValue)
      self.expect_kind(site, body, source, ByteSequenceValue)
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
      self.expect_kind(site, body, destination, ByteSequenceValue)
    }
    F64ToString(destination, source) => {
      self.expect_slot(site, body, destination, I32, OwnedRef)
      self.expect_slot(site, body, source, F64, Trivial)
      self.expect_kind(site, body, destination, ByteSequenceValue)
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
      self.expect_value_shape(
        site,
        body,
        destination,
        I64,
        OwnedErased,
        ErasedValue,
      )
    UneraseUnit(source) =>
      self.expect_value_shape(site, body, source, I64, OwnedErased, ErasedValue)
    InitGlobal(global, source) =>
      self.verify_init_global(site, body, global, source)
    BorrowGlobal(destination, global) =>
      self.verify_borrow_global(site, body, destination, global)
  }
}

///|
fn PhysicalProgramVerifier::verify_unary(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  source : SlotId,
  destination_representation : Representation,
  source_representation : Representation,
) -> Unit raise PhysicalProgramVerificationError {
  self.expect_slot(site, body, destination, destination_representation, Trivial)
  self.expect_slot(site, body, source, source_representation, Trivial)
  self.expect_kind(site, body, destination, ScalarValue)
  self.expect_kind(site, body, source, ScalarValue)
}

///|
fn PhysicalProgramVerifier::verify_binary(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  left : SlotId,
  right : SlotId,
  destination_representation : Representation,
  operand_representation : Representation,
) -> Unit raise PhysicalProgramVerificationError {
  self.expect_slot(site, body, destination, destination_representation, Trivial)
  self.expect_slot(site, body, left, operand_representation, Trivial)
  self.expect_slot(site, body, right, operand_representation, Trivial)
  self.expect_kind(site, body, destination, ScalarValue)
  self.expect_kind(site, body, left, ScalarValue)
  self.expect_kind(site, body, right, ScalarValue)
}

///|
fn PhysicalProgramVerifier::verify_erasure(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  source : SlotId,
  source_representation : Representation,
) -> Unit raise PhysicalProgramVerificationError {
  self.expect_slot(site, body, destination, I64, OwnedErased)
  self.expect_kind(site, body, destination, ErasedValue)
  ignore(self.expect_representation(site, body, source, source_representation))
}

///|
fn PhysicalProgramVerifier::verify_unerasure(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  source : SlotId,
  destination_representation : Representation,
) -> Unit raise PhysicalProgramVerificationError {
  ignore(
    self.expect_representation(
      site, body, destination, destination_representation,
    ),
  )
  self.expect_slot(site, body, source, I64, OwnedErased)
  self.expect_kind(site, body, source, ErasedValue)
}

///|
fn PhysicalProgramVerifier::verify_direct_call(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  target : FunctionId,
  environment : SlotId?,
  witnesses : Array[SlotId],
  arguments : Array[SlotId],
  destination : SlotId?,
  tail_result~ : ResultAbi?,
) -> Unit raise PhysicalProgramVerificationError {
  let entry = self.function_entry(site, target)
  match entry {
    PhysicalBody(target_body) =>
      match (target_body.inputs.environment, environment) {
        (None, None) => ()
        (Some(expected), Some(actual)) => {
          self.expect_slot(site, body, actual, I32, OwnedRef)
          self.expect_kind(
            site,
            body,
            actual,
            target_body.slots[expected.value].kind,
          )
        }
        _ =>
          self.fail(
            site, "direct-call environment presence does not match target",
          )
      }
    RuntimeImport(import_) => {
      ignore(import_)
      if environment is Some(_) {
        self.fail(site, "runtime import call cannot carry an environment")
      }
    }
  }
  let abi = self.function_callable_abi(site, target)
  self.verify_call_abi(
    site,
    body,
    abi,
    witnesses,
    arguments,
    destination,
    tail_result~,
  )
}

///|
fn PhysicalProgramVerifier::verify_call_abi(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  abi : CallableAbi,
  witnesses : Array[SlotId],
  arguments : Array[SlotId],
  destination : SlotId?,
  tail_result~ : ResultAbi?,
) -> Unit raise PhysicalProgramVerificationError {
  if witnesses.length() != abi.witnesses.length() {
    self.fail(site, "call has the wrong witness count")
  }
  if arguments.length() != abi.parameters.length() {
    self.fail(site, "call has the wrong user argument count")
  }
  let witness_slots : Array[SlotMetadata] = []
  for witness in witnesses {
    witness_slots.push(self.slot_metadata(site, body, witness))
  }
  let parameter_slots : Array[SlotMetadata] = []
  for argument in arguments {
    parameter_slots.push(self.slot_metadata(site, body, argument))
  }
  let result = match tail_result {
    Some(result) => result
    None =>
      match destination {
        Some(destination) =>
          self.slot_metadata(site, body, destination).result_abi()
        None => Unit
      }
  }
  let callsite = CallableAbi::from_slot_metadata(
    witness_slots, parameter_slots, result,
  )
  match abi.callsite_mismatch(callsite) {
    None => ()
    Some(CallParameterMismatch(index)) =>
      self.fail(site, "call argument \{index} has the wrong value shape")
    Some(CallResultMismatch) =>
      if tail_result is Some(_) {
        self.fail(site, "tail-call result ABI does not match caller")
      } else {
        self.fail(site, "call result ABI does not match destination slot")
      }
    Some(CallShapeMismatch) =>
      self.fail(
        site, "callsite value shapes do not instantiate the callable ABI",
      )
  }
}

///|
fn PhysicalProgramVerifier::expect_callable_kind(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  kind : SemanticValueKind,
) -> Unit raise PhysicalProgramVerificationError {
  match kind {
    CallableValue | LayoutConstructorValue(_) => ()
    _ => self.fail(site, "callable slot has the wrong semantic value kind")
  }
}

///|
fn PhysicalProgramVerifier::verify_callable_kind_abi(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  kind : SemanticValueKind,
  abi : CallableAbi,
) -> Unit raise PhysicalProgramVerificationError {
  guard kind is LayoutConstructorValue(arity) else { return }
  if !abi.witnesses.is_empty() || abi.parameters.length() != arity {
    self.fail(site, "layout constructor ABI has the wrong arity")
  }
  for parameter in abi.parameters {
    match parameter.kind {
      LayoutValue | LayoutConstructorValue(_) => ()
      _ => self.fail(site, "layout constructor has a non-evidence parameter")
    }
  }
  if abi.result != Value(I32, Trivial, LayoutValue) {
    self.fail(site, "layout constructor must return a layout value")
  }
}

///|
fn PhysicalProgramVerifier::verify_object_construction(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  shape : ObjectShapeId,
  layout : LayoutOperand,
  witnesses : Array[SlotId],
  values : Array[SlotId],
  stored_witness_count : Int,
  members : Array[MemberSchema],
  environment~ : Bool,
) -> Unit raise PhysicalProgramVerificationError {
  match layout {
    Immediate(layout) =>
      match (environment, self.layout_recipe(site, layout)) {
        (false, Data(actual)) | (true, Environment(actual)) =>
          if actual != shape {
            self.fail(site, "object layout references a different shape")
          }
        _ => self.fail(site, "object construction uses the wrong layout recipe")
      }
    Witness(witness) => {
      self.expect_slot(site, body, witness, I32, Trivial)
      self.expect_kind(site, body, witness, LayoutValue)
    }
  }
  if witnesses.length() != stored_witness_count {
    self.fail(site, "object construction has the wrong witness count")
  }
  for witness in witnesses {
    self.expect_slot(site, body, witness, I32, Trivial)
    self.expect_kind(site, body, witness, LayoutValue)
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
    self.expect_kind(site, body, values[index], schema.kind)
    if schema.cleanup is OwnedErased &&
      schema.witness_ordinal is Some(witness_ordinal) {
      let metadata = self.slot_metadata(site, body, values[index])
      if metadata.erased_companion != Some(witnesses[witness_ordinal]) {
        self.fail(
          site, "erased object member does not use its stored layout witness",
        )
      }
    }
  }
}

///|
fn PhysicalProgramVerifier::verify_projection_result(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  member_index : Int,
  result : ProjectionResult,
  members : Array[MemberSchema],
  consuming~ : Bool,
) -> Unit raise PhysicalProgramVerificationError {
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
  self.expect_kind(site, body, result.value_destination, schema.kind)
  match (schema.cleanup, result.witness_destination) {
    (OwnedErased, Some(witness)) =>
      self.expect_value_shape(site, body, witness, I32, Trivial, LayoutValue)
    (OwnedErased, None) =>
      self.fail(site, "OwnedErased projection requires a witness destination")
    (_, Some(_)) =>
      self.fail(site, "only OwnedErased projections have witness destinations")
    _ => ()
  }
}

///|
fn PhysicalProgramVerifier::verify_projection_selections(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  selections : Array[ProjectionSelection],
  members : Array[MemberSchema],
) -> Unit raise PhysicalProgramVerificationError {
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
fn PhysicalProgramVerifier::verify_init_global(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  global : GlobalId,
  source : SlotId,
) -> Unit raise PhysicalProgramVerificationError {
  let global_metadata = self.global_metadata(site, global)
  let source_metadata = self.slot_metadata(site, body, source)
  if self.image.globals.any(fn(metadata) {
      metadata.erased_companion == Some(global)
    }) {
    self.fail(site, "InitGlobal cannot target an erased companion global")
  }
  if global_metadata.representation != source_metadata.representation ||
    global_metadata.cleanup != source_metadata.cleanup ||
    global_metadata.kind != source_metadata.kind {
    self.fail(site, "InitGlobal source has the wrong value shape")
  }
}

///|
fn PhysicalProgramVerifier::verify_borrow_global(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  destination : SlotId,
  global : GlobalId,
) -> Unit raise PhysicalProgramVerificationError {
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
  self.expect_kind(site, body, destination, global_metadata.kind)
}
