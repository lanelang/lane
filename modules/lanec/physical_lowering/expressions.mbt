///|
fn FunctionLowerer::lower_expr(
  self : FunctionLowerer,
  expression : @anf.AnfExpr,
) -> LocalValue raise PhysicalLoweringError {
  match expression {
    Atom(atom) => self.lower_atom(atom)
    Let(Value(id~, rhs=Atom(JoinPoint(function))), body) =>
      self.lower_join_group([{ id, rhs: JoinPoint(function), }], body)
    Let(binding, body) => {
      let lowered = self.lower_rhs(binding.rhs())
      if lowered is ControlTransferred {
        return ControlTransferred
      }
      match binding {
        Value(id~, ..) => self.bindings.push({ value: id, lowered, })
        Temp(temp~, ..) => self.temps.push({ temp, lowered, })
      }
      self.lower_expr(body)
    }
    LetRec(bindings, body) => {
      guard !bindings.is_empty() else {
        raise RepresentationElaborationInvariant(
          detail="verified Runtime ANF contains an empty recursive group",
        )
      }
      let first = bindings[0]
      match first.rhs {
        Function(_) | EvidenceLambda(_) =>
          self.lower_recursive_group(bindings, body)
        DirectFunction(_) => self.lower_direct_recursive_group(bindings, body)
        JoinPoint(_) => self.lower_join_group(bindings, body)
        Literal(_) | Ref(_) | Temp(_) =>
          raise RepresentationElaborationInvariant(
            detail="verified Runtime ANF contains a non-callable recursive group",
          )
      }
    }
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
  rhs : @anf.AnfRhs,
) -> LocalValue raise PhysicalLoweringError {
  match rhs {
    Atom(atom) => self.lower_atom(atom)
    ApplyEvidence(callee~, arguments~) =>
      self.lower_evidence_apply(callee, arguments)
    Call(callee~, arguments~) => self.lower_call(callee, arguments)
    Construct(construct) => self.lower_construct(construct)
    Match(match_) => self.lower_match(match_)
  }
}

///|
fn FunctionLowerer::materialize_expression_result(
  self : FunctionLowerer,
  expression : @anf.AnfExpr,
) -> LocalValue raise PhysicalLoweringError {
  let result = self.lower_expr(expression)
  if result is ControlTransferred {
    result
  } else {
    self.materialize_local(result)
  }
}

///|
fn FunctionLowerer::lower_atom(
  self : FunctionLowerer,
  atom : @anf.AnfAtom,
) -> LocalValue raise PhysicalLoweringError {
  match atom {
    Literal(literal) => self.lower_literal(literal)
    Ref(value) => self.find_value(value)
    Temp(temp) => self.find_temp(temp)
    Function(function) => self.lower_nested_function(function)
    DirectFunction(function) => self.lower_nested_direct_function(function)
    JoinPoint(_) =>
      raise RepresentationElaborationInvariant(
        detail="verified Runtime ANF join point escaped its lexical binding",
      )
    EvidenceLambda(parameters~, body~) => {
      let (nested_parameters, function) = match
        extract_top_generic_function(body) {
        Some(parts) => parts
        None =>
          raise RepresentationElaborationInvariant(
            detail="verified Runtime ANF generic value is not callable",
          )
      }
      self.lower_nested_function_with_type(
        function,
        Forall(
          parameters + nested_parameters,
          self.image.anf_function_type(function),
        ),
      )
    }
  }
}

///|
fn FunctionLowerer::lower_evidence_apply(
  self : FunctionLowerer,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.RuntimeArgument],
) -> LocalValue raise PhysicalLoweringError {
  match self.lower_atom(callee) {
    Global(global) => EvidenceApplied(global, arguments)
    Slot(callable, type_) => EvidenceAppliedCallable(callable, type_, arguments)
    EvidenceApplied(global, applied) =>
      EvidenceApplied(global, applied + arguments)
    EvidenceAppliedCallable(callable, type_, applied) =>
      EvidenceAppliedCallable(callable, type_, applied + arguments)
    EvidenceAppliedFunction(function, type_, environment, applied) =>
      EvidenceAppliedFunction(function, type_, environment, applied + arguments)
    AdaptedCallable(adaptation) =>
      EvidenceAppliedAdaptedCallable(adaptation, arguments)
    EvidenceAppliedAdaptedCallable(adaptation, applied) =>
      EvidenceAppliedAdaptedCallable(adaptation, applied + arguments)
    RecursiveFunction(function, type_, environment) =>
      EvidenceAppliedFunction(function, type_, environment, arguments)
    _ =>
      raise InvalidTypeApplication(
        detail="type application target is not a generic callable",
      )
  }
}

///|
fn FunctionLowerer::lower_construct(
  self : FunctionLowerer,
  construct : @anf.AnfConstruct,
) -> LocalValue raise PhysicalLoweringError {
  let info = self.image.metadata.verified_data_constructor_info(
    construct.data_constructor,
  )
  let owner_info = self.image.metadata.verified_type_info(info.owner)
  let owner_substitutions = RuntimeSubstitution::from_arguments(
    owner_info.evidence_parameters,
    construct.type_arguments,
  )
  let hidden_substitutions = RuntimeSubstitution::from_arguments(
    info.hidden_evidence_parameters,
    construct.hidden_arguments,
  )
  let substitutions = owner_substitutions.overlay(hidden_substitutions)
  if construct.payloads.length() != info.payload_types.length() {
    raise RepresentationElaborationInvariant(
      detail="verified Runtime ANF constructor payload arity is invalid",
    )
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
    let actual_type = substitutions.apply_type(
      self.image.runtime_types,
      formal_type,
    )
    let source = self.materialize_local(self.lower_atom(payload))
    let lowered = if self.image.runtime_type(formal_type) is Erased(_) {
      match source {
        Slot(slot, _) if self.values[slot.value].erased_companion
          is Some(witness) => {
          witnesses.push(witness)
          Slot(slot, formal_type)
        }
        _ => {
          let witness = self.layout_witness(runtime_type_evidence(actual_type))
          witnesses.push(witness)
          Slot(self.erase_value(source, actual_type, witness), formal_type)
        }
      }
    } else {
      self.adapt_local_value_with_substitutions(
        source, actual_type, formal_type, substitutions,
      )
    }
    let lowered = self.materialize_local(lowered)
    match lowered {
      Unit =>
        if formal_type != Unit {
          raise RepresentationElaborationInvariant(
            detail="non-Unit data field has no runtime representation",
          )
        }
      Slot(field, _) => fields.push(field)
      _ =>
        raise RepresentationElaborationInvariant(
          detail="data field has no runtime representation",
        )
    }
  }
  let shape = self.image.data_shape(construct.data_constructor, info)
  let layout = self.image.intern_layout(Data(shape))
  let result_type = @anf.RuntimeType::Data(info.owner, construct.type_arguments)
  let destination = self.fresh_slot(result_type)
  self.emit(MakeData(destination, shape, Immediate(layout), witnesses, fields))
  Slot(destination, result_type)
}

///|
fn ImageLowerer::data_shape(
  self : ImageLowerer,
  data_constructor : @buslane.DataConId,
  info : @anf.RuntimeDataConstructorInfo,
) -> @physical.ObjectShapeId raise PhysicalLoweringError {
  let members : Array[@physical.MemberSchema] = []
  for parameter in info.hidden_evidence_parameters {
    let metadata = runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
  }
  let mut witness_ordinal = 0
  for payload_type in info.payload_types {
    if self.runtime_type(payload_type) is Erased(_) {
      members.push({
        representation: I64,
        cleanup: OwnedErased,
        kind: ErasedValue,
        witness_ordinal: Some(witness_ordinal),
      })
      witness_ordinal += 1
    } else if self.runtime_type(payload_type) is Concrete(Unit) {
      ()
    } else {
      let metadata = self.slot_metadata(payload_type)
      members.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
        witness_ordinal: None,
      })
    }
  }
  let constructor_tag = self.constructor_tag(data_constructor, info.owner)
  self.intern_object_shape(
    Data({
      family: self.intern_data_family(info.owner),
      constructor_tag,
      stored_witness_count: witness_ordinal,
      members,
    }),
  )
}

///|
fn ImageLowerer::constructor_tag(
  self : ImageLowerer,
  data_constructor : @buslane.DataConId,
  owner : @buslane.TypeId,
) -> Int raise PhysicalLoweringError {
  let owner_info = self.metadata.verified_type_info(owner)
  for index, candidate in owner_info.constructors {
    if candidate == data_constructor {
      return index
    }
  }
  raise RepresentationElaborationInvariant(
    detail="verified Runtime ANF constructor is absent from its owner family",
  )
}

///|
fn FunctionLowerer::find_value(
  self : FunctionLowerer,
  value : @buslane.ValueId,
) -> LocalValue raise PhysicalLoweringError {
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
    None =>
      raise RepresentationElaborationInvariant(
        detail="verified Runtime ANF value is absent from lowering scope",
      )
  }
}

///|
fn FunctionLowerer::find_temp(
  self : FunctionLowerer,
  temp : @anf.AnfTempId,
) -> LocalValue raise PhysicalLoweringError {
  for binding in self.temps.rev_iter() {
    if binding.temp == temp {
      return binding.lowered
    }
  }
  raise RepresentationElaborationInvariant(
    detail="verified Runtime ANF temporary is absent from lowering scope",
  )
}

///|
fn FunctionLowerer::lower_literal(
  self : FunctionLowerer,
  literal : @buslane.Literal,
) -> LocalValue raise PhysicalLoweringError {
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
