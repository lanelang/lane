///|
fn FunctionLowerer::runtime_evidence(
  self : FunctionLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
  argument : @anf.RuntimeArgument,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if parameter.arity == 0 {
    self.layout_witness(argument.evidence)
  } else {
    self.materialize_runtime_evidence(
      self.image.plan_layout_constructor_evidence(argument.evidence),
    )
  }
}

///|
fn ImageLowerer::plan_layout_constructor_evidence(
  _self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> RuntimeEvidencePlan raise LoisvmLoweringError {
  match evidence {
    Parameter(parameter) => Existing(parameter)
    Lambda(_, _) => MaterializeLayoutConstructor(evidence)
    Apply(_, _) | Static(_) =>
      raise InvalidTypeApplication(
        detail="layout-constructor evidence is not a parameter or lambda",
      )
  }
}

///|
fn ImageLowerer::plan_layout_witness(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> RuntimeEvidencePlan raise LoisvmLoweringError {
  match evidence {
    Static(layout) => StaticLayout(runtime_layout_recipe(layout))
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
    MaterializeLayoutConstructor(evidence) =>
      self.materialize_layout_constructor(evidence)
    StaticLayout(recipe) => {
      let layout = self.image.intern_layout(recipe)
      let witness = self.fresh_metadata(layout_witness_metadata())
      self.emit(ConstLayout(witness, layout))
      witness
    }
  }
}

///|
fn FunctionLowerer::materialize_layout_constructor(
  self : FunctionLowerer,
  evidence : @anf.RuntimeEvidence,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let plan = self.image.plan_layout_constructor(evidence)
  let captured = plan.captured_parameters.map(parameter => {
    self.find_witness(parameter.id)
  })
  let environment = self.make_capture_environment(
    plan.environment_shape,
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
fn ImageLowerer::plan_layout_constructor(
  self : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
) -> LayoutConstructorPlan raise LoisvmLoweringError {
  for planned in self.plans.entries {
    if planned.entry is LayoutConstructor(plan) && plan.evidence == evidence {
      return plan
    }
  }
  guard evidence is Lambda(parameters, body) else {
    raise InvalidTypeApplication(detail="layout constructor is not a lambda")
  }
  let captured_parameters = free_runtime_evidence_parameters(
    self,
    evidence,
    parameters.map(parameter => parameter.id),
  )
  let members : Array[@bytecode.MemberSchema] = []
  for parameter in captured_parameters {
    let metadata = runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  let environment_shape = self.environment_shape(0, members)
  let (_, plan) = self.plans.append_with_result(LayoutConstructor, fn(
    function,
  ) {
    let plan = {
      function,
      evidence,
      parameters,
      body,
      captured_parameters,
      environment_shape,
      arity: parameters.length(),
    }
    (LayoutConstructor(plan), plan)
  })
  plan
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
fn ImageLowerer::lower_layout_constructor(
  self : ImageLowerer,
  plan : LayoutConstructorPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    caller_instances: [-1],
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: RuntimeSubstitution::new(),
    specialized_parameters: [],
  }
  let evidence_parameters = []
  for parameter in plan.parameters {
    let evidence = lowerer.fresh_metadata(runtime_evidence_metadata(parameter))
    evidence_parameters.push(evidence)
    lowerer.witnesses.push({ parameter: parameter.id, value: evidence })
  }
  if plan.environment_shape is Some(shape) {
    let environment = lowerer.fresh_metadata(environment_metadata(shape))
    lowerer.environment = Some(environment)
    for index, parameter in plan.captured_parameters {
      let metadata = runtime_evidence_metadata(parameter)
      let evidence = lowerer.fresh_metadata(
        borrowed_evidence_metadata(metadata),
      )
      lowerer.emit(
        BorrowCapture(shape, environment, index, {
          value_destination: evidence,
          witness_destination: None,
        }),
      )
      lowerer.witnesses.push({ parameter: parameter.id, value: evidence })
    }
  }
  let result = lowerer.layout_witness(plan.body)
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

///|
fn concrete_layout_recipe(
  type_ : @anf.RuntimeType,
) -> @bytecode.LayoutRecipe raise LoisvmLoweringError {
  match type_.layout() {
    Some(layout) => runtime_layout_recipe(layout)
    None => raise UnsupportedType(type_~)
  }
}
