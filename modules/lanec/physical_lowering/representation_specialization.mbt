///|
fn FunctionLowerer::representation_worker(
  self : FunctionLowerer,
  source : @physical.FunctionId,
  type_ : @anf.RuntimeType,
  arguments : Array[@anf.RuntimeArgument],
) -> (@physical.FunctionId, @anf.RuntimeType)? raise PhysicalLoweringError {
  guard self.image.representation_specialization_enabled else { return None }
  let (parameters, _, _) = function_type_parts(type_)
  guard parameters.length() == arguments.length() else { return None }
  let arguments = arguments.map(argument => {
    self.substitute_generic_argument(argument)
  })
  let substitutions = self.substitutions.overlay(
    RuntimeSubstitution::from_arguments(parameters, arguments),
  )
  let target_type = substitutions.apply_type(
    self.image.runtime_types,
    callable_body_type(type_),
  )
  guard runtime_type_is_closed(target_type, []) else { return None }
  let source_plan = self.image.plans.get(source.value - 1)
  let (body, captured_parameters, captures, capture_abi, recursive_functions) = match
    source_plan.entry {
    Function(_, body) => (body, [], [], ClosureEnvironment(None), [])
    LiftedFunction(plan) =>
      (
        plan.function,
        plan.captured_parameters,
        plan.captures,
        plan.capture_abi,
        plan.recursive_functions,
      )
    _ => return None
  }
  guard self.image.representation_worker_candidates.contains(body.id) else {
    return None
  }
  let callable = self.image.physical_callable_contract(
    target_type,
    RuntimeSubstitution::new(),
    [],
  )
  let key : RepresentationWorkerKey = { source, callable, arguments, }
  for worker in self.image.representation_workers {
    if worker.key == key {
      return Some((worker.function, worker.type_))
    }
  }
  // Encountering the same semantic definition with a new ABI while lowering
  // one of its workers is an expanding recursive specialization. The generic
  // implementation is the canonical finite fallback for that edge.
  guard !self.image.active_specialization_ancestry.contains(source) else {
    return None
  }
  let ancestry = self.image.active_specialization_ancestry.copy()
  ancestry.push(source)
  let specialized_body = specialize_anf_function(
    body,
    substitutions,
    self.image.runtime_types,
  )
  let (_, worker) = self.image.plans.append_with_result(
    RepresentationWorker(
      function=body.id,
      source=body.source,
      origin=body.origin,
    ),
    fn(function) {
      let worker : RepresentationWorkerPlan = {
        function,
        key,
        body: specialized_body,
        type_: target_type,
        substitutions,
        captured_parameters,
        captures,
        capture_abi,
        recursive_functions,
        ancestry,
      }
      self.image.representation_workers.push(worker)
      (RepresentationWorker(worker), worker)
    },
  )
  Some((worker.function, worker.type_))
}

///|
fn ImageLowerer::lower_representation_worker(
  self : ImageLowerer,
  plan : RepresentationWorkerPlan,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let previous = self.active_specialization_ancestry.copy()
  self.active_specialization_ancestry.clear()
  self.active_specialization_ancestry.append(plan.ancestry)
  let (_, parameter_types, result_type) = function_type_parts(plan.type_)
  let body = self.lower_function_body(
    plan.body,
    [],
    parameter_types,
    result_type,
    plan.captured_parameters,
    plan.captures,
    plan.capture_abi,
    plan.recursive_functions,
    plan.substitutions,
  )
  self.active_specialization_ancestry.clear()
  self.active_specialization_ancestry.append(previous)
  body
}

///|
/// Instantiates worker-local use sites and annotations. Nominal constructor
/// payload contracts remain declaration-owned Runtime Metadata and are never
/// rewritten by representation specialization.
fn specialize_anf_function(
  function : @anf.AnfFunction,
  substitutions : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
) -> @anf.AnfFunction raise PhysicalLoweringError {
  {
    id: function.id,
    source: function.source,
    origin: function.origin,
    parameters: function.parameters,
    result_type: substitutions.apply_type(runtime_types, function.result_type),
    body: specialize_anf_expr(function.body, substitutions, runtime_types),
  }
}

///|
fn specialize_anf_expr(
  expression : @anf.AnfExpr,
  substitutions : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
) -> @anf.AnfExpr raise PhysicalLoweringError {
  match expression {
    Atom(atom) => Atom(specialize_anf_atom(atom, substitutions, runtime_types))
    Let(binding, body) =>
      Let(
        specialize_anf_binding(binding, substitutions, runtime_types),
        specialize_anf_expr(body, substitutions, runtime_types),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: specialize_anf_atom(binding.rhs, substitutions, runtime_types),
        }),
        specialize_anf_expr(body, substitutions, runtime_types),
      )
  }
}

///|
fn specialize_anf_binding(
  binding : @anf.AnfBinding,
  substitutions : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
) -> @anf.AnfBinding raise PhysicalLoweringError {
  match binding {
    Value(id~, rhs~) =>
      Value(id~, rhs=specialize_anf_rhs(rhs, substitutions, runtime_types))
    Temp(temp~, type_~, rhs~) =>
      Temp(
        temp~,
        type_=substitutions.apply_type(runtime_types, type_),
        rhs=specialize_anf_rhs(rhs, substitutions, runtime_types),
      )
  }
}

///|
fn specialize_anf_rhs(
  rhs : @anf.AnfRhs,
  substitutions : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
) -> @anf.AnfRhs raise PhysicalLoweringError {
  match rhs {
    Atom(atom) => Atom(specialize_anf_atom(atom, substitutions, runtime_types))
    Call(callee~, arguments~) =>
      Call(
        callee=specialize_anf_atom(callee, substitutions, runtime_types),
        arguments=arguments.map(argument => {
          specialize_anf_atom(argument, substitutions, runtime_types)
        }),
      )
    ApplyEvidence(callee~, arguments~) =>
      ApplyEvidence(
        callee=specialize_anf_atom(callee, substitutions, runtime_types),
        arguments=arguments.map(argument => {
          substitutions.apply_argument(runtime_types, argument)
        }),
      )
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments.map(argument => {
          substitutions.apply_argument(runtime_types, argument)
        }),
        hidden_arguments: construct.hidden_arguments.map(argument => {
          substitutions.apply_argument(runtime_types, argument)
        }),
        payloads: construct.payloads.map(payload => {
          specialize_anf_atom(payload, substitutions, runtime_types)
        }),
      })
    Match(match_) =>
      Match({
        scrutinee: specialize_anf_atom(
          match_.scrutinee,
          substitutions,
          runtime_types,
        ),
        binder: match_.binder,
        result_type: substitutions.apply_type(runtime_types, match_.result_type),
        alternatives: match_.alternatives.map(alternative => {
          let nested = substitutions.without_parameters(
            alternative.evidence_binders,
          )
          {
            alt_constructor: alternative.alt_constructor,
            evidence_binders: alternative.evidence_binders,
            value_binders: alternative.value_binders,
            body: specialize_anf_expr(alternative.body, nested, runtime_types),
          }
        }),
      })
  }
}

///|
fn specialize_anf_atom(
  atom : @anf.AnfAtom,
  substitutions : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
) -> @anf.AnfAtom raise PhysicalLoweringError {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => atom
    Function(function) =>
      Function(specialize_anf_function(function, substitutions, runtime_types))
    DirectFunction(function) =>
      DirectFunction(
        specialize_anf_function(function, substitutions, runtime_types),
      )
    JoinPoint(function) =>
      JoinPoint(specialize_anf_function(function, substitutions, runtime_types))
    EvidenceLambda(parameters~, body~) => {
      let nested = substitutions.without_parameters(parameters)
      EvidenceLambda(
        parameters~,
        body=specialize_anf_expr(body, nested, runtime_types),
      )
    }
  }
}

///|
fn RuntimeSubstitution::without_parameters(
  self : RuntimeSubstitution,
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> RuntimeSubstitution {
  {
    entries: self.entries.filter(entry => {
      !parameters.any(parameter => parameter.id == entry.0)
    }),
  }
}

///|
fn runtime_type_is_closed(
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => true
    Data(_, arguments) =>
      arguments.all(argument => {
        runtime_evidence_is_closed(argument.evidence, bound)
      })
    Callable(parameters, result) =>
      parameters.all(parameter => runtime_type_is_closed(parameter, bound)) &&
      runtime_type_is_closed(result, bound)
    Erased(_, evidence) => runtime_evidence_is_closed(evidence, bound)
    Forall(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      runtime_type_is_closed(body, nested)
    }
  }
}

///|
fn runtime_evidence_is_closed(
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match evidence {
    Static(_) => true
    Parameter(parameter) => bound.contains(parameter)
    Apply(callee, arguments) =>
      runtime_evidence_is_closed(callee, bound) &&
      arguments.all(argument => runtime_evidence_is_closed(argument, bound))
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      runtime_evidence_is_closed(body, nested)
    }
  }
}

///|
priv struct RepresentationCandidateUse {
  value : @buslane.ValueId
  function : @anf.AnfFunctionId
  mut has_closed_application : Bool
  mut open : Bool
}

///|
priv struct RepresentationStableRecursion {
  value : @buslane.ValueId
  parameters : Array[@anf.RuntimeEvidenceParameter]
}

///|
fn representation_specialization_candidates(
  program : @anf.AnfProgram,
) -> Array[@anf.AnfFunctionId] {
  let metadata = program.metadata()
  let uses : Array[RepresentationCandidateUse] = []
  for term in program.terms() {
    match term {
      Let(value, expression) =>
        if extract_top_function(expression) is Some(function) {
          record_representation_candidate(metadata, value, function, uses)
        }
      LetRec(bindings) =>
        for binding in bindings {
          if extract_top_atom_function(binding.rhs) is Some(function) {
            record_representation_candidate(
              metadata,
              binding.id,
              function,
              uses,
            )
          }
        }
      External(_) => ()
    }
  }
  for term in program.terms() {
    match term {
      Let(value, expression) => {
        let stable_recursion = match
          extract_top_evidence_parameters(expression) {
          Some(parameters) => Some({ value, parameters, })
          None => None
        }
        collect_representation_candidate_expr(
          expression, uses, stable_recursion,
        )
      }
      LetRec(bindings) =>
        for binding in bindings {
          collect_representation_candidate_atom(binding.rhs, uses, None)
        }
      External(_) => ()
    }
  }
  uses.filter_map(candidate => {
    if !candidate.open && candidate.has_closed_application {
      Some(candidate.function)
    } else {
      None
    }
  })
}

///|
fn record_representation_candidate(
  metadata : @anf.RuntimeMetadata,
  value : @buslane.ValueId,
  function : @anf.AnfFunction,
  uses : Array[RepresentationCandidateUse],
) -> Unit {
  guard metadata.value_info(value) is Some(info) && info.type_ is Forall(_, _) else {
    return
  }
  uses.push({
    value,
    function: function.id,
    has_closed_application: false,
    open: false,
  })
}

///|
fn collect_representation_candidate_expr(
  expression : @anf.AnfExpr,
  uses : Array[RepresentationCandidateUse],
  stable_recursion : RepresentationStableRecursion?,
) -> Unit {
  match expression {
    Atom(atom) =>
      collect_representation_candidate_atom(atom, uses, stable_recursion)
    Let(binding, body) => {
      collect_representation_candidate_rhs(
        binding.rhs(),
        uses,
        stable_recursion,
      )
      collect_representation_candidate_expr(body, uses, stable_recursion)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_representation_candidate_atom(
          binding.rhs,
          uses,
          stable_recursion,
        )
      }
      collect_representation_candidate_expr(body, uses, stable_recursion)
    }
  }
}

///|
fn collect_representation_candidate_rhs(
  rhs : @anf.AnfRhs,
  uses : Array[RepresentationCandidateUse],
  stable_recursion : RepresentationStableRecursion?,
) -> Unit {
  match rhs {
    ApplyEvidence(callee=Ref(value), arguments~) =>
      record_representation_candidate_application(
        value, arguments, uses, stable_recursion,
      )
    ApplyEvidence(callee~, ..) =>
      collect_representation_candidate_atom(callee, uses, stable_recursion)
    Atom(atom) =>
      collect_representation_candidate_atom(atom, uses, stable_recursion)
    Call(callee~, arguments~) => {
      collect_representation_candidate_atom(callee, uses, stable_recursion)
      for argument in arguments {
        collect_representation_candidate_atom(argument, uses, stable_recursion)
      }
    }
    Construct(construct) =>
      for payload in construct.payloads {
        collect_representation_candidate_atom(payload, uses, stable_recursion)
      }
    Match(match_) => {
      collect_representation_candidate_atom(
        match_.scrutinee,
        uses,
        stable_recursion,
      )
      for alternative in match_.alternatives {
        collect_representation_candidate_expr(
          alternative.body,
          uses,
          stable_recursion,
        )
      }
    }
  }
}

///|
fn collect_representation_candidate_atom(
  atom : @anf.AnfAtom,
  uses : Array[RepresentationCandidateUse],
  stable_recursion : RepresentationStableRecursion?,
) -> Unit {
  match atom {
    Ref(value) => mark_representation_candidate_open(value, uses)
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      collect_representation_candidate_expr(
        function.body,
        uses,
        stable_recursion,
      )
    EvidenceLambda(body~, ..) =>
      collect_representation_candidate_expr(body, uses, stable_recursion)
    Literal(_) | Temp(_) => ()
  }
}

///|
fn record_representation_candidate_application(
  value : @buslane.ValueId,
  arguments : Array[@anf.RuntimeArgument],
  uses : Array[RepresentationCandidateUse],
  stable_recursion : RepresentationStableRecursion?,
) -> Unit {
  for candidate in uses {
    guard candidate.value == value else { continue }
    if stable_recursion is Some(recursion) &&
      recursion.value == value &&
      is_stable_recursive_application(arguments, recursion.parameters) {
      return
    }
    guard arguments.all(argument => {
      runtime_evidence_is_closed(argument.evidence, [])
    }) else {
      candidate.open = true
      return
    }
    candidate.has_closed_application = true
    return
  }
}

///|
fn is_stable_recursive_application(
  arguments : Array[@anf.RuntimeArgument],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Bool {
  guard arguments.length() == parameters.length() else { return false }
  for index, argument in arguments {
    guard argument.evidence is Parameter(id) && id == parameters[index].id else {
      return false
    }
  }
  true
}

///|
fn extract_top_evidence_parameters(
  expression : @anf.AnfExpr,
) -> Array[@anf.RuntimeEvidenceParameter]? {
  guard expression is Atom(atom) else { return None }
  match atom {
    EvidenceLambda(parameters~, ..) => Some(parameters)
    _ => None
  }
}

///|
fn mark_representation_candidate_open(
  value : @buslane.ValueId,
  uses : Array[RepresentationCandidateUse],
) -> Unit {
  for candidate in uses {
    if candidate.value == value {
      candidate.open = true
      return
    }
  }
}
