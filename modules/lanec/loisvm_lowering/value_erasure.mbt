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
    detail="missing in-scope layout witness for \{to_repr(parameter)}",
  )
}

///|
fn FunctionLowerer::effect_context_witness(
  self : FunctionLowerer,
  effect : @buslane.Effect,
) -> @vmcfg.ValueId {
  let layout = self.image.intern_layout(effect_context_layout_recipe(effect))
  let witness = self.fresh_metadata(layout_witness_metadata())
  self.emit(ConstLayout(witness, layout))
  witness
}

///|
fn effect_context_layout_recipe(
  effect : @buslane.Effect,
) -> @bytecode.LayoutRecipe {
  if effect.canonicalize() == Empty {
    Unit
  } else {
    Reference
  }
}

///|
fn FunctionLowerer::layout_witness(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if type_ is Parameter(parameter) {
    return self.find_witness(parameter)
  }
  let recipe : @bytecode.LayoutRecipe = match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) => Bool
    Primitive(Int) => Int
    Primitive(Double) => Double
    Primitive(String) => String
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
  type_ : @buslane.Type,
  witness : @vmcfg.ValueId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let destination = self.fresh_erased_slot(witness, Owned)
  let materialized = self.materialize_local(value)
  let type_ = local_value_type(materialized).unwrap_or(type_)
  match (materialized, type_) {
    (Unit, Primitive(Unit)) => self.emit(EraseUnit(destination))
    (
      Slot(source, _),
      Primitive(Bool)
      | Primitive(String)
      | Constructor(_)
      | Apply(_, _),
    ) => self.emit(EraseI32(destination, source))
    (Slot(source, _), Primitive(Int)) =>
      self.emit(EraseI64(destination, source))
    (Slot(source, _), Function(_, _, _) | Forall(_, _)) => {
      let (canonical_type, bindings) = self.canonical_callable_type(type_)
      guard self.make_callable_adapter(source, type_, canonical_type, bindings)
        is Slot(adapted, _) else {
        abort("callable adapter was not materialized")
      }
      self.emit(EraseI64(destination, adapted))
    }
    (Slot(source, _), Primitive(Double)) =>
      self.emit(EraseF64(destination, source))
    (Slot(source, Parameter(_)), Parameter(_)) =>
      self.emit(Move(destination, source))
    _ =>
      raise InvalidTypeApplication(
        detail="generic argument representation does not match its type",
      )
  }
  destination
}

///|
fn FunctionLowerer::unerase_value(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  type_ : @buslane.Type,
) -> LocalValue raise LoisvmLoweringError {
  match type_ {
    Primitive(Unit) => {
      self.emit(UneraseUnit(source))
      Unit
    }
    Primitive(Bool) | Primitive(String) | Constructor(_) | Apply(_, _) => {
      let destination = self.fresh_slot(type_)
      self.emit(UneraseI32(destination, source))
      Slot(destination, type_)
    }
    Primitive(Int) => {
      let destination = self.fresh_slot(type_)
      self.emit(UneraseI64(destination, source))
      Slot(destination, type_)
    }
    Function(_, _, _) | Forall(_, _) => {
      let (canonical_type, bindings) = self.canonical_callable_type(type_)
      let canonical = self.fresh_slot(canonical_type)
      self.emit(UneraseI64(canonical, source))
      self.make_callable_adapter(canonical, canonical_type, type_, bindings)
    }
    Primitive(Double) => {
      let destination = self.fresh_slot(type_)
      self.emit(UneraseF64(destination, source))
      Slot(destination, type_)
    }
    Parameter(_) => Slot(source, type_)
    _ => raise UnsupportedType(type_~)
  }
}

///|
