///|
fn ImageLowerer::plan_runtime_argument_evidence(
  self : ImageLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
  argument : @anf.RuntimeArgument,
) -> RuntimeEvidencePlan raise LoisvmLoweringError {
  if parameter.arity == 0 {
    self.plan_layout_witness(argument.evidence)
  } else {
    self.plan_layout_constructor_evidence(argument.evidence)
  }
}

///|
fn ImageLowerer::plan_layout_constructor_evidence(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> RuntimeEvidencePlan raise LoisvmLoweringError {
  match evidence {
    Parameter(parameter) => Existing(parameter)
    Lambda(_, _) => {
      let plan = self.plan_layout_constructor(evidence)
      MaterializeLayoutConstructor(plan.physical_reference())
    }
    Apply(_, _) | Static(_) =>
      raise InvalidTypeApplication(
        detail="layout-constructor evidence is not a parameter or lambda",
      )
  }
}

///|
fn LayoutConstructorPlan::physical_reference(
  self : LayoutConstructorPlan,
) -> PhysicalLayoutConstructorReference {
  {
    function: self.function,
    evidence: self.evidence,
    captured_parameters: self.captured_parameters,
    environment: self.environment,
    arity: self.arity,
  }
}

///|
fn ImageLowerer::plan_layout_witness(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> RuntimeEvidencePlan raise LoisvmLoweringError {
  match evidence {
    Static(layout) => {
      let recipe = runtime_layout_recipe(layout)
      StaticLayout({ recipe, layout: self.intern_layout(recipe), })
    }
    Parameter(parameter) => Existing(parameter)
    Apply(Parameter(parameter), arguments) =>
      ApplyEvidence(
        parameter,
        arguments.map(argument => self.plan_layout_witness(argument)),
      )
    Apply(Lambda(parameters, body), arguments) => {
      let replacements = []
      for index in 0..<parameters.length().min(arguments.length()) {
        replacements.push((parameters[index].id, arguments[index]))
      }
      self.plan_layout_witness(
        substitute_runtime_evidence(body, replacements, []),
      )
    }
    Apply(_, _) =>
      raise InvalidTypeApplication(
        detail="layout evidence application has no callable constructor",
      )
    Lambda(_, _) =>
      raise InvalidTypeApplication(
        detail="layout constructor was used where a layout was required",
      )
  }
}

///|
fn substitute_runtime_evidence(
  evidence : @anf.RuntimeEvidence,
  replacements : Array[(@anf.RuntimeEvidenceId, @anf.RuntimeEvidence)],
  bound : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeEvidence {
  match evidence {
    Static(_) => evidence
    Parameter(parameter) => {
      if bound.contains(parameter) {
        return evidence
      }
      for entry in replacements {
        let (candidate, replacement) = entry
        if candidate == parameter {
          return replacement
        }
      }
      evidence
    }
    Apply(callee, arguments) =>
      Apply(
        substitute_runtime_evidence(callee, replacements, bound),
        arguments.map(argument => {
          substitute_runtime_evidence(argument, replacements, bound)
        }),
      )
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Lambda(
        parameters,
        substitute_runtime_evidence(body, replacements, nested),
      )
    }
  }
}

///|
fn FunctionLowerer::materialize_runtime_evidence(
  self : FunctionLowerer,
  plan : RuntimeEvidencePlan,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  match plan {
    Existing(parameter) => self.find_witness(parameter)
    ApplyEvidence(parameter, arguments) => {
      let evidence_arguments = arguments.map(argument => {
        self.materialize_runtime_evidence(argument)
      })
      let destination = self.fresh_metadata(layout_witness_metadata())
      self.emit(
        CallValue(
          self.find_witness(parameter),
          [],
          evidence_arguments,
          Some(destination),
        ),
      )
      destination
    }
    MaterializeLayoutConstructor(layout_constructor) =>
      self.materialize_layout_constructor(layout_constructor)
    StaticLayout(layout) => {
      let witness = self.fresh_metadata(layout_witness_metadata())
      self.emit(ConstLayout(witness, layout.layout))
      witness
    }
  }
}

///|
fn FunctionLowerer::materialize_layout_constructor(
  self : FunctionLowerer,
  plan : PhysicalLayoutConstructorReference,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let captured = plan.captured_parameters.map(parameter => {
    self.find_witness(parameter.id)
  })
  let environment = self.make_capture_environment(
    plan.environment,
    [],
    captured,
  )
  let destination = self.fresh_metadata(layout_constructor_metadata(plan.arity))
  match environment {
    None => self.emit(ConstFunction(destination, plan.function))
    Some(environment) =>
      self.emit(MakeClosure(destination, plan.function, environment))
  }
  destination
}

///|
fn ImageLowerer::planned_layout_constructor(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> LayoutConstructorPlan raise LoisvmLoweringError {
  for planned in self.plans.entries {
    if planned.entry is LayoutConstructor(plan) && plan.evidence == evidence {
      return plan
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="VM CFG emission requested an unplanned layout constructor \{Repr(evidence)}",
  )
}

///|
fn ImageLowerer::plan_layout_constructor(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> LayoutConstructorPlan raise LoisvmLoweringError {
  for planned in self.plans.entries {
    if planned.entry is LayoutConstructor(plan) && plan.evidence == evidence {
      return plan
    }
  }
  let contract = self.layout_constructor_contract(evidence)
  let members : Array[@bytecode.MemberSchema] = []
  for parameter in contract.captured_parameters {
    let metadata = runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  let environment = self.environment_contract(0, members)
  let body = self.plan_layout_witness(contract.body)
  let (_, plan) = self.plans.append_with_result(LayoutConstructor, fn(
    function,
  ) {
    let plan = {
      function,
      evidence: contract.evidence,
      parameters: contract.parameters,
      body,
      captured_parameters: contract.captured_parameters,
      environment,
      arity: contract.parameters.length(),
    }
    (LayoutConstructor(plan), plan)
  })
  plan
}

///|
fn ImageLowerer::layout_constructor_contract(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> LayoutConstructorContract raise LoisvmLoweringError {
  guard evidence is Lambda(parameters, body) else {
    raise InvalidTypeApplication(detail="layout constructor is not a lambda")
  }
  {
    evidence,
    parameters,
    body,
    captured_parameters: free_runtime_evidence_parameters(
      self,
      evidence,
      parameters.map(parameter => parameter.id),
    ),
  }
}

///|
fn free_runtime_evidence_parameters(
  image : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Array[@anf.RuntimeEvidenceParameter] {
  let ids = []
  collect_runtime_evidence_ids(evidence, bound, ids)
  ids.filter_map(id => image.evidence_parameter(id))
}

///|
fn collect_runtime_evidence_ids(
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
  ids : Array[@anf.RuntimeEvidenceId],
) -> Unit {
  match evidence {
    Static(_) => ()
    Parameter(parameter) =>
      if !bound.contains(parameter) && !ids.contains(parameter) {
        ids.push(parameter)
      }
    Apply(callee, arguments) => {
      collect_runtime_evidence_ids(callee, bound, ids)
      for argument in arguments {
        collect_runtime_evidence_ids(argument, bound, ids)
      }
    }
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      collect_runtime_evidence_ids(body, nested, ids)
    }
  }
}

///|
fn lower_layout_constructor(
  physical_program : PhysicalAnfProgram,
  plan : LayoutConstructorPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let lowerer : FunctionLowerer = {
    physical_program,
    function: Some(plan.function),
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    physical: None,
    adapter_support: None,
  }
  let evidence_parameters = []
  for parameter in plan.parameters {
    let evidence = lowerer.fresh_metadata(runtime_evidence_metadata(parameter))
    evidence_parameters.push(evidence)
    lowerer.witnesses.push({ parameter: parameter.id, value: evidence, })
  }
  if plan.environment is Some(contract) {
    let environment = lowerer.fresh_metadata(
      environment_metadata(contract.shape),
    )
    lowerer.environment = Some(environment)
    for index, parameter in plan.captured_parameters {
      let metadata = runtime_evidence_metadata(parameter)
      let evidence = lowerer.fresh_metadata(
        borrowed_evidence_metadata(metadata),
      )
      lowerer.emit(
        BorrowCapture(contract.shape, environment, index, {
          value_destination: evidence,
          witness_destination: None,
        }),
      )
      lowerer.witnesses.push({ parameter: parameter.id, value: evidence, })
    }
  }
  let result = lowerer.materialize_runtime_evidence(plan.body)
  lowerer.terminate(Return(Some(result)))
  let blocks : Array[@vmcfg.Block] = []
  for index, block in lowerer.blocks {
    guard block.terminator is Some(terminator) else {
      raise UnterminatedBlock(block=index)
    }
    blocks.push({
      parameters: block.parameters,
      instructions: block.instructions,
      terminator,
    })
  }
  {
    values: lowerer.values,
    inputs: {
      environment: lowerer.environment,
      witnesses: [],
      user_parameters: evidence_parameters,
    },
    result: Value(I32, Trivial, LayoutValue),
    blocks,
  }
}

///|
fn runtime_layout_recipe(layout : @anf.RuntimeLayout) -> @bytecode.LayoutRecipe {
  match layout {
    Unit => Unit
    Bool => Bool
    I64 => I64
    I32 => I32
    Char => Char
    F64 => F64
    F32 => F32
    Byte => Byte
    ByteSequence => ByteSequence
    Reference => Reference
    Callable => Callable
  }
}
