///|
fn FunctionLowerer::apply_layout_constructor(
  self : FunctionLowerer,
  constructor_parameter : @buslane.TypeParameterId,
  arguments : Array[@buslane.GenericArgument],
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  guard self.image.metadata.type_parameter_info(constructor_parameter)
    is Some({ kind: Function(parameter_kinds, Type), .. }) else {
    raise UnsupportedType(type_=Parameter(constructor_parameter))
  }
  if parameter_kinds.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="layout constructor argument count does not match its kind",
    )
  }
  let evidence_arguments = []
  for index, kind in parameter_kinds {
    guard kind_requires_runtime_evidence(kind) else { continue }
    guard arguments[index] is TypeArgument(type_) else {
      raise InvalidTypeApplication(
        detail="layout constructor requires a type argument at position \{index}",
      )
    }
    match kind {
      Type => evidence_arguments.push(self.layout_witness(type_))
      Function(_, Type) =>
        evidence_arguments.push(self.layout_constructor(type_))
      _ =>
        raise InvalidTypeApplication(
          detail="layout constructor argument has an unsupported evidence kind",
        )
    }
  }
  let destination = self.fresh_metadata(layout_witness_metadata())
  self.emit(
    CallValue(
      self.find_witness(constructor_parameter),
      [],
      evidence_arguments,
      Some(destination),
    ),
  )
  destination
}

///|
fn FunctionLowerer::runtime_evidence(
  self : FunctionLowerer,
  parameter : @buslane.TypeParameterId,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  guard self.image.metadata.type_parameter_info(parameter) is Some(info) else {
    if parameter.index < 0 {
      return self.layout_witness(type_)
    }
    raise UnsupportedType(type_=Parameter(parameter))
  }
  match info.kind {
    Type => self.layout_witness(type_)
    Function(_, Type) => self.layout_constructor(type_)
    _ => raise UnsupportedType(type_=Parameter(parameter))
  }
}

///|
fn FunctionLowerer::layout_constructor(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let type_ = type_.normalize() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
  match type_ {
    Parameter(parameter) => self.find_witness(parameter)
    TypeLambda(_, _) => self.materialize_layout_constructor(type_)
    Constructor(owner) => {
      guard self.image.metadata.type_info(owner) is Some(info) else {
        raise UnsupportedType(type_~)
      }
      let arguments = info.parameters.map(parameter => {
        guard self.image.metadata.type_parameter_info(parameter) is Some(info) else {
          return @buslane.GenericArgument::TypeArgument(Parameter(parameter))
        }
        match info.kind {
          Effect => EffectArgument(Parameter(parameter))
          _ => TypeArgument(Parameter(parameter))
        }
      })
      let body = if arguments.is_empty() {
        @buslane.Type::Constructor(owner)
      } else {
        Apply(Constructor(owner), arguments)
      }
      self.materialize_layout_constructor(TypeLambda(info.parameters, body))
    }
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn FunctionLowerer::materialize_layout_constructor(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let plan = self.image.plan_layout_constructor(type_)
  let captured = plan.captured_parameters.map(parameter => {
    self.find_witness(parameter)
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
  type_ : @buslane.Type,
) -> LayoutConstructorPlan raise LoisvmLoweringError {
  for planned in self.plans.entries {
    if planned.entry is LayoutConstructor(plan) && plan.type_ == type_ {
      return plan
    }
  }
  guard type_ is TypeLambda(parameters, body) else {
    raise UnsupportedType(type_~)
  }
  let captured_parameters = free_runtime_type_parameters_in_types(self, [type_])
  let members : Array[@bytecode.MemberSchema] = []
  for parameter in captured_parameters {
    let metadata = self.runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  let environment_shape = self.environment_shape(0, members)
  let parameter_kinds = parameters.map(parameter => {
    match self.metadata.type_parameter_info(parameter) {
      Some(info) => info.kind
      None => @buslane.Kind::Type
    }
  })
  let (_, plan) = self.plans.append_with_result(LayoutConstructor, fn(
    function,
  ) {
    let plan = {
      function,
      type_,
      parameters,
      body,
      captured_parameters,
      environment_shape,
      arity: runtime_evidence_arity(parameter_kinds),
    }
    (LayoutConstructor(plan), plan)
  })
  plan
}

///|
fn ImageLowerer::lower_layout_constructor(
  self : ImageLowerer,
  plan : LayoutConstructorPlan,
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
    substitutions: TypeSubstitution(),
  }
  let evidence_parameters = []
  for parameter in plan.parameters {
    guard self.requires_runtime_evidence(parameter) else { continue }
    let evidence = lowerer.fresh_metadata(
      self.runtime_evidence_metadata(parameter),
    )
    evidence_parameters.push(evidence)
    lowerer.witnesses.push({ parameter, value: evidence })
  }
  if plan.environment_shape is Some(shape) {
    let environment = lowerer.fresh_metadata(environment_metadata(shape))
    lowerer.environment = Some(environment)
    for index, parameter in plan.captured_parameters {
      let metadata = self.runtime_evidence_metadata(parameter)
      let evidence = lowerer.fresh_metadata(
        borrowed_evidence_metadata(metadata),
      )
      lowerer.emit(
        BorrowCapture(shape, environment, index, {
          value_destination: evidence,
          witness_destination: None,
        }),
      )
      lowerer.witnesses.push({ parameter, value: evidence })
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
