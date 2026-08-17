///|
priv struct GenericFunctionDefinition {
  value : @buslane.ValueId
  source_function : @bytecode.FunctionId
  function : @anf.AnfFunction
  type_parameters : Array[@buslane.TypeParameterId]
  parameter_types : Array[@buslane.Type]
  result_type : @buslane.Type
}

///|
priv struct RepresentationDemand {
  definition : Int
  key : RepresentationSpecializationKey
  substitutions : @buslane.TypeSubstitution
  parameter_types : Array[@buslane.Type]
  result_type : @buslane.Type
}

///|
priv struct DirectGenericCall {
  target : @buslane.ValueId
  arguments : Array[@buslane.GenericArgument]
}

///|
priv struct DirectCalleeFact {
  target : @buslane.ValueId
  arguments : Array[@buslane.GenericArgument]
}

///|
priv struct CalleeBindingFacts {
  values : Array[(@buslane.ValueId, DirectCalleeFact)]
  temps : Array[(@anf.AnfTempId, DirectCalleeFact)]
}

///|
fn ImageLowerer::plan_representation_specializations(
  self : ImageLowerer,
  program : @anf.AnfProgram,
) -> Unit raise LoisvmLoweringError {
  let definitions = self.generic_function_definitions(program)
  guard !definitions.is_empty() else { return }
  let adjacency = generic_call_adjacency(definitions)
  let sccs = generic_call_sccs(adjacency)
  let seeds : Array[Array[RepresentationDemand]] = Array::makei(
    definitions.length(),
    _ => [],
  )
  for term in program.terms() {
    match term {
      Let(value, expression) if self.find_global(value) is Some(_) =>
        self.collect_representation_seeds(definitions, seeds, expression)
      LetRec(bindings) =>
        for binding in bindings {
          if self.find_global(binding.id) is Some(_) {
            self.collect_representation_seeds(
              definitions,
              seeds,
              Atom(binding.rhs),
            )
          }
        }
      Let(_, _) | External(_) => ()
    }
  }
  let accepted = self.close_representation_demands(
    definitions, adjacency, sccs, seeds,
  )
  for demand in accepted {
    let definition = definitions[demand.definition]
    let (_, plan) = self.plans.append_with_result(
      RepresentationSpecialization(
        function=definition.function.id,
        source=definition.function.source,
      ),
      fn(worker) {
        let plan : RepresentationSpecializationPlan = {
          worker,
          key: demand.key,
          function: definition.function,
          substitutions: demand.substitutions,
          type_parameters: definition.type_parameters,
          parameter_types: demand.parameter_types,
          result_type: demand.result_type,
        }
        (RepresentationWorker(plan), plan)
      },
    )
    self.representation_specializations.push(plan)
  }
}

///|
fn ImageLowerer::generic_function_definitions(
  self : ImageLowerer,
  program : @anf.AnfProgram,
) -> Array[GenericFunctionDefinition] raise LoisvmLoweringError {
  let definitions = []
  for term in program.terms() {
    match term {
      Let(value, expression) =>
        if extract_top_function(expression) is Some(function) {
          self.push_generic_function_definition(definitions, value, function)
        }
      LetRec(bindings) =>
        for binding in bindings {
          if extract_top_atom_function(binding.rhs) is Some(function) {
            self.push_generic_function_definition(
              definitions,
              binding.id,
              function,
            )
          }
        }
      External(_) => ()
    }
  }
  definitions
}

///|
fn ImageLowerer::push_generic_function_definition(
  self : ImageLowerer,
  definitions : Array[GenericFunctionDefinition],
  value : @buslane.ValueId,
  function : @anf.AnfFunction,
) -> Unit raise LoisvmLoweringError {
  guard self.find_global(value) is Some(Function(source_function, type_)) else {
    return
  }
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    type_,
  )
  if type_parameters.any(fn(parameter) {
      self.requires_runtime_evidence(parameter)
    }) {
    definitions.push({
      value,
      source_function,
      function,
      type_parameters,
      parameter_types,
      result_type,
    })
  }
}

///|
fn ImageLowerer::collect_representation_seeds(
  self : ImageLowerer,
  definitions : Array[GenericFunctionDefinition],
  seeds : Array[Array[RepresentationDemand]],
  expression : @anf.AnfExpr,
) -> Unit raise LoisvmLoweringError {
  for call in collect_direct_generic_calls(expression, TypeSubstitution()) {
    if self.representation_demand(definitions, call) is Some(demand) {
      push_representation_demand(seeds[demand.definition], demand)
    }
  }
}

///|
fn collect_direct_generic_calls(
  expression : @anf.AnfExpr,
  substitutions : @buslane.TypeSubstitution,
) -> Array[DirectGenericCall] raise LoisvmLoweringError {
  let calls = []
  collect_calls_in_expression(
    expression,
    substitutions,
    { values: [], temps: [] },
    calls,
  )
  calls
}

///|
fn collect_calls_in_expression(
  expression : @anf.AnfExpr,
  substitutions : @buslane.TypeSubstitution,
  bindings : CalleeBindingFacts,
  calls : Array[DirectGenericCall],
) -> Unit raise LoisvmLoweringError {
  match expression {
    Atom(atom) => collect_calls_in_atom(atom, substitutions, bindings, calls)
    Let(binding, body) => {
      collect_calls_in_rhs(binding.rhs(), substitutions, bindings, calls)
      let nested = {
        values: bindings.values.copy(),
        temps: bindings.temps.copy(),
      }
      if direct_callee_from_rhs(binding.rhs(), substitutions, bindings)
        is Some(fact) {
        match binding {
          Value(id~, ..) => nested.values.push((id, fact))
          Temp(temp~, ..) => nested.temps.push((temp, fact))
        }
      }
      collect_calls_in_expression(body, substitutions, nested, calls)
    }
    LetRec(recursive, body) => {
      for binding in recursive {
        collect_calls_in_atom(binding.rhs, substitutions, bindings, calls)
      }
      collect_calls_in_expression(body, substitutions, bindings, calls)
    }
  }
}

///|
fn collect_calls_in_rhs(
  rhs : @anf.AnfRhs,
  substitutions : @buslane.TypeSubstitution,
  bindings : CalleeBindingFacts,
  calls : Array[DirectGenericCall],
) -> Unit raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => collect_calls_in_atom(atom, substitutions, bindings, calls)
    TypeApply(callee~, ..) =>
      collect_calls_in_atom(callee, substitutions, bindings, calls)
    Call(callee~, arguments~) => {
      collect_calls_in_atom(callee, substitutions, bindings, calls)
      for argument in arguments {
        collect_calls_in_atom(argument, substitutions, bindings, calls)
      }
      if direct_callee_from_atom(callee, bindings) is Some(fact) &&
        !fact.arguments.is_empty() {
        calls.push({ target: fact.target, arguments: fact.arguments })
      }
    }
    Construct(construct) =>
      for payload in construct.payloads {
        collect_calls_in_atom(payload, substitutions, bindings, calls)
      }
    Match(match_) => {
      collect_calls_in_atom(match_.scrutinee, substitutions, bindings, calls)
      for alternative in match_.alternatives {
        collect_calls_in_expression(
          alternative.body,
          substitutions,
          bindings,
          calls,
        )
      }
    }
  }
}

///|
fn collect_calls_in_atom(
  atom : @anf.AnfAtom,
  substitutions : @buslane.TypeSubstitution,
  bindings : CalleeBindingFacts,
  calls : Array[DirectGenericCall],
) -> Unit raise LoisvmLoweringError {
  match atom {
    Function(function) =>
      collect_calls_in_expression(function.body, substitutions, bindings, calls)
    TypeLambda(body~, ..) =>
      collect_calls_in_expression(body, substitutions, bindings, calls)
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn direct_callee_from_rhs(
  rhs : @anf.AnfRhs,
  substitutions : @buslane.TypeSubstitution,
  bindings : CalleeBindingFacts,
) -> DirectCalleeFact? raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => direct_callee_from_atom(atom, bindings)
    TypeApply(callee~, arguments~) =>
      match direct_callee_from_atom(callee, bindings) {
        Some(fact) =>
          Some({
            ..fact,
            arguments: fact.arguments +
            arguments.map(argument => {
              apply_generic_argument_substitution(argument, substitutions)
            }),
          })
        None => None
      }
    Call(..) | Construct(_) | Match(_) => None
  }
}

///|
fn direct_callee_from_atom(
  atom : @anf.AnfAtom,
  bindings : CalleeBindingFacts,
) -> DirectCalleeFact? {
  match atom {
    Ref(value) =>
      match find_value_callee(bindings.values, value) {
        Some(fact) => Some(fact)
        None => Some({ target: value, arguments: [] })
      }
    Temp(temp) => find_temp_callee(bindings.temps, temp)
    Literal(_) | Function(_) | TypeLambda(_) => None
  }
}

///|
fn find_value_callee(
  bindings : Array[(@buslane.ValueId, DirectCalleeFact)],
  value : @buslane.ValueId,
) -> DirectCalleeFact? {
  for index = bindings.length() - 1; index >= 0; index = index - 1 {
    if bindings[index].0 == value {
      return Some(bindings[index].1)
    }
  }
  None
}

///|
fn find_temp_callee(
  bindings : Array[(@anf.AnfTempId, DirectCalleeFact)],
  temp : @anf.AnfTempId,
) -> DirectCalleeFact? {
  for index = bindings.length() - 1; index >= 0; index = index - 1 {
    if bindings[index].0 == temp {
      return Some(bindings[index].1)
    }
  }
  None
}

///|
fn find_generic_definition(
  definitions : Array[GenericFunctionDefinition],
  value : @buslane.ValueId,
) -> Int? {
  for index, definition in definitions {
    if definition.value == value {
      return Some(index)
    }
  }
  None
}

///|
fn generic_call_adjacency(
  definitions : Array[GenericFunctionDefinition],
) -> Array[Array[Int]] raise LoisvmLoweringError {
  Array::makei(definitions.length(), index => {
    let adjacent = []
    for
      call in collect_direct_generic_calls(
        definitions[index].function.body,
        TypeSubstitution(),
      ) {
      if find_generic_definition(definitions, call.target) is Some(target) &&
        !adjacent.contains(target) {
        adjacent.push(target)
      }
    }
    adjacent
  })
}

///|
fn generic_call_sccs(adjacency : Array[Array[Int]]) -> Array[Int] {
  let count = adjacency.length()
  let reachable = Array::makei(count, from => {
    Array::makei(count, to => from == to || adjacency[from].contains(to))
  })
  for via = 0; via < count; via = via + 1 {
    for from = 0; from < count; from = from + 1 {
      guard reachable[from][via] else { continue }
      for to = 0; to < count; to = to + 1 {
        if reachable[via][to] {
          reachable[from][to] = true
        }
      }
    }
  }
  Array::makei(count, index => {
    let mut representative = index
    for candidate = 0; candidate < index; candidate = candidate + 1 {
      if reachable[index][candidate] && reachable[candidate][index] {
        representative = candidate
        break
      }
    }
    representative
  })
}

///|
fn ImageLowerer::representation_demand(
  self : ImageLowerer,
  definitions : Array[GenericFunctionDefinition],
  call : DirectGenericCall,
) -> RepresentationDemand? raise LoisvmLoweringError {
  guard find_generic_definition(definitions, call.target) is Some(definition) else {
    return None
  }
  let generic = definitions[definition]
  guard self.representation_specialization_key(
      generic.source_function,
      generic.type_parameters,
      generic.parameter_types,
      generic.result_type,
      call.arguments,
    )
    is Some((key, substitutions, parameter_types, result_type)) else {
    return None
  }
  Some({ definition, key, substitutions, parameter_types, result_type })
}

///|
fn ImageLowerer::representation_specialization_key(
  self : ImageLowerer,
  source_function : @bytecode.FunctionId,
  type_parameters : Array[@buslane.TypeParameterId],
  formal_parameters : Array[@buslane.Type],
  formal_result : @buslane.Type,
  arguments : Array[@buslane.GenericArgument],
) -> (
  RepresentationSpecializationKey,
  @buslane.TypeSubstitution,
  Array[@buslane.Type],
  @buslane.Type,
)? raise LoisvmLoweringError {
  guard arguments.length() == type_parameters.length() &&
    type_parameters.all(parameter => {
      self.metadata.type_parameter_info(parameter) is Some(_)
    }) &&
    arguments.all(is_closed_generic_argument) else {
    return None
  }
  guard formal_parameters.any(type_ => self.runtime_type(type_) is Erased(_)) ||
    self.runtime_type(formal_result) is Erased(_) else {
    return None
  }
  let substitutions = self.call_type_substitution(type_parameters, arguments)
  let parameter_types = formal_parameters.map(type_ => {
    apply_type_substitution(type_, substitutions)
  })
  let result_type = apply_type_substitution(formal_result, substitutions)
  guard parameter_types.all(is_closed_type) && is_closed_type(result_type) else {
    return None
  }
  let evidence = []
  for index, parameter in type_parameters {
    guard self.requires_runtime_evidence(parameter) else { continue }
    guard arguments[index] is TypeArgument(argument) else { return None }
    let kind = match self.metadata.type_parameter_info(parameter) {
      Some(info) => info.kind
      None if parameter.index < 0 => Type
      None => return None
    }
    match kind {
      Type => evidence.push(self.canonical_runtime_type_key(argument))
      Function(_, Type) => return None
      _ => return None
    }
  }
  let parameters = []
  for type_ in parameter_types {
    let key = self.canonical_runtime_type_key(type_)
    if !(key is Unit) {
      parameters.push(key)
    }
  }
  let result = self.canonical_runtime_type_key(result_type)
  Some(
    (
      { source_function, evidence, parameters, result },
      substitutions,
      parameter_types,
      result_type,
    ),
  )
}

///|
fn ImageLowerer::representation_specialization(
  self : ImageLowerer,
  source_function : @bytecode.FunctionId,
  type_parameters : Array[@buslane.TypeParameterId],
  formal_parameters : Array[@buslane.Type],
  formal_result : @buslane.Type,
  arguments : Array[@buslane.GenericArgument],
) -> (RepresentationSpecializationPlan, @buslane.Type)? raise LoisvmLoweringError {
  guard self.representation_specialization_key(
      source_function, type_parameters, formal_parameters, formal_result, arguments,
    )
    is Some((key, _, _, result_type)) else {
    return None
  }
  for plan in self.representation_specializations {
    if plan.key == key {
      return Some((plan, result_type))
    }
  }
  None
}

///|
fn ImageLowerer::canonical_runtime_type_key(
  self : ImageLowerer,
  type_ : @buslane.Type,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  self.canonical_runtime_type_key_under(type_, TypeSubstitution())
}

///|
fn ImageLowerer::canonical_runtime_type_key_under(
  self : ImageLowerer,
  type_ : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match self.elaborate_runtime_representation(type_) {
    Unit => Unit
    Erased(_) =>
      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue })
    Concrete(Function(_, _, _) | Forall(_, _) as type_, _) =>
      Callable(self.canonical_callable_abi_under(type_, substitutions))
    Concrete(type_, _) => {
      let type_ = apply_type_substitution(type_, substitutions)
      match self.elaborate_runtime_representation(type_) {
        Unit => Unit
        Erased(_) =>
          Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue })
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
  type_ : @buslane.Type,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  self.canonical_callable_abi_under(type_, TypeSubstitution())
}

///|
fn ImageLowerer::canonical_callable_abi_under(
  self : ImageLowerer,
  type_ : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  let (type_parameters, parameters, result) = function_type_parts(type_)
  let witnesses : Array[@bytecode.ValueAbi] = []
  for parameter in type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = self.runtime_evidence_metadata(parameter)
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

///|
fn is_closed_generic_argument(argument : @buslane.GenericArgument) -> Bool {
  match argument {
    TypeArgument(type_) => is_closed_type(type_)
    EffectArgument(effect) => is_closed_effect(effect, [])
  }
}

///|
fn is_closed_type(type_ : @buslane.Type) -> Bool {
  is_closed_type_with_bound(type_, [])
}

///|
fn is_closed_type_with_bound(
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
) -> Bool {
  match type_ {
    Primitive(_) | Constructor(_) => true
    Parameter(parameter) => bound.contains(parameter)
    Apply(callee, arguments) =>
      is_closed_type_with_bound(callee, bound) &&
      arguments.all(argument => {
        match argument {
          TypeArgument(type_) => is_closed_type_with_bound(type_, bound)
          EffectArgument(effect) => is_closed_effect(effect, bound)
        }
      })
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters)
      is_closed_type_with_bound(body, nested)
    }
    Function(parameters, result, effect) =>
      parameters.all(type_ => is_closed_type_with_bound(type_, bound)) &&
      is_closed_type_with_bound(result, bound) &&
      is_closed_effect(effect, bound)
  }
}

///|
fn is_closed_effect(
  effect : @buslane.Effect,
  bound : Array[@buslane.TypeParameterId],
) -> Bool {
  match effect {
    Empty | Builtin(_) => true
    Parameter(parameter) => bound.contains(parameter)
    Singleton(_, arguments) =>
      arguments.all(argument => {
        match argument {
          TypeArgument(type_) => is_closed_type_with_bound(type_, bound)
          EffectArgument(effect) => is_closed_effect(effect, bound)
        }
      })
    Union(effects) => effects.all(effect => is_closed_effect(effect, bound))
  }
}

///|
fn push_representation_demand(
  demands : Array[RepresentationDemand],
  demand : RepresentationDemand,
) -> Unit {
  if !demands.any(existing => existing.key == demand.key) {
    demands.push(demand)
  }
}

///|
fn ImageLowerer::close_representation_demands(
  self : ImageLowerer,
  definitions : Array[GenericFunctionDefinition],
  adjacency : Array[Array[Int]],
  sccs : Array[Int],
  seeds : Array[Array[RepresentationDemand]],
) -> Array[RepresentationDemand] raise LoisvmLoweringError {
  let accepted = []
  let processed = Array::make(definitions.length(), false)
  let mut remaining = 0
  for index, representative in sccs {
    if index == representative {
      remaining = remaining + 1
    }
  }
  let mut completed = 0
  while completed < remaining {
    let mut next : Int? = None
    for representative, owner in sccs {
      guard representative == owner && !processed[representative] else {
        continue
      }
      let mut has_unprocessed_predecessor = false
      for from, targets in adjacency {
        if !processed[sccs[from]] &&
          sccs[from] != representative &&
          targets.any(to => sccs[to] == representative) {
          has_unprocessed_predecessor = true
          break
        }
      }
      if !has_unprocessed_predecessor {
        next = Some(representative)
        break
      }
    }
    guard next is Some(representative) else {
      raise RepresentationSpecializationInvariant(
        detail="generic call SCC condensation is cyclic",
      )
    }
    let mut recursive = false
    for from, targets in adjacency {
      if sccs[from] == representative &&
        targets.any(to => sccs[to] == representative) {
        recursive = true
        break
      }
    }
    let finite = !recursive ||
      self.recursive_scc_demands_are_finite(
        definitions, sccs, representative, seeds,
      )
    if finite {
      for definition, owner in sccs {
        guard owner == representative else { continue }
        for demand in seeds[definition] {
          push_representation_demand(accepted, demand)
          self.propagate_representation_demands(
            definitions, sccs, representative, seeds, demand,
          )
        }
      }
    }
    processed[representative] = true
    completed = completed + 1
  }
  accepted
}

///|
fn ImageLowerer::recursive_scc_demands_are_finite(
  self : ImageLowerer,
  definitions : Array[GenericFunctionDefinition],
  sccs : Array[Int],
  representative : Int,
  seeds : Array[Array[RepresentationDemand]],
) -> Bool raise LoisvmLoweringError {
  for definition, owner in sccs {
    guard owner == representative else { continue }
    for demand in seeds[definition] {
      for
        call in collect_direct_generic_calls(
          definitions[definition].function.body,
          demand.substitutions,
        ) {
        guard find_generic_definition(definitions, call.target) is Some(target) &&
          sccs[target] == representative else {
          continue
        }
        guard self.representation_demand(definitions, call) is Some(required) &&
          seeds[target].any(existing => existing.key == required.key) else {
          return false
        }
      }
    }
  }
  true
}

///|
fn ImageLowerer::propagate_representation_demands(
  self : ImageLowerer,
  definitions : Array[GenericFunctionDefinition],
  sccs : Array[Int],
  source_scc : Int,
  seeds : Array[Array[RepresentationDemand]],
  demand : RepresentationDemand,
) -> Unit raise LoisvmLoweringError {
  for
    call in collect_direct_generic_calls(
      definitions[demand.definition].function.body,
      demand.substitutions,
    ) {
    guard self.representation_demand(definitions, call) is Some(required) &&
      sccs[required.definition] != source_scc else {
      continue
    }
    push_representation_demand(seeds[required.definition], required)
  }
}

///|
fn ImageLowerer::lower_representation_worker(
  self : ImageLowerer,
  plan : RepresentationSpecializationPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  self.lower_function_body(
    plan.function,
    [],
    plan.parameter_types,
    plan.result_type,
    [],
    [],
    None,
    [],
    plan.substitutions,
    plan.type_parameters,
  )
}
