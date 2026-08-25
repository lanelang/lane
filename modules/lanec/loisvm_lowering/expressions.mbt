///|
fn FunctionLowerer::lower_expr(
  self : FunctionLowerer,
  expression : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.lower_atom(atom)
    Let(binding, body) => {
      let lowered = self.lower_rhs(binding.id(), binding.rhs())
      self.verify_planned_value(binding.id(), lowered)
      match binding {
        Value(id~, ..) => self.bindings.push({ value: id, lowered, })
        Temp(temp~, ..) => self.temps.push({ temp, lowered, })
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
  site : @anf.AnfBindingId,
  rhs : @anf.AnfRhs,
) -> LocalValue raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => {
      let lowered = match self.planned_callable_port(site) {
        Some(instance) => self.materialize_planned_callable_atom(atom, instance)
        None => self.lower_atom(atom)
      }
      self.apply_planned_binding_flow(site, lowered)
    }
    ApplyEvidence(callee~, arguments~) =>
      self.lower_evidence_apply(site, callee, arguments)
    Call(callee~, arguments~) => self.lower_call(site, callee, arguments)
    Construct(construct) => self.lower_construct(site, construct)
    Match(match_) => self.lower_match(site, match_)
  }
}

///|
fn FunctionLowerer::lower_atom(
  self : FunctionLowerer,
  atom : @anf.AnfAtom,
) -> LocalValue raise LoisvmLoweringError {
  match atom {
    Literal(literal) => self.lower_literal(literal)
    Ref(value) => self.find_value(value)
    Temp(temp) => self.find_temp(temp)
    Function(function) => self.lower_nested_function(function)
    EvidenceLambda(body~, ..) => {
      let function = match extract_top_function(body) {
        Some(function) => function
        None =>
          raise UnsupportedExpression(
            detail="generic nested value must contain a function",
          )
      }
      self.lower_nested_function(function)
    }
  }
}

///|
fn FunctionLowerer::lower_evidence_apply(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.RuntimeArgument],
) -> LocalValue raise LoisvmLoweringError {
  ignore(arguments)
  let original = self.lower_atom(callee)
  let lowered = match original {
    EvidenceApplied(_, _)
    | EvidenceAppliedCallable(_, _, _, _)
    | EvidenceAppliedNestedCallable(_, _) => original
    _ =>
      match self.planned_callable_port(site) {
        Some(callable) =>
          self.materialize_planned_callable_atom(callee, callable)
        None => original
      }
  }
  if local_value_type(lowered) is Some(type_) &&
    !(self.image.runtime_type(type_) is Concrete(Forall(_, _))) {
    return lowered
  }
  let application = self.planned_evidence_application(site)
  match lowered {
    Global(global) => EvidenceApplied(global, application)
    Slot(callable, type_, shape) =>
      EvidenceAppliedCallable(callable, type_, shape, application)
    NestedCallable(callable) =>
      EvidenceAppliedNestedCallable(callable, application)
    EvidenceApplied(global, _) => EvidenceApplied(global, application)
    EvidenceAppliedCallable(callable, type_, shape, _) =>
      EvidenceAppliedCallable(callable, type_, shape, application)
    EvidenceAppliedNestedCallable(callable, _) =>
      EvidenceAppliedNestedCallable(callable, application)
    RecursiveFunction(_, _, _) as recursive => {
      guard self.materialize_local(recursive) is Slot(callable, type_, shape) else {
        abort("recursive callable was not materialized")
      }
      EvidenceAppliedCallable(callable, type_, shape, application)
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
  site : @anf.AnfBindingId,
  construct : @anf.AnfConstruct,
) -> LocalValue raise LoisvmLoweringError {
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
  let physical_construct = self.planned_construct(site)
  let family = physical_construct.family
  guard family.constructor_plan(construct.data_constructor)
    is Some(constructor_plan) else {
    raise RepresentationSpecializationInvariant(
      detail="planned data family lacks its construction contract",
    )
  }
  let storage_types = constructor_plan.storage_types
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
  let scalar_contract = physical_construct.scalar
  if scalar_contract is Some(contract) {
    if contract.data_constructor != construct.data_constructor ||
      contract.payload_types.length() != construct.payloads.length() {
      raise RepresentationSpecializationInvariant(
        detail="closed aggregate contract does not match its allocation",
      )
    }
    let payloads = []
    for index, payload in construct.payloads {
      let target_type = contract.payload_types[index]
      let source = match
        (payload, physical_construct.callable_payloads[index]) {
        (Function(_) | EvidenceLambda(..), Some(instance)) =>
          self.materialize_planned_callable_atom(payload, instance)
        _ => self.lower_atom(payload)
      }
      let source = self.materialize_local(source)
      let flow = physical_construct.payloads[index]
      let source_shape = self.physical_shape(flow.source)
      let target_shape = self.physical_shape(flow.target)
      if self.local_physical_shape(source) != source_shape {
        raise RepresentationSpecializationInvariant(
          detail="closed aggregate payload \{index} at \{Repr(site)} produced \{Repr(self.local_physical_shape(source))}, but its physical flow owns \{Repr(source_shape)}",
        )
      }
      payloads.push(
        self.materialize_planned_value_flow(
          "closed aggregate payload \{index} at \{Repr(site)}",
          source,
          target_type,
          target_shape,
          flow.bridge,
        ),
      )
    }
    return ClosedAggregate(contract, payloads)
  }
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
  for index, payload in construct.payloads {
    let storage_type = storage_types[index]
    let planned_callable = physical_construct.callable_payloads[index]
    let source = match (payload, planned_callable) {
      (Function(_) | EvidenceLambda(..), Some(instance)) =>
        self.materialize_planned_callable_atom(payload, instance)
      _ => self.lower_atom(payload)
    }
    let source = self.materialize_local(source)
    let flow = physical_construct.payloads[index]
    let source_shape = self.physical_shape(flow.source)
    let target_shape = self.physical_shape(flow.target)
    if self.local_physical_shape(source) != source_shape {
      raise RepresentationSpecializationInvariant(
        detail="data payload \{index} at \{Repr(site)} with callable provenance \{Repr(planned_callable)} produced \{Repr(self.local_physical_shape(source))}, but its physical flow owns \{Repr(source_shape)}",
      )
    }
    let lowered = self.materialize_planned_value_flow(
      "data payload \{index} at \{Repr(site)}",
      source,
      storage_type,
      target_shape,
      flow.bridge,
    )
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
    Some(InstanceGlobal(global, type_, shape)) => {
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
fn FunctionLowerer::lower_literal(
  self : FunctionLowerer,
  literal : @buslane.Literal,
) -> LocalValue raise LoisvmLoweringError {
  match literal {
    Unit => Unit
    Bool(value) => {
      let type_ = @anf.RuntimeType::Scalar(Bool)
      let slot = self.fresh_slot(type_)
      self.emit(ConstBool(slot, value))
      self.slot_value(slot, type_)
    }
    I64(value) => {
      let type_ = @anf.RuntimeType::Scalar(I64)
      let slot = self.fresh_slot(type_)
      self.emit(ConstI64(slot, value))
      self.slot_value(slot, type_)
    }
    I32(value) => {
      let type_ = @anf.RuntimeType::Scalar(I32)
      let slot = self.fresh_slot(type_)
      self.emit(ConstI32(slot, value))
      self.slot_value(slot, type_)
    }
    F32(value) => {
      let type_ = @anf.RuntimeType::Scalar(F32)
      let slot = self.fresh_slot(type_)
      self.emit(ConstF32(slot, value.reinterpret_as_int()))
      self.slot_value(slot, type_)
    }
    Char(value) => {
      let type_ = @anf.RuntimeType::Scalar(Char)
      let slot = self.fresh_slot(type_)
      self.emit(ConstChar(slot, value))
      self.slot_value(slot, type_)
    }
    F64(value) => {
      let type_ = @anf.RuntimeType::Scalar(F64)
      let slot = self.fresh_slot(type_)
      self.emit(ConstF64(slot, value.reinterpret_as_int64()))
      self.slot_value(slot, type_)
    }
    String(value) => {
      let type_ = @anf.RuntimeType::ByteSequence
      let slot = self.fresh_slot(type_)
      let constant = self.image.intern_string(value)
      ignore(self.image.intern_layout(ByteSequence))
      self.emit(ConstString(slot, constant))
      self.slot_value(slot, type_)
    }
  }
}

///|
