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
priv enum CallablePlanBody {
  TopLevel
  Instance(Int)
} derive(Eq)

///|
priv struct CallableAllocationKey {
  body : CallablePlanBody
  site : @anf.AnfBindingId
} derive(Eq)

///|
priv struct CallableAllocationFact {
  key : CallableAllocationKey
  data_constructor : @buslane.DataConId
  type_arguments : Array[@anf.RuntimeArgument]
  hidden_arguments : Array[@anf.RuntimeArgument]
  payload_atoms : Array[@anf.AnfAtom]
  payloads : Array[CallableFlowFact]
}

///|
priv struct ClosedAggregateContract {
  owner : @buslane.TypeId
  data_constructor : @buslane.DataConId
  type_ : @anf.RuntimeType
  payload_types : Array[@anf.RuntimeType]
} derive(Eq)

///|
priv struct ScalarAllocationPlan {
  key : CallableAllocationKey
  contract : ClosedAggregateContract
}

///|
priv struct ScalarParameterPlan {
  instance : Int
  parameter_index : Int
  contract : ClosedAggregateContract
}

///|
priv struct ClosedAggregateScalarReplacementPlan {
  allocations : Array[ScalarAllocationPlan]
  parameters : Array[ScalarParameterPlan]
}

///|
priv struct DataRepresentationAllocationDemand {
  allocation : CallableAllocationKey
  family : DataRepresentationFamilyKey
  type_ : @anf.RuntimeType
}

///|
priv struct DataRepresentationInstanceDemand {
  instance : Int
  families : Array[DataRepresentationFamilyKey]
}

///|
priv struct DataRepresentationCallablePayloadDemand {
  allocation : CallableAllocationKey
  payload_index : Int
  instance : Int
  target_type : @anf.RuntimeType
  families : Array[DataRepresentationFamilyKey]
}

///|
priv struct DataRepresentationCallableArgumentDemand {
  caller : Int
  site : @anf.AnfBindingId
  argument_index : Int
  instance : Int
  target_type : @anf.RuntimeType
  families : Array[DataRepresentationFamilyKey]
}

///|
priv struct CallableRepresentationDraft {
  source_instance : Int
  lexical_arguments : Array[@anf.RuntimeArgument]
  own_arguments : Array[PlannedRuntimeArgument]
  caller : Int
} derive(Eq)

///|
priv struct DataRepresentationCallableArgumentCandidate {
  caller : Int
  site : @anf.AnfBindingId
  argument_index : Int
  draft : CallableRepresentationDraft
  target_type : @anf.RuntimeType
  families : Array[DataRepresentationFamilyKey]
}

///|
priv struct DataRepresentationUseGroup {
  instance : Int
  family : DataRepresentationFamilyKey
} derive(Eq)

///|
priv struct DataRepresentationUseEdge {
  from_group : DataRepresentationUseGroup
  to_group : DataRepresentationUseGroup
} derive(Eq)

///|
priv struct DataRepresentationDemandPlan {
  allocations : Array[DataRepresentationAllocationDemand]
  instances : Array[DataRepresentationInstanceDemand]
  callable_payloads : Array[DataRepresentationCallablePayloadDemand]
  callable_arguments : Array[DataRepresentationCallableArgumentDemand]
}

///|
fn DataRepresentationDemandPlan::empty() -> DataRepresentationDemandPlan {
  {
    allocations: [],
    instances: [],
    callable_payloads: [],
    callable_arguments: [],
  }
}

///|
fn ClosedAggregateScalarReplacementPlan::empty() -> ClosedAggregateScalarReplacementPlan {
  { allocations: [], parameters: [] }
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
  scalar_replacements : ClosedAggregateScalarReplacementPlan
  data_representations : DataRepresentationDemandPlan
  rejected_recursive_groups : Array[@anf.AnfRecursiveGroupId]
}

///|
fn CallableInstancePlan::empty() -> CallableInstancePlan {
  {
    instances: [],
    calls: [],
    scalar_replacements: ClosedAggregateScalarReplacementPlan::empty(),
    data_representations: DataRepresentationDemandPlan::empty(),
    rejected_recursive_groups: [],
  }
}

///|
fn CallableInstancePlan::data_family_at(
  self : CallableInstancePlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
) -> DataRepresentationFamilyKey? {
  guard !callers.is_empty() else { return None }
  let mut selected : DataRepresentationFamilyKey? = None
  for caller in callers {
    let allocation : CallableAllocationKey = {
      body: if caller < 0 {
        TopLevel
      } else {
        Instance(caller)
      },
      site,
    }
    guard data_family_for_allocation(
        self.data_representations.allocations,
        allocation,
      )
      is Some(family) else {
      return None
    }
    match selected {
      None => selected = Some(family)
      Some(existing) if existing == family => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn CallableInstancePlan::data_families_for_instances(
  self : CallableInstancePlan,
  instances : Array[Int],
) -> Array[DataRepresentationFamilyKey] {
  guard !instances.is_empty() else { return [] }
  let selected = data_families_for_instance(
    self.data_representations.instances,
    instances[0],
  )
  for index in 1..<instances.length() {
    let candidate = data_families_for_instance(
      self.data_representations.instances,
      instances[index],
    )
    if candidate != selected {
      return []
    }
  }
  selected
}

///|
fn CallableInstancePlan::data_callable_payload_instance(
  self : CallableInstancePlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
  payload_index : Int,
) -> Int? {
  guard !callers.is_empty() else { return None }
  let mut selected : Int? = None
  for caller in callers {
    let key : CallableAllocationKey = {
      body: if caller < 0 {
        TopLevel
      } else {
        Instance(caller)
      },
      site,
    }
    let mut found : Int? = None
    for demand in self.data_representations.callable_payloads {
      if demand.allocation == key && demand.payload_index == payload_index {
        found = Some(demand.instance)
        break
      }
    }
    guard found is Some(instance) else { return None }
    match selected {
      None => selected = Some(instance)
      Some(existing) if existing == instance => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn CallableInstancePlan::callable_payload_target_type(
  self : CallableInstancePlan,
  instance : Int,
) -> @anf.RuntimeType? {
  let mut selected : @anf.RuntimeType? = None
  for demand in self.data_representations.callable_payloads {
    guard demand.instance == instance else { continue }
    match selected {
      None => selected = Some(demand.target_type)
      Some(existing) if existing == demand.target_type => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn CallableInstancePlan::data_callable_argument_instance(
  self : CallableInstancePlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
  argument_index : Int,
) -> Int? {
  guard !callers.is_empty() else { return None }
  let mut selected : Int? = None
  for caller in callers {
    let mut found : Int? = None
    for demand in self.data_representations.callable_arguments {
      if demand.caller == caller &&
        demand.site == site &&
        demand.argument_index == argument_index {
        found = Some(demand.instance)
        break
      }
    }
    guard found is Some(instance) else { return None }
    match selected {
      None => selected = Some(instance)
      Some(existing) if existing == instance => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn CallableInstancePlan::callable_representation_target_type(
  self : CallableInstancePlan,
  instance : Int,
) -> @anf.RuntimeType? {
  let mut selected = self.callable_payload_target_type(instance)
  for demand in self.data_representations.callable_arguments {
    guard demand.instance == instance else { continue }
    match selected {
      None => selected = Some(demand.target_type)
      Some(existing) if existing == demand.target_type => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn CallableInstancePlan::callable_representation_data_families(
  self : CallableInstancePlan,
  instance : Int,
) -> Array[DataRepresentationFamilyKey] {
  let families = []
  for demand in self.data_representations.callable_payloads {
    if demand.instance == instance {
      append_unique_data_families(families, demand.families)
    }
  }
  for demand in self.data_representations.callable_arguments {
    if demand.instance == instance {
      append_unique_data_families(families, demand.families)
    }
  }
  families
}

///|
fn append_unique_data_families(
  target : Array[DataRepresentationFamilyKey],
  source : Array[DataRepresentationFamilyKey],
) -> Unit {
  for family in source {
    if !target.contains(family) {
      target.push(family)
    }
  }
}

///|
fn CallableInstancePlan::scalar_allocation_contract(
  self : CallableInstancePlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
) -> ClosedAggregateContract? {
  guard !callers.is_empty() else { return None }
  let mut selected : ClosedAggregateContract? = None
  for caller in callers {
    let key : CallableAllocationKey = {
      body: if caller < 0 {
        TopLevel
      } else {
        Instance(caller)
      },
      site,
    }
    let mut found : ClosedAggregateContract? = None
    for allocation in self.scalar_replacements.allocations {
      if allocation.key == key {
        found = Some(allocation.contract)
        break
      }
    }
    guard found is Some(contract) else { return None }
    match selected {
      None => selected = Some(contract)
      Some(existing) if existing == contract => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn CallableInstancePlan::scalar_parameter_contract(
  self : CallableInstancePlan,
  instance : Int,
  parameter_index : Int,
) -> ClosedAggregateContract? {
  for parameter in self.scalar_replacements.parameters {
    if parameter.instance == instance &&
      parameter.parameter_index == parameter_index {
      return Some(parameter.contract)
    }
  }
  None
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
fn CallableInstancePlan::is_closed_call_target(
  self : CallableInstancePlan,
  instance : Int,
) -> Bool {
  self.calls.any(call => !call.open && call.targets.contains(instance))
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
    detail="callable lowering requested function \{function.value} with \{Repr(arguments)} absent from the immutable plan",
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
  for _state = () {
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
    planner.changed = false
    let count = planner.instances.length()
    let (scalar_replacements, data_representations) = planner.plan_aggregate_representations()
    if planner.changed || planner.instances.length() != count {
      continue ()
    }
    break {
      instances: planner.instances,
      calls: planner.calls,
      scalar_replacements,
      data_representations,
      rejected_recursive_groups: planner.rejected_recursive_groups,
    }
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
        data_families: [],
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
      let key : CallableAllocationKey = {
        body: if caller < 0 {
          TopLevel
        } else {
          Instance(caller)
        },
        site,
      }
      let payloads = construct.payloads.map(payload => {
        self.eval_atom(payload, caller)
      })
      self.update_allocation({
        key,
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_arguments: construct.hidden_arguments,
        payload_atoms: construct.payloads,
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
  self.update_binding(caller, Value(match_.binder), scrutinee)
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
priv enum ScalarCarrierConsumer {
  Alias(Int, @anf.AnfBindingId)
  ExactCall(Int, Int)
  ClosedCall(Array[Int])
  Construct(CallableAllocationKey)
  Match(scalar_projectable~ : Bool)
  Return(Int)
  UnsupportedCallee
  UnsupportedEvidence
  Capture(Array[Int])
  UnsupportedArgument
}

///|
priv struct ScalarCarrierUse {
  caller : Int
  binding : @anf.AnfBindingId
  fact : CallableFlowFact
  consumers : Array[ScalarCarrierConsumer]
}

///|
priv struct ScalarCallObservation {
  caller : Int
  site : @anf.AnfBindingId
  target : Int
  parameter_index : Int
  atom : @anf.AnfAtom
  fact : CallableFlowFact
}

///|
priv struct ScalarUseAnalysis {
  planner : CallableInstancePlanner
  uses : Array[ScalarCarrierUse]
  calls : Array[ScalarCallObservation]
}

///|
fn CallableInstancePlanner::plan_aggregate_representations(
  self : CallableInstancePlanner,
) -> (ClosedAggregateScalarReplacementPlan, DataRepresentationDemandPlan) raise LoisvmLoweringError {
  let analysis : ScalarUseAnalysis = { planner: self, uses: [], calls: [] }
  analysis.collect()
  let scalar = analysis.finish()
  (scalar, analysis.finish_data_representations(scalar))
}

///|
fn ScalarUseAnalysis::collect(
  self : ScalarUseAnalysis,
) -> Unit raise LoisvmLoweringError {
  for term in self.planner.program.terms() {
    match term {
      Let(_, expression) => self.collect_expr(expression, -1, Return(-1))
      LetRec(bindings) =>
        for binding in bindings {
          self.collect_atom_captures(binding.rhs, -1)
        }
      External(_) => ()
    }
  }
  for instance in self.planner.instances {
    self.collect_expr(
      instance.definition.function.body,
      instance.id,
      Return(instance.id),
    )
  }
}

///|
fn ScalarUseAnalysis::collect_expr(
  self : ScalarUseAnalysis,
  expression : @anf.AnfExpr,
  caller : Int,
  result_consumer : ScalarCarrierConsumer,
) -> Unit raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.record_atom_use(atom, caller, result_consumer)
    Let(binding, body) => {
      self.collect_rhs(binding.id(), binding.rhs(), caller)
      self.collect_expr(body, caller, result_consumer)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.collect_atom_captures(binding.rhs, caller)
      }
      self.collect_expr(body, caller, result_consumer)
    }
  }
}

///|
fn ScalarUseAnalysis::collect_rhs(
  self : ScalarUseAnalysis,
  site : @anf.AnfBindingId,
  rhs : @anf.AnfRhs,
  caller : Int,
) -> Unit raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => self.record_atom_use(atom, caller, Alias(caller, site))
    ApplyEvidence(callee~, ..) =>
      self.record_atom_use(callee, caller, UnsupportedEvidence)
    Construct(construct) => {
      let allocation : CallableAllocationKey = {
        body: if caller < 0 {
          TopLevel
        } else {
          Instance(caller)
        },
        site,
      }
      for payload in construct.payloads {
        self.record_atom_use(payload, caller, Construct(allocation))
      }
    }
    Match(match_) => {
      let fact = self.atom_fact(match_.scrutinee, caller)
      let consumer = ScalarCarrierConsumer::Match(
        scalar_projectable=self.match_accepts_fact(match_, fact),
      )
      self.record_atom_use(match_.scrutinee, caller, consumer)
      for alternative in match_.alternatives {
        self.collect_expr(alternative.body, caller, UnsupportedArgument)
      }
    }
    Call(callee~, arguments~) => {
      self.record_atom_use(callee, caller, UnsupportedCallee)
      let target = self.exact_call_target(caller, site)
      let targets = self.closed_call_targets(caller, site)
      for index, argument in arguments {
        let fact = self.atom_fact(argument, caller)
        match target {
          Some(instance) if index <
            self.planner.instances[instance].definition.function.parameters.length() => {
            self.calls.push({
              caller,
              site,
              target: instance,
              parameter_index: index,
              atom: argument,
              fact,
            })
            self.record_atom_use(argument, caller, ExactCall(instance, index))
          }
          _ =>
            if !targets.is_empty() &&
              targets.all(instance => {
                index <
                self.planner.instances[instance].definition.function.parameters.length()
              }) {
              for instance in targets {
                self.calls.push({
                  caller,
                  site,
                  target: instance,
                  parameter_index: index,
                  atom: argument,
                  fact,
                })
              }
              self.record_atom_use(argument, caller, ClosedCall(targets))
            } else {
              self.record_atom_use(argument, caller, UnsupportedArgument)
            }
        }
      }
    }
  }
}

///|
fn ScalarUseAnalysis::collect_atom_captures(
  self : ScalarUseAnalysis,
  atom : @anf.AnfAtom,
  caller : Int,
) -> Unit {
  let function = match atom {
    Function(function) => Some(function)
    EvidenceLambda(body~, ..) => extract_top_function(body)
    _ => None
  }
  guard function is Some(function) &&
    self.planner.catalog.find(function.id) is Some(definition) else {
    return
  }
  let instances = self.planner.capture_instances(definition, caller)
  for capture in definition.captures {
    match capture {
      Value(value) =>
        self.record_binding_use(caller, Value(value), Capture(instances))
      Temp(temp) =>
        self.record_binding_use(caller, Temp(temp), Capture(instances))
    }
  }
}

///|
fn CallableInstancePlanner::capture_instances(
  self : CallableInstancePlanner,
  definition : @anf.AnfCallableDefinition,
  caller : Int,
) -> Array[Int] {
  let lexical_arguments = definition.lexical_parameters.map(parameter => {
    self.argument_in_caller(caller, parameter)
  })
  let arguments = lexical_arguments +
    self.identity_arguments(definition.parameters)
  self.instances.filter_map(instance => {
    if instance.definition.function.id == definition.function.id &&
      instance.key.arguments == arguments {
      Some(instance.id)
    } else {
      None
    }
  })
}

///|
fn ScalarUseAnalysis::record_atom_use(
  self : ScalarUseAnalysis,
  atom : @anf.AnfAtom,
  caller : Int,
  consumer : ScalarCarrierConsumer,
) -> Unit {
  self.collect_atom_captures(atom, caller)
  match atom {
    Ref(value) => {
      let local_fact = self.planner.binding_fact(caller, Value(value))
      if !local_fact.allocations.is_empty() {
        self.record_binding_use(caller, Value(value), consumer)
      } else {
        self.record_binding_use(-1, Value(value), consumer)
      }
    }
    Temp(temp) => self.record_binding_use(caller, Temp(temp), consumer)
    _ => ()
  }
}

///|
fn ScalarUseAnalysis::record_binding_use(
  self : ScalarUseAnalysis,
  caller : Int,
  binding : @anf.AnfBindingId,
  consumer : ScalarCarrierConsumer,
) -> Unit {
  let fact = self.planner.binding_fact(caller, binding)
  guard !fact.allocations.is_empty() else { return }
  for usage in self.uses {
    if usage.caller == caller && usage.binding == binding {
      usage.consumers.push(consumer)
      return
    }
  }
  self.uses.push({ caller, binding, fact, consumers: [consumer] })
}

///|
fn ScalarUseAnalysis::atom_fact(
  self : ScalarUseAnalysis,
  atom : @anf.AnfAtom,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  match atom {
    Ref(value) => {
      let local_fact = self.planner.binding_fact(caller, Value(value))
      if !local_fact.allocations.is_empty() {
        local_fact
      } else {
        self.planner.binding_fact(-1, Value(value))
      }
    }
    Temp(temp) => self.planner.binding_fact(caller, Temp(temp))
    Function(_) | EvidenceLambda(_) => self.planner.eval_atom(atom, caller)
    Literal(_) => CallableFlowFact::empty()
  }
}

///|
fn ScalarUseAnalysis::exact_call_target(
  self : ScalarUseAnalysis,
  caller : Int,
  site : @anf.AnfBindingId,
) -> Int? {
  for call in self.planner.calls {
    if call.caller == caller && call.site == site {
      guard !call.open && call.targets is [target] else { return None }
      return Some(target)
    }
  }
  None
}

///|
fn ScalarUseAnalysis::closed_call_targets(
  self : ScalarUseAnalysis,
  caller : Int,
  site : @anf.AnfBindingId,
) -> Array[Int] {
  for call in self.planner.calls {
    if call.caller == caller && call.site == site && !call.open {
      return call.targets
    }
  }
  []
}

///|
fn ScalarUseAnalysis::match_accepts_fact(
  self : ScalarUseAnalysis,
  match_ : @anf.AnfMatch,
  fact : CallableFlowFact,
) -> Bool raise LoisvmLoweringError {
  guard !fact.open && !fact.allocations.is_empty() else { return false }
  for key in fact.allocations {
    guard self.planner.closed_aggregate_contract(key) is Some(contract) else {
      return false
    }
    let mut selected : @anf.AnfAlternative? = None
    let mut default : @anf.AnfAlternative? = None
    for alternative in match_.alternatives {
      match alternative.alt_constructor {
        DataCon(data_constructor) if data_constructor ==
          contract.data_constructor => {
          selected = Some(alternative)
          break
        }
        Default => default = Some(alternative)
        _ => ()
      }
    }
    if selected is None {
      selected = default
    }
    guard selected is Some(alternative) &&
      alternative.evidence_binders.is_empty() else {
      return false
    }
    match alternative.alt_constructor {
      DataCon(_) if alternative.value_binders.length() ==
        contract.payload_types.length() => ()
      Default if alternative.value_binders.is_empty() => ()
      _ => return false
    }
  }
  true
}

///|
fn CallableInstancePlanner::closed_aggregate_contract(
  self : CallableInstancePlanner,
  key : CallableAllocationKey,
) -> ClosedAggregateContract? raise LoisvmLoweringError {
  guard self.allocation(key) is Some(allocation) &&
    allocation.hidden_arguments.is_empty() &&
    self.image.metadata.data_constructor_info(allocation.data_constructor)
    is Some(info) &&
    info.hidden_evidence_parameters.is_empty() &&
    self.image.metadata.type_info(info.owner) is Some(owner) else {
    return None
  }
  let substitutions = match key.body {
    TopLevel => RuntimeSubstitution::new()
    Instance(instance) => self.instances[instance].substitution
  }
  let type_arguments = allocation.type_arguments.map(argument => {
    substitutions.apply_argument(self.image.runtime_types, argument)
  })
  guard type_arguments.length() == owner.evidence_parameters.length() else {
    return None
  }
  let data_substitutions = RuntimeSubstitution::from_arguments(
    owner.evidence_parameters,
    type_arguments,
  )
  let payload_types = info.payload_types.map(type_ => {
    data_substitutions.apply_type(self.image.runtime_types, type_)
  })
  guard payload_types.all(type_ => self.image.runtime_type(type_) is Concrete(_)) else {
    return None
  }
  Some({
    owner: info.owner,
    data_constructor: allocation.data_constructor,
    type_: Data(info.owner, type_arguments),
    payload_types,
  })
}

///|
fn ScalarUseAnalysis::finish(
  self : ScalarUseAnalysis,
) -> ClosedAggregateScalarReplacementPlan raise LoisvmLoweringError {
  let rejected : Array[CallableAllocationKey] = []
  for allocation in self.planner.allocations {
    if self.planner.closed_aggregate_contract(allocation.key) is None {
      rejected.push(allocation.key)
    }
  }
  for usage in self.uses {
    if usage.fact.open ||
      usage.consumers.length() != 1 ||
      !scalar_replacement_consumer(usage.consumers[0]) {
      reject_allocations(rejected, usage.fact.allocations)
    }
  }
  for allocation in self.planner.allocations {
    let caller = match allocation.key.body {
      TopLevel => -1
      Instance(instance) => instance
    }
    if self.find_use(caller, allocation.key.site) is None {
      reject_allocations(rejected, [allocation.key])
    }
  }
  let mut parameters : Array[ScalarParameterPlan] = []
  while true {
    parameters = self.scalar_parameters(rejected)
    let before = rejected.length()
    for usage in self.uses {
      guard usage.consumers is [ExactCall(instance, parameter_index)] else {
        continue
      }
      if !parameters.any(parameter => {
          parameter.instance == instance &&
          parameter.parameter_index == parameter_index
        }) {
        reject_allocations(rejected, usage.fact.allocations)
      }
    }
    for allocation in self.planner.allocations {
      guard !rejected.contains(allocation.key) &&
        !self.allocation_reaches_match(allocation.key, parameters, rejected) else {
        continue
      }
      rejected.push(allocation.key)
    }
    if rejected.length() == before {
      break
    }
  }
  parameters = self.scalar_parameters(rejected)
  let allocations = []
  for allocation in self.planner.allocations {
    guard !rejected.contains(allocation.key) &&
      self.planner.closed_aggregate_contract(allocation.key) is Some(contract) else {
      continue
    }
    allocations.push({ key: allocation.key, contract })
  }
  { allocations, parameters }
}

///|
fn ScalarUseAnalysis::scalar_parameters(
  self : ScalarUseAnalysis,
  rejected : Array[CallableAllocationKey],
) -> Array[ScalarParameterPlan] raise LoisvmLoweringError {
  let parameters : Array[ScalarParameterPlan] = []
  for instance in self.planner.instances {
    guard !instance.generic_fallback && instance.definition.captures.is_empty() else {
      continue
    }
    for index in 0..<instance.definition.function.parameters.length() {
      let observations = self.calls.filter(observation => {
        observation.target == instance.id &&
        observation.parameter_index == index
      })
      guard !observations.is_empty() else { continue }
      let mut selected : ClosedAggregateContract? = None
      let mut valid = true
      for observation in observations {
        if observation.fact.open ||
          !observation.fact.callables.is_empty() ||
          observation.fact.allocations.is_empty() {
          valid = false
          break
        }
        for allocation in observation.fact.allocations {
          if rejected.contains(allocation) {
            valid = false
            break
          }
          guard self.planner.closed_aggregate_contract(allocation)
            is Some(contract) else {
            valid = false
            break
          }
          match selected {
            None => selected = Some(contract)
            Some(existing) if existing == contract => ()
            Some(_) => valid = false
          }
        }
        if !valid {
          break
        }
      }
      if valid && selected is Some(contract) {
        parameters.push({
          instance: instance.id,
          parameter_index: index,
          contract,
        })
      }
    }
  }
  parameters
}

///|
fn ScalarUseAnalysis::allocation_reaches_match(
  self : ScalarUseAnalysis,
  allocation : CallableAllocationKey,
  parameters : Array[ScalarParameterPlan],
  rejected : Array[CallableAllocationKey],
) -> Bool {
  let mut caller = match allocation.body {
    TopLevel => -1
    Instance(instance) => instance
  }
  let mut binding = allocation.site
  let visited : Array[(Int, @anf.AnfBindingId)] = []
  while true {
    if visited.contains((caller, binding)) {
      return false
    }
    visited.push((caller, binding))
    guard self.find_use(caller, binding) is Some(usage) &&
      !usage.fact.allocations.any(key => rejected.contains(key)) &&
      usage.consumers is [consumer] else {
      return false
    }
    match consumer {
      Match(scalar_projectable=true) => return true
      Alias(next_caller, next_binding) => {
        caller = next_caller
        binding = next_binding
      }
      ExactCall(instance, parameter_index) => {
        guard parameters.any(parameter => {
            parameter.instance == instance &&
            parameter.parameter_index == parameter_index
          }) &&
          self.planner.instances[instance].definition.function.parameters.get(
            parameter_index,
          )
          is Some(parameter) else {
          return false
        }
        caller = instance
        binding = Value(parameter)
      }
      Match(scalar_projectable=false)
      | ClosedCall(_)
      | Construct(_)
      | Return(_)
      | Capture(_)
      | UnsupportedCallee
      | UnsupportedEvidence
      | UnsupportedArgument => return false
    }
  } nobreak {
    false
  }
}

///|
fn scalar_replacement_consumer(consumer : ScalarCarrierConsumer) -> Bool {
  consumer is (Alias(_, _) | ExactCall(_, _) | Match(scalar_projectable=true))
}

///|
fn ScalarUseAnalysis::finish_data_representations(
  self : ScalarUseAnalysis,
  scalar : ClosedAggregateScalarReplacementPlan,
) -> DataRepresentationDemandPlan raise LoisvmLoweringError {
  let candidates : Array[DataRepresentationAllocationDemand] = []
  for allocation in self.planner.allocations {
    guard !scalar.allocations.any(replacement => {
        replacement.key == allocation.key
      }) &&
      self.planner.data_representation_candidate(allocation) is Some(candidate) else {
      continue
    }
    candidates.push(candidate)
  }
  let rejected : Array[DataRepresentationUseGroup] = []
  let edges : Array[DataRepresentationUseEdge] = []
  for usage in self.uses {
    let families = data_families_in_fact(usage.fact, candidates)
    guard !families.is_empty() else { continue }
    let groups = data_groups_in_fact(usage.fact, candidates)
    if usage.fact.open || families.length() != 1 {
      reject_data_groups(rejected, groups)
      continue
    }
    let family = families[0]
    for consumer in usage.consumers {
      match consumer {
        Alias(_, _) | Match(_) => ()
        ExactCall(instance, _) => {
          let target = { instance, family }
          if self.planner.instances.get(instance) is Some(candidate) &&
            !self.planner.instance_rejects_data_representation(candidate) {
            connect_data_groups(edges, groups, target)
          } else {
            reject_data_groups(rejected, groups)
          }
        }
        ClosedCall(targets) =>
          for instance in targets {
            let target = { instance, family }
            if self.planner.instances.get(instance) is Some(candidate) &&
              !self.planner.instance_rejects_data_representation(candidate) {
              connect_data_groups(edges, groups, target)
            } else {
              reject_data_groups(rejected, groups)
            }
          }
        Return(instance) =>
          if instance >= 0 {
            connect_data_groups(edges, groups, { instance, family })
          } else {
            reject_data_groups(rejected, groups)
          }
        Construct(allocation) =>
          if !scalar.allocations.any(replacement => {
              replacement.key == allocation
            }) &&
            data_family_for_allocation(candidates, allocation)
            is Some(outer_family) {
            connect_data_groups(
              edges,
              groups,
              data_group_for_allocation(allocation, outer_family),
            )
          } else {
            reject_data_groups(rejected, groups)
          }
        Capture(targets) =>
          if targets.is_empty() {
            reject_data_groups(rejected, groups)
          } else {
            for instance in targets {
              let target = { instance, family }
              if self.planner.instances.get(instance) is Some(candidate) &&
                !self.planner.instance_rejects_data_representation(candidate) {
                connect_data_groups(edges, groups, target)
              } else {
                reject_data_groups(rejected, groups)
              }
            }
          }
        UnsupportedCallee => reject_data_groups(rejected, groups)
        UnsupportedEvidence => reject_data_groups(rejected, groups)
        UnsupportedArgument => reject_data_groups(rejected, groups)
      }
    }
  }
  for candidate in candidates {
    let caller = match candidate.allocation.body {
      TopLevel => -1
      Instance(instance) => instance
    }
    if self.find_use(caller, candidate.allocation.site) is None {
      reject_data_groups(rejected, [
        data_group_for_allocation(candidate.allocation, candidate.family),
      ])
    }
    guard self.planner.allocation(candidate.allocation) is Some(allocation) else {
      reject_data_groups(rejected, [
        data_group_for_allocation(candidate.allocation, candidate.family),
      ])
      continue
    }
    for index, payload in allocation.payloads {
      guard self.planner.data_candidate_payload_type(candidate, index)
        is Some(Callable(_, _) | Forall(_, _) as target_type) else {
        continue
      }
      if self.planner.callable_draft_for_data_payload(
          allocation, index, payload, target_type,
        )
        is None {
        reject_data_groups(rejected, [
          data_group_for_allocation(candidate.allocation, candidate.family),
        ])
      }
    }
  }
  while true {
    let before = edges.length()
    for group in data_representation_groups(candidates, edges) {
      guard group.instance >= 0 &&
        self.planner.instances.get(group.instance) is Some(instance) else {
        continue
      }
      for definition in self.planner.catalog.definitions() {
        guard definition.owner == Some(instance.definition.function.id) else {
          continue
        }
        let targets = self.planner.capture_instances(definition, group.instance)
        for capture in definition.captures {
          guard self.planner.catalog.capture_type(
              capture,
              self.planner.image.metadata,
            )
            is Some(type_) &&
            self.planner.image.data_family_key_for_type(
              instance.substitution.apply_type(
                self.planner.image.runtime_types,
                type_,
              ),
            ) ==
            Some(group.family) else {
            continue
          }
          for target in targets {
            connect_data_groups(edges, [group], {
              instance: target,
              family: group.family,
            })
          }
        }
      }
    }
    if edges.length() == before {
      break
    }
  }
  let groups = data_representation_groups(candidates, edges)
  for group in groups {
    guard group.instance >= 0 &&
      self.planner.instances.get(group.instance) is Some(instance) else {
      continue
    }
    let (_, formal_parameters, _) = function_type_parts(
      instance.definition.type_,
    )
    for observation in self.calls {
      guard observation.target == group.instance &&
        formal_parameters.get(observation.parameter_index) is Some(formal) else {
        continue
      }
      let actual = instance.substitution.apply_type(
        self.planner.image.runtime_types,
        formal,
      )
      guard self.planner.image.data_family_key_for_type(actual) ==
        Some(group.family) else {
        continue
      }
      let observed = data_families_in_fact(observation.fact, candidates)
      if observation.fact.open || observed != [group.family] {
        reject_data_groups(rejected, [group])
      }
    }
  }
  let callable_argument_candidates : Array[
    (
      DataRepresentationCallableArgumentCandidate,
      Array[DataRepresentationUseGroup],
    ),
  ] = []
  for observation in self.calls {
    let target_groups = groups.filter(group => {
      group.instance == observation.target && !rejected.contains(group)
    })
    guard !target_groups.is_empty() &&
      self.planner.instances.get(observation.target) is Some(target) else {
      continue
    }
    let (_, formal_parameters, _) = function_type_parts(target.definition.type_)
    guard formal_parameters.get(observation.parameter_index) is Some(formal) else {
      continue
    }
    let target_type = target.substitution.apply_type(
      self.planner.image.runtime_types,
      formal,
    )
    guard target_type is (Callable(_, _) | Forall(_, _)) else { continue }
    guard observation.atom is (Function(_) | EvidenceLambda(_)) &&
      self.planner.representation_draft_for_fact(
        observation.fact,
        target_type,
        observation.caller,
      )
      is Some(draft) else {
      continue
    }
    let families = []
    for group in target_groups {
      if !families.contains(group.family) {
        families.push(group.family)
      }
    }
    callable_argument_candidates.push(
      (
        {
          caller: observation.caller,
          site: observation.site,
          argument_index: observation.parameter_index,
          draft,
          target_type,
          families,
        },
        target_groups,
      ),
    )
  }
  for index, left in callable_argument_candidates {
    for right_index in (index + 1)..<callable_argument_candidates.length() {
      let right = callable_argument_candidates[right_index]
      if left.0.draft == right.0.draft &&
        (
          left.0.target_type != right.0.target_type ||
          left.0.families != right.0.families
        ) {
        reject_data_groups(rejected, left.1)
        reject_data_groups(rejected, right.1)
      }
    }
  }
  while true {
    let before = rejected.length()
    for edge in edges {
      if rejected.contains(edge.from_group) {
        reject_data_groups(rejected, [edge.to_group])
      }
      if rejected.contains(edge.to_group) {
        reject_data_groups(rejected, [edge.from_group])
      }
    }
    if rejected.length() == before {
      break
    }
  }
  let allocations = candidates.filter(candidate => {
    !rejected.contains(
      data_group_for_allocation(candidate.allocation, candidate.family),
    )
  })
  let instances : Array[DataRepresentationInstanceDemand] = []
  for candidate in allocations {
    let group = data_group_for_allocation(
      candidate.allocation,
      candidate.family,
    )
    add_instance_data_family(instances, group.instance, group.family)
  }
  for edge in edges {
    if !rejected.contains(edge.from_group) && !rejected.contains(edge.to_group) {
      add_instance_data_family(
        instances,
        edge.from_group.instance,
        edge.from_group.family,
      )
      add_instance_data_family(
        instances,
        edge.to_group.instance,
        edge.to_group.family,
      )
    }
  }
  let callable_payloads : Array[DataRepresentationCallablePayloadDemand] = []
  for candidate in allocations {
    guard self.planner.allocation(candidate.allocation) is Some(allocation) else {
      continue
    }
    for index, payload in allocation.payloads {
      guard self.planner.data_candidate_payload_type(candidate, index)
        is Some(Callable(_, _) | Forall(_, _) as target_type) &&
        self.planner.callable_draft_for_data_payload(
          allocation, index, payload, target_type,
        )
        is Some(draft) else {
        continue
      }
      let instance = self.planner.materialize_representation_draft(draft)
      callable_payloads.push({
        allocation: candidate.allocation,
        payload_index: index,
        instance,
        target_type,
        families: [candidate.family],
      })
    }
  }
  let callable_arguments = callable_argument_candidates.filter_map(candidate => {
    if candidate.1.any(group => rejected.contains(group)) {
      None
    } else {
      let accepted = candidate.0
      Some({
        caller: accepted.caller,
        site: accepted.site,
        argument_index: accepted.argument_index,
        instance: self.planner.materialize_representation_draft(accepted.draft),
        target_type: accepted.target_type,
        families: accepted.families,
      })
    }
  })
  { allocations, instances, callable_payloads, callable_arguments }
}

///|
fn CallableInstancePlanner::data_candidate_payload_type(
  self : CallableInstancePlanner,
  candidate : DataRepresentationAllocationDemand,
  index : Int,
) -> @anf.RuntimeType? raise LoisvmLoweringError {
  guard candidate.type_ is Data(owner, arguments) &&
    self.image.metadata.type_info(owner) is Some(owner_info) &&
    self.allocation(candidate.allocation) is Some(allocation) &&
    self.image.metadata.data_constructor_info(allocation.data_constructor)
    is Some(constructor_info) &&
    constructor_info.payload_types.get(index) is Some(payload_type) else {
    return None
  }
  RuntimeSubstitution::from_arguments(owner_info.evidence_parameters, arguments).apply_type(
    self.image.runtime_types,
    payload_type,
  )
  |> Some
}

///|
fn CallableInstancePlanner::callable_instance_for_fact(
  self : CallableInstancePlanner,
  fact : CallableFlowFact,
) -> Int? {
  guard !fact.open &&
    fact.callables is [callable] &&
    self.catalog.find(callable.function) is Some(definition) else {
    return None
  }
  if callable.applied_arguments.length() == definition.parameters.length() {
    let arguments = callable.lexical_arguments +
      callable.applied_arguments.map(argument => argument.argument)
    for instance in self.instances {
      if !instance.generic_fallback &&
        instance.key.function == callable.function &&
        instance.key.arguments == arguments {
        return Some(instance.id)
      }
    }
  }
  if callable.applied_arguments.is_empty() {
    for instance in self.instances {
      if instance.generic_fallback &&
        instance.key.function == callable.function &&
        instance.key.arguments[:definition.lexical_parameters.length()].to_owned() ==
        callable.lexical_arguments {
        return Some(instance.id)
      }
    }
  }
  None
}

///|
fn CallableInstancePlanner::representation_draft_for_fact(
  self : CallableInstancePlanner,
  fact : CallableFlowFact,
  target_type : @anf.RuntimeType,
  caller : Int,
) -> CallableRepresentationDraft? raise LoisvmLoweringError {
  guard self.callable_instance_for_fact(fact) is Some(source) else {
    return None
  }
  let source_instance = self.instances[source]
  let definition = source_instance.definition
  let parameters = definition.lexical_parameters + definition.parameters
  let substitutions = self.image.refine_callable_representation_substitution(
    definition.type_,
    target_type,
    source_instance.substitution,
    parameters.map(parameter => parameter.id),
  )
  let lexical_arguments = definition.lexical_parameters.map(parameter => {
    substitutions
    .argument(parameter.id)
    .unwrap_or(self.identity_argument(parameter))
  })
  let own_arguments = []
  for index, parameter in definition.parameters {
    let argument = substitutions
      .argument(parameter.id)
      .unwrap_or(source_instance.own_arguments[index].argument)
    own_arguments.push({
      argument,
      transform: if is_closed_generic_argument(argument) {
        Closed
      } else {
        source_instance.own_arguments[index].transform
      },
    })
  }
  Some({ source_instance: source, lexical_arguments, own_arguments, caller })
}

///|
fn CallableInstancePlanner::materialize_representation_draft(
  self : CallableInstancePlanner,
  draft : CallableRepresentationDraft,
) -> Int {
  self.ensure_instance(
    self.instances[draft.source_instance].definition,
    draft.lexical_arguments,
    draft.own_arguments,
    generic_fallback=false,
    caller=if draft.caller < 0 { None } else { Some(draft.caller) },
  )
}

///|
fn CallableInstancePlanner::callable_draft_for_data_payload(
  self : CallableInstancePlanner,
  allocation : CallableAllocationFact,
  index : Int,
  fact : CallableFlowFact,
  target_type : @anf.RuntimeType,
) -> CallableRepresentationDraft? raise LoisvmLoweringError {
  guard allocation.payload_atoms.get(index)
    is Some(Function(_) | EvidenceLambda(_)) else {
    return None
  }
  self.representation_draft_for_fact(
    fact,
    target_type,
    match allocation.key.body {
      TopLevel => -1
      Instance(instance) => instance
    },
  )
}

///|
fn data_representation_groups(
  candidates : Array[DataRepresentationAllocationDemand],
  edges : Array[DataRepresentationUseEdge],
) -> Array[DataRepresentationUseGroup] {
  let groups = []
  for candidate in candidates {
    let group = data_group_for_allocation(
      candidate.allocation,
      candidate.family,
    )
    if !groups.contains(group) {
      groups.push(group)
    }
  }
  for edge in edges {
    if !groups.contains(edge.from_group) {
      groups.push(edge.from_group)
    }
    if !groups.contains(edge.to_group) {
      groups.push(edge.to_group)
    }
  }
  groups
}

///|
fn ImageLowerer::data_family_key_for_type(
  self : ImageLowerer,
  type_ : @anf.RuntimeType,
) -> DataRepresentationFamilyKey? {
  match type_ {
    Data(owner, arguments) =>
      self.specialized_data_family_key_or_none(owner, arguments)
    _ => None
  }
}

///|
fn CallableInstancePlanner::data_representation_candidate(
  self : CallableInstancePlanner,
  allocation : CallableAllocationFact,
) -> DataRepresentationAllocationDemand? raise LoisvmLoweringError {
  let substitutions = match allocation.key.body {
    TopLevel => RuntimeSubstitution::new()
    Instance(instance) => {
      guard self.instances.get(instance) is Some(candidate) &&
        !self.instance_rejects_data_representation(candidate) else {
        return None
      }
      candidate.substitution
    }
  }
  guard self.image.metadata.data_constructor_info(allocation.data_constructor)
    is Some(info) &&
    self.image.metadata.type_info(info.owner) is Some(owner) else {
    return None
  }
  for data_constructor in owner.constructors {
    guard self.image.metadata.data_constructor_info(data_constructor)
      is Some(constructor_info) &&
      constructor_info.hidden_evidence_parameters.is_empty() else {
      return None
    }
  }
  let arguments = allocation.type_arguments.map(argument => {
    substitutions.apply_argument(self.image.runtime_types, argument)
  })
  guard arguments.length() == owner.evidence_parameters.length() &&
    self.image.specialized_data_family_key_or_none(info.owner, arguments)
    is Some(family) &&
    self.image.data_representation_changes(info.owner, arguments) else {
    return None
  }
  let owner_substitutions = RuntimeSubstitution::from_arguments(
    owner.evidence_parameters,
    arguments,
  )
  for data_constructor in owner.constructors {
    guard self.image.metadata.data_constructor_info(data_constructor)
      is Some(constructor_info) else {
      return None
    }
    for payload_type in constructor_info.payload_types {
      let storage_type = owner_substitutions.apply_type(
        self.image.runtime_types,
        payload_type,
      )
      guard !(storage_type is (Callable(_, _) | Forall(_, _))) &&
        self.image.nested_data_representations_are_closed(storage_type) else {
        return None
      }
    }
  }
  Some({
    allocation: allocation.key,
    family,
    type_: Data(info.owner, arguments),
  })
}

///|
fn CallableInstancePlanner::instance_rejects_data_representation(
  self : CallableInstancePlanner,
  instance : CallableInstance,
) -> Bool {
  if instance.definition.recursive_group is Some(group) &&
    self.rejected_recursive_groups.contains(group) {
    return true
  }
  if instance.key.arguments.any(argument => {
      !is_closed_generic_argument(argument)
    }) {
    return true
  }
  self.open_functions.contains(instance.definition.function.id)
}

///|
fn data_families_in_fact(
  fact : CallableFlowFact,
  candidates : Array[DataRepresentationAllocationDemand],
) -> Array[DataRepresentationFamilyKey] {
  let families = []
  for allocation in fact.allocations {
    guard data_family_for_allocation(candidates, allocation) is Some(family) else {
      continue
    }
    if !families.contains(family) {
      families.push(family)
    }
  }
  families
}

///|
fn data_groups_in_fact(
  fact : CallableFlowFact,
  candidates : Array[DataRepresentationAllocationDemand],
) -> Array[DataRepresentationUseGroup] {
  let groups = []
  for allocation in fact.allocations {
    guard data_family_for_allocation(candidates, allocation) is Some(family) else {
      continue
    }
    let group = data_group_for_allocation(allocation, family)
    if !groups.contains(group) {
      groups.push(group)
    }
  }
  groups
}

///|
fn data_group_for_allocation(
  allocation : CallableAllocationKey,
  family : DataRepresentationFamilyKey,
) -> DataRepresentationUseGroup {
  {
    instance: match allocation.body {
      TopLevel => -1
      Instance(instance) => instance
    },
    family,
  }
}

///|
fn connect_data_groups(
  edges : Array[DataRepresentationUseEdge],
  sources : Array[DataRepresentationUseGroup],
  target : DataRepresentationUseGroup,
) -> Unit {
  for source in sources {
    let edge : DataRepresentationUseEdge = {
      from_group: source,
      to_group: target,
    }
    if source != target && !edges.contains(edge) {
      edges.push(edge)
    }
  }
}

///|
fn data_family_for_allocation(
  candidates : Array[DataRepresentationAllocationDemand],
  allocation : CallableAllocationKey,
) -> DataRepresentationFamilyKey? {
  for candidate in candidates {
    if candidate.allocation == allocation {
      return Some(candidate.family)
    }
  }
  None
}

///|
fn data_families_for_instance(
  demands : Array[DataRepresentationInstanceDemand],
  instance : Int,
) -> Array[DataRepresentationFamilyKey] {
  for demand in demands {
    if demand.instance == instance {
      return demand.families
    }
  }
  []
}

///|
fn reject_data_groups(
  rejected : Array[DataRepresentationUseGroup],
  groups : Array[DataRepresentationUseGroup],
) -> Unit {
  for group in groups {
    if !rejected.contains(group) {
      rejected.push(group)
    }
  }
}

///|
fn add_instance_data_family(
  instances : Array[DataRepresentationInstanceDemand],
  instance : Int,
  family : DataRepresentationFamilyKey,
) -> Unit {
  for demand in instances {
    if demand.instance == instance {
      if !demand.families.contains(family) {
        demand.families.push(family)
      }
      return
    }
  }
  instances.push({ instance, families: [family] })
}

///|
fn ScalarUseAnalysis::find_use(
  self : ScalarUseAnalysis,
  caller : Int,
  binding : @anf.AnfBindingId,
) -> ScalarCarrierUse? {
  for usage in self.uses {
    if usage.caller == caller && usage.binding == binding {
      return Some(usage)
    }
  }
  None
}

///|
fn reject_allocations(
  rejected : Array[CallableAllocationKey],
  allocations : Array[CallableAllocationKey],
) -> Unit {
  for allocation in allocations {
    if !rejected.contains(allocation) {
      rejected.push(allocation)
    }
  }
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
