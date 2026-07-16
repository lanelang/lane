///|
fn @bytecodec.ByteWriter::write_type_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.TypeSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.TypeSymbolId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_type_parameter_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.TypeParameterId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_parameter_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.TypeParameterId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_type_member_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.TypeMemberSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_member_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.TypeMemberSymbolId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_value_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.ValueSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_value_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.ValueSymbolId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_field_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.FieldSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_field_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.FieldSymbolId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_variant_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.VariantSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_variant_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.VariantSymbolId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_effect_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.EffectSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_effect_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.EffectSymbolId raise {
  { index: self.read_u32_le_int() }
}

///|
fn @bytecodec.ByteWriter::write_operation_symbol_id(
  self : @bytecodec.ByteWriter,
  id : @symbol.OperationSymbolId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_operation_symbol_id(
  self : @bytecodec.ByteReader,
) -> @symbol.OperationSymbolId raise {
  { index: self.read_u32_le_int() }
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
) -> @types.PrimitiveType raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Int
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Double
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Bool
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      String
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      Unit
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="LanePrimitiveType",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
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
) -> @types.Kind raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Type
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Effect
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Function(self.read_lane_kinds(), self.read_lane_kind())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="LaneKind",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_kinds(
  self : @bytecodec.ByteWriter,
  items : Array[@types.Kind],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_lane_kind(item)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_kinds(
  self : @bytecodec.ByteReader,
) -> Array[@types.Kind] raise {
  let items : Array[@types.Kind] = []
  for _ in 0..<self.read_u32_le_int() {
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
) -> @types.TypeParameter raise {
  {
    id: self.read_type_parameter_symbol_id(),
    name: self.read_string(),
    kind: self.read_lane_kind(),
  }
}

///|
fn @bytecodec.ByteWriter::write_type_parameters(
  self : @bytecodec.ByteWriter,
  parameters : Array[@types.TypeParameter],
) -> Unit {
  self.write_u32_le_int(parameters.length())
  for parameter in parameters {
    self.write_type_parameter(parameter)
  }
}

///|
fn @bytecodec.ByteReader::read_type_parameters(
  self : @bytecodec.ByteReader,
) -> Array[@types.TypeParameter] raise {
  let parameters : Array[@types.TypeParameter] = []
  for _ in 0..<self.read_u32_le_int() {
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
) -> @types.Type raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Error
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Primitive(self.read_lane_primitive_type())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Constructor(self.read_type_symbol_id())
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Apply(self.read_lane_type(), self.read_lane_generic_arguments())
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      TypeLambda(self.read_type_parameters(), self.read_lane_type())
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      Parameter(self.read_type_parameter_symbol_id())
    }
    [u8be(6), .. rest] => {
      self.update_view(rest)
      Function(
        self.read_lane_types(),
        self.read_lane_type(),
        self.read_lane_effect(),
      )
    }
    [u8be(7), .. rest] => {
      self.update_view(rest)
      Forall(self.read_type_parameters(), self.read_lane_type())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="LaneType",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_types(
  self : @bytecodec.ByteWriter,
  types : Array[@types.Type],
) -> Unit {
  self.write_u32_le_int(types.length())
  for type_ in types {
    self.write_lane_type(type_)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_types(
  self : @bytecodec.ByteReader,
) -> Array[@types.Type] raise {
  let types : Array[@types.Type] = []
  for _ in 0..<self.read_u32_le_int() {
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
    Io => self.write_u8(4)
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
) -> @types.Effect raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Empty
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Singleton(
        self.read_effect_symbol_id(),
        self.read_lane_generic_arguments(),
      )
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Parameter(self.read_type_parameter_symbol_id())
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Union(self.read_lane_effects())
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      Io
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="LaneEffect",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_effects(
  self : @bytecodec.ByteWriter,
  effects : Array[@types.Effect],
) -> Unit {
  self.write_u32_le_int(effects.length())
  for effect in effects {
    self.write_lane_effect(effect)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_effects(
  self : @bytecodec.ByteReader,
) -> Array[@types.Effect] raise {
  let effects : Array[@types.Effect] = []
  for _ in 0..<self.read_u32_le_int() {
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
) -> @types.GenericArgument raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      TypeArgument(self.read_lane_type())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      EffectArgument(self.read_lane_effect())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="LaneGenericArgument",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteWriter::write_lane_generic_arguments(
  self : @bytecodec.ByteWriter,
  arguments : Array[@types.GenericArgument],
) -> Unit {
  self.write_u32_le_int(arguments.length())
  for argument in arguments {
    self.write_lane_generic_argument(argument)
  }
}

///|
fn @bytecodec.ByteReader::read_lane_generic_arguments(
  self : @bytecodec.ByteReader,
) -> Array[@types.GenericArgument] raise {
  let arguments : Array[@types.GenericArgument] = []
  for _ in 0..<self.read_u32_le_int() {
    arguments.push(self.read_lane_generic_argument())
  }
  arguments
}
