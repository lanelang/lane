///|
using @symbol {
  type FieldSymbolId,
  type TypeSymbolId,
  type ValueSymbolId,
  type VariantSymbolId,
}

///|
pub(all) enum RuntimeValue {
  Int(Int64)
  Bool(Bool)
  String(String)
  Unit
  Struct(symbol~ : TypeSymbolId, fields~ : Array[RuntimeStructField])
  Variant(symbol~ : VariantSymbolId, arguments~ : Array[RuntimeValue])
  Closure(
    function~ : @anf.AnfFunctionDeclaration,
    environment~ : RuntimeEnvironment
  )
  FunctionAtom(function~ : @anf.AnfAtom, environment~ : RuntimeEnvironment)
} derive(Debug, Eq)

///|
pub(all) struct RuntimeStructField {
  symbol : FieldSymbolId
  name : String
  value : RuntimeValue
} derive(Debug, Eq)

///|
struct RuntimeBinding {
  symbol : ValueSymbolId
  value : RuntimeValue
} derive(Debug, Eq)

///|
struct RuntimeTempBinding {
  temp : @anf.AnfTempId
  value : RuntimeValue
} derive(Debug, Eq)

///|
pub struct RuntimeEnvironment {
  values : Array[RuntimeBinding]
  temps : Array[RuntimeTempBinding]
} derive(Debug, Eq)

///|
pub struct RuntimeCallFrame {
  locals : RuntimeEnvironment
} derive(Debug, Eq)

///|
pub struct RuntimeProgram {
  globals : RuntimeEnvironment
} derive(Debug, Eq)

///|
#warnings("-unused_constructor")
pub suberror RuntimeError {
  UnboundValue(ValueSymbolId)
  UnboundTemp(@anf.AnfTempId)
  MissingBuiltin(name~ : String, type_~ : @types.Type)
  BuiltinFailure(name~ : String, message~ : String)
  InvalidRuntimeValue(message~ : String)
} derive(Debug, Eq)

///|
pub type BuiltinHandler = (String, @types.Type, Array[RuntimeValue]) -> RuntimeValue raise RuntimeError

///|
pub struct BuiltinRuntime {
  handlers : Array[BuiltinHandler]
}

///|
/// Creates an empty runtime environment.
pub fn RuntimeEnvironment::RuntimeEnvironment() -> RuntimeEnvironment {
  { values: [], temps: [] }
}

///|
/// Creates a runtime call frame with its local environment.
pub fn RuntimeCallFrame::RuntimeCallFrame(
  locals : RuntimeEnvironment,
) -> RuntimeCallFrame {
  { locals, }
}

///|
/// Creates a runtime program with its global environment.
pub fn RuntimeProgram::RuntimeProgram(
  globals : RuntimeEnvironment,
) -> RuntimeProgram {
  { globals, }
}

///|
/// Looks up a global value symbol in this runtime program.
pub fn RuntimeProgram::lookup_value(
  self : RuntimeProgram,
  symbol : ValueSymbolId,
) -> RuntimeValue raise RuntimeError {
  self.globals.lookup_value(symbol)
}

///|
/// Returns a copy of this runtime environment.
pub fn RuntimeEnvironment::copy(
  self : RuntimeEnvironment,
) -> RuntimeEnvironment {
  { values: self.values.copy(), temps: self.temps.copy() }
}

///|
/// Binds a value symbol in this runtime environment.
pub fn RuntimeEnvironment::bind_value(
  self : RuntimeEnvironment,
  symbol : ValueSymbolId,
  value : RuntimeValue,
) -> Unit {
  self.values.push({ symbol, value })
}

///|
/// Binds an ANF temporary in this runtime environment.
pub fn RuntimeEnvironment::bind_temp(
  self : RuntimeEnvironment,
  temp : @anf.AnfTempId,
  value : RuntimeValue,
) -> Unit {
  self.temps.push({ temp, value })
}

///|
/// Looks up a value symbol, preferring the latest local binding.
pub fn RuntimeEnvironment::lookup_value(
  self : RuntimeEnvironment,
  symbol : ValueSymbolId,
) -> RuntimeValue raise RuntimeError {
  for index = self.values.length() - 1; index >= 0; index = index - 1 {
    let binding = self.values[index]
    if binding.symbol == symbol {
      return binding.value
    }
  }
  raise UnboundValue(symbol)
}

///|
/// Looks up an ANF temporary, preferring the latest local binding.
pub fn RuntimeEnvironment::lookup_temp(
  self : RuntimeEnvironment,
  temp : @anf.AnfTempId,
) -> RuntimeValue raise RuntimeError {
  for index = self.temps.length() - 1; index >= 0; index = index - 1 {
    let binding = self.temps[index]
    if binding.temp == temp {
      return binding.value
    }
  }
  raise UnboundTemp(temp)
}

///|
/// Creates a builtin runtime with no handlers.
pub fn BuiltinRuntime::BuiltinRuntime() -> BuiltinRuntime {
  { handlers: [] }
}

///|
/// Adds a builtin handler. Handlers are tried in insertion order.
pub fn BuiltinRuntime::add_handler(
  self : BuiltinRuntime,
  handler : BuiltinHandler,
) -> Unit {
  self.handlers.push(handler)
}

///|
/// Invokes the first builtin handler that accepts the intrinsic.
pub fn BuiltinRuntime::invoke(
  self : BuiltinRuntime,
  name : String,
  type_ : @types.Type,
  arguments : Array[RuntimeValue],
) -> RuntimeValue raise RuntimeError {
  for handler in self.handlers {
    try {
      return handler(name, type_, arguments)
    } catch {
      MissingBuiltin(..) => ()
      error => raise error
    }
  }
  raise MissingBuiltin(name~, type_~)
}
