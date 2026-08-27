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
  CallableAbiGuard
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
  PhysicalRuntimeImport(function~ : @physical.FunctionId, symbol~ : String)
  PhysicalFunction(function~ : @physical.FunctionId)
  RuntimeImportAdapter(function~ : @physical.FunctionId, symbol~ : String)
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
  scale : WasmModuleScale
} derive(Debug)

///|
priv struct WasmFunctionEmitter {
  module_ : @wasm_types.Module
  record_scale : Bool
  function_scales : Array[WasmFunctionScale]
  mut imported_function_count : Int
  mut emitted_function_count : Int
}

///|
fn WasmFunctionEmitter::new(
  module_ : @wasm_types.Module,
  record_scale : Bool,
) -> WasmFunctionEmitter {
  {
    module_,
    record_scale,
    function_scales: [],
    imported_function_count: 0,
    emitted_function_count: 0,
  }
}

///|
fn WasmFunctionEmitter::append_import(
  self : WasmFunctionEmitter,
  entry : WasmFunctionCatalogEntry,
) -> Unit raise WasmCompileError {
  guard entry.declaration is Import(module_name~, name~) else {
    raise InvalidFunctionCatalog(detail="catalog definition emitted as import")
  }
  if entry.handle.index != self.emitted_function_count {
    raise InvalidFunctionCatalog(
      detail="function emission order differs from catalog",
    )
  }
  self.module_.imports.push({
    mod_name: module_name,
    name,
    desc: Func(entry.type_index),
  })
  self.imported_function_count += 1
  self.emitted_function_count += 1
}

///|
fn WasmFunctionEmitter::append_defined(
  self : WasmFunctionEmitter,
  entry : WasmFunctionCatalogEntry,
  code : @wasm_types.FunctionCode,
  expansions : Array[WasmExpansionScale],
) -> Unit raise WasmCompileError {
  if entry.declaration is Import(_) {
    raise InvalidFunctionCatalog(detail="catalog import emitted as definition")
  }
  if entry.handle.index != self.emitted_function_count {
    raise InvalidFunctionCatalog(
      detail="function emission order differs from catalog",
    )
  }
  self.module_.funcs.push(entry.type_index)
  self.module_.codes.push(code)
  let instruction_count = wasm_instruction_array_size(code.body)
  let local_count = code.locals.length()
  if expansions.fold(init=0, fn(total, expansion) {
      total + expansion.instruction_count
    }) !=
    instruction_count ||
    expansions.fold(init=0, fn(total, expansion) {
      total + expansion.local_count
    }) !=
    local_count {
    raise InvalidFunctionCatalog(
      detail="Wasm expansion accounting does not cover the emitted function",
    )
  }
  if self.record_scale {
    self.function_scales.push({
      index: entry.handle.index,
      instruction_count,
      local_count,
      expansions,
    })
  }
  self.emitted_function_count += 1
}
