///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> CallableAdapterPlan {
  for adapter in self.callable_adapters {
    if adapter.contract.recipe == contract.recipe {
      return adapter
    }
  }
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
  members.push({
    representation: I64,
    cleanup: OwnedCallable,
    kind: CallableValue,
    witness_ordinal: None,
  })
  let environment_shape = self.intern_object_shape(
    Environment({ stored_witness_count: 0, members }),
  )
  let (_, adapter) = self.plans.append_with_result(CallableAdapter, fn(
    function,
  ) {
    let adapter : CallableAdapterPlan = {
      function,
      contract,
      environment_shape,
    }
    self.callable_adapters.push(adapter)
    (CallableAdapter(adapter), adapter)
  })
  adapter
}

///|
fn free_runtime_type_parameters(
  image : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
) -> Array[@anf.RuntimeEvidenceParameter] {
  free_runtime_type_parameters_in_types(image, [source_type, target_type])
}

///|
fn free_runtime_type_parameters_in_types(
  image : ImageLowerer,
  types : Array[@anf.RuntimeType],
) -> Array[@anf.RuntimeEvidenceParameter] {
  let parameters = []
  for type_ in types {
    collect_free_runtime_type_parameters(image, type_, [], parameters)
  }
  parameters
}

///|
fn collect_free_runtime_type_parameters(
  image : ImageLowerer,
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => ()
    Erased(expression, evidence) => {
      collect_free_runtime_type_expression(image, expression, bound, parameters)
      collect_free_runtime_evidence(image, evidence, bound, parameters)
    }
    Data(_, arguments) =>
      for argument in arguments {
        collect_free_runtime_type_expression(
          image,
          argument.type_expression,
          bound,
          parameters,
        )
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
    Forall(type_parameters, body) => {
      let nested_bound = bound.copy()
      nested_bound.append(type_parameters.map(parameter => parameter.id))
      collect_free_runtime_type_parameters(
        image, body, nested_bound, parameters,
      )
    }
    Callable(arguments, result) => {
      for argument in arguments {
        collect_free_runtime_type_parameters(image, argument, bound, parameters)
      }
      collect_free_runtime_type_parameters(image, result, bound, parameters)
    }
  }
}

///|
fn collect_free_runtime_type_expression(
  image : ImageLowerer,
  expression : @anf.RuntimeTypeExpressionId,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  guard image.runtime_types.type_expression(expression) is Some(node) else {
    return
  }
  match node {
    Static(type_) =>
      collect_free_runtime_type_parameters(image, type_, bound, parameters)
    Parameter(parameter) =>
      collect_free_runtime_evidence(
        image,
        Parameter(parameter),
        bound,
        parameters,
      )
    Apply(callee, arguments) => {
      collect_free_runtime_type_expression(image, callee, bound, parameters)
      for argument in arguments {
        collect_free_runtime_type_expression(image, argument, bound, parameters)
      }
    }
    Lambda(binders, body) => {
      let nested = bound.copy()
      nested.append(binders.map(binder => binder.id))
      collect_free_runtime_type_expression(image, body, nested, parameters)
    }
  }
}

///|
fn collect_free_runtime_evidence(
  image : ImageLowerer,
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match evidence {
    Static(_) => ()
    Parameter(id) =>
      if !bound.contains(id) && !parameters.any(parameter => parameter.id == id) {
        parameters.push(
          image.evidence_parameter(id).unwrap_or({ id, arity: 0 }),
        )
      }
    Apply(callee, arguments) => {
      collect_free_runtime_evidence(image, callee, bound, parameters)
      for argument in arguments {
        collect_free_runtime_evidence(image, argument, bound, parameters)
      }
    }
    Lambda(binders, body) => {
      let nested = bound.copy()
      nested.append(binders.map(binder => binder.id))
      collect_free_runtime_evidence(image, body, nested, parameters)
    }
  }
}

///|
fn ImageLowerer::canonical_callable_type(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> (@anf.RuntimeType, RuntimeSubstitution) raise LoisvmLoweringError {
  let bindings = RuntimeSubstitution::new()
  let canonical = self.canonical_callable_type_with_bound(type_, [], bindings)
  (canonical, bindings)
}

///|
fn ImageLowerer::canonical_callable_type_with_bound(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
  bindings : RuntimeSubstitution,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  match type_ {
    Forall(parameters, body) => {
      let nested_bound = bound.copy()
      nested_bound.append(parameters.map(parameter => parameter.id))
      Forall(
        parameters,
        self.canonical_callable_type_with_bound(body, nested_bound, bindings),
      )
    }
    Callable(parameters, result) =>
      Callable(
        parameters.map(type_ => {
          self.canonical_callable_value_type(type_, bound, bindings)
        }),
        self.canonical_callable_value_type(result, bound, bindings),
      )
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn ImageLowerer::canonical_callable_value_type(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
  bindings : RuntimeSubstitution,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  if self.runtime_type(type_) is Concrete(Unit) {
    return type_
  }
  if self.runtime_type(type_) is Erased(Parameter(parameter)) &&
    bound.contains(parameter) {
    return type_
  }
  let parameter = self.fresh_synthetic_parameter()
  let expression = match type_ {
    Erased(expression, _) => expression
    _ => self.runtime_types.intern(Static(type_))
  }
  let evidence = runtime_type_evidence(type_)
  bindings.insert(parameter, { type_expression: expression, evidence })
  Erased(expression, Parameter(parameter))
}

///|
fn runtime_type_evidence(
  type_ : @anf.RuntimeType,
) -> @anf.RuntimeEvidence raise LoisvmLoweringError {
  match type_ {
    Erased(_, evidence) => evidence
    _ =>
      match type_.layout() {
        Some(layout) => Static(layout)
        None => raise UnsupportedType(type_~)
      }
  }
}

///|
fn FunctionLowerer::adapter_witness(
  self : FunctionLowerer,
  parameter : @anf.RuntimeEvidenceId,
  substitutions : RuntimeSubstitution,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if substitutions.argument(parameter) is Some(argument) {
    let parameter_info = self.image.metadata
      .evidence_parameter(parameter)
      .unwrap_or({ id: parameter, arity: 0 })
    return self.runtime_evidence(parameter_info, argument)
  }
  self.find_witness(parameter)
}

///|
fn FunctionLowerer::make_callable_adapter(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> LocalValue raise LoisvmLoweringError {
  guard self.image.plan_callable_adaptation(
      source_type, target_type, substitutions,
    )
    is Some(contract) else {
    return Slot(source, target_type)
  }
  AdaptedCallable({
    source,
    contract,
    captured_witnesses: contract.captured_parameters.map(parameter => {
      parameter: parameter.id,
      value: self.adapter_witness(parameter.id, contract.substitutions),
    }),
  })
}

///|
fn ImageLowerer::plan_callable_adaptation(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  if self.types_representation_equivalent(source_type, target_type) {
    return None
  }
  let (source_parameter_targets, adapter_substitutions) = self.align_callable_parameters(
    source_type, target_type, substitutions,
  )
  let (_, _, source_result) = function_type_parts(source_type)
  let (_, _, target_result) = function_type_parts(target_type)
  if self.types_representation_equivalent(
      adapter_substitutions.apply_type(self.runtime_types, source_result),
      adapter_substitutions.apply_type(self.runtime_types, target_result),
    ) &&
    self.callable_types_share_runtime_abi(
      source_type, target_type, adapter_substitutions,
    ) {
    return None
  }
  let captured_parameters = free_runtime_type_parameters(
    self, source_type, target_type,
  )
  Some({
    recipe: self.callable_adapter_recipe(
      source_type, target_type, source_parameter_targets, adapter_substitutions,
      captured_parameters,
    ),
    source_type,
    target_type,
    source_parameter_targets,
    substitutions: adapter_substitutions,
    captured_parameters,
  })
}

///|
fn FunctionLowerer::materialize_callable_adapter(
  self : FunctionLowerer,
  adaptation : DeferredCallableAdapter,
) -> LocalValue raise LoisvmLoweringError {
  let plan = self.image.callable_adapter(adaptation.contract)
  let witnesses = adaptation.captured_witnesses.map(binding => binding.value)
  let environment = self.fresh_metadata(
    environment_metadata(plan.environment_shape),
  )
  let environment_layout = self.image.intern_layout(
    Environment(plan.environment_shape),
  )
  self.emit(
    MakeEnv(
      environment,
      plan.environment_shape,
      Immediate(environment_layout),
      [],
      witnesses + [adaptation.source],
    ),
  )
  let callable = self.fresh_slot(adaptation.contract.target_type)
  self.emit(MakeClosure(callable, plan.function, environment))
  Slot(callable, adaptation.contract.target_type)
}

///|
/// Align source parameters with target ABI parameters after substitution.
/// Only a target that classifies as Unit may be skipped; every other pair must
/// be definitionally equal. The returned substitution is final: alignment
/// creates it, the adapter plan takes ownership, and subsequent lowering only
/// reads it.
fn ImageLowerer::align_callable_parameters(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> (Array[Int], RuntimeSubstitution) raise LoisvmLoweringError {
  let (source_type_parameters, source_parameters, _) = function_type_parts(
    source_type,
  )
  let (target_type_parameters, target_parameters, _) = function_type_parts(
    target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target type arities differ",
    )
  }
  let alignment = RuntimeSubstitution::new()
  for index, target_parameter in target_type_parameters {
    let source_parameter = source_type_parameters[index]
    guard self.metadata.parameter_type_expression(source_parameter.id)
      is Some(type_expression) else {
      raise InvalidTypeApplication(
        detail="callable evidence parameter has no runtime type expression",
      )
    }
    alignment.insert(target_parameter.id, {
      type_expression,
      evidence: Parameter(source_parameter.id),
    })
  }
  let alignment_substitutions = substitutions.overlay(alignment)
  let source_parameter_targets = []
  let mut source_index = 0
  for target_index, target_parameter in target_parameters {
    let actual_target = alignment_substitutions.apply_type(
      self.runtime_types,
      target_parameter,
    )
    if self.runtime_type(actual_target) is Concrete(Unit) {
      if source_index < source_parameters.length() {
        let actual_source = substitutions.apply_type(
          self.runtime_types,
          source_parameters[source_index],
        )
        if self.runtime_type(actual_source) is Concrete(Unit) &&
          self.types_representation_equivalent(actual_source, actual_target) {
          source_parameter_targets.push(target_index)
          source_index += 1
        }
      }
      continue
    }
    if source_index >= source_parameters.length() {
      raise InvalidTypeApplication(
        detail="callable adapter source parameter \{source_index}/\{source_parameters.length()} does not align with target parameter \{target_index}/\{target_parameters.length()}",
      )
    }
    let actual_source = substitutions.apply_type(
      self.runtime_types,
      source_parameters[source_index],
    )
    if !self.types_representation_equivalent(actual_source, actual_target) {
      raise InvalidTypeApplication(
        detail="callable adapter source parameter \{source_index}/\{source_parameters.length()} (\{Repr(actual_source)}) does not align with target parameter \{target_index}/\{target_parameters.length()} (\{Repr(actual_target)})",
      )
    }
    source_parameter_targets.push(target_index)
    source_index += 1
  }
  if source_index != source_parameters.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target parameters cannot be aligned",
    )
  }
  (source_parameter_targets, alignment_substitutions)
}

///|
fn FunctionLowerer::adapt_local_value_with_substitutions(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> LocalValue raise LoisvmLoweringError {
  let source_value_type = match local_value_type(value) {
    Some(type_) => type_
    None => source_type
  }
  let source_shape = substitutions.apply_type(
    self.image.runtime_types,
    source_value_type,
  )
  let target_shape = substitutions.apply_type(
    self.image.runtime_types,
    target_type,
  )
  let source_runtime = self.image.runtime_type(source_type)
  let target_runtime = self.image.runtime_type(target_type)
  let source_is_erased = match value {
    Slot(slot, _) => self.values[slot.value].erased_companion is Some(_)
    _ => source_runtime is Erased(_)
  }
  match (source_is_erased, target_runtime is Erased(_)) {
    (true, true) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      return Slot(slot, target_type)
    }
    (false, true) => {
      let witness = self.layout_witness(runtime_type_evidence(source_shape))
      return Slot(self.erase_value(value, source_shape, witness), target_type)
    }
    (true, false) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      return self.unerase_value(slot, target_type, substitutions)
    }
    _ => ()
  }
  if self.image.runtime_type(source_shape) is Concrete(Unit) &&
    self.image.runtime_type(target_shape) is Concrete(Unit) {
    return Unit
  }
  guard self.image.runtime_type(source_shape) is Concrete(source_runtime_type) &&
    self.image.runtime_type(target_shape) is Concrete(target_runtime_type) else {
    raise InvalidTypeApplication(
      detail="value adaptation reached an unresolved erased representation",
    )
  }
  match (source_runtime_type, target_runtime_type) {
    (Callable(_, _) | Forall(_, _), Callable(_, _) | Forall(_, _)) => {
      let source_callable_type = match
        self.image.runtime_type(source_value_type) {
        Concrete(Callable(_, _) | Forall(_, _) as type_) => type_
        _ => source_runtime_type
      }
      let target_callable_type = match self.image.runtime_type(target_type) {
        Concrete(Callable(_, _) | Forall(_, _) as type_) => type_
        _ => target_runtime_type
      }
      if self.image.types_representation_equivalent(source_shape, target_shape) &&
        self.image.callable_types_share_runtime_abi(
          source_callable_type, target_callable_type, substitutions,
        ) {
        return match value {
          Slot(slot, _) => Slot(slot, target_shape)
          _ => value
        }
      }
      guard self.materialize_local(value) is Slot(source, _) else {
        raise InvalidTypeApplication(
          detail="callable value is not materialized",
        )
      }
      self.make_callable_adapter(
        source, source_callable_type, target_callable_type, substitutions,
      )
    }
    _ => {
      if self.image.types_representation_equivalent(source_shape, target_shape) {
        return match value {
          Unit => Unit
          Slot(slot, _) => Slot(slot, target_shape)
          _ => value
        }
      }
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="adapted value is not materialized")
      }
      let source_metadata = self.image.slot_metadata(source_runtime_type)
      let target_metadata = self.image.slot_metadata(target_runtime_type)
      if source_metadata.representation != target_metadata.representation ||
        source_metadata.cleanup != target_metadata.cleanup {
        raise InvalidTypeApplication(
          detail="callable adapter cannot bridge incompatible value representations",
        )
      }
      Slot(slot, target_runtime_type)
    }
  }
}

///|
fn ImageLowerer::callable_types_share_runtime_abi(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> Bool raise LoisvmLoweringError {
  self.canonical_callable_abi_under(source_type, substitutions) ==
  self.canonical_callable_abi_under(target_type, substitutions)
}

///|
fn local_value_type(value : LocalValue) -> @anf.RuntimeType? {
  match value {
    Slot(_, type_) => Some(type_)
    ClosedAggregate(contract, _) => Some(contract.type_)
    Global(Function(_, type_))
    | Global(FloatConstant(_, type_))
    | Global(DoubleConstant(_, type_))
    | Global(InstanceGlobal(_, type_)) => Some(type_)
    Global(Intrinsic(contract)) => Some(contract.type_())
    RecursiveFunction(_, type_, _) | EvidenceAppliedCallable(_, type_, _) =>
      Some(type_)
    NestedCallable(callable) | EvidenceAppliedNestedCallable(callable, _) =>
      Some(callable.type_)
    AdaptedCallable(adaptation)
    | EvidenceAppliedAdaptedCallable(adaptation, _) =>
      Some(adaptation.contract.target_type)
    Global(UnitValue) | Unit | EvidenceApplied(_, _) => None
  }
}

///|
fn ImageLowerer::lower_callable_adapter(
  self : ImageLowerer,
  plan : CallableAdapterPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let contract = plan.contract
  let (source_type_parameters, source_parameter_types, source_result_type) = function_type_parts(
    contract.source_type,
  )
  let (target_type_parameters, target_parameter_types, target_result_type) = function_type_parts(
    contract.target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() ||
    contract.source_parameter_targets.length() !=
    source_parameter_types.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target arities differ",
    )
  }
  let lowerer : FunctionLowerer = {
    image: self,
    caller_instances: [-1],
    data_families: [],
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: contract.substitutions,
    specialized_parameters: [],
    representation_worker: false,
  }
  let input_witnesses = []
  for index, parameter in target_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let witness = lowerer.fresh_metadata(runtime_evidence_metadata(parameter))
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter: parameter.id, value: witness })
      let source_parameter = source_type_parameters[index]
      if source_parameter.id != parameter.id {
        lowerer.witnesses.push({
          parameter: source_parameter.id,
          value: witness,
        })
      }
    }
  }
  let environment = lowerer.fresh_metadata(
    environment_metadata(plan.environment_shape),
  )
  lowerer.environment = Some(environment)
  for index, parameter in contract.captured_parameters {
    let metadata = runtime_evidence_metadata(parameter)
    let witness = lowerer.fresh_metadata(borrowed_evidence_metadata(metadata))
    lowerer.emit(
      BorrowCapture(plan.environment_shape, environment, index, {
        value_destination: witness,
        witness_destination: None,
      }),
    )
    lowerer.witnesses.push({ parameter: parameter.id, value: witness })
  }
  let source_callable = lowerer.fresh_borrowed_slot(contract.source_type)
  lowerer.emit(
    BorrowCapture(
      plan.environment_shape,
      environment,
      contract.captured_parameters.length(),
      { value_destination: source_callable, witness_destination: None },
    ),
  )
  let target_parameters : Array[LocalValue] = []
  let user_parameter_slots = []
  for type_ in target_parameter_types {
    if self.runtime_type(type_) is Concrete(Unit) {
      target_parameters.push(Unit)
    } else {
      let slot = lowerer.fresh_slot(type_)
      user_parameter_slots.push(slot)
      target_parameters.push(Slot(slot, type_))
    }
  }
  let source_arguments = []
  for index, source_parameter_type in source_parameter_types {
    let target_index = contract.source_parameter_targets[index]
    let adapted = lowerer.materialize_local(
      lowerer.adapt_local_value_with_substitutions(
        target_parameters[target_index],
        target_parameter_types[target_index],
        source_parameter_type,
        contract.substitutions,
      ),
    )
    if adapted is Slot(slot, _) {
      source_arguments.push(slot)
    }
  }
  let call_witnesses = []
  for parameter in source_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      call_witnesses.push(lowerer.find_witness(parameter.id))
    }
  }
  if self.types_representation_equivalent(
      source_result_type, target_result_type,
    ) {
    lowerer.terminate(
      TailCallValue(source_callable, call_witnesses, source_arguments),
    )
  } else {
    let source_result = lowerer.fresh_optional_slot(source_result_type)
    lowerer.emit(
      CallValue(
        source_callable,
        call_witnesses,
        source_arguments,
        source_result.0,
      ),
    )
    let result = lowerer.materialize_local(
      lowerer.adapt_local_value_with_substitutions(
        source_result.1,
        source_result_type,
        target_result_type,
        contract.substitutions,
      ),
    )
    lowerer.terminate(
      match result {
        Unit => Return(None)
        Slot(slot, _) => Return(Some(slot))
        _ =>
          raise InvalidTypeApplication(
            detail="callable adapter result is not materialized",
          )
      },
    )
  }
  {
    values: lowerer.values,
    inputs: {
      environment: Some(environment),
      witnesses: input_witnesses,
      user_parameters: user_parameter_slots,
    },
    result: self.result_abi(target_result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: lowerer.blocks[0].terminator.unwrap(),
      },
    ],
  }
}
