///|
fn FunctionLowerer::lower_expr(
  self : FunctionLowerer,
  expression : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.lower_atom(atom)
    Let(binding, body) => {
      let lowered = self.lower_rhs(binding.rhs())
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
  rhs : @anf.AnfRhs,
) -> LocalValue raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => self.lower_atom(atom)
    TypeApply(callee~, arguments~) => self.lower_type_apply(callee, arguments)
    Call(callee~, arguments~) => self.lower_call(callee, arguments)
    Construct(construct) => self.lower_construct(construct)
    Match(match_) => self.lower_match(match_)
    Perform(_) =>
      raise UnsupportedExpression(
        detail="perform must be erased before VM CFG lowering",
      )
    Handle(_) =>
      raise UnsupportedExpression(
        detail="handlers must be erased before VM CFG lowering",
      )
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
    TypeLambda(type_parameters~, body~) => {
      let function = match extract_top_function(body) {
        Some(function) => function
        None =>
          raise UnsupportedExpression(
            detail="generic nested value must contain a function",
          )
      }
      self.lower_nested_function_with_type(
        function,
        Forall(type_parameters, self.image.anf_function_type(function)),
      )
    }
  }
}

///|
fn FunctionLowerer::lower_type_apply(
  self : FunctionLowerer,
  callee : @anf.AnfAtom,
  arguments : Array[@buslane.GenericArgument],
) -> LocalValue raise LoisvmLoweringError {
  match self.lower_atom(callee) {
    Global(global) => TypeApplied(global, arguments)
    Slot(callable, type_) => TypeAppliedCallable(callable, type_, arguments)
    TypeApplied(global, applied) => TypeApplied(global, applied + arguments)
    TypeAppliedCallable(callable, type_, applied) =>
      TypeAppliedCallable(callable, type_, applied + arguments)
    AdaptedCallable(adaptation) =>
      TypeAppliedAdaptedCallable(adaptation, arguments)
    TypeAppliedAdaptedCallable(adaptation, applied) =>
      TypeAppliedAdaptedCallable(adaptation, applied + arguments)
    RecursiveFunction(_, _, _) as recursive => {
      guard self.materialize_local(recursive) is Slot(callable, type_) else {
        abort("recursive callable was not materialized")
      }
      TypeAppliedCallable(callable, type_, arguments)
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
  let owner_substitutions = self.data_type_substitutions(
    owner_info.parameters,
    construct.type_arguments,
  )
  let hidden_substitutions = self.data_type_substitutions(
    info.hidden_type_parameters,
    construct.hidden_witnesses,
  )
  let substitutions = owner_substitutions.overlay(hidden_substitutions)
  if construct.payloads.length() != info.payload_types.length() {
    raise InvalidDataPayloadCount(
      data_constructor=construct.data_constructor,
      expected=info.payload_types.length(),
      actual=construct.payloads.length(),
    )
  }
  let fields = []
  for parameter in info.hidden_type_parameters {
    if self.image.requires_runtime_evidence(parameter) {
      let type_ = required_type_substitution_argument(substitutions, parameter)
      fields.push(self.runtime_evidence(parameter, type_))
    }
  }
  let witnesses = []
  for index, payload in construct.payloads {
    let formal_type = info.payload_types[index]
    let actual_type = apply_type_substitution(formal_type, substitutions)
    let source = self.materialize_local(self.lower_atom(payload))
    let lowered = if self.image.runtime_type(formal_type) is Erased(_) {
      match source {
        Slot(slot, _) if self.values[slot.value].erased_companion
          is Some(witness) => {
          witnesses.push(witness)
          Slot(slot, formal_type)
        }
        _ => {
          let witness = self.layout_witness(actual_type)
          witnesses.push(witness)
          Slot(
            self.erase_value(
              source, actual_type, formal_type, substitutions, witness,
            ),
            formal_type,
          )
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
        if formal_type != Primitive(Unit) {
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
  let shape = self.image.data_shape(construct.data_constructor, info)
  let layout = self.image.intern_layout(Data(shape))
  let result_type = if owner_info.parameters.is_empty() {
    @buslane.Type::Constructor(info.owner)
  } else {
    Apply(Constructor(info.owner), construct.type_arguments)
  }
  let destination = self.fresh_slot(result_type)
  self.emit(MakeData(destination, shape, Immediate(layout), witnesses, fields))
  Slot(destination, result_type)
}

///|
fn ImageLowerer::data_shape(
  self : ImageLowerer,
  data_constructor : @buslane.DataConId,
  info : @buslane.DataConInfo,
) -> @bytecode.ObjectShapeId raise LoisvmLoweringError {
  let members : Array[@bytecode.MemberSchema] = []
  for parameter in info.hidden_type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let metadata = self.runtime_evidence_metadata(parameter)
      members.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        kind: metadata.kind,
        witness_ordinal: None,
      })
    }
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
    } else if self.runtime_type(payload_type) is Concrete(Primitive(Unit)) {
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
      let type_ = @buslane.Type::Primitive(Bool)
      let slot = self.fresh_slot(type_)
      self.emit(ConstBool(slot, value))
      Slot(slot, type_)
    }
    I64(value) => {
      let type_ = @buslane.Type::Primitive(I64)
      let slot = self.fresh_slot(type_)
      self.emit(ConstI64(slot, value))
      Slot(slot, type_)
    }
    I32(value) => {
      let type_ = @buslane.Type::Primitive(I32)
      let slot = self.fresh_slot(type_)
      self.emit(ConstI32(slot, value))
      Slot(slot, type_)
    }
    F32(value) => {
      let type_ = @buslane.Type::Primitive(F32)
      let slot = self.fresh_slot(type_)
      self.emit(ConstF32(slot, value.reinterpret_as_int()))
      Slot(slot, type_)
    }
    Char(value) => {
      let type_ = @buslane.Type::Primitive(Char)
      let slot = self.fresh_slot(type_)
      self.emit(ConstChar(slot, value))
      Slot(slot, type_)
    }
    F64(value) => {
      let type_ = @buslane.Type::Primitive(F64)
      let slot = self.fresh_slot(type_)
      self.emit(ConstF64(slot, value.reinterpret_as_int64()))
      Slot(slot, type_)
    }
    String(value) => {
      let type_ = @buslane.Type::Primitive(String)
      let slot = self.fresh_slot(type_)
      let constant = self.image.intern_string(value)
      ignore(self.image.intern_layout(ByteSequence))
      self.emit(ConstString(slot, constant))
      Slot(slot, type_)
    }
  }
}

///|
