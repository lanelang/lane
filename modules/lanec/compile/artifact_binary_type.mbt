///|
fn @bytecodec.ByteWriter::write_type_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.TypeSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.TypeSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_type_parameter_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.TypeParameterId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_parameter_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.TypeParameterId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_type_member_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.TypeMemberSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_member_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.TypeMemberSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_value_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.ValueSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_value_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.ValueSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_field_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.FieldSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_field_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.FieldSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_variant_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.VariantSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_variant_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.VariantSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_effect_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.EffectSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_effect_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.EffectSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_operation_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.OperationSymbolId,
) -> Unit {
  self.write_u32_le(id.index)
}

///|
fn @bytecodec.ByteReader::read_operation_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.OperationSymbolId raise ArtifactBinaryDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_lane_primitive_type(
  self : @bytecodec.ByteWriter,
  primitive : @types.PrimitiveType,
) -> Unit {
  self.write_u8(
    match primitive {
      Int => 0
      Double => 1
      Bool => 2
      String => 3
      Unit => 4
    },
  )
}

///|
fn @bytecodec.ByteReader::read_lane_primitive_type(
  self : @bytecodec.ByteReader,
) -> @types.PrimitiveType raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => Int
    1 => Double
    2 => Bool
    3 => String
    4 => Unit
    tag => invalid_binary_tag(offset~, domain="LanePrimitiveType", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_kind(
  self : @bytecodec.ByteWriter,
  kind : @types.Kind,
) -> Unit {
  match kind {
    Type => self.write_u8(0)
    Effect => self.write_u8(1)
    Function(parameters, result) => {
      self.write_u8(2)
      self.write_lane_kinds(parameters)
      self.write_lane_kind(result)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_lane_kind(
  self : @bytecodec.ByteReader,
) -> @types.Kind raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => Type
    1 => Effect
    2 => Function(self.read_lane_kinds(), self.read_lane_kind())
    tag => invalid_binary_tag(offset~, domain="LaneKind", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_kinds(
  self : @bytecodec.ByteWriter,
  items : Array[@types.Kind],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_lane_kind(item)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_kinds(
  self : @bytecodec.ByteReader,
) -> Array[@types.Kind] raise ArtifactBinaryDecodeError {
  let items : Array[@types.Kind] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_lane_kind())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_type_parameter(
  self : @bytecodec.ByteWriter,
  parameter : @types.TypeParameter,
) -> Unit {
  self.write_type_parameter_symbol_id(parameter.id)
  self.write_string(parameter.name)
  self.write_lane_kind(parameter.kind)
}

///|
fn @bytecodec.ByteReader::read_type_parameter(
  self : @bytecodec.ByteReader,
) -> @types.TypeParameter raise ArtifactBinaryDecodeError {
  {
    id: self.read_type_parameter_symbol_id(),
    name: read_string(self),
    kind: self.read_lane_kind(),
  }
}

///|
fn @bytecodec.ByteWriter::write_type_parameters(
  self : @bytecodec.ByteWriter,
  parameters : Array[@types.TypeParameter],
) -> Unit {
  self.write_u32_le(parameters.length())
  for parameter in parameters {
    self.write_type_parameter(parameter)
  }
}

///|
fn @bytecodec.ByteReader::read_type_parameters(
  self : @bytecodec.ByteReader,
) -> Array[@types.TypeParameter] raise ArtifactBinaryDecodeError {
  let parameters : Array[@types.TypeParameter] = []
  for _ in 0..<read_u32_le(self) {
    parameters.push(self.read_type_parameter())
  }
  parameters
}

///|
fn @bytecodec.ByteWriter::write_lane_type(
  self : @bytecodec.ByteWriter,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Error => self.write_u8(0)
    Primitive(primitive) => {
      self.write_u8(1)
      self.write_lane_primitive_type(primitive)
    }
    Constructor(id) => {
      self.write_u8(2)
      self.write_type_symbol_id(id)
    }
    Apply(callee, arguments) => {
      self.write_u8(3)
      self.write_lane_type(callee)
      self.write_lane_generic_arguments(arguments)
    }
    TypeLambda(parameters, body) => {
      self.write_u8(4)
      self.write_type_parameters(parameters)
      self.write_lane_type(body)
    }
    Parameter(id) => {
      self.write_u8(5)
      self.write_type_parameter_symbol_id(id)
    }
    Function(parameters, result, effect) => {
      self.write_u8(6)
      self.write_lane_types(parameters)
      self.write_lane_type(result)
      self.write_lane_effect(effect)
    }
    Forall(parameters, body) => {
      self.write_u8(7)
      self.write_type_parameters(parameters)
      self.write_lane_type(body)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_lane_type(
  self : @bytecodec.ByteReader,
) -> @types.Type raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => Error
    1 => Primitive(self.read_lane_primitive_type())
    2 => Constructor(self.read_type_symbol_id())
    3 => Apply(self.read_lane_type(), self.read_lane_generic_arguments())
    4 => TypeLambda(self.read_type_parameters(), self.read_lane_type())
    5 => Parameter(self.read_type_parameter_symbol_id())
    6 =>
      Function(
        self.read_lane_types(),
        self.read_lane_type(),
        self.read_lane_effect(),
      )
    7 => Forall(self.read_type_parameters(), self.read_lane_type())
    tag => invalid_binary_tag(offset~, domain="LaneType", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_types(
  self : @bytecodec.ByteWriter,
  types : Array[@types.Type],
) -> Unit {
  self.write_u32_le(types.length())
  for type_ in types {
    self.write_lane_type(type_)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_types(
  self : @bytecodec.ByteReader,
) -> Array[@types.Type] raise ArtifactBinaryDecodeError {
  let types : Array[@types.Type] = []
  for _ in 0..<read_u32_le(self) {
    types.push(self.read_lane_type())
  }
  types
}

///|
fn @bytecodec.ByteWriter::write_lane_effect(
  self : @bytecodec.ByteWriter,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty => self.write_u8(0)
    Singleton(id, arguments) => {
      self.write_u8(1)
      self.write_effect_symbol_id(id)
      self.write_lane_generic_arguments(arguments)
    }
    Parameter(id) => {
      self.write_u8(2)
      self.write_type_parameter_symbol_id(id)
    }
    Union(effects) => {
      self.write_u8(3)
      self.write_lane_effects(effects)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_lane_effect(
  self : @bytecodec.ByteReader,
) -> @types.Effect raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => Empty
    1 =>
      Singleton(
        self.read_effect_symbol_id(),
        self.read_lane_generic_arguments(),
      )
    2 => Parameter(self.read_type_parameter_symbol_id())
    3 => Union(self.read_lane_effects())
    tag => invalid_binary_tag(offset~, domain="LaneEffect", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_effects(
  self : @bytecodec.ByteWriter,
  effects : Array[@types.Effect],
) -> Unit {
  self.write_u32_le(effects.length())
  for effect in effects {
    self.write_lane_effect(effect)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_effects(
  self : @bytecodec.ByteReader,
) -> Array[@types.Effect] raise ArtifactBinaryDecodeError {
  let effects : Array[@types.Effect] = []
  for _ in 0..<read_u32_le(self) {
    effects.push(self.read_lane_effect())
  }
  effects
}

///|
fn @bytecodec.ByteWriter::write_lane_generic_argument(
  self : @bytecodec.ByteWriter,
  argument : @types.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => {
      self.write_u8(0)
      self.write_lane_type(type_)
    }
    EffectArgument(effect) => {
      self.write_u8(1)
      self.write_lane_effect(effect)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_lane_generic_argument(
  self : @bytecodec.ByteReader,
) -> @types.GenericArgument raise ArtifactBinaryDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => TypeArgument(self.read_lane_type())
    1 => EffectArgument(self.read_lane_effect())
    tag => invalid_binary_tag(offset~, domain="LaneGenericArgument", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_generic_arguments(
  self : @bytecodec.ByteWriter,
  arguments : Array[@types.GenericArgument],
) -> Unit {
  self.write_u32_le(arguments.length())
  for argument in arguments {
    self.write_lane_generic_argument(argument)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_generic_arguments(
  self : @bytecodec.ByteReader,
) -> Array[@types.GenericArgument] raise ArtifactBinaryDecodeError {
  let arguments : Array[@types.GenericArgument] = []
  for _ in 0..<read_u32_le(self) {
    arguments.push(self.read_lane_generic_argument())
  }
  arguments
}
