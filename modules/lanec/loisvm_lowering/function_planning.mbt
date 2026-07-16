///|
fn ImageLowerer::plan(
  self : ImageLowerer,
  program : @anf.AnfProgram,
  occurrence : @occurrence.OccurrenceSummary,
) -> @bytecode.FunctionId? raise LoisvmLoweringError {
  let initializers : Array[InitializerBinding] = []
  for term in program.terms {
    match term {
      External(value) =>
        if occurrence.is_reachable(value) {
          self.plan_external(value)
        }
      Let(value, expression) =>
        match extract_top_function(expression) {
          Some(function) =>
            if occurrence.is_reachable(value) {
              self.add_plan(value, Function(value, function))
            }
          None =>
            if occurrence.is_reachable(value) {
              self.add_instance_global(value)
              initializers.push({ value, expression })
            }
        }
      LetRec(bindings) =>
        for binding in bindings {
          if occurrence.is_reachable(binding.id) {
            match extract_top_atom_function(binding.rhs) {
              Some(function) =>
                self.add_plan(binding.id, Function(binding.id, function))
              None => raise UnsupportedTopLevel(value=binding.id)
            }
          }
        }
    }
  }
  if initializers.is_empty() {
    None
  } else {
    let initializer : @bytecode.FunctionId = { value: self.plans.length() + 1 }
    self.plans.push(Initializer(initializers))
    Some(initializer)
  }
}

///|
fn @occurrence.OccurrenceSummary::is_reachable(
  self : @occurrence.OccurrenceSummary,
  value : @buslane.ValueId,
) -> Bool {
  match self.facts.get(value.index) {
    Some(fact) => fact.reachable_from_entry
    None => false
  }
}

///|
fn ImageLowerer::add_instance_global(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> Unit raise LoisvmLoweringError {
  let type_ = match self.metadata.value_info(value) {
    Some(info) => info.type_
    None => raise MissingValueMetadata(value~)
  }
  if type_ == Primitive(Unit) {
    self.globals.push({ value, lowered: UnitValue })
    return
  }
  let metadata = slot_metadata(type_)
  let global : @bytecode.GlobalId = { value: self.instance_globals.length() }
  self.instance_globals.push({
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    erased_companion: None,
  })
  self.globals.push({ value, lowered: InstanceGlobal(global, type_) })
}

///|
fn ImageLowerer::plan_external(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> Unit raise LoisvmLoweringError {
  match self.find_builtin_external(value) {
    Some(external) => self.plan_intrinsic(value, external)
    None =>
      match self.find_runtime_import(value) {
        Some(import_) => self.plan_runtime_import(value, import_)
        None => raise MissingExternal(value~)
      }
  }
}

///|
fn ImageLowerer::plan_intrinsic(
  self : ImageLowerer,
  value : @buslane.ValueId,
  external : @buslane_lowering.BuslaneBuiltinExternal,
) -> Unit raise LoisvmLoweringError {
  if is_scalar_intrinsic(external.name) {
    self.globals.push({
      value,
      lowered: Intrinsic(external.name, external.type_),
    })
  } else if scalar_double_constant(external.name) is Some(bits) {
    self.globals.push({ value, lowered: DoubleConstant(bits, external.type_) })
  } else {
    raise UnsupportedIntrinsic(name=external.name)
  }
}

///|
fn ImageLowerer::plan_runtime_import(
  self : ImageLowerer,
  value : @buslane.ValueId,
  import_ : @buslane_lowering.BuslaneRuntimeImport,
) -> Unit raise LoisvmLoweringError {
  guard import_.type_ is Function(parameters, result, _) else {
    raise UnsupportedExpression(detail="runtime import must be a function")
  }
  let parameter_kinds = []
  for parameter in parameters {
    match runtime_import_value_kind(self.metadata, parameter) {
      Some(kind) => parameter_kinds.push(kind)
      None =>
        raise UnsupportedExpression(
          detail="runtime import parameters must use direct host ABI types",
        )
    }
  }
  let result_kind = match runtime_import_value_kind(self.metadata, result) {
    Some(kind) => kind
    None =>
      raise UnsupportedExpression(
        detail="runtime import result must use a direct host ABI type",
      )
  }
  self.add_plan(
    value,
    RuntimeImport({
      abi_major: 1,
      parameters: parameter_kinds,
      result: result_kind,
      symbol: import_.symbol,
    }),
  )
}

///|
fn ImageLowerer::add_plan(
  self : ImageLowerer,
  value : @buslane.ValueId,
  plan : PlannedEntry,
) -> Unit raise LoisvmLoweringError {
  let function : @bytecode.FunctionId = { value: self.plans.length() + 1 }
  let type_ = match self.metadata.value_info(value) {
    Some(info) => info.type_
    None => raise MissingValueMetadata(value~)
  }
  self.plans.push(plan)
  self.globals.push({ value, lowered: Function(function, type_) })
}

///|
fn ImageLowerer::find_builtin_external(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> @buslane_lowering.BuslaneBuiltinExternal? {
  for external in self.externals.builtins {
    if external.value == value {
      return Some(external)
    }
  }
  None
}

///|
fn ImageLowerer::find_runtime_import(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> @buslane_lowering.BuslaneRuntimeImport? {
  for import_ in self.externals.runtime_imports {
    if import_.value == value {
      return Some(import_)
    }
  }
  None
}

///|
fn ImageLowerer::find_global(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> GlobalValue? {
  for binding in self.globals {
    if binding.value == value {
      return Some(binding.lowered)
    }
  }
  None
}

///|
fn extract_top_function(expression : @anf.AnfExpr) -> @anf.AnfFunction? {
  match expression {
    Atom(atom) => extract_top_atom_function(atom)
    _ => None
  }
}

///|
fn extract_top_atom_function(atom : @anf.AnfAtom) -> @anf.AnfFunction? {
  match atom {
    Function(function) => Some(function)
    TypeLambda(body~, ..) => extract_top_function(body)
    _ => None
  }
}

///|
fn ImageLowerer::lower_function(
  self : ImageLowerer,
  value : @buslane.ValueId,
  function : @anf.AnfFunction,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let type_ = match self.metadata.value_info(value) {
    Some(info) => info.type_
    None => raise MissingValueMetadata(value~)
  }
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    type_,
  )
  self.lower_function_body(
    function,
    type_parameters,
    parameter_types,
    result_type,
    [],
    [],
    None,
    [],
  )
}

///|
fn ImageLowerer::lower_initializer(
  self : ImageLowerer,
  bindings : Array[InitializerBinding],
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: [],
  }
  for binding in bindings {
    let result = lowerer.materialize_local(
      lowerer.lower_expr(binding.expression),
    )
    match (self.find_global(binding.value), result) {
      (Some(UnitValue), Unit) => ()
      (Some(InstanceGlobal(global, _)), Slot(source, _)) =>
        lowerer.emit(InitGlobal(global, source))
      _ =>
        raise UnsupportedExpression(
          detail="top-level initializer result does not match its instance global",
        )
    }
  }
  lowerer.terminate(Return(None))
  let blocks : Array[@vmcfg.Block] = []
  for index, block in lowerer.blocks {
    let terminator = match block.terminator {
      Some(terminator) => terminator
      None => raise UnterminatedBlock(block=index)
    }
    blocks.push({
      parameters: block.parameters,
      instructions: block.instructions,
      terminator,
    })
  }
  {
    values: lowerer.values,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks,
  }
}

///|
fn ImageLowerer::lower_lifted_function(
  self : ImageLowerer,
  plan : LiftedFunctionPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    plan.type_,
  )
  self.lower_function_body(
    plan.function,
    type_parameters,
    parameter_types,
    result_type,
    plan.captured_parameters,
    plan.captures,
    plan.environment_shape,
    plan.recursive_functions,
  )
}

///|
fn ImageLowerer::lower_intrinsic_wrapper(
  self : ImageLowerer,
  plan : IntrinsicWrapperPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    plan.type_,
  )
  if !type_parameters.is_empty() {
    raise UnsupportedIntrinsic(name=plan.name)
  }
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: [],
  }
  let parameter_slots = parameter_types.map(type_ => lowerer.fresh_slot(type_))
  let arguments = []
  for index, slot in parameter_slots {
    arguments.push(Slot(slot, parameter_types[index]))
  }
  let result = lowerer.lower_intrinsic(plan.name, plan.type_, arguments)
  guard result is Slot(result_slot, _) else {
    raise UnsupportedIntrinsic(name=plan.name)
  }
  lowerer.terminate(Return(Some(result_slot)))
  {
    values: lowerer.values,
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: parameter_slots,
    },
    result: result_representation(result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: Return(Some(result_slot)),
      },
    ],
  }
}

///|
fn ImageLowerer::intrinsic_wrapper(
  self : ImageLowerer,
  name : String,
  type_ : @buslane.Type,
) -> @bytecode.FunctionId {
  for wrapper in self.intrinsic_wrappers {
    if wrapper.name == name && wrapper.type_ == type_ {
      return wrapper.function
    }
  }
  let function : @bytecode.FunctionId = { value: self.plans.length() + 1 }
  let wrapper = { function, name, type_ }
  self.intrinsic_wrappers.push(wrapper)
  self.plans.push(IntrinsicWrapper(wrapper))
  function
}

///|
fn ImageLowerer::fresh_synthetic_parameter(
  self : ImageLowerer,
) -> @buslane.TypeParameterId {
  let parameter : @buslane.TypeParameterId = {
    index: self.next_synthetic_parameter,
  }
  self.next_synthetic_parameter -= 1
  parameter
}

///|
