///|
/// A Runtime ANF atom at one physical use site. Callable selection and
/// allocation are occurrence facts: keeping them on the use prevents VM CFG
/// emission from reconstructing either fact from semantic identity.
priv struct PhysicalAnfAtom {
  atom : @anf.AnfAtom
  contract : PhysicalValueContract
  callable : CallableRepresentationTarget?
  allocation : PhysicalCallableAllocationPlan?
}

///|
priv struct PhysicalAnfEnvironment {
  bindings : Array[(@anf.AnfBindingId, PhysicalValueContract)]
}

///|
fn PhysicalAnfEnvironment::contract(
  self : PhysicalAnfEnvironment,
  binding : @anf.AnfBindingId,
) -> PhysicalValueContract? {
  for entry in self.bindings.rev_iter() {
    if entry.0 == binding {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PhysicalAnfEnvironment::bind(
  self : PhysicalAnfEnvironment,
  binding : @anf.AnfBindingId,
  contract : PhysicalValueContract,
) -> Unit {
  self.bindings.push((binding, contract))
}

///|
fn PhysicalAnfEnvironment::restore(
  self : PhysicalAnfEnvironment,
  count : Int,
) -> Unit {
  while self.bindings.length() > count {
    ignore(self.bindings.pop())
  }
}

///|
priv enum PhysicalAnfExpr {
  Atom(PhysicalAnfAtom)
  Let(PhysicalAnfBinding, PhysicalAnfExpr)
  LetRec(Array[PhysicalAnfRecursiveBinding], PhysicalAnfExpr)
}

///|
priv struct PhysicalAnfBinding {
  binding : @anf.AnfBinding
  rhs : PhysicalAnfRhs
  result : PhysicalValueContract
}

///|
priv struct PhysicalAnfRecursiveBinding {
  id : @buslane.ValueId
  rhs : PhysicalAnfAtom
  flow : PhysicalBindingFlowPlan
}

///|
priv enum PhysicalAnfRhs {
  Atom(PhysicalAnfAtom, PhysicalBindingFlowPlan)
  ApplyEvidence(PhysicalAnfEvidenceApplication)
  Call(PhysicalAnfCall)
  Construct(PhysicalAnfConstruct)
  Match(PhysicalAnfMatch)
}

///|
fn PhysicalAnfRhs::result_fields(
  self : PhysicalAnfRhs,
) -> Array[PhysicalValueContract] {
  match self {
    Atom(_, flow) => flow.flow.target.fields
    ApplyEvidence(_) => []
    Call(call) => call.plan.result.target.fields
    Construct(construct) =>
      match construct.plan.representation {
        Product(_) => construct.plan.payloads.map(flow => flow.target)
        Data(_) => []
      }
    Match(match_) =>
      match match_.plan.alternatives {
        [first, ..] => first.result.target.fields
        [] => []
      }
  }
}

///|
priv struct PhysicalAnfEvidenceApplication {
  callee : PhysicalAnfAtom
  arguments : Array[@anf.RuntimeArgument]
  application : DeferredEvidenceApplication
}

///|
priv struct PhysicalAnfCall {
  callee : PhysicalAnfAtom
  arguments : Array[PhysicalAnfAtom]
  plan : PhysicalCallPlan
}

///|
priv struct PhysicalAnfConstruct {
  construct : @anf.AnfConstruct
  payloads : Array[PhysicalAnfAtom]
  plan : PhysicalConstructPlan
}

///|
priv struct PhysicalAnfMatch {
  scrutinee : PhysicalAnfAtom
  binder : @buslane.ValueId
  result_type : @anf.RuntimeType
  alternatives : Array[PhysicalAnfAlternative]
  plan : PhysicalMatchPlan
}

///|
priv struct PhysicalAnfAlternative {
  alt_constructor : @buslane.AltCon
  evidence_binders : Array[@anf.RuntimeEvidenceParameter]
  value_binders : Array[@buslane.ValueId]
  body : PhysicalAnfExpr
  plan : PhysicalMatchAlternativePlan
}

///|
fn PhysicalAnfExpr::result_contract(
  self : PhysicalAnfExpr,
) -> PhysicalValueContract {
  match self {
    Atom(atom) => atom.contract
    Let(_, body) | LetRec(_, body) => body.result_contract()
  }
}

///|
fn PhysicalFunctionPlanner::materialize_physical_atom(
  self : PhysicalFunctionPlanner,
  atom : @anf.AnfAtom,
  requested : CallableRepresentationTarget?,
  requested_shape : PhysicalValueShapeId?,
) -> PhysicalAnfAtom raise LoisvmLoweringError {
  let callable = self.planned_atom_callable_target(atom, requested)
  let candidate_allocation = match callable {
    Some(callable) =>
      self
      .preplan_materialized_atom(atom, Some(callable))
      .map(_ => self.required_callable_allocation(callable))
    None => None
  }
  let base_shape = self.atom_shape(atom)
  let candidate_shape = candidate_allocation.map(allocation => {
    PhysicalValueShape::Slot(
      CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
    )
  })
  let shape = requested_shape.unwrap_or_else(() => {
    self.physical.intern(candidate_shape.unwrap_or(base_shape))
  })
  let allocation = candidate_allocation.bind(allocation => {
    if self.physical.shape(shape) == candidate_shape.unwrap() {
      Some(allocation)
    } else {
      None
    }
  })
  let producer_shape = if allocation is Some(_) {
    candidate_shape.unwrap()
  } else {
    base_shape
  }
  if allocation is None && self.physical.shape(shape) != producer_shape {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF atom \{Repr(atom)} was assigned source shape \{Repr(self.physical.shape(shape))}, but its producer owns \{Repr(producer_shape)}",
    )
  }
  let existing = match atom {
    Ref(value) => self.port_contract(Value(value))
    Temp(temp) => self.port_contract(Temp(temp))
    Function(_) | EvidenceLambda(..) | Literal(_) => None
  }
  let callable_interface = match allocation {
    Some(allocation) => Some(allocation.interface)
    None => self.planned_atom_callable_interface(atom, callable)
  }
  let fields = match existing {
    Some(contract) if contract.shape == shape => contract.fields
    _ => []
  }
  {
    atom,
    contract: self.physical.value_contract(
      shape, callable_interface, fields, "Physical ANF atom",
    ),
    callable,
    allocation,
  }
}

///|
fn PhysicalFunctionPlanner::required_callable_allocation(
  self : PhysicalFunctionPlanner,
  callable : CallableRepresentationTarget,
) -> PhysicalCallableAllocationPlan raise LoisvmLoweringError {
  for allocation in self.callable_allocations {
    if allocation.callable == callable {
      return allocation
    }
  }
  raise RepresentationSpecializationInvariant(
    detail="Physical ANF callable target has no solved allocation contract",
  )
}

///|
fn PhysicalAnfExpr::append_callable_bridge_recipes(
  self : PhysicalAnfExpr,
  recipes : Array[CallableAdapterRecipe],
) -> Unit {
  match self {
    Atom(atom) => atom.append_callable_bridge_recipes(recipes)
    Let(binding, body) => {
      binding.rhs.append_callable_bridge_recipes(recipes)
      body.append_callable_bridge_recipes(recipes)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        binding.flow.flow.append_callable_bridge_recipes(recipes)
        binding.rhs.append_callable_bridge_recipes(recipes)
      }
      body.append_callable_bridge_recipes(recipes)
    }
  }
}

///|
fn PhysicalAnfRhs::append_callable_bridge_recipes(
  self : PhysicalAnfRhs,
  recipes : Array[CallableAdapterRecipe],
) -> Unit {
  match self {
    Atom(atom, flow) => {
      atom.append_callable_bridge_recipes(recipes)
      flow.flow.append_callable_bridge_recipes(recipes)
    }
    ApplyEvidence(application) => {
      application.callee.append_callable_bridge_recipes(recipes)
      if application.application.adapter is Some(adapter) {
        adapter.append_recipes(recipes)
      }
    }
    Call(call) => {
      call.callee.append_callable_bridge_recipes(recipes)
      for argument in call.arguments {
        argument.append_callable_bridge_recipes(recipes)
      }
      for flow in call.plan.arguments {
        flow.append_callable_bridge_recipes(recipes)
      }
      call.plan.result.append_callable_bridge_recipes(recipes)
    }
    Construct(construct) => {
      for payload in construct.payloads {
        payload.append_callable_bridge_recipes(recipes)
      }
      for flow in construct.plan.payloads {
        flow.append_callable_bridge_recipes(recipes)
      }
    }
    Match(match_) => {
      match_.scrutinee.append_callable_bridge_recipes(recipes)
      for alternative in match_.alternatives {
        for payload in alternative.plan.payloads {
          payload.flow.append_callable_bridge_recipes(recipes)
        }
        alternative.plan.result.append_callable_bridge_recipes(recipes)
        alternative.body.append_callable_bridge_recipes(recipes)
      }
    }
  }
}

///|
fn PhysicalAnfAtom::append_callable_bridge_recipes(
  self : PhysicalAnfAtom,
  recipes : Array[CallableAdapterRecipe],
) -> Unit {
  if self.allocation is Some(allocation) {
    for capture in allocation.captures {
      capture.append_callable_bridge_recipes(recipes)
    }
  }
}

///|
fn ImageLowerer::verify_physical_anf_expr(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  expression : PhysicalAnfExpr,
) -> Unit raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.verify_physical_anf_atom(physical, environment, atom)
    Let(binding, body) => {
      self.verify_physical_anf_rhs(
        physical,
        environment,
        binding.result,
        binding.rhs,
      )
      environment.bind(binding.binding.id(), binding.result)
      self.verify_physical_anf_expr(physical, environment, body)
    }
    LetRec(bindings, body) => {
      if bindings.is_empty() {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF recursive group is empty",
        )
      }
      for binding in bindings {
        environment.bind(Value(binding.id), binding.flow.flow.target)
      }
      for binding in bindings {
        self.verify_physical_anf_atom(physical, environment, binding.rhs)
        self.verify_physical_value_flow(physical, binding.flow.flow)
        if binding.rhs.contract != binding.flow.flow.source {
          raise RepresentationSpecializationInvariant(
            detail="Physical ANF recursive callable does not own its source port",
          )
        }
      }
      self.verify_physical_anf_expr(physical, environment, body)
    }
  }
}

///|
fn ImageLowerer::verify_physical_anf_rhs(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  result : PhysicalValueContract,
  rhs : PhysicalAnfRhs,
) -> Unit raise LoisvmLoweringError {
  ignore(physical.shape(result.shape))
  match rhs {
    Atom(atom, binding) => {
      self.verify_physical_anf_atom(physical, environment, atom)
      self.verify_physical_value_flow(physical, binding.flow)
      if atom.contract != binding.flow.source || binding.flow.target != result {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF atom binding does not own its solved value flow",
        )
      }
    }
    ApplyEvidence(application) => {
      self.verify_physical_anf_atom(physical, environment, application.callee)
      let result_shape = physical.shape(result.shape)
      let interface_shape = PhysicalValueShape::Slot(
        CanonicalRuntimeTypeKey::Callable(
          application.application.interface.invocation,
        ),
      )
      if application.application.materialize {
        if result_shape != interface_shape {
          raise RepresentationSpecializationInvariant(
            detail="materialized Physical ANF evidence application disagrees with its callable interface",
          )
        }
      } else if result.shape != application.callee.contract.shape ||
        result_shape != interface_shape {
        raise RepresentationSpecializationInvariant(
          detail="deferred Physical ANF evidence application does not preserve its callable producer",
        )
      }
    }
    Call(call) =>
      self.verify_physical_anf_call(physical, environment, result.shape, call)
    Construct(construct) =>
      self.verify_physical_anf_construct(
        physical,
        environment,
        result.shape,
        construct,
      )
    Match(match_) =>
      self.verify_physical_anf_match(
        physical,
        environment,
        result.shape,
        match_,
      )
  }
}

///|
fn ImageLowerer::verify_physical_anf_atom(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  atom : PhysicalAnfAtom,
) -> Unit raise LoisvmLoweringError {
  self.verify_physical_value_contract(physical, atom.contract)
  let producer : PhysicalValueContract? = match atom.atom {
    Ref(value) =>
      match atom.allocation {
        Some(_) => Some(atom.contract)
        None =>
          match environment.contract(Value(value)) {
            Some(contract) => Some(contract)
            None => self.physical_global_contract(physical, value)
          }
      }
    Temp(temp) => environment.contract(Temp(temp))
    Literal(literal) =>
      Some(
        physical.value_contract(
          physical.identity(
            self
            .canonical_runtime_type_key_under(
              runtime_literal_type(literal),
              RuntimeSubstitution::new(),
            )
            .physical_shape(),
            "literal",
          ),
          None,
          [],
          "literal",
        ),
      )
    Function(_) | EvidenceLambda(..) => atom.allocation.map(_ => atom.contract)
  }
  guard producer is Some(producer) && producer == atom.contract else {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF atom \{Repr(atom.atom)} claims \{Repr(atom.contract)}, but its producer owns \{Repr(producer)}",
    )
  }
  match (atom.callable, atom.allocation) {
    (Some(callable), Some(allocation)) => {
      if allocation.callable != callable ||
        physical.shape(atom.contract.shape) !=
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(allocation.interface.invocation),
        ) {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF callable atom \{Repr(atom.atom)} with target \{Repr(atom.callable)} and shape \{Repr(physical.shape(atom.contract.shape))} disagrees with allocation target \{Repr(allocation.callable)} and invocation \{Repr(allocation.interface.invocation)}",
        )
      }
      self.verify_physical_callable_allocation(
        physical, environment, allocation,
      )
    }
    (Some(_), None) => ()
    (None, Some(_)) =>
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF scalar atom unexpectedly owns a callable allocation",
      )
    (None, None) => ()
  }
}

///|
fn ImageLowerer::record_physical_global_contracts(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
) -> Unit raise LoisvmLoweringError {
  for entry in self.globals {
    let shape = match entry.lowered {
      UnitValue => PhysicalValueShape::Unit
      Function(function, _) =>
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(
            physical.required_invocation(function),
          ),
        )
      Intrinsic(contract) =>
        PhysicalValueShape::Slot(
          CanonicalRuntimeTypeKey::Callable(
            self.canonical_callable_abi_under(
              contract.type_(),
              RuntimeSubstitution::new(),
            ),
          ),
        )
      FloatConstant(_, type_) | DoubleConstant(_, type_) =>
        self
        .canonical_runtime_type_key_under(type_, RuntimeSubstitution::new())
        .physical_shape()
      InstanceGlobal(_, _, key, _) => key.physical_shape()
    }
    let callable_interface = match entry.lowered {
      Function(function, type_) =>
        Some(
          self.callable_interface_under_with_invocation(
            type_,
            RuntimeSubstitution::new(),
            physical.required_invocation(function),
          ),
        )
      Intrinsic(contract) =>
        Some(
          self.canonical_callable_interface_under(
            contract.type_(),
            RuntimeSubstitution::new(),
          ),
        )
      InstanceGlobal(_, _, _, interface) => interface
      UnitValue | FloatConstant(_, _) | DoubleConstant(_, _) => None
    }
    physical.add_global(
      entry.value,
      physical.value_contract(
        physical.intern(shape),
        callable_interface,
        [],
        "global value",
      ),
    )
  }
}

///|
fn ImageLowerer::physical_global_contract(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  value : @buslane.ValueId,
) -> PhysicalValueContract? {
  ignore(self)
  physical.global(value)
}

///|
fn ImageLowerer::verify_physical_anf_call(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  result : PhysicalValueShapeId,
  call : PhysicalAnfCall,
) -> Unit raise LoisvmLoweringError {
  self.verify_physical_anf_atom(physical, environment, call.callee)
  if call.arguments.length() != call.plan.arguments.length() ||
    call.arguments.length() != call.plan.parameter_types.length() ||
    call.arguments.length() != call.plan.callable_arguments.length() {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF call arity disagrees with its invocation contract",
    )
  }
  let invocation_parameters = []
  for index, argument in call.arguments {
    self.verify_physical_anf_atom(physical, environment, argument)
    let flow = call.plan.arguments[index]
    self.verify_physical_value_flow(physical, flow)
    if argument.contract != flow.source {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF call argument disagrees with its solved source port: shape \{Repr(argument.contract.shape)} vs \{Repr(flow.source)}",
      )
    }
    physical.append_parameter_keys(flow.target.shape, invocation_parameters)
  }
  if invocation_parameters != call.plan.invocation.parameters {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF call argument flows disagree with its callable ABI",
    )
  }
  self.verify_physical_value_flow(physical, call.plan.result)
  if call.plan.result.target.shape != result ||
    physical.shape(call.plan.result.source.shape).canonical_result() !=
    call.plan.invocation.result {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF call result disagrees with its invocation contract",
    )
  }
  if call.plan.target is Some(target) &&
    physical.function(target.worker.worker) is None {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF call targets an unknown representation worker",
    )
  }
}

///|
fn ImageLowerer::verify_physical_anf_construct(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  result : PhysicalValueShapeId,
  construct : PhysicalAnfConstruct,
) -> Unit raise LoisvmLoweringError {
  if construct.payloads.length() != construct.plan.payloads.length() ||
    construct.payloads.length() != construct.plan.callable_payloads.length() {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF construction payload arity disagrees with its family contract",
    )
  }
  for index, payload in construct.payloads {
    self.verify_physical_anf_atom(physical, environment, payload)
    let flow = construct.plan.payloads[index]
    self.verify_physical_value_flow(physical, flow)
    if payload.contract != flow.source {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF construction payload disagrees with its solved source port: shape \{Repr(payload.contract.shape)} vs \{Repr(flow.source)}",
      )
    }
  }
  let expected = match construct.plan.representation {
    Product(contract) => {
      if contract.data_constructor != construct.plan.data_constructor ||
        contract.payload_types.length() != construct.payloads.length() {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF scalar construction disagrees with its aggregate contract",
        )
      }
      PhysicalValueShape::Product(
        contract,
        construct.plan.payloads.map(payload => payload.target.shape),
      )
    }
    Data(family) => {
      guard family.constructor_plan(construct.plan.data_constructor)
        is Some(constructor_plan) &&
        constructor_plan.storage_shapes.length() == construct.payloads.length() else {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF construction disagrees with its data-family contract",
        )
      }
      for index, payload in construct.plan.payloads {
        if physical.shape(payload.target.shape) !=
          constructor_plan.storage_shapes[index].physical_shape() {
          raise RepresentationSpecializationInvariant(
            detail="Physical ANF construction payload target disagrees with its data-family member",
          )
        }
      }
      PhysicalValueShape::Slot(self.canonical_data_family_key(family.key))
    }
  }
  if physical.shape(result) != expected {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF construction result disagrees with its family contract",
    )
  }
}

///|
fn ImageLowerer::verify_physical_anf_match(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  result : PhysicalValueShapeId,
  match_ : PhysicalAnfMatch,
) -> Unit raise LoisvmLoweringError {
  self.verify_physical_anf_atom(physical, environment, match_.scrutinee)
  if match_.scrutinee.contract.shape != match_.plan.scrutinee ||
    match_.plan.result != result ||
    match_.alternatives.length() != match_.plan.alternatives.length() {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF match does not own its scrutinee or result port",
    )
  }
  for index, alternative in match_.alternatives {
    let binding_count = environment.bindings.length()
    environment.bind(Value(match_.binder), match_.scrutinee.contract)
    if alternative.plan.alternative_constructor != alternative.alt_constructor ||
      alternative.plan.result.target.shape != result {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF match alternative disagrees with its branch contract",
      )
    }
    for previous in 0..<index {
      if match_.alternatives[previous].alt_constructor ==
        alternative.alt_constructor {
        raise RepresentationSpecializationInvariant(
          detail="Physical ANF match contains a duplicate alternative",
        )
      }
    }
    self.verify_physical_value_flow(physical, alternative.plan.result)
    match physical.shape(match_.scrutinee.contract.shape) {
      Product(contract, fields) =>
        match alternative.alt_constructor {
          DataCon(data_constructor) => {
            if data_constructor != contract.data_constructor ||
              alternative.value_binders.length() != fields.length() ||
              alternative.plan.payloads.length() != fields.length() {
              raise RepresentationSpecializationInvariant(
                detail="Physical ANF aggregate match binders disagree with its selected constructor",
              )
            }
            for payload_index, binder in alternative.value_binders {
              let payload = alternative.plan.payloads[payload_index]
              self.verify_physical_value_flow(physical, payload.flow)
              if payload.flow.source.shape != fields[payload_index] ||
                payload.flow.target.shape != fields[payload_index] {
                raise RepresentationSpecializationInvariant(
                  detail="Physical ANF aggregate match payload does not preserve its product field",
                )
              }
              guard match_.scrutinee.contract.fields.get(payload_index)
                is Some(field) else {
                raise RepresentationSpecializationInvariant(
                  detail="Physical ANF aggregate field has no producer contract",
                )
              }
              environment.bind(Value(binder), field)
            }
          }
          Default =>
            if !alternative.value_binders.is_empty() ||
              !alternative.plan.payloads.is_empty() {
              raise RepresentationSpecializationInvariant(
                detail="Physical ANF aggregate default alternative binds payloads",
              )
            }
          _ =>
            raise RepresentationSpecializationInvariant(
              detail="Physical ANF aggregate match retained an impossible constructor",
            )
        }
      Slot(Value({ kind: DataValue(_), .. })) => {
        if alternative.value_binders.length() !=
          alternative.plan.payloads.length() {
          raise RepresentationSpecializationInvariant(
            detail="Physical ANF data match binders disagree with their physical ports",
          )
        }
        for payload_index, payload in alternative.plan.payloads {
          self.verify_physical_value_flow(physical, payload.flow)
          environment.bind(
            Value(alternative.value_binders[payload_index]),
            payload.flow.target,
          )
        }
      }
      Unit | Slot(_) =>
        if !alternative.value_binders.is_empty() {
          raise RepresentationSpecializationInvariant(
            detail="Physical ANF scalar match unexpectedly binds payloads",
          )
        }
    }
    self.verify_physical_anf_expr(physical, environment, alternative.body)
    environment.restore(binding_count)
  }
}

///|
fn ImageLowerer::verify_physical_callable_allocation(
  self : ImageLowerer,
  physical : PhysicalAnfProgram,
  environment : PhysicalAnfEnvironment,
  allocation : PhysicalCallableAllocationPlan,
) -> Unit raise LoisvmLoweringError {
  if allocation.interface !=
    self.physical_callable_implementation_interface(
      allocation.callable,
      allocation.implementation,
    ) {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF callable allocation interface disagrees with its implementation",
    )
  }
  let capture = self.physical_capture_for_implementation(
    allocation.implementation,
  )
  if allocation.captures.length() != capture.captures.length() {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF callable allocation disagrees with its capture arity",
    )
  }
  for index, flow in allocation.captures {
    self.verify_physical_value_flow(physical, flow)
    let expected = match capture.captures[index].shape {
      Some(shape) => PhysicalValueShape::Slot(shape)
      None => PhysicalValueShape::Unit
    }
    if physical.shape(flow.target.shape) != expected {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF callable capture target disagrees with its closure contract",
      )
    }
    let binding = match capture.captures[index].binding {
      CaptureBinding::Value(value) => @anf.AnfBindingId::Value(value)
      CaptureBinding::Temp(temp) => @anf.AnfBindingId::Temp(temp)
    }
    let producer = match environment.contract(binding) {
      Some(contract) => Some(contract)
      None =>
        match binding {
          Value(value) => self.physical_global_contract(physical, value)
          Temp(_) => None
        }
    }
    guard producer is Some(source) && source == flow.source else {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF callable capture \{Repr(binding)} expects source \{Repr(flow.source)}, but its producer owns \{Repr(producer)}",
      )
    }
  }
}
