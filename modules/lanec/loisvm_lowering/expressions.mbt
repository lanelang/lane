///|
fn FunctionLowerer::lower_expr(
  self : FunctionLowerer,
  expression : PhysicalAnfExpr,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.lower_physical_atom(atom)
    Let(binding, body) => {
      let lowered = self.lower_rhs(binding.rhs, binding.result)
      match binding.binding {
        Value(id~, ..) =>
          self.bindings.push({ value: id, lowered: lowered.value, })
        Temp(temp~, ..) => self.temps.push({ temp, lowered: lowered.value, })
      }
      self.lower_expr(body)
    }
    LetRec(bindings, body) => self.lower_recursive_group(bindings, body)
  }
}

///|
fn @anf.AnfBinding::rhs(self : @anf.AnfBinding) -> @anf.AnfRhs {
  match self {
    Value(rhs~, ..) | Temp(rhs~, ..) => rhs
  }
}

///|
fn FunctionLowerer::lower_rhs(
  self : FunctionLowerer,
  rhs : PhysicalAnfRhs,
  result : PhysicalValueContract,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  match rhs {
    Atom(atom, flow) =>
      self.apply_physical_binding_flow(flow, self.lower_physical_atom(atom))
    ApplyEvidence(application) =>
      { value: self.lower_evidence_apply(application), contract: result, }
    Call(call) => { value: self.lower_call(call), contract: result, }
    Construct(construct) =>
      { value: self.lower_construct(construct), contract: result, }
    Match(match_) => { value: self.lower_match(match_), contract: result, }
  }
}

///|
fn FunctionLowerer::lower_physical_atom(
  self : FunctionLowerer,
  atom : PhysicalAnfAtom,
) -> PhysicalLocalValue raise LoisvmLoweringError {
  let value = match atom.producer {
    Binding(Value(value)) => self.find_value(value)
    Binding(Temp(temp)) => self.find_temp(temp)
    PhysicalAnfAtomProducer::Literal(literal) =>
      self.lower_physical_literal(literal, atom.contract)
    Callable(allocation) => self.lower_callable_allocation(allocation)
  }
  { value, contract: atom.contract, }
}

///|
fn FunctionLowerer::lower_evidence_apply(
  self : FunctionLowerer,
  application : PhysicalAnfEvidenceApplication,
) -> LocalValue raise LoisvmLoweringError {
  let lowered = self.lower_physical_atom(application.callee).value
  match application.application.mode {
    Materialize =>
      return self.materialize_evidence_application(
        lowered,
        application.application,
      )
    Identity => return lowered
    Deferred => ()
  }
  match lowered {
    Global(global) => EvidenceApplied(global, application.application)
    Slot(callable, type_, shape) =>
      EvidenceAppliedCallable(callable, type_, shape, application.application)
    NestedCallable(callable) =>
      EvidenceAppliedNestedCallable(callable, application.application)
    EvidenceApplied(global, _) =>
      EvidenceApplied(global, application.application)
    EvidenceAppliedCallable(callable, type_, shape, _) =>
      EvidenceAppliedCallable(callable, type_, shape, application.application)
    EvidenceAppliedNestedCallable(callable, _) =>
      EvidenceAppliedNestedCallable(callable, application.application)
    RecursiveFunction(_, _, _) as recursive => {
      guard self.materialize_local(recursive) is Slot(callable, type_, shape) else {
        abort("recursive callable was not materialized")
      }
      EvidenceAppliedCallable(callable, type_, shape, application.application)
    }
    _ =>
      raise InvalidTypeApplication(
        detail="type application target is not a generic callable",
      )
  }
}

///|
fn FunctionLowerer::lower_construct(
  self : FunctionLowerer,
  physical : PhysicalAnfConstruct,
) -> LocalValue raise LoisvmLoweringError {
  let physical_construct = physical.plan
  if physical_construct.payloads.length() != physical.payloads.length() {
    raise RepresentationSpecializationInvariant(
      detail="data construction disagrees with its physical payload plan",
    )
  }
  if physical_construct.representation is Product(contract) {
    if contract.payload_types.length() != physical.payloads.length() {
      raise RepresentationSpecializationInvariant(
        detail="closed aggregate contract does not match its allocation",
      )
    }
    let payloads = []
    for index, payload in physical.payloads {
      let target_type = contract.payload_types[index]
      let source = self.materialize_physical_local(
        self.lower_physical_atom(payload),
      )
      let flow = physical_construct.payloads[index]
      payloads.push(
        self.materialize_planned_value_flow(
          "closed aggregate payload \{index}",
          source,
          target_type,
          flow.target,
          flow.bridge,
        ).value,
      )
    }
    return ClosedAggregate(contract, payloads)
  }
  guard physical_construct.representation is Data(data) else {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF construction lacks a selected representation",
    )
  }
  let family = data.family
  let constructor_plan = data.constructor_plan
  let storage_types = constructor_plan.storage_types
  let fields = []
  for evidence in data.stored_evidence {
    fields.push(self.materialize_runtime_evidence(evidence))
  }
  let witnesses = []
  for index, payload in physical.payloads {
    let storage_type = storage_types[index]
    let source = self.materialize_physical_local(
      self.lower_physical_atom(payload),
    )
    let flow = physical_construct.payloads[index]
    let lowered = self.materialize_planned_value_flow(
        "data payload \{index}",
        source,
        storage_type,
        flow.target,
        flow.bridge,
      ).value
    match lowered {
      Unit => ()
      Slot(field, _, _) => {
        if self.values[field.value].erased_companion is Some(witness) {
          witnesses.push(witness)
        }
        fields.push(field)
      }
      _ =>
        raise UnsupportedExpression(
          detail="data field has no runtime representation",
        )
    }
  }
  let shape = constructor_plan.shape
  let layout = self.image.intern_layout(Data(shape))
  let result_key = CanonicalRuntimeTypeKey::Value({
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue(family.family),
  })
  let destination = self.fresh_metadata(result_key.value_metadata(None))
  self.emit(MakeData(destination, shape, Immediate(layout), witnesses, fields))
  LocalValue::Slot(destination, data.result_type, result_key)
}

///|
fn ImageLowerer::constructor_tag(
  self : ImageLowerer,
  data_constructor : @buslane.DataConId,
  owner : @buslane.TypeId,
) -> Int raise LoisvmLoweringError {
  let owner_info = match self.metadata.type_info(owner) {
    Some(info) => info
    None => raise MissingDataConstructorMetadata(data_constructor~)
  }
  for index, candidate in owner_info.constructors {
    if candidate == data_constructor {
      return index
    }
  }
  raise MissingDataConstructorMetadata(data_constructor~)
}

///|
fn FunctionLowerer::find_value(
  self : FunctionLowerer,
  value : @buslane.ValueId,
) -> LocalValue raise LoisvmLoweringError {
  for binding in self.bindings.rev_iter() {
    if binding.value == value {
      return binding.lowered
    }
  }
  match self.image.find_global(value) {
    Some(UnitValue) => Unit
    Some(InstanceGlobal(global, type_, shape, _)) => {
      let destination = self.fresh_metadata(shape.borrowed_value_metadata(None))
      self.emit(BorrowGlobal(destination, global))
      LocalValue::Slot(destination, type_, shape)
    }
    Some(global) => Global(global)
    None => raise MissingValueMetadata(value~)
  }
}

///|
fn FunctionLowerer::find_temp(
  self : FunctionLowerer,
  temp : @anf.AnfTempId,
) -> LocalValue raise LoisvmLoweringError {
  for binding in self.temps.rev_iter() {
    if binding.temp == temp {
      return binding.lowered
    }
  }
  raise UnsupportedExpression(detail="unknown ANF temporary")
}

///|
fn FunctionLowerer::lower_physical_literal(
  self : FunctionLowerer,
  literal : @buslane.Literal,
  contract : PhysicalValueContract,
) -> LocalValue raise LoisvmLoweringError {
  self.lower_literal_with_shape(literal, self.physical_shape(contract.shape))
}

///|
/// Materialize a literal introduced by VM CFG control-flow lowering. Source
/// literals use lower_physical_literal and retain their Physical ANF contract.
fn FunctionLowerer::lower_internal_literal(
  self : FunctionLowerer,
  literal : @buslane.Literal,
) -> LocalValue raise LoisvmLoweringError {
  self.lower_literal_with_shape(
    literal,
    runtime_literal_physical_shape(literal),
  )
}

///|
fn FunctionLowerer::lower_literal_with_shape(
  self : FunctionLowerer,
  literal : @buslane.Literal,
  planned_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  let fresh = fn() -> (@vmcfg.ValueId, CanonicalRuntimeTypeKey) raise LoisvmLoweringError {
    let key = match planned_shape {
      PhysicalValueShape::Slot(key) => key
      _ =>
        raise RepresentationSpecializationInvariant(
          detail="literal has no physical result slot",
        )
    }
    (self.fresh_metadata(key.value_metadata(None)), key)
  }
  match literal {
    Unit => {
      match planned_shape {
        PhysicalValueShape::Unit => ()
        _ =>
          raise RepresentationSpecializationInvariant(
            detail="Unit literal is not represented as Unit",
          )
      }
      Unit
    }
    Bool(value) => {
      let type_ = @anf.RuntimeType::Scalar(Bool)
      let (slot, key) = fresh()
      self.emit(ConstBool(slot, value))
      Slot(slot, type_, key)
    }
    I64(value) => {
      let type_ = @anf.RuntimeType::Scalar(I64)
      let (slot, key) = fresh()
      self.emit(ConstI64(slot, value))
      Slot(slot, type_, key)
    }
    I32(value) => {
      let type_ = @anf.RuntimeType::Scalar(I32)
      let (slot, key) = fresh()
      self.emit(ConstI32(slot, value))
      Slot(slot, type_, key)
    }
    F32(value) => {
      let type_ = @anf.RuntimeType::Scalar(F32)
      let (slot, key) = fresh()
      self.emit(ConstF32(slot, value.reinterpret_as_int()))
      Slot(slot, type_, key)
    }
    Char(value) => {
      let type_ = @anf.RuntimeType::Scalar(Char)
      let (slot, key) = fresh()
      self.emit(ConstChar(slot, value))
      Slot(slot, type_, key)
    }
    F64(value) => {
      let type_ = @anf.RuntimeType::Scalar(F64)
      let (slot, key) = fresh()
      self.emit(ConstF64(slot, value.reinterpret_as_int64()))
      Slot(slot, type_, key)
    }
    String(value) => {
      let type_ = @anf.RuntimeType::ByteSequence
      let (slot, key) = fresh()
      let constant = self.image.intern_string(value)
      ignore(self.image.intern_layout(ByteSequence))
      self.emit(ConstString(slot, constant))
      Slot(slot, type_, key)
    }
  }
}

///|
