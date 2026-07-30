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
  LoisvmBytecode
  Wat
} derive(Debug, Eq)

///|
pub(all) enum ExploreStageId {
  Syntax
  Resolved
  Checked
  BuslaneModule
  BuslaneLinked
  BuslaneEffectSpecialized
  BuslaneHandlersElaborated
  BuslaneMonadic
  BuslaneSelectiveCps
  BuslaneOpenContextResolved
  BuslaneMonadicLifted
  BuslaneCoreOptimized
  BuslaneEffectsErased
  Executable
  Anf
  VmcfgInitial
  LoisvmBytecode
  Wasm
} derive(Debug, Eq)

///|
pub(all) struct ExploreSnapshot {
  domain : ExploreStageDomain
  text_format : ExploreTextFormat
  text : String
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)

///|
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
pub(all) struct ExploreStages {
  syntax : ExploreStageState
  resolved : ExploreStageState
  checked : ExploreStageState
  buslane_module : ExploreStageState
  buslane_linked : ExploreStageState
  buslane_effect_specialized : ExploreStageState
  buslane_handlers_elaborated : ExploreStageState
  buslane_monadic : ExploreStageState
  buslane_selective_cps : ExploreStageState
  buslane_open_context_resolved : ExploreStageState
  buslane_monadic_lifted : ExploreStageState
  buslane_core_optimized : ExploreStageState
  buslane_effects_erased : ExploreStageState
  executable : ExploreStageState
  anf : ExploreStageState
  vmcfg_initial : ExploreStageState
  loisvm_bytecode : ExploreStageState
  wasm : ExploreStageState
} derive(Debug, Eq)

///|
pub(all) struct ExploreRequest {
  root_source : @module_frontend.SourceInput
  library_sources : Array[@module_frontend.SourceInput]
  entry : String
} derive(Debug, Eq)

///|
pub(all) struct EntrySummary {
  module_path_text : String
  name : String
  type_text : String
} derive(Debug, Eq)

///|
pub(all) struct ExploreReport {
  schema_version : Int
  compiler : ExploreCompilerIdentity
  root : ExploreRootIdentity
  selected_entry : EntrySummary?
  status : ExploreStatus
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  stages : ExploreStages
} derive(Debug, Eq)

///|
pub(all) struct EntryReport {
  schema_version : Int
  entries : Array[EntrySummary]
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub fn ExploreStages::ordered(self : ExploreStages) -> Array[ExploreStage] {
  [
    explore_stage(Syntax, self.syntax),
    explore_stage(Resolved, self.resolved),
    explore_stage(Checked, self.checked),
    explore_stage(BuslaneModule, self.buslane_module),
    explore_stage(BuslaneLinked, self.buslane_linked),
    explore_stage(BuslaneEffectSpecialized, self.buslane_effect_specialized),
    explore_stage(BuslaneHandlersElaborated, self.buslane_handlers_elaborated),
    explore_stage(BuslaneMonadic, self.buslane_monadic),
    explore_stage(BuslaneSelectiveCps, self.buslane_selective_cps),
    explore_stage(
      BuslaneOpenContextResolved,
      self.buslane_open_context_resolved,
    ),
    explore_stage(BuslaneMonadicLifted, self.buslane_monadic_lifted),
    explore_stage(BuslaneCoreOptimized, self.buslane_core_optimized),
    explore_stage(BuslaneEffectsErased, self.buslane_effects_erased),
    explore_stage(Executable, self.executable),
    explore_stage(Anf, self.anf),
    explore_stage(VmcfgInitial, self.vmcfg_initial),
    explore_stage(LoisvmBytecode, self.loisvm_bytecode),
    explore_stage(Wasm, self.wasm),
  ]
}

///|
fn explore_stage(
  id : ExploreStageId,
  state : ExploreStageState,
) -> ExploreStage {
  { id: id.key(), title: id.title(), state }
}

///|
pub fn ExploreStageId::key(self : ExploreStageId) -> String {
  match self {
    Syntax => "syntax"
    Resolved => "resolved"
    Checked => "checked"
    BuslaneModule => "buslane.module"
    BuslaneLinked => "buslane.linked"
    BuslaneEffectSpecialized => "buslane.effect-specialized"
    BuslaneHandlersElaborated => "buslane.handlers-elaborated"
    BuslaneMonadic => "buslane.monadic"
    BuslaneSelectiveCps => "buslane.selective-cps"
    BuslaneOpenContextResolved => "buslane.open-context-resolved"
    BuslaneMonadicLifted => "buslane.monadic-lifted"
    BuslaneCoreOptimized => "buslane.core-optimized"
    BuslaneEffectsErased => "buslane.effects-erased"
    Executable => "executable"
    Anf => "anf"
    VmcfgInitial => "vmcfg.initial"
    LoisvmBytecode => "loisvm.bytecode"
    Wasm => "wasm"
  }
}

///|
fn ExploreStageId::title(self : ExploreStageId) -> String {
  match self {
    Syntax => "Syntax AST"
    Resolved => "Resolved AST"
    Checked => "Checked Source AST"
    BuslaneModule => "Buslane (Module Lowering)"
    BuslaneLinked => "Buslane (Linking)"
    BuslaneEffectSpecialized => "Buslane (Reachable Effect Specialization)"
    BuslaneHandlersElaborated => "Buslane (Handler Elaboration)"
    BuslaneMonadic => "Buslane (Monadic Transformation)"
    BuslaneSelectiveCps => "Buslane (Selective CPS)"
    BuslaneOpenContextResolved => "Buslane (Open Context Resolution)"
    BuslaneMonadicLifted => "Buslane (Monadic Lift)"
    BuslaneCoreOptimized => "Buslane (Effect-Aware Core Optimization)"
    BuslaneEffectsErased => "Buslane (Effect Erasure)"
    Executable => "Executable Program (Whole-Program Elaboration)"
    Anf => "ANF"
    VmcfgInitial => "VM CFG (Initial Lowering)"
    LoisvmBytecode => "LoisVM Bytecode (ARC and Slot Finalization)"
    Wasm => "Wasm (LoisVM Backend Lowering)"
  }
}

///|
fn ExploreStageId::index(self : ExploreStageId) -> Int {
  match self {
    Syntax => 0
    Resolved => 1
    Checked => 2
    BuslaneModule => 3
    BuslaneLinked => 4
    BuslaneEffectSpecialized => 5
    BuslaneHandlersElaborated => 6
    BuslaneMonadic => 7
    BuslaneSelectiveCps => 8
    BuslaneOpenContextResolved => 9
    BuslaneMonadicLifted => 10
    BuslaneCoreOptimized => 11
    BuslaneEffectsErased => 12
    Executable => 13
    Anf => 14
    VmcfgInitial => 15
    LoisvmBytecode => 16
    Wasm => 17
  }
}

///|
fn ExploreStageId::domain(self : ExploreStageId) -> ExploreStageDomain {
  match self {
    Wasm => Backend
    _ => Compiler
  }
}

///|
fn ExploreStageId::text_format(self : ExploreStageId) -> ExploreTextFormat {
  match self {
    Syntax => Lane
    Resolved => ResolvedLane
    Checked => CheckedLane
    BuslaneModule
    | BuslaneLinked
    | BuslaneEffectSpecialized
    | BuslaneMonadicLifted
    | BuslaneCoreOptimized
    | BuslaneEffectsErased
    | Executable => Buslane
    BuslaneHandlersElaborated
    | BuslaneMonadic
    | BuslaneSelectiveCps
    | BuslaneOpenContextResolved => EffectLowering
    Anf => Anf
    VmcfgInitial => Vmcfg
    LoisvmBytecode => LoisvmBytecode
    Wasm => Wat
  }
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
    LoisvmBytecode => "loisvm-bytecode"
    Wat => "wat"
  }
}
