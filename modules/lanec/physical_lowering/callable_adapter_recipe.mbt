///|
priv struct CallableAdapterEvidenceBinding {
  parameter : @anf.RuntimeEvidenceId
  recipe : CallableAdapterEvidenceRecipe
}

///|
fn ImageLowerer::callable_adapter_recipe(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  source_parameter_targets : Array[Int],
  substitutions : RuntimeSubstitution,
  captured_parameters : Array[@anf.RuntimeEvidenceParameter],
) -> CallableAdapterRecipe raise PhysicalLoweringError {
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
      bind_callable_adapter_evidence(evidence, target_parameter.id, recipe)
      input_index += 1
    }
  }
  let captured_evidence = []
  for index, parameter in captured_parameters {
    bind_callable_adapter_evidence(evidence, parameter.id, Capture(index))
    captured_evidence.push(
      value_metadata_abi(runtime_evidence_metadata(parameter)),
    )
  }
  for index, source_parameter in source_type_parameters {
    if substitutions.argument(source_parameter.id) is Some(_) {
      bind_callable_adapter_evidence(
        evidence,
        source_parameter.id,
        self.callable_adapter_parameter_evidence_recipe(
          source_parameter, substitutions, evidence,
        ),
      )
      continue
    }
    guard target_type_parameters.get(index) is Some(target_parameter) else {
      raise InvalidTypeApplication(
        detail="callable adapter has no evidence source for a generic source parameter",
      )
    }
    if self.requires_runtime_evidence(source_parameter) !=
      self.requires_runtime_evidence(target_parameter) {
      raise InvalidTypeApplication(
        detail="callable adapter source and target evidence arities differ",
      )
    }
    if self.requires_runtime_evidence(source_parameter) {
      bind_callable_adapter_evidence(
        evidence,
        source_parameter.id,
        find_callable_adapter_evidence(evidence, target_parameter.id),
      )
    }
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
    source_arguments.push({
      target: if target_physical_index < 0 {
        None
      } else {
        Some(target_physical_index)
      },
      flow: self.callable_adapter_value_flow_recipe(
        target_parameter, source_parameter, substitutions, evidence,
      ),
    })
  }
  let source_witnesses = []
  for parameter in source_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      source_witnesses.push(
        self.callable_adapter_parameter_evidence_recipe(
          parameter, substitutions, evidence,
        ),
      )
    }
  }
  let result = if self.types_representation_equivalent(
      source_result, target_result,
    ) {
    CallableAdapterResultRecipe::TailCall
  } else {
    Adapt(
      self.callable_adapter_value_flow_recipe(
        source_result, target_result, substitutions, evidence,
      ),
    )
  }
  {
    source_abi: self.canonical_callable_abi(source_type),
    target_abi: self.canonical_callable_abi_under(target_type, substitutions),
    captured_evidence,
    source_witnesses,
    target_parameters: target_parameter_recipes,
    source_arguments,
    result,
  }
}

///|
fn bind_callable_adapter_evidence(
  bindings : Array[CallableAdapterEvidenceBinding],
  parameter : @anf.RuntimeEvidenceId,
  recipe : CallableAdapterEvidenceRecipe,
) -> Unit raise PhysicalLoweringError {
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
  bindings.push({ parameter, recipe, })
}

///|
fn ImageLowerer::callable_adapter_value_flow_recipe(
  self : ImageLowerer,
  value_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterValueFlowRecipe raise PhysicalLoweringError {
  let source_shape = substitutions.apply_type(self.runtime_types, value_type)
  let target_shape = substitutions.apply_type(self.runtime_types, target_type)
  {
    value: self.callable_adapter_value_recipe(value_type, evidence),
    source_shape: self.callable_adapter_value_recipe(source_shape, evidence),
    target: self.callable_adapter_value_recipe(target_type, evidence),
    target_shape: self.callable_adapter_value_recipe(target_shape, evidence),
    definitionally_equal: self.types_representation_equivalent(
      source_shape, target_shape,
    ),
    nested_adapter: self.callable_adapter_nested_recipe(
      value_type, target_type, substitutions, evidence,
    ),
  }
}

///|
fn ImageLowerer::callable_adapter_nested_recipe(
  self : ImageLowerer,
  value_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterNestedRecipe? raise PhysicalLoweringError {
  let source_runtime = self.runtime_type(value_type)
  let target_runtime = self.runtime_type(target_type)
  let nested_contract = match (source_runtime, target_runtime) {
    (Erased(_), Concrete(Callable(_, _) | Forall(_, _) as concrete)) => {
      let (canonical, bindings) = self.canonical_callable_type(concrete)
      self.plan_callable_adaptation(canonical, concrete, bindings)
    }
    (Concrete(Callable(_, _) | Forall(_, _) as concrete), Erased(_)) => {
      let (canonical, bindings) = self.canonical_callable_type(concrete)
      self.plan_callable_adaptation(concrete, canonical, bindings)
    }
    (
      Concrete(Callable(_, _) | Forall(_, _) as source),
      Concrete(Callable(_, _) | Forall(_, _) as target),
    ) => self.plan_callable_adaptation(source, target, substitutions)
    _ => None
  }
  match nested_contract {
    Some(contract) =>
      Some({
        recipe: contract.recipe,
        captured_evidence: contract.captured_parameters.map(parameter => {
          self.callable_adapter_parameter_evidence_recipe(
            parameter,
            contract.substitutions,
            evidence,
          )
        }),
      })
    None => None
  }
}

///|
fn ImageLowerer::plan_layout_constructor_or_witness(
  self : ImageLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
) -> RuntimeEvidencePlan raise PhysicalLoweringError {
  if parameter.arity == 0 {
    self.plan_layout_witness(Parameter(parameter.id))
  } else {
    self.plan_layout_constructor_evidence(Parameter(parameter.id))
  }
}

///|
fn ImageLowerer::callable_adapter_parameter_evidence_recipe(
  self : ImageLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
  substitutions : RuntimeSubstitution,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterEvidenceRecipe raise PhysicalLoweringError {
  let plan = match substitutions.argument(parameter.id) {
    Some(argument) =>
      if parameter.arity == 0 {
        self.plan_layout_witness(argument.evidence)
      } else {
        self.plan_layout_constructor_evidence(argument.evidence)
      }
    None => self.plan_layout_constructor_or_witness(parameter)
  }
  self.callable_adapter_evidence_recipe(plan, evidence)
}

///|
fn ImageLowerer::callable_adapter_value_recipe(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  evidence : Array[CallableAdapterEvidenceBinding],
) -> CallableAdapterValueRecipe raise PhysicalLoweringError {
  match self.elaborate_runtime_representation(type_) {
    RuntimeUnit => Unit
    RuntimeErased(erased_evidence) =>
      Erased(
        self.callable_adapter_evidence_recipe(
          self.plan_layout_witness(erased_evidence),
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
) -> CallableAdapterEvidenceRecipe raise PhysicalLoweringError {
  match plan {
    Existing(parameter) => find_callable_adapter_evidence(evidence, parameter)
    ApplyEvidence(parameter, arguments) =>
      Apply(
        find_callable_adapter_evidence(evidence, parameter),
        arguments.map(argument => {
          self.callable_adapter_evidence_recipe(argument, evidence)
        }),
      )
    MaterializeLayoutConstructor(evidence_value) => {
      let captured = free_runtime_evidence_parameters(
        self,
        evidence_value,
        match evidence_value {
          Lambda(parameters, _) => parameters.map(parameter => parameter.id)
          _ => []
        },
      )
      LayoutConstructor(
        evidence_value,
        captured.map(parameter => {
          self.callable_adapter_evidence_recipe(
            self.plan_layout_constructor_or_witness(parameter),
            evidence,
          )
        }),
      )
    }
    StaticLayout(recipe) => Static(recipe)
  }
}

///|
fn find_callable_adapter_evidence(
  evidence : Array[CallableAdapterEvidenceBinding],
  parameter : @anf.RuntimeEvidenceId,
) -> CallableAdapterEvidenceRecipe raise PhysicalLoweringError {
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
fn value_metadata_abi(metadata : @vmcfg.ValueMetadata) -> @physical.ValueAbi {
  {
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    kind: metadata.kind,
  }
}

///|
fn ImageLowerer::canonical_runtime_type_key(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> CanonicalRuntimeTypeKey raise PhysicalLoweringError {
  self.canonical_runtime_type_key_under(type_, RuntimeSubstitution::new())
}

///|
fn ImageLowerer::canonical_runtime_type_key_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalRuntimeTypeKey raise PhysicalLoweringError {
  match self.elaborate_runtime_representation(type_) {
    RuntimeUnit => Unit
    RuntimeErased(_) =>
      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, })
    Concrete(Callable(_, _) | Forall(_, _) as type_, _) =>
      Callable(self.canonical_callable_abi_under(type_, substitutions))
    Concrete(type_, _) => {
      let type_ = substitutions.apply_type(self.runtime_types, type_)
      match self.elaborate_runtime_representation(type_) {
        RuntimeUnit => Unit
        RuntimeErased(_) =>
          Value({
            representation: I64,
            cleanup: OwnedErased,
            kind: ErasedValue,
          })
        Concrete(type_, metadata) =>
          if metadata.kind is CallableValue {
            Callable(self.canonical_callable_abi(type_))
          } else {
            Value({
              representation: metadata.representation,
              cleanup: metadata.cleanup,
              kind: metadata.kind,
            })
          }
      }
    }
  }
}

///|
fn ImageLowerer::canonical_callable_abi(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> CanonicalCallableAbi raise PhysicalLoweringError {
  self.canonical_callable_abi_under(type_, RuntimeSubstitution::new())
}

///|
fn ImageLowerer::canonical_callable_abi_under(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CanonicalCallableAbi raise PhysicalLoweringError {
  let (type_parameters, parameters, result) = function_type_parts(type_)
  let witnesses : Array[@physical.ValueAbi] = []
  for parameter in type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = runtime_evidence_metadata(parameter)
      witnesses.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      })
    }
  }
  let parameter_abis : Array[CanonicalRuntimeTypeKey] = []
  for parameter in parameters {
    let key = self.canonical_runtime_type_key_under(parameter, substitutions)
    if !(key is Unit) {
      parameter_abis.push(key)
    }
  }
  {
    witnesses,
    parameters: parameter_abis,
    result: self.canonical_runtime_type_key_under(result, substitutions),
  }
}
