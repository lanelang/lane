///|
priv enum RuntimeArgumentTransform {
  Projection(@anf.RuntimeEvidenceId)
  Closed
  Expanding
} derive(Eq)

///|
priv struct PlannedRuntimeArgument {
  argument : @anf.RuntimeArgument
  transform : RuntimeArgumentTransform
} derive(Eq)

///|
priv struct CallableClosureFact {
  function : @anf.AnfFunctionId
  lexical_arguments : Array[@anf.RuntimeArgument]
  applied_arguments : Array[PlannedRuntimeArgument]
} derive(Eq)

///|
priv struct CallableFlowFact {
  callables : Array[CallableClosureFact]
  allocations : Array[CallableAllocationKey]
  open : Bool
} derive(Eq)

///|
priv struct CallableAllocationKey {
  caller : Int
  site : @anf.AnfBindingId
} derive(Eq)

///|
priv struct CallableAllocationFact {
  key : CallableAllocationKey
  data_constructor : @buslane.DataConId
  payloads : Array[CallableFlowFact]
}

///|
priv struct CallableBindingFact {
  caller : Int
  binding : @anf.AnfBindingId
  mut fact : CallableFlowFact
}

///|
priv struct CallableInstanceKey {
  function : @anf.AnfFunctionId
  arguments : Array[@anf.RuntimeArgument]
} derive(Eq)

///|
priv struct CallableInstance {
  id : Int
  key : CallableInstanceKey
  definition : @anf.AnfCallableDefinition
  substitution : RuntimeSubstitution
  own_arguments : Array[PlannedRuntimeArgument]
  generic_fallback : Bool
}

///|
priv struct CallableCallSite {
  caller : Int
  site : @anf.AnfBindingId
  targets : Array[Int]
  mut open : Bool
}

///|
priv struct CallableInstancePlan {
  instances : Array[CallableInstance]
  calls : Array[CallableCallSite]
  rejected_recursive_groups : Array[@anf.AnfRecursiveGroupId]
}

///|
fn CallableInstancePlan::empty() -> CallableInstancePlan {
  { instances: [], calls: [], rejected_recursive_groups: [] }
}

///|
fn CallableInstancePlan::generic_instance(
  self : CallableInstancePlan,
  function : @anf.AnfFunctionId,
) -> Int? {
  for instance in self.instances {
    if instance.key.function == function && instance.generic_fallback {
      return Some(instance.id)
    }
  }
  None
}

///|
fn CallableInstancePlan::exact_call_target(
  self : CallableInstancePlan,
  caller : Int,
  site : @anf.AnfBindingId,
) -> CallableInstance? {
  for call in self.calls {
    if call.caller == caller && call.site == site {
      guard !call.open && call.targets is [target] else { return None }
      return Some(self.instances[target])
    }
  }
  None
}

///|
fn ImageLowerer::callable_instance(
  self : ImageLowerer,
  function : @anf.AnfFunctionId,
  substitutions : RuntimeSubstitution,
) -> Int raise LoisvmLoweringError {
  guard self.callable_catalog.find(function) is Some(definition) else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF callable catalog is incomplete",
    )
  }
  let arguments = []
  for parameter in definition.lexical_parameters {
    guard self.metadata.parameter_type_expression(parameter.id)
      is Some(type_expression) else {
      raise RepresentationSpecializationInvariant(
        detail="Runtime ANF evidence parameter lacks a type expression",
      )
    }
    arguments.push(
      substitutions.apply_argument(self.runtime_types, {
        type_expression,
        evidence: Parameter(parameter.id),
      }),
    )
  }
  for parameter in definition.parameters {
    guard self.metadata.parameter_type_expression(parameter.id)
      is Some(type_expression) else {
      raise RepresentationSpecializationInvariant(
        detail="Runtime ANF evidence parameter lacks a type expression",
      )
    }
    arguments.push({ type_expression, evidence: Parameter(parameter.id) })
  }
  for instance in self.callable_instances.instances {
    if instance.key.function == function && instance.key.arguments == arguments {
      return instance.id
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="callable lowering requested an instance absent from the immutable plan",
  )
}

///|
priv struct CallableInstancePlanner {
  image : ImageLowerer
  program : @anf.AnfProgram
  catalog : @anf.AnfCallableCatalog
  instances : Array[CallableInstance]
  bindings : Array[CallableBindingFact]
  results : Array[CallableFlowFact]
  allocations : Array[CallableAllocationFact]
  calls : Array[CallableCallSite]
  open_functions : Array[@anf.AnfFunctionId]
  rejected_recursive_groups : Array[@anf.AnfRecursiveGroupId]
  mut changed : Bool
}

///|
fn ImageLowerer::plan_callable_instances(
  self : ImageLowerer,
  program : @anf.AnfProgram,
) -> CallableInstancePlan raise LoisvmLoweringError {
  let planner : CallableInstancePlanner = {
    image: self,
    program,
    catalog: self.callable_catalog,
    instances: [],
    bindings: [],
    results: [],
    allocations: [],
    calls: [],
    open_functions: [],
    rejected_recursive_groups: [],
    changed: false,
  }
  planner.seed_top_level_callables()
  while true {
    planner.changed = false
    planner.analyze_top_terms()
    let count = planner.instances.length()
    for index in 0..<count {
      planner.analyze_instance(index)
    }
    if !planner.changed && planner.instances.length() == count {
      break
    }
  }
  {
    instances: planner.instances,
    calls: planner.calls,
    rejected_recursive_groups: planner.rejected_recursive_groups,
  }
}

///|
fn ImageLowerer::plan_lifted_callable_instances(
  self : ImageLowerer,
) -> Unit raise LoisvmLoweringError {
  for instance in self.callable_instances.instances {
    let definition = instance.definition
    guard instance.generic_fallback &&
      !self.plans.contains_top_level_function(definition.function.id) else {
      continue
    }
    // Recursive groups are planned atomically by their allocation site.
    guard definition.recursive_group is None else { continue }
    let function_type = instance.substitution.apply_type(
      self.runtime_types,
      definition.type_,
    )
    let capture = self.plan_callable_capture(
      definition,
      function_type,
      instance.substitution,
      [],
    )
    let (_, plan) = self.plans.append_with_result(
      LiftedFunction(
        function=definition.function.id,
        source=definition.function.source,
      ),
      fn(lowered_function) {
        let plan : LiftedFunctionPlan = {
          lowered_function,
          function: definition.function,
          instance: instance.id,
          type_: function_type,
          substitutions: instance.substitution,
          specialized_parameters: [],
          capture,
          recursive_functions: [],
        }
        (LiftedFunction(plan), plan)
      },
    )
    self.lifted_functions.push(plan)
  }
  let planned_groups : Array[
    (@anf.AnfRecursiveGroupId, Array[@anf.RuntimeArgument]),
  ] = []
  for seed in self.callable_instances.instances {
    guard seed.generic_fallback &&
      !self.plans.contains_top_level_function(seed.definition.function.id) &&
      seed.definition.recursive_group is Some(group) else {
      continue
    }
    let lexical_arguments = seed.key.arguments[:seed.definition.lexical_parameters.length()].to_owned()
    guard !planned_groups.any(entry => {
      entry.0 == group && entry.1 == lexical_arguments
    }) else {
      continue
    }
    let group_instances = self.callable_instances.instances.filter(instance => {
      instance.generic_fallback &&
      instance.definition.recursive_group == Some(group) &&
      instance.key.arguments[:instance.definition.lexical_parameters.length()].to_owned() ==
      lexical_arguments
    })
    let inputs = group_instances.map(instance => {
      let function_type = instance.substitution.apply_type(
        self.runtime_types,
        instance.definition.type_,
      )
      CallableCaptureInput::{
        definition: instance.definition,
        function_type,
        substitutions: instance.substitution,
        specialized_parameters: [],
      }
    })
    let capture = self.plan_callable_captures(inputs)
    let origins = group_instances.map(instance => {
      LiftedRecursiveFunction(
        function=instance.definition.function.id,
        source=instance.definition.function.source,
      )
    })
    let plans : Array[LiftedFunctionPlan] = []
    ignore(
      self.plans.append_group(origins, fn(function_ids) {
        let recursive_functions = Array::makei(group_instances.length(), index => {
          let instance = group_instances[index]
          guard instance.definition.function.source is Some(value) else {
            abort("recursive ANF callable lacks its binding provenance")
          }
          {
            value,
            function: function_ids[index],
            type_: inputs[index].function_type,
          }
        })
        fn(index) {
          let instance = group_instances[index]
          let plan : LiftedFunctionPlan = {
            lowered_function: function_ids[index],
            function: instance.definition.function,
            instance: instance.id,
            type_: inputs[index].function_type,
            substitutions: instance.substitution,
            specialized_parameters: [],
            capture,
            recursive_functions,
          }
          plans.push(plan)
          LiftedFunction(plan)
        }
      }),
    )
    self.lifted_functions.append(plans)
    planned_groups.push((group, lexical_arguments))
  }
}

///|
fn ImageLowerer::lifted_function(
  self : ImageLowerer,
  instance : Int,
) -> LiftedFunctionPlan? {
  for plan in self.lifted_functions {
    if plan.instance == instance {
      return Some(plan)
    }
  }
  None
}

///|
fn CallableFlowFact::empty() -> CallableFlowFact {
  { callables: [], allocations: [], open: false }
}

///|
fn CallableFlowFact::open() -> CallableFlowFact {
  { callables: [], allocations: [], open: true }
}

///|
fn CallableFlowFact::callable(
  callable : CallableClosureFact,
) -> CallableFlowFact {
  { callables: [callable], allocations: [], open: false }
}

///|
fn CallableFlowFact::allocation(
  allocation : CallableAllocationKey,
) -> CallableFlowFact {
  { callables: [], allocations: [allocation], open: false }
}

///|
fn merge_callable_flow_fact(
  left : CallableFlowFact,
  right : CallableFlowFact,
) -> CallableFlowFact {
  let callables = left.callables.copy()
  for callable in right.callables {
    if !callables.contains(callable) {
      callables.push(callable)
    }
  }
  let allocations = left.allocations.copy()
  for allocation in right.allocations {
    if !allocations.contains(allocation) {
      allocations.push(allocation)
    }
  }
  { callables, allocations, open: left.open || right.open }
}

///|
fn CallableInstancePlanner::seed_top_level_callables(
  self : CallableInstancePlanner,
) -> Unit {
  for definition in self.catalog.definitions() {
    guard definition.owner is None else { continue }
    let lexical_arguments = self.identity_arguments(
      definition.lexical_parameters,
    )
    let own_arguments = self.identity_planned_arguments(definition.parameters)
    ignore(
      self.ensure_instance(
        definition,
        lexical_arguments,
        own_arguments,
        generic_fallback=true,
        caller=None,
      ),
    )
  }
}

///|
fn CallableInstancePlanner::analyze_top_terms(
  self : CallableInstancePlanner,
) -> Unit raise LoisvmLoweringError {
  for term in self.program.terms() {
    match term {
      Let(value, expression) => {
        let fact = self.eval_expr(expression, -1)
        self.update_binding(-1, Value(value), fact)
      }
      LetRec(bindings) =>
        for binding in bindings {
          self.update_binding(
            -1,
            Value(binding.id),
            self.eval_atom(binding.rhs, -1),
          )
        }
      External(value) => {
        guard self.image.metadata.value_info(value) is Some(info) else {
          continue
        }
        if runtime_type_can_carry_callable_flow(info.type_) {
          self.update_binding(-1, Value(value), CallableFlowFact::open())
        }
      }
    }
  }
}

///|
fn CallableInstancePlanner::analyze_instance(
  self : CallableInstancePlanner,
  instance_id : Int,
) -> Unit raise LoisvmLoweringError {
  let instance = self.instances[instance_id]
  let result = self.eval_expr(instance.definition.function.body, instance_id)
  self.update_result(instance_id, result)
}

///|
fn CallableInstancePlanner::eval_expr(
  self : CallableInstancePlanner,
  expression : @anf.AnfExpr,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.eval_atom(atom, caller)
    Let(binding, body) => {
      let fact = self.eval_rhs(binding.id(), binding.rhs(), caller)
      self.update_binding(caller, binding.id(), fact)
      self.eval_expr(body, caller)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.update_binding(
          caller,
          Value(binding.id),
          self.eval_atom(binding.rhs, caller),
        )
      }
      self.eval_expr(body, caller)
    }
  }
}

///|
fn CallableInstancePlanner::eval_rhs(
  self : CallableInstancePlanner,
  site : @anf.AnfBindingId,
  rhs : @anf.AnfRhs,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => self.eval_atom(atom, caller)
    ApplyEvidence(callee~, arguments~) => {
      let fact = self.eval_atom(callee, caller)
      let applied = arguments.map(argument => {
        self.planned_argument(caller, argument)
      })
      {
        ..fact,
        callables: fact.callables.map(callable => {
          ..callable,
          applied_arguments: callable.applied_arguments + applied,
        }),
      }
    }
    Call(callee~, arguments~) =>
      self.eval_call(
        caller,
        site,
        self.eval_atom(callee, caller),
        arguments.map(argument => self.eval_atom(argument, caller)),
      )
    Construct(construct) => {
      let key : CallableAllocationKey = { caller, site }
      let payloads = construct.payloads.map(payload => {
        self.eval_atom(payload, caller)
      })
      self.update_allocation({
        key,
        data_constructor: construct.data_constructor,
        payloads,
      })
      CallableFlowFact::allocation(key)
    }
    Match(match_) => self.eval_match(match_, caller)
  }
}

///|
fn CallableInstancePlanner::eval_atom(
  self : CallableInstancePlanner,
  atom : @anf.AnfAtom,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  match atom {
    Literal(_) => CallableFlowFact::empty()
    Ref(value) =>
      merge_callable_flow_fact(
        self.binding_fact(caller, Value(value)),
        self.binding_fact(-1, Value(value)),
      )
    Temp(temp) => self.binding_fact(caller, Temp(temp))
    Function(function) => self.function_fact(function.id, caller)
    EvidenceLambda(body~, ..) => self.eval_expr(body, caller)
  }
}

///|
fn CallableInstancePlanner::function_fact(
  self : CallableInstancePlanner,
  function : @anf.AnfFunctionId,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  guard self.catalog.find(function) is Some(definition) else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF callable catalog is incomplete",
    )
  }
  let lexical_arguments = definition.lexical_parameters.map(parameter => {
    self.argument_in_caller(caller, parameter)
  })
  ignore(
    self.ensure_instance(
      definition,
      lexical_arguments,
      self.identity_planned_arguments(definition.parameters),
      generic_fallback=true,
      caller=if caller < 0 { None } else { Some(caller) },
    ),
  )
  CallableFlowFact::callable({
    function,
    lexical_arguments,
    applied_arguments: [],
  })
}

///|
fn CallableInstancePlanner::eval_call(
  self : CallableInstancePlanner,
  caller : Int,
  site : @anf.AnfBindingId,
  callee : CallableFlowFact,
  arguments : Array[CallableFlowFact],
) -> CallableFlowFact {
  let mut result = CallableFlowFact::empty()
  let mut open = callee.open
  for callable in callee.callables {
    guard self.catalog.find(callable.function) is Some(definition) else {
      open = true
      continue
    }
    if callable.applied_arguments.length() != definition.parameters.length() {
      open = true
      continue
    }
    let instance = self.ensure_instance(
      definition,
      callable.lexical_arguments,
      callable.applied_arguments,
      generic_fallback=false,
      caller=if caller < 0 { None } else { Some(caller) },
    )
    self.record_call(caller, site, instance)
    for
      index in 0..<arguments
      .length()
      .min(definition.function.parameters.length()) {
      self.update_binding(
        instance,
        Value(definition.function.parameters[index]),
        arguments[index],
      )
    }
    result = merge_callable_flow_fact(result, self.result_fact(instance))
  }
  if open {
    for argument in arguments {
      for callable in argument.callables {
        if !self.open_functions.contains(callable.function) {
          self.open_functions.push(callable.function)
          self.changed = true
        }
      }
    }
    self.mark_call_open(caller, site)
    result = merge_callable_flow_fact(result, CallableFlowFact::open())
  }
  result
}

///|
fn CallableInstancePlanner::eval_match(
  self : CallableInstancePlanner,
  match_ : @anf.AnfMatch,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  let scrutinee = self.eval_atom(match_.scrutinee, caller)
  let mut result = CallableFlowFact::empty()
  for alternative in match_.alternatives {
    let matching = scrutinee.allocations.filter_map(key => {
      guard self.allocation(key) is Some(allocation) else { return None }
      match alternative.alt_constructor {
        DataCon(data_constructor) if data_constructor ==
          allocation.data_constructor => Some(allocation)
        Default => Some(allocation)
        Literal(_) | DataCon(_) => None
      }
    })
    for index, binder in alternative.value_binders {
      let mut fact = CallableFlowFact::empty()
      for allocation in matching {
        if allocation.payloads.get(index) is Some(payload) {
          fact = merge_callable_flow_fact(fact, payload)
        }
      }
      if scrutinee.open {
        fact = merge_callable_flow_fact(fact, CallableFlowFact::open())
      }
      self.update_binding(caller, Value(binder), fact)
    }
    result = merge_callable_flow_fact(
      result,
      self.eval_expr(alternative.body, caller),
    )
  }
  result
}

///|
fn CallableInstancePlanner::planned_argument(
  self : CallableInstancePlanner,
  caller : Int,
  argument : @anf.RuntimeArgument,
) -> PlannedRuntimeArgument raise LoisvmLoweringError {
  let transform = self.argument_transform(caller, argument)
  let argument = if caller < 0 {
    argument
  } else {
    self.instances[caller].substitution.apply_argument(
      self.image.runtime_types,
      argument,
    )
  }
  { argument, transform }
}

///|
fn CallableInstancePlanner::argument_transform(
  self : CallableInstancePlanner,
  caller : Int,
  argument : @anf.RuntimeArgument,
) -> RuntimeArgumentTransform {
  guard caller >= 0 else { return Closed }
  let instance = self.instances[caller]
  let parameters = instance.definition.lexical_parameters +
    instance.definition.parameters
  for parameter in parameters {
    if self.identity_argument(parameter) == argument {
      return Projection(parameter.id)
    }
  }
  if runtime_argument_mentions_any(
      self.image.runtime_types,
      argument,
      parameters.map(parameter => parameter.id),
    ) {
    Expanding
  } else {
    Closed
  }
}

///|
fn CallableInstancePlanner::ensure_instance(
  self : CallableInstancePlanner,
  definition : @anf.AnfCallableDefinition,
  lexical_arguments : Array[@anf.RuntimeArgument],
  own_arguments : Array[PlannedRuntimeArgument],
  generic_fallback~ : Bool,
  caller~ : Int?,
) -> Int {
  let mut recursive_fallback = false
  let own_arguments = match (caller, definition.recursive_group) {
    (Some(caller), Some(group)) if self.instances[caller].definition.recursive_group ==
      Some(group) &&
      own_arguments.any(argument => argument.transform is Expanding) => {
      if !self.rejected_recursive_groups.contains(group) {
        self.rejected_recursive_groups.push(group)
        self.changed = true
      }
      recursive_fallback = true
      self.identity_planned_arguments(definition.parameters)
    }
    _ => own_arguments
  }
  let generic_fallback = generic_fallback || recursive_fallback
  let arguments = lexical_arguments +
    own_arguments.map(argument => argument.argument)
  let key : CallableInstanceKey = {
    function: definition.function.id,
    arguments,
  }
  for instance in self.instances {
    if instance.key == key {
      return instance.id
    }
  }
  let substitution = RuntimeSubstitution::new()
  let parameters = definition.lexical_parameters + definition.parameters
  for index, parameter in parameters {
    substitution.insert(parameter.id, arguments[index])
  }
  let id = self.instances.length()
  self.instances.push({
    id,
    key,
    definition,
    substitution,
    own_arguments,
    generic_fallback,
  })
  self.results.push(CallableFlowFact::empty())
  self.changed = true
  id
}

///|
fn CallableInstancePlanner::identity_planned_arguments(
  self : CallableInstancePlanner,
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Array[PlannedRuntimeArgument] {
  parameters.map(parameter => {
    argument: self.identity_argument(parameter),
    transform: Projection(parameter.id),
  })
}

///|
fn CallableInstancePlanner::identity_arguments(
  self : CallableInstancePlanner,
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Array[@anf.RuntimeArgument] {
  parameters.map(parameter => self.identity_argument(parameter))
}

///|
fn CallableInstancePlanner::identity_argument(
  self : CallableInstancePlanner,
  parameter : @anf.RuntimeEvidenceParameter,
) -> @anf.RuntimeArgument {
  guard self.image.metadata.parameter_type_expression(parameter.id)
    is Some(type_expression) else {
    abort("Runtime ANF parameter lacks a type-expression identity")
  }
  { type_expression, evidence: Parameter(parameter.id) }
}

///|
fn CallableInstancePlanner::argument_in_caller(
  self : CallableInstancePlanner,
  caller : Int,
  parameter : @anf.RuntimeEvidenceParameter,
) -> @anf.RuntimeArgument {
  if caller >= 0 &&
    self.instances[caller].substitution.argument(parameter.id) is Some(argument) {
    argument
  } else {
    self.identity_argument(parameter)
  }
}

///|
fn CallableInstancePlanner::binding_fact(
  self : CallableInstancePlanner,
  caller : Int,
  binding : @anf.AnfBindingId,
) -> CallableFlowFact {
  for entry in self.bindings {
    if entry.caller == caller && entry.binding == binding {
      return entry.fact
    }
  }
  CallableFlowFact::empty()
}

///|
fn CallableInstancePlanner::update_binding(
  self : CallableInstancePlanner,
  caller : Int,
  binding : @anf.AnfBindingId,
  fact : CallableFlowFact,
) -> Unit {
  for entry in self.bindings {
    if entry.caller == caller && entry.binding == binding {
      let merged = merge_callable_flow_fact(entry.fact, fact)
      if merged != entry.fact {
        entry.fact = merged
        self.changed = true
      }
      return
    }
  }
  if fact != CallableFlowFact::empty() {
    self.bindings.push({ caller, binding, fact })
    self.changed = true
  }
}

///|
fn CallableInstancePlanner::result_fact(
  self : CallableInstancePlanner,
  instance : Int,
) -> CallableFlowFact {
  self.results[instance]
}

///|
fn CallableInstancePlanner::update_result(
  self : CallableInstancePlanner,
  instance : Int,
  fact : CallableFlowFact,
) -> Unit {
  let merged = merge_callable_flow_fact(self.results[instance], fact)
  if merged != self.results[instance] {
    self.results[instance] = merged
    self.changed = true
  }
}

///|
fn CallableInstancePlanner::update_allocation(
  self : CallableInstancePlanner,
  allocation : CallableAllocationFact,
) -> Unit {
  for existing in self.allocations {
    if existing.key == allocation.key {
      for
        index in 0..<existing.payloads
        .length()
        .min(allocation.payloads.length()) {
        let merged = merge_callable_flow_fact(
          existing.payloads[index],
          allocation.payloads[index],
        )
        if merged != existing.payloads[index] {
          existing.payloads[index] = merged
          self.changed = true
        }
      }
      return
    }
  }
  self.allocations.push(allocation)
  self.changed = true
}

///|
fn CallableInstancePlanner::allocation(
  self : CallableInstancePlanner,
  key : CallableAllocationKey,
) -> CallableAllocationFact? {
  for allocation in self.allocations {
    if allocation.key == key {
      return Some(allocation)
    }
  }
  None
}

///|
fn CallableInstancePlanner::record_call(
  self : CallableInstancePlanner,
  caller : Int,
  site : @anf.AnfBindingId,
  target : Int,
) -> Unit {
  for call in self.calls {
    if call.caller == caller && call.site == site {
      if !call.targets.contains(target) {
        call.targets.push(target)
        self.changed = true
      }
      return
    }
  }
  self.calls.push({ caller, site, targets: [target], open: false })
  self.changed = true
}

///|
fn CallableInstancePlanner::mark_call_open(
  self : CallableInstancePlanner,
  caller : Int,
  site : @anf.AnfBindingId,
) -> Unit {
  for call in self.calls {
    if call.caller == caller && call.site == site {
      if !call.open {
        call.open = true
        self.changed = true
      }
      return
    }
  }
  self.calls.push({ caller, site, targets: [], open: true })
  self.changed = true
}

///|
fn runtime_type_can_carry_callable_flow(type_ : @anf.RuntimeType) -> Bool {
  match type_ {
    Callable(_, _) | Forall(_, _) | Data(_, _) | Erased(_, _) => true
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => false
  }
}

///|
fn runtime_argument_mentions_any(
  runtime_types : RuntimeTypeArena,
  argument : @anf.RuntimeArgument,
  parameters : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  runtime_evidence_mentions_parameters(argument.evidence, parameters, []) ||
  runtime_type_expression_mentions_parameters(
    runtime_types,
    argument.type_expression,
    parameters,
    [],
  )
}

///|
fn runtime_evidence_mentions_parameters(
  evidence : @anf.RuntimeEvidence,
  parameters : Array[@anf.RuntimeEvidenceId],
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match evidence {
    Static(_) => false
    Parameter(parameter) =>
      !bound.contains(parameter) && parameters.contains(parameter)
    Apply(callee, arguments) =>
      runtime_evidence_mentions_parameters(callee, parameters, bound) ||
      arguments.any(argument => {
        runtime_evidence_mentions_parameters(argument, parameters, bound)
      })
    Lambda(binders, body) =>
      runtime_evidence_mentions_parameters(
        body,
        parameters,
        bound + binders.map(binder => binder.id),
      )
  }
}

///|
fn runtime_type_expression_mentions_parameters(
  runtime_types : RuntimeTypeArena,
  expression : @anf.RuntimeTypeExpressionId,
  parameters : Array[@anf.RuntimeEvidenceId],
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match runtime_types.type_expression(expression) {
    Some(Static(type_)) =>
      runtime_type_mentions_parameters(runtime_types, type_, parameters, bound)
    Some(Parameter(parameter)) =>
      !bound.contains(parameter) && parameters.contains(parameter)
    Some(Apply(callee, arguments)) =>
      runtime_type_expression_mentions_parameters(
        runtime_types, callee, parameters, bound,
      ) ||
      arguments.any(argument => {
        runtime_type_expression_mentions_parameters(
          runtime_types, argument, parameters, bound,
        )
      })
    Some(Lambda(binders, body)) =>
      runtime_type_expression_mentions_parameters(
        runtime_types,
        body,
        parameters,
        bound + binders.map(binder => binder.id),
      )
    None => false
  }
}

///|
fn runtime_type_mentions_parameters(
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
  parameters : Array[@anf.RuntimeEvidenceId],
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => false
    Erased(_, evidence) =>
      runtime_evidence_mentions_parameters(evidence, parameters, bound)
    Data(_, arguments) =>
      arguments.any(argument => {
        runtime_evidence_mentions_parameters(
          argument.evidence,
          parameters,
          bound,
        ) ||
        runtime_type_expression_mentions_parameters(
          runtime_types,
          argument.type_expression,
          parameters,
          bound,
        )
      })
    Callable(arguments, result) =>
      arguments.any(argument => {
        runtime_type_mentions_parameters(
          runtime_types, argument, parameters, bound,
        )
      }) ||
      runtime_type_mentions_parameters(runtime_types, result, parameters, bound)
    Forall(binders, body) =>
      runtime_type_mentions_parameters(
        runtime_types,
        body,
        parameters,
        bound + binders.map(binder => binder.id),
      )
  }
}
