///|
fn FunctionLowerer::lower_expr(
  self : FunctionLowerer,
  expression : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.lower_atom(atom)
    Let(binding, body) => {
      let lowered = self.lower_rhs(binding.id(), binding.rhs())
      match binding {
        Value(id~, ..) => self.bindings.push({ value: id, lowered })
        Temp(temp~, ..) => self.temps.push({ temp, lowered })
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
    Atom(atom) => self.lower_atom(atom)
    ApplyEvidence(callee~, arguments~) =>
      self.lower_evidence_apply(callee, arguments)
    Call(callee~, arguments~) => self.lower_call(site, callee, arguments)
    Construct(construct) => self.lower_construct(site, construct)
    Match(match_) => self.lower_match(match_)
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
  callee : @anf.AnfAtom,
  arguments : Array[@anf.RuntimeArgument],
) -> LocalValue raise LoisvmLoweringError {
  match self.lower_atom(callee) {
    Global(global) => EvidenceApplied(global, arguments)
    Slot(callable, type_) => EvidenceAppliedCallable(callable, type_, arguments)
    NestedCallable(callable) =>
      EvidenceAppliedNestedCallable(callable, arguments)
    EvidenceApplied(global, applied) =>
      EvidenceApplied(global, applied + arguments)
    EvidenceAppliedCallable(callable, type_, applied) =>
      EvidenceAppliedCallable(callable, type_, applied + arguments)
    EvidenceAppliedNestedCallable(callable, applied) =>
      EvidenceAppliedNestedCallable(callable, applied + arguments)
    AdaptedCallable(adaptation) =>
      EvidenceAppliedAdaptedCallable(adaptation, arguments)
    EvidenceAppliedAdaptedCallable(adaptation, applied) =>
      EvidenceAppliedAdaptedCallable(adaptation, applied + arguments)
    RecursiveFunction(_, _, _) as recursive => {
      guard self.materialize_local(recursive) is Slot(callable, type_) else {
        abort("recursive callable was not materialized")
      }
      EvidenceAppliedCallable(callable, type_, arguments)
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
  let family_key = if self.representation_worker {
    self.image.callable_instances
    .data_family_at(self.caller_instances, site)
    .unwrap_or(Declaration(info.owner))
  } else {
    Declaration(info.owner)
  }
  let family = self.image.data_family(family_key)
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
  let scalar_contract = self.image.callable_instances.scalar_allocation_contract(
    self.caller_instances,
    site,
  )
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
      let source = self.lower_atom(payload)
      let source_type = local_value_type(source).unwrap_or(target_type)
      payloads.push(
        self.adapt_local_value_with_substitutions(
          source,
          source_type,
          target_type,
          self.substitutions,
        ),
      )
    }
    return ClosedAggregate(contract, payloads)
  }
  let fields = []
  for parameter in info.hidden_evidence_parameters {
    guard substitutions.argument(parameter.id) is Some(argument) else {
      raise InvalidTypeApplication(detail="missing hidden runtime evidence")
    }
    fields.push(self.runtime_evidence(parameter, argument))
  }
  let witnesses = []
  for index, payload in construct.payloads {
    let formal_type = info.payload_types[index]
    let storage_type = storage_types[index]
    let actual_type = substitutions.apply_type(
      self.image.runtime_types,
      formal_type,
    )
    let planned_callable = if self.representation_worker {
      self.image.callable_instances.data_callable_payload_instance(
        self.caller_instances,
        site,
        index,
      )
    } else {
      None
    }
    let source = match planned_callable {
      Some(instance) =>
        self.materialize_planned_callable_atom(payload, instance)
      None => self.lower_atom(payload)
    }
    let source = self.materialize_local(source)
    let lowered = if self.image.runtime_type(storage_type) is Erased(_) {
      match source {
        Slot(slot, _) if self.values[slot.value].erased_companion
          is Some(witness) => {
          witnesses.push(witness)
          Slot(slot, storage_type)
        }
        _ => {
          let witness = self.layout_witness(runtime_type_evidence(actual_type))
          witnesses.push(witness)
          Slot(self.erase_value(source, actual_type, witness), storage_type)
        }
      }
    } else {
      self.adapt_local_value_with_substitutions(
        source, actual_type, storage_type, substitutions,
      )
    }
    let lowered = self.materialize_local(lowered)
    match lowered {
      Unit =>
        if storage_type != Unit {
          raise UnsupportedExpression(
            detail="non-Unit data field has no runtime representation",
          )
        }
      Slot(field, _) => fields.push(field)
      _ =>
        raise UnsupportedExpression(
          detail="data field has no runtime representation",
        )
    }
  }
  let shape = self.image.materialize_data_shape(
    family,
    constructor_plan,
    info,
    self.data_families,
  )
  let layout = self.image.intern_layout(Data(shape))
  let destination = self.fresh_slot(result_type)
  self.emit(MakeData(destination, shape, Immediate(layout), witnesses, fields))
  Slot(destination, result_type)
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
    Some(InstanceGlobal(global, type_)) => {
      let destination = self.fresh_borrowed_slot(type_)
      self.emit(BorrowGlobal(destination, global))
      Slot(destination, type_)
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
      Slot(slot, type_)
    }
    I64(value) => {
      let type_ = @anf.RuntimeType::Scalar(I64)
      let slot = self.fresh_slot(type_)
      self.emit(ConstI64(slot, value))
      Slot(slot, type_)
    }
    I32(value) => {
      let type_ = @anf.RuntimeType::Scalar(I32)
      let slot = self.fresh_slot(type_)
      self.emit(ConstI32(slot, value))
      Slot(slot, type_)
    }
    F32(value) => {
      let type_ = @anf.RuntimeType::Scalar(F32)
      let slot = self.fresh_slot(type_)
      self.emit(ConstF32(slot, value.reinterpret_as_int()))
      Slot(slot, type_)
    }
    Char(value) => {
      let type_ = @anf.RuntimeType::Scalar(Char)
      let slot = self.fresh_slot(type_)
      self.emit(ConstChar(slot, value))
      Slot(slot, type_)
    }
    F64(value) => {
      let type_ = @anf.RuntimeType::Scalar(F64)
      let slot = self.fresh_slot(type_)
      self.emit(ConstF64(slot, value.reinterpret_as_int64()))
      Slot(slot, type_)
    }
    String(value) => {
      let type_ = @anf.RuntimeType::ByteSequence
      let slot = self.fresh_slot(type_)
      let constant = self.image.intern_string(value)
      ignore(self.image.intern_layout(ByteSequence))
      self.emit(ConstString(slot, constant))
      Slot(slot, type_)
    }
  }
}

///|
