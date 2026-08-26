///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> CallableAdapterPlan {
  self.callable_adapter_plan(contract.recipe)
}

///|
fn ImageLowerer::callable_adapter_plan(
  self : ImageLowerer,
  recipe : CallableAdapterRecipe,
) -> CallableAdapterPlan {
  for adapter in self.callable_adapters {
    if adapter.recipe == recipe {
      return adapter
    }
  }
  let members : Array[@bytecode.MemberSchema] = []
  for evidence in recipe.captured_evidence {
    members.push({
      representation: evidence.representation,
      cleanup: evidence.cleanup,
      kind: evidence.kind,
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
    Environment({ stored_witness_count: 0, members, }),
  )
  let (_, adapter) = self.plans.append_with_result(CallableAdapter, fn(
    function,
  ) {
    let adapter : CallableAdapterPlan = { function, recipe, environment_shape, }
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
    Erased(_, evidence) =>
      collect_free_runtime_evidence(image, evidence, bound, parameters)
    Data(_, _) => ()
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
          image.evidence_parameter(id).unwrap_or({ id, arity: 0, }),
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
  bindings.insert(parameter, { type_expression: expression, evidence, })
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
      .unwrap_or({ id: parameter, arity: 0, })
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
    target_type,
    substitutions: adapter_substitutions,
    captured_parameters,
  })
}

///|
fn ImageLowerer::plan_applied_callable_adaptation(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CallableAdapterContract raise LoisvmLoweringError {
  let (_, source_parameters, _) = function_type_parts(source_type)
  let (_, target_parameters, _) = function_type_parts(target_type)
  let source_parameter_targets = self.align_callable_value_parameters(
    source_parameters, target_parameters, substitutions,
  )
  let captured_parameters = free_runtime_type_parameters(
    self, source_type, target_type,
  )
  for entry in substitutions.entries {
    let (_, argument) = entry
    collect_free_runtime_evidence(
      self,
      argument.evidence,
      [],
      captured_parameters,
    )
  }
  {
    recipe: self.callable_adapter_recipe(
      source_type, target_type, source_parameter_targets, substitutions, captured_parameters,
    ),
    target_type,
    substitutions,
    captured_parameters,
  }
}

///|
fn FunctionLowerer::materialize_applied_callable(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  source_type : @anf.RuntimeType,
  arguments : Array[@anf.RuntimeArgument],
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, _, _) = function_type_parts(source_type)
  let substitutions = self.call_type_substitution(parameters, arguments)
  let target_type = substitutions.apply_type(
    self.image.runtime_types,
    callable_body_type(source_type),
  )
  let contract = self.image.plan_applied_callable_adaptation(
    source_type, target_type, substitutions,
  )
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
fn callable_body_type(
  type_ : @anf.RuntimeType,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  match type_ {
    Forall(_, body) => callable_body_type(body)
    Callable(_, _) => type_
    _ => raise UnsupportedType(type_~)
  }
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
  (
    self.align_callable_value_parameters(
      source_parameters, target_parameters, alignment_substitutions,
    ),
    alignment_substitutions,
  )
}

///|
fn ImageLowerer::align_callable_value_parameters(
  self : ImageLowerer,
  source_parameters : Array[@anf.RuntimeType],
  target_parameters : Array[@anf.RuntimeType],
  substitutions : RuntimeSubstitution,
) -> Array[Int] raise LoisvmLoweringError {
  let source_parameter_targets = []
  let mut source_index = 0
  for target_index, target_parameter in target_parameters {
    let actual_target = substitutions.apply_type(
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
  source_parameter_targets
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
    Global(Function(_, type_))
    | Global(FloatConstant(_, type_))
    | Global(DoubleConstant(_, type_))
    | Global(InstanceGlobal(_, type_)) => Some(type_)
    Global(Intrinsic(contract)) => Some(contract.type_())
    RecursiveFunction(_, type_, _) | EvidenceAppliedCallable(_, type_, _) =>
      Some(type_)
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
  let recipe = plan.recipe
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
  let input_witnesses = []
  for witness in recipe.target_abi.witnesses {
    input_witnesses.push(
      lowerer.fresh_metadata(
        adapter_value_metadata(Value(witness), None, Owned),
      ),
    )
  }
  let environment = lowerer.fresh_metadata(
    environment_metadata(plan.environment_shape),
  )
  lowerer.environment = Some(environment)
  let captured_evidence = []
  for index, evidence in recipe.captured_evidence {
    let witness = lowerer.fresh_metadata(
      adapter_value_metadata(Value(evidence), None, Borrowed),
    )
    lowerer.emit(
      BorrowCapture(plan.environment_shape, environment, index, {
        value_destination: witness,
        witness_destination: None,
      }),
    )
    captured_evidence.push(witness)
  }
  let source_callable = lowerer.fresh_metadata(
    adapter_value_metadata(Callable(recipe.source_abi), None, Borrowed),
  )
  lowerer.emit(
    BorrowCapture(
      plan.environment_shape,
      environment,
      recipe.captured_evidence.length(),
      { value_destination: source_callable, witness_destination: None, },
    ),
  )
  let user_parameter_slots = []
  for parameter in recipe.target_parameters {
    guard lowerer.fresh_callable_adapter_value(
        parameter, input_witnesses, captured_evidence,
      )
      is Some(slot) else {
      raise InvalidTypeApplication(
        detail="callable adapter has a Unit physical parameter",
      )
    }
    user_parameter_slots.push(slot)
  }
  let source_arguments = []
  for argument in recipe.source_arguments {
    let input = match argument.target {
      Some(target) =>
        match user_parameter_slots.get(target) {
          Some(input) => Some(input)
          None =>
            raise InvalidTypeApplication(
              detail="callable adapter source argument selects a missing input",
            )
        }
      None => None
    }
    match
      lowerer.adapt_callable_adapter_value(
        input,
        argument.flow,
        input_witnesses,
        captured_evidence,
      ) {
      Some(adapted) => source_arguments.push(adapted)
      None => ()
    }
  }
  let source_witnesses = recipe.source_witnesses.map(witness => {
    lowerer.materialize_callable_adapter_evidence(
      witness, input_witnesses, captured_evidence,
    )
  })
  match recipe.result {
    TailCall =>
      lowerer.terminate(
        TailCallValue(source_callable, source_witnesses, source_arguments),
      )
    Adapt(flow) => {
      let source_result = lowerer.fresh_callable_adapter_value(
        flow.value,
        input_witnesses,
        captured_evidence,
      )
      lowerer.emit(
        CallValue(
          source_callable, source_witnesses, source_arguments, source_result,
        ),
      )
      let result = lowerer.adapt_callable_adapter_value(
        source_result, flow, input_witnesses, captured_evidence,
      )
      lowerer.terminate(Return(result))
    }
  }
  {
    values: lowerer.values,
    inputs: {
      environment: Some(environment),
      witnesses: input_witnesses,
      user_parameters: user_parameter_slots,
    },
    result: canonical_result_abi(recipe.target_abi.result),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: lowerer.blocks[0].terminator.unwrap(),
      },
    ],
  }
}

///|
fn FunctionLowerer::fresh_callable_adapter_value(
  self : FunctionLowerer,
  recipe : CallableAdapterValueRecipe,
  inputs : Array[@vmcfg.ValueId],
  captures : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId? raise LoisvmLoweringError {
  match recipe {
    Unit => None
    Concrete(key, _) =>
      Some(self.fresh_metadata(adapter_value_metadata(key, None, Owned)))
    Erased(evidence) => {
      let companion = self.materialize_callable_adapter_evidence(
        evidence, inputs, captures,
      )
      Some(
        self.fresh_metadata(
          adapter_value_metadata(
            Value({
              representation: I64,
              cleanup: OwnedErased,
              kind: ErasedValue,
            }),
            Some(companion),
            Owned,
          ),
        ),
      )
    }
  }
}

///|
fn FunctionLowerer::adapt_callable_adapter_value(
  self : FunctionLowerer,
  value : @vmcfg.ValueId?,
  flow : CallableAdapterValueFlowRecipe,
  inputs : Array[@vmcfg.ValueId],
  captures : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId? raise LoisvmLoweringError {
  match (flow.value, flow.target) {
    (Unit, Unit) => {
      if value is Some(_) {
        raise InvalidTypeApplication(
          detail="Unit callable adapter flow received a physical value",
        )
      }
      None
    }
    (Unit, Erased(evidence)) => {
      if value is Some(_) {
        raise InvalidTypeApplication(
          detail="Unit callable adapter erasure received a physical value",
        )
      }
      let companion = self.materialize_callable_adapter_evidence(
        evidence, inputs, captures,
      )
      let destination = self.fresh_erased_slot(companion, Owned)
      self.emit(EraseUnit(destination))
      Some(destination)
    }
    (Erased(_), Unit) => {
      guard value is Some(source) else {
        raise InvalidTypeApplication(
          detail="callable adapter Unit projection has no erased source",
        )
      }
      self.emit(UneraseUnit(source))
      None
    }
    (Erased(_), Erased(_)) => value
    (Concrete(_, _), Erased(evidence)) => {
      guard value is Some(source) else {
        raise InvalidTypeApplication(
          detail="callable adapter erasure has no concrete source",
        )
      }
      let source = self.materialize_nested_callable_adapter(
        source,
        flow.nested_adapter,
        inputs,
        captures,
      )
      let companion = self.materialize_callable_adapter_evidence(
        evidence, inputs, captures,
      )
      let destination = self.fresh_erased_slot(companion, Owned)
      self.emit_callable_adapter_erasure(destination, source, flow.source_shape)
      Some(destination)
    }
    (Erased(_), Concrete(_, _)) => {
      guard value is Some(source) else {
        raise InvalidTypeApplication(
          detail="callable adapter unerasure has no erased source",
        )
      }
      let concrete = self.emit_callable_adapter_unerasure(
        source,
        flow.target_shape,
      )
      Some(
        self.materialize_nested_callable_adapter(
          concrete,
          flow.nested_adapter,
          inputs,
          captures,
        ),
      )
    }
    (Concrete(_, _), Concrete(_, _)) => {
      guard value is Some(source) else {
        raise InvalidTypeApplication(
          detail="concrete callable adapter flow has no source",
        )
      }
      Some(
        self.materialize_nested_callable_adapter(
          source,
          flow.nested_adapter,
          inputs,
          captures,
        ),
      )
    }
    (Unit, Concrete(_, _)) | (Concrete(_, _), Unit) =>
      raise InvalidTypeApplication(
        detail="callable adapter changes Unit into a concrete runtime value",
      )
  }
}

///|
fn FunctionLowerer::emit_callable_adapter_erasure(
  self : FunctionLowerer,
  destination : @vmcfg.ValueId,
  source : @vmcfg.ValueId,
  shape : CallableAdapterValueRecipe,
) -> Unit raise LoisvmLoweringError {
  guard shape is Concrete(key, _) else {
    raise InvalidTypeApplication(
      detail="callable adapter erasure has no concrete physical shape",
    )
  }
  match canonical_representation(key) {
    I32 => self.emit(EraseI32(destination, source))
    I64 => self.emit(EraseI64(destination, source))
    F32 => self.emit(EraseF32(destination, source))
    F64 => self.emit(EraseF64(destination, source))
  }
}

///|
fn FunctionLowerer::emit_callable_adapter_unerasure(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  shape : CallableAdapterValueRecipe,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  guard shape is Concrete(key, _) else {
    raise InvalidTypeApplication(
      detail="callable adapter unerasure has no concrete physical shape",
    )
  }
  let destination = self.fresh_metadata(
    adapter_value_metadata(key, None, Owned),
  )
  match canonical_representation(key) {
    I32 => self.emit(UneraseI32(destination, source))
    I64 => self.emit(UneraseI64(destination, source))
    F32 => self.emit(UneraseF32(destination, source))
    F64 => self.emit(UneraseF64(destination, source))
  }
  destination
}

///|
fn FunctionLowerer::materialize_nested_callable_adapter(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  nested : CallableAdapterNestedRecipe?,
  inputs : Array[@vmcfg.ValueId],
  captures : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  guard nested is Some(nested) else { return source }
  let plan = self.image.callable_adapter_plan(nested.recipe)
  let evidence = nested.captured_evidence.map(recipe => {
    self.materialize_callable_adapter_evidence(recipe, inputs, captures)
  })
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
      evidence + [source],
    ),
  )
  let destination = self.fresh_metadata(
    adapter_value_metadata(Callable(nested.recipe.target_abi), None, Owned),
  )
  self.emit(MakeClosure(destination, plan.function, environment))
  destination
}

///|
fn FunctionLowerer::materialize_callable_adapter_evidence(
  self : FunctionLowerer,
  recipe : CallableAdapterEvidenceRecipe,
  inputs : Array[@vmcfg.ValueId],
  captures : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  match recipe {
    Input(index) =>
      inputs
      .get(index)
      .unwrap_or_else(() => {
        raise InvalidTypeApplication(
          detail="callable adapter evidence selects a missing input",
        )
      })
    Capture(index) =>
      captures
      .get(index)
      .unwrap_or_else(() => {
        raise InvalidTypeApplication(
          detail="callable adapter evidence selects a missing capture",
        )
      })
    Apply(callee, arguments) => {
      let callee = self.materialize_callable_adapter_evidence(
        callee, inputs, captures,
      )
      let arguments = arguments.map(argument => {
        self.materialize_callable_adapter_evidence(argument, inputs, captures)
      })
      let destination = self.fresh_metadata(layout_witness_metadata())
      self.emit(CallValue(callee, [], arguments, Some(destination)))
      destination
    }
    LayoutConstructor(evidence, captured) => {
      let plan = self.image.plan_layout_constructor(evidence)
      let captured_values = captured.map(recipe => {
        self.materialize_callable_adapter_evidence(recipe, inputs, captures)
      })
      let environment = self.make_capture_environment(
        plan.environment_shape,
        [],
        captured_values,
      )
      let destination = self.fresh_metadata(
        layout_constructor_metadata(plan.arity),
      )
      match environment {
        None => self.emit(ConstFunction(destination, plan.function))
        Some(environment) =>
          self.emit(MakeClosure(destination, plan.function, environment))
      }
      destination
    }
    Static(layout) => {
      let layout = self.image.intern_layout(layout)
      let destination = self.fresh_metadata(layout_witness_metadata())
      self.emit(ConstLayout(destination, layout))
      destination
    }
  }
}

///|
fn adapter_value_metadata(
  key : CanonicalRuntimeTypeKey,
  erased_companion : @vmcfg.ValueId?,
  ownership : @vmcfg.Ownership,
) -> @vmcfg.ValueMetadata {
  let abi = match key {
    Unit => abort("Unit has no value metadata")
    Value(abi) => abi
    Callable(_) =>
      { representation: I64, cleanup: OwnedCallable, kind: CallableValue, }
  }
  {
    representation: abi.representation,
    cleanup: abi.cleanup,
    kind: abi.kind,
    ownership: if abi.cleanup is Trivial {
      Trivial
    } else {
      ownership
    },
    erased_companion,
  }
}

///|
fn canonical_representation(
  key : CanonicalRuntimeTypeKey,
) -> @bytecode.Representation {
  match key {
    Unit => abort("Unit has no value representation")
    Value(abi) => abi.representation
    Callable(_) => I64
  }
}

///|
fn canonical_result_abi(key : CanonicalRuntimeTypeKey) -> @bytecode.ResultAbi {
  match key {
    Unit => Unit
    Value(abi) => Value(abi.representation, abi.cleanup, abi.kind)
    Callable(_) => Value(I64, OwnedCallable, CallableValue)
  }
}
