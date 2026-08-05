///|
pub fn FunctionBody::callable_abi(self : FunctionBody) -> CallableAbi? {
  let witnesses = []
  for witness in self.inputs.witnesses {
    guard self.slots.get(witness.value) is Some(metadata) else { return None }
    witnesses.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
    })
  }
  let parameters = []
  for parameter in self.inputs.user_parameters {
    guard self.slots.get(parameter.value) is Some(metadata) else { return None }
    parameters.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
    })
  }
  Some({ witnesses, parameters, result: self.result })
}

///|
pub fn RuntimeImport::callable_abi(self : RuntimeImport) -> CallableAbi {
  let parameters = []
  for parameter in self.parameters {
    if runtime_value_abi(parameter) is Some(abi) {
      parameters.push(abi)
    }
  }
  {
    witnesses: [],
    parameters,
    result: match runtime_value_abi(self.result) {
      Some(abi) => Value(abi.representation, abi.cleanup, abi.kind)
      None => Unit
    },
  }
}

///|
pub fn FunctionEntry::callable_abi(self : FunctionEntry) -> CallableAbi? {
  match self {
    BytecodeBody(body) => body.callable_abi()
    RuntimeImport(import_) => Some(import_.callable_abi())
  }
}

///|
pub fn BytecodeImage::callable_abi(
  self : BytecodeImage,
  id : CallableAbiId,
) -> CallableAbi? {
  self.callable_abis.get(id.value)
}

///|
pub fn BytecodeImage::function_callable_abi(
  self : BytecodeImage,
  id : FunctionId,
) -> CallableAbi? {
  guard id.value > 0 && self.functions.get(id.value - 1) is Some(entry) else {
    return None
  }
  entry.callable_abi()
}

///|
pub fn BytecodeImage::function_callable_abi_id(
  self : BytecodeImage,
  id : FunctionId,
) -> CallableAbiId? {
  guard self.function_callable_abi(id) is Some(abi) else { return None }
  self.callable_abis.search(abi).map(index => { value: index })
}

///|
fn runtime_value_abi(kind : RuntimeValueKind) -> ValueAbi? {
  match kind {
    Unit => None
    Bool => Some({ representation: I32, cleanup: Trivial, kind: ScalarValue })
    I64 => Some({ representation: I64, cleanup: Trivial, kind: ScalarValue })
    F64 => Some({ representation: F64, cleanup: Trivial, kind: ScalarValue })
    F32 => Some({ representation: F32, cleanup: Trivial, kind: ScalarValue })
    String =>
      Some({ representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue })
    Opaque =>
      Some({
        representation: I32,
        cleanup: OwnedRef,
        kind: OpaqueReferenceValue,
      })
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
