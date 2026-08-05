///|
pub fn FunctionBody::callable_abi(self : FunctionBody) -> CallableAbi? {
  let parameters = []
  for parameter in self.inputs.user_parameters {
    guard self.slots.get(parameter.value) is Some(metadata) else { return None }
    parameters.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
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
      Some(abi) => Value(abi.representation, abi.cleanup)
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
    Bool => Some({ representation: I32, cleanup: Trivial })
    I64 => Some({ representation: I64, cleanup: Trivial })
    F64 => Some({ representation: F64, cleanup: Trivial })
    F32 => Some({ representation: F32, cleanup: Trivial })
    String | Opaque => Some({ representation: I32, cleanup: OwnedRef })
  }
}
