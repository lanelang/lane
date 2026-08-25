///|
/// An interned physical value contract. Runtime ANF types remain semantic;
/// only this identity crosses into representation-aware VM CFG emission.
priv struct PhysicalValueShapeId {
  index : Int
} derive(Debug, Eq)

///|
priv struct PhysicalValueContract {
  shape : PhysicalValueShapeId
  callable_interface : PhysicalCallableInterface?
  fields : Array[PhysicalValueContract]
} derive(Debug, Eq)

///|
priv enum PhysicalValueShape {
  Unit
  Slot(CanonicalRuntimeTypeKey)
  Product(ClosedAggregateContract, Array[PhysicalValueShapeId])
} derive(Debug, Eq)

///|
fn PhysicalAnfProgram::value_contract(
  self : PhysicalAnfProgram,
  shape : PhysicalValueShapeId,
  callable_interface : PhysicalCallableInterface?,
  fields : Array[PhysicalValueContract],
  origin : String,
) -> PhysicalValueContract raise LoisvmLoweringError {
  match self.shape(shape) {
    Slot(Callable(invocation)) => {
      guard callable_interface is Some(interface) &&
        interface.invocation == invocation &&
        fields.is_empty() else {
        raise RepresentationSpecializationInvariant(
          detail="\{origin} callable contract \{Repr(callable_interface)} disagrees with physical shape \{Repr(self.shape(shape))}",
        )
      }
    }
    Product(_, shapes) => {
      guard callable_interface is None && shapes.length() == fields.length() else {
        raise RepresentationSpecializationInvariant(
          detail="\{origin} aggregate contract disagrees with its physical shape",
        )
      }
      for index, field in fields {
        if shapes[index] != field.shape {
          raise RepresentationSpecializationInvariant(
            detail="\{origin} aggregate field contract disagrees with its physical shape",
          )
        }
      }
    }
    Unit | Slot(_) =>
      if callable_interface is Some(_) || !fields.is_empty() {
        raise RepresentationSpecializationInvariant(
          detail="\{origin} scalar contract carries callable or aggregate structure",
        )
      }
  }
  { shape, callable_interface, fields, }
}

///|
fn PhysicalValueShape::canonical_result(
  self : PhysicalValueShape,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match self {
    Unit => Unit
    Slot(key) => key
    Product(_, _) =>
      raise RepresentationSpecializationInvariant(
        detail="a callable result cannot expose a multi-value aggregate contract",
      )
  }
}

///|
fn PhysicalAnfProgram::append_parameter_keys(
  self : PhysicalAnfProgram,
  shape : PhysicalValueShapeId,
  parameters : Array[CanonicalRuntimeTypeKey],
) -> Unit raise LoisvmLoweringError {
  match self.shape(shape) {
    Unit => ()
    Slot(key) => parameters.push(key)
    Product(_, fields) =>
      for field in fields {
        self.append_parameter_keys(field, parameters)
      }
  }
}

///|
priv struct PhysicalValuePortPlan {
  binding : @anf.AnfBindingId
  contract : PhysicalValueContract
  callable_instance : CallableRepresentationTarget?
  callable_worker : Bool
  mut evidence_application : DeferredEvidenceApplication?
}

///|
priv struct PhysicalValueFlowPlan {
  source : PhysicalValueContract
  target : PhysicalValueContract
  bridge : PhysicalValueBridge?
}

///|
priv struct PhysicalBindingFlowPlan {
  binding : @anf.AnfBindingId
  target_type : @anf.RuntimeType
  flow : PhysicalValueFlowPlan
}

///|
/// The physical boundary of one Runtime ANF body. The body result is produced
/// by the expression plan, rather than reconstructed from its declaration.
priv struct PhysicalParameterPlan {
  binding : @anf.AnfBindingId
  type_ : @anf.RuntimeType
  contract : PhysicalValueContract
}

///|
priv struct PhysicalRecursiveFunctionPlan {
  recursive : RecursiveFunctionPlan
  shape : PhysicalValueShapeId
}

///|
priv struct PhysicalFunctionPlan {
  interface : PhysicalCallableInterface
  evidence_parameters : Array[@anf.RuntimeEvidenceParameter]
  substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  capture : CallableCaptureContract
  parameters : Array[PhysicalParameterPlan]
  recursive_functions : Array[PhysicalRecursiveFunctionPlan]
  result_type : @anf.RuntimeType
  result : PhysicalValueFlowPlan
  body : PhysicalAnfExpr
}

///|
priv struct PhysicalRepresentationCallTarget {
  instance : CallableInstance
  worker : RepresentationSpecializationPlan
  substitutions : RuntimeSubstitution
  invocation : PhysicalRepresentationInvocation
}

///|
priv enum PhysicalRepresentationInvocation {
  Direct
  Captured(@anf.AnfFunctionId)
}

///|
priv struct PhysicalCallPlan {
  site : @anf.AnfBindingId
  target : PhysicalRepresentationCallTarget?
  callable_arguments : Array[CallableRepresentationTarget?]
  invocation : CanonicalCallableAbi
  witnesses : Array[RuntimeEvidencePlan]
  parameter_types : Array[@anf.RuntimeType]
  arguments : Array[PhysicalValueFlowPlan]
  abi_result_evidence : RuntimeEvidencePlan?
  abi_result_type : @anf.RuntimeType
  result_type : @anf.RuntimeType
  result : PhysicalValueFlowPlan
}

///|
priv struct PhysicalCallableSemantics {
  substitutions : RuntimeSubstitution
  witnesses : Array[RuntimeEvidencePlan]
  parameter_types : Array[@anf.RuntimeType]
  result_type : @anf.RuntimeType
}

///|
priv struct PhysicalCallableAllocationPlan {
  function : @anf.AnfFunctionId
  callable : CallableRepresentationTarget
  implementation : PhysicalCallableImplementation
  interface : PhysicalCallableInterface
  captures : Array[PhysicalValueFlowPlan]
}

///|
priv enum PhysicalCallableImplementation {
  Generic(Int)
  Worker(@bytecode.FunctionId)
} derive(Debug, Eq)

///|
priv enum PhysicalValueBridge {
  Erase(PhysicalErasureBridge)
  Unerase(CallableAdapterContract?)
  Callable(CallableAdapterContract)
}

///|
priv struct PhysicalErasureBridge {
  evidence : RuntimeEvidencePlan
  callable : CallableAdapterContract?
}

///|
priv struct PhysicalConstructPlan {
  data_constructor : @buslane.DataConId
  representation : PhysicalConstructRepresentation
  callable_payloads : Array[CallableRepresentationTarget?]
  payloads : Array[PhysicalValueFlowPlan]
}

///|
priv enum PhysicalConstructRepresentation {
  Product(ClosedAggregateContract)
  Data(DataRepresentationFamilyPlan)
}

///|
priv struct PhysicalMatchPlan {
  site : @anf.AnfBindingId
  scrutinee : PhysicalValueShapeId
  result : PhysicalValueShapeId
  alternatives : Array[PhysicalMatchAlternativePlan]
}

///|
priv struct PhysicalMatchAlternativePlan {
  alternative_constructor : @buslane.AltCon
  payloads : Array[PhysicalMatchPayloadPlan]
  result : PhysicalValueFlowPlan
}

///|
priv struct PhysicalMatchPayloadPlan {
  type_ : @anf.RuntimeType
  flow : PhysicalValueFlowPlan
}

///|
priv struct DeferredEvidenceApplication {
  binding : @anf.AnfBindingId
  source_type : @anf.RuntimeType
  target_type : @anf.RuntimeType
  arguments : Array[@anf.RuntimeArgument]
  materialize : Bool
  adapter : CallableAdapterContract?
  interface : PhysicalCallableInterface
}

///|
/// A verified physical program. Function identities are allocated by the
/// function-table owner; value-shape identities are allocated only here.
priv struct PhysicalAnfProgram {
  shapes : Array[PhysicalValueShape]
  invocations : Array[(@bytecode.FunctionId, CanonicalCallableAbi)]
  interfaces : Array[(@bytecode.FunctionId, PhysicalCallableInterface)]
  globals : Array[(@buslane.ValueId, PhysicalValueContract)]
  functions : Array[(@bytecode.FunctionId, PhysicalFunctionPlan)]
  representation_workers : Array[RepresentationSpecializationPlan]
  adapter_contracts : Array[CallableAdapterContract]
  layout_constructors : Array[@anf.RuntimeEvidence]
}

///|
priv struct PhysicalFunctionPlanner {
  image : ImageLowerer
  physical : PhysicalAnfProgram
  source_function : @anf.AnfFunctionId?
  mut substitutions : RuntimeSubstitution
  specialized_parameters : Array[@anf.RuntimeEvidenceId]
  flow_instances : Array[Int]
  scalar_owners : Array[CallableRepresentationOwner]
  representation_owners : Array[CallableRepresentationOwner]
  representation_contract : RepresentationSpecializationKey?
  excluded_data_components : Array[Int]
  excluded_callable_components : Array[Int]
  ports : Array[PhysicalValuePortPlan]
  callable_allocations : Array[PhysicalCallableAllocationPlan]
  atoms : Array[(@anf.AnfBindingId, @anf.AnfAtom)]
  types : Array[(@anf.AnfBindingId, @anf.RuntimeType)]
}

///|
fn PhysicalAnfProgram::new() -> PhysicalAnfProgram {
  {
    shapes: [],
    invocations: [],
    interfaces: [],
    globals: [],
    functions: [],
    representation_workers: [],
    adapter_contracts: [],
    layout_constructors: [],
  }
}

///|
fn PhysicalAnfProgram::add_global(
  self : PhysicalAnfProgram,
  value : @buslane.ValueId,
  contract : PhysicalValueContract,
) -> Unit raise LoisvmLoweringError {
  if self.globals.any(entry => entry.0 == value) {
    raise RepresentationSpecializationInvariant(
      detail="one global value received two physical producer contracts",
    )
  }
  self.globals.push((value, contract))
}

///|
fn PhysicalAnfProgram::global(
  self : PhysicalAnfProgram,
  value : @buslane.ValueId,
) -> PhysicalValueContract? {
  for entry in self.globals {
    if entry.0 == value {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PhysicalAnfProgram::record_adapter_contract(
  self : PhysicalAnfProgram,
  contract : CallableAdapterContract,
) -> Unit {
  if self.adapter_contracts.any(existing => existing.recipe == contract.recipe) {
    return
  }
  self.adapter_contracts.push(contract)
  for nested in contract.nested_adapters {
    self.record_adapter_contract(nested)
  }
}

///|
fn PhysicalAnfProgram::record_bridge_support(
  self : PhysicalAnfProgram,
  bridge : PhysicalValueBridge,
) -> Unit {
  match bridge {
    Erase({ callable: Some(contract), .. })
    | Unerase(Some(contract))
    | Callable(contract) => self.record_adapter_contract(contract)
    Erase({ callable: None, .. }) | Unerase(None) => ()
  }
}

///|
fn PhysicalAnfProgram::record_runtime_argument(
  self : PhysicalAnfProgram,
  argument : @anf.RuntimeArgument,
) -> Unit {
  if argument.evidence is Lambda(_, _) &&
    !self.layout_constructors.contains(argument.evidence) {
    self.layout_constructors.push(argument.evidence)
  }
}

///|
fn PhysicalAnfProgram::has_adapter_recipe(
  self : PhysicalAnfProgram,
  recipe : CallableAdapterRecipe,
) -> Bool {
  self.adapter_contracts.any(contract => contract.recipe == recipe)
}

///|
fn PhysicalAnfProgram::intern(
  self : PhysicalAnfProgram,
  shape : PhysicalValueShape,
) -> PhysicalValueShapeId {
  for index, candidate in self.shapes {
    if candidate == shape {
      return { index, }
    }
  }
  let identity : PhysicalValueShapeId = { index: self.shapes.length(), }
  self.shapes.push(shape)
  identity
}

///|
fn PhysicalAnfProgram::shape(
  self : PhysicalAnfProgram,
  identity : PhysicalValueShapeId,
) -> PhysicalValueShape raise LoisvmLoweringError {
  match self.shapes.get(identity.index) {
    Some(shape) => shape
    None =>
      raise RepresentationSpecializationInvariant(
        detail="physical value port names an unknown shape",
      )
  }
}

///|
fn PhysicalAnfProgram::identity(
  self : PhysicalAnfProgram,
  shape : PhysicalValueShape,
  provenance : String,
) -> PhysicalValueShapeId raise LoisvmLoweringError {
  for index, candidate in self.shapes {
    if candidate == shape {
      return { index, }
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="\{provenance} produced physical shape \{Repr(shape)} absent from the frozen plan",
  )
}

///|
fn PhysicalAnfProgram::add_function(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
  plan : PhysicalFunctionPlan,
) -> Unit raise LoisvmLoweringError {
  if self.functions.any(entry => entry.0 == function) {
    raise RepresentationSpecializationInvariant(
      detail="one emitted function received two physical plans",
    )
  }
  self.add_interface(function, plan.interface)
  ignore(
    self.intern(
      PhysicalValueShape::Slot(
        CanonicalRuntimeTypeKey::Callable(plan.interface.invocation),
      ),
    ),
  )
  self.functions.push((function, plan))
}

///|
fn PhysicalAnfProgram::add_invocation(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
  invocation : CanonicalCallableAbi,
) -> Unit raise LoisvmLoweringError {
  for existing in self.invocations {
    if existing.0 == function {
      if existing.1 != invocation {
        raise RepresentationSpecializationInvariant(
          detail="callable implementation \{Repr(function)} received physical invocation contracts \{Repr(existing.1)} and \{Repr(invocation)}",
        )
      }
      return
    }
  }
  self.invocations.push((function, invocation))
}

///|
fn PhysicalAnfProgram::add_interface(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
  interface : PhysicalCallableInterface,
) -> Unit raise LoisvmLoweringError {
  for existing in self.interfaces {
    if existing.0 == function {
      if existing.1 != interface {
        raise RepresentationSpecializationInvariant(
          detail="callable implementation \{Repr(function)} received two physical interface contracts",
        )
      }
      return
    }
  }
  self.add_invocation(function, interface.invocation)
  self.interfaces.push((function, interface))
}

///|
fn PhysicalAnfProgram::interface(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
) -> PhysicalCallableInterface? {
  for entry in self.interfaces {
    if entry.0 == function {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PhysicalAnfProgram::invocation(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
) -> CanonicalCallableAbi? {
  for entry in self.invocations {
    if entry.0 == function {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PhysicalAnfProgram::required_invocation(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  self
  .invocation(function)
  .unwrap_or_else(() => {
    raise RepresentationSpecializationInvariant(
      detail="generic function body \{Repr(function)} has no frozen invocation contract",
    )
  })
}

///|
fn ImageLowerer::ensure_generic_callable_invocation(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  let generic = self.generic_callable_representation_target(callable)
  guard generic is Semantic(instance) &&
    self.generic_callable_instance_implementation(instance)
    is Some(implementation) else {
    raise RepresentationSpecializationInvariant(
      detail="callable representation has no generic physical implementation",
    )
  }
  self.ensure_generic_function_interface(instance, implementation.function).invocation
}

///|
fn ImageLowerer::ensure_generic_function_invocation(
  self : ImageLowerer,
  instance : Int,
  implementation : @bytecode.FunctionId,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  self.ensure_generic_function_interface(instance, implementation).invocation
}

///|
fn ImageLowerer::ensure_generic_function_interface(
  self : ImageLowerer,
  instance : Int,
  implementation : @bytecode.FunctionId,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  guard self.physical_anf is Some(physical) else {
    raise RepresentationSpecializationInvariant(
      detail="generic callable invocation was requested outside physical representation planning",
    )
  }
  guard self.callable_instances.instances.get(instance) is Some(requested) &&
    self.callable_instances.generic_instance(requested.definition.function.id)
    is Some(instance) else {
    raise RepresentationSpecializationInvariant(
      detail="generic callable invocation has no canonical fallback instance",
    )
  }
  if physical.interface(implementation) is Some(interface) {
    return interface
  }
  if self.generic_invocations_in_progress.contains(implementation) {
    raise RepresentationSpecializationInvariant(
      detail="generic higher-order invocation contracts recursively expand through \{Repr(implementation)}",
    )
  }
  self.generic_invocations_in_progress.push(implementation)
  let interface = self.plan_generic_callable_interface(instance, implementation)
  ignore(self.generic_invocations_in_progress.pop())
  physical.add_interface(implementation, interface)
  interface
}

///|
fn ImageLowerer::plan_generic_callable_interface(
  self : ImageLowerer,
  instance : Int,
  implementation : @bytecode.FunctionId,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  guard self.callable_instances.instances.get(instance) is Some(_) else {
    raise RepresentationSpecializationInvariant(
      detail="generic invocation names an unknown callable instance",
    )
  }
  let mut selected : PlannedFunction? = None
  for candidate in self.plans.entries {
    if candidate.function == implementation {
      selected = Some(candidate)
      break
    }
  }
  guard selected is Some(selected) else {
    raise RepresentationSpecializationInvariant(
      detail="generic invocation has no planned function implementation",
    )
  }
  let (function, type_, substitutions) = match selected.entry {
    Function(value, function) => {
      guard self.metadata.value_info(value) is Some(info) else {
        raise RepresentationSpecializationInvariant(
          detail="generic top-level callable has no declared type",
        )
      }
      (function, info.type_, RuntimeSubstitution::new())
    }
    LiftedFunction(plan) => (plan.function, plan.type_, plan.substitutions)
    _ =>
      raise RepresentationSpecializationInvariant(
        detail="generic invocation points at a non-generic function variant",
      )
  }
  let (_, parameter_types, _) = function_type_parts(type_)
  if function.parameters.length() != parameter_types.length() {
    raise RepresentationSpecializationInvariant(
      detail="generic invocation parameter arity does not match Runtime ANF",
    )
  }
  self.canonical_callable_interface_under(type_, substitutions)
}

///|
fn PhysicalAnfProgram::function(
  self : PhysicalAnfProgram,
  function : @bytecode.FunctionId,
) -> PhysicalFunctionPlan? {
  for entry in self.functions {
    if entry.0 == function {
      return Some(entry.1)
    }
  }
  None
}

///|
fn ImageLowerer::physical_function(
  self : ImageLowerer,
  function : @bytecode.FunctionId,
) -> PhysicalFunctionPlan? {
  self.physical_anf.bind(plan => plan.function(function))
}

///|
fn ImageLowerer::physical_capture(
  self : ImageLowerer,
  function : @bytecode.FunctionId,
) -> CallableCaptureContract raise LoisvmLoweringError {
  guard self.physical_function(function) is Some(plan) else {
    raise RepresentationSpecializationInvariant(
      detail="emitted callable has no physical function variant",
    )
  }
  plan.capture
}

///|
fn ImageLowerer::physical_invocation(
  self : ImageLowerer,
  function : @bytecode.FunctionId,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  guard self.physical_anf.bind(plan => plan.invocation(function))
    is Some(invocation) else {
    raise RepresentationSpecializationInvariant(
      detail="emitted callable \{Repr(function)} with origins \{Repr(self.plans.entries.filter_map(planned => if planned.function == function { Some(planned.origin) } else { None }))} has no physical invocation contract",
    )
  }
  invocation
}

///|
fn PhysicalFunctionPlan::parameter(
  self : PhysicalFunctionPlan,
  index : Int,
  physical : PhysicalAnfProgram,
) -> PhysicalValueShape raise LoisvmLoweringError {
  guard self.parameters.get(index) is Some(parameter) else {
    raise RepresentationSpecializationInvariant(
      detail="VM CFG emission requested an unknown physical parameter",
    )
  }
  physical.shape(parameter.contract.shape)
}

///|
fn PhysicalFunctionPlan::authorizes_bridge(
  self : PhysicalFunctionPlan,
  contract : CallableAdapterContract,
) -> Bool {
  self.callable_bridge_recipes().contains(contract.recipe)
}

///|
fn PhysicalFunctionPlan::callable_bridge_recipes(
  self : PhysicalFunctionPlan,
) -> Array[CallableAdapterRecipe] {
  let recipes = []
  self.result.append_callable_bridge_recipes(recipes)
  self.body.append_callable_bridge_recipes(recipes)
  recipes
}

///|
fn PhysicalValueFlowPlan::append_callable_bridge_recipes(
  self : PhysicalValueFlowPlan,
  recipes : Array[CallableAdapterRecipe],
) -> Unit {
  match self.bridge {
    Some(Callable(planned))
    | Some(Erase({ callable: Some(planned), .. }))
    | Some(Unerase(Some(planned))) => planned.append_recipes(recipes)
    Some(Erase(_)) | Some(Unerase(None)) | None => ()
  }
}

///|
fn CallableAdapterContract::append_recipes(
  self : CallableAdapterContract,
  recipes : Array[CallableAdapterRecipe],
) -> Unit {
  if !recipes.contains(self.recipe) {
    recipes.push(self.recipe)
  }
  for nested in self.nested_adapters {
    nested.append_recipes(recipes)
  }
}

///|
fn FunctionLowerer::apply_physical_binding_flow(
  self : FunctionLowerer,
  planned : PhysicalBindingFlowPlan,
  value : PhysicalLocalValue,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  guard self.image.physical_anf is Some(_) else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF binding flow has no owning physical plan",
    )
  }
  let adapted = match planned.flow.bridge {
    None => value
    Some(bridge) =>
      self.materialize_planned_value_flow(
        "Physical ANF binding flow at \{Repr(planned.binding)}",
        value,
        planned.target_type,
        planned.flow.target,
        Some(bridge),
      )
  }
  { value: adapted.value, contract: planned.flow.target, }
}

///|
fn FunctionLowerer::materialize_physical_function_result(
  self : FunctionLowerer,
  result : PhysicalLocalValue,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  guard self.physical is Some(function) && self.image.physical_anf is Some(_) else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF function has no owning physical result plan",
    )
  }
  self.materialize_planned_value_flow(
    "Runtime ANF function result",
    result,
    function.result_type,
    function.result.target,
    function.result.bridge,
  )
}

///|
fn FunctionLowerer::physical_parameter_shape(
  self : FunctionLowerer,
  index : Int,
) -> PhysicalValueShape raise LoisvmLoweringError {
  guard self.physical is Some(function) &&
    self.image.physical_anf is Some(physical) else {
    raise RepresentationSpecializationInvariant(
      detail="represented function has no owning physical plan",
    )
  }
  function.parameter(index, physical)
}

///|
fn FunctionLowerer::physical_shape(
  self : FunctionLowerer,
  identity : PhysicalValueShapeId,
) -> PhysicalValueShape raise LoisvmLoweringError {
  guard self.image.physical_anf is Some(physical) else {
    raise RepresentationSpecializationInvariant(
      detail="represented function has no owning physical plan",
    )
  }
  physical.shape(identity)
}

///|
fn FunctionLowerer::materialize_physical_match_alternative(
  self : FunctionLowerer,
  match_ : PhysicalAnfMatch,
  alternative : PhysicalAnfAlternative,
  result : PhysicalLocalValue,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  self.materialize_physical_match_alternative_plan(
    alternative.plan,
    match_.plan.site,
    match_.result_type,
    alternative,
    result,
  )
}

///|
fn FunctionLowerer::materialize_physical_match_alternative_plan(
  self : FunctionLowerer,
  planned : PhysicalMatchAlternativePlan,
  site : @anf.AnfBindingId,
  result_type : @anf.RuntimeType,
  alternative : PhysicalAnfAlternative,
  result : PhysicalLocalValue,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  ignore(alternative)
  self.materialize_planned_call_argument(
    site,
    result,
    result_type,
    planned.result.target,
    planned.result.bridge,
  )
}

///|
fn FunctionLowerer::fresh_planned_optional_slot(
  self : FunctionLowerer,
  type_ : @anf.RuntimeType,
  shape : PhysicalValueShape,
) -> (@vmcfg.ValueId?, LocalValue) raise LoisvmLoweringError {
  let type_ = self.instantiate_runtime_type(type_)
  match shape {
    Unit => (None, Unit)
    Product(_, _) =>
      raise RepresentationSpecializationInvariant(
        detail="a control-flow join cannot encode a product shape in one VM CFG value",
      )
    Slot(key) => {
      let erased_companion = match key {
        Value({ cleanup: OwnedErased, .. }) => {
          guard type_ is Erased(_, evidence) else {
            raise RepresentationSpecializationInvariant(
              detail="an erased physical port has no runtime evidence",
            )
          }
          Some(self.layout_witness(evidence))
        }
        _ => None
      }
      let slot = self.fresh_metadata(key.value_metadata(erased_companion))
      (Some(slot), LocalValue::Slot(slot, type_, key))
    }
  }
}

///|
fn CanonicalRuntimeTypeKey::value_metadata(
  self : CanonicalRuntimeTypeKey,
  erased_companion : @vmcfg.ValueId?,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  let abi = match self {
    Unit =>
      raise RepresentationSpecializationInvariant(
        detail="Unit has no VM CFG value metadata",
      )
    Value(abi) => abi
    Callable(_) =>
      { representation: I64, cleanup: OwnedCallable, kind: CallableValue, }
  }
  let ownership : @vmcfg.Ownership = if abi.cleanup is Trivial {
    Trivial
  } else {
    Owned
  }
  {
    representation: abi.representation,
    cleanup: abi.cleanup,
    kind: abi.kind,
    ownership,
    erased_companion,
  }
}

///|
fn CanonicalRuntimeTypeKey::borrowed_value_metadata(
  self : CanonicalRuntimeTypeKey,
  erased_companion : @vmcfg.ValueId?,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  let metadata = self.value_metadata(erased_companion)
  if metadata.cleanup is Trivial {
    metadata
  } else {
    { ..metadata, ownership: Borrowed, }
  }
}

///|
fn CanonicalRuntimeTypeKey::physical_shape(
  self : CanonicalRuntimeTypeKey,
) -> PhysicalValueShape {
  match self {
    Unit => Unit
    key => Slot(key)
  }
}

///|
fn PhysicalValueShape::result_abi(
  self : PhysicalValueShape,
) -> @bytecode.ResultAbi raise LoisvmLoweringError {
  match self {
    Unit => Unit
    Slot(Unit) =>
      raise RepresentationSpecializationInvariant(
        detail="Unit cannot be nested in a physical slot shape",
      )
    Slot(Value(abi)) => Value(abi.representation, abi.cleanup, abi.kind)
    Slot(Callable(_)) => Value(I64, OwnedCallable, CallableValue)
    Product(_, _) =>
      raise RepresentationSpecializationInvariant(
        detail="a function result cannot expose an unlowered product shape",
      )
  }
}

///|
fn FunctionLowerer::physical_shape_of_type(
  self : FunctionLowerer,
  type_ : @anf.RuntimeType,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  self.image.canonical_runtime_type_key_under(
    self.instantiate_runtime_type(type_),
    RuntimeSubstitution::new(),
  )
}

///|
fn FunctionLowerer::slot_value(
  self : FunctionLowerer,
  slot : @vmcfg.ValueId,
  type_ : @anf.RuntimeType,
) -> LocalValue raise LoisvmLoweringError {
  Slot(slot, type_, self.physical_shape_of_type(type_))
}

///|
fn PhysicalFunctionPlanner::append_port(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
  shape : PhysicalValueShape,
  callable_interface : PhysicalCallableInterface?,
  origin : String,
  fields? : Array[PhysicalValueContract] = [],
  evidence_application? : DeferredEvidenceApplication? = None,
) -> PhysicalValueShapeId raise LoisvmLoweringError {
  match (shape, callable_interface) {
    (Slot(Callable(invocation)), Some(interface)) if interface.invocation ==
      invocation => ()
    (Slot(Callable(_)), _) | (_, Some(_)) =>
      raise RepresentationSpecializationInvariant(
        detail="\{origin} physical value port \{Repr(binding)} interface \{Repr(callable_interface)} disagrees with shape \{Repr(shape)}",
      )
    (_, None) => ()
  }
  let identity = self.physical.intern(shape)
  let contract = self.physical.value_contract(
    identity, callable_interface, fields, origin,
  )
  let callable_instance = self.callable_at_port(binding)
  let callable_worker = self.callable_port_uses_worker(binding)
  for port in self.ports {
    if port.binding == binding {
      if port.contract != contract ||
        port.callable_instance != callable_instance ||
        port.callable_worker != callable_worker {
        raise RepresentationSpecializationInvariant(
          detail="one Runtime ANF value port received two physical shapes",
        )
      }
      if evidence_application is Some(application) {
        match port.evidence_application {
          None => port.evidence_application = Some(application)
          Some(_) =>
            raise RepresentationSpecializationInvariant(
              detail="one Runtime ANF value port received two evidence-application views",
            )
        }
      }
      return identity
    }
  }
  self.ports.push({
    binding,
    contract,
    callable_instance,
    callable_worker,
    evidence_application,
  })
  identity
}

///|
fn PhysicalFunctionPlanner::preplan_physical_bridge(
  self : PhysicalFunctionPlanner,
  origin : String,
  site : @anf.AnfBindingId?,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  source_shape : PhysicalValueShape,
  target_shape : PhysicalValueShape,
  source_callable : CallableRepresentationTarget?,
  target_callable : CallableRepresentationTarget?,
  source_interface : PhysicalCallableInterface?,
  target_interface : PhysicalCallableInterface?,
) -> PhysicalValueBridge? raise LoisvmLoweringError {
  if source_shape == target_shape {
    return None
  }
  let source_is_erased = source_shape
    is Slot(Value({ cleanup: OwnedErased, .. }))
  let target_is_erased = target_shape
    is Slot(Value({ cleanup: OwnedErased, .. }))
  if target_is_erased && !source_is_erased {
    let source = substitutions.apply_type(self.image.runtime_types, source_type)
    let (evidence_type, callable) = match source_shape {
      Slot(Callable(source_abi)) => {
        if !(self.image.runtime_type(source)
          is Concrete(Callable(_, _) | Forall(_, _))) &&
          source_callable is None {
          raise RepresentationSpecializationInvariant(
            detail="\{origin} callable erasure at \{Repr(site)} in callable instances \{Repr(self.representation_owners)} has no semantic callable provenance for \{Repr(source_type)} under \{Repr(substitutions)}",
          )
        }
        let callable_type = self.image.callable_erasure_source_type(
          source_type, substitutions, source_callable,
        )
        guard source_interface is Some(source_interface) &&
          source_interface.invocation == source_abi else {
          raise RepresentationSpecializationInvariant(
            detail="\{origin} callable erasure at \{Repr(site)} has no exact physical callable interface",
          )
        }
        (
          callable_type,
          self.image.plan_callable_erasure_adaptation(
            callable_type, source_interface,
          ),
        )
      }
      _ => (source, None)
    }
    let bridge = PhysicalValueBridge::Erase({
      evidence: self.image.plan_layout_witness(
        runtime_type_evidence(evidence_type),
      ),
      callable,
    })
    self.physical.record_bridge_support(bridge)
    return Some(bridge)
  }
  if source_is_erased && !target_is_erased {
    let callable = match target_shape {
      Slot(Callable(target_abi)) => {
        guard target_interface is Some(target_interface) &&
          target_interface.invocation == target_abi else {
          raise RepresentationSpecializationInvariant(
            detail="\{origin} callable unerasure at \{Repr(site)} has no exact physical callable interface",
          )
        }
        self.image.plan_erased_callable_adaptation(
          target_type, substitutions, target_callable, target_interface,
        )
      }
      _ =>
        self.image.plan_value_adaptation(
          source_type, target_type, substitutions,
        )
    }
    let bridge = PhysicalValueBridge::Unerase(callable)
    self.physical.record_bridge_support(bridge)
    return Some(bridge)
  }
  if source_shape is Slot(Value({ kind: DataValue(source_family), .. })) &&
    target_shape is Slot(Value({ kind: DataValue(target_family), .. })) {
    let source_key = self.image.data_family_by_bytecode_id(source_family).key
    let target_key = self.image.data_family_by_bytecode_id(target_family).key
    raise RepresentationSpecializationInvariant(
      detail="\{origin} identity-preserving data flow in \{Repr(self.source_function)} at \{Repr(site)} in \{self.representation_owners.length()} callable instances \{Repr(self.representation_owners)} with representation worker \{self.representation_contract is Some(_)} and excluded data components \{Repr(self.excluded_data_components)} crosses \{Repr(source_key)} / \{Repr(source_type)} and \{Repr(target_key)} / \{Repr(target_type)}",
    )
  }
  if source_shape is Slot(Value({ kind: DataValue(_), .. })) ||
    target_shape is Slot(Value({ kind: DataValue(_), .. })) {
    raise RepresentationSpecializationInvariant(
      detail="\{origin} identity-preserving data flow in \{Repr(self.source_function)} at \{Repr(site)} in \{self.representation_owners.length()} callable instances \{Repr(self.representation_owners)} crosses \{Repr(source_type)} / \{Repr(source_shape)} and \{Repr(target_type)} / \{Repr(target_shape)}",
    )
  }
  let contract = try {
    match (source_shape, target_shape) {
      (Slot(Callable(source_abi)), Slot(Callable(target_abi))) =>
        self.image.plan_callable_representation_adaptation(
          source_callable, target_callable, source_type, target_type, substitutions,
          source_abi, target_abi, source_interface, target_interface,
        )
      _ =>
        self.image.plan_value_adaptation(
          source_type, target_type, substitutions,
        )
    }
  } catch {
    error =>
      raise RepresentationSpecializationInvariant(
        detail="\{origin} physical flow at \{Repr(site)} in callable instances \{Repr(self.representation_owners)} with callable provenance \{Repr((source_callable, target_callable))} cannot adapt \{Repr(source_type)} / \{Repr(source_shape)} to \{Repr(target_type)} / \{Repr(target_shape)}: \{Repr(error)}",
      )
  }
  guard contract is Some(contract) else {
    raise RepresentationSpecializationInvariant(
      detail="\{origin} physical flow at \{Repr(site)} from \{Repr(source_type)} / \{Repr(source_shape)} to \{Repr(target_type)} / \{Repr(target_shape)} has no representation bridge",
    )
  }
  let bridge = PhysicalValueBridge::Callable(contract)
  self.physical.record_bridge_support(bridge)
  Some(bridge)
}

///|
fn PhysicalFunctionPlanner::preplan_physical_value_flow_with_interfaces(
  self : PhysicalFunctionPlanner,
  origin : String,
  site : @anf.AnfBindingId?,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  source_shape : PhysicalValueShape,
  target_shape : PhysicalValueShape,
  source_callable : CallableRepresentationTarget?,
  target_callable : CallableRepresentationTarget?,
  source_interface : PhysicalCallableInterface?,
  target_interface : PhysicalCallableInterface?,
  source_fields? : Array[PhysicalValueContract] = [],
  target_fields? : Array[PhysicalValueContract] = [],
) -> PhysicalValueFlowPlan raise LoisvmLoweringError {
  {
    source: self.physical.value_contract(
      self.physical.intern(source_shape),
      source_interface,
      source_fields,
      "\{origin} source",
    ),
    target: self.physical.value_contract(
      self.physical.intern(target_shape),
      target_interface,
      target_fields,
      "\{origin} target",
    ),
    bridge: self.preplan_physical_bridge(
      origin, site, source_type, target_type, substitutions, source_shape, target_shape,
      source_callable, target_callable, source_interface, target_interface,
    ),
  }
}

///|
/// Complete a boundary flow from the contract already owned by structural
/// Physical ANF. This keeps the expression producer contract authoritative;
/// only the consumer-side contract and bridge are created here.
fn PhysicalFunctionPlanner::preplan_physical_contract_flow(
  self : PhysicalFunctionPlanner,
  origin : String,
  site : @anf.AnfBindingId?,
  source : PhysicalValueContract,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
  target_shape : PhysicalValueShape,
  source_callable : CallableRepresentationTarget?,
  target_callable : CallableRepresentationTarget?,
  target_interface : PhysicalCallableInterface?,
) -> PhysicalValueFlowPlan raise LoisvmLoweringError {
  let source_shape = self.physical.shape(source.shape)
  let target = self.physical.value_contract(
    self.physical.intern(target_shape),
    target_interface,
    [],
    "\{origin} target",
  )
  {
    source,
    target,
    bridge: self.preplan_physical_bridge(
      origin,
      site,
      source_type,
      target_type,
      substitutions,
      source_shape,
      target_shape,
      source_callable,
      target_callable,
      source.callable_interface,
      target_interface,
    ),
  }
}

///|
fn physical_value_bridge_equal(
  left : PhysicalValueBridge,
  right : PhysicalValueBridge,
) -> Bool {
  match (left, right) {
    (Erase(left), Erase(right)) =>
      left.evidence == right.evidence &&
      (match (left.callable, right.callable) {
        (None, None) => true
        (Some(left), Some(right)) => left.recipe == right.recipe
        _ => false
      })
    (Unerase(left), Unerase(right)) =>
      match (left, right) {
        (None, None) => true
        (Some(left), Some(right)) => left.recipe == right.recipe
        _ => false
      }
    (Callable(left), Callable(right)) => left.recipe == right.recipe
    _ => false
  }
}

///|
fn physical_value_flow_equal(
  left : PhysicalValueFlowPlan,
  right : PhysicalValueFlowPlan,
) -> Bool {
  left.source == right.source &&
  left.target == right.target &&
  (match (left.bridge, right.bridge) {
    (None, None) => true
    (Some(left), Some(right)) => physical_value_bridge_equal(left, right)
    _ => false
  })
}

///|
fn PhysicalFunctionPlanner::record_type(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
  type_ : @anf.RuntimeType,
) -> Unit raise LoisvmLoweringError {
  for entry in self.types {
    if entry.0 == binding {
      if entry.1 != type_ {
        raise RepresentationSpecializationInvariant(
          detail="one Runtime ANF value port received two runtime types",
        )
      }
      return
    }
  }
  self.types.push((binding, type_))
}

///|
fn PhysicalFunctionPlanner::port_type(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
) -> @anf.RuntimeType? {
  for entry in self.types {
    if entry.0 == binding {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PhysicalFunctionPlanner::port_shape(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
) -> PhysicalValueShape? raise LoisvmLoweringError {
  for port in self.ports {
    if port.binding == binding {
      return Some(self.physical.shape(port.contract.shape))
    }
  }
  None
}

///|
fn PhysicalFunctionPlanner::port_contract(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
) -> PhysicalValueContract? {
  for port in self.ports {
    if port.binding == binding {
      return Some(port.contract)
    }
  }
  None
}

///|
fn PhysicalFunctionPlanner::callable_at_port(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
) -> CallableRepresentationTarget? {
  for port in self.ports {
    if port.binding == binding {
      return port.callable_instance
    }
  }
  if self.representation_contract is Some(contract) {
    for entry in contract.callable_ports {
      if entry.0 == binding {
        return Some(entry.1)
      }
    }
  }
  self.image.representation_solution.callable_instance_at_port(
    self.representation_owners,
    binding,
  )
}

///|
fn PhysicalFunctionPlanner::callable_at_allocation(
  self : PhysicalFunctionPlanner,
  function : @anf.AnfFunctionId,
) -> CallableRepresentationTarget? {
  self.image.representation_solution.callable_instance_at_allocation(
    self.representation_owners,
    function,
  )
}

///|
fn PhysicalFunctionPlanner::callable_allocation_uses_worker(
  self : PhysicalFunctionPlanner,
  function : @anf.AnfFunctionId,
) -> Bool {
  if self.representation_contract is Some(contract) {
    return contract.callable_allocations.any(entry => entry.0 == function)
  }
  self.image.representation_solution.callable_allocation_uses_worker(
    self.representation_owners,
    function,
    self.excluded_callable_components,
  )
}

///|
fn PhysicalFunctionPlanner::callable_port_uses_worker(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
) -> Bool {
  for port in self.ports {
    if port.binding == binding {
      return port.callable_worker
    }
  }
  if self.representation_contract is Some(contract) {
    return contract.callable_ports.any(entry => entry.0 == binding)
  }
  self.image.representation_solution.callable_port_uses_worker(
    self.representation_owners,
    binding,
    self.excluded_callable_components,
  )
}

///|
fn PhysicalFunctionPlanner::callable_at_argument(
  self : PhysicalFunctionPlanner,
  site : @anf.AnfBindingId,
  argument_index : Int,
) -> CallableRepresentationTarget? {
  if self.representation_contract is Some(contract) {
    for entry in contract.callable_arguments {
      if entry.0 == site && entry.1 == argument_index {
        return Some(entry.2)
      }
    }
  }
  self.image.representation_solution.callable_instance_at_argument(
    self.representation_owners,
    site,
    argument_index,
  )
}

///|
fn PhysicalFunctionPlanner::callable_at_result(
  self : PhysicalFunctionPlanner,
) -> CallableRepresentationTarget? {
  if self.representation_contract is Some(contract) &&
    contract.callable_result is Some(callable) {
    return Some(callable)
  }
  self.image.representation_solution.callable_instance_at_result(
    self.representation_owners,
  )
}

///|
fn ImageLowerer::elaborate_physical_anf(
  self : ImageLowerer,
) -> PhysicalAnfProgram raise LoisvmLoweringError {
  let physical = PhysicalAnfProgram::new()
  self.physical_anf = Some(physical)
  let generic_plan_count = self.plans.length()
  for index = 0; index < generic_plan_count; index = index + 1 {
    let planned = self.plans.get(index)
    match planned.entry {
      Function(_, function) => {
        guard self.callable_instances.generic_instance(function.id)
          is Some(instance) else {
          raise RepresentationSpecializationInvariant(
            detail="top-level callable has no generic semantic instance",
          )
        }
        ignore(
          self.ensure_generic_function_invocation(instance, planned.function),
        )
      }
      LiftedFunction(plan) =>
        ignore(
          self.ensure_generic_function_invocation(
            plan.instance,
            planned.function,
          ),
        )
      _ => ()
    }
  }
  self.plan_representation_specializations(physical, self.callable_instances)
  self.freeze_callable_representation_targets()
  self.predeclare_physical_invocations(physical)
  self.record_physical_global_contracts(physical)
  let mut index = 0
  while index < self.plans.length() {
    let planned = self.plans.get(index)
    match planned.entry {
      Function(value, function) => {
        guard self.metadata.value_info(value) is Some(info) &&
          self.callable_instances.generic_instance(function.id)
          is Some(instance) else {
          raise RepresentationSpecializationInvariant(
            detail="top-level callable lacks its semantic generic instance",
          )
        }
        let (evidence, parameters, result) = function_type_parts(info.type_)
        let representation_owner = callable_representation_owner(instance)
        let excluded_data_components = self.representation_solution.data_boundary_components(
          representation_owner,
          function.parameters,
        )
        let excluded_callable_components = self.representation_solution.callable_boundary_components(
          representation_owner,
          function.parameters,
          self.callable_instances.instances[instance].definition.captures,
        )
        physical.add_function(
          planned.function,
          self.plan_physical_function(
            physical,
            function,
            [instance],
            [representation_owner],
            [representation_owner],
            excluded_data_components,
            excluded_callable_components,
            RuntimeSubstitution::new(),
            [],
            evidence,
            parameters,
            result,
            Some(
              self.callable_interface_under_with_invocation(
                info.type_,
                RuntimeSubstitution::new(),
                physical.required_invocation(planned.function),
              ),
            ),
            CallableCaptureContract::empty(),
            [],
            [],
            None,
          ),
        )
      }
      LiftedFunction(plan) => {
        let (evidence, parameters, result) = function_type_parts(plan.type_)
        let representation_owner = callable_representation_owner(plan.instance)
        let excluded_data_components = self.representation_solution.data_boundary_components(
          representation_owner,
          plan.function.parameters,
        )
        let excluded_callable_components = self.representation_solution.callable_boundary_components(
          representation_owner,
          plan.function.parameters,
          self.callable_instances.instances[plan.instance].definition.captures,
        )
        physical.add_function(
          planned.function,
          self.plan_physical_function(
            physical,
            plan.function,
            [plan.instance],
            [representation_owner],
            [representation_owner],
            excluded_data_components,
            excluded_callable_components,
            plan.substitutions,
            plan.specialized_parameters,
            evidence,
            parameters,
            result,
            Some(
              self.callable_interface_under_with_invocation(
                plan.type_,
                plan.substitutions,
                physical.required_invocation(planned.function),
              ),
            ),
            self.plan_lifted_physical_capture(plan),
            [],
            plan.recursive_functions,
            None,
          ),
        )
      }
      RepresentationWorker(plan) => {
        let instance = plan.owner.source_instance()
        let representation_owner = CallableRepresentationOwner::Callable(
          plan.owner,
        )
        physical.add_function(
          planned.function,
          self.plan_physical_function(
            physical,
            plan.function,
            [instance],
            [representation_owner],
            [representation_owner],
            [],
            [],
            plan.substitutions,
            plan.specialized_parameters,
            plan.residual_parameters,
            plan.parameter_types,
            plan.result_type,
            Some(self.representation_worker_interface(plan)),
            self.plan_representation_worker_capture(plan),
            plan.scalar_parameters,
            plan.recursive_functions,
            Some(plan.key),
          ),
        )
      }
      InitializerStep(step) => {
        let planner : PhysicalFunctionPlanner = {
          image: self,
          physical,
          source_function: None,
          substitutions: RuntimeSubstitution::new(),
          specialized_parameters: [],
          flow_instances: [-1],
          scalar_owners: [CallableRepresentationOwner::TopLevel],
          representation_owners: [CallableRepresentationOwner::TopLevel],
          representation_contract: None,
          excluded_data_components: [],
          excluded_callable_components: [],
          ports: [],
          callable_allocations: [],
          atoms: [],
          types: [],
        }
        let (_, body) = planner.plan_physical_expr(step.expression, None)
        let (result_type, expected, result_callable) = match
          self.find_global(step.value) {
          Some(InstanceGlobal(_, type_, shape, callable)) =>
            (type_, shape.physical_shape(), callable)
          Some(UnitValue) =>
            (@anf.RuntimeType::Unit, PhysicalValueShape::Unit, None)
          _ =>
            raise RepresentationSpecializationInvariant(
              detail="initializer has no planned global physical contract",
            )
        }
        let source_type = planner.expression_result_type(step.expression)
        let result = planner.preplan_physical_contract_flow(
          "initializer-result",
          None,
          body.result_contract(),
          source_type,
          result_type,
          RuntimeSubstitution::new(),
          expected,
          planner.expression_result_callable_instance(step.expression),
          None,
          result_callable,
        )
        let interface : PhysicalCallableInterface = {
          evidence_parameters: [],
          parameter_types: [],
          result_type,
          invocation: {
            witnesses: [],
            parameters: [],
            result: expected.canonical_result(),
          },
          parameters: [],
          parameter_callables: [],
          result_callable,
        }
        interface.verify()
        physical.add_function(planned.function, {
          interface,
          evidence_parameters: [],
          substitutions: RuntimeSubstitution::new(),
          specialized_parameters: [],
          capture: CallableCaptureContract::empty(),
          parameters: [],
          recursive_functions: [],
          result_type,
          result,
          body,
        })
      }
      InitializerOrchestrator(_)
      | IntrinsicWrapper(_)
      | CallableAdapter(_)
      | LayoutConstructor(_)
      | RuntimeImport(_) => ()
    }
    index += 1
  }
  self.verify_physical_anf(physical)
  self.materialize_physical_representation_support(physical)
  while index < self.plans.length() {
    let planned = self.plans.get(index)
    match planned.entry {
      CallableAdapter(plan) =>
        physical.add_invocation(planned.function, plan.recipe.target_abi)
      LayoutConstructor(plan) =>
        physical.add_invocation(
          planned.function,
          layout_constructor_invocation(plan),
        )
      _ =>
        raise RepresentationSpecializationInvariant(
          detail="physical support materialization appended a non-support function",
        )
    }
    index += 1
  }
  physical
}

///|
fn ImageLowerer::predeclare_physical_invocations(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
) -> Unit raise LoisvmLoweringError {
  for planned in self.plans.entries {
    match planned.entry {
      Function(_, _) | LiftedFunction(_) => ()
      RepresentationWorker(plan) =>
        physical.add_interface(
          planned.function,
          self.representation_worker_interface(plan),
        )
      InitializerStep(step) => {
        let result = match self.find_global(step.value) {
          Some(InstanceGlobal(_, _, shape, _)) => shape
          Some(UnitValue) => CanonicalRuntimeTypeKey::Unit
          _ =>
            raise RepresentationSpecializationInvariant(
              detail="initializer has no planned global invocation result",
            )
        }
        physical.add_invocation(planned.function, {
          witnesses: [],
          parameters: [],
          result,
        })
      }
      InitializerOrchestrator(_) =>
        physical.add_invocation(planned.function, {
          witnesses: [],
          parameters: [],
          result: CanonicalRuntimeTypeKey::Unit,
        })
      IntrinsicWrapper(plan) =>
        physical.add_invocation(
          planned.function,
          self.canonical_callable_abi_under(
            plan.contract.type_(),
            RuntimeSubstitution::new(),
          ),
        )
      CallableAdapter(plan) =>
        physical.add_invocation(planned.function, plan.recipe.target_abi)
      LayoutConstructor(plan) =>
        physical.add_invocation(
          planned.function,
          layout_constructor_invocation(plan),
        )
      RuntimeImport(_) => {
        guard planned.origin is RuntimeImport(source~, ..) &&
          self.metadata.value_info(source) is Some(info) else {
          raise RepresentationSpecializationInvariant(
            detail="runtime import has no semantic callable contract",
          )
        }
        physical.add_invocation(
          planned.function,
          self.canonical_callable_abi_under(
            info.type_,
            RuntimeSubstitution::new(),
          ),
        )
      }
    }
  }
}

///|
fn ImageLowerer::materialize_physical_representation_support(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
) -> Unit raise LoisvmLoweringError {
  for evidence in physical.layout_constructors {
    ignore(self.plan_layout_constructor(evidence))
  }
  for contract in physical.adapter_contracts {
    self.preplan_callable_adapter(contract)
  }
}

///|
fn layout_constructor_invocation(
  plan : LayoutConstructorPlan,
) -> CanonicalCallableAbi {
  let parameters : Array[CanonicalRuntimeTypeKey] = []
  for parameter in plan.parameters {
    let metadata = runtime_evidence_metadata(parameter)
    parameters.push(
      CanonicalRuntimeTypeKey::Value({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      }),
    )
  }
  let result = layout_witness_metadata()
  {
    witnesses: [],
    parameters,
    result: CanonicalRuntimeTypeKey::Value({
      representation: result.representation,
      cleanup: result.cleanup,
      kind: result.kind,
    }),
  }
}

///|
fn ImageLowerer::representation_worker_definition(
  self : ImageLowerer,
  plan : RepresentationSpecializationPlan,
) -> @anf.AnfCallableDefinition raise LoisvmLoweringError {
  guard plan.owner.instance(self.callable_instances) is Some(instance) else {
    raise RepresentationSpecializationInvariant(
      detail="representation worker names an unknown callable instance",
    )
  }
  instance.definition
}

///|
fn ImageLowerer::plan_representation_worker_capture(
  self : ImageLowerer,
  plan : RepresentationSpecializationPlan,
) -> CallableCaptureContract raise LoisvmLoweringError {
  self.plan_callable_capture(
    [CallableRepresentationOwner::Callable(plan.owner)],
    self.representation_worker_definition(plan),
    plan.callable_type(),
    plan.substitutions,
    plan.specialized_parameters,
    [],
    [],
    physical_captures=Some(plan.key.captures),
  )
}

///|
fn ImageLowerer::plan_lifted_physical_capture(
  self : ImageLowerer,
  plan : LiftedFunctionPlan,
) -> CallableCaptureContract raise LoisvmLoweringError {
  let excluded_data_components = self.representation_solution.data_boundary_components(
    callable_representation_owner(plan.instance),
    plan.function.parameters,
  )
  let excluded_callable_components = self.representation_solution.callable_boundary_components(
    callable_representation_owner(plan.instance),
    plan.function.parameters,
    self.callable_instances.instances[plan.instance].definition.captures,
  )
  let members = if plan.recursive_functions.is_empty() {
    [plan]
  } else {
    self.lifted_functions.filter(candidate => {
      plan.recursive_functions.any(recursive => {
        recursive.function == candidate.lowered_function
      })
    })
  }
  let inputs = members.map(callable => {
    guard self.callable_instances.instances.get(callable.instance)
      is Some(instance) else {
      raise RepresentationSpecializationInvariant(
        detail="lifted callable has no semantic instance",
      )
    }
    CallableCaptureInput::{
      owners: [callable_representation_owner(instance.id)],
      definition: instance.definition,
      function_type: callable.type_,
      substitutions: callable.substitutions,
      specialized_parameters: callable.specialized_parameters,
    }
  })
  self.plan_callable_captures(
    inputs, excluded_data_components, excluded_callable_components,
  )
}

///|
fn ImageLowerer::plan_physical_function(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  function : @anf.AnfFunction,
  flow_instances : Array[Int],
  scalar_owners : Array[CallableRepresentationOwner],
  representation_owners : Array[CallableRepresentationOwner],
  excluded_data_components : Array[Int],
  excluded_callable_components : Array[Int],
  substitutions : RuntimeSubstitution,
  specialized_parameters : Array[@anf.RuntimeEvidenceId],
  evidence_parameters : Array[@anf.RuntimeEvidenceParameter],
  parameter_types : Array[@anf.RuntimeType],
  result_type : @anf.RuntimeType,
  expected_interface : PhysicalCallableInterface?,
  capture : CallableCaptureContract,
  scalar_parameters : Array[ScalarParameterPlan],
  recursive_functions : Array[RecursiveFunctionPlan],
  representation_contract : RepresentationSpecializationKey?,
) -> PhysicalFunctionPlan raise LoisvmLoweringError {
  if function.parameters.length() != parameter_types.length() {
    raise RepresentationSpecializationInvariant(
      detail="physical function parameter arity does not match Runtime ANF",
    )
  }
  for entry in substitutions.entries {
    physical.record_runtime_argument(entry.1)
  }
  let planner : PhysicalFunctionPlanner = {
    image: self,
    physical,
    source_function: Some(function.id),
    substitutions,
    specialized_parameters,
    flow_instances,
    scalar_owners,
    representation_owners,
    representation_contract,
    excluded_data_components,
    excluded_callable_components,
    ports: [],
    callable_allocations: [],
    atoms: [],
    types: [],
  }
  let expected_invocation = expected_interface.map(interface => {
    interface.invocation
  })
  for captured in capture.captures {
    guard captured.shape is Some(shape) else { continue }
    let binding = match captured.binding {
      CaptureBinding::Value(value) => @anf.AnfBindingId::Value(value)
      CaptureBinding::Temp(temp) => @anf.AnfBindingId::Temp(temp)
    }
    planner.record_type(binding, captured.type_)
    let shape = shape.physical_shape()
    let interface = captured.callable_interface
    ignore(planner.append_port(binding, shape, interface, "capture"))
  }
  for recursive in recursive_functions {
    guard physical.interface(recursive.function) is Some(interface) else {
      raise RepresentationSpecializationInvariant(
        detail="recursive callable has no certified physical interface",
      )
    }
    let binding = @anf.AnfBindingId::Value(recursive.value)
    planner.record_type(binding, recursive.type_)
    ignore(
      planner.append_port(
        binding,
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(interface.invocation),
        ),
        Some(interface),
        "recursive callable",
      ),
    )
  }
  let parameters : Array[PhysicalParameterPlan] = []
  let mut physical_parameter_index = 0
  for index, parameter in function.parameters {
    let mut scalar : ClosedAggregateContract? = None
    for projection in scalar_parameters {
      if projection.parameter_index == index {
        scalar = Some(projection.contract)
        break
      }
    }
    let parameter_fields : Array[PhysicalValueContract] = []
    let shape = match scalar {
      Some(contract) => {
        let payloads = []
        for payload_type in contract.payload_types {
          if planner.shape_of_type(payload_type) is Unit {
            let identity = physical.intern(Unit)
            let field = physical.value_contract(
              identity,
              None,
              [],
              "aggregate parameter field",
            )
            payloads.push(field)
            parameter_fields.push(field)
            continue
          }
          let shape = match expected_invocation {
            Some(invocation) => {
              guard invocation.parameters.get(physical_parameter_index)
                is Some(key) else {
                raise RepresentationSpecializationInvariant(
                  detail="representation worker has too few aggregate parameters",
                )
              }
              key.physical_shape()
            }
            None => planner.shape_of_type(payload_type)
          }
          let identity = physical.intern(shape)
          let callable_interface = match shape {
            Slot(Callable(invocation)) =>
              self.callable_interface_for_type_with_invocation(
                payload_type, substitutions, invocation,
              )
            Unit | Slot(_) | Product(_, _) => None
          }
          let field = physical.value_contract(
            identity,
            callable_interface,
            [],
            "aggregate parameter field",
          )
          payloads.push(field)
          parameter_fields.push(field)
          physical_parameter_index += 1
        }
        PhysicalValueShape::Product(
          contract,
          payloads.map(payload => payload.shape),
        )
      }
      None => {
        let semantic = planner.shape_of_type(parameter_types[index])
        let port = match expected_invocation {
          Some(invocation) if !(semantic is Unit) => {
            guard invocation.parameters.get(physical_parameter_index)
              is Some(key) else {
              raise RepresentationSpecializationInvariant(
                detail="representation worker has too few parameters",
              )
            }
            key.physical_shape()
          }
          Some(_) => PhysicalValueShape::Unit
          None =>
            planner.shape_of_port(Value(parameter), parameter_types[index])
        }
        if port is Unit {
          PhysicalValueShape::Unit
        } else {
          physical_parameter_index += 1
          port
        }
      }
    }
    let parameter_type = match scalar {
      Some(contract) => contract.type_
      None => planner.instantiate_type(parameter_types[index])
    }
    planner.record_type(Value(parameter), parameter_type)
    let parameter_interface = match expected_interface {
      Some(interface) => interface.parameter_callables[index]
      None =>
        planner.callable_interface_at_port(
          Value(parameter),
          parameter_types[index],
          shape,
          substitutions,
        )
    }
    let parameter_shape = planner.append_port(
      Value(parameter),
      shape,
      parameter_interface,
      "function-parameter",
      fields=parameter_fields,
    )
    parameters.push({
      binding: Value(parameter),
      type_: parameter_type,
      contract: physical.value_contract(
        parameter_shape, parameter_interface, parameter_fields, "function parameter",
      ),
    })
  }
  let (produced, body) = planner.plan_physical_expr(
    function.body,
    planner.callable_at_result(),
  )
  let source_type = planner.expression_result_type(function.body)
  let result_type = planner.instantiate_type(result_type)
  let boundary_result = match expected_invocation {
    Some(invocation) => invocation.result.physical_shape()
    None => planner.shape_of_result(result_type)
  }
  if produced is Product(_, _) || boundary_result is Product(_, _) {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF function result has no single-slot invocation shape",
    )
  }
  let result = planner.preplan_physical_contract_flow(
    "function-result",
    None,
    body.result_contract(),
    source_type,
    result_type,
    RuntimeSubstitution::new(),
    boundary_result,
    planner.expression_result_callable_instance(function.body),
    planner.callable_at_result(),
    expected_interface.bind(interface => interface.result_callable),
  )
  let physical_parameters = []
  for parameter in parameters {
    physical.append_parameter_keys(
      parameter.contract.shape,
      physical_parameters,
    )
  }
  let witnesses : Array[@bytecode.ValueAbi] = []
  for parameter in evidence_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = runtime_evidence_metadata(parameter)
      witnesses.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
      })
    }
  }
  let invocation : CanonicalCallableAbi = {
    witnesses,
    parameters: physical_parameters,
    result: boundary_result.canonical_result(),
  }
  if expected_invocation is Some(expected) && invocation != expected {
    raise RepresentationSpecializationInvariant(
      detail="representation worker invocation contract disagrees with its planned physical ports: expected \{Repr(expected)}, planned \{Repr(invocation)}",
    )
  }
  guard expected_interface is Some(interface) else {
    raise RepresentationSpecializationInvariant(
      detail="physical callable function has no complete interface contract",
    )
  }
  {
    interface,
    evidence_parameters,
    substitutions,
    specialized_parameters,
    capture,
    parameters,
    recursive_functions: recursive_functions.map(recursive => {
      let shape = physical.intern(
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(
            physical.required_invocation(recursive.function),
          ),
        ),
      )
      { recursive, shape, }
    }),
    result_type,
    result,
    body,
  }
}

///|
fn PhysicalFunctionPlanner::shape_of_type(
  self : PhysicalFunctionPlanner,
  type_ : @anf.RuntimeType,
) -> PhysicalValueShape raise LoisvmLoweringError {
  let key = self.image.canonical_runtime_type_key_under(
    self.instantiate_type(type_),
    RuntimeSubstitution::new(),
  )
  match key {
    Unit => PhysicalValueShape::Unit
    key => PhysicalValueShape::Slot(key)
  }
}

///|
fn PhysicalFunctionPlanner::shape_of_result(
  self : PhysicalFunctionPlanner,
  type_ : @anf.RuntimeType,
) -> PhysicalValueShape raise LoisvmLoweringError {
  if self.representation_contract is Some(contract) {
    return contract.result.physical_shape()
  }
  let type_ = self.instantiate_type(type_)
  if self.callable_at_result() is Some(callable) {
    return PhysicalValueShape::Slot(
      CanonicalRuntimeTypeKey::Callable(
        self.callable_physical_abi(
          callable,
          worker=self.image.representation_solution.callable_result_uses_worker(
            self.representation_owners,
            self.excluded_callable_components,
          ),
        ),
      ),
    )
  }
  guard type_ is Data(owner, _) &&
    self.image.representation_solution.data_family_at_result_excluding(
      self.representation_owners,
      self.excluded_data_components,
    )
    is Some(family) &&
    family.owner() == owner else {
    return self.shape_of_type(type_)
  }
  PhysicalValueShape::Slot(self.image.canonical_data_family_key(family))
}

///|
fn PhysicalFunctionPlanner::selected_representation_worker(
  self : PhysicalFunctionPlanner,
  callable : CallableRepresentationTarget,
) -> RepresentationSpecializationPlan? {
  guard self.image.representation_specialization_for_callable(callable)
    is Some(plan) &&
    !plan.data_components.any(component => {
      self.excluded_data_components.contains(component)
    }) &&
    !plan.callable_components.any(component => {
      self.excluded_callable_components.contains(component)
    }) else {
    return None
  }
  Some(plan)
}

///|
fn PhysicalFunctionPlanner::callable_physical_abi(
  self : PhysicalFunctionPlanner,
  callable : CallableRepresentationTarget,
  worker~ : Bool,
) -> CanonicalCallableAbi raise LoisvmLoweringError {
  if worker && self.selected_representation_worker(callable) is Some(plan) {
    return self.image.representation_worker_invocation(plan)
  }
  self.image.generic_callable_representation_physical_abi(callable)
}

///|
fn PhysicalFunctionPlanner::shape_of_port(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
  type_ : @anf.RuntimeType,
) -> PhysicalValueShape raise LoisvmLoweringError {
  let type_ = self.instantiate_type(type_)
  if self.callable_at_port(binding) is Some(instance) {
    return PhysicalValueShape::Slot(
      CanonicalRuntimeTypeKey::Callable(
        self.callable_physical_abi(
          instance,
          worker=self.callable_port_uses_worker(binding),
        ),
      ),
    )
  }
  guard type_ is Data(owner, _) &&
    self.image.representation_solution.data_family_at_port_excluding(
      self.representation_owners,
      binding,
      self.excluded_data_components,
    )
    is Some(family) &&
    family.owner() == owner else {
    return self.shape_of_type(type_)
  }
  PhysicalValueShape::Slot(self.image.canonical_data_family_key(family))
}

///|
fn PhysicalFunctionPlanner::instantiate_type(
  self : PhysicalFunctionPlanner,
  type_ : @anf.RuntimeType,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  if runtime_type_mentions_any(type_, self.specialized_parameters, []) {
    self.substitutions.apply_type(self.image.runtime_types, type_)
  } else {
    type_
  }
}

///|
fn PhysicalFunctionPlanner::plan_physical_expr(
  self : PhysicalFunctionPlanner,
  expression : @anf.AnfExpr,
  result_callable : CallableRepresentationTarget?,
) -> (PhysicalValueShape, PhysicalAnfExpr) raise LoisvmLoweringError {
  match expression {
    Atom(atom) => {
      let shape = match result_callable {
        Some(callable) => self.planned_atom_shape(atom, Some(callable))
        None => {
          ignore(
            self.preplan_materialized_atom(
              atom,
              self.atom_callable_instance(atom),
            ),
          )
          self.atom_shape(atom)
        }
      }
      (
        shape,
        PhysicalAnfExpr::Atom(
          self.materialize_physical_atom(
            atom,
            result_callable,
            Some(self.physical.intern(shape)),
          ),
        ),
      )
    }
    Let(binding, body) => {
      let (produced, rhs) = self.plan_physical_rhs(binding.id(), binding.rhs())
      if self.port_type(binding.id()) is None {
        raise RepresentationSpecializationInvariant(
          detail="Runtime ANF value producer has no planned runtime type",
        )
      }
      let interface = self.callable_interface_at_port(
        binding.id(),
        self.port_type(binding.id()).unwrap(),
        produced,
        self.substitutions,
      )
      let fields = rhs.result_fields()
      let result_shape = self.append_port(
        binding.id(),
        produced,
        interface,
        "let-binding",
        fields~,
      )
      let result = self.physical.value_contract(
        result_shape, interface, fields, "let-binding",
      )
      let (body_shape, body) = self.plan_physical_expr(body, result_callable)
      (body_shape, PhysicalAnfExpr::Let({ binding, rhs, result, }, body))
    }
    LetRec(bindings, body) => {
      let physical_bindings : Array[PhysicalAnfRecursiveBinding] = []
      for binding in bindings {
        guard self.atom_type(binding.rhs) is Some(type_) else {
          raise RepresentationSpecializationInvariant(
            detail="recursive Runtime ANF binding has no runtime type",
          )
        }
        let port = @anf.AnfBindingId::Value(binding.id)
        let target_callable = self.callable_at_port(port)
        let callable = match target_callable {
          Some(callable) => Some(callable)
          None => self.atom_callable_instance(binding.rhs)
        }
        guard self.preplan_materialized_atom(binding.rhs, callable)
          is Some(allocation) else {
          raise RepresentationSpecializationInvariant(
            detail="recursive Runtime ANF binding has no callable allocation",
          )
        }
        let target_type = self.instantiate_type(type_)
        self.record_type(port, target_type)
        if target_callable is Some(callable) {
          guard self.image.callable_representation_implementation(
              callable,
              self.callable_port_uses_worker(port),
            )
            is Some(_) else {
            raise RepresentationSpecializationInvariant(
              detail="recursive first-class callable has no generic implementation",
            )
          }
        }
        let target_shape = match target_callable {
          Some(callable) =>
            PhysicalValueShape::Slot(
              CanonicalRuntimeTypeKey::Callable(
                self.callable_physical_abi(
                  callable,
                  worker=self.callable_port_uses_worker(port),
                ),
              ),
            )
          None => self.atom_shape(binding.rhs)
        }
        let source_shape = PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
        )
        let target_interface = match target_callable {
          Some(callable) =>
            Some(
              self.image.callable_representation_interface(
                callable,
                worker=self.callable_port_uses_worker(port),
              ),
            )
          None => Some(allocation.interface)
        }
        let flow = self.preplan_physical_value_flow_with_interfaces(
          "recursive-binding",
          Some(port),
          self.planned_argument_type(binding.rhs, Some(allocation.callable)),
          target_type,
          self.substitutions,
          source_shape,
          target_shape,
          Some(allocation.callable),
          target_callable,
          Some(allocation.interface),
          target_interface,
        )
        let binding_flow = { binding: port, target_type, flow, }
        ignore(
          self.append_port(
            port, target_shape, target_interface, "recursive-binding",
          ),
        )
        physical_bindings.push({
          id: binding.id,
          rhs: self.materialize_physical_atom(
            binding.rhs,
            target_callable,
            Some(flow.source.shape),
          ),
          flow: binding_flow,
        })
      }
      let (body_shape, body) = self.plan_physical_expr(body, result_callable)
      (body_shape, PhysicalAnfExpr::LetRec(physical_bindings, body))
    }
  }
}

///|
fn PhysicalFunctionPlanner::plan_physical_rhs(
  self : PhysicalFunctionPlanner,
  site : @anf.AnfBindingId,
  rhs : @anf.AnfRhs,
) -> (PhysicalValueShape, PhysicalAnfRhs) raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => {
      let source_atom = atom
      guard self.atom_type(atom) is Some(type_) else {
        raise RepresentationSpecializationInvariant(
          detail="Runtime ANF atom binding has no runtime type",
        )
      }
      self.record_type(site, self.instantiate_type(type_))
      let target_callable = self.callable_at_port(site)
      let requested_callable = match target_callable {
        Some(callable) => Some(callable)
        None => self.atom_callable_instance(atom)
      }
      let allocation = self.preplan_materialized_atom(atom, requested_callable)
      let source_callable = match allocation {
        Some(allocation) => Some(allocation.callable)
        None => self.atom_callable_instance(atom)
      }
      let source_interface = match allocation {
        Some(allocation) => Some(allocation.interface)
        None => self.planned_atom_callable_interface(atom, source_callable)
      }
      let source_shape = self.planned_atom_shape(atom, requested_callable)
      let target_shape = self.shape_of_port(site, self.instantiate_type(type_))
      let target_interface = self.callable_interface_at_port(
        site,
        self.instantiate_type(type_),
        target_shape,
        self.substitutions,
      )
      let flow = self.preplan_physical_value_flow_with_interfaces(
        "atom-binding",
        Some(site),
        self.planned_argument_type(atom, source_callable),
        self.instantiate_type(type_),
        self.substitutions,
        source_shape,
        target_shape,
        source_callable,
        target_callable,
        source_interface,
        target_interface,
      )
      let binding_flow : PhysicalBindingFlowPlan = {
        binding: site,
        target_type: self.instantiate_type(type_),
        flow,
      }
      if flow.bridge is None && flow.source == flow.target {
        self.atoms.push((site, atom))
      }
      (
        target_shape,
        PhysicalAnfRhs::Atom(
          self.materialize_physical_atom(
            source_atom,
            requested_callable,
            Some(flow.source.shape),
          ),
          binding_flow,
        ),
      )
    }
    ApplyEvidence(callee~, arguments~) => {
      let source_atom = self.resolved_atom(callee)
      let inherited = self.deferred_evidence_application(callee)
      let source_type = match inherited {
        Some(application) => application.source_type
        None =>
          self
          .atom_type(callee)
          .unwrap_or_else(() => {
            raise RepresentationSpecializationInvariant(
              detail="Runtime ANF evidence application has no semantic callee type",
            )
          })
      }
      let inherited_arguments = match inherited {
        Some(application) => application.arguments
        None => []
      }
      let applied = arguments.map(argument => {
        self.substitutions.apply_argument(self.image.runtime_types, argument)
      })
      for argument in applied {
        self.physical.record_runtime_argument(argument)
      }
      let type_ = self.applied_callable_type(callee, arguments)
      let source_type = self.instantiate_type(source_type)
      let all_arguments = inherited_arguments + applied
      let source_shape = self.planned_atom_shape(
        source_atom,
        self.atom_callable_instance(callee),
      )
      guard self.planned_atom_callable_interface(
          source_atom,
          self.atom_callable_instance(callee),
        )
        is Some(source_interface) &&
        source_shape ==
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(source_interface.invocation),
        ) else {
        raise RepresentationSpecializationInvariant(
          detail="evidence application source has no exact physical callable interface",
        )
      }
      let materialize = !self.callable_port_uses_worker(site) &&
        self.image.representation_solution.callable_port_requires_materialization(
          self.representation_owners,
          site,
        )
      let target_interface = if materialize {
        self.image.canonical_callable_interface_under(
          type_,
          RuntimeSubstitution::new(),
        )
      } else {
        self.image.callable_interface_semantic_view(
          source_interface,
          type_,
          RuntimeSubstitution::new(),
        )
      }
      let adapter = if materialize {
        self.plan_evidence_application_adapter(
          source_type, type_, all_arguments, source_interface, target_interface,
        )
      } else {
        None
      }
      if adapter is Some(adapter) {
        self.physical.record_adapter_contract(adapter)
      }
      let application : DeferredEvidenceApplication = {
        binding: site,
        source_type,
        target_type: type_,
        arguments: all_arguments,
        materialize,
        adapter,
        interface: target_interface,
      }
      self.record_type(site, type_)
      // Evidence application is a deferred invocation view over the same
      // runtime callable. Its arguments become witness operands at the call;
      // no zero-witness callable value is materialized here.
      let shape = if materialize {
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(target_interface.invocation),
        )
      } else {
        source_shape
      }
      ignore(
        self.append_port(
          site,
          shape,
          Some(target_interface),
          "evidence-application",
          evidence_application=Some(application),
        ),
      )
      (
        shape,
        PhysicalAnfRhs::ApplyEvidence({
          callee: self.materialize_physical_atom(
            source_atom,
            self.atom_callable_instance(callee),
            Some(self.physical.intern(source_shape)),
          ),
          arguments,
          application,
        }),
      )
    }
    Call(callee~, arguments~) => {
      let callee_substitutions = self.callable_substitutions(callee)
      let physical_callee = callee
      let callee_callable = self.atom_callable_instance(callee)
      let callable_arguments = Array::makei(arguments.length(), index => {
        self.callable_at_argument(site, index)
      })
      let representation_candidate = self.image
        .representation_call_target(self.flow_instances, site)
        .bind(pair => {
          if pair.1.data_components.any(component => {
              self.excluded_data_components.contains(component)
            }) {
            return None
          }
          match self.representation_invocation(callee, pair.0) {
            Some(Direct) => Some(pair)
            Some(Captured(_)) if self.callable_atom_uses_worker(callee) =>
              Some(pair)
            Some(Captured(_)) | None => None
          }
        })
      let target = representation_candidate
        .bind(pair => {
          if self.representation_invocation(callee, pair.0) is Some(invocation) {
            Some({
              instance: pair.0,
              worker: pair.1,
              substitutions: callee_substitutions.compose(
                pair.0.substitution,
                self.image.runtime_types,
              ),
              invocation,
            })
          } else {
            None
          }
        })
        .bind(target => {
          if self.representation_call_preserves_identity(
              site, arguments, callable_arguments, target,
            ) {
            Some(target)
          } else {
            None
          }
        })
      if target is None {
        for index, argument in arguments {
          if self.planned_atom_shape(argument, callable_arguments[index])
            is Product(_, _) {
            let candidate = match representation_candidate {
              None => "no representation worker"
              Some((instance, worker)) => {
                let sources = Array::makei(arguments.length(), argument_index => {
                  self.planned_atom_shape(
                    arguments[argument_index],
                    callable_arguments[argument_index],
                  )
                })
                "worker for instance \{instance.id} has source shapes \{Repr(sources)}, scalar parameters \{Repr(worker.scalar_parameters.map(parameter => parameter.parameter_index))}, and invocation \{Repr(self.image.representation_worker_invocation(worker))}"
              }
            }
            raise RepresentationSpecializationInvariant(
              detail="closed aggregate argument \{index} at \{Repr(site)} cannot enter the generic callable ABI because \{candidate}",
            )
          }
        }
      }
      let materializes = match physical_callee {
        Function(_) | EvidenceLambda(..) => true
        Ref(value) => self.port_shape(Value(value)) is None
        Temp(_) | Literal(_) => false
      }
      match target {
        Some({ invocation: Captured(_), .. }) =>
          if materializes {
            ignore(
              self.preplan_materialized_atom(physical_callee, callee_callable),
            )
          }
        Some({ invocation: Direct, .. }) => ()
        None =>
          if materializes {
            ignore(
              self.preplan_materialized_atom(physical_callee, callee_callable),
            )
          }
      }
      let callee_interface = self
        .planned_atom_callable_interface(callee, callee_callable)
        .unwrap_or_else(() => {
          raise RepresentationSpecializationInvariant(
            detail="Runtime ANF call producer lacks a callable physical interface",
          )
        })
      let callee_invocation = callee_interface.invocation
      let result_type = self.planned_call_result_type(callee, target)
      self.record_type(site, result_type)
      let invocation = match target {
        Some(target) =>
          self.image.representation_worker_invocation(target.worker)
        None => callee_invocation
      }
      let call_interface = self.physical_call_interface(
        callee_interface, target, invocation,
      )
      let semantics = self.callable_semantics(
        call_interface,
        match target {
          Some(target) => target.substitutions
          None =>
            self.callable_interface_substitutions(
              callee, call_interface, callee_substitutions,
            )
        },
      )
      let argument_flows = match target {
        Some(target) =>
          self.plan_representation_call_arguments(
            site, arguments, callable_arguments, target, call_interface,
          )
        None => {
          let source_shapes = []
          for index, argument in arguments {
            source_shapes.push(
              self.physical.intern(
                self.planned_atom_shape(argument, callable_arguments[index]),
              ),
            )
          }
          let argument_shapes = self.logical_callable_parameter_shapes(
            semantics.parameter_types,
            semantics.substitutions,
            arguments.length(),
            invocation,
          )
          self.preplan_call_value_flows(
            site, arguments, callable_arguments, source_shapes, argument_shapes,
            semantics, call_interface,
          )
        }
      }
      let abi_result = invocation.result.physical_shape()
      let result = self.shape_of_port(site, result_type)
      let result_callable = self.callable_at_port(site)
      let bridge_callable = if abi_result is Slot(Callable(_)) {
        target.bind(target => {
          self.image.representation_solution.callable_instance_at_result([
            CallableRepresentationOwner::Callable(target.worker.owner),
          ])
        })
      } else {
        result_callable
      }
      let target_result_interface = self.callable_interface_at_port(
        site,
        result_type,
        result,
        semantics.substitutions,
      )
      let result = self.preplan_physical_value_flow_with_interfaces(
        "call-result",
        Some(site),
        semantics.result_type,
        result_type,
        semantics.substitutions,
        abi_result,
        result,
        bridge_callable,
        result_callable,
        call_interface.result_callable,
        target_result_interface,
      )
      let abi_result_evidence = if abi_result
        is PhysicalValueShape::Slot(Value({ cleanup: OwnedErased, .. })) {
        Some(
          self.image.plan_layout_witness(
            runtime_type_evidence(
              semantics.substitutions.apply_type(
                self.image.runtime_types,
                semantics.result_type,
              ),
            ),
          ),
        )
      } else {
        None
      }
      let plan : PhysicalCallPlan = {
        site,
        target,
        callable_arguments,
        invocation,
        witnesses: semantics.witnesses,
        parameter_types: semantics.parameter_types,
        arguments: argument_flows,
        abi_result_evidence,
        abi_result_type: semantics.substitutions.apply_type(
          self.image.runtime_types,
          semantics.result_type,
        ),
        result_type,
        result,
      }
      let shape = self.physical.shape(result.target.shape)
      ignore(
        self.append_port(site, shape, target_result_interface, "call-result"),
      )
      (
        shape,
        PhysicalAnfRhs::Call({
          callee: self.materialize_physical_atom(callee, None, None),
          arguments: arguments.mapi((index, argument) => {
            self.materialize_physical_atom(
              argument,
              callable_arguments[index],
              Some(argument_flows[index].source.shape),
            )
          }),
          plan,
        }),
      )
    }
    Construct(construct) => {
      guard self.image.metadata.data_constructor_info(
          construct.data_constructor,
        )
        is Some(info) else {
        raise MissingDataConstructorMetadata(
          data_constructor=construct.data_constructor,
        )
      }
      guard self.image.metadata.type_info(info.owner) is Some(owner_info) else {
        raise MissingDataConstructorMetadata(
          data_constructor=construct.data_constructor,
        )
      }
      let type_arguments = construct.type_arguments.map(argument => {
        self.substitutions.apply_argument(self.image.runtime_types, argument)
      })
      let hidden_arguments = construct.hidden_arguments.map(argument => {
        self.substitutions.apply_argument(self.image.runtime_types, argument)
      })
      for argument in type_arguments {
        self.physical.record_runtime_argument(argument)
      }
      for argument in hidden_arguments {
        self.physical.record_runtime_argument(argument)
      }
      let construct_substitutions = RuntimeSubstitution::from_arguments(
        owner_info.evidence_parameters,
        type_arguments,
      ).overlay(
        RuntimeSubstitution::from_arguments(
          info.hidden_evidence_parameters,
          hidden_arguments,
        ),
      )
      self.record_type(site, Data(info.owner, type_arguments))
      let family_key = self.image.representation_solution
        .data_family_at_excluding(
          self.representation_owners,
          site,
          self.excluded_data_components,
        )
        .unwrap_or(Declaration(info.owner))
      let family = self.image.data_family(family_key)
      let scalar = self.image.representation_solution.scalar_allocation_contract(
        self.scalar_owners,
        site,
      )
      let callable_payloads = Array::makei(construct.payloads.length(), index => {
        self.image.representation_solution.data_callable_payload_instance_excluding(
          self.representation_owners,
          site,
          index,
          self.excluded_data_components,
        )
      })
      let payloads = []
      if scalar is Some(contract) {
        for index, target in contract.payload_types {
          let source_callable = self.planned_atom_callable_target(
            construct.payloads[index],
            callable_payloads[index],
          )
          let source_type = self.planned_argument_type(
            construct.payloads[index],
            source_callable,
          )
          let source_shape = self.planned_atom_shape(
            construct.payloads[index],
            source_callable,
          )
          let source_interface = self.planned_atom_callable_interface(
            construct.payloads[index],
            source_callable,
          )
          let target_interface = match target {
            Callable(_, _) | Forall(_, _) =>
              Some(
                self.image.canonical_callable_interface_under(
                  target,
                  self.substitutions,
                ),
              )
            _ => None
          }
          let target_shape = self.shape_of_runtime_value_type(target)
          payloads.push(
            self.preplan_physical_value_flow_with_interfaces(
              "scalar-construction-payload",
              Some(site),
              source_type,
              target,
              self.substitutions,
              source_shape,
              target_shape,
              source_callable,
              callable_payloads[index],
              source_interface,
              target_interface,
            ),
          )
        }
        let plan : PhysicalConstructPlan = {
          data_constructor: construct.data_constructor,
          representation: Product(contract),
          callable_payloads,
          payloads,
        }
        let shape = PhysicalValueShape::Product(
          contract,
          payloads.map(payload => payload.target.shape),
        )
        return (
          shape,
          PhysicalAnfRhs::Construct({
            construct,
            payloads: construct.payloads.mapi((index, payload) => {
              self.materialize_physical_atom(
                payload,
                callable_payloads[index],
                Some(payloads[index].source.shape),
              )
            }),
            plan,
          }),
        )
      }
      self.image.finalize_data_family_contract(family)
      guard family.constructor_plan(construct.data_constructor)
        is Some(constructor_plan) else {
        raise RepresentationSpecializationInvariant(
          detail="planned data family lacks its construction contract",
        )
      }
      for index, _ in info.payload_types {
        let payload = construct.payloads[index]
        let target_interface = constructor_plan.storage_callable_interfaces[index]
        let source_callable = self.planned_atom_callable_target(
          payload,
          callable_payloads[index],
        )
        let allocation = self.preplan_materialized_atom(
          payload, source_callable,
        )
        let source_shape = match allocation {
          Some(allocation) =>
            PhysicalValueShape::Slot(
              CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
            )
          None => self.planned_atom_shape(payload, source_callable)
        }
        let source_interface = match allocation {
          Some(allocation) => Some(allocation.interface)
          None => self.planned_atom_callable_interface(payload, source_callable)
        }
        let target_shape = constructor_plan.storage_shapes[index].physical_shape()
        if source_shape
          is PhysicalValueShape::Slot(
            Value({ kind: DataValue(source_family), .. })
          ) &&
          target_shape
          is PhysicalValueShape::Slot(
            Value({ kind: DataValue(target_family), .. })
          ) &&
          source_family != target_family {
          let source_key = self.image.data_family_by_bytecode_id(source_family).key
          let target_key = self.image.data_family_by_bytecode_id(target_family).key
          raise RepresentationSpecializationInvariant(
            detail="planned data allocation stores a value from \{Repr(source_key)} in a field owned by \{Repr(target_key)}",
          )
        }
        payloads.push(
          self.preplan_physical_value_flow_with_interfaces(
            "data-construction-payload",
            Some(site),
            self.planned_argument_type(payload, source_callable),
            constructor_plan.storage_types[index],
            construct_substitutions,
            source_shape,
            target_shape,
            source_callable,
            callable_payloads[index],
            source_interface,
            target_interface,
          ),
        )
      }
      let plan : PhysicalConstructPlan = {
        data_constructor: construct.data_constructor,
        representation: Data(family),
        callable_payloads,
        payloads,
      }
      let bytecode_family = self.image.materialize_data_family(family)
      let shape = PhysicalValueShape::Slot(
        Value({
          representation: I32,
          cleanup: OwnedRef,
          kind: DataValue(bytecode_family),
        }),
      )
      (
        shape,
        PhysicalAnfRhs::Construct({
          construct,
          payloads: construct.payloads.mapi((index, payload) => {
            self.materialize_physical_atom(
              payload,
              callable_payloads[index],
              Some(payloads[index].source.shape),
            )
          }),
          plan,
        }),
      )
    }
    Match(match_) => {
      let scrutinee = match_.scrutinee
      let scrutinee_callable = self.atom_callable_instance(scrutinee)
      ignore(self.preplan_materialized_atom(scrutinee, scrutinee_callable))
      let scrutinee_shape = self.atom_shape(match_.scrutinee)
      let scrutinee_aggregate = match scrutinee_shape {
        Product(contract, _) => Some(contract)
        _ => None
      }
      let scrutinee_interface = self.planned_atom_callable_interface(
        scrutinee, scrutinee_callable,
      )
      let physical_scrutinee = self.materialize_physical_atom(
        match_.scrutinee,
        None,
        Some(self.physical.intern(scrutinee_shape)),
      )
      ignore(
        self.append_port(
          Value(match_.binder),
          scrutinee_shape,
          scrutinee_interface,
          "match-scrutinee",
          fields=physical_scrutinee.contract.fields,
        ),
      )
      let (alternative_substitutions, alternative_payloads) = self.plan_match_payloads(
        site,
        match_,
        physical_scrutinee.contract,
      )
      let result_type = self.instantiate_type(match_.result_type)
      self.record_type(site, result_type)
      let result = self.shape_of_port(site, result_type)
      let result_interface = self.callable_interface_at_port(
        site,
        result_type,
        result,
        self.substitutions,
      )
      let alternatives = []
      let physical_alternatives : Array[PhysicalAnfAlternative] = []
      for index, alternative in match_.alternatives {
        if scrutinee_aggregate is Some(contract) &&
          !(alternative.alt_constructor is DataCon(data_constructor) &&
          data_constructor == contract.data_constructor) &&
          !(alternative.alt_constructor is Default &&
          !match_.alternatives.any(candidate => {
            candidate.alt_constructor is DataCon(data_constructor) &&
            data_constructor == contract.data_constructor
          })) {
          continue
        }
        guard alternative_substitutions.get(index) is Some(substitutions) else {
          raise RepresentationSpecializationInvariant(
            detail="Runtime ANF match alternative has no substitution scope",
          )
        }
        let outer_substitutions = self.substitutions
        self.substitutions = substitutions
        let (produced, body) = self.plan_physical_expr(
          alternative.body,
          self.callable_at_port(site),
        )
        let source_type = self.expression_result_type(alternative.body)
        let source_contract = body.result_contract()
        let alternative_plan : PhysicalMatchAlternativePlan = {
          alternative_constructor: alternative.alt_constructor,
          payloads: alternative_payloads[index],
          result: self.preplan_physical_value_flow_with_interfaces(
            "match-result",
            Some(site),
            source_type,
            result_type,
            RuntimeSubstitution::new(),
            produced,
            result,
            self.expression_result_callable_instance(alternative.body),
            self.callable_at_port(site),
            source_contract.callable_interface,
            result_interface,
            source_fields=source_contract.fields,
            target_fields=source_contract.fields,
          ),
        }
        alternatives.push(alternative_plan)
        physical_alternatives.push({
          alt_constructor: alternative.alt_constructor,
          evidence_binders: alternative.evidence_binders,
          value_binders: alternative.value_binders,
          body,
          plan: alternative_plan,
        })
        self.substitutions = outer_substitutions
      }
      let plan : PhysicalMatchPlan = {
        site,
        scrutinee: self.physical.intern(scrutinee_shape),
        result: self.physical.intern(result),
        alternatives,
      }
      (
        result,
        PhysicalAnfRhs::Match({
          scrutinee: physical_scrutinee,
          binder: match_.binder,
          result_type: match_.result_type,
          alternatives: physical_alternatives,
          plan,
        }),
      )
    }
  }
}

///|
fn PhysicalFunctionPlanner::plan_evidence_application_adapter(
  self : PhysicalFunctionPlanner,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  arguments : Array[@anf.RuntimeArgument],
  source_interface : PhysicalCallableInterface,
  target_interface : PhysicalCallableInterface,
) -> CallableAdapterContract? raise LoisvmLoweringError {
  let (parameters, _, _) = function_type_parts(source_type)
  if arguments.length() > parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="evidence application consumes more parameters than its callable declares",
    )
  }
  let substitutions = RuntimeSubstitution::new()
  for index, argument in arguments {
    substitutions.insert(parameters[index].id, argument)
  }
  self.image.plan_callable_adaptation_with_interfaces(
    source_type, target_type, substitutions, source_interface, target_interface,
  )
}

///|
fn PhysicalFunctionPlanner::expression_result_type(
  self : PhysicalFunctionPlanner,
  expression : @anf.AnfExpr,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  match expression {
    Atom(atom) => {
      let atom = self.resolved_atom(atom)
      let nested = match atom {
        Function(function) => Some(function)
        EvidenceLambda(body~, ..) => extract_top_function(body)
        Literal(_) | Ref(_) | Temp(_) => None
      }
      if nested is Some(function) {
        let callable = self.image.callable_representation_target(
          function.id,
          self.substitutions,
        )
        return self.image.callable_representation_semantic_type(callable)
      }
      let callable_instance = match atom {
        Ref(value) => self.callable_at_port(Value(value))
        Temp(temp) => self.callable_at_port(Temp(temp))
        Literal(_) | Function(_) | EvidenceLambda(..) => None
      }
      self.planned_argument_type(atom, callable_instance)
    }
    Let(_, body) | LetRec(_, body) => self.expression_result_type(body)
  }
}

///|
fn PhysicalFunctionPlanner::expression_result_callable_instance(
  self : PhysicalFunctionPlanner,
  expression : @anf.AnfExpr,
) -> CallableRepresentationTarget? raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.atom_callable_instance(atom)
    Let(_, body) | LetRec(_, body) =>
      self.expression_result_callable_instance(body)
  }
}

///|
fn PhysicalFunctionPlanner::atom_callable_instance(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
) -> CallableRepresentationTarget? raise LoisvmLoweringError {
  match atom {
    Ref(value) => self.callable_value_provenance(Value(value))
    Temp(temp) => self.callable_value_provenance(Temp(temp))
    Function(function) =>
      match self.callable_at_allocation(function.id) {
        Some(callable) => Some(callable)
        None =>
          Some(
            self.image.callable_representation_target(
              function.id,
              self.substitutions,
            ),
          )
      }
    EvidenceLambda(body~, ..) =>
      extract_top_function(body).map(function => {
        self
        .callable_at_allocation(function.id)
        .unwrap_or_else(() => {
          self.image.callable_representation_target(
            function.id,
            self.substitutions,
          )
        })
      })
    Literal(_) => None
  }
}

///|
fn PhysicalFunctionPlanner::planned_atom_callable_target(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
  planned : CallableRepresentationTarget?,
) -> CallableRepresentationTarget? raise LoisvmLoweringError {
  match materialized_function(atom) {
    Some(function) => Some(self.materialized_callable_target(function, planned))
    None => self.atom_callable_instance(atom)
  }
}

///|
fn PhysicalFunctionPlanner::callable_value_provenance(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
) -> CallableRepresentationTarget? {
  if self.callable_at_port(binding) is Some(callable) {
    return Some(callable)
  }
  None
}

///|
fn PhysicalFunctionPlanner::callable_atom_uses_worker(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
) -> Bool {
  let local_port = match atom {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Function(_) | EvidenceLambda(..) | Literal(_) => None
  }
  let is_local = local_port is Some(binding) &&
    self.ports.any(port => port.binding == binding)
  if atom is Ref(value) &&
    !is_local &&
    self.image.find_global(value) is Some(Function(_, _)) {
    return true
  }
  match atom {
    Ref(value) => self.callable_port_uses_worker(Value(value))
    Temp(temp) => self.callable_port_uses_worker(Temp(temp))
    Function(_) | EvidenceLambda(..) => true
    Literal(_) => false
  }
}

///|
fn PhysicalFunctionPlanner::planned_call_result_type(
  self : PhysicalFunctionPlanner,
  callee : @anf.AnfAtom,
  target : PhysicalRepresentationCallTarget?,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  if target is Some(target) {
    let (_, _, result) = function_type_parts(target.instance.definition.type_)
    return target.substitutions.apply_type(self.image.runtime_types, result)
  }
  let deferred = self.deferred_evidence_application(callee)
  match deferred {
    Some(application) => {
      let (parameters, _, result) = function_type_parts(application.source_type)
      let substitutions = self.substitutions.overlay(
        RuntimeSubstitution::from_arguments(parameters, application.arguments),
      )
      substitutions.apply_type(self.image.runtime_types, result)
    }
    None => {
      guard self.atom_type(callee) is Some(type_) else {
        raise RepresentationSpecializationInvariant(
          detail="Runtime ANF call has no semantic result type",
        )
      }
      let (_, _, result) = function_type_parts(self.instantiate_type(type_))
      self.instantiate_type(result)
    }
  }
}

///|
fn PhysicalFunctionPlanner::representation_invocation(
  self : PhysicalFunctionPlanner,
  callee : @anf.AnfAtom,
  target : CallableInstance,
) -> PhysicalRepresentationInvocation? {
  if target.definition.captures.is_empty() {
    return Some(Direct)
  }
  let port = match callee {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Literal(_) | Function(_) | EvidenceLambda(..) => None
  }
  if port.bind(binding => self.callable_at_port(binding)) is Some(_) {
    return None
  }
  let callee = self.resolved_atom(callee)
  let function = match callee {
    Function(function) => Some(function)
    EvidenceLambda(body~, ..) => extract_top_function(body)
    Literal(_) | Ref(_) | Temp(_) => None
  }
  match function {
    Some(function) if function.id == target.definition.function.id =>
      Some(Captured(function.id))
    _ => None
  }
}

///|
fn PhysicalFunctionPlanner::plan_representation_call_arguments(
  self : PhysicalFunctionPlanner,
  site : @anf.AnfBindingId,
  arguments : Array[@anf.AnfAtom],
  callable_arguments : Array[CallableRepresentationTarget?],
  target : PhysicalRepresentationCallTarget,
  interface : PhysicalCallableInterface,
) -> Array[PhysicalValueFlowPlan] raise LoisvmLoweringError {
  if arguments.length() != target.worker.parameter_types.length() {
    raise RepresentationSpecializationInvariant(
      detail="representation call arguments do not match its semantic worker contract",
    )
  }
  let flows = []
  let invocation = interface.invocation
  let mut physical_index = 0
  for index, formal in target.worker.parameter_types {
    let mut scalar : ClosedAggregateContract? = None
    for parameter in target.worker.scalar_parameters {
      if parameter.parameter_index == index {
        scalar = Some(parameter.contract)
        break
      }
    }
    match scalar {
      Some(contract) => {
        let payload_shapes = []
        for payload_type in contract.payload_types {
          let semantic_shape = self.shape_of_type(payload_type)
          if semantic_shape is Unit {
            payload_shapes.push(self.physical.intern(Unit))
            continue
          }
          guard invocation.parameters.get(physical_index) is Some(key) else {
            raise RepresentationSpecializationInvariant(
              detail="representation worker has too few physical aggregate parameters",
            )
          }
          payload_shapes.push(self.physical.intern(key.physical_shape()))
          physical_index += 1
        }
        let target_shape = PhysicalValueShape::Product(contract, payload_shapes)
        if self.planned_atom_shape(arguments[index], callable_arguments[index]) !=
          target_shape {
          raise RepresentationSpecializationInvariant(
            detail="closed aggregate call argument disagrees with its worker contract",
          )
        }
        let shape = self.physical.intern(target_shape)
        let contract = self.materialize_physical_atom(
            arguments[index],
            callable_arguments[index],
            Some(shape),
          ).contract
        flows.push({ source: contract, target: contract, bridge: None, })
      }
      None => {
        let actual = target.substitutions.apply_type(
          self.image.runtime_types,
          formal,
        )
        let semantic_shape = self.shape_of_type(actual)
        let target_shape = if semantic_shape is Unit {
          PhysicalValueShape::Unit
        } else {
          guard invocation.parameters.get(physical_index) is Some(key) else {
            raise RepresentationSpecializationInvariant(
              detail="representation worker has too few physical parameters",
            )
          }
          physical_index += 1
          key.physical_shape()
        }
        let source_type = self.planned_argument_type(
          arguments[index],
          callable_arguments[index],
        )
        let source_shape = self.planned_atom_shape(
          arguments[index],
          callable_arguments[index],
        )
        let source_callable = self.planned_atom_callable_target(
          arguments[index],
          callable_arguments[index],
        )
        flows.push(
          self.preplan_physical_value_flow_with_interfaces(
            "representation-call-argument",
            Some(site),
            source_type,
            formal,
            target.substitutions,
            source_shape,
            target_shape,
            source_callable,
            callable_arguments[index],
            self.planned_atom_callable_interface(
              arguments[index],
              source_callable,
            ),
            interface.parameter_callables[index],
          ),
        )
      }
    }
  }
  if physical_index != invocation.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="representation worker has unconsumed physical parameters",
    )
  }
  flows
}

///|
/// A direct representation worker may be selected only when every value that
/// crosses the call retains its identity. Callable and erased values can use
/// explicit bridge recipes; nominal families and scalar products cannot be
/// implicitly converted at a call boundary.
fn PhysicalFunctionPlanner::representation_call_preserves_identity(
  self : PhysicalFunctionPlanner,
  site : @anf.AnfBindingId,
  arguments : Array[@anf.AnfAtom],
  callable_arguments : Array[CallableRepresentationTarget?],
  target : PhysicalRepresentationCallTarget,
) -> Bool raise LoisvmLoweringError {
  if arguments.length() != target.worker.parameter_types.length() {
    return false
  }
  let interface = self.image.representation_worker_interface(target.worker)
  let invocation = interface.invocation
  let mut physical_index = 0
  for index, formal in target.worker.parameter_types {
    let mut scalar : ClosedAggregateContract? = None
    for parameter in target.worker.scalar_parameters {
      if parameter.parameter_index == index {
        scalar = Some(parameter.contract)
        break
      }
    }
    let target_shape = match scalar {
      Some(contract) => {
        let fields = []
        for payload_type in contract.payload_types {
          if self.shape_of_type(payload_type) is Unit {
            fields.push(self.physical.intern(Unit))
            continue
          }
          guard invocation.parameters.get(physical_index) is Some(key) else {
            return false
          }
          fields.push(self.physical.intern(key.physical_shape()))
          physical_index += 1
        }
        PhysicalValueShape::Product(contract, fields)
      }
      None => {
        let actual = target.substitutions.apply_type(
          self.image.runtime_types,
          target.worker.parameter_types[index],
        )
        if self.shape_of_type(actual) is Unit {
          PhysicalValueShape::Unit
        } else {
          guard invocation.parameters.get(physical_index) is Some(key) else {
            return false
          }
          physical_index += 1
          key.physical_shape()
        }
      }
    }
    let source_shape = self.planned_atom_shape(
      arguments[index],
      callable_arguments[index],
    )
    if source_shape != target_shape &&
      source_shape is Slot(Callable(source_abi)) &&
      target_shape is Slot(Callable(target_abi)) {
      let source_type = self.planned_argument_type(
        arguments[index],
        callable_arguments[index],
      )
      let adaptable = try {
        let source_callable = self.planned_atom_callable_target(
          arguments[index],
          callable_arguments[index],
        )
        ignore(
          self.image.plan_callable_representation_adaptation(
            source_callable,
            callable_arguments[index],
            source_type,
            formal,
            target.substitutions,
            source_abi,
            target_abi,
            self.planned_atom_callable_interface(
              arguments[index],
              source_callable,
            ),
            interface.parameter_callables[index],
          ),
        )
        true
      } catch {
        InvalidTypeApplication(_) => false
        error => raise error
      }
      if !adaptable {
        return false
      }
    }
    if !physical_flow_preserves_identity(source_shape, target_shape) {
      return false
    }
  }
  if physical_index != invocation.parameters.length() {
    return false
  }
  let target_result_type = target.substitutions.apply_type(
    self.image.runtime_types,
    target.worker.result_type,
  )
  let source_result = invocation.result.physical_shape()
  let target_result = self.shape_of_port(site, target_result_type)
  if !physical_flow_preserves_identity(source_result, target_result) {
    return false
  }
  true
}

///|
fn physical_flow_preserves_identity(
  source : PhysicalValueShape,
  target : PhysicalValueShape,
) -> Bool {
  if source == target {
    return true
  }
  match (source, target) {
    (Product(_, _), _) | (_, Product(_, _)) => false
    (Slot(Value({ kind: DataValue(_), .. })), _)
    | (_, Slot(Value({ kind: DataValue(_), .. }))) => false
    _ => true
  }
}

///|
fn PhysicalFunctionPlanner::preplan_call_value_flows(
  self : PhysicalFunctionPlanner,
  site : @anf.AnfBindingId,
  arguments : Array[@anf.AnfAtom],
  callable_arguments : Array[CallableRepresentationTarget?],
  source_shapes : Array[PhysicalValueShapeId],
  argument_shapes : Array[PhysicalValueShapeId],
  semantics : PhysicalCallableSemantics,
  interface : PhysicalCallableInterface,
) -> Array[PhysicalValueFlowPlan] raise LoisvmLoweringError {
  let parameters = semantics.parameter_types
  let substitutions = semantics.substitutions
  if parameters.length() != arguments.length() {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF call arguments do not match its semantic callable type",
    )
  }
  let flows = []
  for index, formal in parameters {
    guard argument_shapes.get(index) is Some(target_shape) else {
      raise RepresentationSpecializationInvariant(
        detail="callable invocation lacks a logical argument shape",
      )
    }
    guard source_shapes.get(index) is Some(source_shape) else {
      raise RepresentationSpecializationInvariant(
        detail="callable invocation lacks a source argument shape",
      )
    }
    let source_callable = self.planned_atom_callable_target(
      arguments[index],
      callable_arguments[index],
    )
    flows.push(
      self.preplan_physical_value_flow_with_interfaces(
        "call-argument",
        Some(site),
        self.planned_argument_type(arguments[index], callable_arguments[index]),
        formal,
        substitutions,
        self.physical.shape(source_shape),
        self.physical.shape(target_shape),
        source_callable,
        callable_arguments[index],
        self.planned_atom_callable_interface(arguments[index], source_callable),
        interface.parameter_callables[index],
      ),
    )
  }
  flows
}

///|
fn PhysicalFunctionPlanner::callable_substitutions(
  self : PhysicalFunctionPlanner,
  callee : @anf.AnfAtom,
) -> RuntimeSubstitution raise LoisvmLoweringError {
  let base_substitutions = match self.atom_callable_instance(callee) {
    Some(callable) if callable.instance(self.image.callable_instances)
      is Some(instance) =>
      self.substitutions.compose(
        instance.substitution,
        self.image.runtime_types,
      )
    _ => self.substitutions
  }
  let deferred = self.deferred_evidence_application(callee)
  match deferred {
    Some(application) => {
      let (parameters, _, _) = function_type_parts(application.source_type)
      if parameters.length() != application.arguments.length() {
        raise RepresentationSpecializationInvariant(
          detail="deferred evidence application does not close its callable type",
        )
      }
      base_substitutions.overlay(
        RuntimeSubstitution::from_arguments(parameters, application.arguments),
      )
    }
    None => base_substitutions
  }
}

///|
fn PhysicalFunctionPlanner::callable_interface_substitutions(
  self : PhysicalFunctionPlanner,
  callee : @anf.AnfAtom,
  interface : PhysicalCallableInterface,
  substitutions : RuntimeSubstitution,
) -> RuntimeSubstitution raise LoisvmLoweringError {
  guard self.deferred_evidence_application(callee) is Some(application) else {
    return substitutions
  }
  if interface.evidence_parameters.is_empty() {
    return substitutions
  }
  if interface.evidence_parameters.length() != application.arguments.length() {
    raise RepresentationSpecializationInvariant(
      detail="deferred evidence application does not match its physical callable interface",
    )
  }
  substitutions.overlay(
    RuntimeSubstitution::from_arguments(
      interface.evidence_parameters,
      application.arguments,
    ),
  )
}

///|
fn PhysicalFunctionPlanner::callable_semantics(
  self : PhysicalFunctionPlanner,
  interface : PhysicalCallableInterface,
  substitutions : RuntimeSubstitution,
) -> PhysicalCallableSemantics raise LoisvmLoweringError {
  let witnesses = interface.evidence_parameters.map(parameter => {
    self.image.plan_runtime_argument_evidence(
      parameter,
      required_runtime_argument(
        substitutions,
        self.image.runtime_types,
        parameter.id,
      ),
    )
  })
  {
    substitutions,
    witnesses,
    parameter_types: interface.parameter_types,
    result_type: interface.result_type,
  }
}

///|
/// Returns the complete callable interface selected for one physical call.
fn PhysicalFunctionPlanner::physical_call_interface(
  self : PhysicalFunctionPlanner,
  callee : PhysicalCallableInterface,
  target : PhysicalRepresentationCallTarget?,
  invocation : CanonicalCallableAbi,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  let interface = match target {
    Some(target) => self.image.representation_worker_interface(target.worker)
    None => callee
  }
  if interface.invocation != invocation {
    raise RepresentationSpecializationInvariant(
      detail="physical call interface disagrees with its selected invocation ABI",
    )
  }
  interface
}

///|
fn PhysicalFunctionPlanner::planned_atom_shape(
  self : PhysicalFunctionPlanner,
  argument : @anf.AnfAtom,
  callable_instance : CallableRepresentationTarget?,
) -> PhysicalValueShape raise LoisvmLoweringError {
  if materialized_function(argument) is Some(function) {
    let callable = self.materialized_callable_target(
      function, callable_instance,
    )
    let allocation = self.preplan_callable_allocation(function, callable)
    PhysicalValueShape::Slot(
      CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
    )
  } else {
    match (argument, callable_instance) {
      (Ref(value), planned) if self.port_shape(Value(value)) is None => {
        let allocation = self.preplan_materialized_atom(argument, planned)
        match allocation {
          Some(allocation) =>
            PhysicalValueShape::Slot(
              CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
            )
          None => self.atom_shape(argument)
        }
      }
      _ => self.atom_shape(argument)
    }
  }
}

///|
fn PhysicalFunctionPlanner::planned_atom_callable_interface(
  self : PhysicalFunctionPlanner,
  argument : @anf.AnfAtom,
  callable_instance : CallableRepresentationTarget?,
) -> PhysicalCallableInterface? raise LoisvmLoweringError {
  let local_port = match argument {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Function(_) | EvidenceLambda(..) | Literal(_) => None
  }
  if local_port is Some(binding) {
    for port in self.ports {
      if port.binding == binding {
        return port.contract.callable_interface
      }
    }
  }
  let shape = self.planned_atom_shape(argument, callable_instance)
  guard shape is PhysicalValueShape::Slot(Callable(invocation)) else {
    return None
  }
  if self.deferred_evidence_application(argument) is Some(application) &&
    application.interface.invocation == invocation {
    return Some(application.interface)
  }
  if argument is Ref(value) &&
    self.image.physical_global_contract(self.physical, value)
    is Some({ callable_interface: Some(interface), .. }) &&
    interface.invocation == invocation {
    return Some(interface)
  }
  if callable_instance is Some(callable) {
    let candidate = if materialized_function(argument) is Some(function) {
      let callable = self.materialized_callable_target(function, Some(callable))
      self.preplan_callable_allocation(function, callable).interface
    } else {
      self.image.callable_representation_interface(
        callable,
        worker=self.callable_atom_uses_worker(argument),
      )
    }
    if candidate.invocation == invocation {
      return Some(candidate)
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="physical callable atom \{Repr(argument)} with target \{Repr(callable_instance)} and invocation \{Repr(invocation)} has no certified producer interface",
  )
}

///|
fn PhysicalFunctionPlanner::callable_interface_at_port(
  self : PhysicalFunctionPlanner,
  binding : @anf.AnfBindingId,
  type_ : @anf.RuntimeType,
  shape : PhysicalValueShape,
  substitutions : RuntimeSubstitution,
) -> PhysicalCallableInterface? raise LoisvmLoweringError {
  guard shape is PhysicalValueShape::Slot(Callable(invocation)) else {
    return None
  }
  for port in self.ports {
    if port.binding == binding {
      guard port.contract.callable_interface is Some(interface) &&
        interface.invocation == invocation else {
        raise RepresentationSpecializationInvariant(
          detail="callable value port has no exact physical interface",
        )
      }
      return Some(interface)
    }
  }
  match self.callable_at_port(binding) {
    Some(callable) =>
      Some(
        self.image.callable_representation_interface(
          callable,
          worker=self.callable_port_uses_worker(binding),
        ),
      )
    None => {
      let interface = self.image.canonical_callable_interface_under(
        type_, substitutions,
      ) catch {
        error =>
          raise RepresentationSpecializationInvariant(
            detail="physical callable port \{Repr(binding)} cannot form its canonical interface from \{Repr(type_)} under \{Repr(substitutions)}: \{Repr(error)}",
          )
      }
      if interface.invocation != invocation {
        raise RepresentationSpecializationInvariant(
          detail="physical callable port has a non-canonical invocation without a representation owner",
        )
      }
      Some(interface)
    }
  }
}

///|
fn materialized_function(atom : @anf.AnfAtom) -> @anf.AnfFunction? {
  match atom {
    Function(function) => Some(function)
    EvidenceLambda(body~, ..) => extract_top_function(body)
    Literal(_) | Ref(_) | Temp(_) => None
  }
}

///|
fn PhysicalFunctionPlanner::materialized_callable_target(
  self : PhysicalFunctionPlanner,
  function : @anf.AnfFunction,
  planned : CallableRepresentationTarget?,
) -> CallableRepresentationTarget raise LoisvmLoweringError {
  let callable = match planned {
    Some(callable) => callable
    None =>
      self
      .callable_at_allocation(function.id)
      .unwrap_or_else(() => {
        self.image.callable_representation_target(
          function.id,
          self.substitutions,
        )
      })
  }
  callable
}

///|
fn PhysicalFunctionPlanner::shape_of_runtime_value_type(
  self : PhysicalFunctionPlanner,
  type_ : @anf.RuntimeType,
) -> PhysicalValueShape raise LoisvmLoweringError {
  let key = self.image.canonical_runtime_value_key(self.instantiate_type(type_))
  match key {
    Unit => Unit
    key => Slot(key)
  }
}

///|
fn PhysicalFunctionPlanner::logical_callable_parameter_shapes(
  self : PhysicalFunctionPlanner,
  parameters : Array[@anf.RuntimeType],
  substitutions : RuntimeSubstitution,
  argument_count : Int,
  invocation : CanonicalCallableAbi,
) -> Array[PhysicalValueShapeId] raise LoisvmLoweringError {
  if parameters.length() != argument_count {
    raise RepresentationSpecializationInvariant(
      detail="logical callable parameter arity disagrees with Runtime ANF",
    )
  }
  let shapes = []
  let mut physical_index = 0
  for parameter in parameters {
    let canonical = match
      self.image.canonical_runtime_value_key_under(
        parameter,
        RuntimeSubstitution::new(),
      ) {
      Unit => PhysicalValueShape::Unit
      key => PhysicalValueShape::Slot(key)
    }
    if canonical is Unit {
      shapes.push(self.physical.intern(Unit))
      continue
    }
    guard invocation.parameters.get(physical_index) is Some(key) else {
      raise RepresentationSpecializationInvariant(
        detail="callable invocation has too few physical parameters",
      )
    }
    shapes.push(self.physical.intern(key.physical_shape()))
    physical_index += 1
  }
  if physical_index != invocation.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="callable invocation \{Repr(invocation)} has \{invocation.parameters.length() - physical_index} unconsumed physical parameters after aligning \{Repr(parameters)} under \{Repr(substitutions)}",
    )
  }
  shapes
}

///|
fn PhysicalFunctionPlanner::planned_argument_type(
  self : PhysicalFunctionPlanner,
  argument : @anf.AnfAtom,
  callable_instance : CallableRepresentationTarget?,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  let source_instance = match argument {
    Ref(value) => self.callable_at_port(Value(value))
    Temp(temp) => self.callable_at_port(Temp(temp))
    Function(_) | EvidenceLambda(..) => callable_instance
    Literal(_) => None
  }
  if source_instance is Some(instance) {
    return self.image.callable_representation_semantic_type(instance)
  }
  let callable_type = match argument {
    Function(function) | EvidenceLambda(body=Atom(Function(function)), ..) => {
      let callable = self.image.callable_representation_target(
        function.id,
        self.substitutions,
      )
      self.image
      .callable_representation_implementation(callable, false)
      .map(implementation => implementation.type_)
    }
    Ref(value) =>
      match self.image.find_global(value) {
        Some(Function(_, _)) if callable_instance is Some(callable) =>
          Some(self.image.callable_representation_semantic_type(callable))
        Some(Function(_, type_)) => Some(type_)
        Some(Intrinsic(contract)) => Some(contract.type_())
        _ => None
      }
    Literal(_) | Temp(_) | EvidenceLambda(..) => None
  }
  if callable_type is Some(type_) {
    return type_
  }
  self
  .atom_type(argument)
  .map(type_ => self.instantiate_type(type_))
  .unwrap_or_else(() => {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF call argument has no semantic type",
    )
  })
}

///|
fn PhysicalFunctionPlanner::resolved_atom(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
) -> @anf.AnfAtom {
  let binding = match atom {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Literal(_) | Function(_) | EvidenceLambda(..) => None
  }
  guard binding is Some(binding) else { return atom }
  for entry in self.atoms.rev_iter() {
    if entry.0 == binding {
      return self.resolved_atom(entry.1)
    }
  }
  atom
}

///|
fn PhysicalFunctionPlanner::preplan_materialized_atom(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
  callable : CallableRepresentationTarget?,
) -> PhysicalCallableAllocationPlan? raise LoisvmLoweringError {
  let function = materialized_function(atom)
  if function is Some(function) {
    let callable = self.materialized_callable_target(function, callable)
    guard self.image.callable_representation_implementation(callable, false)
      is Some(_) else {
      raise RepresentationSpecializationInvariant(
        detail="first-class callable has no generic implementation",
      )
    }
    return Some(self.preplan_callable_allocation(function, callable))
  }
  let type_ = match atom {
    Ref(value) =>
      match self.image.find_global(value) {
        Some(Function(_, type_)) => Some(type_)
        Some(Intrinsic(contract)) => {
          ignore(self.image.intrinsic_wrapper(contract))
          Some(contract.type_())
        }
        _ => None
      }
    Literal(_) | Temp(_) | Function(_) | EvidenceLambda(..) => None
  }
  ignore(type_)
  None
}

///|
fn ImageLowerer::callable_capture_contract(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  selected : Bool,
) -> CallableCaptureContract raise LoisvmLoweringError {
  if selected &&
    self.representation_specialization_for_callable(callable) is Some(plan) {
    return self.plan_representation_worker_capture(plan)
  }
  guard self.callable_representation_implementation(callable, false)
    is Some(implementation) else {
    raise RepresentationSpecializationInvariant(
      detail="callable allocation has no generic implementation",
    )
  }
  for lifted in self.lifted_functions {
    if lifted.lowered_function == implementation.function {
      return self.plan_lifted_physical_capture(lifted)
    }
  }
  CallableCaptureContract::empty()
}

///|
fn ImageLowerer::physical_callable_implementation(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  selected : Bool,
) -> PhysicalCallableImplementation raise LoisvmLoweringError {
  if selected &&
    self.representation_specialization_for_callable(callable) is Some(plan) {
    return Worker(plan.worker)
  }
  guard self.generic_callable_representation_target(callable)
    is Semantic(instance) else {
    raise RepresentationSpecializationInvariant(
      detail="callable allocation has no generic physical implementation identity",
    )
  }
  Generic(instance)
}

///|
fn ImageLowerer::physical_callable_implementation_interface(
  self : ImageLowerer,
  callable : CallableRepresentationTarget,
  implementation : PhysicalCallableImplementation,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  match implementation {
    Generic(instance) => {
      guard self.generic_callable_representation_target(callable)
        is Semantic(expected) &&
        expected == instance else {
        raise RepresentationSpecializationInvariant(
          detail="generic callable allocation disagrees with its canonical fallback",
        )
      }
      self.callable_representation_interface(callable, worker=false)
    }
    Worker(function) => {
      guard self.representation_specialization_for_callable(callable)
        is Some(plan) &&
        plan.worker == function else {
        raise RepresentationSpecializationInvariant(
          detail="representation worker allocation has no matching callable interface",
        )
      }
      self.representation_worker_interface(plan)
    }
  }
}

///|
fn ImageLowerer::materialized_callable_implementation(
  self : ImageLowerer,
  implementation : PhysicalCallableImplementation,
) -> CallableInstanceImplementation raise LoisvmLoweringError {
  match implementation {
    Generic(instance) =>
      self
      .generic_callable_instance_implementation(instance)
      .unwrap_or_else(() => {
        raise RepresentationSpecializationInvariant(
          detail="planned generic callable allocation has no implementation",
        )
      })
    Worker(function) => {
      guard self.physical_anf is Some(physical) else {
        raise RepresentationSpecializationInvariant(
          detail="planned representation worker has no owning physical plan",
        )
      }
      for worker in physical.representation_workers {
        if worker.worker == function {
          return { function, type_: worker.callable_type(), }
        }
      }
      raise RepresentationSpecializationInvariant(
        detail="planned representation worker allocation has no contract",
      )
    }
  }
}

///|
fn PhysicalFunctionPlanner::preplan_callable_allocation(
  self : PhysicalFunctionPlanner,
  function : @anf.AnfFunction,
  callable : CallableRepresentationTarget,
) -> PhysicalCallableAllocationPlan raise LoisvmLoweringError {
  let selected = self.callable_allocation_uses_worker(function.id) &&
    self.selected_representation_worker(callable) is Some(_)
  let implementation = self.image.physical_callable_implementation(
    callable, selected,
  )
  let interface = self.image.physical_callable_implementation_interface(
    callable, implementation,
  )
  let capture = self.image.callable_capture_contract(callable, selected)
  let captures : Array[PhysicalValueFlowPlan] = []
  for target in capture.captures {
    let binding = match target.binding {
      CaptureBinding::Value(value) => @anf.AnfBindingId::Value(value)
      CaptureBinding::Temp(temp) => @anf.AnfBindingId::Temp(temp)
    }
    let source_type = match self.port_type(binding) {
      Some(type_) => type_
      None => {
        let source = match target.binding {
          CaptureBinding::Value(value) => @anf.AnfCapture::Value(value)
          CaptureBinding::Temp(temp) => @anf.AnfCapture::Temp(temp)
        }
        guard self.image.callable_catalog.capture_type(
            source,
            self.image.metadata,
          )
          is Some(type_) else {
          raise RepresentationSpecializationInvariant(
            detail="callable allocation capture has no semantic source type",
          )
        }
        type_
      }
    }
    let source_type = self.instantiate_type(source_type)
    let source_shape = self
      .port_shape(binding)
      .unwrap_or_else(() => self.shape_of_runtime_value_type(source_type))
    let target_shape = match target.shape {
      Some(shape) => shape.physical_shape()
      None => PhysicalValueShape::Unit
    }
    let callable = self.callable_at_port(binding)
    let source_interface = self.callable_interface_at_port(
      binding,
      source_type,
      source_shape,
      self.substitutions,
    )
    captures.push(
      self.preplan_physical_value_flow_with_interfaces(
        "callable capture",
        Some(binding),
        source_type,
        target.type_,
        self.substitutions,
        source_shape,
        target_shape,
        callable,
        callable,
        source_interface,
        target.callable_interface,
      ),
    )
  }
  for planned in self.callable_allocations {
    if planned.callable == callable {
      if planned.function != function.id ||
        planned.implementation != implementation ||
        planned.interface != interface {
        raise RepresentationSpecializationInvariant(
          detail="callable allocation \{Repr(function.id)} received both \{Repr(planned.callable)} via \{Repr(planned.implementation)} and \{Repr(callable)} via \{Repr(implementation)}",
        )
      }
      let mut equal = planned.captures.length() == captures.length()
      for index, existing in planned.captures {
        if !equal {
          break
        }
        equal = physical_value_flow_equal(existing, captures[index])
      }
      if !equal {
        raise RepresentationSpecializationInvariant(
          detail="one callable allocation received two physical capture contracts",
        )
      }
      return planned
    }
  }
  let allocation = {
    function: function.id,
    callable,
    implementation,
    interface,
    captures,
  }
  self.callable_allocations.push(allocation)
  allocation
}

///|
fn PhysicalFunctionPlanner::plan_match_payloads(
  self : PhysicalFunctionPlanner,
  site : @anf.AnfBindingId,
  match_ : @anf.AnfMatch,
  scrutinee : PhysicalValueContract,
) -> (Array[RuntimeSubstitution], Array[Array[PhysicalMatchPayloadPlan]]) raise LoisvmLoweringError {
  let scopes = match_.alternatives.map(_ => self.substitutions)
  let payloads : Array[Array[PhysicalMatchPayloadPlan]] = match_.alternatives.map(_ => {
      []
    },
  )
  if self.physical.shape(scrutinee.shape) is Product(contract, fields) {
    let mut selected : Int? = None
    let mut default : Int? = None
    for index, alternative in match_.alternatives {
      match alternative.alt_constructor {
        DataCon(data_constructor) if data_constructor ==
          contract.data_constructor => {
          selected = Some(index)
          break
        }
        Default => default = Some(index)
        _ => ()
      }
    }
    if selected is None {
      selected = default
    }
    guard selected is Some(selected) else {
      raise RepresentationSpecializationInvariant(
        detail="closed aggregate match has no selected alternative",
      )
    }
    let alternative = match_.alternatives[selected]
    if alternative.alt_constructor is DataCon(_) {
      if alternative.value_binders.length() != fields.length() ||
        fields.length() != contract.payload_types.length() {
        raise RepresentationSpecializationInvariant(
          detail="closed aggregate match payloads disagree with its product contract",
        )
      }
      for index, binder in alternative.value_binders {
        let type_ = contract.payload_types[index]
        guard scrutinee.fields.get(index) is Some(field) &&
          field.shape == fields[index] else {
          raise RepresentationSpecializationInvariant(
            detail="aggregate match payload has no producer contract",
          )
        }
        let flow : PhysicalValueFlowPlan = {
          source: field,
          target: field,
          bridge: None,
        }
        payloads[selected].push({ type_, flow, })
        self.record_type(Value(binder), type_)
        ignore(
          self.append_port(
            Value(binder),
            self.physical.shape(field.shape),
            field.callable_interface,
            "aggregate-match-payload",
          ),
        )
      }
    } else if !alternative.value_binders.is_empty() {
      raise RepresentationSpecializationInvariant(
        detail="closed aggregate default alternative binds payloads",
      )
    }
    return (scopes, payloads)
  }
  guard self.physical.shape(scrutinee.shape)
    is Slot(Value({ kind: DataValue(family_id), .. })) &&
    self.atom_type(match_.scrutinee) is Some(scrutinee_type) &&
    self.instantiate_type(scrutinee_type) is Data(owner, arguments) &&
    self.image.metadata.type_info(owner) is Some(owner_info) else {
    return (scopes, payloads)
  }
  let family = self.image.data_family_by_bytecode_id(family_id)
  self.image.finalize_data_family_contract(family)
  let owner_substitutions = RuntimeSubstitution::from_arguments(
    owner_info.evidence_parameters,
    arguments.map(argument => {
      self.substitutions.apply_argument(self.image.runtime_types, argument)
    }),
  )
  for alternative_index, alternative in match_.alternatives {
    if alternative.alt_constructor is Default {
      scopes[alternative_index] = self.substitutions.overlay(
        owner_substitutions,
      )
      continue
    }
    guard alternative.alt_constructor is DataCon(data_constructor) else {
      continue
    }
    guard self.image.metadata.data_constructor_info(data_constructor)
      is Some(info) &&
      family.constructor_plan(data_constructor) is Some(constructor_plan) &&
      alternative.value_binders.length() == info.payload_types.length() &&
      constructor_plan.storage_shapes.length() == info.payload_types.length() else {
      raise RepresentationSpecializationInvariant(
        detail="data match does not agree with its physical constructor contract",
      )
    }
    let hidden = RuntimeSubstitution::new()
    match constructor_plan.storage_hidden_arguments {
      Some(arguments) =>
        for index, parameter in info.hidden_evidence_parameters {
          guard arguments.get(index) is Some(argument) &&
            alternative.evidence_binders.get(index) is Some(binder) else {
            raise RepresentationSpecializationInvariant(
              detail="specialized data match lacks its planned hidden argument",
            )
          }
          hidden.insert(parameter.id, argument)
          hidden.insert(binder.id, argument)
        }
      None =>
        for index, parameter in info.hidden_evidence_parameters {
          guard alternative.evidence_binders.get(index) is Some(binder) &&
            self.image.metadata.parameter_type_expression(binder.id)
            is Some(type_expression) else {
            raise RepresentationSpecializationInvariant(
              detail="data match lacks a hidden physical evidence binder",
            )
          }
          hidden.insert(parameter.id, {
            type_expression,
            evidence: Parameter(binder.id),
          })
        }
    }
    let substitutions = owner_substitutions.overlay(hidden)
    scopes[alternative_index] = self.substitutions.overlay(substitutions)
    for index, binder in alternative.value_binders {
      let payload_type = substitutions.apply_type(
        self.image.runtime_types,
        info.payload_types[index],
      )
      let storage_type = constructor_plan.storage_types[index]
      let source_shape = self.shape_from_key(
        constructor_plan.storage_shapes[index],
      )
      let target_type = if family.key is Specialized(_, _, _) {
        storage_type
      } else {
        payload_type
      }
      let planned_target_shape = self.shape_of_port(Value(binder), target_type)
      // A nominal-data projection keeps the finalized data-family identity.
      // Callable fields may still require the representation selected for the
      // binder and therefore retain an explicit flow boundary here.
      let target_shape = match source_shape {
        Slot(Value({ kind: DataValue(_), .. })) => source_shape
        _ => planned_target_shape
      }
      let target_callable = self.callable_at_port(Value(binder))
      let target_interface = self.callable_interface_at_port(
        Value(binder),
        target_type,
        target_shape,
        scopes[alternative_index],
      )
      let flow = self.preplan_physical_value_flow_with_interfaces(
        "data-match-payload",
        Some(site),
        target_type,
        target_type,
        scopes[alternative_index],
        source_shape,
        target_shape,
        None,
        target_callable,
        constructor_plan.storage_callable_interfaces[index],
        target_interface,
      )
      payloads[alternative_index].push({ type_: target_type, flow, })
      self.record_type(Value(binder), target_type)
      ignore(
        self.append_port(
          Value(binder),
          target_shape,
          target_interface,
          "match-payload",
        ),
      )
    }
  }
  (scopes, payloads)
}

///|
fn PhysicalFunctionPlanner::shape_from_key(
  _self : PhysicalFunctionPlanner,
  key : CanonicalRuntimeTypeKey,
) -> PhysicalValueShape {
  key.physical_shape()
}

///|
fn PhysicalFunctionPlanner::atom_shape(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
) -> PhysicalValueShape raise LoisvmLoweringError {
  match atom {
    Literal(literal) => self.shape_of_type(runtime_literal_type(literal))
    Ref(value) =>
      match self.port_shape(Value(value)) {
        Some(shape) => shape
        None =>
          match self.image.find_global(value) {
            Some(UnitValue) => PhysicalValueShape::Unit
            Some(InstanceGlobal(_, _, shape, _)) => shape.physical_shape()
            _ => {
              guard self.image.metadata.value_info(value) is Some(info) else {
                raise MissingValueMetadata(value~)
              }
              self.shape_of_type(info.type_)
            }
          }
      }
    Temp(temp) =>
      match self.port_shape(Temp(temp)) {
        Some(shape) => shape
        None => {
          guard self.image.callable_catalog.capture_type(
              @anf.AnfCapture::Temp(temp),
              self.image.metadata,
            )
            is Some(type_) else {
            raise RepresentationSpecializationInvariant(
              detail="Runtime ANF temporary has no semantic type",
            )
          }
          self.shape_of_type(type_)
        }
      }
    Function(function) => {
      let callable = self.materialized_callable_target(function, None)
      let allocation = self.preplan_callable_allocation(function, callable)
      PhysicalValueShape::Slot(
        CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
      )
    }
    EvidenceLambda(body~, ..) => {
      guard extract_top_function(body) is Some(function) else {
        raise RepresentationSpecializationInvariant(
          detail="Runtime ANF evidence lambda has no callable definition",
        )
      }
      let callable = self.materialized_callable_target(function, None)
      let allocation = self.preplan_callable_allocation(function, callable)
      PhysicalValueShape::Slot(
        CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
      )
    }
  }
}

///|
fn PhysicalFunctionPlanner::applied_callable_type(
  self : PhysicalFunctionPlanner,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.RuntimeArgument],
) -> @anf.RuntimeType raise LoisvmLoweringError {
  guard self.atom_type(callee) is Some(type_) else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF evidence application has no semantic callee type",
    )
  }
  let type_ = self.instantiate_type(type_)
  guard type_ is Forall(parameters, body) &&
    parameters.length() == arguments.length() else {
    raise RepresentationSpecializationInvariant(
      detail="Runtime ANF evidence application does not consume one complete forall",
    )
  }
  let applied = arguments.map(argument => {
    self.substitutions.apply_argument(self.image.runtime_types, argument)
  })
  RuntimeSubstitution::from_arguments(parameters, applied).apply_type(
    self.image.runtime_types,
    body,
  )
}

///|
fn PhysicalFunctionPlanner::deferred_evidence_application(
  self : PhysicalFunctionPlanner,
  callee : @anf.AnfAtom,
) -> DeferredEvidenceApplication? {
  let binding = match self.resolved_atom(callee) {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Literal(_) | Function(_) | EvidenceLambda(..) => None
  }
  guard binding is Some(binding) else { return None }
  for port in self.ports {
    if port.binding == binding {
      return port.evidence_application
    }
  }
  None
}

///|
fn PhysicalFunctionPlanner::atom_type(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
) -> @anf.RuntimeType? {
  let binding = match atom {
    Ref(value) => Some(@anf.AnfBindingId::Value(value))
    Temp(temp) => Some(@anf.AnfBindingId::Temp(temp))
    Literal(_) | Function(_) | EvidenceLambda(..) => None
  }
  if binding is Some(binding) && self.port_type(binding) is Some(type_) {
    return Some(type_)
  }
  self.declared_atom_type(atom)
}

///|
fn PhysicalFunctionPlanner::declared_atom_type(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
) -> @anf.RuntimeType? {
  match atom {
    Literal(literal) => Some(runtime_literal_type(literal))
    Ref(value) =>
      match self.image.metadata.value_info(value) {
        Some(info) => Some(info.type_)
        None =>
          self.image.callable_catalog.capture_type(
            @anf.AnfCapture::Value(value),
            self.image.metadata,
          )
      }
    Temp(temp) =>
      self.image.callable_catalog.capture_type(
        @anf.AnfCapture::Temp(temp),
        self.image.metadata,
      )
    Function(function) =>
      self.image.callable_catalog.find(function.id).map(info => info.type_)
    EvidenceLambda(body~, ..) =>
      extract_top_function(body).bind(function => {
        self.image.callable_catalog.find(function.id).map(info => info.type_)
      })
  }
}

///|
fn runtime_literal_type(literal : @buslane.Literal) -> @anf.RuntimeType {
  match literal {
    Unit => Unit
    Bool(_) => Scalar(Bool)
    I64(_) => Scalar(I64)
    I32(_) => Scalar(I32)
    Char(_) => Scalar(Char)
    F64(_) => Scalar(F64)
    F32(_) => Scalar(F32)
    String(_) => ByteSequence
  }
}

///|
fn ImageLowerer::verify_physical_anf(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
) -> Unit raise LoisvmLoweringError {
  for worker_index, worker in physical.representation_workers {
    for previous in 0..<worker_index {
      if physical.representation_workers[previous].key == worker.key {
        raise RepresentationSpecializationInvariant(
          detail="one canonical representation contract produced two workers",
        )
      }
    }
    guard physical.function(worker.worker) is Some(function) else {
      raise RepresentationSpecializationInvariant(
        detail="selected representation worker has no physical function contract",
      )
    }
    if !function.interface.invocation.witnesses.is_empty() {
      raise RepresentationSpecializationInvariant(
        detail="selected representation worker is not closed over runtime evidence",
      )
    }
  }
  for function_index, entry in physical.functions {
    if entry.0.value <= 0 {
      raise RepresentationSpecializationInvariant(
        detail="physical function plan contains a non-canonical function identity",
      )
    }
    for previous in 0..<function_index {
      if physical.functions[previous].0 == entry.0 {
        raise RepresentationSpecializationInvariant(
          detail="physical function identity is duplicated",
        )
      }
    }
    self.verify_physical_value_flow(physical, entry.1.result)
    let invocation_parameters = []
    for parameter in entry.1.parameters {
      ignore(physical.shape(parameter.contract.shape))
      physical.append_parameter_keys(
        parameter.contract.shape,
        invocation_parameters,
      )
    }
    if invocation_parameters != entry.1.interface.invocation.parameters ||
      physical.shape(entry.1.result.target.shape).canonical_result() !=
      entry.1.interface.invocation.result {
      raise RepresentationSpecializationInvariant(
        detail="physical function invocation contract disagrees with its value ports",
      )
    }
    if entry.1.body.result_contract() != entry.1.result.source {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF function body does not own its result source port",
      )
    }
    let environment : PhysicalAnfEnvironment = { bindings: [], }
    for captured in entry.1.capture.captures {
      let binding = match captured.binding {
        CaptureBinding::Value(value) => @anf.AnfBindingId::Value(value)
        CaptureBinding::Temp(temp) => @anf.AnfBindingId::Temp(temp)
      }
      let shape = match captured.shape {
        Some(shape) => PhysicalValueShape::Slot(shape)
        None => PhysicalValueShape::Unit
      }
      let identity = physical.identity(shape, "callable capture")
      environment.bind(
        binding,
        physical.value_contract(
          identity,
          captured.callable_interface,
          [],
          "callable capture",
        ),
      )
    }
    for parameter in entry.1.parameters {
      environment.bind(parameter.binding, parameter.contract)
    }
    for recursive in entry.1.recursive_functions {
      let interface = physical.interface(recursive.recursive.function)
      environment.bind(
        Value(recursive.recursive.value),
        physical.value_contract(
          recursive.shape,
          interface,
          [],
          "recursive callable",
        ),
      )
    }
    self.verify_physical_anf_expr(physical, environment, entry.1.body)
    for recipe in entry.1.callable_bridge_recipes() {
      if !physical.has_adapter_recipe(recipe) {
        raise RepresentationSpecializationInvariant(
          detail="physical function bridge has no planned callable adapter contract",
        )
      }
    }
  }
}

///|
fn ImageLowerer::physical_capture_for_implementation(
  self : ImageLowerer,
  implementation : PhysicalCallableImplementation,
) -> CallableCaptureContract raise LoisvmLoweringError {
  let callable = self.materialized_callable_implementation(implementation)
  self.physical_capture(callable.function)
}

///|
fn ImageLowerer::verify_physical_value_contract(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  contract : PhysicalValueContract,
) -> Unit raise LoisvmLoweringError {
  ignore(
    physical.value_contract(
      contract.shape,
      contract.callable_interface,
      contract.fields,
      "Physical ANF verifier",
    ),
  )
  for field in contract.fields {
    self.verify_physical_value_contract(physical, field)
  }
}

///|
fn ImageLowerer::verify_physical_value_flow(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  flow : PhysicalValueFlowPlan,
) -> Unit raise LoisvmLoweringError {
  self.verify_physical_value_contract(physical, flow.source)
  self.verify_physical_value_contract(physical, flow.target)
  let source = physical.shape(flow.source.shape)
  let target = physical.shape(flow.target.shape)
  if source == target {
    if flow.bridge is Some(_) {
      raise RepresentationSpecializationInvariant(
        detail="identity-preserving physical flow contains a representation bridge",
      )
    }
    return
  }
  guard flow.bridge is Some(bridge) else {
    raise RepresentationSpecializationInvariant(
      detail="unequal physical value shapes have no explicit representation bridge",
    )
  }
  match bridge {
    Erase({ callable, .. }) => {
      guard target is Slot(Value({ cleanup: OwnedErased, .. })) &&
        !(source is Slot(Value({ cleanup: OwnedErased, .. }))) else {
        raise RepresentationSpecializationInvariant(
          detail="physical erase bridge does not flow from a concrete shape to an erased shape",
        )
      }
      if callable is Some(contract) {
        guard source is Slot(Callable(invocation)) &&
          contract.recipe.source_abi == invocation else {
          raise RepresentationSpecializationInvariant(
            detail="physical callable erasure disagrees with its source invocation contract",
          )
        }
        if !physical.has_adapter_recipe(contract.recipe) {
          raise RepresentationSpecializationInvariant(
            detail="physical callable erasure has no planned adapter contract",
          )
        }
      }
    }
    Unerase(callable) => {
      guard source is Slot(Value({ cleanup: OwnedErased, .. })) &&
        !(target is Slot(Value({ cleanup: OwnedErased, .. }))) else {
        raise RepresentationSpecializationInvariant(
          detail="physical unerase bridge does not flow from an erased shape to a concrete shape",
        )
      }
      if callable is Some(contract) {
        guard target is Slot(Callable(invocation)) &&
          contract.recipe.target_abi == invocation else {
          raise RepresentationSpecializationInvariant(
            detail="physical callable unerasure disagrees with its target invocation contract",
          )
        }
        if !physical.has_adapter_recipe(contract.recipe) {
          raise RepresentationSpecializationInvariant(
            detail="physical callable unerasure has no planned adapter contract",
          )
        }
      }
    }
    Callable(contract) => {
      guard source is Slot(Callable(source_abi)) &&
        target is Slot(Callable(target_abi)) &&
        contract.recipe.source_abi == source_abi &&
        contract.recipe.target_abi == target_abi else {
        raise RepresentationSpecializationInvariant(
          detail="physical callable bridge disagrees with its source or target invocation contract",
        )
      }
      if !physical.has_adapter_recipe(contract.recipe) {
        raise RepresentationSpecializationInvariant(
          detail="physical callable bridge has no planned adapter contract",
        )
      }
    }
  }
}
