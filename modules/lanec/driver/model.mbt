///|
pub(all) struct ExploreCompilerIdentity {
  name : String
  version : String
} derive(Debug, Eq)

///|
pub(all) struct ExploreRootIdentity {
  source_id : String
  module_path_text : String?
} derive(Debug, Eq)

///|
/// Stable machine-readable outcome of an exploration request. `Failed(id)`
/// names the first stage that did not complete.
pub(all) enum ExploreStatus {
  Succeeded
  Failed(ExploreStageId)
} derive(Debug, Eq)

///|
pub(all) enum ExploreStageDomain {
  Compiler
  Backend
} derive(Debug, Eq)

///|
pub(all) enum ExploreTextFormat {
  Lane
  ResolvedLane
  CheckedLane
  Buslane
  EffectLowering
  Anf
  Vmcfg
  PhysicalProgram
  Wat
} derive(Debug, Eq)

///|
/// Stable structural quantities reported by Explore. Each identifier has one
/// meaning across every stage that emits it; stages omit identifiers that do
/// not apply to their IR.
pub(all) enum ExploreMetricId {
  DeclarationCount
  TopTermCount
  FunctionCount
  ImportCount
  NodeCount
  SourceGenericBinderCount
  GenericBinderCount
  SourceTypeApplicationCount
  TypeApplicationCount
  BlockCount
  InstructionCount
  CallCount
  ExternalCount
  ValueCount
  SlotCount
  DirectCallCount
  IndirectCallCount
  FunctionReferenceCount
  ClosureCount
  EnvironmentCount
  CallableAbiCount
  GlobalCount
  LayoutCount
  ObjectShapeCount
  ConstantCount
  EraseCount
  UneraseCount
  RetainCount
  ReleaseCount
  LocalCount
  TableEntryCount
} derive(Debug, Eq)

///|
pub(all) struct ExploreMetric {
  id : ExploreMetricId
  value : Int
} derive(Debug, Eq)

///|
/// A stage-local function size observation. `index` is the function identity
/// assigned by the observed IR owner and names a node in the report provenance
/// graph. Stages without owner-assigned function identities omit these
/// observations and publish aggregate metrics only.
pub(all) struct ExploreFunctionScale {
  index : Int
  block_count : Int
  operation_count : Int
  value_count : Int
} derive(Debug, Eq)

///|
pub(all) struct ExploreScaleObservation {
  metrics : Array[ExploreMetric]
  functions : Array[ExploreFunctionScale]
  modules : Array[ExploreModuleScale]
} derive(Debug, Eq)

///|
/// Linker-owned contribution of one source module to a whole-program stage.
pub(all) struct ExploreModuleScale {
  module_path_text : String
  input_top_terms : Int
  retained_top_terms : Int
  input_value_bindings : Int
  retained_value_bindings : Int
} derive(Debug, Eq)

///|
pub(all) struct ExploreFunctionRef {
  stage : ExploreStageId
  index : Int
} derive(Debug, Eq)

///|
pub(all) enum ExploreFunctionRole {
  SourceFunction(value~ : Int, name~ : String?)
  AnonymousFunction
  Initializer(value~ : Int, name~ : String?)
  InitializerOrchestrator
  IntrinsicWrapper(name~ : String)
  CallableAdapter
  LayoutConstructor
  RuntimeImport(value~ : Int, name~ : String?, symbol~ : String)
  InternalRuntimeImport(name~ : String)
  PhysicalRuntimeImport(symbol~ : String)
  WasmPhysicalFunction
  RuntimeImportAdapter(symbol~ : String)
  WasmRuntimeFunction(name~ : String)
  WasmHelperFunction(name~ : String, ordinal~ : Int?)
  EntryWrapper
} derive(Debug, Eq)

///|
pub(all) struct ExploreFunctionNode {
  function : ExploreFunctionRef
  roles : Array[ExploreFunctionRole]
} derive(Debug, Eq)

///|
pub(all) struct ExploreFunctionEdge {
  source : ExploreFunctionRef
  target : ExploreFunctionRef
} derive(Debug, Eq)

///|
pub(all) struct ExploreFunctionGraph {
  nodes : Array[ExploreFunctionNode]
  edges : Array[ExploreFunctionEdge]
} derive(Debug, Eq)

///|
/// Current Explore Report Protocol schema owned by the compiler driver.
pub let explore_report_schema_version : Int = 8

///|
/// Canonical total order of protocol stages. This order is also the execution
/// order and is independent of map or source-pool iteration order.
pub(all) enum ExploreStageId {
  Syntax
  Resolved
  Checked
  BuslaneModule
  BuslaneLinked
  BuslaneEffectSpecialized
  BuslaneCoreOptimized
  BuslaneHandlersElaborated
  BuslaneMonadic
  BuslaneSelectiveCps
  BuslaneOpenContextResolved
  BuslaneMonadicLifted
  BuslaneCpsCoreOptimized
  Executable
  Anf
  VmcfgInitial
  PhysicalProgram
  Wasm
} derive(Debug, Eq)

///|
/// A completed stage's immutable rendered observation and diagnostics.
pub(all) struct ExploreSnapshot {
  domain : ExploreStageDomain
  text_format : ExploreTextFormat
  text : String
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  scale : ExploreScaleObservation
} derive(Debug, Eq)

///|
/// State of one fixed protocol stage. `Failed` is used only for the first
/// failing stage; subsequent stages are `Unavailable`.
pub(all) enum ExploreStageState {
  Completed(ExploreSnapshot)
  Failed(Array[@compiler_diag.CompilerDiagnostic])
  Unavailable
} derive(Debug, Eq)

///|
pub(all) struct ExploreStage {
  id : String
  title : String
  state : ExploreStageState
} derive(Debug, Eq)

///|
pub struct ExploreStages {
  priv stages : Array[ExploreStage]
} derive(Debug, Eq)

///|
priv struct ExploreStageDescriptor {
  id : ExploreStageId
  key : String
  title : String
  domain : ExploreStageDomain
  text_format : ExploreTextFormat
}

///|
/// Input to the Explore Protocol. Library sources form an unordered import pool;
/// `entry` must uniquely select one linked artifact-defined entry, and the
/// embedding environment must state its execution admission policy explicitly.
pub(all) struct ExploreRequest {
  root_source : @module_frontend.SourceInput
  library_sources : Array[@module_frontend.SourceInput]
  entry : String
  execution_profile : @executable.ExecutionProfile
} derive(Debug, Eq)

///|
pub(all) struct EntrySummary {
  module_path_text : String
  name : String
  type_text : String
} derive(Debug, Eq)

///|
/// Versioned complete Explore Protocol response. Reports are deterministic for
/// equal requests and retain completed snapshots even when a later stage fails.
pub(all) struct ExploreReport {
  schema_version : Int
  compiler : ExploreCompilerIdentity
  root : ExploreRootIdentity
  selected_entry : EntrySummary?
  status : ExploreStatus
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  stages : ExploreStages
  functions : ExploreFunctionGraph
} derive(Debug, Eq)

///|
/// Versioned entry-discovery response. Diagnostics are complete and an error
/// response never exposes entries from a partial compilation.
pub(all) struct EntryReport {
  schema_version : Int
  entries : Array[EntrySummary]
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)

///|
/// Returns all 18 stages in canonical pipeline order, including unavailable and
/// failed states; callers need not reconstruct ordering from record fields.
pub fn ExploreStages::ordered(self : ExploreStages) -> Array[ExploreStage] {
  self.stages.copy()
}

///|
let explore_stage_catalog : Array[ExploreStageDescriptor] = [
  {
    id: Syntax,
    key: "syntax",
    title: "Syntax AST",
    domain: Compiler,
    text_format: Lane,
  },
  {
    id: Resolved,
    key: "resolved",
    title: "Resolved AST",
    domain: Compiler,
    text_format: ResolvedLane,
  },
  {
    id: Checked,
    key: "checked",
    title: "Checked Source AST",
    domain: Compiler,
    text_format: CheckedLane,
  },
  {
    id: BuslaneModule,
    key: "buslane.module",
    title: "Buslane (Module Lowering)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: BuslaneLinked,
    key: "buslane.linked",
    title: "Buslane (Linking)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: BuslaneEffectSpecialized,
    key: "buslane.effect-specialized",
    title: "Buslane (Reachable Effect Specialization)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: BuslaneCoreOptimized,
    key: "buslane.core-optimized",
    title: "Buslane (Effect-Aware Core Optimization)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: BuslaneHandlersElaborated,
    key: "buslane.handlers-elaborated",
    title: "Buslane (Handler Elaboration)",
    domain: Compiler,
    text_format: EffectLowering,
  },
  {
    id: BuslaneMonadic,
    key: "buslane.monadic",
    title: "Buslane (Monadic Transformation)",
    domain: Compiler,
    text_format: EffectLowering,
  },
  {
    id: BuslaneSelectiveCps,
    key: "buslane.selective-cps",
    title: "Buslane (Selective CPS)",
    domain: Compiler,
    text_format: EffectLowering,
  },
  {
    id: BuslaneOpenContextResolved,
    key: "buslane.open-context-resolved",
    title: "Buslane (Open Context Resolution)",
    domain: Compiler,
    text_format: EffectLowering,
  },
  {
    id: BuslaneMonadicLifted,
    key: "buslane.monadic-lifted",
    title: "Buslane (Monadic Lift)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: BuslaneCpsCoreOptimized,
    key: "buslane.cps-core-optimized",
    title: "Buslane (CPS Core Optimized)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: Executable,
    key: "executable",
    title: "Executable Program (Effect-Aware CPS Core)",
    domain: Compiler,
    text_format: Buslane,
  },
  {
    id: Anf,
    key: "anf",
    title: "Runtime ANF (Effect Projection)",
    domain: Compiler,
    text_format: Anf,
  },
  {
    id: VmcfgInitial,
    key: "vmcfg.initial",
    title: "VM CFG (Initial Lowering)",
    domain: Compiler,
    text_format: Vmcfg,
  },
  {
    id: PhysicalProgram,
    key: "physical",
    title: "Physical Program (ARC and Slot Finalization)",
    domain: Compiler,
    text_format: PhysicalProgram,
  },
  {
    id: Wasm,
    key: "wasm",
    title: "WebAssembly",
    domain: Backend,
    text_format: Wat,
  },
]

///|
fn ExploreStageId::descriptor(self : ExploreStageId) -> ExploreStageDescriptor {
  for descriptor in explore_stage_catalog {
    if descriptor.id == self {
      return descriptor
    }
  }
  abort("Explore stage catalog is incomplete")
}

///|
pub fn ExploreStageId::key(self : ExploreStageId) -> String {
  self.descriptor().key
}

///|
fn ExploreStageId::index(self : ExploreStageId) -> Int {
  for index, descriptor in explore_stage_catalog {
    if descriptor.id == self {
      return index
    }
  }
  abort("Explore stage catalog is incomplete")
}

///|
fn ExploreStageId::domain(self : ExploreStageId) -> ExploreStageDomain {
  self.descriptor().domain
}

///|
fn ExploreStageId::text_format(self : ExploreStageId) -> ExploreTextFormat {
  self.descriptor().text_format
}

///|
pub fn ExploreStageDomain::name(self : ExploreStageDomain) -> String {
  match self {
    Compiler => "compiler"
    Backend => "backend"
  }
}

///|
pub fn ExploreTextFormat::name(self : ExploreTextFormat) -> String {
  match self {
    Lane => "lane"
    ResolvedLane => "lane-resolved"
    CheckedLane => "lane-checked"
    Buslane => "buslane"
    EffectLowering => "buslane-effect-lowering"
    Anf => "anf"
    Vmcfg => "vmcfg"
    PhysicalProgram => "physical-program"
    Wat => "wat"
  }
}

///|
pub fn ExploreMetricId::key(self : ExploreMetricId) -> String {
  match self {
    DeclarationCount => "declarationCount"
    TopTermCount => "topTermCount"
    FunctionCount => "functionCount"
    ImportCount => "importCount"
    NodeCount => "nodeCount"
    SourceGenericBinderCount => "sourceGenericBinderCount"
    GenericBinderCount => "genericBinderCount"
    SourceTypeApplicationCount => "sourceTypeApplicationCount"
    TypeApplicationCount => "typeApplicationCount"
    BlockCount => "blockCount"
    InstructionCount => "instructionCount"
    CallCount => "callCount"
    ExternalCount => "externalCount"
    ValueCount => "valueCount"
    SlotCount => "slotCount"
    DirectCallCount => "directCallCount"
    IndirectCallCount => "indirectCallCount"
    FunctionReferenceCount => "functionReferenceCount"
    ClosureCount => "closureCount"
    EnvironmentCount => "environmentCount"
    CallableAbiCount => "callableAbiCount"
    GlobalCount => "globalCount"
    LayoutCount => "layoutCount"
    ObjectShapeCount => "objectShapeCount"
    ConstantCount => "constantCount"
    EraseCount => "eraseCount"
    UneraseCount => "uneraseCount"
    RetainCount => "retainCount"
    ReleaseCount => "releaseCount"
    LocalCount => "localCount"
    TableEntryCount => "tableEntryCount"
  }
}

///|
pub fn ExploreMetricId::title(self : ExploreMetricId) -> String {
  match self {
    DeclarationCount => "Declarations"
    TopTermCount => "Top terms"
    FunctionCount => "Functions"
    ImportCount => "Imports"
    NodeCount => "IR nodes"
    SourceGenericBinderCount => "Source generic binders"
    GenericBinderCount => "Runtime generic binders"
    SourceTypeApplicationCount => "Source type applications"
    TypeApplicationCount => "Runtime type applications"
    BlockCount => "Blocks"
    InstructionCount => "Instructions"
    CallCount => "Calls"
    ExternalCount => "Externals"
    ValueCount => "Virtual values"
    SlotCount => "Physical slots"
    DirectCallCount => "Direct calls"
    IndirectCallCount => "Indirect calls"
    FunctionReferenceCount => "Function references"
    ClosureCount => "Closures"
    EnvironmentCount => "Environments"
    CallableAbiCount => "Callable ABIs"
    GlobalCount => "Globals"
    LayoutCount => "Layouts"
    ObjectShapeCount => "Object shapes"
    ConstantCount => "Constants"
    EraseCount => "Erasures"
    UneraseCount => "Unerasures"
    RetainCount => "Retains"
    ReleaseCount => "Releases"
    LocalCount => "Wasm locals"
    TableEntryCount => "Table entries"
  }
}
