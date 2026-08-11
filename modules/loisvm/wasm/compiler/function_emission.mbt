///|
pub(all) enum WasmRuntimeFunctionRole {
  Allocate
  Free
  RetainReference
  ReleaseReference
  ByteSequenceNew
  RequireByteSequenceLayout
  ByteSequenceEqual
  ByteSequenceConcat
  ByteSequenceSlice
  HostObjectNew
  ByteSequenceMake
  ByteSequenceIndex
  ByteSequenceGet
  ByteSequenceSet
  ByteSequenceIsValidUtf8
  InstanceGlobalCleanup
} derive(Debug, Eq)

///|
pub(all) enum WasmHelperFunctionRole {
  NoopErased
  RetainReferenceErased
  ReleaseReferenceErased
  RetainCallable
  ReleaseCallable
  DestroyNoop
  DestroyHostObject
  DestroyShape(shape~ : Int)
  ByteSequenceSizer
} derive(Debug, Eq)

///|
pub(all) enum WasmFunctionOrigin {
  InternalRuntimeImport(@internal_abi.InternalRuntimeFunction)
  PhysicalRuntimeImport(function~ : @bytecode.FunctionId, symbol~ : String)
  BytecodeFunction(function~ : @bytecode.FunctionId)
  RuntimeImportAdapter(function~ : @bytecode.FunctionId, symbol~ : String)
  RuntimeFunction(WasmRuntimeFunctionRole)
  HelperFunction(WasmHelperFunctionRole)
  EntryWrapper
} derive(Debug, Eq)

///|
pub(all) struct WasmFunctionProvenance {
  index : Int
  origin : WasmFunctionOrigin
} derive(Debug, Eq)

///|
pub(all) struct WasmCompileObservation {
  module_ : @wasm_types.Module
  functions : Array[WasmFunctionProvenance]
} derive(Debug)

///|
priv struct WasmFunctionEmitter {
  module_ : @wasm_types.Module
  functions : Array[WasmFunctionProvenance]
}

///|
fn WasmFunctionEmitter::new(
  module_ : @wasm_types.Module,
) -> WasmFunctionEmitter {
  { module_, functions: [] }
}

///|
fn WasmFunctionEmitter::append_import(
  self : WasmFunctionEmitter,
  module_name : String,
  name : String,
  type_index : Int,
  origin : WasmFunctionOrigin,
) -> Int {
  let index = self.functions.length()
  self.module_.imports.push({
    mod_name: module_name,
    name,
    desc: Func(type_index),
  })
  self.functions.push({ index, origin })
  index
}

///|
fn WasmFunctionEmitter::append_defined(
  self : WasmFunctionEmitter,
  type_index : Int,
  code : @wasm_types.FunctionCode,
  origin : WasmFunctionOrigin,
) -> Int {
  let index = self.functions.length()
  self.module_.funcs.push(type_index)
  self.module_.codes.push(code)
  self.functions.push({ index, origin })
  index
}
