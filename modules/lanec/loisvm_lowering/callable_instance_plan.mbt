///|
priv enum RuntimeArgumentTransform {
  Projection(@anf.RuntimeEvidenceId)
  Closed
  Expanding
} derive(Debug, Eq)

///|
priv struct PlannedRuntimeArgument {
  argument : @anf.RuntimeArgument
  transform : RuntimeArgumentTransform
} derive(Debug, Eq)

///|
priv struct CallableClosureFact {
  source_instance : Int
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
priv struct DataRepresentationAllocationCandidate {
  allocation : CallableAllocationKey
  data_constructor : @buslane.DataConId
  family : DataRepresentationFamilyCandidateKey
  type_ : @anf.RuntimeType
  hidden_arguments : Array[@anf.RuntimeArgument]
  storage_types : Array[@anf.RuntimeType]
}

///|
priv struct DataRepresentationAllocationDemand {
  allocation : CallableAllocationKey
  data_constructor : @buslane.DataConId
  family : DataRepresentationFamilyKey
  type_ : @anf.RuntimeType
  hidden_arguments : Array[@anf.RuntimeArgument]
  storage_types : Array[@anf.RuntimeType]
  component : Int
}

///|
priv struct DataRepresentationPortDemand {
  instance : Int
  binding : @anf.AnfBindingId
  family : DataRepresentationFamilyKey
  component : Int
} derive(Eq)

///|
priv struct DataRepresentationResultDemand {
  instance : Int
  family : DataRepresentationFamilyKey
  component : Int
} derive(Eq)

///|
priv struct DataRepresentationGlobalDemand {
  value : @buslane.ValueId
  family : DataRepresentationFamilyKey
  component : Int
} derive(Eq)

///|
priv struct DataRepresentationCaptureDemand {
  instance : Int
  binding : @anf.AnfBindingId
  family : DataRepresentationFamilyKey
  component : Int
} derive(Eq)

///|
priv struct CallableRepresentationPortDemand {
  instance : Int
  binding : @anf.AnfBindingId
  callable : CallableRepresentationTarget
  component : Int
}

///|
priv struct CallableRepresentationResultDemand {
  instance : Int
  callable : CallableRepresentationTarget
  component : Int
} derive(Eq)

///|
priv enum CallableRepresentationNode {
  Port(Int, @anf.AnfBindingId)
  Allocation(Int, @anf.AnfFunctionId)
} derive(Eq)

///|
priv struct CallableRepresentationNodeKey {
  owner : Int
  kind : Int
  identity : Int
} derive(Eq, Hash)

///|
priv struct CallableRepresentationConstraint {
  node : CallableRepresentationNode
  targets : Array[CallableRepresentationTarget]
}

///|
priv struct CallableRepresentationGraph {
  nodes : Array[CallableRepresentationNode]
  components : @hashmap.HashMap[CallableRepresentationNodeKey, Int]
}

///|
priv struct CallableRepresentationGraphBuilder {
  indices : @hashmap.HashMap[CallableRepresentationNodeKey, Int]
  nodes : Array[CallableRepresentationNode]
  parents : Array[Int]
}

///|
priv struct CallableRepresentationAllocationDemand {
  caller : Int
  function : @anf.AnfFunctionId
  callable : CallableRepresentationTarget
  component : Int
  generic : Bool
  worker : Bool
}

///|
priv struct CallableRepresentationPortComponent {
  instance : Int
  binding : @anf.AnfBindingId
  component : Int
  generic : Bool
}

///|
priv struct CallableRepresentationAssignmentPlan {
  allocations : Array[CallableRepresentationAllocationDemand]
  ports : Array[CallableRepresentationPortDemand]
  results : Array[CallableRepresentationResultDemand]
  components : Array[CallableRepresentationPortComponent]
}

///|
priv struct CallableRepresentationArgumentDemand {
  caller : Int
  site : @anf.AnfBindingId
  argument_index : Int
  target : Int
  parameter : @buslane.ValueId
  callable : CallableRepresentationTarget
  component : Int
}

///|
priv struct DataRepresentationCallablePayloadDemand {
  allocation : CallableAllocationKey
  payload_index : Int
  callable : CallableRepresentationTarget
  target_type : @anf.RuntimeType
  data_component : Int
  callable_component : Int
}

///|
priv struct DataRepresentationDataPayloadDemand {
  allocation : CallableAllocationKey
  payload_index : Int
  family : DataRepresentationFamilyKey
}

///|
priv struct DataRepresentationCallableArgumentDemand {
  callable : CallableRepresentationTarget
  target_type : @anf.RuntimeType
}

///|
priv struct CallableRepresentationDraft {
  source_instance : Int
  lexical_arguments : Array[@anf.RuntimeArgument]
  own_arguments : Array[PlannedRuntimeArgument]
  caller : Int
} derive(Eq)

///|
priv enum CallableRepresentationTarget {
  Semantic(Int)
  Refined(
    source_instance~ : Int,
    lexical_arguments~ : Array[@anf.RuntimeArgument],
    own_arguments~ : Array[PlannedRuntimeArgument]
  )
} derive(Debug, Eq)

///|
fn CallableRepresentationTarget::instance(
  self : CallableRepresentationTarget,
  plan : CallableInstancePlan,
) -> CallableInstance? {
  match self {
    Semantic(instance) => plan.instances.get(instance)
    Refined(source_instance~, lexical_arguments~, own_arguments~) => {
      guard plan.instances.get(source_instance) is Some(source) else {
        return None
      }
      let arguments = lexical_arguments +
        own_arguments.map(argument => argument.argument)
      let parameters = source.definition.lexical_parameters +
        source.definition.parameters
      guard parameters.length() == arguments.length() else { return None }
      let substitution = RuntimeSubstitution::new()
      for index, parameter in parameters {
        substitution.insert(parameter.id, arguments[index])
      }
      Some({
        id: source_instance,
        key: { function: source.key.function, arguments, },
        definition: source.definition,
        substitution,
        own_arguments,
        generic_fallback: false,
      })
    }
  }
}

///|
priv struct DataRepresentationCallableArgumentCandidate {
  draft : CallableRepresentationDraft
  target_type : @anf.RuntimeType
  families : Array[DataRepresentationFamilyCandidateKey]
}

///|
priv enum DataRepresentationUseNode {
  Allocation(CallableAllocationKey)
  Port(Int, @anf.AnfBindingId)
  Result(Int)
  Global(@buslane.ValueId)
  Capture(Int, @anf.AnfBindingId)
} derive(Eq)

///|
priv struct DataRepresentationUseGroup {
  node : DataRepresentationUseNode
  family : DataRepresentationFamilyCandidateKey
} derive(Eq)

///|
priv struct DataRepresentationUseEdge {
  from_group : DataRepresentationUseGroup
  to_group : DataRepresentationUseGroup
} derive(Eq)

///|
priv struct DataRepresentationDemandPlan {
  allocations : Array[DataRepresentationAllocationDemand]
  ports : Array[DataRepresentationPortDemand]
  results : Array[DataRepresentationResultDemand]
  globals : Array[DataRepresentationGlobalDemand]
  captures : Array[DataRepresentationCaptureDemand]
  data_payloads : Array[DataRepresentationDataPayloadDemand]
  callable_payloads : Array[DataRepresentationCallablePayloadDemand]
  callable_arguments : Array[DataRepresentationCallableArgumentDemand]
}

///|
fn DataRepresentationDemandPlan::empty() -> DataRepresentationDemandPlan {
  {
    allocations: [],
    ports: [],
    results: [],
    globals: [],
    captures: [],
    data_payloads: [],
    callable_payloads: [],
    callable_arguments: [],
  }
}

///|
fn ClosedAggregateScalarReplacementPlan::empty() -> ClosedAggregateScalarReplacementPlan {
  { allocations: [], parameters: [], }
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
priv struct CallableCaptureFlow {
  source_instance : Int
  target_instance : Int
  binding : @anf.AnfBindingId
} derive(Eq)

///|
priv struct CallableInstancePlan {
  instances : Array[CallableInstance]
  calls : Array[CallableCallSite]
  rejected_recursive_groups : Array[@anf.AnfRecursiveGroupId]
}

///|
fn CallableInstancePlan::empty() -> CallableInstancePlan {
  { instances: [], calls: [], rejected_recursive_groups: [], }
}

///|
priv struct PhysicalRepresentationDemandPlan {
  scalar_replacements : ClosedAggregateScalarReplacementPlan
  data_representations : DataRepresentationDemandPlan
  callable_allocations : Array[CallableRepresentationAllocationDemand]
  callable_ports : Array[CallableRepresentationPortDemand]
  callable_results : Array[CallableRepresentationResultDemand]
  callable_arguments : Array[CallableRepresentationArgumentDemand]
  callable_components : Array[CallableRepresentationPortComponent]
  callable_materializations : Array[(Int, @anf.AnfBindingId)]
}

///|
fn PhysicalRepresentationDemandPlan::empty() -> PhysicalRepresentationDemandPlan {
  {
    scalar_replacements: ClosedAggregateScalarReplacementPlan::empty(),
    data_representations: DataRepresentationDemandPlan::empty(),
    callable_allocations: [],
    callable_ports: [],
    callable_results: [],
    callable_arguments: [],
    callable_components: [],
    callable_materializations: [],
  }
}

///|
fn PhysicalRepresentationDemandPlan::callable_port_requires_materialization(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
) -> Bool {
  for demand in self.callable_materializations {
    if instances.contains(demand.0) && demand.1 == binding {
      return true
    }
  }
  false
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_excluding(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
  excluded_components : Array[Int],
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
    let mut found : DataRepresentationFamilyKey? = None
    for demand in self.data_representations.allocations {
      if demand.allocation == allocation &&
        !excluded_components.contains(demand.component) {
        found = Some(demand.family)
        break
      }
    }
    guard found is Some(family) else { return None }
    match selected {
      None => selected = Some(family)
      Some(existing) if existing == family => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_port(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  binding : @anf.AnfBindingId,
) -> DataRepresentationFamilyKey? {
  self.data_family_at_port_excluding(callers, binding, [])
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_port_excluding(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  binding : @anf.AnfBindingId,
  excluded_components : Array[Int],
) -> DataRepresentationFamilyKey? {
  guard !callers.is_empty() else { return None }
  let mut selected : DataRepresentationFamilyKey? = None
  for caller in callers {
    let mut found : DataRepresentationFamilyKey? = None
    for port in self.data_representations.ports {
      if port.instance == caller &&
        port.binding == binding &&
        !excluded_components.contains(port.component) {
        match found {
          None => found = Some(port.family)
          Some(existing) if existing == port.family => ()
          Some(_) => return None
        }
      }
    }
    guard found is Some(family) else { return None }
    match selected {
      None => selected = Some(family)
      Some(existing) if existing == family => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::data_boundary_components(
  self : PhysicalRepresentationDemandPlan,
  instance : Int,
  parameters : Array[@buslane.ValueId],
) -> Array[Int] {
  let components = []
  for port in self.data_representations.ports {
    if port.instance == instance &&
      port.binding is Value(parameter) &&
      parameters.contains(parameter) &&
      !components.contains(port.component) {
      components.push(port.component)
    }
  }
  for result in self.data_representations.results {
    if result.instance == instance && !components.contains(result.component) {
      components.push(result.component)
    }
  }
  for capture in self.data_representations.captures {
    if capture.instance == instance && !components.contains(capture.component) {
      components.push(capture.component)
    }
  }
  components
}

///|
fn PhysicalRepresentationDemandPlan::data_components_for_instance(
  self : PhysicalRepresentationDemandPlan,
  instance : Int,
) -> Array[Int] {
  let components = []
  for allocation in self.data_representations.allocations {
    if allocation.allocation.body == Instance(instance) &&
      !components.contains(allocation.component) {
      components.push(allocation.component)
    }
  }
  for port in self.data_representations.ports {
    if port.instance == instance && !components.contains(port.component) {
      components.push(port.component)
    }
  }
  for result in self.data_representations.results {
    if result.instance == instance && !components.contains(result.component) {
      components.push(result.component)
    }
  }
  for capture in self.data_representations.captures {
    if capture.instance == instance && !components.contains(capture.component) {
      components.push(capture.component)
    }
  }
  components
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_result(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
) -> DataRepresentationFamilyKey? {
  self.data_family_at_result_excluding(callers, [])
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_result_excluding(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  excluded_components : Array[Int],
) -> DataRepresentationFamilyKey? {
  guard !callers.is_empty() else { return None }
  let mut selected : DataRepresentationFamilyKey? = None
  for caller in callers {
    let mut found : DataRepresentationFamilyKey? = None
    for result in self.data_representations.results {
      if result.instance == caller &&
        !excluded_components.contains(result.component) {
        match found {
          None => found = Some(result.family)
          Some(existing) if existing == result.family => ()
          Some(_) => return None
        }
      }
    }
    guard found is Some(family) else { return None }
    match selected {
      None => selected = Some(family)
      Some(existing) if existing == family => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_global(
  self : PhysicalRepresentationDemandPlan,
  value : @buslane.ValueId,
) -> DataRepresentationFamilyKey? {
  let mut selected : DataRepresentationFamilyKey? = None
  for global in self.data_representations.globals {
    guard global.value == value else { continue }
    match selected {
      None => selected = Some(global.family)
      Some(existing) if existing == global.family => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_capture(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
) -> DataRepresentationFamilyKey? {
  self.data_family_at_capture_excluding(instances, binding, [])
}

///|
fn PhysicalRepresentationDemandPlan::data_family_at_capture_excluding(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
  excluded_components : Array[Int],
) -> DataRepresentationFamilyKey? {
  guard !instances.is_empty() else { return None }
  let mut selected : DataRepresentationFamilyKey? = None
  for instance in instances {
    let mut found : DataRepresentationFamilyKey? = None
    for capture in self.data_representations.captures {
      if capture.instance == instance &&
        capture.binding == binding &&
        !excluded_components.contains(capture.component) {
        match found {
          None => found = Some(capture.family)
          Some(existing) if existing == capture.family => ()
          Some(_) => return None
        }
      }
    }
    match found {
      None => ()
      Some(family) =>
        match selected {
          None => selected = Some(family)
          Some(existing) if existing == family => ()
          Some(_) => return None
        }
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_port(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
) -> CallableRepresentationTarget? {
  self.callable_instance_at_port_excluding(instances, binding, [])
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_allocation(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  function : @anf.AnfFunctionId,
) -> CallableRepresentationTarget? {
  guard !callers.is_empty() else { return None }
  let mut selected : CallableRepresentationTarget? = None
  for caller in callers {
    let mut found : CallableRepresentationTarget? = None
    for allocation in self.callable_allocations {
      if allocation.caller == caller && allocation.function == function {
        match found {
          None => found = Some(allocation.callable)
          Some(existing) if existing == allocation.callable => ()
          Some(_) => return None
        }
      }
    }
    guard found is Some(callable) else { return None }
    match selected {
      None => selected = Some(callable)
      Some(existing) if existing == callable => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::callable_allocation_assignments(
  self : PhysicalRepresentationDemandPlan,
  caller : Int,
) -> Array[(@anf.AnfFunctionId, CallableRepresentationTarget)] {
  self.callable_allocations.filter_map(allocation => {
    if allocation.caller == caller && allocation.worker {
      Some((allocation.function, allocation.callable))
    } else {
      None
    }
  })
}

///|
fn PhysicalRepresentationDemandPlan::callable_allocation_uses_worker(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  function : @anf.AnfFunctionId,
  excluded_components : Array[Int],
) -> Bool {
  guard !callers.is_empty() else { return false }
  for caller in callers {
    let mut found = false
    for allocation in self.callable_allocations {
      guard allocation.caller == caller && allocation.function == function else {
        continue
      }
      found = true
      if !allocation.worker ||
        excluded_components.contains(allocation.component) {
        return false
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_port_excluding(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
  excluded_components : Array[Int],
) -> CallableRepresentationTarget? {
  guard !instances.is_empty() else { return None }
  let mut selected : CallableRepresentationTarget? = None
  for instance in instances {
    let mut found : CallableRepresentationTarget? = None
    for port in self.callable_ports {
      if port.instance == instance &&
        port.binding == binding &&
        !excluded_components.contains(port.component) {
        match found {
          None => found = Some(port.callable)
          Some(existing) if existing == port.callable => ()
          Some(_) => return None
        }
      }
    }
    guard found is Some(callable) else { return None }
    match selected {
      None => selected = Some(callable)
      Some(existing) if existing == callable => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_result(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
) -> CallableRepresentationTarget? {
  self.callable_instance_at_result_excluding(instances, [])
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_result_excluding(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  excluded_components : Array[Int],
) -> CallableRepresentationTarget? {
  guard !instances.is_empty() else { return None }
  let mut selected : CallableRepresentationTarget? = None
  for instance in instances {
    let mut found : CallableRepresentationTarget? = None
    for result in self.callable_results {
      if result.instance == instance &&
        !excluded_components.contains(result.component) {
        match found {
          None => found = Some(result.callable)
          Some(existing) if existing == result.callable => ()
          Some(_) => return None
        }
      }
    }
    guard found is Some(callable) else { return None }
    match selected {
      None => selected = Some(callable)
      Some(existing) if existing == callable => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::callable_port_assignments(
  self : PhysicalRepresentationDemandPlan,
  instance : Int,
) -> Array[(@anf.AnfBindingId, CallableRepresentationTarget)] {
  let assignments : Array[(@anf.AnfBindingId, CallableRepresentationTarget)] = []
  for port in self.callable_ports {
    if port.instance == instance &&
      !self.callable_component_requires_generic(port.component) &&
      !assignments.any(existing => {
        existing.0 == port.binding && existing.1 == port.callable
      }) {
      assignments.push((port.binding, port.callable))
    }
  }
  assignments
}

///|
fn PhysicalRepresentationDemandPlan::callable_argument_assignments(
  self : PhysicalRepresentationDemandPlan,
  caller : Int,
) -> Array[(@anf.AnfBindingId, Int, CallableRepresentationTarget)] {
  let assignments : Array[
    (@anf.AnfBindingId, Int, CallableRepresentationTarget),
  ] = []
  for argument in self.callable_arguments {
    if argument.caller == caller &&
      !self.callable_component_requires_generic(argument.component) &&
      !assignments.any(existing => {
        existing.0 == argument.site &&
        existing.1 == argument.argument_index &&
        existing.2 == argument.callable
      }) {
      assignments.push(
        (argument.site, argument.argument_index, argument.callable),
      )
    }
  }
  assignments
}

///|
fn PhysicalRepresentationDemandPlan::data_port_assignments(
  self : PhysicalRepresentationDemandPlan,
  instance : Int,
) -> Array[(@anf.AnfBindingId, DataRepresentationFamilyKey)] {
  let assignments : Array[(@anf.AnfBindingId, DataRepresentationFamilyKey)] = []
  for port in self.data_representations.ports {
    guard port.instance == instance else { continue }
    let mut duplicate = false
    for assignment in assignments {
      let (binding, family) = assignment
      if binding == port.binding && family == port.family {
        duplicate = true
        break
      }
    }
    if !duplicate {
      assignments.push((port.binding, port.family))
    }
  }
  assignments
}

///|
fn PhysicalRepresentationDemandPlan::has_data_capture_assignment(
  self : PhysicalRepresentationDemandPlan,
  instance : Int,
) -> Bool {
  self.data_representations.captures.any(capture => capture.instance == instance)
}

///|
fn PhysicalRepresentationDemandPlan::data_callable_payload_instance_excluding(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
  payload_index : Int,
  excluded_components : Array[Int],
) -> CallableRepresentationTarget? {
  guard !callers.is_empty() else { return None }
  let mut selected : CallableRepresentationTarget? = None
  for caller in callers {
    let key : CallableAllocationKey = {
      body: if caller < 0 {
        TopLevel
      } else {
        Instance(caller)
      },
      site,
    }
    let mut found : CallableRepresentationTarget? = None
    for demand in self.data_representations.callable_payloads {
      if demand.allocation == key &&
        demand.payload_index == payload_index &&
        !excluded_components.contains(demand.data_component) {
        found = Some(demand.callable)
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
fn PhysicalRepresentationDemandPlan::callable_payload_target_type(
  self : PhysicalRepresentationDemandPlan,
  callable : CallableRepresentationTarget,
) -> @anf.RuntimeType? {
  let mut selected : @anf.RuntimeType? = None
  for demand in self.data_representations.callable_payloads {
    guard demand.callable == callable else { continue }
    match selected {
      None => selected = Some(demand.target_type)
      Some(existing) if existing == demand.target_type => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_argument(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
  argument_index : Int,
) -> CallableRepresentationTarget? {
  self.callable_instance_at_argument_excluding(callers, site, argument_index, [])
}

///|
fn PhysicalRepresentationDemandPlan::callable_instance_at_argument_excluding(
  self : PhysicalRepresentationDemandPlan,
  callers : Array[Int],
  site : @anf.AnfBindingId,
  argument_index : Int,
  excluded_components : Array[Int],
) -> CallableRepresentationTarget? {
  guard !callers.is_empty() else { return None }
  let mut selected : CallableRepresentationTarget? = None
  for caller in callers {
    let mut found : CallableRepresentationTarget? = None
    for demand in self.callable_arguments {
      if demand.caller == caller &&
        demand.site == site &&
        demand.argument_index == argument_index &&
        !excluded_components.contains(demand.component) {
        found = Some(demand.callable)
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
fn PhysicalRepresentationDemandPlan::callable_boundary_components(
  self : PhysicalRepresentationDemandPlan,
  instance : Int,
  parameters : Array[@buslane.ValueId],
  captures : Array[@anf.AnfCapture],
) -> Array[Int] {
  let components = []
  for port in self.callable_components {
    guard port.instance == instance else { continue }
    let boundary = match port.binding {
      Value(value) =>
        parameters.contains(value) ||
        captures.contains(@anf.AnfCapture::Value(value))
      Temp(temp) => captures.contains(@anf.AnfCapture::Temp(temp))
    }
    if boundary && !components.contains(port.component) {
      components.push(port.component)
    }
  }
  for result in self.callable_results {
    if result.instance == instance && !components.contains(result.component) {
      components.push(result.component)
    }
  }
  components
}

///|
fn PhysicalRepresentationDemandPlan::callable_representation_target_type(
  self : PhysicalRepresentationDemandPlan,
  callable : CallableRepresentationTarget,
) -> @anf.RuntimeType? {
  let mut selected = self.callable_payload_target_type(callable)
  for demand in self.data_representations.callable_arguments {
    guard demand.callable == callable else { continue }
    match selected {
      None => selected = Some(demand.target_type)
      Some(existing) if existing == demand.target_type => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn PhysicalRepresentationDemandPlan::demands_callable_instance(
  self : PhysicalRepresentationDemandPlan,
  callable : CallableRepresentationTarget,
) -> Bool {
  self.callable_allocations.any(demand => demand.callable == callable) ||
  self.callable_ports.any(demand => demand.callable == callable) ||
  self.callable_results.any(demand => demand.callable == callable) ||
  self.callable_arguments.any(demand => demand.callable == callable) ||
  self.data_representations.callable_payloads.any(demand => {
    demand.callable == callable
  }) ||
  self.data_representations.callable_arguments.any(demand => {
    demand.callable == callable
  })
}

///|
fn PhysicalRepresentationDemandPlan::refined_callable_targets(
  self : PhysicalRepresentationDemandPlan,
) -> Array[CallableRepresentationTarget] {
  let targets : Array[CallableRepresentationTarget] = []
  for demand in self.callable_allocations {
    if demand.callable is Refined(..) && !targets.contains(demand.callable) {
      targets.push(demand.callable)
    }
  }
  for demand in self.callable_ports {
    if demand.callable is Refined(..) && !targets.contains(demand.callable) {
      targets.push(demand.callable)
    }
  }
  for demand in self.callable_results {
    if demand.callable is Refined(..) && !targets.contains(demand.callable) {
      targets.push(demand.callable)
    }
  }
  for demand in self.callable_arguments {
    if demand.callable is Refined(..) && !targets.contains(demand.callable) {
      targets.push(demand.callable)
    }
  }
  for demand in self.data_representations.callable_payloads {
    if demand.callable is Refined(..) && !targets.contains(demand.callable) {
      targets.push(demand.callable)
    }
  }
  for demand in self.data_representations.callable_arguments {
    if demand.callable is Refined(..) && !targets.contains(demand.callable) {
      targets.push(demand.callable)
    }
  }
  targets
}

///|
fn PhysicalRepresentationDemandPlan::callable_components_for_target(
  self : PhysicalRepresentationDemandPlan,
  callable : CallableRepresentationTarget,
) -> Array[Int] {
  let components = []
  for demand in self.callable_allocations {
    if demand.callable == callable &&
      !self.callable_component_requires_generic(demand.component) &&
      !components.contains(demand.component) {
      components.push(demand.component)
    }
  }
  for demand in self.callable_ports {
    if demand.callable == callable &&
      !self.callable_component_requires_generic(demand.component) &&
      !components.contains(demand.component) {
      components.push(demand.component)
    }
  }
  for demand in self.callable_results {
    if demand.callable == callable &&
      !self.callable_component_requires_generic(demand.component) &&
      !components.contains(demand.component) {
      components.push(demand.component)
    }
  }
  for demand in self.callable_arguments {
    if demand.callable == callable &&
      !self.callable_component_requires_generic(demand.component) &&
      !components.contains(demand.component) {
      components.push(demand.component)
    }
  }
  for demand in self.data_representations.callable_payloads {
    if demand.callable == callable &&
      demand.callable_component >= 0 &&
      !self.callable_component_requires_generic(demand.callable_component) &&
      !components.contains(demand.callable_component) {
      components.push(demand.callable_component)
    }
  }
  components
}

///|
fn PhysicalRepresentationDemandPlan::callable_component_requires_generic(
  self : PhysicalRepresentationDemandPlan,
  component : Int,
) -> Bool {
  if component < 0 {
    return false
  }
  let mut found = false
  for allocation in self.callable_allocations {
    guard allocation.component == component else { continue }
    found = true
    if allocation.generic {
      return true
    }
  }
  for port in self.callable_components {
    guard port.component == component else { continue }
    found = true
    if port.generic {
      return true
    }
  }
  !found
}

///|
fn PhysicalRepresentationDemandPlan::callable_port_uses_worker(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
  excluded_components : Array[Int],
) -> Bool {
  guard !instances.is_empty() else { return false }
  for instance in instances {
    let mut found = false
    for port in self.callable_ports {
      guard port.instance == instance && port.binding == binding else {
        continue
      }
      found = true
      if excluded_components.contains(port.component) ||
        self.callable_component_requires_generic(port.component) {
        return false
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn PhysicalRepresentationDemandPlan::worker_callable_at_port(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  binding : @anf.AnfBindingId,
) -> CallableRepresentationTarget? {
  guard self.callable_port_uses_worker(instances, binding, []) else {
    return None
  }
  for instance in instances {
    for demand in self.callable_arguments {
      guard demand.target == instance && binding == Value(demand.parameter) else {
        continue
      }
      if self.callable_component_requires_generic(demand.component) {
        return None
      }
    }
  }
  self.callable_instance_at_port(instances, binding)
}

///|
fn PhysicalRepresentationDemandPlan::callable_result_uses_worker(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
  excluded_components : Array[Int],
) -> Bool {
  guard !instances.is_empty() else { return false }
  for instance in instances {
    let mut found = false
    for result in self.callable_results {
      guard result.instance == instance else { continue }
      found = true
      if excluded_components.contains(result.component) ||
        self.callable_component_requires_generic(result.component) {
        return false
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn PhysicalRepresentationDemandPlan::worker_callable_at_result(
  self : PhysicalRepresentationDemandPlan,
  instances : Array[Int],
) -> CallableRepresentationTarget? {
  guard self.callable_result_uses_worker(instances, []) else { return None }
  self.callable_instance_at_result(instances)
}

///|
fn PhysicalRepresentationDemandPlan::scalar_allocation_contract(
  self : PhysicalRepresentationDemandPlan,
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
fn PhysicalRepresentationDemandPlan::scalar_parameter_contract(
  self : PhysicalRepresentationDemandPlan,
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
    arguments.push({ type_expression, evidence: Parameter(parameter.id), })
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
  capture_flows : Array[CallableCaptureFlow]
  open_functions : Array[@anf.AnfFunctionId]
  rejected_recursive_groups : Array[@anf.AnfRecursiveGroupId]
  mut changed : Bool
}

///|
fn ImageLowerer::plan_callable_instances(
  self : ImageLowerer,
  program : @anf.AnfProgram,
) -> (CallableInstancePlan, PhysicalRepresentationDemandPlan) raise LoisvmLoweringError {
  let planner : CallableInstancePlanner = {
    image: self,
    program,
    catalog: self.callable_catalog,
    instances: [],
    bindings: [],
    results: [],
    allocations: [],
    calls: [],
    capture_flows: [],
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
    let representation_demands = planner.plan_aggregate_representations()
    if planner.changed || planner.instances.length() != count {
      continue ()
    }
    break (
      {
        instances: planner.instances,
        calls: planner.calls,
        rejected_recursive_groups: planner.rejected_recursive_groups,
      },
      representation_demands,
    )
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
    let specialized_parameters = self.specialized_lexical_parameters(instance)
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
          specialized_parameters,
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
      let specialized_parameters = self.specialized_lexical_parameters(instance)
      CallableCaptureInput::{
        instances: [instance.id],
        definition: instance.definition,
        function_type,
        substitutions: instance.substitution,
        specialized_parameters,
      }
    })
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
            specialized_parameters: inputs[index].specialized_parameters,
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
fn ImageLowerer::specialized_lexical_parameters(
  self : ImageLowerer,
  instance : CallableInstance,
) -> Array[@anf.RuntimeEvidenceId] raise LoisvmLoweringError {
  instance.definition.lexical_parameters.filter_map(parameter => {
    match instance.substitution.argument(parameter.id) {
      Some(argument) => {
        let resolved = instance.substitution.apply_argument(
          self.runtime_types,
          argument,
        )
        if self.generic_argument_is_closed(resolved) {
          Some(parameter.id)
        } else {
          None
        }
      }
      _ => None
    }
  })
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
  { callables: [], allocations: [], open: false, }
}

///|
fn CallableFlowFact::open() -> CallableFlowFact {
  { callables: [], allocations: [], open: true, }
}

///|
fn CallableFlowFact::callable(
  callable : CallableClosureFact,
) -> CallableFlowFact {
  { callables: [callable], allocations: [], open: false, }
}

///|
fn CallableFlowFact::allocation(
  allocation : CallableAllocationKey,
) -> CallableFlowFact {
  { callables: [], allocations: [allocation], open: false, }
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
  { callables, allocations, open: left.open || right.open, }
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
        self.invocation_callee_fact(callee, caller),
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
fn CallableInstancePlanner::invocation_callee_fact(
  self : CallableInstancePlanner,
  callee : @anf.AnfAtom,
  caller : Int,
) -> CallableFlowFact raise LoisvmLoweringError {
  let fact = self.eval_atom(callee, caller)
  guard fact == CallableFlowFact::empty() else { return fact }
  let binding = match callee {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Function(_) | EvidenceLambda(_) | Literal(_) => None
  }
  guard binding is Some(binding) &&
    self.runtime_type_at(caller, binding) is Some(Callable(_, _) | Forall(_, _)) else {
    return fact
  }
  CallableFlowFact::open()
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
  let instance = self.ensure_instance(
    definition,
    lexical_arguments,
    self.identity_planned_arguments(definition.parameters),
    generic_fallback=true,
    caller=if caller < 0 { None } else { Some(caller) },
  )
  for capture in definition.captures {
    let binding = match capture {
      Value(value) => @anf.AnfBindingId::Value(value)
      Temp(temp) => @anf.AnfBindingId::Temp(temp)
    }
    self.update_binding(
      instance,
      binding,
      self.captured_binding_fact(caller, binding),
    )
  }
  CallableFlowFact::callable({
    source_instance: instance,
    function,
    lexical_arguments,
    applied_arguments: [],
  })
}

///|
fn CallableInstancePlanner::captured_binding_fact(
  self : CallableInstancePlanner,
  caller : Int,
  binding : @anf.AnfBindingId,
) -> CallableFlowFact {
  let captured = self.binding_fact(caller, binding)
  match binding {
    Value(value) =>
      merge_callable_flow_fact(captured, self.binding_fact(-1, Value(value)))
    Temp(_) => captured
  }
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
    for capture in definition.captures {
      let binding = match capture {
        Value(value) => @anf.AnfBindingId::Value(value)
        Temp(temp) => @anf.AnfBindingId::Temp(temp)
      }
      self.update_binding(
        instance,
        binding,
        self.binding_fact(callable.source_instance, binding),
      )
      self.record_capture_flow(callable.source_instance, instance, binding)
    }
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
  { argument, transform, }
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
  { type_expression, evidence: Parameter(parameter.id), }
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
    self.bindings.push({ caller, binding, fact, })
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
  Join(Int, @anf.AnfBindingId)
  ExactCall(Int, Int, @anf.AnfBindingId)
  ClosedCall(Array[Int], Int, @anf.AnfBindingId)
  Invoke
  Construct(CallableAllocationKey, Int)
  Match(scalar_projectable~ : Bool)
  Return(Int)
  Global(@buslane.ValueId)
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
priv struct ScalarCallableAllocationUse {
  caller : Int
  function : @anf.AnfFunctionId
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
priv struct ScalarInvocationObservation {
  caller : Int
  site : @anf.AnfBindingId
  callee : @anf.AnfAtom
  targets : Array[Int]
}

///|
priv struct CallableStorageObservation {
  caller : Int
  binding : @anf.AnfBindingId
  carrier : (Int, @anf.AnfBindingId)?
  sources : Array[(CallableAllocationKey, Int)]
  open : Bool
}

///|
priv struct ScalarUseAnalysis {
  planner : CallableInstancePlanner
  uses : Array[ScalarCarrierUse]
  callable_allocations : Array[ScalarCallableAllocationUse]
  calls : Array[ScalarCallObservation]
  invocations : Array[ScalarInvocationObservation]
  callable_storage : Array[CallableStorageObservation]
}

///|
fn CallableInstancePlanner::plan_aggregate_representations(
  self : CallableInstancePlanner,
) -> PhysicalRepresentationDemandPlan raise LoisvmLoweringError {
  let analysis : ScalarUseAnalysis = {
    planner: self,
    uses: [],
    callable_allocations: [],
    calls: [],
    invocations: [],
    callable_storage: [],
  }
  analysis.collect()
  let callable_graph = analysis.callable_graph()
  let scalar = analysis.finish()
  let mut data_representations = analysis.finish_data_representations(
    scalar, callable_graph,
  )
  let forced_generic_callable_components : Array[Int] = []
  let mut callable_assignments = analysis.finish_callable_assignments(
    data_representations, callable_graph, forced_generic_callable_components,
  )
  while true {
    let mut changed = false
    for allocation in callable_assignments.allocations {
      let instance_id = match allocation.callable {
        Semantic(instance) | Refined(source_instance=instance, ..) => instance
      }
      guard allocation.generic &&
        self.instances.get(instance_id) is Some(instance) else {
        continue
      }
      for capture in instance.definition.captures {
        let binding = match capture {
          Value(value) => @anf.AnfBindingId::Value(value)
          Temp(temp) => @anf.AnfBindingId::Temp(temp)
        }
        for component in callable_assignments.components {
          if component.instance == allocation.caller &&
            component.binding == binding &&
            !forced_generic_callable_components.contains(component.component) {
            forced_generic_callable_components.push(component.component)
            changed = true
          }
        }
      }
    }
    if changed {
      callable_assignments = analysis.finish_callable_assignments(
        data_representations, callable_graph, forced_generic_callable_components,
      )
      continue
    }
    let rejected = analysis.data_components_rejected_by_generic_callables(
      data_representations, callable_assignments, callable_graph,
    )
    if rejected.is_empty() {
      break
    }
    data_representations = data_representations.excluding_components(rejected)
    callable_assignments = analysis.finish_callable_assignments(
      data_representations, callable_graph, forced_generic_callable_components,
    )
  }
  let callable_arguments = analysis.resolved_callable_arguments(
    callable_assignments,
  )
  let callable_materializations = analysis.callable_materialization_ports()
  {
    scalar_replacements: scalar,
    data_representations,
    callable_allocations: callable_assignments.allocations,
    callable_ports: callable_assignments.ports,
    callable_results: callable_assignments.results,
    callable_arguments,
    callable_components: callable_assignments.components,
    callable_materializations,
  }
}

///|
fn ScalarUseAnalysis::callable_materialization_ports(
  self : ScalarUseAnalysis,
) -> Array[(Int, @anf.AnfBindingId)] raise LoisvmLoweringError {
  let demands : Array[(Int, @anf.AnfBindingId)] = []
  for usage in self.uses {
    guard self.planner.runtime_type_at(usage.caller, usage.binding)
      is Some(Callable(_, _) | Forall(_, _)) else {
      continue
    }
    if usage.consumers.any(callable_consumer_materializes_value) {
      demands.push((usage.caller, usage.binding))
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for usage in self.uses {
      guard !demands.contains((usage.caller, usage.binding)) else { continue }
      if usage.consumers.any(consumer => {
          match consumer {
            Alias(caller, binding) | Join(caller, binding) =>
              demands.contains((caller, binding))
            _ => false
          }
        }) {
        demands.push((usage.caller, usage.binding))
        changed = true
      }
    }
  }
  demands
}

///|
fn callable_consumer_materializes_value(
  consumer : ScalarCarrierConsumer,
) -> Bool {
  match consumer {
    Alias(_, _) | Join(_, _) | Invoke => false
    ExactCall(_, _, _)
    | ClosedCall(_, _, _)
    | Construct(_, _)
    | Match(_)
    | Return(_)
    | Global(_)
    | Capture(_)
    | UnsupportedArgument => true
  }
}

///|
fn DataRepresentationDemandPlan::excluding_components(
  self : DataRepresentationDemandPlan,
  rejected : Array[Int],
) -> DataRepresentationDemandPlan {
  {
    allocations: self.allocations.filter(demand => {
      !rejected.contains(demand.component)
    }),
    ports: self.ports.filter(demand => !rejected.contains(demand.component)),
    results: self.results.filter(demand => !rejected.contains(demand.component)),
    globals: self.globals.filter(demand => !rejected.contains(demand.component)),
    captures: self.captures.filter(demand => {
      !rejected.contains(demand.component)
    }),
    data_payloads: self.data_payloads.filter(demand => {
      self.allocations.any(allocation => {
        allocation.allocation == demand.allocation &&
        !rejected.contains(allocation.component)
      })
    }),
    callable_payloads: self.callable_payloads.filter(demand => {
      !rejected.contains(demand.data_component)
    }),
    callable_arguments: self.callable_arguments,
  }
}

///|
fn ScalarUseAnalysis::data_components_rejected_by_generic_callables(
  self : ScalarUseAnalysis,
  data : DataRepresentationDemandPlan,
  callables : CallableRepresentationAssignmentPlan,
  callable_graph : CallableRepresentationGraph,
) -> Array[Int] raise LoisvmLoweringError {
  let rejected = self.data_components_rejected_by_generic_invocations(
    data, callables,
  )
  for payload in data.callable_payloads {
    if callable_assignment_component_requires_generic(
        callables,
        payload.callable_component,
      ) &&
      !rejected.contains(payload.data_component) {
      rejected.push(payload.data_component)
    }
  }
  for allocation in callables.allocations {
    guard allocation.generic else { continue }
    let instance = match allocation.callable {
      Semantic(instance) | Refined(source_instance=instance, ..) => instance
    }
    for capture in data.captures {
      if capture.instance == instance && !rejected.contains(capture.component) {
        rejected.push(capture.component)
      }
    }
  }
  for storage in self.callable_storage {
    guard self.planner.runtime_type_at(storage.caller, storage.binding)
      is Some(Callable(_, _) | Forall(_, _)) else {
      continue
    }
    let component = callable_graph.component(
      Port(storage.caller, storage.binding),
    )
    guard callable_assignment_component_requires_generic(callables, component) else {
      continue
    }
    if storage.carrier is Some(carrier) {
      for port in data.ports {
        if port.instance == carrier.0 &&
          port.binding == carrier.1 &&
          !rejected.contains(port.component) {
          rejected.push(port.component)
        }
      }
    }
    for source in storage.sources {
      for allocation in data.allocations {
        if allocation.allocation == source.0 &&
          !rejected.contains(allocation.component) {
          rejected.push(allocation.component)
        }
      }
    }
  }
  rejected
}

///|
fn ScalarUseAnalysis::data_components_rejected_by_generic_invocations(
  self : ScalarUseAnalysis,
  data : DataRepresentationDemandPlan,
  callables : CallableRepresentationAssignmentPlan,
) -> Array[Int] {
  let rejected = []
  for invocation in self.invocations {
    guard self.callable_invocation_requires_generic(invocation, callables) else {
      continue
    }
    for port in data.ports {
      if port.instance == invocation.caller &&
        port.binding == invocation.site &&
        !rejected.contains(port.component) {
        rejected.push(port.component)
      }
    }
    if self.find_use(invocation.caller, invocation.site) is Some(result) {
      for allocation in data.allocations {
        if result.fact.allocations.contains(allocation.allocation) &&
          !rejected.contains(allocation.component) {
          rejected.push(allocation.component)
        }
      }
    }
    for usage in self.uses {
      guard usage.caller == invocation.caller &&
        usage.consumers.any(consumer => {
          match consumer {
            ExactCall(target, _, site) =>
              invocation.targets.contains(target) && site == invocation.site
            ClosedCall(_, _, site) => site == invocation.site
            _ => false
          }
        }) else {
        continue
      }
      for port in data.ports {
        if port.instance == usage.caller &&
          port.binding == usage.binding &&
          !rejected.contains(port.component) {
          rejected.push(port.component)
        }
      }
      for allocation in data.allocations {
        if usage.fact.allocations.contains(allocation.allocation) &&
          !rejected.contains(allocation.component) {
          rejected.push(allocation.component)
        }
      }
    }
    for target in invocation.targets {
      for result in data.results {
        if result.instance == target && !rejected.contains(result.component) {
          rejected.push(result.component)
        }
      }
    }
  }
  rejected
}

///|
fn ScalarUseAnalysis::callable_invocation_requires_generic(
  self : ScalarUseAnalysis,
  invocation : ScalarInvocationObservation,
  assignments : CallableRepresentationAssignmentPlan,
) -> Bool {
  if invocation.targets.is_empty() {
    return true
  }
  guard self.callable_node_for_atom(invocation.callee, invocation.caller)
    is Some(node) else {
    return true
  }
  if node is Port(_, _) &&
    invocation.targets.any(target => {
      self.planner.instances
      .get(target)
      .map(instance => !instance.definition.captures.is_empty())
      .unwrap_or(true)
    }) {
    return true
  }
  callable_assignment_requires_generic(assignments, node)
}

///|
fn ScalarUseAnalysis::finish_callable_assignments(
  self : ScalarUseAnalysis,
  data_representations : DataRepresentationDemandPlan,
  callable_graph : CallableRepresentationGraph,
  forced_generic_components : Array[Int],
) -> CallableRepresentationAssignmentPlan raise LoisvmLoweringError {
  let constraints : Array[CallableRepresentationConstraint] = []
  for observation in self.calls {
    guard self.planner.instances.get(observation.target) is Some(instance) &&
      instance.definition.function.parameters.get(observation.parameter_index)
      is Some(parameter) &&
      self.planner.runtime_type_at(observation.target, Value(parameter))
      is Some(target_type) &&
      target_type is (Callable(_, _) | Forall(_, _)) &&
      self.planner.representation_draft_for_fact(
        observation.fact,
        target_type,
        observation.caller,
      )
      is Some(draft) &&
      self.planner.callable_draft_closes_representation(draft) &&
      self.callable_node_for_atom(observation.atom, observation.caller)
      is Some(node) else {
      continue
    }
    let target = callable_representation_target(draft)
    ignore(constrain_callable_node(constraints, callable_graph, node, target))
    ignore(
      constrain_callable_node(
        constraints,
        callable_graph,
        Port(observation.target, Value(parameter)),
        target,
      ),
    )
  }
  for invocation in self.invocations {
    guard self.callable_node_for_atom(invocation.callee, invocation.caller)
      is Some(node) else {
      continue
    }
    for target in invocation.targets {
      if !self.planner.instances[target].generic_fallback {
        ignore(
          constrain_callable_node(
            constraints,
            callable_graph,
            node,
            CallableRepresentationTarget::Semantic(target),
          ),
        )
      }
    }
  }
  for demand in data_representations.callable_payloads {
    guard self.planner.allocation(demand.allocation) is Some(allocation) &&
      allocation.payload_atoms.get(demand.payload_index) is Some(atom) &&
      self.callable_node_for_atom(
        atom,
        match demand.allocation.body {
          TopLevel => -1
          Instance(instance) => instance
        },
      )
      is Some(node) else {
      continue
    }
    ignore(
      constrain_callable_node(
        constraints,
        callable_graph,
        node,
        demand.callable,
      ),
    )
  }
  for usage in self.uses {
    guard !usage.fact.open &&
      self.planner.callable_instance_for_fact(usage.fact) is Some(callable) else {
      continue
    }
    ignore(
      constrain_callable_node(
        constraints,
        callable_graph,
        Port(usage.caller, usage.binding),
        CallableRepresentationTarget::Semantic(callable),
      ),
    )
  }
  for allocation in self.callable_allocations {
    guard !allocation.fact.open &&
      self.planner.callable_instance_for_fact(allocation.fact) is Some(callable) else {
      continue
    }
    ignore(
      constrain_callable_node(
        constraints,
        callable_graph,
        Allocation(allocation.caller, allocation.function),
        CallableRepresentationTarget::Semantic(callable),
      ),
    )
  }
  let allocations : Array[CallableRepresentationAllocationDemand] = []
  let ports : Array[CallableRepresentationPortDemand] = []
  let results : Array[CallableRepresentationResultDemand] = []
  let components : Array[CallableRepresentationPortComponent] = []
  for usage in self.callable_allocations {
    let node = CallableRepresentationNode::Allocation(
      usage.caller,
      usage.function,
    )
    let selected = selected_callable_node_target(
      self.planner,
      constraints,
      callable_graph,
      node,
    )
    let callable = match selected {
      Some(callable) => Some(callable)
      None =>
        self.planner
        .callable_instance_for_fact(usage.fact)
        .map(instance => CallableRepresentationTarget::Semantic(instance))
    }
    guard callable is Some(callable) else { continue }
    let component = callable_graph.component(node)
    let generic = self.callable_component_requires_generic(
      node, constraints, data_representations, callable_graph, forced_generic_components,
    )
    let worker = !generic
    allocations.push({
      caller: usage.caller,
      function: usage.function,
      callable,
      component,
      generic,
      worker,
    })
  }
  for node in callable_graph.nodes {
    guard node is Port(instance, binding) &&
      self.planner.runtime_type_at(instance, binding)
      is Some(Callable(_, _) | Forall(_, _)) else {
      continue
    }
    let component : CallableRepresentationPortComponent = {
      instance,
      binding,
      component: callable_graph.component(node),
      generic: self.callable_component_requires_generic(
        node, constraints, data_representations, callable_graph, forced_generic_components,
      ),
    }
    if !components.any(existing => {
        existing.instance == component.instance &&
        existing.binding == component.binding
      }) {
      components.push(component)
    }
    let target = selected_callable_node_target(
      self.planner,
      constraints,
      callable_graph,
      node,
    )
    guard target is Some(target) else { continue }
    let port : CallableRepresentationPortDemand = {
      instance,
      binding,
      callable: target,
      component: component.component,
    }
    if !ports.any(existing => {
        existing.instance == port.instance &&
        existing.binding == port.binding &&
        existing.callable == port.callable
      }) {
      ports.push(port)
    }
  }
  for usage in self.uses {
    guard selected_callable_node_target(
        self.planner,
        constraints,
        callable_graph,
        Port(usage.caller, usage.binding),
      )
      is Some(target) else {
      continue
    }
    let component = callable_graph.component(Port(usage.caller, usage.binding))
    for consumer in usage.consumers {
      guard consumer is Return(instance) && instance >= 0 else { continue }
      let result : CallableRepresentationResultDemand = {
        instance,
        callable: target,
        component,
      }
      if !results.contains(result) {
        results.push(result)
      }
    }
  }
  { allocations, ports, results, components, }
}

///|
fn ScalarUseAnalysis::resolved_callable_arguments(
  self : ScalarUseAnalysis,
  assignments : CallableRepresentationAssignmentPlan,
) -> Array[CallableRepresentationArgumentDemand] {
  let arguments : Array[CallableRepresentationArgumentDemand] = []
  for observation in self.calls {
    guard self.callable_node_for_atom(observation.atom, observation.caller)
      is Some(node) &&
      selected_callable_node_assignment(assignments, node)
      is Some((callable, component)) &&
      self.planner.instances[observation.target].definition.function.parameters.get(
        observation.parameter_index,
      )
      is Some(parameter) else {
      continue
    }
    let demand : CallableRepresentationArgumentDemand = {
      caller: observation.caller,
      site: observation.site,
      argument_index: observation.parameter_index,
      target: observation.target,
      parameter,
      callable,
      component,
    }
    if !arguments.any(existing => {
        existing.caller == demand.caller &&
        existing.site == demand.site &&
        existing.argument_index == demand.argument_index &&
        existing.callable == demand.callable
      }) {
      arguments.push(demand)
    }
  }
  arguments
}

///|
fn selected_callable_assignment(
  assignments : CallableRepresentationAssignmentPlan,
  caller : Int,
  binding : @anf.AnfBindingId,
) -> (CallableRepresentationTarget, Int)? {
  let mut selected : (CallableRepresentationTarget, Int)? = None
  for port in assignments.ports {
    guard port.instance == caller && port.binding == binding else { continue }
    match selected {
      None => selected = Some((port.callable, port.component))
      Some((callable, component)) if callable == port.callable &&
        component == port.component => ()
      Some(_) => return None
    }
  }
  selected
}

///|
fn selected_callable_node_assignment(
  assignments : CallableRepresentationAssignmentPlan,
  node : CallableRepresentationNode,
) -> (CallableRepresentationTarget, Int)? {
  match node {
    Port(caller, binding) =>
      selected_callable_assignment(assignments, caller, binding)
    Allocation(caller, function) => {
      let mut selected : (CallableRepresentationTarget, Int)? = None
      for allocation in assignments.allocations {
        guard allocation.caller == caller && allocation.function == function else {
          continue
        }
        match selected {
          None => selected = Some((allocation.callable, allocation.component))
          Some((callable, component)) if callable == allocation.callable &&
            component == allocation.component => ()
          Some(_) => return None
        }
      }
      selected
    }
  }
}

///|
fn callable_assignment_requires_generic(
  assignments : CallableRepresentationAssignmentPlan,
  node : CallableRepresentationNode,
) -> Bool {
  match node {
    Port(caller, binding) => {
      for component in assignments.components {
        if component.instance == caller && component.binding == binding {
          return component.generic
        }
      }
      true
    }
    Allocation(caller, function) => {
      for allocation in assignments.allocations {
        if allocation.caller == caller && allocation.function == function {
          return allocation.generic
        }
      }
      true
    }
  }
}

///|
fn callable_assignment_component_requires_generic(
  assignments : CallableRepresentationAssignmentPlan,
  component : Int,
) -> Bool {
  if component < 0 {
    return true
  }
  let mut found = false
  for allocation in assignments.allocations {
    guard allocation.component == component else { continue }
    found = true
    if allocation.generic {
      return true
    }
  }
  for port in assignments.components {
    guard port.component == component else { continue }
    found = true
    if port.generic {
      return true
    }
  }
  !found
}

///|
fn ScalarUseAnalysis::callable_component_requires_generic(
  self : ScalarUseAnalysis,
  node : CallableRepresentationNode,
  constraints : Array[CallableRepresentationConstraint],
  data_representations : DataRepresentationDemandPlan,
  callable_graph : CallableRepresentationGraph,
  forced_generic_components : Array[Int],
) -> Bool {
  let component = callable_graph.component(node)
  if forced_generic_components.contains(component) {
    return true
  }
  guard selected_callable_node_target(
      self.planner,
      constraints,
      callable_graph,
      node,
    )
    is Some(target) &&
    self.planner.callable_representation_target_key(target)
    is Some((function, _, generic_fallback)) &&
    self.planner.catalog.find(function) is Some(definition) else {
    return true
  }
  if generic_fallback && !definition.parameters.is_empty() {
    return true
  }
  for usage in self.uses {
    guard callable_graph.component(Port(usage.caller, usage.binding)) ==
      component else {
      continue
    }
    if usage.fact.open || usage.fact.callables.length() > 1 {
      return true
    }
    for consumer in usage.consumers {
      if consumer is Construct(data_allocation, payload_index) &&
        !data_representations.callable_payloads.any(payload => {
          payload.allocation == data_allocation &&
          payload.payload_index == payload_index
        }) {
        return true
      }
    }
  }
  for storage in self.callable_storage {
    guard callable_graph.component(Port(storage.caller, storage.binding)) ==
      component else {
      continue
    }
    if storage.open || storage.sources.is_empty() {
      return true
    }
    for source in storage.sources {
      if !data_representations.callable_payloads.any(payload => {
          payload.allocation == source.0 && payload.payload_index == source.1
        }) {
        return true
      }
    }
  }
  for allocation in self.callable_allocations {
    guard callable_graph.component(
        Allocation(allocation.caller, allocation.function),
      ) ==
      component else {
      continue
    }
    if allocation.fact.open || allocation.fact.callables.length() > 1 {
      return true
    }
    for consumer in allocation.consumers {
      if consumer is Construct(data_allocation, payload_index) &&
        !data_representations.callable_payloads.any(payload => {
          payload.allocation == data_allocation &&
          payload.payload_index == payload_index
        }) {
        return true
      }
    }
  }
  false
}

///|
fn ScalarUseAnalysis::callable_node_for_atom(
  self : ScalarUseAnalysis,
  atom : @anf.AnfAtom,
  caller : Int,
) -> CallableRepresentationNode? {
  match atom {
    Function(function) => Some(Allocation(caller, function.id))
    EvidenceLambda(body~, ..) =>
      extract_top_function(body).map(function => Allocation(caller, function.id))
    Ref(_) | Temp(_) =>
      self
      .callable_port_for_atom(atom, caller)
      .map(port => Port(port.0, port.1))
    Literal(_) => None
  }
}

///|
fn ScalarUseAnalysis::callable_port_for_atom(
  self : ScalarUseAnalysis,
  atom : @anf.AnfAtom,
  caller : Int,
) -> (Int, @anf.AnfBindingId)? {
  match atom {
    Ref(value) => {
      let binding = @anf.AnfBindingId::Value(value)
      let owner = if caller >= 0 && !self.planner.global_value(value) {
        caller
      } else {
        -1
      }
      Some((owner, binding))
    }
    Temp(temp) => Some((caller, @anf.AnfBindingId::Temp(temp)))
    Function(_) | EvidenceLambda(_) | Literal(_) => None
  }
}

///|
fn CallableInstancePlanner::global_value(
  self : CallableInstancePlanner,
  value : @buslane.ValueId,
) -> Bool {
  for term in self.program.terms() {
    match term {
      Let(bound, _) | External(bound) if bound == value => return true
      LetRec(bindings) if bindings.any(binding => binding.id == value) =>
        return true
      Let(_, _) | LetRec(_) | External(_) => ()
    }
  }
  false
}

///|
fn CallableRepresentationGraph::component(
  self : CallableRepresentationGraph,
  node : CallableRepresentationNode,
) -> Int {
  self.components.at(callable_representation_node_key(node))
}

///|
fn callable_representation_node_key(
  node : CallableRepresentationNode,
) -> CallableRepresentationNodeKey {
  match node {
    Port(owner, Value(value)) => { owner, kind: 0, identity: value.index, }
    Port(owner, Temp(temp)) => { owner, kind: 1, identity: temp.index, }
    Allocation(owner, function) => { owner, kind: 2, identity: function.value, }
  }
}

///|
fn CallableRepresentationGraph::representative(
  self : CallableRepresentationGraph,
  node : CallableRepresentationNode,
) -> CallableRepresentationNode {
  self.nodes[self.component(node)]
}

///|
fn ScalarUseAnalysis::callable_graph(
  self : ScalarUseAnalysis,
) -> CallableRepresentationGraph {
  let builder : CallableRepresentationGraphBuilder = {
    indices: @hashmap.HashMap([]),
    nodes: [],
    parents: [],
  }
  for usage in self.uses {
    ignore(builder.ensure_node(Port(usage.caller, usage.binding)))
  }
  for allocation in self.callable_allocations {
    ignore(
      builder.ensure_node(Allocation(allocation.caller, allocation.function)),
    )
  }
  for storage in self.callable_storage {
    let target = CallableRepresentationNode::Port(
      storage.caller,
      storage.binding,
    )
    ignore(builder.ensure_node(target))
    for source in storage.sources {
      guard self.planner.allocation(source.0) is Some(allocation) &&
        allocation.payload_atoms.get(source.1) is Some(atom) &&
        self.callable_node_for_atom(
          atom,
          match source.0.body {
            TopLevel => -1
            Instance(instance) => instance
          },
        )
        is Some(source_node) else {
        continue
      }
      builder.connect(source_node, target)
    }
  }
  for usage in self.uses {
    for consumer in usage.consumers {
      self.connect_callable_consumer(
        builder,
        Port(usage.caller, usage.binding),
        consumer,
      )
    }
  }
  for allocation in self.callable_allocations {
    for consumer in allocation.consumers {
      self.connect_callable_consumer(
        builder,
        Allocation(allocation.caller, allocation.function),
        consumer,
      )
    }
  }
  for flow in self.planner.capture_flows {
    builder.connect(
      Port(flow.source_instance, flow.binding),
      Port(flow.target_instance, flow.binding),
    )
  }
  builder.finish()
}

///|
fn CallableRepresentationGraphBuilder::ensure_node(
  self : CallableRepresentationGraphBuilder,
  node : CallableRepresentationNode,
) -> Int {
  let key = callable_representation_node_key(node)
  if self.indices.get(key) is Some(index) {
    return index
  }
  let index = self.nodes.length()
  self.indices.set(key, index)
  self.nodes.push(node)
  self.parents.push(index)
  index
}

///|
fn CallableRepresentationGraphBuilder::root(
  self : CallableRepresentationGraphBuilder,
  index : Int,
) -> Int {
  let mut root = index
  while self.parents[root] != root {
    root = self.parents[root]
  }
  let mut cursor = index
  while self.parents[cursor] != cursor {
    let parent = self.parents[cursor]
    self.parents[cursor] = root
    cursor = parent
  }
  root
}

///|
fn CallableRepresentationGraphBuilder::connect(
  self : CallableRepresentationGraphBuilder,
  left : CallableRepresentationNode,
  right : CallableRepresentationNode,
) -> Unit {
  let left_root = self.root(self.ensure_node(left))
  let right_root = self.root(self.ensure_node(right))
  if left_root < right_root {
    self.parents[right_root] = left_root
  } else if right_root < left_root {
    self.parents[left_root] = right_root
  }
}

///|
fn CallableRepresentationGraphBuilder::finish(
  self : CallableRepresentationGraphBuilder,
) -> CallableRepresentationGraph {
  let components : @hashmap.HashMap[CallableRepresentationNodeKey, Int] = @hashmap.HashMap([],
  )
  for index, node in self.nodes {
    components.set(callable_representation_node_key(node), self.root(index))
  }
  { nodes: self.nodes, components, }
}

///|
fn ScalarUseAnalysis::connect_callable_consumer(
  self : ScalarUseAnalysis,
  graph : CallableRepresentationGraphBuilder,
  source : CallableRepresentationNode,
  consumer : ScalarCarrierConsumer,
) -> Unit {
  match consumer {
    Alias(caller, binding) | Join(caller, binding) =>
      graph.connect(source, Port(caller, binding))
    ExactCall(target, parameter_index, _) => {
      guard self.planner.instances.get(target) is Some(instance) &&
        instance.definition.function.parameters.get(parameter_index)
        is Some(parameter) else {
        return
      }
      graph.connect(source, Port(target, Value(parameter)))
    }
    ClosedCall(targets, parameter_index, _) =>
      for target in targets {
        guard self.planner.instances.get(target) is Some(instance) &&
          instance.definition.function.parameters.get(parameter_index)
          is Some(parameter) else {
          continue
        }
        graph.connect(source, Port(target, Value(parameter)))
      }
    Capture(targets) =>
      match source {
        Port(_, binding) =>
          for target in targets {
            graph.connect(source, Port(target, binding))
          }
        Allocation(_, _) => ()
      }
    Return(instance) =>
      for call in self.planner.calls {
        if call.targets.contains(instance) {
          graph.connect(source, Port(call.caller, call.site))
        }
      }
    Invoke | Construct(_, _) | Match(_) | Global(_) | UnsupportedArgument => ()
  }
}

///|
fn constrain_callable_node(
  constraints : Array[CallableRepresentationConstraint],
  graph : CallableRepresentationGraph,
  node : CallableRepresentationNode,
  target : CallableRepresentationTarget,
) -> Bool {
  let node = graph.representative(node)
  for constraint in constraints {
    if constraint.node == node {
      if constraint.targets.contains(target) {
        return false
      }
      constraint.targets.push(target)
      return true
    }
  }
  constraints.push({ node, targets: [target], })
  true
}

///|
fn callable_node_targets(
  constraints : Array[CallableRepresentationConstraint],
  graph : CallableRepresentationGraph,
  node : CallableRepresentationNode,
) -> Array[CallableRepresentationTarget] {
  let node = graph.representative(node)
  for constraint in constraints {
    if constraint.node == node {
      return constraint.targets
    }
  }
  []
}

///|
fn selected_callable_node_target(
  planner : CallableInstancePlanner,
  constraints : Array[CallableRepresentationConstraint],
  graph : CallableRepresentationGraph,
  node : CallableRepresentationNode,
) -> CallableRepresentationTarget? {
  let mut selected : CallableRepresentationTarget? = None
  let mut selected_function : @anf.AnfFunctionId? = None
  let mut selected_arguments : Array[@anf.RuntimeArgument] = []
  let mut selected_generic = false
  for target in callable_node_targets(constraints, graph, node) {
    guard planner.callable_representation_target_key(target)
      is Some((function, arguments, generic)) else {
      return None
    }
    match selected {
      None => {
        selected = Some(target)
        selected_function = Some(function)
        selected_arguments = arguments
        selected_generic = generic
      }
      Some(existing) => {
        guard selected_function == Some(function) else { return None }
        if selected_arguments == arguments {
          if (existing is Refined(_) && target is Semantic(_)) ||
            (selected_generic && !generic) {
            selected = Some(target)
            selected_generic = generic
          }
          continue
        }
        if selected_generic && !generic {
          selected = Some(target)
          selected_arguments = arguments
          selected_generic = false
          continue
        }
        if !selected_generic && generic {
          continue
        }
        return None
      }
    }
  }
  selected
}

///|
fn CallableInstancePlanner::callable_draft_closes_representation(
  self : CallableInstancePlanner,
  draft : CallableRepresentationDraft,
) -> Bool {
  guard self.instances.get(draft.source_instance) is Some(source) else {
    return false
  }
  let lexical_count = source.definition.lexical_parameters.length()
  draft.lexical_arguments != source.key.arguments[:lexical_count].to_owned() ||
  draft.own_arguments.any(argument => argument.transform is Closed)
}

///|
fn CallableInstancePlanner::callable_representation_target_key(
  self : CallableInstancePlanner,
  target : CallableRepresentationTarget,
) -> (@anf.AnfFunctionId, Array[@anf.RuntimeArgument], Bool)? {
  match target {
    Semantic(instance) =>
      self.instances
      .get(instance)
      .map(instance => {
        (
          instance.key.function,
          instance.key.arguments,
          instance.generic_fallback,
        )
      })
    Refined(source_instance~, lexical_arguments~, own_arguments~) =>
      self.instances
      .get(source_instance)
      .map(source => {
        (
          source.key.function,
          lexical_arguments + own_arguments.map(argument => argument.argument),
          false,
        )
      })
  }
}

///|
fn ScalarUseAnalysis::collect(
  self : ScalarUseAnalysis,
) -> Unit raise LoisvmLoweringError {
  for term in self.planner.program.terms() {
    match term {
      Let(value, expression) => self.collect_expr(expression, -1, Global(value))
      LetRec(bindings) =>
        for binding in bindings {
          self.record_atom_use(binding.rhs, -1, Alias(-1, Value(binding.id)))
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
        self.record_atom_use(
          binding.rhs,
          caller,
          Alias(caller, Value(binding.id)),
        )
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
      self.record_atom_use(callee, caller, Alias(caller, site))
    Construct(construct) => {
      let allocation : CallableAllocationKey = {
        body: if caller < 0 {
          TopLevel
        } else {
          Instance(caller)
        },
        site,
      }
      for index, payload in construct.payloads {
        self.record_atom_use(payload, caller, Construct(allocation, index))
      }
    }
    Match(match_) => {
      let fact = self.atom_fact(match_.scrutinee, caller)
      let consumer = ScalarCarrierConsumer::Match(
        scalar_projectable=self.match_accepts_fact(match_, fact),
      )
      self.record_atom_use(match_.scrutinee, caller, consumer)
      for alternative in match_.alternatives {
        for index, binder in alternative.value_binders {
          let sources = fact.allocations.filter_map(key => {
            guard self.planner.allocation(key) is Some(allocation) else {
              return None
            }
            let matches = match alternative.alt_constructor {
              DataCon(data_constructor) =>
                allocation.data_constructor == data_constructor
              Default => true
              Literal(_) => false
            }
            if matches && index < allocation.payloads.length() {
              Some((key, index))
            } else {
              None
            }
          })
          self.callable_storage.push({
            caller,
            binding: Value(binder),
            carrier: self.callable_port_for_atom(match_.scrutinee, caller),
            sources,
            open: fact.open,
          })
        }
        self.collect_expr(alternative.body, caller, Join(caller, site))
      }
    }
    Call(callee~, arguments~) => {
      let target = self.exact_call_target(caller, site)
      let targets = self.closed_call_targets(caller, site)
      self.invocations.push({
        caller,
        site,
        callee,
        targets: match target {
          Some(target) => [target]
          None => targets
        },
      })
      self.record_atom_use(callee, caller, ScalarCarrierConsumer::Invoke)
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
            self.record_atom_use(
              argument,
              caller,
              ExactCall(instance, index, site),
            )
          }
          _ =>
            if !targets.is_empty() &&
              targets.all(instance => {
                index <
                self.planner.instances[instance].definition.function.parameters.length()
              }) {
              self.record_atom_use(
                argument,
                caller,
                ClosedCall(targets, index, site),
              )
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
) -> Unit raise LoisvmLoweringError {
  self.collect_atom_captures(atom, caller)
  let function = match atom {
    Function(function) => Some(function)
    EvidenceLambda(body~, ..) => extract_top_function(body)
    Literal(_) | Ref(_) | Temp(_) => None
  }
  if function is Some(function) {
    self.record_callable_allocation_use(
      caller,
      function.id,
      self.planner.function_fact(function.id, caller),
      consumer,
    )
    return
  }
  if self.callable_port_for_atom(atom, caller) is Some((owner, binding)) {
    self.record_binding_use(owner, binding, consumer)
  }
}

///|
fn ScalarUseAnalysis::record_callable_allocation_use(
  self : ScalarUseAnalysis,
  caller : Int,
  function : @anf.AnfFunctionId,
  fact : CallableFlowFact,
  consumer : ScalarCarrierConsumer,
) -> Unit {
  for allocation in self.callable_allocations {
    if allocation.caller == caller && allocation.function == function {
      allocation.consumers.push(consumer)
      return
    }
  }
  self.callable_allocations.push({
    caller,
    function,
    fact,
    consumers: [consumer],
  })
}

///|
fn ScalarUseAnalysis::record_binding_use(
  self : ScalarUseAnalysis,
  caller : Int,
  binding : @anf.AnfBindingId,
  consumer : ScalarCarrierConsumer,
) -> Unit {
  let fact = self.planner.binding_fact(caller, binding)
  for usage in self.uses {
    if usage.caller == caller && usage.binding == binding {
      usage.consumers.push(consumer)
      return
    }
  }
  self.uses.push({ caller, binding, fact, consumers: [consumer], })
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
      if local_fact != CallableFlowFact::empty() {
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
      guard usage.consumers is [ExactCall(instance, parameter_index, _)] else {
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
    allocations.push({ key: allocation.key, contract, })
  }
  { allocations, parameters, }
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
      ExactCall(instance, parameter_index, _) => {
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
      | Join(_, _)
      | ClosedCall(_, _, _)
      | Construct(_, _)
      | Return(_)
      | Global(_)
      | Capture(_)
      | Invoke
      | UnsupportedArgument => return false
    }
  } nobreak {
    false
  }
}

///|
fn scalar_replacement_consumer(consumer : ScalarCarrierConsumer) -> Bool {
  consumer
  is (Alias(_, _) | ExactCall(_, _, _) | Match(scalar_projectable=true))
}

///|
fn ScalarUseAnalysis::data_identity_flow_targets(
  self : ScalarUseAnalysis,
  binding : @anf.AnfBindingId,
  consumer : ScalarCarrierConsumer,
) -> Array[DataRepresentationUseNode] {
  match consumer {
    Alias(caller, binding) | Join(caller, binding) => [Port(caller, binding)]
    ExactCall(instance, parameter_index, _) => {
      guard self.planner.instances.get(instance) is Some(target) &&
        target.definition.function.parameters.get(parameter_index)
        is Some(parameter) else {
        return []
      }
      [Port(instance, Value(parameter))]
    }
    ClosedCall(instances, parameter_index, _) =>
      instances.filter_map(instance => {
        self.planner.instances
        .get(instance)
        .bind(target => {
          target.definition.function.parameters
          .get(parameter_index)
          .map(parameter => Port(instance, Value(parameter)))
        })
      })
    Return(instance) => if instance < 0 { [] } else { [Result(instance)] }
    Global(value) => [Global(value)]
    Capture(instances) => instances.map(instance => Capture(instance, binding))
    Match(_) | Construct(_, _) | Invoke | UnsupportedArgument => []
  }
}

///|
fn ScalarUseAnalysis::finish_data_representations(
  self : ScalarUseAnalysis,
  scalar : ClosedAggregateScalarReplacementPlan,
  callable_graph : CallableRepresentationGraph,
) -> DataRepresentationDemandPlan raise LoisvmLoweringError {
  let candidates : Array[DataRepresentationAllocationCandidate] = []
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
  let declaration_boundaries : Array[DataRepresentationUseNode] = []
  for usage in self.uses {
    let families = data_families_in_fact(usage.fact, candidates)
    let groups = data_groups_in_fact(usage.fact, candidates)
    guard self.planner.runtime_type_at(usage.caller, usage.binding)
      is Some(Data(owner, _)) else {
      reject_data_groups(rejected, groups)
      continue
    }
    if usage.fact.open || families.length() != 1 {
      reject_data_groups(rejected, groups)
      for consumer in usage.consumers {
        for target in self.data_identity_flow_targets(usage.binding, consumer) {
          if !declaration_boundaries.contains(target) {
            declaration_boundaries.push(target)
          }
        }
      }
      continue
    }
    let family = families[0]
    guard family.owner == owner else {
      reject_data_groups(rejected, groups)
      for consumer in usage.consumers {
        for target in self.data_identity_flow_targets(usage.binding, consumer) {
          if !declaration_boundaries.contains(target) {
            declaration_boundaries.push(target)
          }
        }
      }
      continue
    }
    for invocation in self.invocations {
      guard invocation.caller == usage.caller &&
        invocation.site == usage.binding else {
        continue
      }
      let call_result : DataRepresentationUseGroup = {
        node: Port(usage.caller, usage.binding),
        family,
      }
      connect_data_groups(edges, groups, call_result)
      for target in invocation.targets {
        guard self.planner.instances.get(target) is Some(instance) else {
          reject_data_groups(rejected, groups + [call_result])
          continue
        }
        let (_, _, result_type) = function_type_parts(instance.definition.type_)
        let result_type = instance.substitution.apply_type(
          self.planner.image.runtime_types,
          result_type,
        )
        guard result_type is Data(result_owner, _) &&
          result_owner == family.owner else {
          reject_data_groups(rejected, groups + [call_result])
          continue
        }
        connect_data_groups(edges, groups + [call_result], {
          node: Result(target),
          family,
        })
      }
    }
    for consumer in usage.consumers {
      match consumer {
        Alias(target_caller, target_binding)
        | Join(target_caller, target_binding) =>
          connect_data_groups(edges, groups, {
            node: Port(target_caller, target_binding),
            family,
          })
        Match(_) => ()
        ExactCall(instance, parameter_index, _) => {
          guard self.planner.instances.get(instance) is Some(target_instance) &&
            target_instance.definition.function.parameters.get(parameter_index)
            is Some(parameter) &&
            self.planner.runtime_type_at(instance, Value(parameter))
            is Some(Data(owner, _)) &&
            family.owner == owner else {
            reject_data_groups(rejected, groups)
            continue
          }
          let target : DataRepresentationUseGroup = {
            node: Port(instance, Value(parameter)),
            family,
          }
          if self.planner.instances.get(instance) is Some(candidate) &&
            !self.planner.instance_rejects_data_representation(candidate) {
            connect_data_groups(edges, groups, target)
          } else {
            reject_data_groups(rejected, groups)
          }
        }
        ClosedCall(targets, parameter_index, _) =>
          for instance in targets {
            guard self.planner.instances.get(instance) is Some(target_instance) &&
              target_instance.definition.function.parameters.get(
                parameter_index,
              )
              is Some(parameter) &&
              self.planner.runtime_type_at(instance, Value(parameter))
              is Some(Data(owner, _)) &&
              family.owner == owner else {
              reject_data_groups(rejected, groups)
              continue
            }
            let target : DataRepresentationUseGroup = {
              node: Port(instance, Value(parameter)),
              family,
            }
            if self.planner.instances.get(instance) is Some(candidate) &&
              !self.planner.instance_rejects_data_representation(candidate) {
              connect_data_groups(edges, groups, target)
            } else {
              reject_data_groups(rejected, groups)
            }
          }
        Return(instance) =>
          if instance >= 0 &&
            self.planner.instances.get(instance) is Some(target_instance) {
            let (_, _, result_type) = function_type_parts(
              target_instance.definition.type_,
            )
            let result_type = target_instance.substitution.apply_type(
              self.planner.image.runtime_types,
              result_type,
            )
            if !(result_type is Data(owner, _) && family.owner == owner) {
              reject_data_groups(rejected, groups)
              continue
            }
            connect_data_groups(edges, groups, {
              node: Result(instance),
              family,
            })
          }
        Global(value) => {
          guard self.planner.image.metadata.value_info(value) is Some(info) &&
            info.type_ is Data(owner, _) &&
            family.owner == owner else {
            reject_data_groups(rejected, groups)
            continue
          }
          connect_data_groups(edges, groups, { node: Global(value), family, })
        }
        Construct(allocation, _) =>
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
              guard self.planner.runtime_type_at(instance, usage.binding)
                is Some(Data(owner, _)) &&
                family.owner == owner else {
                reject_data_groups(rejected, groups)
                continue
              }
              let target : DataRepresentationUseGroup = {
                node: Capture(instance, usage.binding),
                family,
              }
              if self.planner.instances.get(instance) is Some(candidate) &&
                !self.planner.instance_rejects_data_representation(candidate) {
                connect_data_groups(edges, groups, target)
              } else {
                reject_data_groups(rejected, groups)
              }
            }
          }
        Invoke | UnsupportedArgument => reject_data_groups(rejected, groups)
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
      guard data_candidate_payload_type(candidate, index) is Some(target_type) else {
        reject_data_groups(rejected, [
          data_group_for_allocation(candidate.allocation, candidate.family),
        ])
        continue
      }
      if target_type is Data(_, _) {
        let payload_groups = data_groups_in_fact(payload, candidates)
        let payload_families = data_families_in_fact(payload, candidates)
        if payload.open || payload_families.length() > 1 {
          reject_data_groups(
            rejected,
            [data_group_for_allocation(candidate.allocation, candidate.family)] +
            payload_groups,
          )
        }
        continue
      }
      guard target_type is (Callable(_, _) | Forall(_, _)) else { continue }
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
  let groups = data_representation_groups(candidates, edges)
  for group in groups {
    if declaration_boundaries.contains(group.node) {
      reject_data_groups(rejected, [group])
    }
  }
  for group in groups {
    guard group.node is Port(instance_id, Value(parameter)) &&
      self.planner.instances.get(instance_id) is Some(instance) &&
      instance.definition.function.parameters.search_by(id => id == parameter)
      is Some(parameter_index) else {
      continue
    }
    for observation in self.calls {
      guard observation.target == instance_id &&
        observation.parameter_index == parameter_index else {
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
      data_representation_group_instance(group) == Some(observation.target) &&
      !rejected.contains(group)
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
      ({ draft, target_type, families, }, target_groups),
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
  let allocations : Array[DataRepresentationAllocationDemand] = []
  for candidate in candidates {
    let group = data_group_for_allocation(
      candidate.allocation,
      candidate.family,
    )
    guard !rejected.contains(group) else { continue }
    let component = data_representation_component(group, groups, edges)
    allocations.push({
      allocation: candidate.allocation,
      data_constructor: candidate.data_constructor,
      family: candidate.family.finalize(component),
      type_: candidate.type_,
      hidden_arguments: candidate.hidden_arguments,
      storage_types: candidate.storage_types,
      component,
    })
  }
  let data_payloads : Array[DataRepresentationDataPayloadDemand] = []
  for candidate in allocations {
    guard self.planner.allocation(candidate.allocation) is Some(allocation) else {
      continue
    }
    for index, payload in allocation.payloads {
      guard candidate.storage_types.get(index) is Some(Data(owner, _)) else {
        continue
      }
      let payload_groups = data_groups_in_fact(payload, candidates).filter(group => {
        !rejected.contains(group)
      })
      let family = if payload_groups.is_empty() {
        DataRepresentationFamilyKey::Declaration(owner)
      } else {
        let first = payload_groups[0]
        let selected = first.family.finalize(
          data_representation_component(first, groups, edges),
        )
        for group in payload_groups {
          if group.family.finalize(
              data_representation_component(group, groups, edges),
            ) !=
            selected {
            raise RepresentationSpecializationInvariant(
              detail="accepted specialized data member has conflicting nested data-family components",
            )
          }
        }
        selected
      }
      data_payloads.push({
        allocation: candidate.allocation,
        payload_index: index,
        family,
      })
    }
  }
  let callable_payloads : Array[DataRepresentationCallablePayloadDemand] = []
  for candidate in allocations {
    guard self.planner.allocation(candidate.allocation) is Some(allocation) else {
      continue
    }
    for index, payload in allocation.payloads {
      guard candidate.storage_types.get(index)
        is Some(Callable(_, _) | Forall(_, _) as target_type) &&
        self.planner.callable_draft_for_data_payload(
          allocation, index, payload, target_type,
        )
        is Some(draft) else {
        continue
      }
      callable_payloads.push({
        allocation: candidate.allocation,
        payload_index: index,
        callable: callable_representation_target(draft),
        target_type,
        data_component: candidate.component,
        callable_component: self
        .callable_node_for_atom(
          allocation.payload_atoms[index],
          match candidate.allocation.body {
            TopLevel => -1
            Instance(instance) => instance
          },
        )
        .map(node => callable_graph.component(node))
        .unwrap_or(-1),
      })
    }
  }
  let callable_arguments = callable_argument_candidates.filter_map(candidate => {
    if candidate.1.any(group => rejected.contains(group)) {
      None
    } else {
      let accepted = candidate.0
      let demand : DataRepresentationCallableArgumentDemand = {
        callable: callable_representation_target(accepted.draft),
        target_type: accepted.target_type,
      }
      Some(demand)
    }
  })
  let ports : Array[DataRepresentationPortDemand] = []
  let results : Array[DataRepresentationResultDemand] = []
  let globals : Array[DataRepresentationGlobalDemand] = []
  let captures : Array[DataRepresentationCaptureDemand] = []
  for group in groups {
    guard !rejected.contains(group) else { continue }
    match group.node {
      Port(instance, binding) => {
        let component = data_representation_component(group, groups, edges)
        let demand : DataRepresentationPortDemand = {
          instance,
          binding,
          family: group.family.finalize(component),
          component,
        }
        if !ports.contains(demand) {
          ports.push(demand)
        }
      }
      Result(instance) => {
        let component = data_representation_component(group, groups, edges)
        let demand : DataRepresentationResultDemand = {
          instance,
          family: group.family.finalize(component),
          component,
        }
        if !results.contains(demand) {
          results.push(demand)
        }
      }
      Global(value) => {
        let component = data_representation_component(group, groups, edges)
        let demand : DataRepresentationGlobalDemand = {
          value,
          family: group.family.finalize(component),
          component,
        }
        if !globals.contains(demand) {
          globals.push(demand)
        }
      }
      Capture(instance, binding) => {
        let component = data_representation_component(group, groups, edges)
        let demand : DataRepresentationCaptureDemand = {
          instance,
          binding,
          family: group.family.finalize(component),
          component,
        }
        if !captures.contains(demand) {
          captures.push(demand)
        }
      }
      Allocation(_) => ()
    }
  }
  for usage in self.uses {
    guard !usage.fact.open else { continue }
    let usage_groups = data_groups_in_fact(usage.fact, candidates)
    guard !usage_groups.is_empty() &&
      usage_groups.all(group => !rejected.contains(group)) else {
      continue
    }
    let component = data_representation_component(
      usage_groups[0],
      groups,
      edges,
    )
    let family = usage_groups[0].family.finalize(component)
    guard usage_groups.all(group => {
      group.family.finalize(component) == family &&
      data_representation_component(group, groups, edges) == component
    }) else {
      continue
    }
    let port : DataRepresentationPortDemand = {
      instance: usage.caller,
      binding: usage.binding,
      family,
      component,
    }
    if !ports.contains(port) {
      ports.push(port)
    }
    for consumer in usage.consumers {
      if consumer is Return(instance) && instance >= 0 {
        let demand : DataRepresentationResultDemand = {
          instance,
          family,
          component,
        }
        if !results.contains(demand) {
          results.push(demand)
        }
      }
      if consumer is Global(value) {
        let demand : DataRepresentationGlobalDemand = {
          value,
          family,
          component,
        }
        if !globals.contains(demand) {
          globals.push(demand)
        }
      }
      if consumer is Capture(instances) {
        for instance in instances {
          let demand : DataRepresentationCaptureDemand = {
            instance,
            binding: usage.binding,
            family,
            component,
          }
          if !captures.contains(demand) {
            captures.push(demand)
          }
        }
      }
    }
  }
  {
    allocations,
    ports,
    results,
    globals,
    captures,
    data_payloads,
    callable_payloads,
    callable_arguments,
  }
}

///|
fn data_candidate_payload_type(
  candidate : DataRepresentationAllocationCandidate,
  index : Int,
) -> @anf.RuntimeType? {
  candidate.storage_types.get(index)
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
  let base = if caller < 0 {
    source_instance.substitution
  } else {
    self.instances[caller].substitution.overlay(source_instance.substitution)
  }
  guard self.image.refine_callable_representation_substitution(
      definition.type_,
      target_type,
      base,
      parameters.map(parameter => parameter.id),
    )
    is Some(substitutions) else {
    return None
  }
  let lexical_arguments = definition.lexical_parameters.map(parameter => {
    let argument = substitutions
      .argument(parameter.id)
      .unwrap_or(self.identity_argument(parameter))
    substitutions.apply_argument(self.image.runtime_types, argument)
  })
  let own_arguments = []
  for index, parameter in definition.parameters {
    let argument = substitutions
      .argument(parameter.id)
      .unwrap_or(source_instance.own_arguments[index].argument)
    let argument = substitutions.apply_argument(
      self.image.runtime_types,
      argument,
    )
    own_arguments.push({
      argument,
      transform: if self.image.generic_argument_is_closed(argument) {
        Closed
      } else {
        source_instance.own_arguments[index].transform
      },
    })
  }
  Some({ source_instance: source, lexical_arguments, own_arguments, caller, })
}

///|
fn callable_representation_target(
  draft : CallableRepresentationDraft,
) -> CallableRepresentationTarget {
  Refined(
    source_instance=draft.source_instance,
    lexical_arguments=draft.lexical_arguments,
    own_arguments=draft.own_arguments,
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
  guard allocation.payload_atoms.get(index) is Some(_) else { return None }
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
  candidates : Array[DataRepresentationAllocationCandidate],
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
fn data_representation_component(
  seed : DataRepresentationUseGroup,
  groups : Array[DataRepresentationUseGroup],
  edges : Array[DataRepresentationUseEdge],
) -> Int {
  let reachable = [seed]
  let mut cursor = 0
  while cursor < reachable.length() {
    let current = reachable[cursor]
    for edge in edges {
      let adjacent = if edge.from_group == current {
        Some(edge.to_group)
      } else if edge.to_group == current {
        Some(edge.from_group)
      } else {
        None
      }
      if adjacent is Some(group) && !reachable.contains(group) {
        reachable.push(group)
      }
    }
    cursor += 1
  }
  for index, group in groups {
    if reachable.contains(group) {
      return index
    }
  }
  abort("data representation group has no component")
}

///|
fn CallableInstancePlanner::data_representation_candidate(
  self : CallableInstancePlanner,
  allocation : CallableAllocationFact,
) -> DataRepresentationAllocationCandidate? raise LoisvmLoweringError {
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
  let arguments = allocation.type_arguments.map(argument => {
    substitutions.apply_argument(self.image.runtime_types, argument)
  })
  let hidden_arguments = allocation.hidden_arguments.map(argument => {
    substitutions.apply_argument(self.image.runtime_types, argument)
  })
  guard arguments.length() == owner.evidence_parameters.length() &&
    hidden_arguments.length() == info.hidden_evidence_parameters.length() &&
    arguments.all(argument => self.image.generic_argument_is_closed(argument)) &&
    self.image.specialized_data_family_key_or_none(info.owner, arguments)
    is Some(family) else {
    return None
  }
  let owner_substitutions = RuntimeSubstitution::from_arguments(
    owner.evidence_parameters,
    arguments,
  )
  let storage_substitutions = owner_substitutions.overlay(
    RuntimeSubstitution::from_arguments(
      info.hidden_evidence_parameters,
      hidden_arguments,
    ),
  )
  let storage_types = info.payload_types.map(payload_type => {
    storage_substitutions.apply_type(self.image.runtime_types, payload_type)
  })
  let mut family_changes_representation = false
  for data_constructor in owner.constructors {
    guard self.image.metadata.data_constructor_info(data_constructor)
      is Some(constructor_info) else {
      raise MissingDataConstructorMetadata(data_constructor~)
    }
    let specialized_payloads = constructor_info.payload_types.map(payload_type => {
      owner_substitutions.apply_type(self.image.runtime_types, payload_type)
    })
    if constructor_info.payload_types != specialized_payloads ||
      specialized_payloads.any(type_ => {
        self.image.runtime_type_may_change_physical_representation(type_)
      }) {
      family_changes_representation = true
      break
    }
  }
  if !family_changes_representation {
    return None
  }
  Some({
    allocation: allocation.key,
    data_constructor: allocation.data_constructor,
    family,
    type_: Data(info.owner, arguments),
    hidden_arguments,
    storage_types,
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
      !self.image.generic_argument_is_closed(argument)
    }) {
    return true
  }
  self.open_functions.contains(instance.definition.function.id)
}

///|
fn CallableInstancePlanner::runtime_type_at(
  self : CallableInstancePlanner,
  caller : Int,
  binding : @anf.AnfBindingId,
) -> @anf.RuntimeType? raise LoisvmLoweringError {
  let capture = match binding {
    Value(value) => @anf.AnfCapture::Value(value)
    Temp(temp) => @anf.AnfCapture::Temp(temp)
  }
  guard self.catalog.capture_type(capture, self.image.metadata) is Some(type_) else {
    return None
  }
  if caller < 0 {
    Some(type_)
  } else {
    self.instances
    .get(caller)
    .map(instance => {
      instance.substitution.apply_type(self.image.runtime_types, type_)
    })
  }
}

///|
fn data_families_in_fact(
  fact : CallableFlowFact,
  candidates : Array[DataRepresentationAllocationCandidate],
) -> Array[DataRepresentationFamilyCandidateKey] {
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
  candidates : Array[DataRepresentationAllocationCandidate],
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
  family : DataRepresentationFamilyCandidateKey,
) -> DataRepresentationUseGroup {
  { node: Allocation(allocation), family, }
}

///|
fn data_representation_group_instance(
  group : DataRepresentationUseGroup,
) -> Int? {
  match group.node {
    Allocation({ body: Instance(instance), .. })
    | Port(instance, _)
    | Result(instance)
    | Capture(instance, _) => Some(instance)
    Allocation({ body: TopLevel, .. }) | Global(_) => None
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
  candidates : Array[DataRepresentationAllocationCandidate],
  allocation : CallableAllocationKey,
) -> DataRepresentationFamilyCandidateKey? {
  for candidate in candidates {
    if candidate.allocation == allocation {
      return Some(candidate.family)
    }
  }
  None
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
  self.calls.push({ caller, site, targets: [target], open: false, })
  self.changed = true
}

///|
fn CallableInstancePlanner::record_capture_flow(
  self : CallableInstancePlanner,
  source_instance : Int,
  target_instance : Int,
  binding : @anf.AnfBindingId,
) -> Unit {
  let flow = { source_instance, target_instance, binding, }
  if !self.capture_flows.contains(flow) {
    self.capture_flows.push(flow)
    self.changed = true
  }
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
  self.calls.push({ caller, site, targets: [], open: true, })
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
