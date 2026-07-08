///|
fn @bytecodec.ByteWriter::write_name_namespace(
  self : @bytecodec.ByteWriter,
  value : NameNamespace,
) -> Unit {
  self.write_u8(
    match value {
      TypeName => 0
      TypeParameterName => 1
      ValueName => 2
      DataConstructorName => 3
      EffectName => 4
      OperationName => 5
    },
  )
}

///|
fn @bytecodec.ByteReader::read_name_namespace(
  self : @bytecodec.ByteReader,
) -> NameNamespace raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      TypeName
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      TypeParameterName
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      ValueName
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      DataConstructorName
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      EffectName
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      OperationName
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="NameNamespace", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_kind(
  self : @bytecodec.ByteWriter,
  value : Kind,
) -> Unit {
  match value {
    Type => self.write_u8(0)
    Effect => self.write_u8(1)
    Function(parameters, result) => {
      self.write_u8(2)
      self.write_kinds(parameters)
      self.write_kind(result)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_kind(
  self : @bytecodec.ByteReader,
) -> Kind raise BuslaneDecodeError {
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
      Function(self.read_kinds(), self.read_kind())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="Kind", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_kinds(
  self : @bytecodec.ByteWriter,
  items : Array[Kind],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_kind(item)
  }
}

///|
fn @bytecodec.ByteReader::read_kinds(
  self : @bytecodec.ByteReader,
) -> Array[Kind] raise BuslaneDecodeError {
  let items : Array[Kind] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_kind())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_primitive_type(
  self : @bytecodec.ByteWriter,
  value : PrimitiveType,
) -> Unit {
  self.write_u8(
    match value {
      Unit => 0
      Bool => 1
      Int => 2
      Double => 3
      String => 4
    },
  )
}

///|
fn @bytecodec.ByteReader::read_primitive_type(
  self : @bytecodec.ByteReader,
) -> PrimitiveType raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Unit
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Bool
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Int
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Double
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      String
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="PrimitiveType", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_type(
  self : @bytecodec.ByteWriter,
  value : Type,
) -> Unit {
  match value {
    Primitive(primitive) => {
      self.write_u8(0)
      self.write_primitive_type(primitive)
    }
    Parameter(id) => {
      self.write_u8(1)
      self.write_type_parameter_id(id)
    }
    Constructor(id) => {
      self.write_u8(2)
      self.write_type_id(id)
    }
    Apply(callee, arguments) => {
      self.write_u8(3)
      self.write_type(callee)
      self.write_generic_arguments(arguments)
    }
    TypeLambda(parameters, body) => {
      self.write_u8(4)
      self.write_type_parameter_ids(parameters)
      self.write_type(body)
    }
    Function(parameters, result, effect) => {
      self.write_u8(5)
      self.write_types(parameters)
      self.write_type(result)
      self.write_effect(effect)
    }
    Forall(parameters, body) => {
      self.write_u8(6)
      self.write_type_parameter_ids(parameters)
      self.write_type(body)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_type(
  self : @bytecodec.ByteReader,
) -> Type raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Primitive(self.read_primitive_type())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Parameter(self.read_type_parameter_id())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Constructor(self.read_type_id())
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Apply(self.read_type(), self.read_generic_arguments())
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      TypeLambda(self.read_type_parameter_ids(), self.read_type())
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      Function(self.read_types(), self.read_type(), self.read_effect())
    }
    [u8be(6), .. rest] => {
      self.update_view(rest)
      Forall(self.read_type_parameter_ids(), self.read_type())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="Type", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_effect(
  self : @bytecodec.ByteWriter,
  value : Effect,
) -> Unit {
  match value {
    Empty => self.write_u8(0)
    Singleton(id, arguments) => {
      self.write_u8(1)
      self.write_effect_id(id)
      self.write_generic_arguments(arguments)
    }
    Parameter(id) => {
      self.write_u8(2)
      self.write_type_parameter_id(id)
    }
    Union(effects) => {
      self.write_u8(3)
      self.write_effects(effects)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_effect(
  self : @bytecodec.ByteReader,
) -> Effect raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Empty
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Singleton(self.read_effect_id(), self.read_generic_arguments())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Parameter(self.read_type_parameter_id())
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Union(self.read_effects())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="Effect", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_generic_argument(
  self : @bytecodec.ByteWriter,
  value : GenericArgument,
) -> Unit {
  match value {
    TypeArgument(type_) => {
      self.write_u8(0)
      self.write_type(type_)
    }
    EffectArgument(effect) => {
      self.write_u8(1)
      self.write_effect(effect)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_generic_argument(
  self : @bytecodec.ByteReader,
) -> GenericArgument raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      TypeArgument(self.read_type())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      EffectArgument(self.read_effect())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(
        offset~,
        domain="GenericArgument",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_value_kind(
  self : @bytecodec.ByteWriter,
  value : ValueKind,
) -> Unit {
  self.write_u8(
    match value {
      Function => 0
      Value => 1
      External => 2
      Parameter => 3
      Local => 4
      MatchBinder => 5
    },
  )
}

///|
fn @bytecodec.ByteReader::read_value_kind(
  self : @bytecodec.ByteReader,
) -> ValueKind raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Function
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Value
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      External
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Parameter
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      Local
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      MatchBinder
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="ValueKind", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}
