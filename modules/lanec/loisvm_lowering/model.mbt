///|
pub(all) suberror LoisvmLoweringError {
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
  RepresentationSpecializationInvariant(detail~ : String)
  UnsupportedIntrinsic(name~ : String)
  UnterminatedBlock(block~ : Int)
  VmcfgFinalizeError(@vmcfg.FinalizeError)
  FunctionProvenanceCompilerDefect(FunctionProvenanceError)
} derive(Debug, Eq)

///|
pub(all) suberror FunctionProvenanceError {
  OriginCountMismatch(functions~ : Int, origins~ : Int)
  InvalidSourceFunction(function~ : @bytecode.FunctionId)
  FinalizedFunctionCountMismatch(functions~ : Int, origins~ : Int)
  TransitionOperationCountMismatch(
    function~ : @bytecode.FunctionId,
    events~ : Int,
    operations~ : Int
  )
  TransitionEventStreamMismatch(
    function~ : @bytecode.FunctionId,
    source~ : @bytecode.FunctionId
  )
  TransitionEventMismatch(
    function~ : @bytecode.FunctionId,
    event~ : Int,
    transition~ : LoisvmRepresentationTransitionId
  )
} derive(Debug, Eq)

///|
priv enum GlobalValue {
  UnitValue
  Function(@bytecode.FunctionId, @anf.RuntimeType)
  Intrinsic(RuntimeIntrinsicFunctionContract)
  FloatConstant(Int, @anf.RuntimeType)
  DoubleConstant(Int64, @anf.RuntimeType)
  InstanceGlobal(
    @bytecode.GlobalId,
    @anf.RuntimeType,
    CanonicalRuntimeTypeKey,
    PhysicalCallableInterface?
  )
}

///|
priv struct PhysicalGlobalValue {
  producer : PhysicalGlobalProducer
  contract : PhysicalValueContract
}

///|
priv enum PhysicalGlobalProducer {
  PhysicalUnit
  PhysicalFunction(@bytecode.FunctionId)
  PhysicalIntrinsic(IntrinsicWrapperPlan)
  PhysicalFloatConstant(Int)
  PhysicalDoubleConstant(Int64)
  PhysicalInstanceGlobal(@bytecode.GlobalId, CanonicalRuntimeTypeKey)
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
  CallableAdapter(CallableAdapterPlan)
  RepresentationWorker(RepresentationSpecializationPlan)
  LayoutConstructor(LayoutConstructorPlan)
  RuntimeImport(@bytecode.RuntimeImport)
}

///|
pub(all) enum LoisvmFunctionOrigin {
  TopLevelFunction(function~ : @anf.AnfFunctionId, source~ : @buslane.ValueId?)
  LiftedFunction(function~ : @anf.AnfFunctionId, source~ : @buslane.ValueId?)
  LiftedRecursiveFunction(
    function~ : @anf.AnfFunctionId,
    source~ : @buslane.ValueId?
  )
  Initializer(source~ : @buslane.ValueId)
  InitializerOrchestrator
  IntrinsicWrapper(name~ : String)
  CallableAdapter(transition~ : LoisvmRepresentationTransitionId)
  RepresentationSpecialization(
    function~ : @anf.AnfFunctionId,
    source~ : @buslane.ValueId?
  )
  LayoutConstructor
  RuntimeImport(source~ : @buslane.ValueId, symbol~ : String)
} derive(Debug, Eq)

///|
priv struct PlannedFunction {
  function : @bytecode.FunctionId
  entry : PlannedEntry
  origin : LoisvmFunctionOrigin
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
) -> Array[(@bytecode.FunctionId, LoisvmFunctionOrigin)] {
  self.entries.map(planned => (planned.function, planned.origin))
}

///|
fn FunctionPlanTable::contains_top_level_function(
  self : FunctionPlanTable,
  function : @anf.AnfFunctionId,
) -> Bool {
  self.entries.any(entry => {
    match entry.origin {
      TopLevelFunction(function=planned, ..) => planned == function
      LiftedFunction(..)
      | LiftedRecursiveFunction(..)
      | RepresentationSpecialization(..)
      | Initializer(..)
      | InitializerOrchestrator
      | IntrinsicWrapper(..)
      | CallableAdapter(_)
      | LayoutConstructor
      | RuntimeImport(..) => false
    }
  })
}

///|
fn FunctionPlanTable::append(
  self : FunctionPlanTable,
  origin : LoisvmFunctionOrigin,
  make_entry : (@bytecode.FunctionId) -> PlannedEntry,
) -> PlannedFunction {
  let (planned, _) = self.append_with_result(origin, fn(function) {
    (make_entry(function), ())
  })
  planned
}

///|
fn[T] FunctionPlanTable::append_with_result(
  self : FunctionPlanTable,
  origin : LoisvmFunctionOrigin,
  make_entry : (@bytecode.FunctionId) -> (PlannedEntry, T),
) -> (PlannedFunction, T) {
  let function : @bytecode.FunctionId = { value: self.entries.length() + 1, }
  let (entry, result) = make_entry(function)
  let planned = { function, entry, origin, }
  self.entries.push(planned)
  (planned, result)
}

///|
fn FunctionPlanTable::append_group(
  self : FunctionPlanTable,
  origins : Array[LoisvmFunctionOrigin],
  prepare_entries : (Array[@bytecode.FunctionId]) -> (Int) -> PlannedEntry,
) -> Array[PlannedFunction] {
  let first = self.entries.length() + 1
  let functions : Array[@bytecode.FunctionId] = []
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
  function : @bytecode.FunctionId
  value : @buslane.ValueId
  expression : @anf.AnfExpr
}

///|
priv struct IntrinsicWrapperPlan {
  function : @bytecode.FunctionId
  contract : RuntimeIntrinsicFunctionContract
  invocation : PhysicalCallableContractId
  parameter_shapes : Array[CanonicalRuntimeTypeKey]
  result_shape : CanonicalRuntimeTypeKey
}

///|
#warnings("-unused_value")
priv struct CallableAdapterPlan {
  function : @bytecode.FunctionId
  recipe : CallableAdapterRecipe
  environment : PhysicalEnvironmentContract
  transition : LoisvmRepresentationTransitionId
} derive(Debug)

///|
pub(all) struct LoisvmRepresentationTransitionId {
  index : Int
} derive(Debug, Eq)

///|
pub(all) enum LoisvmRepresentationContract {
  Unit
  Value(@bytecode.ValueAbi)
  Callable(contract~ : Int)
} derive(Debug, Eq)

///|
pub(all) struct LoisvmCallableContractNode {
  id : Int
  representative : Int
  witnesses : Array[@bytecode.ValueAbi]
  parameters : Array[LoisvmRepresentationContract]
  result : LoisvmRepresentationContract
} derive(Debug, Eq)

///|
pub(all) enum LoisvmRepresentationTransitionKind {
  Erase
  Unerase
  CallableAdapter
} derive(Debug, Eq)

///|
pub(all) struct LoisvmRepresentationTransition {
  id : LoisvmRepresentationTransitionId
  source : LoisvmRepresentationContract
  target : LoisvmRepresentationContract
  kind : LoisvmRepresentationTransitionKind
} derive(Debug, Eq)

///|
pub(all) enum LoisvmRepresentationTransitionBoundary {
  InitializerResult
  FunctionResult
  RecursiveBinding
  AtomBinding
  CallResult
  ScalarConstructionPayload
  DataConstructionPayload
  MatchResult
  RepresentationCallArgument
  CallArgument
  CallableCapture
  DataMatchPayload
  CallableAdapterArgument
  CallableAdapterDiscard
  CallableAdapterResult
} derive(Debug, Eq)

///|
pub(all) struct LoisvmRepresentationTransitionOccurrence {
  event : Int
  function : @bytecode.FunctionId
  origins : Array[LoisvmFunctionOrigin]
  transition : LoisvmRepresentationTransitionId
  boundary : LoisvmRepresentationTransitionBoundary
  binding : @anf.AnfBindingId?
  ordinal : Int?
} derive(Debug, Eq)

///|
priv enum PhysicalRepresentationTransitionKind {
  Erase
  Unerase
  CallableAdapter
} derive(Eq)

///|
priv struct PhysicalRepresentationTransition {
  source : CanonicalRuntimeTypeKey
  target : CanonicalRuntimeTypeKey
  kind : PhysicalRepresentationTransitionKind
} derive(Eq)

///|
priv struct PhysicalRepresentationTransitionCatalog {
  transitions : Array[PhysicalRepresentationTransition]
}

///|
priv struct PhysicalRepresentationTransitionSite {
  transition : LoisvmRepresentationTransitionId
  boundary : LoisvmRepresentationTransitionBoundary
  binding : @anf.AnfBindingId?
  ordinal : Int?
} derive(Eq)

///|
priv enum PhysicalRepresentationTransitionOperation {
  Produced(@vmcfg.ValueId)
  Consumed(@vmcfg.ValueId)
} derive(Eq)

///|
priv struct PhysicalEmittedRepresentationTransitionEvent {
  transition : LoisvmRepresentationTransitionId
  boundary : LoisvmRepresentationTransitionBoundary
  binding : @anf.AnfBindingId?
  ordinal : Int?
  operation : PhysicalRepresentationTransitionOperation
}

///|
priv struct CallableAdapterContract {
  recipe : CallableAdapterRecipe
  source_type : @anf.RuntimeType
  target_type : @anf.RuntimeType
  source_parameter_targets : Array[Int]
  substitutions : RuntimeSubstitution
  captures : Array[CallableAdapterEvidenceCapture]
  nested_adapters : Array[CallableAdapterContract]
} derive(Debug)

///|
priv struct CallableAdapterEvidenceCapture {
  source : @anf.RuntimeEvidenceParameter
} derive(Debug)

///|
priv enum CallableAdapterEvidenceRecipe {
  Input(Int)
  Capture(Int)
  Apply(CallableAdapterEvidenceRecipe, Array[CallableAdapterEvidenceRecipe])
  LayoutConstructor(@anf.RuntimeEvidence, Array[CallableAdapterEvidenceRecipe])
  Static(@bytecode.LayoutRecipe)
} derive(Debug, Eq)

///|
priv enum CallableAdapterValueRecipe {
  Unit
  Erased(CallableAdapterEvidenceRecipe)
  Concrete(CanonicalRuntimeTypeKey)
} derive(Debug, Eq)

///|
priv struct CallableAdapterValueFlowRecipe {
  value : CallableAdapterValueRecipe
  source_shape : CallableAdapterValueRecipe
  target : CallableAdapterValueRecipe
  target_shape : CallableAdapterValueRecipe
  definitionally_equal : Bool
  nested_adapter : CallableAdapterNestedRecipe?
  transition : LoisvmRepresentationTransitionId?
} derive(Debug, Eq)

///|
priv struct CallableAdapterNestedRecipe {
  recipe : CallableAdapterRecipe
  captured_evidence : Array[CallableAdapterEvidenceRecipe]
} derive(Debug, Eq)

///|
priv enum CallableAdapterArgumentInput {
  TargetParameter(Int)
  Unit
} derive(Debug, Eq)

///|
priv struct CallableAdapterArgumentRecipe {
  input : CallableAdapterArgumentInput
  flow : CallableAdapterValueFlowRecipe
} derive(Debug, Eq)

///|
priv struct CallableAdapterDiscardRecipe {
  input : Int
  flow : CallableAdapterValueFlowRecipe
} derive(Debug, Eq)

///|
priv enum CallableAdapterResultRecipe {
  TailCall
  Adapt(CallableAdapterValueFlowRecipe)
} derive(Debug, Eq)

///|
priv struct CallableAdapterRecipe {
  source_abi : PhysicalCallableContractId
  target_abi : PhysicalCallableContractId
  captured_evidence : Array[@bytecode.ValueAbi]
  source_witnesses : Array[CallableAdapterEvidenceRecipe]
  target_parameters : Array[CallableAdapterValueRecipe]
  source_arguments : Array[CallableAdapterArgumentRecipe]
  target_discards : Array[CallableAdapterDiscardRecipe]
  result : CallableAdapterResultRecipe
} derive(Debug, Eq)

///|
priv enum CanonicalRuntimeTypeKey {
  Unit
  Value(@bytecode.ValueAbi)
  Callable(PhysicalCallableContractId)
} derive(Debug, Eq)

///|
/// Canonical identity of one node in the physical callable-contract graph.
/// Recursive invocation structure is represented by graph edges rather than
/// recursively embedding another callable ABI value.
priv struct PhysicalCallableContractId {
  index : Int
} derive(Debug, Eq)

///|
priv struct PhysicalCallableContract {
  witnesses : Array[@bytecode.ValueAbi]
  parameters : Array[CanonicalRuntimeTypeKey]
  result : CanonicalRuntimeTypeKey
} derive(Debug, Eq)

///|
priv enum PhysicalCallableContractNode {
  Reserved
  Defined(PhysicalCallableContract)
}

///|
priv struct PhysicalCallableContractCatalog {
  nodes : Array[PhysicalCallableContractNode]
  mut representatives : Array[PhysicalCallableContractId]
  mut canonical : Bool
}

///|
priv enum CanonicalRuntimeEvidenceKey {
  Static(@anf.RuntimeLayout)
  Bound(Int)
  Apply(CanonicalRuntimeEvidenceKey, Array[CanonicalRuntimeEvidenceKey])
  Lambda(Array[Int], CanonicalRuntimeEvidenceKey)
} derive(Debug, Eq)

///|
priv enum CanonicalRepresentationTypeExpressionKey {
  Static(CanonicalRepresentationTypeKey)
  Bound(Int)
  Apply(
    CanonicalRepresentationTypeExpressionKey,
    Array[CanonicalRepresentationTypeExpressionKey]
  )
  Lambda(Array[Int], CanonicalRepresentationTypeExpressionKey)
} derive(Debug, Eq)

///|
priv struct CanonicalRepresentationArgumentKey {
  type_expression : CanonicalRepresentationTypeExpressionKey
  evidence : CanonicalRuntimeEvidenceKey
} derive(Debug, Eq)

///|
priv enum CanonicalRepresentationTypeKey {
  Unit
  Scalar(@anf.RuntimeScalarType)
  ByteSequence
  OpaqueReference(@buslane.TypeId)
  Data(@buslane.TypeId, Array[CanonicalRepresentationArgumentKey])
  Callable(
    Array[CanonicalRepresentationTypeKey],
    CanonicalRepresentationTypeKey
  )
  Erased(CanonicalRepresentationTypeExpressionKey, CanonicalRuntimeEvidenceKey)
  Forall(Array[Int], CanonicalRepresentationTypeKey)
} derive(Debug, Eq)

///|
priv enum DataRepresentationFamilyKey {
  Declaration(@buslane.TypeId)
  Specialized(@buslane.TypeId, Array[CanonicalRepresentationArgumentKey], Int)
} derive(Debug, Eq)

///|
priv struct DataRepresentationFamilyCandidateKey {
  owner : @buslane.TypeId
  arguments : Array[CanonicalRepresentationArgumentKey]
} derive(Eq)

///|
priv struct DataRepresentationFamilyId {
  index : Int
} derive(Debug, Eq)

///|
priv struct DataRepresentationCallableStorageDemand {
  callable : CallableRepresentationTarget
  component : Int
} derive(Debug, Eq)

///|
priv struct DataRepresentationConstructorPlan {
  data_constructor : @buslane.DataConId
  mut shape : @bytecode.ObjectShapeId?
  storage_hidden_arguments : Array[@anf.RuntimeArgument]?
  storage_evidence_parameters : Array[@anf.RuntimeEvidenceParameter]
  storage_types : Array[@anf.RuntimeType]
  storage_data_families : Array[DataRepresentationFamilyKey?]
  storage_callable_demands : Array[
    Array[DataRepresentationCallableStorageDemand],
  ]
  storage_callable_interfaces : Array[PhysicalCallableInterface?]
  storage_shapes : Array[CanonicalRuntimeTypeKey]
} derive(Debug)

///|
#warnings("-unused_value")
priv struct DataRepresentationFamilyPlan {
  identity : DataRepresentationFamilyId
  key : DataRepresentationFamilyKey
  mut bytecode_family : @bytecode.DataFamilyId?
  owner : @buslane.TypeId
  constructors : Array[DataRepresentationConstructorPlan]
} derive(Debug)

///|
priv enum CanonicalSpecializedEvidenceKey {
  FirstOrder(CanonicalRuntimeTypeKey)
  HigherKinded(CanonicalRuntimeEvidenceKey)
} derive(Eq)

///|
/// The compile-time projection owned by a callable implementation boundary.
/// `PhysicalCallableContractId` remains the pure runtime identity; this structure
/// records which logical parameter produced each physical ABI slot.
priv enum PhysicalCallableParameterProjection {
  Unit
  Slot(CanonicalRuntimeTypeKey)
  Product(Array[PhysicalCallableParameterProjection])
} derive(Debug, Eq)

///|
priv struct PhysicalCallableInterface {
  evidence_parameters : Array[@anf.RuntimeEvidenceParameter]
  evidence_arguments : Array[@anf.RuntimeArgument]
  parameter_types : Array[@anf.RuntimeType]
  result_type : @anf.RuntimeType
  invocation : PhysicalCallableContractId
  callable_target : CallableRepresentationTarget?
  parameters : Array[PhysicalCallableParameterProjection]
  parameter_callable_targets : Array[CallableRepresentationTarget?]
  result_callable_target : CallableRepresentationTarget?
} derive(Debug, Eq)

///|
priv struct PhysicalCallableCaptureProjection {
  binding : @anf.AnfBindingId
  shape : CanonicalRuntimeTypeKey
  callable : CallableRepresentationTarget?
  worker : Bool
} derive(Eq)

///|
priv struct RepresentationSpecializationKey {
  source_function : @anf.AnfFunctionId
  specialized_evidence : Array[(Int, CanonicalSpecializedEvidenceKey)]
  data_ports : Array[(@anf.AnfBindingId, DataRepresentationFamilyKey)]
  callable_ports : Array[(@anf.AnfBindingId, CallableRepresentationTarget)]
  callable_allocations : Array[
    (@anf.AnfFunctionId, CallableRepresentationTarget),
  ]
  callable_arguments : Array[
    (@anf.AnfBindingId, Int, CallableRepresentationTarget),
  ]
  callable_result : CallableRepresentationTarget?
  captures : Array[PhysicalCallableCaptureProjection]
  parameters : Array[CanonicalRuntimeTypeKey]
  scalar_parameters : Array[
    (Int, @buslane.DataConId, Array[CanonicalRuntimeTypeKey]),
  ]
  result : CanonicalRuntimeTypeKey
} derive(Eq)

///|
priv struct RepresentationSpecializationPlan {
  worker : @bytecode.FunctionId
  owner : CallableRepresentationTarget
  aliases : Array[CallableRepresentationTarget]
  data_components : Array[Int]
  callable_components : Array[Int]
  key : RepresentationSpecializationKey
  function : @anf.AnfFunction
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  residual_parameters : Array[@anf.RuntimeEvidenceParameter]
  parameter_types : Array[@anf.RuntimeType]
  scalar_parameters : Array[ScalarParameterPlan]
  result_type : @anf.RuntimeType
  recursive_functions : Array[RecursiveFunctionPlan]
}

///|
priv struct LayoutConstructorPlan {
  function : @bytecode.FunctionId
  evidence : @anf.RuntimeEvidence
  parameters : Array[@anf.RuntimeEvidenceParameter]
  body : RuntimeEvidencePlan
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
  environment : PhysicalEnvironmentContract?
  arity : Int
}

///|
priv struct LayoutConstructorContract {
  evidence : @anf.RuntimeEvidence
  parameters : Array[@anf.RuntimeEvidenceParameter]
  body : @anf.RuntimeEvidence
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
}

///|
priv struct PhysicalLayoutConstructorReference {
  function : @bytecode.FunctionId
  evidence : @anf.RuntimeEvidence
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
  environment : PhysicalEnvironmentContract?
  arity : Int
} derive(Debug, Eq)

///|
priv struct PhysicalEnvironmentContract {
  shape : @bytecode.ObjectShapeId
  layout : @bytecode.LayoutId
} derive(Debug, Eq)

///|
priv enum RuntimeEvidencePlan {
  Existing(@anf.RuntimeEvidenceId)
  ApplyEvidence(@anf.RuntimeEvidenceId, Array[RuntimeEvidencePlan])
  MaterializeLayoutConstructor(PhysicalLayoutConstructorReference)
  StaticLayout(PhysicalStaticLayout)
} derive(Debug, Eq)

///|
priv struct PhysicalStaticLayout {
  recipe : @bytecode.LayoutRecipe
  layout : @bytecode.LayoutId
} derive(Debug, Eq)

///|
pub(all) struct LoisvmFunctionProvenance {
  function : @bytecode.FunctionId
  origins : Array[LoisvmFunctionOrigin]
} derive(Debug, Eq)

///|
pub(all) struct LoisvmLoweringProvenance {
  functions : Array[LoisvmFunctionProvenance]
  callable_contracts : Array[LoisvmCallableContractNode]
  representation_transitions : Array[LoisvmRepresentationTransition]
  transition_occurrences : Array[LoisvmRepresentationTransitionOccurrence]
} derive(Debug, Eq)

///|
priv enum CaptureBinding {
  Value(@buslane.ValueId)
  Temp(@anf.AnfTempId)
} derive(Debug, Eq)

///|
priv struct CapturePlan {
  binding : CaptureBinding
  type_ : @anf.RuntimeType
  shape : CanonicalRuntimeTypeKey?
  callable_interface : PhysicalCallableInterface?
  member_index : Int?
}

///|
priv struct LiftedFunctionPlan {
  lowered_function : @bytecode.FunctionId
  function : @anf.AnfFunction
  instance : Int
  type_ : @anf.RuntimeType
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  recursive_functions : Array[RecursiveFunctionPlan]
}

///|
priv struct CallableInstanceImplementation {
  function : @bytecode.FunctionId
  type_ : @anf.RuntimeType
}

///|
priv struct CallableCaptureContract {
  captured_evidence : Array[CapturedEvidencePlan]
  captures : Array[CapturePlan]
  environment : PhysicalEnvironmentContract?
}

///|
priv struct CapturedEvidencePlan {
  source : @anf.RuntimeEvidenceId
  target : @anf.RuntimeEvidenceParameter
}

///|
priv struct RecursiveFunctionPlan {
  value : @buslane.ValueId
  function : @bytecode.FunctionId
  type_ : @anf.RuntimeType
}

///|
priv struct DeferredNestedCallable {
  source : @anf.AnfFunctionId
  lowered_function : @bytecode.FunctionId
  environment : @vmcfg.ValueId?
  invocation : PhysicalCallableContractId
}

///|
priv enum LocalValue {
  Unit
  Slot(@vmcfg.ValueId, CanonicalRuntimeTypeKey)
  ClosedAggregate(ClosedAggregateContract, Array[LocalValue])
  Global(PhysicalGlobalProducer)
  RecursiveFunction(@bytecode.FunctionId, @vmcfg.ValueId?)
  NestedCallable(DeferredNestedCallable)
  EvidenceApplied(PhysicalGlobalProducer, PhysicalEvidenceApplication)
  EvidenceAppliedNestedCallable(
    DeferredNestedCallable,
    PhysicalEvidenceApplication
  )
  EvidenceAppliedCallable(
    @vmcfg.ValueId,
    CanonicalRuntimeTypeKey,
    PhysicalEvidenceApplication
  )
}

///|
/// A value emitted from Physical ANF together with the contract certified by
/// that IR. VM CFG emission must consume this contract instead of recovering
/// representation facts from LocalValue storage details.
priv struct PhysicalLocalValue {
  value : LocalValue
  contract : PhysicalValueContract
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
