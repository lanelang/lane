///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> CallableAdapterPlan {
  for adapter in self.callable_adapters {
    if adapter.recipe == contract.recipe {
      return adapter
    }
  }
  let members : Array[@bytecode.MemberSchema] = []
  for metadata in contract.recipe.captured_evidence {
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
    Environment({ stored_witness_count: 0, members, }),
  )
  let (_, adapter) = self.plans.append_with_result(CallableAdapter, fn(
    function,
  ) {
    let adapter : CallableAdapterPlan = {
      function,
      recipe: contract.recipe,
      environment_shape,
    }
    self.callable_adapters.push(adapter)
    (CallableAdapter(adapter), adapter)
  })
  adapter
}

///|
fn ImageLowerer::planned_callable_adapter(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> CallableAdapterPlan raise LoisvmLoweringError {
  self.planned_callable_adapter_recipe(contract.recipe)
}

///|
fn ImageLowerer::planned_callable_adapter_recipe(
  self : ImageLowerer,
  recipe : CallableAdapterRecipe,
) -> CallableAdapterPlan raise LoisvmLoweringError {
  for adapter in self.callable_adapters {
    if adapter.recipe == recipe {
      return adapter
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="VM CFG emission requested a callable adapter absent from the frozen representation plan",
  )
}

///|
fn ImageLowerer::preplan_callable_adapter(
  self : ImageLowerer,
  contract : CallableAdapterContract,
) -> Unit raise LoisvmLoweringError {
  for adapter in self.callable_adapters {
    if adapter.recipe == contract.recipe {
      return
    }
  }
  ignore(self.callable_adapter(contract))
  self.preplan_callable_adapter_recipe_evidence(contract.recipe)
  for entry in contract.substitutions.entries {
    if entry.1.evidence is Lambda(_, _) {
      ignore(self.plan_layout_constructor(entry.1.evidence))
    }
  }
  for nested in contract.nested_adapters {
    self.preplan_callable_adapter(nested)
  }
}

///|
fn ImageLowerer::preplan_callable_adapter_recipe_evidence(
  self : ImageLowerer,
  recipe : CallableAdapterRecipe,
) -> Unit raise LoisvmLoweringError {
  for witness in recipe.source_witnesses {
    self.preplan_callable_adapter_evidence_recipe(witness)
  }
  for parameter in recipe.target_parameters {
    self.preplan_callable_adapter_value_recipe(parameter)
  }
  for argument in recipe.source_arguments {
    self.preplan_callable_adapter_flow_recipe(argument.flow)
  }
  if recipe.result is Adapt(flow) {
    self.preplan_callable_adapter_flow_recipe(flow)
  }
}

///|
fn ImageLowerer::preplan_callable_adapter_flow_recipe(
  self : ImageLowerer,
  flow : CallableAdapterValueFlowRecipe,
) -> Unit raise LoisvmLoweringError {
  self.preplan_callable_adapter_value_recipe(flow.value)
  self.preplan_callable_adapter_value_recipe(flow.source_shape)
  self.preplan_callable_adapter_value_recipe(flow.target)
  self.preplan_callable_adapter_value_recipe(flow.target_shape)
  if flow.nested_adapter is Some(nested) {
    self.preplan_callable_adapter_recipe_evidence(nested.recipe)
    for evidence in nested.captured_evidence {
      self.preplan_callable_adapter_evidence_recipe(evidence)
    }
  }
}

///|
fn ImageLowerer::preplan_callable_adapter_value_recipe(
  self : ImageLowerer,
  recipe : CallableAdapterValueRecipe,
) -> Unit raise LoisvmLoweringError {
  if recipe is Erased(evidence) {
    self.preplan_callable_adapter_evidence_recipe(evidence)
  }
}

///|
fn ImageLowerer::preplan_callable_adapter_evidence_recipe(
  self : ImageLowerer,
  recipe : CallableAdapterEvidenceRecipe,
) -> Unit raise LoisvmLoweringError {
  match recipe {
    Input(_) | Capture(_) | Static(_) => ()
    Apply(callee, arguments) => {
      self.preplan_callable_adapter_evidence_recipe(callee)
      for argument in arguments {
        self.preplan_callable_adapter_evidence_recipe(argument)
      }
    }
    LayoutConstructor(evidence, captured) => {
      ignore(self.plan_layout_constructor(evidence))
      for capture in captured {
        self.preplan_callable_adapter_evidence_recipe(capture)
      }
    }
  }
}

///|
fn ImageLowerer::plan_value_adaptation(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let source_shape = substitutions.apply_type(self.runtime_types, source_type)
  let target_shape = substitutions.apply_type(self.runtime_types, target_type)
  let source_runtime = self.runtime_type(source_type)
  let target_runtime = self.runtime_type(target_type)
  let contract = match (source_runtime, target_runtime) {
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
    _ =>
      match (self.runtime_type(source_shape), self.runtime_type(target_shape)) {
        (
          Concrete(Callable(_, _) | Forall(_, _) as source),
          Concrete(Callable(_, _) | Forall(_, _) as target),
        ) => self.plan_callable_adaptation(source, target, substitutions)
        _ => None
      }
  }
  contract
}

///|
fn ImageLowerer::plan_erased_callable_adaptation(
  self : ImageLowerer,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  instance : CallableRepresentationTarget?,
  target_interface : PhysicalCallableInterface,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let resolved_target = substitutions.apply_type(
    self.runtime_types,
    target_type,
  )
  let source = match resolved_target {
    Callable(_, _) | Forall(_, _) as target => target
    _ => {
      guard instance is Some(instance) &&
        instance.instance(self.callable_instances) is Some(planned) else {
        raise RepresentationSpecializationInvariant(
          detail="non-canonical erased-to-callable physical flow has no callable instance provenance",
        )
      }
      let source = planned.substitution.apply_type(
        self.runtime_types,
        planned.definition.type_,
      )
      guard source is (Callable(_, _) | Forall(_, _)) else {
        raise RepresentationSpecializationInvariant(
          detail="erased callable instance \{Repr(instance)} has no callable semantic type",
        )
      }
      source
    }
  }
  let (canonical, bindings) = self.canonical_callable_type(source)
  let source_interface = self.canonical_callable_interface_under(
    canonical, bindings,
  )
  let source_abi = source_interface.invocation
  let target_abi = target_interface.invocation
  if source_interface.representation_equal(target_interface) {
    return None
  }
  guard self.plan_callable_representation_adaptation(
      None,
      instance,
      canonical,
      source,
      bindings,
      source_abi,
      target_abi,
      Some(source_interface),
      Some(target_interface),
    )
    is Some(contract) else {
    raise RepresentationSpecializationInvariant(
      detail="erased callable payload and target ABI differ without an adaptation recipe",
    )
  }
  Some(contract)
}

///|
fn ImageLowerer::plan_callable_erasure_adaptation(
  self : ImageLowerer,
  source : @anf.RuntimeType,
  source_interface : PhysicalCallableInterface,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  guard self.runtime_type(source)
    is Concrete(Callable(_, _) | Forall(_, _) as source) else {
    raise RepresentationSpecializationInvariant(
      detail="callable erasure has no concrete semantic source type",
    )
  }
  let (canonical, bindings) = self.canonical_callable_type(source)
  let target_interface = self.canonical_callable_interface_under(
    canonical, bindings,
  )
  if source_interface.representation_equal(target_interface) {
    return None
  }
  self.plan_callable_adaptation_with_interfaces(
    source, canonical, bindings, source_interface, target_interface,
  )
}

///|
fn ImageLowerer::callable_erasure_source_type(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  instance : CallableRepresentationTarget?,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  let source = substitutions.apply_type(self.runtime_types, source_type)
  if self.runtime_type(source)
    is Concrete(Callable(_, _) | Forall(_, _) as source) {
    return source
  }
  guard instance is Some(instance) &&
    instance.instance(self.callable_instances) is Some(planned) else {
    raise RepresentationSpecializationInvariant(
      detail="physical callable erasure of \{Repr(source_type)} resolved as \{Repr(source)} under \{Repr(substitutions)} has no semantic callable provenance \{Repr(instance)}",
    )
  }
  let source = planned.substitution.apply_type(
    self.runtime_types,
    planned.definition.type_,
  )
  guard source is (Callable(_, _) | Forall(_, _)) else {
    raise RepresentationSpecializationInvariant(
      detail="physical callable erasure provenance is not callable",
    )
  }
  source
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
fn ImageLowerer::callable_adapter_evidence_captures(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> (
  Array[CallableAdapterEvidenceCapture],
  Array[CallableAdapterEvidenceAlias],
) raise LoisvmLoweringError {
  let captures : Array[CallableAdapterEvidenceCapture] = []
  let aliases : Array[CallableAdapterEvidenceAlias] = []
  for parameter in free_runtime_type_parameters(self, source_type, target_type) {
    let resolved = self.callable_adapter_parameter_evidence(
      parameter,
      substitutions.apply_evidence(Parameter(parameter.id)),
    )
    self.collect_callable_adapter_evidence_captures(resolved, captures)
    let source = Existing(parameter.id)
    if source != resolved {
      aliases.push({ evidence: source, replacement: resolved, })
    }
  }
  let source_type = substitutions.apply_type(self.runtime_types, source_type)
  let target_type = substitutions.apply_type(self.runtime_types, target_type)
  let (source_parameters, _, _) = function_type_parts(source_type)
  let (target_parameters, _, _) = function_type_parts(target_type)
  if source_parameters.length() == target_parameters.length() {
    return (captures, aliases)
  }
  for parameter in source_parameters {
    let resolved = substitutions.apply_evidence(Parameter(parameter.id))
    guard resolved != Parameter(parameter.id) else { continue }
    let discovered : Array[CallableAdapterEvidenceCapture] = []
    self.collect_callable_adapter_evidence_captures(
      self.callable_adapter_parameter_evidence(parameter, resolved),
      discovered,
    )
    for capture in discovered {
      if !target_parameters.any(target => target.id == capture.source.id) &&
        !captures.any(existing => existing.source.id == capture.source.id) {
        captures.push(capture)
      }
    }
  }
  (captures, aliases)
}

///|
fn ImageLowerer::callable_adapter_parameter_evidence(
  self : ImageLowerer,
  parameter : @anf.RuntimeEvidenceParameter,
  evidence : @anf.RuntimeEvidence,
) -> RuntimeEvidencePlan raise LoisvmLoweringError {
  if parameter.arity == 0 {
    self.plan_layout_witness(evidence)
  } else {
    self.plan_layout_constructor_evidence(evidence)
  }
}

///|
fn ImageLowerer::collect_callable_adapter_evidence_captures(
  self : ImageLowerer,
  plan : RuntimeEvidencePlan,
  captures : Array[CallableAdapterEvidenceCapture],
) -> Unit raise LoisvmLoweringError {
  match plan {
    Existing(id) =>
      if !captures.any(capture => capture.source.id == id) {
        captures.push({
          source: self.evidence_parameter(id).unwrap_or({ id, arity: 0, }),
        })
      }
    ApplyEvidence(id, arguments) => {
      if !captures.any(capture => capture.source.id == id) {
        captures.push({
          source: self
          .evidence_parameter(id)
          .unwrap_or({ id, arity: arguments.length(), }),
        })
      }
      for argument in arguments {
        self.collect_callable_adapter_evidence_captures(argument, captures)
      }
    }
    MaterializeLayoutConstructor(evidence) => {
      let layout_constructor = self.layout_constructor_contract(evidence)
      for parameter in layout_constructor.captured_parameters {
        if !captures.any(capture => capture.source.id == parameter.id) {
          captures.push({ source: parameter, })
        }
      }
    }
    StaticLayout(_) => ()
  }
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
  let argument = match substitutions.argument(parameter) {
    Some(argument) =>
      Some(
        self.substitutions.apply_argument(self.image.runtime_types, argument),
      )
    None =>
      self.substitutions
      .argument(parameter)
      .map(argument => {
        self.substitutions.apply_argument(self.image.runtime_types, argument)
      })
  }
  if argument is Some(argument) {
    let parameter_info = self.image.metadata
      .evidence_parameter(parameter)
      .unwrap_or({ id: parameter, arity: 0, })
    return self.runtime_evidence(parameter_info, argument)
  }
  self.find_witness(parameter)
}

///|
fn ImageLowerer::plan_callable_adaptation(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let source_interface = self.canonical_callable_interface_under(
    source_type, substitutions,
  )
  let target_interface = self.canonical_callable_interface_under(
    target_type, substitutions,
  )
  self.plan_callable_adaptation_with_interfaces(
    source_type, target_type, substitutions, source_interface, target_interface,
  )
}

///|
/// Plans one callable conversion from semantic compatibility plus the physical
/// ABI facts owned by the enclosing value-flow boundary. Type substitution may
/// prove that two semantic types are equal; it may not overwrite either ABI.
fn ImageLowerer::plan_callable_adaptation_with_interfaces(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  source_interface : PhysicalCallableInterface,
  target_interface : PhysicalCallableInterface,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let (source_parameter_targets, adapter_substitutions) = self.align_callable_parameters(
    source_type, target_type, substitutions,
  )
  if source_interface.representation_equal(target_interface) {
    return None
  }
  let (captures, evidence_aliases) = self.callable_adapter_evidence_captures(
    source_type, target_type, adapter_substitutions,
  )
  let nested_adapters = []
  Some({
    recipe: self.callable_adapter_recipe_with_interfaces(
      source_type, target_type, source_interface, target_interface, source_parameter_targets,
      adapter_substitutions, captures, evidence_aliases, nested_adapters,
    ),
    source_type,
    target_type,
    source_parameter_targets,
    substitutions: adapter_substitutions,
    captures,
    nested_adapters,
  })
}

///|
/// Plans the boundary between the generic implementation ABI and the one
/// representation worker owned by a semantic callable target. The target's
/// closed substitution is the proof that generic erased parameters and worker
/// parameters denote the same logical values; the adapter must not try to
/// rediscover that relation from the two lowered type spellings.
fn ImageLowerer::plan_callable_representation_adaptation(
  self : ImageLowerer,
  source_callable : CallableRepresentationTarget?,
  target_callable : CallableRepresentationTarget?,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  source_abi : CanonicalCallableAbi,
  target_abi : CanonicalCallableAbi,
  source_interface : PhysicalCallableInterface?,
  target_interface : PhysicalCallableInterface?,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let candidates = []
  if source_callable is Some(callable) {
    candidates.push(callable)
  }
  if target_callable is Some(callable) && !candidates.contains(callable) {
    candidates.push(callable)
  }
  let mut boundary_substitutions = substitutions
  boundary_substitutions = boundary_substitutions.overlay(
    self.callable_type_parameter_alignment(source_type, target_type),
  )
  let mut representation_source = source_type
  let mut representation_target = target_type
  let mut source_interface = source_interface
  let mut target_interface = target_interface
  let mut owns_boundary = false
  for callable in candidates {
    guard callable.instance(self.callable_instances) is Some(instance) else {
      continue
    }
    let semantic_type = self.callable_representation_semantic_type(callable)
    let owns_source = self.types_representation_equivalent(
      boundary_substitutions.apply_type(self.runtime_types, source_type),
      boundary_substitutions.apply_type(self.runtime_types, semantic_type),
    )
    let owns_target = self.types_representation_equivalent(
      boundary_substitutions.apply_type(self.runtime_types, target_type),
      boundary_substitutions.apply_type(self.runtime_types, semantic_type),
    )
    if !owns_source && !owns_target {
      continue
    }
    boundary_substitutions = instance.substitution.compose(
      boundary_substitutions,
      self.runtime_types,
    )
    if self.callable_representation_implementation(callable, false)
      is Some(generic) {
      let generic_abi = self.generic_callable_representation_physical_abi(
        callable,
      )
      if source_abi == generic_abi {
        representation_source = generic.type_
        if source_interface is None {
          source_interface = Some(
            self.callable_representation_interface(callable, worker=false),
          )
        }
        owns_boundary = true
      }
      if target_abi == generic_abi {
        representation_target = generic.type_
        if target_interface is None {
          target_interface = Some(
            self.callable_representation_interface(callable, worker=false),
          )
        }
        owns_boundary = true
      }
    }
    if self.representation_specialization_for_callable(callable) is Some(worker) {
      boundary_substitutions = worker.substitutions.compose(
        boundary_substitutions,
        self.runtime_types,
      )
      let worker_type = worker.callable_type()
      let worker_abi = self.representation_worker_invocation(worker)
      if source_abi == worker_abi {
        representation_source = worker_type
        if source_interface is None {
          source_interface = Some(self.representation_worker_interface(worker))
        }
        owns_boundary = true
      }
      if target_abi == worker_abi {
        representation_target = worker_type
        if target_interface is None {
          target_interface = Some(self.representation_worker_interface(worker))
        }
        owns_boundary = true
      }
    }
  }
  boundary_substitutions = self.overlay_callable_type_parameter_alignment(
    boundary_substitutions, source_type, representation_source,
  )
  boundary_substitutions = self.overlay_callable_type_parameter_alignment(
    boundary_substitutions, target_type, representation_target,
  )
  let source_interface = match source_interface {
    Some(interface) => interface
    None =>
      self.canonical_callable_interface_under(
        representation_source, boundary_substitutions,
      )
  }
  let target_interface = match target_interface {
    Some(interface) => interface
    None =>
      self.canonical_callable_interface_under(
        representation_target, boundary_substitutions,
      )
  }
  if source_interface.invocation != source_abi ||
    target_interface.invocation != target_abi {
    raise RepresentationSpecializationInvariant(
      detail="callable adaptation boundary interfaces \{Repr((source_interface, target_interface))} disagree with physical ABIs \{Repr((source_abi, target_abi))}",
    )
  }
  if owns_boundary {
    return self.plan_callable_adaptation_with_interfaces(
      representation_source, representation_target, boundary_substitutions, source_interface,
      target_interface,
    )
  }
  self.plan_callable_adaptation_with_interfaces(
    source_type, target_type, boundary_substitutions, source_interface, target_interface,
  )
}

///|
fn ImageLowerer::overlay_callable_type_parameter_alignment(
  self : ImageLowerer,
  substitutions : RuntimeSubstitution,
  semantic_type : @anf.RuntimeType,
  implementation_type : @anf.RuntimeType,
) -> RuntimeSubstitution raise LoisvmLoweringError {
  let alignment = self.callable_type_parameter_alignment(
    semantic_type, implementation_type,
  )
  let mut result = substitutions
  for parameter in alignment.parameters() {
    let existing = result.argument(parameter)
    let identity = existing is Some(argument) &&
      argument.evidence == @anf.RuntimeEvidence::Parameter(parameter) &&
      self.runtime_types.type_expression(argument.type_expression) ==
      Some(@anf.RuntimeTypeExpression::Parameter(parameter))
    if existing is None || identity {
      guard alignment.argument(parameter) is Some(argument) else {
        raise RepresentationSpecializationInvariant(
          detail="callable type-parameter alignment lost one of its parameters",
        )
      }
      let replacement = RuntimeSubstitution::new()
      replacement.insert(parameter, argument)
      result = result.overlay(replacement)
    }
  }
  let refinable = []
  collect_free_runtime_type_parameters(self, implementation_type, [], refinable)
  if !refinable.is_empty() &&
    self.refine_callable_representation_substitution(
      implementation_type,
      semantic_type,
      result,
      refinable.map(parameter => parameter.id),
    )
    is Some(refined) {
    result = refined
  }
  result
}

///|
fn FunctionLowerer::materialize_callable_adapter(
  self : FunctionLowerer,
  adaptation : DeferredCallableAdapter,
) -> LocalValue raise LoisvmLoweringError {
  let (plan, environment) = self.planned_callable_adapter_environment(
    adaptation,
  )
  self.materialize_callable_adapter_closure(adaptation, plan, environment)
}

///|
fn FunctionLowerer::materialize_callable_adapter_closure(
  self : FunctionLowerer,
  adaptation : DeferredCallableAdapter,
  plan : CallableAdapterPlan,
  environment : @vmcfg.ValueId,
) -> LocalValue raise LoisvmLoweringError {
  let target_shape = CanonicalRuntimeTypeKey::Callable(
    adaptation.contract.recipe.target_abi,
  )
  let callable = self.fresh_metadata(target_shape.value_metadata(None))
  self.emit(MakeClosure(callable, plan.function, environment))
  LocalValue::Slot(callable, adaptation.contract.target_type, target_shape)
}

///|
fn FunctionLowerer::materialize_planned_callable_bridge(
  self : FunctionLowerer,
  provenance : String,
  value : LocalValue,
  contract : CallableAdapterContract,
) -> LocalValue raise LoisvmLoweringError {
  let materialized = self.materialize_local(value)
  guard materialized is Slot(source, _, source_shape) &&
    source_shape ==
    CanonicalRuntimeTypeKey::Callable(contract.recipe.source_abi) else {
    raise RepresentationSpecializationInvariant(
      detail="planned callable bridge source is not \{Repr(contract.recipe.source_abi)} in \{provenance}",
    )
  }
  self.materialize_callable_adapter({
    source,
    contract,
    captured_witnesses: contract.captures.map(capture => {
      let value = self.adapter_witness(
        capture.source.id,
        contract.substitutions,
      ) catch {
        error =>
          raise RepresentationSpecializationInvariant(
            detail="\{provenance} in \{Repr(self.function)} with specialized evidence \{Repr(self.specialized_parameters)} cannot materialize captured evidence \{Repr(capture.source)} for \{Repr(contract.source_type)} / \{Repr(contract.recipe.source_abi)} -> \{Repr(contract.target_type)} / \{Repr(contract.recipe.target_abi)} under \{Repr(contract.substitutions)}: \{Repr(error)}",
          )
      }
      { parameter: capture.source.id, value, }
    }),
  })
}

///|
fn FunctionLowerer::planned_callable_adapter_environment(
  self : FunctionLowerer,
  adaptation : DeferredCallableAdapter,
) -> (CallableAdapterPlan, @vmcfg.ValueId) raise LoisvmLoweringError {
  if self.physical is Some(function) {
    guard function.authorizes_bridge(adaptation.contract) else {
      raise RepresentationSpecializationInvariant(
        detail="represented VM CFG emission requested \{Repr(adaptation.contract.recipe)}, but its physical function variant authorizes \{Repr(function.callable_bridge_recipes())}",
      )
    }
  }
  self.callable_adapter_environment(adaptation)
}

///|
fn FunctionLowerer::callable_adapter_environment(
  self : FunctionLowerer,
  adaptation : DeferredCallableAdapter,
) -> (CallableAdapterPlan, @vmcfg.ValueId) raise LoisvmLoweringError {
  let plan = self.image.planned_callable_adapter(adaptation.contract)
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
  (plan, environment)
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
  let (_, source_parameters, _) = function_type_parts(source_type)
  let (_, target_parameters, _) = function_type_parts(target_type)
  let alignment = self.callable_type_parameter_alignment(
    source_type, target_type,
  )
  let mut alignment_substitutions = substitutions.overlay(alignment)
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
    let mut actual_source = alignment_substitutions.apply_type(
      self.runtime_types,
      source_parameters[source_index],
    )
    let mut actual_target = alignment_substitutions.apply_type(
      self.runtime_types,
      target_parameter,
    )
    if !self.types_representation_equivalent(actual_source, actual_target) {
      let refinable = []
      collect_free_runtime_type_parameters(self, actual_source, [], refinable)
      if !refinable.is_empty() {
        if self.refine_callable_representation_substitution(
            actual_source,
            actual_target,
            alignment_substitutions,
            refinable.map(parameter => parameter.id),
          )
          is Some(refined) {
          alignment_substitutions = refined
        }
        actual_source = alignment_substitutions.apply_type(
          self.runtime_types,
          source_parameters[source_index],
        )
        actual_target = alignment_substitutions.apply_type(
          self.runtime_types,
          target_parameter,
        )
      }
    }
    if !self.types_representation_equivalent(actual_source, actual_target) {
      raise InvalidTypeApplication(
        detail="callable adapter source parameter \{source_index}/\{source_parameters.length()} (\{Repr(actual_source)}) does not align with target parameter \{target_index}/\{target_parameters.length()} (\{Repr(actual_target)}) in source \{Repr(source_type)} and target \{Repr(target_type)} under \{Repr(substitutions)}",
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
fn ImageLowerer::callable_type_parameter_alignment(
  self : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
) -> RuntimeSubstitution raise LoisvmLoweringError {
  let (source_parameters, _, _) = function_type_parts(source_type)
  let (target_parameters, _, _) = function_type_parts(target_type)
  let alignment = RuntimeSubstitution::new()
  if source_parameters.length() != target_parameters.length() {
    return alignment
  }
  for index, target_parameter in target_parameters {
    let source_parameter = source_parameters[index]
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
  alignment
}

///|
fn local_value_type(value : LocalValue) -> @anf.RuntimeType? {
  match value {
    Slot(_, type_, _) => Some(type_)
    ClosedAggregate(contract, _) => Some(contract.type_)
    Global(Function(_, type_))
    | Global(FloatConstant(_, type_))
    | Global(DoubleConstant(_, type_))
    | Global(InstanceGlobal(_, type_, _, _)) => Some(type_)
    Global(Intrinsic(contract)) => Some(contract.type_())
    RecursiveFunction(_, type_, _) => Some(type_)
    EvidenceAppliedCallable(_, _, _, application)
    | EvidenceAppliedNestedCallable(_, application)
    | EvidenceApplied(_, application) => Some(application.target_type)
    NestedCallable(callable) => Some(callable.type_)
    Global(UnitValue) | Unit => None
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
    function: Some(plan.function),
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: RuntimeSubstitution::new(),
    specialized_parameters: [],
    physical: None,
  }
  let input_witnesses = []
  for witness in recipe.target_abi.witnesses {
    input_witnesses.push(
      lowerer.fresh_metadata(
        CanonicalRuntimeTypeKey::Value(witness).value_metadata(None),
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
      CanonicalRuntimeTypeKey::Value(evidence).borrowed_value_metadata(None),
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
    CanonicalRuntimeTypeKey::Callable(recipe.source_abi).borrowed_value_metadata(
      None,
    ),
  )
  lowerer.emit(
    BorrowCapture(
      plan.environment_shape,
      environment,
      recipe.captured_evidence.length(),
      { value_destination: source_callable, witness_destination: None, },
    ),
  )
  let source_witnesses = recipe.source_witnesses.map(witness => {
    lowerer.materialize_callable_adapter_evidence(
      witness, input_witnesses, captured_evidence,
    )
  })
  let user_parameter_slots = []
  for parameter in recipe.target_parameters {
    guard lowerer.fresh_callable_adapter_value(
        parameter, input_witnesses, captured_evidence,
      )
      is Some(slot) else {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter physical parameter is Unit",
      )
    }
    user_parameter_slots.push(slot)
  }
  for discard in recipe.target_discards {
    guard user_parameter_slots.get(discard.input) is Some(input) &&
      lowerer.adapt_callable_adapter_value(
        Some(input),
        discard.flow,
        input_witnesses,
        captured_evidence,
      )
      is None else {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter discard did not consume its target parameter",
      )
    }
  }
  let source_arguments = []
  for argument in recipe.source_arguments {
    let input = match argument.input {
      TargetParameter(target) => {
        guard user_parameter_slots.get(target) is Some(input) else {
          raise RepresentationSpecializationInvariant(
            detail="callable adapter source argument selects no physical input",
          )
        }
        Some(input)
      }
      Unit => None
    }
    guard lowerer.adapt_callable_adapter_value(
        input,
        argument.flow,
        input_witnesses,
        captured_evidence,
      )
      is Some(adapted) else {
      raise RepresentationSpecializationInvariant(
        detail="callable adapter source argument lowered to Unit",
      )
    }
    source_arguments.push(adapted)
  }
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
    result: recipe.target_abi.result.physical_shape().result_abi(),
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
    Concrete(key) => Some(self.fresh_metadata(key.value_metadata(None)))
    Erased(evidence) => {
      let companion = self.materialize_callable_adapter_evidence(
        evidence, inputs, captures,
      )
      guard recipe.physical_key() is Some(key) else {
        raise RepresentationSpecializationInvariant(
          detail="erased callable adapter value has no physical key",
        )
      }
      Some(self.fresh_metadata(key.value_metadata(Some(companion))))
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
        raise RepresentationSpecializationInvariant(
          detail="Unit callable adapter flow received a physical value",
        )
      }
      None
    }
    (Unit, Erased(evidence)) => {
      if value is Some(_) {
        raise RepresentationSpecializationInvariant(
          detail="Unit callable adapter erasure received a physical value",
        )
      }
      let witness = self.materialize_callable_adapter_evidence(
        evidence, inputs, captures,
      )
      let destination = self.fresh_erased_slot(witness, Owned)
      self.emit(EraseUnit(destination))
      Some(destination)
    }
    (Erased(_), Unit) => {
      guard value is Some(source) else {
        raise RepresentationSpecializationInvariant(
          detail="callable adapter Unit projection has no erased source",
        )
      }
      self.emit(UneraseUnit(source))
      None
    }
    (Erased(_), Erased(_)) => value
    (Concrete(_), Erased(evidence)) => {
      guard value is Some(source) else {
        raise RepresentationSpecializationInvariant(
          detail="callable adapter erasure has no concrete source",
        )
      }
      let source = self.materialize_nested_callable_adapter(
        source,
        flow.nested_adapter,
        inputs,
        captures,
      )
      let witness = self.materialize_callable_adapter_evidence(
        evidence, inputs, captures,
      )
      let destination = self.fresh_erased_slot(witness, Owned)
      self.emit_callable_adapter_erasure(destination, source, flow.source_shape)
      Some(destination)
    }
    (Erased(_), Concrete(target)) => {
      guard value is Some(source) else {
        raise RepresentationSpecializationInvariant(
          detail="callable adapter unerasure has no erased source",
        )
      }
      let concrete = self.emit_callable_adapter_unerasure(source, target)
      Some(
        self.materialize_nested_callable_adapter(
          concrete,
          flow.nested_adapter,
          inputs,
          captures,
        ),
      )
    }
    (Concrete(_), Concrete(_)) => {
      guard value is Some(source) else {
        raise RepresentationSpecializationInvariant(
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
    (Unit, Concrete(_)) | (Concrete(_), Unit) =>
      raise RepresentationSpecializationInvariant(
        detail="callable adapter changes Unit into a concrete runtime value",
      )
  }
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
      match inputs.get(index) {
        Some(value) => value
        None =>
          raise RepresentationSpecializationInvariant(
            detail="callable adapter evidence selects missing input \{index}",
          )
      }
    Capture(index) =>
      match captures.get(index) {
        Some(value) => value
        None =>
          raise RepresentationSpecializationInvariant(
            detail="callable adapter evidence selects missing capture \{index}",
          )
      }
    Apply(callee, arguments) => {
      let callee = self.materialize_callable_adapter_evidence(
        callee, inputs, captures,
      )
      let arguments = arguments.map(argument => {
        self.materialize_callable_adapter_evidence(argument, inputs, captures)
      })
      let result = self.fresh_metadata(layout_witness_metadata())
      self.emit(CallValue(callee, [], arguments, Some(result)))
      result
    }
    LayoutConstructor(evidence, captured) => {
      let plan = self.image.planned_layout_constructor(evidence)
      if plan.captured_parameters.length() != captured.length() {
        raise RepresentationSpecializationInvariant(
          detail="callable adapter layout constructor capture arity disagrees with its plan",
        )
      }
      let captured = captured.map(capture => {
        self.materialize_callable_adapter_evidence(capture, inputs, captures)
      })
      let environment = self.make_capture_environment(
        plan.environment_shape,
        [],
        captured,
      )
      let result = self.fresh_metadata(layout_constructor_metadata(plan.arity))
      match environment {
        None => self.emit(ConstFunction(result, plan.function))
        Some(environment) =>
          self.emit(MakeClosure(result, plan.function, environment))
      }
      result
    }
    Static(layout) => {
      let layout = self.image.intern_layout(layout)
      let result = self.fresh_metadata(layout_witness_metadata())
      self.emit(ConstLayout(result, layout))
      result
    }
  }
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
  let plan = self.image.planned_callable_adapter_recipe(nested.recipe)
  let captured_evidence = nested.captured_evidence.map(evidence => {
    self.materialize_callable_adapter_evidence(evidence, inputs, captures)
  })
  if captured_evidence.length() != nested.recipe.captured_evidence.length() {
    raise RepresentationSpecializationInvariant(
      detail="nested callable adapter capture arity disagrees with its recipe",
    )
  }
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
      captured_evidence + [source],
    ),
  )
  let result = self.fresh_metadata(
    CanonicalRuntimeTypeKey::Callable(nested.recipe.target_abi).value_metadata(
      None,
    ),
  )
  self.emit(MakeClosure(result, plan.function, environment))
  result
}

///|
fn FunctionLowerer::emit_callable_adapter_erasure(
  self : FunctionLowerer,
  destination : @vmcfg.ValueId,
  source : @vmcfg.ValueId,
  recipe : CallableAdapterValueRecipe,
) -> Unit raise LoisvmLoweringError {
  guard recipe.physical_key() is Some(key) else {
    raise RepresentationSpecializationInvariant(
      detail="callable adapter erasure source is Unit",
    )
  }
  let representation = match key {
    Value(abi) => abi.representation
    Callable(_) => I64
    Unit =>
      raise RepresentationSpecializationInvariant(
        detail="callable adapter erasure source has an invalid Unit key",
      )
  }
  match representation {
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
  target : CanonicalRuntimeTypeKey,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let destination = self.fresh_metadata(target.value_metadata(None))
  let representation = match target {
    Value(abi) => abi.representation
    Callable(_) => I64
    Unit =>
      raise RepresentationSpecializationInvariant(
        detail="callable adapter unerasure target has an invalid Unit key",
      )
  }
  match representation {
    I32 => self.emit(UneraseI32(destination, source))
    I64 => self.emit(UneraseI64(destination, source))
    F32 => self.emit(UneraseF32(destination, source))
    F64 => self.emit(UneraseF64(destination, source))
  }
  destination
}
