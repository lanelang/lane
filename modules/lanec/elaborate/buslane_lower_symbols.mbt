///|
fn BuslaneLowerer::define_external(
  self : BuslaneLowerer,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  let id = self.metadata.define_value(External, type_)
  self.external_terms.push(External(id))
  id
}

///|
fn BuslaneLowerer::define_builtin_external(
  self : BuslaneLowerer,
  name : String,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  let value = self.define_external(type_)
  self.builtin_externals.push({ value, name, type_ })
  value
}

///|
fn BuslaneLowerer::define_fresh_value(
  self : BuslaneLowerer,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  self.metadata.define_value(kind, type_)
}

///|
fn BuslaneLowerer::define_value(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  if self.registry.find_value(source) is Some(target) {
    return target
  }
  let target = self.metadata.define_value(kind, type_)
  self.registry.register_value(source, target)
}

///|
fn BuslaneLowerer::define_operation(
  self : BuslaneLowerer,
  source : @symbol.OperationSymbolId,
  owner : @buslane.EffectId,
  type_parameters : Array[@types.TypeParameter],
  payload : Array[@types.Type],
  result : @types.Type,
) -> @buslane.OperationId {
  if self.registry.find_operation(source) is Some(target) {
    return target
  }
  for parameter in type_parameters {
    ignore(self.define_type_parameter(parameter))
  }
  let target = self.metadata.define_operation(
    owner,
    payload.map(fn(type_) { self.lower_type(type_) }),
    self.lower_type(result),
  )
  self.registry.register_operation(source, target)
}

///|
fn BuslaneLowerer::bind_value_alias(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
  target : @buslane.ValueId,
) -> Unit {
  ignore(self.registry.register_value(source, target))
}

///|
fn BuslaneLowerer::define_type_parameter(
  self : BuslaneLowerer,
  parameter : @types.TypeParameter,
) -> @buslane.TypeParameterId {
  self.define_type_parameter_with_kind(parameter.id, lower_kind(parameter.kind))
}

///|
fn BuslaneLowerer::define_type_parameter_with_kind(
  self : BuslaneLowerer,
  source : @symbol.TypeParameterId,
  kind : @buslane.Kind,
) -> @buslane.TypeParameterId {
  if self.registry.find_type_parameter(source) is Some(target) {
    return target
  }
  let target = self.metadata.define_type_parameter(kind)
  self.registry.register_type_parameter(source, target)
}

///|
fn BuslaneLowerer::type_id(
  self : BuslaneLowerer,
  source : @symbol.TypeSymbolId,
) -> @buslane.TypeId {
  self.registry.require_type(source)
}

///|
fn BuslaneLowerer::type_parameter_id(
  self : BuslaneLowerer,
  source : @symbol.TypeParameterId,
) -> @buslane.TypeParameterId {
  self.registry.require_type_parameter(source)
}

///|
fn BuslaneLowerer::value_id(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
) -> @buslane.ValueId {
  self.registry.require_value(source)
}

///|
fn BuslaneLowerer::data_constructor_id(
  self : BuslaneLowerer,
  source : @symbol.VariantSymbolId,
) -> @buslane.DataConId {
  self.registry.require_data_constructor(source)
}

///|
fn BuslaneLowerer::effect_id(
  self : BuslaneLowerer,
  source : @symbol.EffectSymbolId,
) -> @buslane.EffectId {
  self.registry.require_effect(source)
}

///|
fn BuslaneLowerer::operation_id(
  self : BuslaneLowerer,
  source : @symbol.OperationSymbolId,
) -> @buslane.OperationId {
  self.registry.require_operation(source)
}

///|
fn BuslaneLowerer::struct_constructor_id(
  self : BuslaneLowerer,
  source : @symbol.TypeSymbolId,
) -> @buslane.DataConId {
  self.registry.require_struct_constructor(source)
}

///|
fn BuslaneLowerer::field_selector_id(
  self : BuslaneLowerer,
  source : @symbol.FieldSymbolId,
) -> @buslane.ValueId {
  self.registry.require_field_selector(source)
}
