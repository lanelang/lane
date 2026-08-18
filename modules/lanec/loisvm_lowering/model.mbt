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
  FunctionTableCanonicalizationCompilerDefect(
    FunctionTableCanonicalizationError
  )
} derive(Debug, Eq)

///|
pub(all) suberror FunctionTableCanonicalizationError {
  OriginCountMismatch(functions~ : Int, origins~ : Int)
  InvalidFunctionReference(function~ : @bytecode.FunctionId)
  MissingFunctionMapping(function~ : @bytecode.FunctionId)
  FinalizedFunctionCountMismatch(functions~ : Int, origins~ : Int)
} derive(Debug, Eq)

///|
priv enum GlobalValue {
  UnitValue
  Function(@bytecode.FunctionId, @anf.RuntimeType)
  Intrinsic(RuntimeIntrinsicFunctionContract)
  FloatConstant(Int, @anf.RuntimeType)
  DoubleConstant(Int64, @anf.RuntimeType)
  InstanceGlobal(@bytecode.GlobalId, @anf.RuntimeType)
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
  CallableAdapter
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
  { entries: [] }
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
fn FunctionPlanTable::origins(
  self : FunctionPlanTable,
) -> Array[LoisvmFunctionOrigin] {
  self.entries.map(planned => planned.origin)
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
      | CallableAdapter
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
  let function : @bytecode.FunctionId = { value: self.entries.length() + 1 }
  let (entry, result) = make_entry(function)
  let planned = { function, entry, origin }
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
    functions.push({ value: first + index })
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
}

///|
#warnings("-unused_value")
priv struct CallableAdapterPlan {
  function : @bytecode.FunctionId
  contract : CallableAdapterContract
  environment_shape : @bytecode.ObjectShapeId
} derive(Debug)

///|
priv struct CallableAdapterContract {
  recipe : CallableAdapterRecipe
  source_type : @anf.RuntimeType
  target_type : @anf.RuntimeType
  source_parameter_targets : Array[Int]
  substitutions : RuntimeSubstitution
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
} derive(Debug)

///|
priv enum CallableAdapterEvidenceRecipe {
  Input(Int)
  Capture(Int)
  Apply(CallableAdapterEvidenceRecipe, Array[CallableAdapterEvidenceRecipe])
  LayoutConstructor(@anf.RuntimeEvidence)
  Static(@bytecode.LayoutRecipe)
} derive(Debug, Eq)

///|
priv enum CallableAdapterValueRecipe {
  Unit
  Erased(CallableAdapterEvidenceRecipe)
  Concrete(CanonicalRuntimeTypeKey, @bytecode.LayoutRecipe)
} derive(Debug, Eq)

///|
priv struct CallableAdapterValueFlowRecipe {
  value : CallableAdapterValueRecipe
  source_shape : CallableAdapterValueRecipe
  target : CallableAdapterValueRecipe
  target_shape : CallableAdapterValueRecipe
  definitionally_equal : Bool
  nested_adapter : CallableAdapterRecipe?
} derive(Debug, Eq)

///|
priv struct CallableAdapterArgumentRecipe {
  target : Int
  flow : CallableAdapterValueFlowRecipe
} derive(Debug, Eq)

///|
priv enum CallableAdapterResultRecipe {
  TailCall
  Adapt(CallableAdapterValueFlowRecipe)
} derive(Debug, Eq)

///|
priv struct CallableAdapterRecipe {
  source_abi : CanonicalCallableAbi
  target_abi : CanonicalCallableAbi
  captured_evidence : Array[@bytecode.ValueAbi]
  target_parameters : Array[CallableAdapterValueRecipe]
  source_arguments : Array[CallableAdapterArgumentRecipe]
  result : CallableAdapterResultRecipe
} derive(Debug, Eq)

///|
priv enum CanonicalRuntimeTypeKey {
  Unit
  Value(@bytecode.ValueAbi)
  Callable(CanonicalCallableAbi)
} derive(Debug, Eq)

///|
priv enum CanonicalRuntimeEvidenceKey {
  Static(@anf.RuntimeLayout)
  Bound(Int)
  Apply(CanonicalRuntimeEvidenceKey, Array[CanonicalRuntimeEvidenceKey])
  Lambda(Array[Int], CanonicalRuntimeEvidenceKey)
} derive(Eq)

///|
priv enum CanonicalSpecializedEvidenceKey {
  FirstOrder(CanonicalRuntimeTypeKey)
  HigherKinded(CanonicalRuntimeEvidenceKey)
} derive(Eq)

///|
priv struct CanonicalCallableAbi {
  witnesses : Array[@bytecode.ValueAbi]
  parameters : Array[CanonicalRuntimeTypeKey]
  result : CanonicalRuntimeTypeKey
} derive(Debug, Eq)

///|
priv struct RepresentationSpecializationKey {
  source_function : @anf.AnfFunctionId
  specialized_evidence : Array[(Int, CanonicalSpecializedEvidenceKey)]
  retained_arities : Array[Int]
  parameters : Array[CanonicalRuntimeTypeKey]
  scalar_parameters : Array[
    (Int, @buslane.DataConId, Array[CanonicalRuntimeTypeKey]),
  ]
  result : CanonicalRuntimeTypeKey
} derive(Eq)

///|
priv struct RepresentationSpecializationPlan {
  worker : @bytecode.FunctionId
  instances : Array[Int]
  key : RepresentationSpecializationKey
  function : @anf.AnfFunction
  substitutions : RuntimeSubstitution
  retained_parameters : Array[@anf.RuntimeEvidenceParameter]
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  parameter_types : Array[@anf.RuntimeType]
  scalar_parameters : Array[ScalarParameterPlan]
  result_type : @anf.RuntimeType
  capture : CallableCaptureContract
  recursive_functions : Array[RecursiveFunctionPlan]
}

///|
priv struct LayoutConstructorPlan {
  function : @bytecode.FunctionId
  evidence : @anf.RuntimeEvidence
  parameters : Array[@anf.RuntimeEvidenceParameter]
  body : @anf.RuntimeEvidence
  captured_parameters : Array[@anf.RuntimeEvidenceParameter]
  environment_shape : @bytecode.ObjectShapeId?
  arity : Int
}

///|
priv enum RuntimeEvidencePlan {
  Existing(@anf.RuntimeEvidenceId)
  ApplyEvidence(@anf.RuntimeEvidenceId, Array[RuntimeEvidencePlan])
  MaterializeLayoutConstructor(@anf.RuntimeEvidence)
  StaticLayout(@bytecode.LayoutRecipe)
}

///|
priv struct CanonicalRuntimeImport {
  descriptor : @bytecode.RuntimeImport
  old_ids : Array[@bytecode.FunctionId]
}

///|
pub(all) struct LoisvmFunctionProvenance {
  function : @bytecode.FunctionId
  origins : Array[LoisvmFunctionOrigin]
} derive(Debug, Eq)

///|
priv struct CanonicalizedFunctionTable {
  image : @vmcfg.Image
  provenance : Array[LoisvmFunctionProvenance]
}

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
  lowered_function : @bytecode.FunctionId
  function : @anf.AnfFunction
  instance : Int
  type_ : @anf.RuntimeType
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  capture : CallableCaptureContract
  recursive_functions : Array[RecursiveFunctionPlan]
}

///|
priv struct CallableCaptureContract {
  captured_evidence : Array[CapturedEvidencePlan]
  captures : Array[CapturePlan]
  environment_shape : @bytecode.ObjectShapeId?
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
priv struct DeferredCallableAdapter {
  source : @vmcfg.ValueId
  contract : CallableAdapterContract
  captured_witnesses : Array[WitnessBinding]
}

///|
priv struct DeferredNestedCallable {
  function : @anf.AnfFunction
  instance : Int
  type_ : @anf.RuntimeType
  environment : @vmcfg.ValueId?
}

///|
priv enum LocalValue {
  Unit
  Slot(@vmcfg.ValueId, @anf.RuntimeType)
  ClosedAggregate(ClosedAggregateContract, Array[LocalValue])
  Global(GlobalValue)
  RecursiveFunction(@bytecode.FunctionId, @anf.RuntimeType, @vmcfg.ValueId?)
  NestedCallable(DeferredNestedCallable)
  EvidenceApplied(GlobalValue, Array[@anf.RuntimeArgument])
  EvidenceAppliedNestedCallable(
    DeferredNestedCallable,
    Array[@anf.RuntimeArgument]
  )
  EvidenceAppliedCallable(
    @vmcfg.ValueId,
    @anf.RuntimeType,
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
