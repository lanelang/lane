///|
fn SlotMetadata::value_abi(self : SlotMetadata) -> ValueAbi {
  {
    representation: self.representation,
    cleanup: self.cleanup,
    kind: self.kind,
  }
}

///|
fn ValueAbi::result_abi(self : ValueAbi) -> ResultAbi {
  Value(self.representation, self.cleanup, self.kind)
}

///|
fn CallableAbi::from_value_abis(
  witnesses : Array[ValueAbi],
  parameters : Array[ValueAbi],
  result : ResultAbi,
) -> CallableAbi {
  { witnesses, parameters, result, }
}

///|
pub fn SlotMetadata::result_abi(self : SlotMetadata) -> ResultAbi {
  self.value_abi().result_abi()
}

///|
/// Projects finalized slot metadata into the callable ABI used by definitions
/// and call sites.
pub fn CallableAbi::from_slot_metadata(
  witness_slots : Array[SlotMetadata],
  parameter_slots : Array[SlotMetadata],
  result : ResultAbi,
) -> CallableAbi {
  CallableAbi::from_value_abis(
    witness_slots.map(slot => slot.value_abi()),
    parameter_slots.map(slot => slot.value_abi()),
    result,
  )
}

///|
pub fn FunctionBody::callable_abi(self : FunctionBody) -> CallableAbi? {
  let witnesses = []
  for witness in self.inputs.witnesses {
    guard self.slots.get(witness.value) is Some(metadata) else { return None }
    witnesses.push(metadata)
  }
  let parameters = []
  for parameter in self.inputs.user_parameters {
    guard self.slots.get(parameter.value) is Some(metadata) else { return None }
    parameters.push(metadata)
  }
  Some(CallableAbi::from_slot_metadata(witnesses, parameters, self.result))
}

///|
pub fn runtime_import_callable_abi(
  import_ : @wasm_abi.ImportContract,
) -> CallableAbi {
  let parameters = []
  for parameter in import_.parameters {
    if import_parameter_value_abi(parameter) is Some(abi) {
      parameters.push(abi)
    }
  }
  CallableAbi::from_value_abis(
    [],
    parameters,
    match import_result_value_abi(import_.result) {
      Some(abi) => abi.result_abi()
      None => Unit
    },
  )
}

///|
pub fn FunctionEntry::callable_abi(self : FunctionEntry) -> CallableAbi? {
  match self {
    PhysicalBody(body) => body.callable_abi()
    RuntimeImport(import_) => Some(runtime_import_callable_abi(import_))
  }
}

///|
pub fn PhysicalProgram::callable_abi(
  self : PhysicalProgram,
  id : CallableAbiId,
) -> CallableAbi? {
  self.callable_abis.get(id.value)
}

///|
pub fn PhysicalProgram::function_callable_abi(
  self : PhysicalProgram,
  id : FunctionId,
) -> CallableAbi? {
  guard id.value > 0 && self.functions.get(id.value - 1) is Some(entry) else {
    return None
  }
  entry.callable_abi()
}

///|
pub fn PhysicalProgram::function_callable_abi_id(
  self : PhysicalProgram,
  id : FunctionId,
) -> CallableAbiId? {
  guard self.function_callable_abi(id) is Some(abi) else { return None }
  self.callable_abis.search(abi).map(index => { value: index, })
}

///|
fn core_value_abi(type_ : @wasm_abi.CoreValueType) -> ValueAbi {
  {
    representation: match type_ {
      I32 => I32
      I64 => I64
      F32 => F32
      F64 => F64
    },
    cleanup: Trivial,
    kind: ScalarValue,
  }
}

///|
fn import_parameter_value_abi(
  parameter : @wasm_abi.ImportParameter,
) -> ValueAbi? {
  match parameter {
    ErasedUnit => None
    Direct(type_) => Some(core_value_abi(type_))
  }
}

///|
fn import_result_value_abi(result : @wasm_abi.ImportResult) -> ValueAbi? {
  match result {
    Unit => None
    Direct(type_) => Some(core_value_abi(type_))
  }
}

///|
pub fn CallableAbi::accepts_callsite(
  self : CallableAbi,
  callsite : CallableAbi,
) -> Bool {
  self.callsite_mismatch(callsite) is None
}

///|
priv enum CallableAbiMismatch {
  CallShapeMismatch
  CallParameterMismatch(Int)
  CallResultMismatch
}

///|
fn CallableAbi::callsite_mismatch(
  self : CallableAbi,
  callsite : CallableAbi,
) -> CallableAbiMismatch? {
  if self.witnesses.length() != callsite.witnesses.length() ||
    self.parameters.length() != callsite.parameters.length() {
    return Some(CallShapeMismatch)
  }
  for index in 0..<self.witnesses.length() {
    let expected = self.witnesses[index]
    let actual = callsite.witnesses[index]
    if expected.representation != actual.representation ||
      expected.cleanup != actual.cleanup ||
      expected.kind != actual.kind {
      return Some(CallShapeMismatch)
    }
  }
  for index in 0..<self.parameters.length() {
    let expected = self.parameters[index]
    let actual = callsite.parameters[index]
    if expected.representation != actual.representation ||
      expected.cleanup != actual.cleanup ||
      expected.kind != actual.kind {
      return Some(CallParameterMismatch(index))
    }
  }
  match (self.result, callsite.result) {
    (Unit, Unit) => None
    (
      Value(representation, cleanup, kind),
      Value(actual_representation, actual_cleanup, actual_kind),
    ) =>
      if representation == actual_representation &&
        cleanup == actual_cleanup &&
        kind == actual_kind {
        None
      } else {
        Some(CallResultMismatch)
      }
    _ => Some(CallResultMismatch)
  }
}
