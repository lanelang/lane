///|
priv struct ObservedAnfFunction {
  function : @anf.AnfFunctionId
  source : @buslane.ValueId?
  origin : @function_origin.FunctionOrigin
  disposition : ExploreFunctionRole
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
  { names: [], nodes: [], edges: [], }
}

///|
fn ExploreFunctionGraphBuilder::finish(
  self : ExploreFunctionGraphBuilder,
) -> ExploreFunctionGraph {
  { nodes: self.nodes, edges: self.edges, }
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
fn ExploreFunctionGraphBuilder::semantic_role(
  self : ExploreFunctionGraphBuilder,
  source : @buslane.ValueId?,
  origin : @function_origin.FunctionOrigin,
) -> ExploreFunctionRole {
  match origin {
    SourceWritten =>
      match source {
        Some(value) =>
          SourceFunction(value=value.index, name=self.source_name(value))
        None => SourceAnonymousFunction
      }
    HandlerElaboration => HandlerElaborationFunction
    MonadicTransformation => MonadicTransformationFunction
    SelectiveCps => SelectiveCpsFunction
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
      function: { stage: Anf, index: function.function.value, },
      roles: [
        self.semantic_role(function.source, function.origin),
        function.disposition,
      ],
    })
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_vmcfg(
  self : ExploreFunctionGraphBuilder,
  functions : Array[@physical_lowering.PhysicalFunctionProvenance],
) -> Unit {
  for function in functions {
    let target : ExploreFunctionRef = {
      stage: VmcfgInitial,
      index: function.function.value,
    }
    let roles = []
    for origin in function.origins {
      roles.append(self.physical_roles(origin))
      if origin.anf_function() is Some(anf_function) {
        self.edges.push({
          source: { stage: Anf, index: anf_function.value, },
          target,
        })
      }
    }
    self.nodes.push({ function: target, roles, })
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_physical(
  self : ExploreFunctionGraphBuilder,
  functions : Array[@physical_lowering.PhysicalFunctionProvenance],
) -> Unit {
  for function in functions {
    let index = function.function.value
    let roles = []
    for origin in function.origins {
      roles.append(self.physical_roles(origin))
    }
    self.nodes.push({ function: { stage: PhysicalProgram, index, }, roles, })
    self.edges.push({
      source: { stage: VmcfgInitial, index, },
      target: { stage: PhysicalProgram, index, },
    })
  }
}

///|
fn @physical_lowering.PhysicalFunctionOrigin::anf_function(
  self : @physical_lowering.PhysicalFunctionOrigin,
) -> @anf.AnfFunctionId? {
  match self {
    TopLevelFunction(function~, ..)
    | LiftedFunction(function~, ..)
    | LiftedRecursiveFunction(function~, ..)
    | RepresentationWorker(function~, ..) => Some(function)
    _ => None
  }
}

///|
fn ExploreFunctionGraphBuilder::physical_roles(
  self : ExploreFunctionGraphBuilder,
  origin : @physical_lowering.PhysicalFunctionOrigin,
) -> Array[ExploreFunctionRole] {
  match origin {
    TopLevelFunction(source~, origin~, ..)
    | LiftedFunction(source~, origin~, ..)
    | LiftedRecursiveFunction(source~, origin~, ..) =>
      [self.semantic_role(source, origin)]
    RepresentationWorker(source~, origin~, ..) =>
      [self.semantic_role(source, origin), RepresentationWorker]
    Initializer(source~) =>
      [Initializer(value=source.index, name=self.source_name(source))]
    InitializerOrchestrator => [InitializerOrchestrator]
    IntrinsicWrapper(name~) => [IntrinsicWrapper(name~)]
    CallableAdapter(contract~, reason~) => [CallableAdapter(contract~, reason~)]
    LayoutConstructor => [LayoutConstructor]
    RuntimeImport(source~, module_name~, field_name~) =>
      [
        RuntimeImport(
          value=source.index,
          name=self.source_name(source),
          module_name~,
          field_name~,
        ),
      ]
  }
}

///|
fn ExploreFunctionGraphBuilder::observe_wasm(
  self : ExploreFunctionGraphBuilder,
  functions : Array[@wasm_compiler.WasmFunctionProvenance],
) -> Unit {
  for function in functions {
    let target : ExploreFunctionRef = { stage: Wasm, index: function.index, }
    self.nodes.push({ function: target, roles: [wasm_role(function.origin)], })
    if function.origin.physical_function() is Some(physical_function) {
      self.edges.push({
        source: { stage: PhysicalProgram, index: physical_function.value, },
        target,
      })
    }
  }
}

///|
fn @wasm_compiler.WasmFunctionOrigin::physical_function(
  self : @wasm_compiler.WasmFunctionOrigin,
) -> @physical.FunctionId? {
  match self {
    PhysicalRuntimeImport(function~, ..)
    | PhysicalFunction(function~)
    | RuntimeImportAdapter(function~, ..) => Some(function)
    _ => None
  }
}

///|
fn wasm_role(origin : @wasm_compiler.WasmFunctionOrigin) -> ExploreFunctionRole {
  match origin {
    InternalRuntimeImport(function) =>
      InternalRuntimeImport(name=function.name())
    WasiPreview1Import(import_) => {
      let contract = import_.contract()
      WasiPreview1Import(
        module_name=contract.module_name,
        field_name=contract.field_name,
      )
    }
    PhysicalRuntimeImport(module_name~, field_name~, ..) =>
      PhysicalRuntimeImport(module_name~, field_name~)
    PhysicalFunction(_) => WasmPhysicalFunction
    RuntimeImportAdapter(module_name~, field_name~, ..) =>
      RuntimeImportAdapter(module_name~, field_name~)
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
    CallableAbiGuard =>
      WasmHelperFunction(name="callable ABI guard", ordinal=None)
    NoopErased => WasmHelperFunction(name="noop erased", ordinal=None)
    RetainReferenceErased =>
      WasmHelperFunction(name="retain reference erased", ordinal=None)
    ReleaseReferenceErased =>
      WasmHelperFunction(name="release reference erased", ordinal=None)
    RetainCallable => WasmHelperFunction(name="retain callable", ordinal=None)
    ReleaseCallable => WasmHelperFunction(name="release callable", ordinal=None)
    DestroyNoop => WasmHelperFunction(name="destroy noop", ordinal=None)
    DestroyShape(shape~) =>
      WasmHelperFunction(name="destroy shape", ordinal=Some(shape))
    ByteSequenceSizer =>
      WasmHelperFunction(name="byte sequence sizer", ordinal=None)
  }
}
