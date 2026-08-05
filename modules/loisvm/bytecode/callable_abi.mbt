///|
pub fn FunctionBody::callable_abi(self : FunctionBody) -> CallableAbi? {
  let parameters = []
  for parameter in self.inputs.user_parameters {
    guard self.slots.get(parameter.value) is Some(metadata) else { return None }
    parameters.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
    })
  }
  Some({
    witness_count: self.inputs.witnesses.length(),
    parameters,
    result: self.result,
  })
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
    witness_count: 0,
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
  if self.witness_count != callsite.witness_count ||
    self.parameters.length() != callsite.parameters.length() {
    return Some(CallShapeMismatch)
  }
  let implementation_bindings : Array[(Int, SemanticValueKind)] = []
  let callsite_bindings : Array[(Int, SemanticValueKind)] = []
  for index in 0..<self.parameters.length() {
    let expected = self.parameters[index]
    let actual = callsite.parameters[index]
    if expected.representation != actual.representation ||
      expected.cleanup != actual.cleanup ||
      !match_call_semantic_kind(
        implementation_bindings,
        callsite_bindings,
        expected.kind,
        actual.kind,
      ) {
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
        call_result_kind_matches(
          implementation_bindings, callsite_bindings, kind, actual_kind,
        ) {
        None
      } else {
        Some(CallResultMismatch)
      }
    _ => Some(CallResultMismatch)
  }
}

///|
fn match_call_semantic_kind(
  implementation_bindings : Array[(Int, SemanticValueKind)],
  callsite_bindings : Array[(Int, SemanticValueKind)],
  implementation : SemanticValueKind,
  callsite : SemanticValueKind,
) -> Bool {
  if implementation is AbstractReferenceValue(parameter) {
    return bind_abstract_reference_kind(
      implementation_bindings, parameter, callsite,
    )
  }
  if callsite is AbstractReferenceValue(parameter) {
    return bind_abstract_reference_kind(
      callsite_bindings, parameter, implementation,
    )
  }
  implementation == callsite
}

///|
fn bind_abstract_reference_kind(
  bindings : Array[(Int, SemanticValueKind)],
  parameter : Int,
  concrete : SemanticValueKind,
) -> Bool {
  guard semantic_kind_is_reference(concrete) else { return false }
  for binding in bindings {
    let (bound_parameter, bound_kind) = binding
    if bound_parameter == parameter {
      return bound_kind == concrete
    }
  }
  bindings.push((parameter, concrete))
  true
}

///|
fn call_result_kind_matches(
  implementation_bindings : Array[(Int, SemanticValueKind)],
  callsite_bindings : Array[(Int, SemanticValueKind)],
  implementation : SemanticValueKind,
  callsite : SemanticValueKind,
) -> Bool {
  if implementation is AbstractReferenceValue(parameter) {
    return bind_abstract_reference_kind(
      implementation_bindings, parameter, callsite,
    )
  }
  if callsite is AbstractReferenceValue(parameter) {
    return bind_abstract_reference_kind(
      callsite_bindings, parameter, implementation,
    )
  }
  implementation == callsite
}

///|
fn semantic_kind_is_reference(kind : SemanticValueKind) -> Bool {
  match kind {
    ByteSequenceValue
    | DataValue(_)
    | EnvironmentValue(_)
    | AbstractReferenceValue(_)
    | OpaqueReferenceValue => true
    _ => false
  }
}
