///|
fn FunctionLowerer::lower_nested_function(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
) -> LocalValue raise LoisvmLoweringError {
  let instance = self.image.callable_instance(function.id, self.substitutions)
  let planned = self.image.callable_instances.instances[instance]
  guard self.image.lifted_function(instance) is Some(plan) else {
    raise RepresentationSpecializationInvariant(
      detail="nested callable \{Repr(function.id)} instance \{instance} (owner=\{Repr(planned.definition.owner)}, generic=\{planned.generic_fallback}, group=\{Repr(planned.definition.recursive_group)}) is absent from the frozen function plan",
    )
  }
  let function_type = planned.substitution.apply_type(
    self.image.runtime_types,
    planned.definition.type_,
  )
  let (function_type, capture) = if self.representation_worker &&
    self.image.representation_specialization_for_instance(instance)
    is Some(worker) {
    (worker.callable_type(), worker.capture)
  } else {
    (function_type, plan.capture)
  }
  NestedCallable({
    function,
    instance,
    type_: function_type,
    environment: self.capture_environment(capture),
  })
}

///|
fn FunctionLowerer::materialize_nested_callable(
  self : FunctionLowerer,
  callable : DeferredNestedCallable,
) -> LocalValue raise LoisvmLoweringError {
  if self.representation_worker &&
    self.image.representation_specialization_for_instance(callable.instance)
    is Some(plan) {
    return self.materialize_representation_worker(plan, callable.environment)
  }
  guard self.image.lifted_function(callable.instance) is Some(plan) else {
    raise RepresentationSpecializationInvariant(
      detail="nested callable is absent from the frozen function plan",
    )
  }
  self.materialize_planned_callable(
    plan.lowered_function,
    callable.type_,
    callable.environment,
  )
}

///|
fn FunctionLowerer::materialize_planned_callable_atom(
  self : FunctionLowerer,
  atom : @anf.AnfAtom,
  instance : Int,
) -> LocalValue raise LoisvmLoweringError {
  let function = match atom {
    Function(function) => function
    EvidenceLambda(body~, ..) =>
      match extract_top_function(body) {
        Some(function) => function
        None =>
          raise RepresentationSpecializationInvariant(
            detail="planned callable use has no function",
          )
      }
    _ =>
      raise RepresentationSpecializationInvariant(
        detail="planned callable use is not a callable allocation",
      )
  }
  self.materialize_planned_callable_instance(function, instance)
}

///|
fn FunctionLowerer::materialize_planned_callable_instance(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
  instance : Int,
) -> LocalValue raise LoisvmLoweringError {
  guard self.image.callable_instances.instances.get(instance) is Some(planned) &&
    planned.definition.function.id == function.id else {
    raise RepresentationSpecializationInvariant(
      detail="planned callable payload does not match its function allocation",
    )
  }
  match self.image.representation_specialization_for_instance(instance) {
    Some(plan) =>
      self.materialize_representation_worker(
        plan,
        self.capture_environment(plan.capture),
      )
    None => {
      guard self.image.lifted_function(instance) is Some(plan) else {
        raise RepresentationSpecializationInvariant(
          detail="planned callable payload has no emitted implementation",
        )
      }
      self.materialize_planned_callable(
        plan.lowered_function,
        plan.type_,
        self.capture_environment(plan.capture),
      )
    }
  }
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
  match environment {
    None => {
      let destination = self.fresh_slot(lowered_type)
      self.emit(ConstFunction(destination, lowered_function))
      Slot(destination, lowered_type)
    }
    Some(environment) => {
      let destination = self.fresh_slot(lowered_type)
      self.emit(MakeClosure(destination, lowered_function, environment))
      Slot(destination, lowered_type)
    }
  }
}

///|
fn FunctionLowerer::lower_recursive_group(
  self : FunctionLowerer,
  bindings : Array[@anf.AnfRecursiveBinding],
  body : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  let functions : Array[@anf.AnfFunction] = []
  let recursive_values : Array[@buslane.ValueId] = []
  let plans : Array[LiftedFunctionPlan] = []
  for binding in bindings {
    let function = match extract_top_atom_function(binding.rhs) {
      Some(function) => function
      None =>
        raise UnsupportedExpression(
          detail="local recursive bindings must contain functions",
        )
    }
    functions.push(function)
    recursive_values.push(binding.id)
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
  let environment = self.capture_environment(first.capture)
  let recursive_functions = first.recursive_functions
  let value_count = self.bindings.length()
  for recursive in recursive_functions {
    self.bindings.push({
      value: recursive.value,
      lowered: RecursiveFunction(
        recursive.function,
        recursive.type_,
        environment,
      ),
    })
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
      self.intern_object_shape(Environment({ stored_witness_count, members })),
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
    Value(id) => self.bindings.push({ value: id, lowered: value })
    Temp(temp) => self.temps.push({ temp, lowered: value })
  }
}
