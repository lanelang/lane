///|
pub(all) suberror LoisvmLoweringError {
  MissingValueMetadata(value~ : @buslane.ValueId)
  MissingDataConstructorMetadata(data_constructor~ : @buslane.DataConId)
  MissingExternal(value~ : @buslane.ValueId)
  MissingEntry(value~ : @buslane.ValueId)
  InvalidFunctionType(value~ : @buslane.ValueId, type_~ : @buslane.Type)
  UnsupportedType(type_~ : @buslane.Type)
  UnsupportedTopLevel(value~ : @buslane.ValueId)
  UnsupportedExpression(detail~ : String)
  CompilerDefect(@executable.ExecutableElaborationError)
  TypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  UnsupportedGenericData(data_constructor~ : @buslane.DataConId)
  InvalidDataPayloadCount(
    data_constructor~ : @buslane.DataConId,
    expected~ : Int,
    actual~ : Int
  )
  InvalidTypeApplication(detail~ : String)
  UnsupportedIntrinsic(name~ : String)
  UnterminatedBlock(block~ : Int)
  EffectLoweringError(@effect_lowering_core.SynthesisError)
  VmcfgFinalizeError(@vmcfg.FinalizeError)
} derive(Debug, Eq)

///|
priv enum GlobalValue {
  UnitValue
  Function(@bytecode.FunctionId, @buslane.Type)
  Intrinsic(@buslane_lowering.BuslaneIntrinsicFunctionContract)
  FloatConstant(Int, @buslane.Type)
  DoubleConstant(Int64, @buslane.Type)
  InstanceGlobal(@bytecode.GlobalId, @buslane.Type)
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
  contract : @buslane_lowering.BuslaneIntrinsicFunctionContract
}

///|
#warnings("-unused_value")
priv struct CallableAdapterPlan {
  function : @bytecode.FunctionId
  source_type : @buslane.Type
  target_type : @buslane.Type
  source_parameter_targets : Array[Int]
  substitutions : @buslane.TypeSubstitution
  captured_parameters : Array[@buslane.TypeParameterId]
  environment_shape : @bytecode.ObjectShapeId
} derive(Debug)

///|
priv struct LayoutConstructorPlan {
  function : @bytecode.FunctionId
  type_ : @buslane.Type
  parameters : Array[@buslane.TypeParameterId]
  body : @buslane.Type
  captured_parameters : Array[@buslane.TypeParameterId]
  environment_shape : @bytecode.ObjectShapeId?
  arity : Int
}

///|
priv struct CanonicalRuntimeImport {
  descriptor : @bytecode.RuntimeImport
  old_ids : Array[@bytecode.FunctionId]
}

///|
priv enum CaptureBinding {
  Value(@buslane.ValueId)
  Temp(@anf.AnfTempId)
} derive(Eq)

///|
priv struct CapturePlan {
  binding : CaptureBinding
  type_ : @buslane.Type
  member_index : Int?
}

///|
priv struct LiftedFunctionPlan {
  function : @anf.AnfFunction
  type_ : @buslane.Type
  captured_parameters : Array[@buslane.TypeParameterId]
  captures : Array[CapturePlan]
  environment_shape : @bytecode.ObjectShapeId?
  recursive_functions : Array[RecursiveFunctionPlan]
}

///|
priv struct RecursiveFunctionPlan {
  value : @buslane.ValueId
  function : @bytecode.FunctionId
  type_ : @buslane.Type
}

///|
priv enum LocalValue {
  Unit
  Slot(@vmcfg.ValueId, @buslane.Type)
  Global(GlobalValue)
  RecursiveFunction(@bytecode.FunctionId, @buslane.Type, @vmcfg.ValueId?)
  TypeApplied(GlobalValue, Array[@buslane.GenericArgument])
  TypeAppliedCallable(
    @vmcfg.ValueId,
    @buslane.Type,
    Array[@buslane.GenericArgument]
  )
}

///|
priv struct WitnessBinding {
  parameter : @buslane.TypeParameterId
  value : @vmcfg.ValueId
}

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
