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
  UnsupportedGenericData(data_constructor~ : @buslane.DataConId)
  InvalidDataPayloadCount(
    data_constructor~ : @buslane.DataConId,
    expected~ : Int,
    actual~ : Int
  )
  InvalidTypeApplication(detail~ : String)
  UnsupportedIntrinsic(name~ : String)
  NonAsciiString(value~ : String)
  UnterminatedBlock(block~ : Int)
  EffectLoweringError(@effect_lowering.SynthesisError)
  VmcfgFinalizeError(@vmcfg.FinalizeError)
} derive(Debug, Eq)

///|
priv enum GlobalValue {
  Function(@bytecode.FunctionId, @buslane.Type)
  Intrinsic(String, @buslane.Type)
  DoubleConstant(Int64, @buslane.Type)
}

///|
priv struct GlobalBinding {
  value : @buslane.ValueId
  lowered : GlobalValue
}

///|
priv enum PlannedEntry {
  Function(@buslane.ValueId, @anf.AnfFunction)
  LiftedFunction(LiftedFunctionPlan)
  IntrinsicWrapper(IntrinsicWrapperPlan)
  CallableAdapter(CallableAdapterPlan)
  RuntimeImport(@buslane.ValueId, @buslane_lowering.BuslaneBuiltinExternal)
}

///|
priv struct IntrinsicWrapperPlan {
  function : @bytecode.FunctionId
  name : String
  type_ : @buslane.Type
}

///|
priv struct CallableAdapterPlan {
  function : @bytecode.FunctionId
  source_type : @buslane.Type
  target_type : @buslane.Type
  captured_parameters : Array[@buslane.TypeParameterId]
  environment_shape : @bytecode.ObjectShapeId
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
priv struct TypeArgumentBinding {
  parameter : @buslane.TypeParameterId
  argument : @buslane.GenericArgument
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
