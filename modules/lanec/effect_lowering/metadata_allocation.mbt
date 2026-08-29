///|
fn @buslane.MetadataRegistry::define_cps_value(
  self : @buslane.MetadataRegistry,
  occurrence : String,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId raise SynthesisError {
  self.define_value(occurrence, kind, type_) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
}

///|
fn @buslane.MetadataRegistry::define_cps_type_parameter(
  self : @buslane.MetadataRegistry,
  occurrence : String,
  kind : @buslane.Kind,
  flavor? : @buslane.EffectFlavor = Algebraic,
) -> @buslane.TypeParameterId raise SynthesisError {
  self.define_type_parameter(occurrence, kind, flavor~) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
}

///|
fn @buslane.MetadataRegistry::define_cps_type(
  self : @buslane.MetadataRegistry,
  occurrence : String,
  parameters : Array[@buslane.TypeParameterId],
  flavor? : @buslane.TypeFlavor = Data,
) -> @buslane.TypeId raise SynthesisError {
  self.define_type(occurrence, parameters, flavor~) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
}

///|
fn @buslane.MetadataRegistry::define_cps_data_constructor(
  self : @buslane.MetadataRegistry,
  occurrence : String,
  owner : @buslane.TypeId,
  hidden_type_parameters : Array[@buslane.TypeParameterId],
  payload_types : Array[@buslane.Type],
) -> @buslane.DataConId raise SynthesisError {
  self.define_data_constructor(
    occurrence, owner, hidden_type_parameters, payload_types,
  ) catch {
    error => raise MetadataAllocationCompilerDefect(error)
  }
}
