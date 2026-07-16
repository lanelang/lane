///|
pub using @bytecode {type RuntimeValueKind}

///|
pub struct HostStringView {
  length : Int
  read_byte : (Int) -> Byte
}

///|
pub fn HostStringView::new(
  length~ : Int,
  read_byte~ : (Int) -> Byte,
) -> HostStringView {
  { length, read_byte }
}

///|
pub fn HostStringView::length(self : HostStringView) -> Int {
  self.length
}

///|
pub fn HostStringView::byte(self : HostStringView, index : Int) -> Byte? {
  if index < 0 || index >= self.length {
    None
  } else {
    Some((self.read_byte)(index))
  }
}

///|
pub fn HostStringView::to_bytes(self : HostStringView) -> Bytes {
  let bytes = Array::make(self.length, b'\x00')
  for index in 0..<self.length {
    bytes[index] = (self.read_byte)(index)
  }
  Bytes::from_array(bytes)
}

///|
pub fn HostStringView::to_string(self : HostStringView) -> String {
  @utf8.decode(self.to_bytes()) catch {
    _ => abort("HostStringView contains non-ASCII bytes")
  }
}

///|
pub impl Eq for HostStringView with fn equal(
  self : HostStringView,
  other : HostStringView,
) -> Bool {
  if self.length != other.length {
    return false
  }
  for index in 0..<self.length {
    if (self.read_byte)(index) != (other.read_byte)(index) {
      return false
    }
  }
  true
}

///|
pub impl Debug for HostStringView with fn to_repr(self : HostStringView) -> Repr {
  Repr::ctor("HostStringView", [(None, Repr::string(self.to_string()))])
}

///|
pub(all) enum HostValue {
  Unit
  Bool(Bool)
  Int(Int64)
  Double(Double)
  BorrowedString(HostStringView)
  String(String)
  BorrowedOpaque(BorrowedHostObject)
  OwnedOpaque(OwnedHostObject)
} derive(Debug)

///|
priv struct RuntimeContextState {
  host_objects : HostObjectTable
}

///|
struct RuntimeContext {
  state : RuntimeContextState
}

///|
struct ExecutionRuntime {
  context : RuntimeContext
}

///|
pub fn ExecutionRuntime::new(
  config? : ExecutionConfig = ExecutionConfig::defaults(),
) -> ExecutionRuntime {
  {
    context: {
      state: { host_objects: HostObjectTable::new(config.max_host_objects) },
    },
  }
}

///|
pub fn ExecutionRuntime::context(self : ExecutionRuntime) -> RuntimeContext {
  self.context
}

///|
pub(all) suberror RuntimeImportFailure {
  Failure(message~ : String)
} derive(Debug, Eq)

///|
pub(all) suberror RuntimeImportResolutionError {
  UnresolvedImport(symbol~ : String)
  AbiMismatch(symbol~ : String, expected_major~ : Int, actual_major~ : Int)
  ParameterKindsMismatch(
    symbol~ : String,
    expected~ : Array[RuntimeValueKind],
    actual~ : Array[RuntimeValueKind]
  )
  ResultKindMismatch(
    symbol~ : String,
    expected~ : RuntimeValueKind,
    actual~ : RuntimeValueKind
  )
} derive(Debug, Eq)

///|
pub(all) enum ResourceLimitKind {
  CallDepth
  LiveHeapBytes
  HostObjects
} derive(Debug, Eq)

///|
pub(all) suberror ExecutionError {
  RuntimeImportFailure(symbol~ : String, message~ : String)
  ExecutionResourceLimit(kind~ : ResourceLimitKind)
  Interrupted
  EngineTrap(detail~ : String)
  InternalRuntimeFailure(detail~ : String)
  InstanceNotReady
} derive(Debug, Eq)

///|
pub(all) struct ExecutionConfig {
  max_call_depth : Int?
  max_live_heap_bytes : Int?
  max_host_objects : Int?
} derive(Debug, Eq)

///|
pub fn ExecutionConfig::defaults() -> ExecutionConfig {
  { max_call_depth: None, max_live_heap_bytes: None, max_host_objects: None }
}

///|
pub type RuntimeFunction = (RuntimeContext, Array[HostValue]) -> HostValue raise RuntimeImportFailure

///|
pub struct RuntimeBinding {
  symbol : String
  abi_major : Int
  parameters : Array[RuntimeValueKind]
  result : RuntimeValueKind
  invoke : RuntimeFunction
}

///|
pub fn RuntimeBinding::new(
  symbol~ : String,
  abi_major~ : Int,
  parameters~ : Array[RuntimeValueKind],
  result~ : RuntimeValueKind,
  invoke~ : RuntimeFunction,
) -> RuntimeBinding {
  { symbol, abi_major, parameters, result, invoke }
}

///|
pub fn RuntimeBinding::symbol(self : RuntimeBinding) -> String {
  self.symbol
}

///|
pub fn RuntimeBinding::abi_major(self : RuntimeBinding) -> Int {
  self.abi_major
}

///|
pub fn RuntimeBinding::parameters(
  self : RuntimeBinding,
) -> Array[RuntimeValueKind] {
  self.parameters
}

///|
pub fn RuntimeBinding::result(self : RuntimeBinding) -> RuntimeValueKind {
  self.result
}

///|
pub fn RuntimeBinding::call(
  self : RuntimeBinding,
  context : RuntimeContext,
  arguments : Array[HostValue],
) -> HostValue raise RuntimeImportFailure {
  (self.invoke)(context, arguments)
}

///|
pub struct RuntimeRegistry {
  bindings : Array[RuntimeBinding]
}

///|
pub fn RuntimeRegistry::new() -> RuntimeRegistry {
  { bindings: [] }
}

///|
pub fn RuntimeRegistry::register(
  self : RuntimeRegistry,
  binding : RuntimeBinding,
) -> Unit {
  self.bindings.push(binding)
}

///|
pub fn RuntimeRegistry::find(
  self : RuntimeRegistry,
  symbol : String,
) -> RuntimeBinding? {
  for binding in self.bindings {
    if binding.symbol == symbol {
      return Some(binding)
    }
  }
  None
}

///|
pub fn RuntimeRegistry::resolve(
  self : RuntimeRegistry,
  symbol : String,
  expected_abi_major~ : Int,
  expected_parameters~ : Array[RuntimeValueKind],
  expected_result~ : RuntimeValueKind,
) -> Result[RuntimeBinding, RuntimeImportResolutionError] {
  let binding = match self.find(symbol) {
    Some(binding) => binding
    None => return Err(UnresolvedImport(symbol~))
  }
  if binding.abi_major() != expected_abi_major {
    return Err(
      AbiMismatch(
        symbol~,
        expected_major=expected_abi_major,
        actual_major=binding.abi_major(),
      ),
    )
  }
  if binding.parameters() != expected_parameters {
    return Err(
      ParameterKindsMismatch(
        symbol~,
        expected=expected_parameters,
        actual=binding.parameters(),
      ),
    )
  }
  if binding.result() != expected_result {
    return Err(
      ResultKindMismatch(
        symbol~,
        expected=expected_result,
        actual=binding.result(),
      ),
    )
  }
  Ok(binding)
}
