///|
fn @bytecodec.ByteWriter::write_module_interface(
  self : @bytecodec.ByteWriter,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  self.write_string(interface.module_path)
  self.write_module_interface_types(interface.types)
  self.write_module_interface_effects(interface.effects)
  self.write_module_interface_type_aliases(interface.type_aliases)
  self.write_module_interface_values(interface.values)
  self.write_optimization_hints(interface.optimization_hints)
}

///|
fn @bytecodec.ByteReader::read_module_interface(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterface raise ArtifactBinaryDecodeError {
  {
    module_path: read_string(self),
    source_id: None,
    types: self.read_module_interface_types(),
    effects: self.read_module_interface_effects(),
    type_aliases: self.read_module_interface_type_aliases(),
    values: self.read_module_interface_values(),
    optimization_hints: self.read_optimization_hints(),
  }
}

///|
fn @bytecodec.ByteWriter::write_module_interface_types(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceType],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_module_interface_type(item)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_types(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceType] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceType] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_module_interface_type())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_type(
  self : @bytecodec.ByteWriter,
  item : @module_interface.ModuleInterfaceType,
) -> Unit {
  match item {
    Struct(declaration) => {
      self.write_u8(0)
      self.write_type_symbol_id(declaration.symbol)
      self.write_string(declaration.name)
      self.write_type_parameters(declaration.type_parameters)
      self.write_type_members(declaration.type_members)
      self.write_fields(declaration.fields)
      self.write_source_span(declaration.loc)
    }
    Enum(declaration) => {
      self.write_u8(1)
      self.write_type_symbol_id(declaration.symbol)
      self.write_string(declaration.name)
      self.write_type_parameters(declaration.type_parameters)
      self.write_variants(declaration.variants)
      self.write_source_span(declaration.loc)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_type(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterfaceType raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 =>
      Struct({
        symbol: self.read_type_symbol_id(),
        name: read_string(self),
        type_parameters: self.read_type_parameters(),
        type_members: self.read_type_members(),
        fields: self.read_fields(),
        loc: self.read_source_span(),
      })
    1 =>
      Enum({
        symbol: self.read_type_symbol_id(),
        name: read_string(self),
        type_parameters: self.read_type_parameters(),
        variants: self.read_variants(),
        loc: self.read_source_span(),
      })
    tag => invalid_binary_tag(offset~, domain="ModuleInterfaceType", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_type_members(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceTypeMember],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_type_member_symbol_id(item.symbol)
    self.write_type_parameter(item.type_parameter)
    self.write_string(item.name)
    self.write_lane_kind(item.kind)
    self.write_u32_le(item.index)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_type_members(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceTypeMember] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceTypeMember] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_type_member_symbol_id(),
      type_parameter: self.read_type_parameter(),
      name: read_string(self),
      kind: self.read_lane_kind(),
      index: read_u32_le(self),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_fields(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceField],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_field_symbol_id(item.symbol)
    self.write_bool(item.is_offered)
    self.write_string(item.name)
    self.write_u32_le(item.index)
    self.write_lane_type(item.type_)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_fields(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceField] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceField] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_field_symbol_id(),
      is_offered: read_bool(self),
      name: read_string(self),
      index: read_u32_le(self),
      type_: self.read_lane_type(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_variants(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceVariant],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_variant_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_u32_le(item.index)
    self.write_type_parameters(item.type_parameters)
    self.write_lane_types(item.payload)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_variants(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceVariant] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceVariant] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_variant_symbol_id(),
      name: read_string(self),
      index: read_u32_le(self),
      type_parameters: self.read_type_parameters(),
      payload: self.read_lane_types(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_effects(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceEffect],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_effect_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_type_parameters(item.type_parameters)
    self.write_module_interface_operations(item.operations)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_effects(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceEffect] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceEffect] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_effect_symbol_id(),
      name: read_string(self),
      type_parameters: self.read_type_parameters(),
      operations: self.read_module_interface_operations(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_operations(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceOperation],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_operation_symbol_id(item.symbol)
    self.write_string(item.name)
    self.write_u32_le(item.index)
    self.write_type_parameters(item.type_parameters)
    self.write_lane_types(item.payload)
    self.write_lane_type(item.result)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_operations(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceOperation] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceOperation] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_operation_symbol_id(),
      name: read_string(self),
      index: read_u32_le(self),
      type_parameters: self.read_type_parameters(),
      payload: self.read_lane_types(),
      result: self.read_lane_type(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_type_aliases(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceTypeAlias],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_string(item.name)
    self.write_type_parameters(item.type_parameters)
    self.write_type_alias_body(item.body)
    self.write_lane_kind(item.kind)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_type_aliases(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceTypeAlias] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceTypeAlias] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      name: read_string(self),
      type_parameters: self.read_type_parameters(),
      body: self.read_type_alias_body(),
      kind: self.read_lane_kind(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_type_alias_body(
  self : @bytecodec.ByteWriter,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> Unit {
  match body {
    TypeBody(type_) => {
      self.write_u8(0)
      self.write_lane_type(type_)
    }
    EffectBody(effect) => {
      self.write_u8(1)
      self.write_lane_effect(effect)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_type_alias_body(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterfaceTypeAliasBody raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => TypeBody(self.read_lane_type())
    1 => EffectBody(self.read_lane_effect())
    tag =>
      invalid_binary_tag(offset~, domain="ModuleInterfaceTypeAliasBody", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_module_interface_values(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceValue],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_value_symbol_id(item.symbol)
    self.write_module_interface_value_kind(item.kind)
    self.write_string(item.name)
    self.write_lane_type(item.type_)
    self.write_optional_value_parameters(item.parameters)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_module_interface_values(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceValue] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceValue] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_value_symbol_id(),
      kind: self.read_module_interface_value_kind(),
      name: read_string(self),
      type_: self.read_lane_type(),
      parameters: self.read_optional_value_parameters(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_module_interface_value_kind(
  self : @bytecodec.ByteWriter,
  kind : @module_interface.ModuleInterfaceValueKind,
) -> Unit {
  self.write_u8(
    match kind {
      Function => 0
      Let => 1
      Offer => 2
    },
  )
}

///|
fn @bytecodec.ByteReader::read_module_interface_value_kind(
  self : @bytecodec.ByteReader,
) -> @module_interface.ModuleInterfaceValueKind raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => Function
    1 => Let
    2 => Offer
    tag => invalid_binary_tag(offset~, domain="ModuleInterfaceValueKind", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_optional_value_parameters(
  self : @bytecodec.ByteWriter,
  parameters : Array[@module_interface.ModuleInterfaceValueParameter]?,
) -> Unit {
  match parameters {
    None => self.write_bool(false)
    Some(parameters) => {
      self.write_bool(true)
      self.write_value_parameters(parameters)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_optional_value_parameters(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceValueParameter]? raise ArtifactBinaryDecodeError {
  if read_bool(self) {
    Some(self.read_value_parameters())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteWriter::write_value_parameters(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.ModuleInterfaceValueParameter],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_value_symbol_id(item.symbol)
    self.write_bool(item.is_auto)
    self.write_bool(item.is_offered)
    self.write_string(item.name)
    self.write_lane_type(item.type_)
    self.write_source_span(item.loc)
  }
}

///|
fn @bytecodec.ByteReader::read_value_parameters(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.ModuleInterfaceValueParameter] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.ModuleInterfaceValueParameter] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      symbol: self.read_value_symbol_id(),
      is_auto: read_bool(self),
      is_offered: read_bool(self),
      name: read_string(self),
      type_: self.read_lane_type(),
      loc: self.read_source_span(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_optimization_hints(
  self : @bytecodec.ByteWriter,
  items : Array[@module_interface.OptimizationHint],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_string(item.name)
  }
}

///|
fn @bytecodec.ByteReader::read_optimization_hints(
  self : @bytecodec.ByteReader,
) -> Array[@module_interface.OptimizationHint] raise ArtifactBinaryDecodeError {
  let items : Array[@module_interface.OptimizationHint] = []
  for _ in 0..<read_u32_le(self) {
    items.push({ name: read_string(self) })
  }
  items
}
