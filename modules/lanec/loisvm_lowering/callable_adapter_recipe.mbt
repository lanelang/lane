///|
priv struct CallableAdapterEvidenceBinding {
  evidence : RuntimeEvidencePlan
  recipe : CallableAdapterEvidenceRecipe
}

///|
priv struct CallableAdapterEvidenceAlias {
  evidence : RuntimeEvidencePlan
  replacement : RuntimeEvidencePlan
}

///|
fn ImageLowerer::callable_adapter_recipe_with_interfaces(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  source_interface : PhysicalCallableInterface,
  target_interface : PhysicalCallableInterface,
  source_parameter_targets : Array[Int],
  substitutions : RuntimeSubstitution,
  captures : Array[CallableAdapterEvidenceCapture],
  aliases : Array[CallableAdapterEvidenceAlias],
  nested_adapters : Array[CallableAdapterContract],
) -> CallableAdapterRecipe raise LoisvmLoweringError {
  let source_abi = source_interface.invocation
  let target_abi = target_interface.invocation
  let source_parameter_projection = source_interface.parameters
  let target_parameter_projection = target_interface.parameters
  let (source_type_parameters, source_parameters, source_result) = function_type_parts(
    source_type,
  )
  let (target_type_parameters, target_parameters, target_result) = function_type_parts(
    target_type,
  )
  if source_parameter_targets.length() != source_parameters.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target arities differ",
    )
  }
  let evidence : Array[CallableAdapterEvidenceBinding] = []
  let mut input_index = 0
  for target_parameter in target_type_parameters {
    let target_requires_evidence = self.requires_runtime_evidence(
      target_parameter,
    )
    if target_requires_evidence {
      let recipe = CallableAdapterEvidenceRecipe::Input(input_index)
      bind_callable_adapter_evidence(
        evidence,
        Existing(target_parameter.id),
        recipe,
      )
      let resolved = self.callable_adapter_parameter_evidence(
        target_parameter,
        substitutions.apply_evidence(Parameter(target_parameter.id)),
      )
      match resolved {
        Existing(_) | ApplyEvidence(_, _) =>
          bind_callable_adapter_evidence(evidence, resolved, recipe)
        _ => ()
      }
      input_index += 1
    }
  }
  if input_index != target_abi.witnesses.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter target type \{Repr(target_type)} exposes \{input_index} evidence parameter(s), but its physical ABI \{Repr(target_abi)} exposes \{target_abi.witnesses.length()} witness(es)",
    )
  }
  let captured_evidence = []
  for index, capture in captures {
    bind_callable_adapter_evidence(
      evidence,
      Existing(capture.source.id),
      Capture(index),
    )
    captured_evidence.push(
      value_metadata_abi(runtime_evidence_metadata(capture.source)),
    )
  }
  for mapping in aliases {
    let recipe = self.callable_adapter_evidence_recipe(
      mapping.replacement,
      evidence,
    )
    bind_callable_adapter_evidence(evidence, mapping.evidence, recipe)
  }
  if source_type_parameters.length() == target_type_parameters.length() {
    for index, source_parameter in source_type_parameters {
      let recipe = CallableAdapterEvidenceRecipe::Input(index)
      bind_callable_adapter_evidence(
        evidence,
        Existing(source_parameter.id),
        recipe,
      )
      let resolved = self.callable_adapter_parameter_evidence(
        source_parameter,
        substitutions.apply_evidence(Parameter(source_parameter.id)),
      )
      match resolved {
        Existing(_) | ApplyEvidence(_, _) =>
          bind_callable_adapter_evidence(evidence, resolved, recipe)
        _ => ()
      }
    }
  }
  if source_type_parameters.length() != source_abi.witnesses.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter source evidence parameters disagree with its physical ABI",
    )
  }
  let source_witnesses = source_type_parameters.map(parameter => {
    match find_callable_adapter_evidence(evidence, Existing(parameter.id)) {
      Some(recipe) => recipe
      None => {
        let resolved = substitutions.apply_evidence(Parameter(parameter.id))
        if resolved == Parameter(parameter.id) {
          raise RepresentationSpecializationInvariant(
            detail="callable adapter source witness has no target input, capture, or concrete substitution",
          )
        }
        self.callable_adapter_evidence_recipe(
          self.plan_layout_witness(resolved),
          evidence,
        )
      }
    }
  })
  let source_parameter_keys = callable_adapter_parameter_keys(
    source_parameter_projection,
    source_abi.parameters,
  )
  let target_parameter_keys = callable_adapter_parameter_keys(
    target_parameter_projection,
    target_abi.parameters,
  )
  if source_parameter_keys.length() != source_parameters.length() ||
    target_parameter_keys.length() != target_parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter parameter projection arity disagrees with its semantic type",
    )
  }
  let target_parameter_recipes = []
  let target_physical_indices = Array::make(target_parameters.length(), -1)
  for index, type_ in target_parameters {
    let recipe = self.callable_adapter_physical_value_recipe(
      type_,
      target_parameter_keys[index],
      substitutions,
      evidence,
    )
    if !(recipe is Unit) {
      target_physical_indices[index] = target_parameter_recipes.length()
      target_parameter_recipes.push(recipe)
    }
  }
  let source_arguments : Array[CallableAdapterArgumentRecipe] = []
  let target_discards : Array[CallableAdapterDiscardRecipe] = []
  for index, source_parameter in source_parameters {
    let target_index = source_parameter_targets[index]
    let target_parameter = target_parameters[target_index]
    let target_physical_index = target_physical_indices[target_index]
    let source_key = source_parameter_keys[index]
    let target_key = target_parameter_keys[target_index]
    if source_key is None {
      if target_key is Some(_) {
        guard target_physical_index >= 0 else {
          raise RepresentationSpecializationInvariant(
            detail="callable adapter discard has no target physical parameter",
          )
        }
        target_discards.push({
          input: target_physical_index,
          flow: self.callable_adapter_physical_value_flow_recipe(
            target_parameter,
            source_parameter,
            substitutions,
            target_key,
            None,
            target_interface.parameter_callables[target_index],
            None,
            evidence,
            nested_adapters,
          ),
        })
      }
      continue
    }
    source_arguments.push({
      input: if target_physical_index < 0 {
        CallableAdapterArgumentInput::Unit
      } else {
        TargetParameter(target_physical_index)
      },
      flow: self.callable_adapter_physical_value_flow_recipe(
        target_parameter,
        source_parameter,
        substitutions,
        target_key,
        source_key,
        target_interface.parameter_callables[target_index],
        source_interface.parameter_callables[index],
        evidence,
        nested_adapters,
      ),
    })
  }
  let result = if source_abi.result == target_abi.result &&
    source_interface.result_callable == target_interface.result_callable {
    CallableAdapterResultRecipe::TailCall
  } else {
    Adapt(
      self.callable_adapter_physical_value_flow_recipe(
        source_result,
        target_result,
        substitutions,
        source_abi.result.optional_key(),
        target_abi.result.optional_key(),
        source_interface.result_callable,
        target_interface.result_callable,
        evidence,
        nested_adapters,
      ),
    )
  }
  let recipe = {
    source_abi,
    target_abi,
    captured_evidence,
    source_witnesses,
    target_parameters: target_parameter_recipes,
    source_arguments,
    target_discards,
    result,
  }
  verify_callable_adapter_recipe(recipe)
  recipe
}

///|
fn callable_adapter_parameter_keys(
  projections : Array[PhysicalCallableParameterProjection],
  physical : Array[CanonicalRuntimeTypeKey],
) -> Array[CanonicalRuntimeTypeKey?] raise LoisvmLoweringError {
  let keys : Array[CanonicalRuntimeTypeKey?] = []
  let mut physical_index = 0
  for projection in projections {
    match projection {
      Unit => keys.push(None)
      Slot(expected) => {
        guard physical.get(physical_index) is Some(key) && key == expected else {
          raise RepresentationSpecializationInvariant(
            detail="callable adapter parameter projection disagrees with its physical ABI",
          )
        }
        keys.push(Some(key))
        physical_index += 1
      }
      Product(_) =>
        raise RepresentationSpecializationInvariant(
          detail="first-class callable adapter cannot expose a scalar-expanded parameter",
        )
    }
  }
  if physical_index != physical.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter ABI has unconsumed physical parameters",
    )
  }
  keys
}

///|
fn ImageLowerer::callable_adapter_physical_value_recipe(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  key : CanonicalRuntimeTypeKey?,
  substitutions : RuntimeSubstitution,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterValueRecipe raise LoisvmLoweringError {
  match key {
    None => Unit
    Some(Value({ cleanup: OwnedErased, .. })) => {
      let resolved = substitutions.apply_type(self.runtime_types, type_)
      Erased(
        self.callable_adapter_evidence_recipe(
          self.plan_layout_witness(runtime_type_evidence(resolved)),
          evidence,
        ),
      )
    }
    Some(key) => Concrete(key)
  }
}

///|
fn verify_callable_adapter_recipe(
  recipe : CallableAdapterRecipe,
) -> Unit raise LoisvmLoweringError {
  if recipe.target_parameters.length() != recipe.target_abi.parameters.length() ||
    recipe.source_arguments.length() != recipe.source_abi.parameters.length() ||
    recipe.source_witnesses.length() != recipe.source_abi.witnesses.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter recipe parameter arity disagrees with its canonical ABI",
    )
  }
  for index, parameter in recipe.target_parameters {
    if parameter.physical_key() != Some(recipe.target_abi.parameters[index]) {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter target parameter recipe disagrees with its canonical ABI",
      )
    }
  }
  let target_uses = Array::make(recipe.target_abi.parameters.length(), 0)
  for index, argument in recipe.source_arguments {
    let input = match argument.input {
      TargetParameter(target) => {
        guard recipe.target_abi.parameters.get(target) is Some(input) else {
          raise RepresentationSpecializationInvariant(
            detail="callable adapter source argument selects no target ABI parameter",
          )
        }
        target_uses[target] += 1
        Some(input)
      }
      Unit => None
    }
    if argument.flow.value.physical_key() != input ||
      argument.flow.target.physical_key() !=
      Some(recipe.source_abi.parameters[index]) {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter source argument flow disagrees with its canonical ABI",
      )
    }
    verify_callable_adapter_identity_flow(argument.flow)
    verify_callable_adapter_nested_flow(argument.flow)
  }
  for discard in recipe.target_discards {
    guard recipe.target_abi.parameters.get(discard.input) is Some(input) else {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter discard selects no target ABI parameter",
      )
    }
    target_uses[discard.input] += 1
    if discard.flow.value.physical_key() != Some(input) ||
      discard.flow.target.physical_key() is Some(_) {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter discard flow disagrees with its target ABI",
      )
    }
    verify_callable_adapter_identity_flow(discard.flow)
    verify_callable_adapter_nested_flow(discard.flow)
  }
  if target_uses.any(count => count != 1) {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter must consume every target physical parameter exactly once",
    )
  }
  match recipe.result {
    TailCall =>
      if recipe.source_abi.result != recipe.target_abi.result {
        raise RepresentationSpecializationInvariant(
          detail="tail-call adapter recipe changes its result ABI",
        )
      }
    Adapt(flow) => {
      if flow.value.physical_key() != recipe.source_abi.result.optional_key() ||
        flow.target.physical_key() != recipe.target_abi.result.optional_key() {
        raise RepresentationSpecializationInvariant(
          detail="callable adapter result flow \{Repr(flow)} disagrees with source \{Repr(recipe.source_abi.result)} and target \{Repr(recipe.target_abi.result)}",
        )
      }
      verify_callable_adapter_identity_flow(flow)
      verify_callable_adapter_nested_flow(flow)
    }
  }
}

///|
fn verify_callable_adapter_identity_flow(
  flow : CallableAdapterValueFlowRecipe,
) -> Unit raise LoisvmLoweringError {
  guard flow.value is Concrete(source) &&
    flow.target is Concrete(target) &&
    source != target else {
    return
  }
  if flow.nested_adapter is None {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter cannot preserve a concrete value across distinct physical contracts \{Repr(source)} and \{Repr(target)}",
    )
  }
}

///|
fn verify_callable_adapter_nested_flow(
  flow : CallableAdapterValueFlowRecipe,
) -> Unit raise LoisvmLoweringError {
  guard flow.nested_adapter is Some(nested) else { return }
  let source = match flow.value {
    Concrete(Callable(abi)) => Some(abi)
    _ => None
  }
  let target = match flow.target {
    Concrete(Callable(abi)) => Some(abi)
    _ => None
  }
  if (source is Some(source) && source != nested.recipe.source_abi) ||
    (target is Some(target) && target != nested.recipe.target_abi) {
    raise RepresentationSpecializationInvariant(
      detail="nested callable adapter recipe \{Repr(nested)} disagrees with enclosing source \{Repr(source)} and target \{Repr(target)} in \{Repr(flow)}",
    )
  }
}

///|
fn CanonicalRuntimeTypeKey::optional_key(
  self : CanonicalRuntimeTypeKey,
) -> CanonicalRuntimeTypeKey? {
  match self {
    Unit => None
    key => Some(key)
  }
}

///|
fn CallableAdapterValueRecipe::physical_key(
  self : CallableAdapterValueRecipe,
) -> CanonicalRuntimeTypeKey? {
  match self {
    Unit => None
    Erased(_) =>
      Some(
        Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, }),
      )
    Concrete(key) => Some(key)
  }
}

///|
fn bind_callable_adapter_evidence(
  bindings : Array[CallableAdapterEvidenceBinding],
  evidence : RuntimeEvidencePlan,
  recipe : CallableAdapterEvidenceRecipe,
) -> Unit raise LoisvmLoweringError {
  for binding in bindings {
    if binding.evidence == evidence {
      if binding.recipe != recipe {
        raise InvalidTypeApplication(
          detail="callable adapter evidence \{Repr(evidence)} has two runtime sources \{Repr(binding.recipe)} and \{Repr(recipe)}",
        )
      }
      return
    }
  }
  bindings.push({ evidence, recipe, })
}

///|
fn ImageLowerer::callable_adapter_physical_value_flow_recipe(
  self : ImageLowerer,
  value_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  value_key : CanonicalRuntimeTypeKey?,
  target_key : CanonicalRuntimeTypeKey?,
  value_interface : PhysicalCallableInterface?,
  target_interface : PhysicalCallableInterface?,
  evidence : Array[CallableAdapterEvidenceBinding],
  nested_adapters : Array[CallableAdapterContract],
) -> CallableAdapterValueFlowRecipe raise LoisvmLoweringError {
  let source_shape = substitutions.apply_type(self.runtime_types, value_type)
  let target_shape = substitutions.apply_type(self.runtime_types, target_type)
  {
    value: self.callable_adapter_physical_value_recipe(
      value_type, value_key, substitutions, evidence,
    ),
    source_shape: self.callable_adapter_physical_value_recipe(
      source_shape,
      value_key,
      RuntimeSubstitution::new(),
      evidence,
    ),
    target: self.callable_adapter_physical_value_recipe(
      target_type, target_key, substitutions, evidence,
    ),
    target_shape: self.callable_adapter_physical_value_recipe(
      target_shape,
      target_key,
      RuntimeSubstitution::new(),
      evidence,
    ),
    definitionally_equal: self.types_representation_equivalent(
      source_shape, target_shape,
    ),
    nested_adapter: self.callable_adapter_nested_recipe(
      value_type, target_type, substitutions, value_key, target_key, value_interface,
      target_interface, evidence, nested_adapters,
    ),
  }
}

///|
fn ImageLowerer::callable_adapter_nested_recipe(
  self : ImageLowerer,
  value_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  value_key : CanonicalRuntimeTypeKey?,
  target_key : CanonicalRuntimeTypeKey?,
  value_interface : PhysicalCallableInterface?,
  target_interface : PhysicalCallableInterface?,
  evidence : Array[CallableAdapterEvidenceBinding],
  nested_adapters : Array[CallableAdapterContract],
) -> CallableAdapterNestedRecipe? raise LoisvmLoweringError {
  let contract = self.callable_adapter_nested_contract(
    value_type, target_type, substitutions, value_key, target_key, value_interface,
    target_interface,
  )
  if contract is Some(contract) {
    nested_adapters.push(contract)
    Some({
      recipe: contract.recipe,
      captured_evidence: contract.captures.map(capture => {
        let parameter = capture.source
        let captured = contract.substitutions.apply_evidence(
          Parameter(parameter.id),
        )
        self.callable_adapter_evidence_recipe(
          if parameter.arity == 0 {
            self.plan_layout_witness(captured)
          } else {
            self.plan_layout_constructor_evidence(captured)
          },
          evidence,
        )
      }),
    })
  } else {
    None
  }
}

///|
fn ImageLowerer::callable_adapter_nested_contract(
  self : ImageLowerer,
  value_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  value_key : CanonicalRuntimeTypeKey?,
  target_key : CanonicalRuntimeTypeKey?,
  value_interface : PhysicalCallableInterface?,
  target_interface : PhysicalCallableInterface?,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let resolved_value = substitutions.apply_type(self.runtime_types, value_type)
  let resolved_target = substitutions.apply_type(
    self.runtime_types,
    target_type,
  )
  match (value_key, target_key) {
    (Some(Value({ cleanup: OwnedErased, .. })), Some(Callable(_))) => {
      guard self.runtime_type(resolved_target)
        is Concrete(Callable(_, _) | Forall(_, _) as concrete) else {
        raise RepresentationSpecializationInvariant(
          detail="callable unerasure target has no concrete callable semantic type",
        )
      }
      let (canonical, bindings) = self.canonical_callable_type(concrete)
      self.plan_callable_adaptation_with_interfaces(
        canonical,
        concrete,
        bindings,
        self.canonical_callable_interface_under(canonical, bindings),
        target_interface.unwrap_or_else(() => {
          self.canonical_callable_interface_under(concrete, bindings)
        }),
      )
    }
    (Some(Callable(_)), Some(Value({ cleanup: OwnedErased, .. }))) => {
      guard self.runtime_type(resolved_value)
        is Concrete(Callable(_, _) | Forall(_, _) as concrete) else {
        raise RepresentationSpecializationInvariant(
          detail="callable erasure source has no concrete callable semantic type",
        )
      }
      let (canonical, bindings) = self.canonical_callable_type(concrete)
      self.plan_callable_adaptation_with_interfaces(
        concrete,
        canonical,
        bindings,
        value_interface.unwrap_or_else(() => {
          self.canonical_callable_interface_under(concrete, bindings)
        }),
        self.canonical_callable_interface_under(canonical, bindings),
      )
    }
    (Some(Callable(source_abi)), Some(Callable(target_abi))) => {
      guard self.runtime_type(resolved_value)
        is Concrete(Callable(_, _) | Forall(_, _) as source) &&
        self.runtime_type(resolved_target)
        is Concrete(Callable(_, _) | Forall(_, _) as target) else {
        raise RepresentationSpecializationInvariant(
          detail="concrete callable flow has no concrete callable semantic types",
        )
      }
      let source_interface = value_interface.unwrap_or_else(() => {
        self.callable_interface_under_with_invocation(
          source,
          RuntimeSubstitution::new(),
          source_abi,
        )
      })
      let target_interface = target_interface.unwrap_or_else(() => {
        self.callable_interface_under_with_invocation(
          target,
          RuntimeSubstitution::new(),
          target_abi,
        )
      })
      self.plan_callable_adaptation_with_interfaces(
        source,
        target,
        RuntimeSubstitution::new(),
        source_interface,
        target_interface,
      )
    }
    _ => None
  }
}

///|
fn ImageLowerer::callable_adapter_evidence_recipe(
  self : ImageLowerer,
  plan : RuntimeEvidencePlan,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterEvidenceRecipe raise LoisvmLoweringError {
  if find_callable_adapter_evidence(evidence, plan) is Some(recipe) {
    return recipe
  }
  match plan {
    Existing(parameter) =>
      raise InvalidTypeApplication(
        detail="missing callable adapter evidence source for \{Repr(parameter)}",
      )
    ApplyEvidence(parameter, arguments) =>
      Apply(
        require_callable_adapter_evidence(evidence, Existing(parameter)),
        arguments.map(argument => {
          self.callable_adapter_evidence_recipe(argument, evidence)
        }),
      )
    MaterializeLayoutConstructor(layout_constructor) =>
      LayoutConstructor(
        layout_constructor.evidence,
        layout_constructor.captured_parameters.map(parameter => {
          require_callable_adapter_evidence(evidence, Existing(parameter.id))
        }),
      )
    StaticLayout(layout) => Static(layout.recipe)
  }
}

///|
fn find_callable_adapter_evidence(
  evidence : Array[CallableAdapterEvidenceBinding],
  plan : RuntimeEvidencePlan,
) -> CallableAdapterEvidenceRecipe? {
  for binding in evidence {
    if binding.evidence == plan {
      return Some(binding.recipe)
    }
  }
  None
}

///|
fn require_callable_adapter_evidence(
  evidence : Array[CallableAdapterEvidenceBinding],
  plan : RuntimeEvidencePlan,
) -> CallableAdapterEvidenceRecipe raise LoisvmLoweringError {
  if find_callable_adapter_evidence(evidence, plan) is Some(recipe) {
    return recipe
  }
  raise InvalidTypeApplication(
    detail="missing callable adapter evidence source for \{Repr(plan)}",
  )
}

///|
fn value_metadata_abi(metadata : @vmcfg.ValueMetadata) -> @bytecode.ValueAbi {
  {
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    kind: metadata.kind,
  }
}
