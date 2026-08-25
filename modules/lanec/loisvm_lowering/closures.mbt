///|
fn FunctionLowerer::lower_nested_function(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
) -> LocalValue raise LoisvmLoweringError {
  let allocation = self.planned_callable_allocation(function.id, "nested")
  let implementation = self.image.materialized_callable_implementation(
    allocation.implementation,
  )
  NestedCallable({
    function,
    lowered_function: implementation.function,
    type_: implementation.type_,
    environment: self.capture_environment(
      self.image.physical_capture(implementation.function),
      allocation,
    ),
    invocation: allocation.interface.invocation,
  })
}

///|
fn FunctionLowerer::materialize_nested_callable(
  self : FunctionLowerer,
  callable : DeferredNestedCallable,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_callable_value_with_abi(
    callable.lowered_function,
    callable.type_,
    callable.environment,
    callable.invocation,
  )
}

///|
fn FunctionLowerer::materialize_planned_callable_atom(
  self : FunctionLowerer,
  atom : @anf.AnfAtom,
  callable : CallableRepresentationTarget,
) -> LocalValue raise LoisvmLoweringError {
  let function = match atom {
    Function(function) => Some(function)
    EvidenceLambda(body~, ..) => extract_top_function(body)
    Literal(_) | Ref(_) | Temp(_) => None
  }
  if function is Some(function) {
    return self.materialize_planned_callable_instance(function, callable)
  }
  let lowered = self.lower_atom(atom)
  let value = match lowered {
    Global(Function(_, _)) => {
      guard callable.instance(self.image.callable_instances) is Some(planned) else {
        raise RepresentationSpecializationInvariant(
          detail="planned callable flow names an unknown semantic instance",
        )
      }
      self.materialize_planned_callable_instance(
        planned.definition.function,
        callable,
      )
    }
    NestedCallable(nested) => self.materialize_nested_callable(nested)
    RecursiveFunction(_, _, _) => self.materialize_local(lowered)
    _ => self.materialize_local(lowered)
  }
  guard value is Slot(_, _, Callable(_)) else {
    raise RepresentationSpecializationInvariant(
      detail="planned callable flow did not materialize a callable slot",
    )
  }
  value
}

///|
fn FunctionLowerer::materialize_planned_callable_instance(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
  callable : CallableRepresentationTarget,
) -> LocalValue raise LoisvmLoweringError {
  guard callable.instance(self.image.callable_instances) is Some(planned) &&
    planned.definition.function.id == function.id else {
    raise RepresentationSpecializationInvariant(
      detail="planned callable payload does not match its function allocation",
    )
  }
  let allocation = self.planned_callable_allocation(
    function.id,
    "planned-instance",
  )
  let implementation = self.image.materialized_callable_implementation(
    allocation.implementation,
  )
  self.materialize_callable_value_with_abi(
    implementation.function,
    implementation.type_,
    self.capture_environment(
      self.image.physical_capture(implementation.function),
      allocation,
    ),
    allocation.interface.invocation,
  )
}

///|
fn FunctionLowerer::materialize_callable_value(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  lowered_type : @anf.RuntimeType,
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable(lowered_function, lowered_type, environment)
}

///|
fn FunctionLowerer::materialize_callable_value_with_abi(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  lowered_type : @anf.RuntimeType,
  environment : @vmcfg.ValueId?,
  invocation : CanonicalCallableAbi,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable_with_abi(
    lowered_function, lowered_type, environment, invocation,
  )
}

///|
fn FunctionLowerer::materialize_representation_worker(
  self : FunctionLowerer,
  plan : RepresentationSpecializationPlan,
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable(
    plan.worker,
    plan.callable_type(),
    environment,
  )
}

///|
fn FunctionLowerer::materialize_planned_callable(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  lowered_type : @anf.RuntimeType,
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable_with_abi(
    lowered_function,
    lowered_type,
    environment,
    self.image.physical_invocation(lowered_function),
  )
}

///|
fn FunctionLowerer::materialize_planned_callable_with_abi(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  lowered_type : @anf.RuntimeType,
  environment : @vmcfg.ValueId?,
  invocation : CanonicalCallableAbi,
) -> LocalValue raise LoisvmLoweringError {
  let shape = CanonicalRuntimeTypeKey::Callable(invocation)
  let destination = self.fresh_metadata(shape.value_metadata(None))
  match environment {
    None => {
      self.emit(ConstFunction(destination, lowered_function))
      LocalValue::Slot(destination, lowered_type, shape)
    }
    Some(environment) => {
      self.emit(MakeClosure(destination, lowered_function, environment))
      LocalValue::Slot(destination, lowered_type, shape)
    }
  }
}

///|
fn FunctionLowerer::lower_recursive_group(
  self : FunctionLowerer,
  bindings : Array[@anf.AnfRecursiveBinding],
  body : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  let plans : Array[LiftedFunctionPlan] = []
  for binding in bindings {
    let function = match extract_top_atom_function(binding.rhs) {
      Some(function) => function
      None =>
        raise UnsupportedExpression(
          detail="local recursive bindings must contain functions",
        )
    }
    let instance = self.image.callable_instance(function.id, self.substitutions)
    guard self.image.lifted_function(instance) is Some(plan) else {
      raise RepresentationSpecializationInvariant(
        detail="recursive callable is absent from the frozen function plan",
      )
    }
    plans.push(plan)
  }
  guard plans.get(0) is Some(first) else {
    raise RepresentationSpecializationInvariant(
      detail="recursive callable group is empty",
    )
  }
  let recursive_functions = first.recursive_functions
  let first_allocation = self.planned_callable_allocation(
    first.function.id,
    "recursive-group",
  )
  let first_implementation = self.image.materialized_callable_implementation(
    first_allocation.implementation,
  )
  let environment = self.capture_environment(
    self.image.physical_capture(first_implementation.function),
    first_allocation,
  )
  let value_count = self.bindings.length()
  for index, recursive in recursive_functions {
    let binding = @anf.AnfBindingId::Value(recursive.value)
    let callable = self.planned_callable_port(binding)
    let allocation = self.planned_callable_allocation(
      plans[index].function.id,
      "recursive-member",
    )
    let implementation = self.image.materialized_callable_implementation(
      allocation.implementation,
    )
    let deferred = RecursiveFunction(
      implementation.function,
      implementation.type_,
      environment,
    )
    let lowered = match callable {
      Some(_) => self.materialize_local(deferred)
      None => deferred
    }
    let lowered = self.apply_planned_binding_flow(binding, lowered)
    self.verify_planned_value(binding, lowered)
    self.bindings.push({ value: recursive.value, lowered, })
  }
  let result = self.lower_expr(body)
  self.restore_bindings(value_count, self.temps.length())
  result
}

///|
fn collect_free_runtime_evidence_in_expr(
  image : ImageLowerer,
  expression : @anf.AnfExpr,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match expression {
    Atom(atom) =>
      collect_free_runtime_evidence_in_atom(image, atom, bound, parameters)
    Let(binding, body) => {
      collect_free_runtime_evidence_in_rhs(
        image,
        binding.rhs(),
        bound,
        parameters,
      )
      collect_free_runtime_evidence_in_expr(image, body, bound, parameters)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_free_runtime_evidence_in_atom(
          image,
          binding.rhs,
          bound,
          parameters,
        )
      }
      collect_free_runtime_evidence_in_expr(image, body, bound, parameters)
    }
  }
}

///|
fn collect_free_runtime_evidence_in_rhs(
  image : ImageLowerer,
  rhs : @anf.AnfRhs,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match rhs {
    Atom(atom) =>
      collect_free_runtime_evidence_in_atom(image, atom, bound, parameters)
    ApplyEvidence(callee~, arguments~) => {
      collect_free_runtime_evidence_in_atom(image, callee, bound, parameters)
      for argument in arguments {
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
    }
    Call(callee~, arguments~) => {
      collect_free_runtime_evidence_in_atom(image, callee, bound, parameters)
      for argument in arguments {
        collect_free_runtime_evidence_in_atom(
          image, argument, bound, parameters,
        )
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments {
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
      for argument in construct.hidden_arguments {
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
      for payload in construct.payloads {
        collect_free_runtime_evidence_in_atom(image, payload, bound, parameters)
      }
    }
    Match(match_) => {
      collect_free_runtime_evidence_in_atom(
        image,
        match_.scrutinee,
        bound,
        parameters,
      )
      for alternative in match_.alternatives {
        let nested = bound.copy()
        nested.append(
          alternative.evidence_binders.map(parameter => parameter.id),
        )
        collect_free_runtime_evidence_in_expr(
          image,
          alternative.body,
          nested,
          parameters,
        )
      }
    }
  }
}

///|
fn collect_free_runtime_evidence_in_atom(
  image : ImageLowerer,
  atom : @anf.AnfAtom,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => ()
    Function(function) =>
      collect_free_runtime_evidence_in_expr(
        image,
        function.body,
        bound,
        parameters,
      )
    EvidenceLambda(parameters=binders, body~) => {
      let nested = bound.copy()
      nested.append(binders.map(parameter => parameter.id))
      collect_free_runtime_evidence_in_expr(image, body, nested, parameters)
    }
  }
}

///|
fn ImageLowerer::environment_shape(
  self : ImageLowerer,
  stored_witness_count : Int,
  members : Array[@bytecode.MemberSchema],
) -> @bytecode.ObjectShapeId? {
  if stored_witness_count == 0 && members.is_empty() {
    None
  } else {
    Some(
      self.intern_object_shape(Environment({ stored_witness_count, members, })),
    )
  }
}

///|
fn FunctionLowerer::make_capture_environment(
  self : FunctionLowerer,
  environment_shape : @bytecode.ObjectShapeId?,
  witnesses : Array[@vmcfg.ValueId],
  capture_slots : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId? {
  match environment_shape {
    None => None
    Some(shape) => {
      let layout = self.image.intern_layout(Environment(shape))
      let environment = self.fresh_metadata(environment_metadata(shape))
      self.emit(
        MakeEnv(environment, shape, Immediate(layout), witnesses, capture_slots),
      )
      Some(environment)
    }
  }
}

///|
fn FunctionLowerer::capture_value(
  self : FunctionLowerer,
  binding : CaptureBinding,
) -> LocalValue raise LoisvmLoweringError {
  match binding {
    Value(value) => self.find_value(value)
    Temp(temp) => self.find_temp(temp)
  }
}

///|
fn FunctionLowerer::bind_capture(
  self : FunctionLowerer,
  binding : CaptureBinding,
  value : LocalValue,
) -> Unit {
  match binding {
    Value(id) => self.bindings.push({ value: id, lowered: value, })
    Temp(temp) => self.temps.push({ temp, lowered: value, })
  }
}
