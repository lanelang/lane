///|
priv struct ObservedAnfFunction {
  function : @anf.AnfFunctionId
  source : @buslane.ValueId?
}

///|
priv struct AnfStageObservation {
  scale : ExploreScaleObservation
  functions : Array[ObservedAnfFunction]
}

///|
priv struct ExploreFunctionGraphBuilder {
  names : Array[String]
  nodes : Array[ExploreFunctionNode]
  edges : Array[ExploreFunctionEdge]
}

///|
fn ExploreFunctionGraphBuilder::new() -> ExploreFunctionGraphBuilder {
  { names: [], nodes: [], edges: [] }
}

///|
fn ExploreFunctionGraphBuilder::finish(
  self : ExploreFunctionGraphBuilder,
) -> ExploreFunctionGraph {
  { nodes: self.nodes, edges: self.edges }
}

///|
fn ExploreFunctionGraphBuilder::source_name(
  self : ExploreFunctionGraphBuilder,
  value : @buslane.ValueId,
) -> String? {
  if value.index >= 0 && value.index < self.names.length() {
    Some(self.names[value.index])
  } else {
    None
  }
}

///|
fn ExploreFunctionGraphBuilder::source_role(
  self : ExploreFunctionGraphBuilder,
  source : @buslane.ValueId?,
) -> ExploreFunctionRole {
  match source {
    Some(value) =>
      SourceFunction(value=value.index, name=self.source_name(value))
    None => AnonymousFunction
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_anf(
  self : ExploreFunctionGraphBuilder,
  metadata : @buslane.MetadataRegistry,
  functions : Array[ObservedAnfFunction],
) -> Unit {
  self.names.clear()
  for info in metadata.values {
    self.names.push(info.name.occurrence)
  }
  for function in functions {
    self.nodes.push({
      function: { stage: Anf, index: function.function.value },
      roles: [self.source_role(function.source)],
    })
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_vmcfg(
  self : ExploreFunctionGraphBuilder,
  functions : Array[@loisvm_lowering.LoisvmFunctionProvenance],
) -> Unit {
  for function in functions {
    let target : ExploreFunctionRef = {
      stage: VmcfgInitial,
      index: function.function.value,
    }
    let roles = []
    for origin in function.origins {
      roles.push(self.loisvm_role(origin))
      if origin.anf_function() is Some(anf_function) {
        self.edges.push({
          source: { stage: Anf, index: anf_function.value },
          target,
        })
      }
    }
    self.nodes.push({ function: target, roles })
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_bytecode(
  self : ExploreFunctionGraphBuilder,
  functions : Array[@loisvm_lowering.LoisvmFunctionProvenance],
) -> Unit {
  for function in functions {
    let index = function.function.value
    self.nodes.push({
      function: { stage: LoisvmBytecode, index },
      roles: function.origins.map(origin => self.loisvm_role(origin)),
    })
    self.edges.push({
      source: { stage: VmcfgInitial, index },
      target: { stage: LoisvmBytecode, index },
    })
  }
}

///|
fn @loisvm_lowering.LoisvmFunctionOrigin::anf_function(
  self : @loisvm_lowering.LoisvmFunctionOrigin,
) -> @anf.AnfFunctionId? {
  match self {
    TopLevelFunction(function~, ..)
    | LiftedFunction(function~, ..)
    | LiftedRecursiveFunction(function~, ..)
    | RepresentationSpecialization(function~, ..) => Some(function)
    _ => None
  }
}

///|
fn ExploreFunctionGraphBuilder::loisvm_role(
  self : ExploreFunctionGraphBuilder,
  origin : @loisvm_lowering.LoisvmFunctionOrigin,
) -> ExploreFunctionRole {
  match origin {
    TopLevelFunction(source~, ..)
    | LiftedFunction(source~, ..)
    | LiftedRecursiveFunction(source~, ..) => self.source_role(source)
    Initializer(source~) =>
      Initializer(value=source.index, name=self.source_name(source))
    InitializerOrchestrator => InitializerOrchestrator
    IntrinsicWrapper(name~) => IntrinsicWrapper(name~)
    CallableAdapter => CallableAdapter
    RepresentationSpecialization(source~, ..) =>
      match source {
        Some(source) =>
          RepresentationWorker(
            value=Some(source.index),
            name=self.source_name(source),
          )
        None => RepresentationWorker(value=None, name=None)
      }
    LayoutConstructor => LayoutConstructor
    RuntimeImport(source~, symbol~) =>
      RuntimeImport(value=source.index, name=self.source_name(source), symbol~)
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_wasm(
  self : ExploreFunctionGraphBuilder,
  functions : Array[@wasm_compiler.WasmFunctionProvenance],
) -> Unit {
  for function in functions {
    let target : ExploreFunctionRef = { stage: Wasm, index: function.index }
    self.nodes.push({ function: target, roles: [wasm_role(function.origin)] })
    if function.origin.bytecode_function() is Some(bytecode_function) {
      self.edges.push({
        source: { stage: LoisvmBytecode, index: bytecode_function.value },
        target,
      })
    }
  }
}

///|
fn @wasm_compiler.WasmFunctionOrigin::bytecode_function(
  self : @wasm_compiler.WasmFunctionOrigin,
) -> @bytecode.FunctionId? {
  match self {
    PhysicalRuntimeImport(function~, ..)
    | BytecodeFunction(function~)
    | RuntimeImportAdapter(function~, ..) => Some(function)
    _ => None
  }
}

///|
fn wasm_role(origin : @wasm_compiler.WasmFunctionOrigin) -> ExploreFunctionRole {
  match origin {
    InternalRuntimeImport(function) =>
      InternalRuntimeImport(name=function.name())
    PhysicalRuntimeImport(symbol~, ..) => PhysicalRuntimeImport(symbol~)
    BytecodeFunction(_) => WasmBytecodeFunction
    RuntimeImportAdapter(symbol~, ..) => RuntimeImportAdapter(symbol~)
    RuntimeFunction(role) => WasmRuntimeFunction(name=wasm_runtime_name(role))
    HelperFunction(role) => wasm_helper_role(role)
    EntryWrapper => EntryWrapper
  }
}

///|
fn wasm_runtime_name(role : @wasm_compiler.WasmRuntimeFunctionRole) -> String {
  match role {
    Allocate => "allocate"
    Free => "free"
    RetainReference => "retain reference"
    ReleaseReference => "release reference"
    ByteSequenceNew => "byte sequence new"
    RequireByteSequenceLayout => "require byte sequence layout"
    ByteSequenceEqual => "byte sequence equal"
    ByteSequenceConcat => "byte sequence concat"
    ByteSequenceSlice => "byte sequence slice"
    HostObjectNew => "host object new"
    ByteSequenceMake => "byte sequence make"
    ByteSequenceIndex => "byte sequence index"
    ByteSequenceGet => "byte sequence get"
    ByteSequenceSet => "byte sequence set"
    ByteSequenceIsValidUtf8 => "byte sequence is valid UTF-8"
    InstanceGlobalCleanup => "instance global cleanup"
  }
}

///|
fn wasm_helper_role(
  role : @wasm_compiler.WasmHelperFunctionRole,
) -> ExploreFunctionRole {
  match role {
    NoopErased => WasmHelperFunction(name="noop erased", ordinal=None)
    RetainReferenceErased =>
      WasmHelperFunction(name="retain reference erased", ordinal=None)
    ReleaseReferenceErased =>
      WasmHelperFunction(name="release reference erased", ordinal=None)
    RetainCallable => WasmHelperFunction(name="retain callable", ordinal=None)
    ReleaseCallable => WasmHelperFunction(name="release callable", ordinal=None)
    DestroyNoop => WasmHelperFunction(name="destroy noop", ordinal=None)
    DestroyHostObject =>
      WasmHelperFunction(name="destroy host object", ordinal=None)
    DestroyShape(shape~) =>
      WasmHelperFunction(name="destroy shape", ordinal=Some(shape))
    ByteSequenceSizer =>
      WasmHelperFunction(name="byte sequence sizer", ordinal=None)
  }
}
