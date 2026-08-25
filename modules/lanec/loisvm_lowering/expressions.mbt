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
  let value = match atom.callable {
    Some(callable) =>
      self.materialize_physical_callable_atom(
        atom.atom,
        callable,
        atom.allocation,
      )
    None =>
      match atom.atom {
        Function(function) => {
          guard atom.allocation is Some(allocation) else {
            raise RepresentationSpecializationInvariant(
              detail="Physical ANF nested function has no allocation contract",
            )
          }
          self.lower_nested_function_with_allocation(function, allocation)
        }
        EvidenceLambda(body~, ..) => {
          guard extract_top_function(body) is Some(function) &&
            atom.allocation is Some(allocation) else {
            raise RepresentationSpecializationInvariant(
              detail="Physical ANF evidence lambda has no allocation contract",
            )
          }
          self.lower_nested_function_with_allocation(function, allocation)
        }
        Literal(literal) => self.lower_physical_literal(literal, atom.contract)
        Ref(_) | Temp(_) => self.lower_atom(atom.atom)
      }
  }
  { value, contract: atom.contract, }
}

///|
fn FunctionLowerer::lower_atom(
  self : FunctionLowerer,
  atom : @anf.AnfAtom,
) -> LocalValue raise LoisvmLoweringError {
  match atom {
    Ref(value) => self.find_value(value)
    Temp(temp) => self.find_temp(temp)
    Literal(_) | Function(_) | EvidenceLambda(..) =>
      raise RepresentationSpecializationInvariant(
        detail="Runtime ANF atom reached lowering without its Physical ANF contract",
      )
  }
}

///|
fn FunctionLowerer::lower_evidence_apply(
  self : FunctionLowerer,
  application : PhysicalAnfEvidenceApplication,
) -> LocalValue raise LoisvmLoweringError {
  ignore(application.arguments)
  let lowered = self.lower_physical_atom(application.callee).value
  if application.application.materialize {
    return self.materialize_evidence_application(
      lowered,
      application.application,
    )
  }
  if local_value_type(lowered) is Some(type_) &&
    !(self.image.runtime_type(type_) is Concrete(Forall(_, _))) {
    return lowered
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
  let construct = physical.construct
  let info = match
    self.image.metadata.data_constructor_info(construct.data_constructor) {
    Some(info) => info
    None =>
      raise MissingDataConstructorMetadata(
        data_constructor=construct.data_constructor,
      )
  }
  let owner_info = match self.image.metadata.type_info(info.owner) {
    Some(info) => info
    None =>
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
  let owner_substitutions = RuntimeSubstitution::from_arguments(
    owner_info.evidence_parameters,
    type_arguments,
  )
  let hidden_substitutions = RuntimeSubstitution::from_arguments(
    info.hidden_evidence_parameters,
    hidden_arguments,
  )
  let substitutions = owner_substitutions.overlay(hidden_substitutions)
  let result_type = @anf.RuntimeType::Data(info.owner, type_arguments)
  let physical_construct = physical.plan
  if construct.payloads.length() != info.payload_types.length() {
    raise InvalidDataPayloadCount(
      data_constructor=construct.data_constructor,
      expected=info.payload_types.length(),
      actual=construct.payloads.length(),
    )
  }
  if physical_construct.payloads.length() != construct.payloads.length() {
    raise RepresentationSpecializationInvariant(
      detail="data construction disagrees with its physical payload plan",
    )
  }
  if physical_construct.representation is Product(contract) {
    if contract.data_constructor != construct.data_constructor ||
      contract.payload_types.length() != construct.payloads.length() {
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
  guard physical_construct.representation is Data(family) &&
    family.constructor_plan(construct.data_constructor)
    is Some(constructor_plan) else {
    raise RepresentationSpecializationInvariant(
      detail="planned data family lacks its construction contract",
    )
  }
  let storage_types = constructor_plan.storage_types
  let fields = []
  if constructor_plan.storage_hidden_arguments is Some(expected) &&
    expected != hidden_arguments {
    raise RepresentationSpecializationInvariant(
      detail="data construction hidden arguments disagree with its specialized family contract",
    )
  }
  for parameter in constructor_plan.storage_evidence_parameters {
    guard substitutions.argument(parameter.id) is Some(argument) else {
      raise InvalidTypeApplication(detail="missing hidden runtime evidence")
    }
    fields.push(self.runtime_evidence(parameter, argument))
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
      Unit =>
        if storage_type != Unit {
          raise UnsupportedExpression(
            detail="non-Unit data field has no runtime representation",
          )
        }
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
  let shape = self.image.materialize_data_shape(family, constructor_plan, info)
  let layout = self.image.intern_layout(Data(shape))
  guard family.bytecode_family is Some(bytecode_family) else {
    raise RepresentationSpecializationInvariant(
      detail="VM CFG construction received an unmaterialized data-family contract",
    )
  }
  let result_key = CanonicalRuntimeTypeKey::Value({
    representation: I32,
    cleanup: OwnedRef,
    kind: DataValue(bytecode_family),
  })
  let destination = self.fresh_metadata(result_key.value_metadata(None))
  self.emit(MakeData(destination, shape, Immediate(layout), witnesses, fields))
  LocalValue::Slot(destination, result_type, result_key)
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
  self.lower_literal_with_shape(
    literal,
    Some(self.physical_shape(contract.shape)),
  )
}

///|
/// Materialize a literal introduced by VM CFG control-flow lowering. Source
/// literals use lower_physical_literal and retain their Physical ANF contract.
fn FunctionLowerer::lower_internal_literal(
  self : FunctionLowerer,
  literal : @buslane.Literal,
) -> LocalValue raise LoisvmLoweringError {
  self.lower_literal_with_shape(literal, None)
}

///|
fn FunctionLowerer::lower_literal_with_shape(
  self : FunctionLowerer,
  literal : @buslane.Literal,
  planned_shape : PhysicalValueShape?,
) -> LocalValue raise LoisvmLoweringError {
  let fresh = fn(
    type_ : @anf.RuntimeType,
  ) -> (@vmcfg.ValueId, CanonicalRuntimeTypeKey) raise LoisvmLoweringError {
    let key = match planned_shape {
      Some(PhysicalValueShape::Slot(key)) => key
      Some(_) =>
        raise RepresentationSpecializationInvariant(
          detail="literal has no physical result slot",
        )
      None => self.physical_shape_of_type(type_)
    }
    (self.fresh_metadata(key.value_metadata(None)), key)
  }
  match literal {
    Unit => {
      match planned_shape {
        None | Some(PhysicalValueShape::Unit) => ()
        _ =>
          raise RepresentationSpecializationInvariant(
            detail="Unit literal is not represented as Unit",
          )
      }
      Unit
    }
    Bool(value) => {
      let type_ = @anf.RuntimeType::Scalar(Bool)
      let (slot, key) = fresh(type_)
      self.emit(ConstBool(slot, value))
      Slot(slot, type_, key)
    }
    I64(value) => {
      let type_ = @anf.RuntimeType::Scalar(I64)
      let (slot, key) = fresh(type_)
      self.emit(ConstI64(slot, value))
      Slot(slot, type_, key)
    }
    I32(value) => {
      let type_ = @anf.RuntimeType::Scalar(I32)
      let (slot, key) = fresh(type_)
      self.emit(ConstI32(slot, value))
      Slot(slot, type_, key)
    }
    F32(value) => {
      let type_ = @anf.RuntimeType::Scalar(F32)
      let (slot, key) = fresh(type_)
      self.emit(ConstF32(slot, value.reinterpret_as_int()))
      Slot(slot, type_, key)
    }
    Char(value) => {
      let type_ = @anf.RuntimeType::Scalar(Char)
      let (slot, key) = fresh(type_)
      self.emit(ConstChar(slot, value))
      Slot(slot, type_, key)
    }
    F64(value) => {
      let type_ = @anf.RuntimeType::Scalar(F64)
      let (slot, key) = fresh(type_)
      self.emit(ConstF64(slot, value.reinterpret_as_int64()))
      Slot(slot, type_, key)
    }
    String(value) => {
      let type_ = @anf.RuntimeType::ByteSequence
      let (slot, key) = fresh(type_)
      let constant = self.image.intern_string(value)
      ignore(self.image.intern_layout(ByteSequence))
      self.emit(ConstString(slot, constant))
      Slot(slot, type_, key)
    }
  }
}

///|
