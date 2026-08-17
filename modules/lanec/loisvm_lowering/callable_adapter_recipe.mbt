///|
priv struct CallableAdapterEvidenceBinding {
  parameter : @buslane.TypeParameterId
  recipe : CallableAdapterEvidenceRecipe
}

///|
fn ImageLowerer::callable_adapter_recipe(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  source_parameter_targets : Array[Int],
  substitutions : @buslane.TypeSubstitution,
  captured_parameters : Array[@buslane.TypeParameterId],
) -> CallableAdapterRecipe raise LoisvmLoweringError {
  let (source_type_parameters, source_parameters, source_result) = function_type_parts(
    source_type,
  )
  let (target_type_parameters, target_parameters, target_result) = function_type_parts(
    target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() ||
    source_parameter_targets.length() != source_parameters.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target arities differ",
    )
  }
  let evidence : Array[CallableAdapterEvidenceBinding] = []
  let mut input_index = 0
  for index, target_parameter in target_type_parameters {
    let target_requires_evidence = self.requires_runtime_evidence(
      target_parameter,
    )
    let source_parameter = source_type_parameters[index]
    if target_requires_evidence !=
      self.requires_runtime_evidence(source_parameter) {
      raise InvalidTypeApplication(
        detail="callable adapter source and target evidence arities differ",
      )
    }
    if target_requires_evidence {
      let recipe = CallableAdapterEvidenceRecipe::Input(input_index)
      bind_callable_adapter_evidence(evidence, target_parameter, recipe)
      bind_callable_adapter_evidence(evidence, source_parameter, recipe)
      input_index += 1
    }
  }
  let captured_evidence = []
  for index, parameter in captured_parameters {
    bind_callable_adapter_evidence(evidence, parameter, Capture(index))
    captured_evidence.push(
      value_metadata_abi(self.runtime_evidence_metadata(parameter)),
    )
  }
  let target_parameter_recipes = []
  let target_physical_indices = Array::make(target_parameters.length(), -1)
  for index, type_ in target_parameters {
    let recipe = self.callable_adapter_value_recipe(type_, evidence)
    if !(recipe is Unit) {
      target_physical_indices[index] = target_parameter_recipes.length()
      target_parameter_recipes.push(recipe)
    }
  }
  let source_arguments = []
  for index, source_parameter in source_parameters {
    let target_index = source_parameter_targets[index]
    let target_parameter = target_parameters[target_index]
    let target_physical_index = target_physical_indices[target_index]
    if target_physical_index < 0 {
      if !(self.callable_adapter_value_recipe(source_parameter, evidence)
        is Unit) {
        raise InvalidTypeApplication(
          detail="callable adapter maps a runtime source parameter to Unit",
        )
      }
      continue
    }
    source_arguments.push({
      target: target_physical_index,
      flow: self.callable_adapter_value_flow_recipe(
        target_parameter, source_parameter, substitutions, evidence,
      ),
    })
  }
  let result = if self.types_definitionally_equal(source_result, target_result) {
    CallableAdapterResultRecipe::TailCall
  } else {
    Adapt(
      self.callable_adapter_value_flow_recipe(
        source_result, target_result, substitutions, evidence,
      ),
    )
  }
  {
    source_abi: self.canonical_callable_abi_under(source_type, substitutions),
    target_abi: self.canonical_callable_abi_under(target_type, substitutions),
    captured_evidence,
    target_parameters: target_parameter_recipes,
    source_arguments,
    result,
  }
}

///|
fn bind_callable_adapter_evidence(
  bindings : Array[CallableAdapterEvidenceBinding],
  parameter : @buslane.TypeParameterId,
  recipe : CallableAdapterEvidenceRecipe,
) -> Unit raise LoisvmLoweringError {
  for binding in bindings {
    if binding.parameter == parameter {
      if binding.recipe != recipe {
        raise InvalidTypeApplication(
          detail="callable adapter evidence parameter has two runtime sources",
        )
      }
      return
    }
  }
  bindings.push({ parameter, recipe })
}

///|
fn ImageLowerer::callable_adapter_value_flow_recipe(
  self : ImageLowerer,
  value_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterValueFlowRecipe raise LoisvmLoweringError {
  let source_shape = apply_type_substitution(value_type, substitutions)
  let target_shape = apply_type_substitution(target_type, substitutions)
  {
    value: self.callable_adapter_value_recipe(value_type, evidence),
    source_shape: self.callable_adapter_value_recipe(source_shape, evidence),
    target: self.callable_adapter_value_recipe(target_type, evidence),
    target_shape: self.callable_adapter_value_recipe(target_shape, evidence),
    definitionally_equal: self.types_definitionally_equal(
      source_shape, target_shape,
    ),
    nested_adapter: self.callable_adapter_nested_recipe(
      value_type, target_type, substitutions,
    ),
  }
}

///|
fn ImageLowerer::callable_adapter_nested_recipe(
  self : ImageLowerer,
  value_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> CallableAdapterRecipe? raise LoisvmLoweringError {
  let source_runtime = self.runtime_type(value_type)
  let target_runtime = self.runtime_type(target_type)
  let nested_contract = match (source_runtime, target_runtime) {
    (Erased(_), Concrete(Function(_, _, _) | Forall(_, _) as concrete)) => {
      let (canonical, bindings) = self.erased_callable_abi(
        value_type, concrete, substitutions,
      )
      self.plan_callable_adaptation(canonical, concrete, bindings)
    }
    (Concrete(Function(_, _, _) | Forall(_, _) as concrete), Erased(_)) => {
      let (canonical, bindings) = self.erased_callable_abi(
        target_type, concrete, substitutions,
      )
      self.plan_callable_adaptation(concrete, canonical, bindings)
    }
    (
      Concrete(Function(_, _, _) | Forall(_, _) as source),
      Concrete(Function(_, _, _) | Forall(_, _) as target),
    ) => self.plan_callable_adaptation(source, target, substitutions)
    _ => None
  }
  match nested_contract {
    Some(contract) => Some(contract.recipe)
    None => None
  }
}

///|
fn ImageLowerer::callable_adapter_value_recipe(
  self : ImageLowerer,
  type_ : @buslane.Type,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterValueRecipe raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    Unit => Unit
    Erased(type_) =>
      Erased(
        self.callable_adapter_evidence_recipe(
          self.plan_layout_witness(type_),
          evidence,
        ),
      )
    Concrete(type_, _) =>
      Concrete(
        self.canonical_runtime_type_key(type_),
        concrete_layout_recipe(type_),
      )
  }
}

///|
fn ImageLowerer::callable_adapter_evidence_recipe(
  self : ImageLowerer,
  plan : RuntimeEvidencePlan,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterEvidenceRecipe raise LoisvmLoweringError {
  match plan {
    Existing(parameter) => find_callable_adapter_evidence(evidence, parameter)
    ApplyEvidence(parameter, arguments) =>
      Apply(
        find_callable_adapter_evidence(evidence, parameter),
        arguments.map(argument => {
          self.callable_adapter_evidence_recipe(argument, evidence)
        }),
      )
    MaterializeLayoutConstructor(type_) => LayoutConstructor(type_)
    StaticLayout(recipe) => Static(recipe)
  }
}

///|
fn find_callable_adapter_evidence(
  evidence : Array[CallableAdapterEvidenceBinding],
  parameter : @buslane.TypeParameterId,
) -> CallableAdapterEvidenceRecipe raise LoisvmLoweringError {
  for binding in evidence {
    if binding.parameter == parameter {
      return binding.recipe
    }
  }
  raise InvalidTypeApplication(
    detail="missing callable adapter evidence source for \{Repr(parameter)}",
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
