///|
fn FunctionLowerer::lower_callable_allocation(
  self : FunctionLowerer,
  allocation : PhysicalCallableAllocationPlan,
) -> LocalValue raise LoisvmLoweringError {
  let implementation = allocation.lowered_implementation
  NestedCallable({
    source: allocation.function,
    lowered_function: implementation.function,
    environment: self.capture_environment(allocation),
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
    callable.environment,
    callable.invocation,
  )
}

///|
fn FunctionLowerer::materialize_callable_value(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable(lowered_function, environment)
}

///|
fn FunctionLowerer::materialize_callable_value_with_abi(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  environment : @vmcfg.ValueId?,
  invocation : CanonicalCallableAbi,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable_with_abi(
    lowered_function, environment, invocation,
  )
}

///|
fn FunctionLowerer::materialize_representation_worker(
  self : FunctionLowerer,
  plan : PhysicalRepresentationWorkerCall,
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable(plan.worker, environment)
}

///|
fn FunctionLowerer::materialize_planned_callable(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_callable_with_abi(
    lowered_function,
    environment,
    self.physical_program.required_invocation(lowered_function),
  )
}

///|
fn FunctionLowerer::materialize_planned_callable_with_abi(
  self : FunctionLowerer,
  lowered_function : @bytecode.FunctionId,
  environment : @vmcfg.ValueId?,
  invocation : CanonicalCallableAbi,
) -> LocalValue raise LoisvmLoweringError {
  let shape = CanonicalRuntimeTypeKey::Callable(invocation)
  let destination = self.fresh_metadata(shape.value_metadata(None))
  match environment {
    None => {
      self.emit(ConstFunction(destination, lowered_function))
      LocalValue::Slot(destination, shape)
    }
    Some(environment) => {
      self.emit(MakeClosure(destination, lowered_function, environment))
      LocalValue::Slot(destination, shape)
    }
  }
}

///|
fn FunctionLowerer::lower_recursive_group(
  self : FunctionLowerer,
  bindings : Array[PhysicalAnfRecursiveBinding],
  body : PhysicalAnfExpr,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  guard bindings.get(0) is Some(first_binding) &&
    first_binding.rhs.producer is Callable(first_allocation) else {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF recursive group lacks its complete allocation contract",
    )
  }
  let environment = self.capture_environment(first_allocation)
  let value_count = self.bindings.length()
  for binding in bindings {
    guard binding.rhs.producer is Callable(allocation) else {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF recursive member has no selected implementation",
      )
    }
    let implementation = allocation.lowered_implementation
    let deferred = RecursiveFunction(implementation.function, environment)
    let lowered = self.materialize_local(deferred)
    let lowered = self.apply_physical_binding_flow(binding.flow, {
      value: lowered,
      contract: binding.rhs.contract,
    })
    self.bindings.push({ value: binding.id, lowered: lowered.value, })
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
fn ImageLowerer::environment_contract(
  self : ImageLowerer,
  stored_witness_count : Int,
  members : Array[@bytecode.MemberSchema],
) -> PhysicalEnvironmentContract? raise LoisvmLoweringError {
  if stored_witness_count == 0 && members.is_empty() {
    None
  } else {
    let shape = self.intern_object_shape(
      Environment({ stored_witness_count, members, }),
    )
    Some({ shape, layout: self.required_layout(Environment(shape)), })
  }
}

///|
fn FunctionLowerer::make_capture_environment(
  self : FunctionLowerer,
  environment : PhysicalEnvironmentContract?,
  witnesses : Array[@vmcfg.ValueId],
  capture_slots : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId? {
  match environment {
    None => None
    Some(contract) => {
      let environment = self.fresh_metadata(
        environment_metadata(contract.shape),
      )
      self.emit(
        MakeEnv(
          environment,
          contract.shape,
          Immediate(contract.layout),
          witnesses,
          capture_slots,
        ),
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
