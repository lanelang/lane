///|
fn FunctionLowerer::planned_representation_worker(
  self : FunctionLowerer,
  source : @physical.FunctionId,
  arguments : Array[@anf.RuntimeArgument],
) -> (@physical.FunctionId, @anf.RuntimeType)? raise PhysicalLoweringError {
  let arguments = arguments.map(argument => {
    self.substitute_generic_argument(argument)
  })
  match
    self.image.representation_specialization.resolve(
      source,
      arguments,
      self.image.runtime_types,
    ) {
    Generic => None
    Specialized(function, type_) => Some((function, type_))
  }
}

///|
fn RepresentationSpecializationPlan::resolve(
  self : RepresentationSpecializationPlan,
  source : @physical.FunctionId,
  arguments : Array[@anf.RuntimeArgument],
  runtime_types : RuntimeTypeArena,
) -> RepresentationSpecializationDisposition {
  for worker in self.workers {
    let contract = self.contracts.entries[worker.contract.value]
    if contract.source == source &&
      @anf.runtime_arguments_alpha_equivalent(contract.arguments, arguments, expression => {
        runtime_types.type_expression(expression)
      }) {
      return Specialized(worker.function, worker.type_)
    }
  }
  Generic
}

///|
fn ImageLowerer::intern_representation_worker_contract(
  self : ImageLowerer,
  catalog : RepresentationWorkerContractCatalog,
  contract : RepresentationWorkerContract,
) -> RepresentationWorkerContractId {
  for index, existing in catalog.entries {
    if existing.source == contract.source &&
      self.physical_callable_contracts_equivalent(
        existing.callable,
        contract.callable,
      ) &&
      @anf.runtime_arguments_alpha_equivalent(
        existing.arguments,
        contract.arguments,
        expression => self.runtime_types.type_expression(expression),
      ) {
      return { value: index, }
    }
  }
  let id : RepresentationWorkerContractId = { value: catalog.entries.length(), }
  catalog.entries.push(contract)
  id
}

///|
fn ImageLowerer::lower_representation_worker(
  self : ImageLowerer,
  plan : RepresentationWorkerPlan,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let (_, parameter_types, result_type) = function_type_parts(plan.type_)
  self.lower_function_body(
    plan.body,
    [],
    parameter_types,
    result_type,
    [],
    [],
    ClosureEnvironment(None),
    [],
    plan.substitutions,
  )
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
    Unit | Scalar(_) | ByteSequence | ByteBuffer => true
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
priv struct RepresentationCandidate {
  value : @buslane.ValueId
  function : @anf.AnfFunction
  parameters : Array[@anf.RuntimeEvidenceParameter]
  closed_applications : Array[Array[@anf.RuntimeArgument]]
  calls : Array[RepresentationCandidateCall]
  mut open : Bool
}

///|
priv struct RepresentationCandidateCall {
  target : @buslane.ValueId
  arguments : Array[@anf.RuntimeArgument]
}

///|
priv struct RepresentationSpecializationDemand {
  candidate : Int
  arguments : Array[@anf.RuntimeArgument]
}

///|
priv struct RepresentationCandidateApplication {
  candidate : Int
  arguments : Array[@anf.RuntimeArgument]
}

///|
priv struct RepresentationApplicationScope {
  mut values : Array[(@buslane.ValueId, RepresentationCandidateApplication)]
  mut temps : Array[(@anf.AnfTempId, RepresentationCandidateApplication)]
}

///|
fn plan_representation_specialization(
  image : ImageLowerer,
  program : @anf.AnfProgram,
) -> RepresentationSpecializationPlan raise PhysicalLoweringError {
  let candidates = collect_representation_candidates(program)
  let demands = solve_representation_specialization_demands(
    candidates,
    image.runtime_types,
  )
  let contracts : RepresentationWorkerContractCatalog = { entries: [], }
  let workers : Array[RepresentationWorkerPlan] = []
  for demand in demands {
    let candidate = candidates[demand.candidate]
    guard !candidate.open &&
      image.find_global(candidate.value) is Some(Function(source, type_)) else {
      continue
    }
    let (parameters, _, _) = function_type_parts(type_)
    guard parameters.length() == demand.arguments.length() else {
      raise RepresentationElaborationInvariant(
        detail="specialization demand does not match its generic definition",
      )
    }
    let substitutions = RuntimeSubstitution::from_arguments(
      parameters,
      demand.arguments,
    )
    let target_type = substitutions.apply_type(
      image.runtime_types,
      callable_body_type(type_),
    )
    guard runtime_type_is_closed(target_type, []) else { continue }
    let callable = image.physical_callable_contract(
      target_type,
      RuntimeSubstitution::new(),
      [],
    )
    let contract = image.intern_representation_worker_contract(contracts, {
      source,
      callable,
      arguments: demand.arguments,
    })
    if workers.any(worker => worker.contract == contract) {
      continue
    }
    let specialized_body = specialize_anf_function(
      candidate.function,
      substitutions,
      image.runtime_types,
    )
    let (_, worker) = image.plans.append_with_result(
      RepresentationWorker(
        function=candidate.function.id,
        source=candidate.function.source,
        origin=candidate.function.origin,
        contract~,
      ),
      fn(function) {
        let worker : RepresentationWorkerPlan = {
          function,
          contract,
          body: specialized_body,
          type_: target_type,
          substitutions,
        }
        (RepresentationWorker(worker), worker)
      },
    )
    workers.push(worker)
  }
  { contracts, workers, }
}

///|
fn collect_representation_candidates(
  program : @anf.AnfProgram,
) -> Array[RepresentationCandidate] raise PhysicalLoweringError {
  let metadata = program.metadata()
  let candidates : Array[RepresentationCandidate] = []
  for term in program.terms() {
    match term {
      Let(value, expression) =>
        if extract_top_function(expression) is Some(function) {
          record_representation_candidate(metadata, value, function, candidates)
        }
      LetRec(bindings) =>
        for binding in bindings {
          if extract_top_atom_function(binding.rhs) is Some(function) {
            record_representation_candidate(
              metadata,
              binding.id,
              function,
              candidates,
            )
          }
        }
      External(_) => ()
    }
  }
  let scope : RepresentationApplicationScope = { values: [], temps: [], }
  for term in program.terms() {
    match term {
      Let(value, expression) => {
        let application = collect_representation_candidate_expr(
          expression,
          candidates,
          representation_candidate_index(candidates, value),
          scope,
        )
        scope.bind_value(value, application)
      }
      LetRec(bindings) =>
        for binding in bindings {
          collect_representation_candidate_atom_use(
            binding.rhs,
            candidates,
            representation_candidate_index(candidates, binding.id),
            scope,
          )
        }
      External(_) => ()
    }
  }
  candidates
}

///|
fn record_representation_candidate(
  metadata : @anf.RuntimeMetadata,
  value : @buslane.ValueId,
  function : @anf.AnfFunction,
  candidates : Array[RepresentationCandidate],
) -> Unit raise PhysicalLoweringError {
  guard metadata.value_info(value) is Some(info) && info.type_ is Forall(_, _) else {
    return
  }
  let (parameters, _, _) = function_type_parts(info.type_)
  candidates.push({
    value,
    function,
    parameters,
    closed_applications: [],
    calls: [],
    open: false,
  })
}

///|
fn collect_representation_candidate_expr(
  expression : @anf.AnfExpr,
  candidates : Array[RepresentationCandidate],
  current : Int?,
  scope : RepresentationApplicationScope,
) -> RepresentationCandidateApplication? {
  match expression {
    Atom(atom) => {
      let application = scope.resolve(atom, candidates)
      if application is None {
        collect_representation_candidate_atom_use(
          atom, candidates, current, scope,
        )
      }
      application
    }
    Let(binding, body) => {
      let application = collect_representation_candidate_rhs(
        binding.rhs(),
        candidates,
        current,
        scope,
      )
      scope.bind(binding, application)
      collect_representation_candidate_expr(body, candidates, current, scope)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_representation_candidate_atom_use(
          binding.rhs,
          candidates,
          current,
          scope,
        )
      }
      collect_representation_candidate_expr(body, candidates, current, scope)
    }
  }
}

///|
fn collect_representation_candidate_rhs(
  rhs : @anf.AnfRhs,
  candidates : Array[RepresentationCandidate],
  current : Int?,
  scope : RepresentationApplicationScope,
) -> RepresentationCandidateApplication? {
  match rhs {
    ApplyEvidence(callee~, arguments~) => {
      guard scope.resolve(callee, candidates) is Some(application) else {
        collect_representation_candidate_atom_use(
          callee, candidates, current, scope,
        )
        return None
      }
      let applied : RepresentationCandidateApplication = {
        candidate: application.candidate,
        arguments: application.arguments + arguments,
      }
      let parameter_count = candidates[applied.candidate].parameters.length()
      if applied.arguments.length() == parameter_count {
        record_representation_candidate_application(
          applied, candidates, current,
        )
      }
      if applied.arguments.length() <= parameter_count {
        Some(applied)
      } else {
        None
      }
    }
    Atom(atom) => {
      let application = scope.resolve(atom, candidates)
      if application is None {
        collect_representation_candidate_atom_use(
          atom, candidates, current, scope,
        )
      }
      application
    }
    Call(callee~, arguments~) => {
      match scope.resolve(callee, candidates) {
        Some(application) =>
          if application.arguments.length() !=
            candidates[application.candidate].parameters.length() {
            candidates[application.candidate].open = true
          }
        None =>
          collect_representation_candidate_atom_use(
            callee, candidates, current, scope,
          )
      }
      for argument in arguments {
        collect_representation_candidate_atom_use(
          argument, candidates, current, scope,
        )
      }
      None
    }
    Construct(construct) => {
      for payload in construct.payloads {
        collect_representation_candidate_atom_use(
          payload, candidates, current, scope,
        )
      }
      None
    }
    Match(match_) => {
      collect_representation_candidate_atom_use(
        match_.scrutinee,
        candidates,
        current,
        scope,
      )
      for alternative in match_.alternatives {
        if collect_representation_candidate_expr(
            alternative.body,
            candidates,
            current,
            { values: scope.values.copy(), temps: scope.temps.copy(), },
          )
          is Some(application) {
          candidates[application.candidate].open = true
        }
      }
      None
    }
  }
}

///|
fn collect_representation_candidate_atom_use(
  atom : @anf.AnfAtom,
  candidates : Array[RepresentationCandidate],
  current : Int?,
  scope : RepresentationApplicationScope,
) -> Unit {
  if scope.resolve(atom, candidates) is Some(application) {
    candidates[application.candidate].open = true
    return
  }
  match atom {
    Ref(_) | Temp(_) => ()
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      if collect_representation_candidate_expr(
          function.body,
          candidates,
          current,
          { values: scope.values.copy(), temps: scope.temps.copy(), },
        )
        is Some(application) {
        candidates[application.candidate].open = true
      }
    EvidenceLambda(body~, ..) =>
      if collect_representation_candidate_expr(body, candidates, current, {
          values: scope.values.copy(),
          temps: scope.temps.copy(),
        })
        is Some(application) {
        candidates[application.candidate].open = true
      }
    Literal(_) => ()
  }
}

///|
fn record_representation_candidate_application(
  application : RepresentationCandidateApplication,
  candidates : Array[RepresentationCandidate],
  current : Int?,
) -> Unit {
  let target = application.candidate
  if current is Some(source) {
    candidates[source].calls.push({
      target: candidates[target].value,
      arguments: application.arguments,
    })
  }
  if application.arguments.all(argument => {
      runtime_evidence_is_closed(argument.evidence, [])
    }) {
    candidates[target].closed_applications.push(application.arguments)
  } else if current is None {
    candidates[target].open = true
  }
}

///|
fn RepresentationApplicationScope::resolve(
  self : RepresentationApplicationScope,
  atom : @anf.AnfAtom,
  candidates : Array[RepresentationCandidate],
) -> RepresentationCandidateApplication? {
  match atom {
    Ref(value) => {
      for entry in self.values {
        if entry.0 == value {
          return Some(entry.1)
        }
      }
      representation_candidate_index(candidates, value).map(candidate => {
        candidate,
        arguments: [],
      })
    }
    Temp(temp) => {
      for entry in self.temps {
        if entry.0 == temp {
          return Some(entry.1)
        }
      }
      None
    }
    Literal(_)
    | Function(_)
    | DirectFunction(_)
    | JoinPoint(_)
    | EvidenceLambda(_) => None
  }
}

///|
fn RepresentationApplicationScope::bind(
  self : RepresentationApplicationScope,
  binding : @anf.AnfBinding,
  application : RepresentationCandidateApplication?,
) -> Unit {
  match binding {
    Value(id~, ..) => self.bind_value(id, application)
    Temp(temp~, ..) => {
      self.temps = self.temps.filter(entry => entry.0 != temp)
      if application is Some(application) {
        self.temps.push((temp, application))
      }
    }
  }
}

///|
fn RepresentationApplicationScope::bind_value(
  self : RepresentationApplicationScope,
  value : @buslane.ValueId,
  application : RepresentationCandidateApplication?,
) -> Unit {
  self.values = self.values.filter(entry => entry.0 != value)
  if application is Some(application) {
    self.values.push((value, application))
  }
}

///|
fn solve_representation_specialization_demands(
  candidates : Array[RepresentationCandidate],
  runtime_types : RuntimeTypeArena,
) -> Array[RepresentationSpecializationDemand] raise PhysicalLoweringError {
  let demands : Array[RepresentationSpecializationDemand] = []
  for index, candidate in candidates {
    guard !candidate.open else { continue }
    for arguments in candidate.closed_applications {
      add_representation_specialization_demand(
        demands, index, arguments, runtime_types,
      )
    }
  }
  let mut next = 0
  while next < demands.length() {
    let demand = demands[next]
    next += 1
    let source = candidates[demand.candidate]
    let substitutions = RuntimeSubstitution::from_arguments(
      source.parameters,
      demand.arguments,
    )
    for call in source.calls {
      guard representation_candidate_index(candidates, call.target)
        is Some(target_index) &&
        !candidates[target_index].open else {
        continue
      }
      let arguments = call.arguments.map(argument => {
        substitutions.apply_argument(runtime_types, argument)
      })
      guard arguments.all(argument => {
        runtime_evidence_is_closed(argument.evidence, [])
      }) else {
        continue
      }
      if representation_candidates_share_recursive_component(
          candidates,
          demand.candidate,
          target_index,
        ) &&
        !@anf.runtime_arguments_alpha_equivalent(demand.arguments, arguments, expression => {
          runtime_types.type_expression(expression)
        }) {
        continue
      }
      add_representation_specialization_demand(
        demands, target_index, arguments, runtime_types,
      )
    }
  }
  demands
}

///|
fn representation_candidate_index(
  candidates : Array[RepresentationCandidate],
  value : @buslane.ValueId,
) -> Int? {
  for index, candidate in candidates {
    if candidate.value == value {
      return Some(index)
    }
  }
  None
}

///|
fn add_representation_specialization_demand(
  demands : Array[RepresentationSpecializationDemand],
  candidate : Int,
  arguments : Array[@anf.RuntimeArgument],
  runtime_types : RuntimeTypeArena,
) -> Unit {
  if demands.any(demand => {
      demand.candidate == candidate &&
      @anf.runtime_arguments_alpha_equivalent(demand.arguments, arguments, expression => {
        runtime_types.type_expression(expression)
      })
    }) {
    return
  }
  demands.push({ candidate, arguments, })
}

///|
fn representation_candidates_share_recursive_component(
  candidates : Array[RepresentationCandidate],
  left : Int,
  right : Int,
) -> Bool {
  if left == right {
    return true
  }
  representation_candidate_reaches(candidates, left, right) &&
  representation_candidate_reaches(candidates, right, left)
}

///|
fn representation_candidate_reaches(
  candidates : Array[RepresentationCandidate],
  source : Int,
  target : Int,
) -> Bool {
  let pending = [source]
  let visited : Array[Int] = []
  while !pending.is_empty() {
    let current = pending.pop().unwrap()
    if visited.contains(current) {
      continue
    }
    visited.push(current)
    for call in candidates[current].calls {
      guard representation_candidate_index(candidates, call.target)
        is Some(next) else {
        continue
      }
      if next == target {
        return true
      }
      if !visited.contains(next) {
        pending.push(next)
      }
    }
  }
  false
}
