///|
fn ImageLowerer::plan(
  self : ImageLowerer,
  program : @anf.AnfProgram,
) -> @physical.FunctionId? raise PhysicalLoweringError {
  let initializers : Array[InitializerStepPlan] = []
  for term in program.terms() {
    match term {
      External(value) => self.plan_external(value)
      Let(value, expression) =>
        match extract_top_function(expression) {
          Some(function) =>
            self.add_plan(
              value,
              Function(value, function),
              TopLevelFunction(
                function=function.id,
                source=function.source,
                origin=function.origin,
              ),
            )
          None => {
            self.add_instance_global(value)
            ignore(
              self.plans.append(Initializer(source=value), fn(function) {
                let step = { function, value, expression, }
                initializers.push(step)
                InitializerStep(step)
              }),
            )
          }
        }
      LetRec(bindings) =>
        for binding in bindings {
          match extract_top_atom_function(binding.rhs) {
            Some(function) =>
              self.add_plan(
                binding.id,
                Function(binding.id, function),
                TopLevelFunction(
                  function=function.id,
                  source=function.source,
                  origin=function.origin,
                ),
              )
            None =>
              raise RepresentationElaborationInvariant(
                detail="verified Runtime ANF top-level recursion is not callable",
              )
          }
        }
    }
  }
  if initializers.is_empty() {
    None
  } else {
    let initializer = self.plans.append(InitializerOrchestrator, _ => {
        InitializerOrchestrator(initializers)
      }).function
    Some(initializer)
  }
}

///|
fn ImageLowerer::add_instance_global(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> Unit raise PhysicalLoweringError {
  let type_ = self.metadata.verified_value_info(value).type_
  if self.runtime_type(type_) is Concrete(Unit) {
    self.globals.push({ value, lowered: UnitValue, })
    return
  }
  let metadata = self.slot_metadata(type_)
  let global : @physical.GlobalId = { value: self.instance_globals.length(), }
  self.instance_globals.push({
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    kind: metadata.kind,
    erased_companion: None,
  })
  self.globals.push({ value, lowered: InstanceGlobal(global, type_), })
}

///|
fn ImageLowerer::plan_external(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> Unit raise PhysicalLoweringError {
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
) -> Unit raise PhysicalLoweringError {
  let intrinsic = external.intrinsic()
  let type_ = self.metadata.verified_value_info(value).type_
  match intrinsic {
    F32Inf =>
      self.globals.push({ value, lowered: FloatConstant(0x7f800000, type_), })
    F32NegativeInf =>
      self.globals.push({
        value,
        lowered: FloatConstant(0xff800000U.reinterpret_as_int(), type_),
      })
    F32Nan =>
      self.globals.push({ value, lowered: FloatConstant(0x7fc00000, type_), })
    F64Inf =>
      self.globals.push({
        value,
        lowered: DoubleConstant(
          0x7ff0000000000000UL.reinterpret_as_int64(),
          type_,
        ),
      })
    F64NegativeInf =>
      self.globals.push({
        value,
        lowered: DoubleConstant(
          0xfff0000000000000UL.reinterpret_as_int64(),
          type_,
        ),
      })
    F64Nan =>
      self.globals.push({
        value,
        lowered: DoubleConstant(
          0x7ff8000000000000UL.reinterpret_as_int64(),
          type_,
        ),
      })
    _ => {
      guard intrinsic.signature() is Function(implementation~, ..) else {
        raise UnsupportedIntrinsic(name=intrinsic.name())
      }
      let (_, parameters, result) = function_type_parts(type_)
      let function_contract = { intrinsic, parameters, result, implementation, }
      match implementation {
        Direct =>
          self.globals.push({ value, lowered: Intrinsic(function_contract), })
        Fatal(..) => {
          let function = self.intrinsic_wrapper(function_contract)
          self.globals.push({ value, lowered: Function(function, type_), })
        }
      }
    }
  }
}

///|
fn ImageLowerer::plan_runtime_import(
  self : ImageLowerer,
  value : @buslane.ValueId,
  import_ : @buslane_lowering.BuslaneRuntimeImport,
) -> Unit {
  let origin = PhysicalFunctionOrigin::RuntimeImport(
    source=value,
    module_name=import_.contract.module_name,
    field_name=import_.contract.field_name,
  )
  guard import_.contract.parameters.any(parameter => parameter is GuestAddress) else {
    self.add_plan(value, RuntimeImport(import_.contract), origin)
    return
  }
  let raw = self.plans.append(origin, _ => RuntimeImport(import_.contract))
  let source_type = self.metadata.verified_value_info(value).type_
  let adapter_origin = PhysicalFunctionOrigin::RuntimeImportAdapter(
    module_name=import_.contract.module_name,
    field_name=import_.contract.field_name,
  )
  let adapter = self.plans.append(adapter_origin, _ => {
    RuntimeImportAdapter({
      import_function: raw.function,
      contract: import_.contract,
      source_type,
    })
  })
  self.globals.push({ value, lowered: Function(adapter.function, source_type), })
}

///|
fn ImageLowerer::add_plan(
  self : ImageLowerer,
  value : @buslane.ValueId,
  plan : PlannedEntry,
  origin : PhysicalFunctionOrigin,
) -> Unit {
  let function = self.plans.append(origin, _ => plan).function
  let type_ = self.metadata.verified_value_info(value).type_
  self.globals.push({ value, lowered: Function(function, type_), })
}

///|
fn ImageLowerer::find_builtin_external(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> @buslane_lowering.BuslaneBuiltinExternal? {
  for external in self.externals.builtins {
    if external.value() == value {
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
fn extract_top_generic_function(
  expression : @anf.AnfExpr,
) -> (Array[@anf.RuntimeEvidenceParameter], @anf.AnfFunction)? {
  guard expression is Atom(atom) else { return None }
  match atom {
    Function(function) => Some(([], function))
    EvidenceLambda(parameters~, body~) => {
      guard extract_top_generic_function(body) is Some((nested, function)) else {
        return None
      }
      Some((parameters + nested, function))
    }
    _ => None
  }
}

///|
fn extract_top_atom_function(atom : @anf.AnfAtom) -> @anf.AnfFunction? {
  match atom {
    Function(function) => Some(function)
    EvidenceLambda(body~, ..) => extract_top_function(body)
    _ => None
  }
}

///|
fn ImageLowerer::lower_function(
  self : ImageLowerer,
  value : @buslane.ValueId,
  function : @anf.AnfFunction,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let type_ = self.metadata.verified_value_info(value).type_
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
    ClosureEnvironment(None),
    [],
    RuntimeSubstitution::new(),
  )
}

///|
fn ImageLowerer::lower_initializer_step(
  self : ImageLowerer,
  step : InitializerStepPlan,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: RuntimeSubstitution::new(),
  }
  let result = lowerer.materialize_local(lowerer.lower_expr(step.expression))
  let (result_abi, returned) = match (self.find_global(step.value), result) {
    (Some(UnitValue), Unit) => (@physical.ResultAbi::Unit, None)
    (Some(InstanceGlobal(_, type_)), Slot(source, _)) =>
      (self.result_abi(type_), Some(source))
    _ =>
      raise RepresentationElaborationInvariant(
        detail="top-level initializer result does not match its instance global",
      )
  }
  lowerer.terminate(Return(returned))
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
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: result_abi,
    blocks,
  }
}

///|
fn ImageLowerer::lower_initializer_orchestrator(
  self : ImageLowerer,
  steps : Array[InitializerStepPlan],
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: RuntimeSubstitution::new(),
  }
  for step in steps {
    match self.find_global(step.value) {
      Some(UnitValue) =>
        lowerer.emit(CallDirect(step.function, None, [], [], None))
      Some(InstanceGlobal(global, type_)) => {
        let destination = lowerer.fresh_slot(type_)
        lowerer.emit(CallDirect(step.function, None, [], [], Some(destination)))
        lowerer.emit(InitGlobal(global, destination))
      }
      _ =>
        raise RepresentationElaborationInvariant(
          detail="top-level initializer step does not match an instance global",
        )
    }
  }
  lowerer.terminate(Return(None))
  {
    values: lowerer.values,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: Return(None),
      },
    ],
  }
}

///|
fn ImageLowerer::lower_lifted_function(
  self : ImageLowerer,
  plan : LiftedFunctionPlan,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
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
    plan.capture_abi,
    plan.recursive_functions,
    plan.substitutions,
  )
}

///|
fn ImageLowerer::lower_intrinsic_wrapper(
  self : ImageLowerer,
  plan : IntrinsicWrapperPlan,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let intrinsic = plan.contract.intrinsic
  let parameter_types = plan.contract.parameters
  let result_type = plan.contract.result
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: RuntimeSubstitution::new(),
  }
  let parameter_slots = parameter_types.map(type_ => lowerer.fresh_slot(type_))
  match plan.contract.implementation {
    Fatal(message_parameter~) => {
      let message = parameter_slots[message_parameter]
      lowerer.terminate(Fatal(message))
      {
        values: lowerer.values,
        inputs: {
          environment: None,
          witnesses: [],
          user_parameters: parameter_slots,
        },
        result: self.result_abi(result_type),
        blocks: [
          { parameters: [], instructions: [], terminator: Fatal(message), },
        ],
      }
    }
    Direct => {
      let arguments = []
      for index, slot in parameter_slots {
        arguments.push(Slot(slot, parameter_types[index]))
      }
      let result = lowerer.lower_intrinsic(plan.contract, arguments)
      guard result is Slot(result_slot, _) else {
        raise UnsupportedIntrinsic(name=intrinsic.name())
      }
      lowerer.terminate(Return(Some(result_slot)))
      {
        values: lowerer.values,
        inputs: {
          environment: None,
          witnesses: [],
          user_parameters: parameter_slots,
        },
        result: self.result_abi(result_type),
        blocks: [
          {
            parameters: [],
            instructions: lowerer.blocks[0].instructions,
            terminator: Return(Some(result_slot)),
          },
        ],
      }
    }
  }
}

///|
fn ImageLowerer::intrinsic_wrapper(
  self : ImageLowerer,
  contract : RuntimeIntrinsicFunctionContract,
) -> @physical.FunctionId {
  for wrapper in self.intrinsic_wrappers {
    if wrapper.contract == contract {
      return wrapper.function
    }
  }
  let function = self.plans.append(
      IntrinsicWrapper(name=contract.intrinsic.name()),
      fn(function) {
        let wrapper = { function, contract, }
        self.intrinsic_wrappers.push(wrapper)
        IntrinsicWrapper(wrapper)
      },
    ).function
  function
}

///|
fn ImageLowerer::fresh_synthetic_parameter(
  self : ImageLowerer,
) -> @anf.RuntimeEvidenceId {
  let id = @anf.RuntimeEvidenceId::Synthetic(self.synthetic_parameters.length())
  self.synthetic_parameters.push({ id, arity: 0, })
  id
}

///|
fn ImageLowerer::evidence_parameter(
  self : ImageLowerer,
  id : @anf.RuntimeEvidenceId,
) -> @anf.RuntimeEvidenceParameter? {
  match id {
    Projected(_) => self.metadata.evidence_parameter(id)
    Synthetic(index) => self.synthetic_parameters.get(index)
  }
}

///|
