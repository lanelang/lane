///|
fn FunctionLowerer::find_witness(
  self : FunctionLowerer,
  parameter : @buslane.TypeParameterId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  for binding in self.witnesses {
    if binding.parameter == parameter {
      return binding.value
    }
  }
  raise InvalidTypeApplication(
    detail="missing in-scope layout witness for \{Repr(parameter)}",
  )
}

///|
fn FunctionLowerer::layout_witness(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let type_ = self.instantiate_runtime_type(type_)
  let type_ = match self.image.layout_runtime_type(type_) {
    Erased(Parameter(parameter)) => return self.find_witness(parameter)
    Erased(Apply(Parameter(constructor_parameter), arguments)) =>
      return self.apply_layout_constructor(constructor_parameter, arguments)
    Erased(type_) => raise UnsupportedType(type_~)
    Concrete(type_) => type_
  }
  let recipe : @bytecode.LayoutRecipe = match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) => Bool
    Primitive(I64) => I64
    Primitive(I32) => I32
    Primitive(Char) => Char
    Primitive(F32) => F32
    Primitive(F64) => F64
    Primitive(String) => ByteSequence
    Primitive(Byte) => Byte
    Primitive(Bytes) => ByteSequence
    Function(_, _, _) | Forall(_, _) => Callable
    Constructor(_) | Apply(_, _) => Reference
    _ => raise UnsupportedType(type_~)
  }
  let layout = self.image.intern_layout(recipe)
  let witness = self.fresh_metadata(layout_witness_metadata())
  self.emit(ConstLayout(witness, layout))
  witness
}

///|
fn FunctionLowerer::erase_value(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @buslane.Type,
  erased_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
  witness : @vmcfg.ValueId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let destination = self.fresh_erased_slot(witness, Owned)
  let materialized = self.materialize_local(value)
  let type_ = local_value_type(materialized).unwrap_or(source_type)
  match self.image.runtime_type(type_) {
    Erased(_) => {
      guard materialized is Slot(source, _) else {
        raise InvalidTypeApplication(
          detail="generic argument representation does not match its type",
        )
      }
      self.emit(Move(destination, source))
    }
    Concrete(type_) =>
      match (materialized, type_) {
        (Unit, Primitive(Unit)) => self.emit(EraseUnit(destination))
        (
          Slot(source, _),
          Primitive(Bool)
          | Primitive(I32)
          | Primitive(Char)
          | Primitive(String)
          | Primitive(Byte)
          | Primitive(Bytes)
          | Constructor(_)
          | Apply(_, _),
        ) => self.emit(EraseI32(destination, source))
        (Slot(source, _), Primitive(I64)) =>
          self.emit(EraseI64(destination, source))
        (Slot(source, _), Primitive(F32)) =>
          self.emit(EraseF32(destination, source))
        (Slot(source, _), Function(_, _, _) | Forall(_, _)) => {
          let (canonical_type, bindings) = self.erased_callable_abi(
            erased_type, type_, substitutions,
          )
          guard self.materialize_local(
              self.make_callable_adapter(
                source, type_, canonical_type, bindings,
              ),
            )
            is Slot(adapted, _) else {
            abort("callable adapter was not materialized")
          }
          self.emit(EraseI64(destination, adapted))
        }
        (Slot(source, _), Primitive(F64)) =>
          self.emit(EraseF64(destination, source))
        _ =>
          raise InvalidTypeApplication(
            detail="generic argument representation does not match its type",
          )
      }
  }
  destination
}

///|
fn FunctionLowerer::unerase_value(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  erased_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> LocalValue raise LoisvmLoweringError {
  let target_type = apply_type_substitution(target_type, substitutions)
  match self.image.runtime_type(target_type) {
    Erased(_) => Slot(source, target_type)
    Concrete(runtime_type) =>
      match runtime_type {
        Primitive(Unit) => {
          self.emit(UneraseUnit(source))
          Unit
        }
        Primitive(Bool)
        | Primitive(I32)
        | Primitive(Char)
        | Primitive(String)
        | Primitive(Byte)
        | Primitive(Bytes)
        | Constructor(_)
        | Apply(_, _) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseI32(destination, source))
          Slot(destination, target_type)
        }
        Primitive(I64) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseI64(destination, source))
          Slot(destination, target_type)
        }
        Primitive(F32) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseF32(destination, source))
          Slot(destination, target_type)
        }
        Function(_, _, _) | Forall(_, _) => {
          let (canonical_type, bindings) = self.erased_callable_abi(
            erased_type, runtime_type, substitutions,
          )
          let canonical = self.fresh_slot(canonical_type)
          self.emit(UneraseI64(canonical, source))
          self.make_callable_adapter(
            canonical, canonical_type, runtime_type, bindings,
          )
        }
        Primitive(F64) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseF64(destination, source))
          Slot(destination, target_type)
        }
        _ => raise UnsupportedType(type_=runtime_type)
      }
  }
}

///|
fn FunctionLowerer::erased_callable_abi(
  self : FunctionLowerer,
  erased_type : @buslane.Type,
  concrete_type : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
) -> (@buslane.Type, @buslane.TypeSubstitution) raise LoisvmLoweringError {
  match erased_position_callable_type(erased_type, substitutions, []) {
    Some(callable) => (callable, substitutions)
    None => self.canonical_callable_type(concrete_type)
  }
}

///|
fn erased_position_callable_type(
  type_ : @buslane.Type,
  substitutions : @buslane.TypeSubstitution,
  visited : Array[@buslane.TypeParameterId],
) -> @buslane.Type? raise LoisvmLoweringError {
  match type_ {
    Function(_, _, _) | Forall(_, _) => Some(type_)
    Parameter(parameter) if parameter.index < 0 && !visited.contains(parameter) => {
      guard type_substitution_type_argument(substitutions, parameter)
        is Some(type_) else {
        return None
      }
      let visited = visited.copy()
      visited.push(parameter)
      erased_position_callable_type(type_, substitutions, visited)
    }
    _ => None
  }
}

///|
