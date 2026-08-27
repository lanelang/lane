///|
pub(all) suberror PhysicalLoweringError {
  RuntimeAnfCompilerDefect(@anf.RuntimeAnfLoweringError)
  MissingValueMetadata(value~ : @buslane.ValueId)
  MissingDataConstructorMetadata(data_constructor~ : @buslane.DataConId)
  MissingExternal(value~ : @buslane.ValueId)
  MissingEntry(value~ : @buslane.ValueId)
  UnsupportedType(type_~ : @anf.RuntimeType)
  UnsupportedTopLevel(value~ : @buslane.ValueId)
  UnsupportedExpression(detail~ : String)
  UnsupportedGenericData(data_constructor~ : @buslane.DataConId)
  InvalidDataPayloadCount(
    data_constructor~ : @buslane.DataConId,
    expected~ : Int,
    actual~ : Int
  )
  InvalidTypeApplication(detail~ : String)
  UnsupportedIntrinsic(name~ : String)
  UnterminatedBlock(block~ : Int)
  VmcfgFinalizeError(@vmcfg.FinalizeError)
  FunctionProvenanceCompilerDefect(FunctionProvenanceError)
} derive(Debug, Eq)

///|
pub(all) suberror FunctionProvenanceError {
  OriginCountMismatch(functions~ : Int, origins~ : Int)
  InvalidSourceFunction(function~ : @physical.FunctionId)
  FinalizedFunctionCountMismatch(functions~ : Int, origins~ : Int)
} derive(Debug, Eq)

///|
priv enum GlobalValue {
  UnitValue
  Function(@physical.FunctionId, @anf.RuntimeType)
  Intrinsic(RuntimeIntrinsicFunctionContract)
  FloatConstant(Int, @anf.RuntimeType)
  DoubleConstant(Int64, @anf.RuntimeType)
  InstanceGlobal(@physical.GlobalId, @anf.RuntimeType)
}

///|
priv struct RuntimeIntrinsicFunctionContract {
  intrinsic : @abi.Intrinsic
  parameters : Array[@anf.RuntimeType]
  result : @anf.RuntimeType
  implementation : @abi.IntrinsicFunctionImplementation
} derive(Eq)

///|
fn RuntimeIntrinsicFunctionContract::type_(
  self : RuntimeIntrinsicFunctionContract,
) -> @anf.RuntimeType {
  Callable(self.parameters, self.result)
}

///|
priv struct GlobalBinding {
  value : @buslane.ValueId
  lowered : GlobalValue
}

///|
priv enum PlannedEntry {
  Function(@buslane.ValueId, @anf.AnfFunction)
  InitializerStep(InitializerStepPlan)
  InitializerOrchestrator(Array[InitializerStepPlan])
  LiftedFunction(LiftedFunctionPlan)
  IntrinsicWrapper(IntrinsicWrapperPlan)
  RepresentationWorker(RepresentationWorkerPlan)
  CallableAdapter(CallableAdapterPlan)
  LayoutConstructor(LayoutConstructorPlan)
  RuntimeImport(@lane_runtime.RuntimeImport)
}

///|
pub(all) enum PhysicalFunctionOrigin {
  TopLevelFunction(
    function~ : @anf.AnfFunctionId,
    source~ : @buslane.ValueId?,
    origin~ : @function_origin.FunctionOrigin
  )
  LiftedFunction(
    function~ : @anf.AnfFunctionId,
    source~ : @buslane.ValueId?,
    origin~ : @function_origin.FunctionOrigin
  )
  LiftedRecursiveFunction(
    function~ : @anf.AnfFunctionId,
    source~ : @buslane.ValueId?,
    origin~ : @function_origin.FunctionOrigin
  )
  Initializer(source~ : @buslane.ValueId)
  InitializerOrchestrator
  IntrinsicWrapper(name~ : String)
  RepresentationWorker(
    function~ : @anf.AnfFunctionId,
    source~ : @buslane.ValueId?,
    origin~ : @function_origin.FunctionOrigin
  )
  CallableAdapter
  LayoutConstructor
  RuntimeImport(source~ : @buslane.ValueId, symbol~ : String)
} derive(Debug, Eq)

///|
priv struct PlannedFunction {
  function : @physical.FunctionId
  entry : PlannedEntry
  origin : PhysicalFunctionOrigin
}

///|
priv struct FunctionPlanTable {
  entries : Array[PlannedFunction]
}

///|
fn FunctionPlanTable::new() -> FunctionPlanTable {
  { entries: [], }
}

///|
fn FunctionPlanTable::length(self : FunctionPlanTable) -> Int {
  self.entries.length()
}

///|
fn FunctionPlanTable::get(
  self : FunctionPlanTable,
  index : Int,
) -> PlannedFunction {
  self.entries[index]
}

///|
#warnings("-unused_value")
fn FunctionPlanTable::observations(
  self : FunctionPlanTable,
) -> Array[(@physical.FunctionId, PhysicalFunctionOrigin)] {
  self.entries.map(planned => (planned.function, planned.origin))
}

///|
fn FunctionPlanTable::origins(
  self : FunctionPlanTable,
) -> Array[PhysicalFunctionOrigin] {
  self.entries.map(planned => planned.origin)
}

///|
fn FunctionPlanTable::append(
  self : FunctionPlanTable,
  origin : PhysicalFunctionOrigin,
  make_entry : (@physical.FunctionId) -> PlannedEntry,
) -> PlannedFunction {
  let (planned, _) = self.append_with_result(origin, fn(function) {
    (make_entry(function), ())
  })
  planned
}

///|
fn[T] FunctionPlanTable::append_with_result(
  self : FunctionPlanTable,
  origin : PhysicalFunctionOrigin,
  make_entry : (@physical.FunctionId) -> (PlannedEntry, T),
) -> (PlannedFunction, T) {
  let function : @physical.FunctionId = { value: self.entries.length() + 1, }
  let (entry, result) = make_entry(function)
  let planned = { function, entry, origin, }
  self.entries.push(planned)
  (planned, result)
}

///|
fn FunctionPlanTable::append_group(
  self : FunctionPlanTable,
  origins : Array[PhysicalFunctionOrigin],
  prepare_entries : (Array[@physical.FunctionId]) -> (Int) -> PlannedEntry,
) -> Array[PlannedFunction] {
  let first = self.entries.length() + 1
  let functions : Array[@physical.FunctionId] = []
  for index = 0; index < origins.length(); index = index + 1 {
    functions.push({ value: first + index, })
  }
  let make_entry = prepare_entries(functions)
  let planned_functions : Array[PlannedFunction] = []
  for index = 0; index < origins.length(); index = index + 1 {
    let planned = {
      function: functions[index],
      entry: make_entry(index),
      origin: origins[index],
    }
    self.entries.push(planned)
    planned_functions.push(planned)
  }
  planned_functions
}

///|
priv struct InitializerStepPlan {
  function : @physical.FunctionId
  value : @buslane.ValueId
  expression : @anf.AnfExpr
}

///|
priv struct IntrinsicWrapperPlan {
  function : @physical.FunctionId
  contract : RuntimeIntrinsicFunctionContract
}

///|
/// A worker owns both its externally visible callable contract and the closed
/// runtime arguments used to rewrite its body. Uniform generic nominal storage
/// can hide those arguments from the outer callable ABI even though nested
/// callable adaptations still depend on them.
priv struct RepresentationWorkerKey {
  source : @physical.FunctionId
  callable : PhysicalCallableContract
  arguments : Array[@anf.RuntimeArgument]
} derive(Eq)

///|
priv struct RepresentationWorkerPlan {
  function : @physical.FunctionId
  key : RepresentationWorkerKey
  body : @anf.AnfFunction
  type_ : @anf.RuntimeType
  substitutions : RuntimeSubstitution
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
  captures : Array[CapturePlan]
  environment_shape : @physical.ObjectShapeId?
  recursive_functions : Array[RecursiveFunctionPlan]
  ancestry : Array[@physical.FunctionId]
}

///|
#warnings("-unused_value")
priv struct CallableAdapterPlan {
  function : @physical.FunctionId
  key : CallableAdapterWorkerKey
  contract : CallableAdapterContract
  environment_shape : @physical.ObjectShapeId
} derive(Debug)

///|
priv struct CallableAdapterContract {
  source_type : @anf.RuntimeType
  target_type : @anf.RuntimeType
  source_parameter_targets : Array[Int]
  substitutions : RuntimeSubstitution
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
} derive(Debug)

///|
priv enum PhysicalEvidenceContract {
  Input(Int)
  Capture(Int)
  Bound(Int)
  Apply(PhysicalEvidenceContract, Array[PhysicalEvidenceContract])
  Lambda(Array[Int], PhysicalEvidenceContract)
  Static(@physical.LayoutRecipe)
} derive(Debug, Eq)

///|
priv enum PhysicalValueContract {
  Unit
  Erased
  Open(PhysicalEvidenceContract)
  Concrete(@physical.ValueAbi, @physical.LayoutRecipe)
  Callable(PhysicalCallableContract)
} derive(Debug, Eq)

///|
priv struct PhysicalValueBoundary {
  abi : PhysicalValueContract
  shape : PhysicalValueContract
} derive(Debug, Eq)

///|
priv struct PhysicalCallableContract {
  abi : @physical.CallableAbiNodeId
  evidence_arguments : Array[PhysicalEvidenceContract]
  parameters : Array[PhysicalValueBoundary]
  result : PhysicalValueBoundary
} derive(Debug, Eq)

///|
priv struct CallableAdapterWorkerKey {
  source : PhysicalCallableContract
  target : PhysicalCallableContract
  source_parameter_targets : Array[Int]
} derive(Debug, Eq)

///|
priv struct LayoutConstructorPlan {
  function : @physical.FunctionId
  evidence : @anf.RuntimeEvidence
  parameters : Array[@anf.RuntimeEvidenceParameter]
  body : @anf.RuntimeEvidence
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
  environment_shape : @physical.ObjectShapeId?
  arity : Int
}

///|
priv enum RuntimeEvidencePlan {
  Existing(@anf.RuntimeEvidenceId)
  ApplyEvidence(@anf.RuntimeEvidenceId, Array[RuntimeEvidencePlan])
  MaterializeLayoutConstructor(@anf.RuntimeEvidence)
  StaticLayout(@physical.LayoutRecipe)
}

///|
pub(all) struct PhysicalFunctionProvenance {
  function : @physical.FunctionId
  origins : Array[PhysicalFunctionOrigin]
} derive(Debug, Eq)

///|
pub(all) enum IndirectCallOrigin {
  SourceBound
  SourceAnonymous
  HandlerElaboration
  MonadicTransformation
  SelectiveCps
  CallableAdapter
  RepresentationWorker
  Initialization
  RuntimeSupport
} derive(Debug, Eq)

///|
pub(all) struct PhysicalIndirectCallObservation {
  function : @physical.FunctionId
  ordinal : Int
  origins : Array[IndirectCallOrigin]
  resolution : @vmcfg.IndirectCallResolution
  boundaries : Array[@vmcfg.CallableFlowBoundary]
} derive(Debug, Eq)

///|
pub(all) struct PhysicalLoweringProvenance {
  functions : Array[PhysicalFunctionProvenance]
  indirect_calls : Array[PhysicalIndirectCallObservation]
} derive(Debug, Eq)

///|
priv enum CaptureBinding {
  Value(@buslane.ValueId)
  Temp(@anf.AnfTempId)
} derive(Eq)

///|
priv struct CapturePlan {
  binding : CaptureBinding
  type_ : @anf.RuntimeType
  member_index : Int?
}

///|
priv struct LiftedFunctionPlan {
  function : @anf.AnfFunction
  type_ : @anf.RuntimeType
  substitutions : RuntimeSubstitution
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
  captures : Array[CapturePlan]
  environment_shape : @physical.ObjectShapeId?
  recursive_functions : Array[RecursiveFunctionPlan]
  specialization_ancestry : Array[@physical.FunctionId]
}

///|
priv struct RecursiveFunctionPlan {
  value : @buslane.ValueId
  function : @physical.FunctionId
  type_ : @anf.RuntimeType
}

///|
priv struct DeferredCallableAdapter {
  source : @vmcfg.ValueId
  contract : CallableAdapterContract
  captured_witnesses : Array[WitnessBinding]
}

///|
priv enum LocalValue {
  Unit
  Slot(@vmcfg.ValueId, @anf.RuntimeType)
  Global(GlobalValue)
  RecursiveFunction(@physical.FunctionId, @anf.RuntimeType, @vmcfg.ValueId?)
  EvidenceApplied(GlobalValue, Array[@anf.RuntimeArgument])
  EvidenceAppliedCallable(
    @vmcfg.ValueId,
    @anf.RuntimeType,
    Array[@anf.RuntimeArgument]
  )
  EvidenceAppliedFunction(
    @physical.FunctionId,
    @anf.RuntimeType,
    @vmcfg.ValueId?,
    Array[@anf.RuntimeArgument]
  )
  AdaptedCallable(DeferredCallableAdapter)
  EvidenceAppliedAdaptedCallable(
    DeferredCallableAdapter,
    Array[@anf.RuntimeArgument]
  )
}

///|
priv struct WitnessBinding {
  parameter : @anf.RuntimeEvidenceId
  value : @vmcfg.ValueId
}

///|
priv struct RuntimeSubstitution {
  entries : Array[(@anf.RuntimeEvidenceId, @anf.RuntimeArgument)]
} derive(Debug)

///|
priv struct ValueBinding {
  value : @buslane.ValueId
  lowered : LocalValue
}

///|
priv struct TempBinding {
  temp : @anf.AnfTempId
  lowered : LocalValue
}

///|
priv struct LowerBlock {
  parameters : Array[@vmcfg.ValueId]
  instructions : Array[@vmcfg.Instruction]
  mut terminator : @vmcfg.Terminator?
}
