///|
enum BuslaneRuntimeValueKind {
  Int(Int64)
  Bool(Bool)
  String(String)
  Unit
  Data(
    data_constructor~ : @buslane.DataConId,
    arguments~ : Array[BuslaneRuntimeValue]
  )
  Closure(
    parameters~ : Array[@buslane.ValueId],
    body~ : @buslane.Expr,
    environment~ : BuslaneRuntimeEnvironment
  )
  TypeClosure(body~ : @buslane.Expr, environment~ : BuslaneRuntimeEnvironment)
  NativeFunction(BuslaneNativeFunction)
  ResumeContinuation(BuslaneResumeContinuation)
  External(@buslane.ValueId)
}

///|
pub struct BuslaneRuntimeValue {
  priv kind : BuslaneRuntimeValueKind
}

///|
priv struct BuslaneRuntimeEnvironment {
  parent : BuslaneRuntimeEnvironment?
  mut values : @immut_sorted_map.SortedMap[
    @buslane.ValueId,
    BuslaneRuntimeValue,
  ]
}

///|
pub struct BuslaneRuntimeProgram {
  priv globals : BuslaneRuntimeEnvironment
}

///|
#warnings("-unused_constructor")
pub suberror BuslaneRuntimeError {
  InvalidProgram(Array[@buslane.VerifyDiagnostic])
  UnboundValue(@buslane.ValueId)
  MissingExternal(@buslane.ValueId)
  UnhandledOperation(@buslane.OperationId)
  ExternalFailure(id~ : @buslane.ValueId, message~ : String)
  InvalidValue(message~ : String)
} derive(Debug, Eq)

///|
pub type BuslaneNativeFunction = (Array[BuslaneRuntimeValue]) -> BuslaneRuntimeValue raise BuslaneRuntimeError

///|
priv struct BuslaneResumeContinuation {
  kont : Kont
}

///|
pub type BuslaneExternalResolver = (@buslane.ValueId, @buslane.Type) -> BuslaneRuntimeValue raise BuslaneRuntimeError

///|
pub struct BuslaneExternalRuntime {
  priv resolvers : Array[BuslaneExternalResolver]
}

///|
/// Creates a runtime error for an external value that no runtime handler owns.
pub fn missing_external(id : @buslane.ValueId) -> BuslaneRuntimeError {
  MissingExternal(id)
}

///|
/// Creates a runtime error for an external value handler failure.
pub fn external_failure(
  id : @buslane.ValueId,
  message : String,
) -> BuslaneRuntimeError {
  ExternalFailure(id~, message~)
}

///|
/// Creates an integer Buslane runtime value.
pub fn BuslaneRuntimeValue::int(value : Int64) -> BuslaneRuntimeValue {
  { kind: Int(value) }
}

///|
/// Creates a boolean Buslane runtime value.
pub fn BuslaneRuntimeValue::bool(value : Bool) -> BuslaneRuntimeValue {
  { kind: Bool(value) }
}

///|
/// Creates a string Buslane runtime value.
pub fn BuslaneRuntimeValue::string(value : String) -> BuslaneRuntimeValue {
  { kind: String(value) }
}

///|
/// Returns the unit Buslane runtime value.
pub fn BuslaneRuntimeValue::unit() -> BuslaneRuntimeValue {
  { kind: Unit }
}

///|
/// Returns this runtime value as an integer when it is an integer value.
pub fn BuslaneRuntimeValue::as_int(self : BuslaneRuntimeValue) -> Int64? {
  match self.kind {
    Int(value) => Some(value)
    _ => None
  }
}

///|
/// Returns this runtime value as a boolean when it is a boolean value.
pub fn BuslaneRuntimeValue::as_bool(self : BuslaneRuntimeValue) -> Bool? {
  match self.kind {
    Bool(value) => Some(value)
    _ => None
  }
}

///|
/// Returns this runtime value as a string when it is a string value.
pub fn BuslaneRuntimeValue::as_string(self : BuslaneRuntimeValue) -> String? {
  match self.kind {
    String(value) => Some(value)
    _ => None
  }
}

///|
/// Returns whether this runtime value behaves as a callable value.
pub fn BuslaneRuntimeValue::is_function(self : BuslaneRuntimeValue) -> Bool {
  match self.kind {
    Closure(..) | TypeClosure(..) | NativeFunction(_) | ResumeContinuation(_) =>
      true
    _ => false
  }
}

///|
/// Creates an opaque external Buslane runtime value.
pub fn BuslaneRuntimeValue::external(
  id : @buslane.ValueId,
) -> BuslaneRuntimeValue {
  { kind: External(id) }
}

///|
/// Creates a native function Buslane runtime value.
pub fn BuslaneRuntimeValue::native_function(
  handler : BuslaneNativeFunction,
) -> BuslaneRuntimeValue {
  { kind: NativeFunction(handler) }
}

///|
/// Creates a nominal data Buslane runtime value.
pub fn BuslaneRuntimeValue::data(
  data_constructor : @buslane.DataConId,
  arguments : Array[BuslaneRuntimeValue],
) -> BuslaneRuntimeValue {
  { kind: Data(data_constructor~, arguments~) }
}

///|
fn BuslaneRuntimeValue::runtime(
  kind : BuslaneRuntimeValueKind,
) -> BuslaneRuntimeValue {
  { kind, }
}

///|
fn BuslaneRuntimeValue::resume_continuation(kont : Kont) -> BuslaneRuntimeValue {
  { kind: ResumeContinuation({ kont, }) }
}

///|
/// Creates an empty Buslane runtime environment.
fn BuslaneRuntimeEnvironment::BuslaneRuntimeEnvironment() -> BuslaneRuntimeEnvironment {
  { parent: None, values: @immut_sorted_map.new() }
}

///|
/// Creates a runtime program from a global environment.
fn BuslaneRuntimeProgram::BuslaneRuntimeProgram(
  globals : BuslaneRuntimeEnvironment,
) -> BuslaneRuntimeProgram {
  { globals, }
}

///|
/// Creates an external runtime with no handlers.
pub fn BuslaneExternalRuntime::BuslaneExternalRuntime() -> BuslaneExternalRuntime {
  { resolvers: [] }
}

///|
/// Adds an external value resolver. Resolvers are tried in insertion order.
pub fn BuslaneExternalRuntime::add_resolver(
  self : BuslaneExternalRuntime,
  resolver : BuslaneExternalResolver,
) -> Unit {
  self.resolvers.push(resolver)
}

///|
/// Resolves an external declaration into a runtime value.
fn BuslaneExternalRuntime::resolve(
  self : BuslaneExternalRuntime,
  id : @buslane.ValueId,
  type_ : @buslane.Type,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  for resolver in self.resolvers {
    try {
      return resolver(id, type_)
    } catch {
      MissingExternal(_) => ()
      error => raise error
    }
  }
  BuslaneRuntimeValue::external(id)
}

///|
/// Creates a child frame whose parent is this runtime environment.
fn BuslaneRuntimeEnvironment::child(
  self : BuslaneRuntimeEnvironment,
) -> BuslaneRuntimeEnvironment {
  { parent: Some(self), values: @immut_sorted_map.new() }
}

///|
/// Binds a Buslane value identity in this runtime environment frame.
fn BuslaneRuntimeEnvironment::bind(
  self : BuslaneRuntimeEnvironment,
  id : @buslane.ValueId,
  value : BuslaneRuntimeValue,
) -> Unit {
  self.values = self.values.add(id, value)
}

///|
/// Looks up a value identity, searching outward through parent frames.
fn BuslaneRuntimeEnvironment::lookup(
  self : BuslaneRuntimeEnvironment,
  id : @buslane.ValueId,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  if self.values.get(id) is Some(value) {
    return value
  }
  if self.parent is Some(parent) {
    return parent.lookup(id)
  }
  raise UnboundValue(id)
}

///|
/// Looks up a global value in a runtime program.
pub fn BuslaneRuntimeProgram::lookup(
  self : BuslaneRuntimeProgram,
  id : @buslane.ValueId,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  self.globals.lookup(id)
}
