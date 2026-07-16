///|
let buslane_codec_version = 2

///|
pub suberror BuslaneDecodeError {
  ByteError(@bytecodec.ByteDecodeError)
  UnsupportedCodecVersion(version~ : Int)
  InvalidTag(offset~ : Int, domain~ : String, tag~ : Int)
} derive(Debug, Eq)

///|
pub fn encode_program(program : Program) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(buslane_codec_version)
  writer.write_program(program)
  writer.to_bytes()
}

///|
pub fn decode_program(bytes : Bytes) -> Program raise BuslaneDecodeError {
  let reader = @bytecodec.ByteReader::from_bytes(bytes)
  let version = read_u32_le(reader)
  if version != buslane_codec_version {
    raise UnsupportedCodecVersion(version~)
  }
  let program = reader.read_program()
  expect_end(reader)
  program
}

///|
fn @bytecodec.ByteWriter::write_program(
  self : @bytecodec.ByteWriter,
  program : Program,
) -> Unit {
  self.write_metadata_registry(program.metadata)
  self.write_top_terms(program.terms)
}

///|
fn @bytecodec.ByteReader::read_program(
  self : @bytecodec.ByteReader,
) -> Program raise BuslaneDecodeError {
  { metadata: self.read_metadata_registry(), terms: self.read_top_terms() }
}

///|
fn @bytecodec.ByteWriter::write_metadata_registry(
  self : @bytecodec.ByteWriter,
  registry : MetadataRegistry,
) -> Unit {
  self.write_u32_le_int(registry.next_unique)
  self.write_type_infos(registry.types)
  self.write_type_parameter_infos(registry.type_parameters)
  self.write_value_infos(registry.values)
  self.write_data_con_infos(registry.data_constructors)
  self.write_effect_infos(registry.effects)
  self.write_operation_infos(registry.operations)
}

///|
fn @bytecodec.ByteReader::read_metadata_registry(
  self : @bytecodec.ByteReader,
) -> MetadataRegistry raise BuslaneDecodeError {
  {
    next_unique: read_u32_le(self),
    types: self.read_type_infos(),
    type_parameters: self.read_type_parameter_infos(),
    values: self.read_value_infos(),
    data_constructors: self.read_data_con_infos(),
    effects: self.read_effect_infos(),
    operations: self.read_operation_infos(),
  }
}

///|
fn @bytecodec.ByteWriter::write_type_infos(
  self : @bytecodec.ByteWriter,
  items : Array[TypeInfo],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_buslane_name(item.name)
    self.write_type_flavor(item.flavor)
    self.write_type_parameter_ids(item.parameters)
    self.write_data_con_ids(item.constructors)
  }
}

///|
fn @bytecodec.ByteReader::read_type_infos(
  self : @bytecodec.ByteReader,
) -> Array[TypeInfo] raise BuslaneDecodeError {
  let items : Array[TypeInfo] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      name: self.read_buslane_name(),
      flavor: self.read_type_flavor(),
      parameters: self.read_type_parameter_ids(),
      constructors: self.read_data_con_ids(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_type_parameter_infos(
  self : @bytecodec.ByteWriter,
  items : Array[TypeParameterInfo],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_buslane_name(item.name)
    self.write_kind(item.kind)
  }
}

///|
fn @bytecodec.ByteReader::read_type_parameter_infos(
  self : @bytecodec.ByteReader,
) -> Array[TypeParameterInfo] raise BuslaneDecodeError {
  let items : Array[TypeParameterInfo] = []
  for _ in 0..<read_u32_le(self) {
    items.push({ name: self.read_buslane_name(), kind: self.read_kind() })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_value_infos(
  self : @bytecodec.ByteWriter,
  items : Array[ValueInfo],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_buslane_name(item.name)
    self.write_value_kind(item.kind)
    self.write_type(item.type_)
  }
}

///|
fn @bytecodec.ByteReader::read_value_infos(
  self : @bytecodec.ByteReader,
) -> Array[ValueInfo] raise BuslaneDecodeError {
  let items : Array[ValueInfo] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      name: self.read_buslane_name(),
      kind: self.read_value_kind(),
      type_: self.read_type(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_data_con_infos(
  self : @bytecodec.ByteWriter,
  items : Array[DataConInfo],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_buslane_name(item.name)
    self.write_type_id(item.owner)
    self.write_type_parameter_ids(item.hidden_type_parameters)
    self.write_types(item.payload_types)
  }
}

///|
fn @bytecodec.ByteReader::read_data_con_infos(
  self : @bytecodec.ByteReader,
) -> Array[DataConInfo] raise BuslaneDecodeError {
  let items : Array[DataConInfo] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      name: self.read_buslane_name(),
      owner: self.read_type_id(),
      hidden_type_parameters: self.read_type_parameter_ids(),
      payload_types: self.read_types(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_effect_infos(
  self : @bytecodec.ByteWriter,
  items : Array[EffectInfo],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_buslane_name(item.name)
    self.write_effect_flavor(item.flavor)
    self.write_type_parameter_ids(item.parameters)
    self.write_operation_ids(item.operations)
  }
}

///|
fn @bytecodec.ByteReader::read_effect_infos(
  self : @bytecodec.ByteReader,
) -> Array[EffectInfo] raise BuslaneDecodeError {
  let items : Array[EffectInfo] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      name: self.read_buslane_name(),
      flavor: self.read_effect_flavor(),
      parameters: self.read_type_parameter_ids(),
      operations: self.read_operation_ids(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_type_flavor(
  self : @bytecodec.ByteWriter,
  flavor : TypeFlavor,
) -> Unit {
  self.write_u8(
    match flavor {
      Data => 0
      External => 1
    },
  )
}

///|
fn @bytecodec.ByteReader::read_type_flavor(
  self : @bytecodec.ByteReader,
) -> TypeFlavor raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Data
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      External
    }
    [u8be(tag), ..] =>
      invalid_tag(offset~, domain="TypeFlavor", tag=tag.reinterpret_as_int())
    [] => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_effect_flavor(
  self : @bytecodec.ByteWriter,
  flavor : EffectFlavor,
) -> Unit {
  self.write_u8(
    match flavor {
      Algebraic => 0
      External => 1
    },
  )
}

///|
fn @bytecodec.ByteReader::read_effect_flavor(
  self : @bytecodec.ByteReader,
) -> EffectFlavor raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Algebraic
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      External
    }
    [u8be(tag), ..] =>
      invalid_tag(offset~, domain="EffectFlavor", tag=tag.reinterpret_as_int())
    [] => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_operation_infos(
  self : @bytecodec.ByteWriter,
  items : Array[OperationInfo],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_buslane_name(item.name)
    self.write_effect_id(item.owner)
    self.write_type_parameter_ids(item.hidden_type_parameters)
    self.write_types(item.payload_types)
    self.write_type(item.result_type)
  }
}

///|
fn @bytecodec.ByteReader::read_operation_infos(
  self : @bytecodec.ByteReader,
) -> Array[OperationInfo] raise BuslaneDecodeError {
  let items : Array[OperationInfo] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      name: self.read_buslane_name(),
      owner: self.read_effect_id(),
      hidden_type_parameters: self.read_type_parameter_ids(),
      payload_types: self.read_types(),
      result_type: self.read_type(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_buslane_name(
  self : @bytecodec.ByteWriter,
  name : BuslaneName,
) -> Unit {
  self.write_name_namespace(name.name_space)
  self.write_string(name.occurrence)
  self.write_u32_le_int(name.unique.value)
}

///|
fn @bytecodec.ByteReader::read_buslane_name(
  self : @bytecodec.ByteReader,
) -> BuslaneName raise BuslaneDecodeError {
  {
    name_space: self.read_name_namespace(),
    occurrence: read_string(self),
    unique: { value: read_u32_le(self) },
  }
}

///|
fn @bytecodec.ByteWriter::write_type_id(
  self : @bytecodec.ByteWriter,
  id : TypeId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_id(
  self : @bytecodec.ByteReader,
) -> TypeId raise BuslaneDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_type_parameter_id(
  self : @bytecodec.ByteWriter,
  id : TypeParameterId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_type_parameter_id(
  self : @bytecodec.ByteReader,
) -> TypeParameterId raise BuslaneDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_value_id(
  self : @bytecodec.ByteWriter,
  id : ValueId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_value_id(
  self : @bytecodec.ByteReader,
) -> ValueId raise BuslaneDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_data_con_id(
  self : @bytecodec.ByteWriter,
  id : DataConId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_data_con_id(
  self : @bytecodec.ByteReader,
) -> DataConId raise BuslaneDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_effect_id(
  self : @bytecodec.ByteWriter,
  id : EffectId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_effect_id(
  self : @bytecodec.ByteReader,
) -> EffectId raise BuslaneDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_operation_id(
  self : @bytecodec.ByteWriter,
  id : OperationId,
) -> Unit {
  self.write_u32_le_int(id.index)
}

///|
fn @bytecodec.ByteReader::read_operation_id(
  self : @bytecodec.ByteReader,
) -> OperationId raise BuslaneDecodeError {
  { index: read_u32_le(self) }
}

///|
fn @bytecodec.ByteWriter::write_type_parameter_ids(
  self : @bytecodec.ByteWriter,
  items : Array[TypeParameterId],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_type_parameter_id(item)
  }
}

///|
fn @bytecodec.ByteReader::read_type_parameter_ids(
  self : @bytecodec.ByteReader,
) -> Array[TypeParameterId] raise BuslaneDecodeError {
  let items : Array[TypeParameterId] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_type_parameter_id())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_data_con_ids(
  self : @bytecodec.ByteWriter,
  items : Array[DataConId],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_data_con_id(item)
  }
}

///|
fn @bytecodec.ByteReader::read_data_con_ids(
  self : @bytecodec.ByteReader,
) -> Array[DataConId] raise BuslaneDecodeError {
  let items : Array[DataConId] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_data_con_id())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_operation_ids(
  self : @bytecodec.ByteWriter,
  items : Array[OperationId],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_operation_id(item)
  }
}

///|
fn @bytecodec.ByteReader::read_operation_ids(
  self : @bytecodec.ByteReader,
) -> Array[OperationId] raise BuslaneDecodeError {
  let items : Array[OperationId] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_operation_id())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_types(
  self : @bytecodec.ByteWriter,
  items : Array[Type],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_type(item)
  }
}

///|
fn @bytecodec.ByteReader::read_types(
  self : @bytecodec.ByteReader,
) -> Array[Type] raise BuslaneDecodeError {
  let items : Array[Type] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_type())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_generic_arguments(
  self : @bytecodec.ByteWriter,
  items : Array[GenericArgument],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_generic_argument(item)
  }
}

///|
fn @bytecodec.ByteReader::read_generic_arguments(
  self : @bytecodec.ByteReader,
) -> Array[GenericArgument] raise BuslaneDecodeError {
  let items : Array[GenericArgument] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_generic_argument())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_effects(
  self : @bytecodec.ByteWriter,
  items : Array[Effect],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_effect(item)
  }
}

///|
fn @bytecodec.ByteReader::read_effects(
  self : @bytecodec.ByteReader,
) -> Array[Effect] raise BuslaneDecodeError {
  let items : Array[Effect] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_effect())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_exprs(
  self : @bytecodec.ByteWriter,
  items : Array[Expr],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_expr(item)
  }
}

///|
fn @bytecodec.ByteReader::read_exprs(
  self : @bytecodec.ByteReader,
) -> Array[Expr] raise BuslaneDecodeError {
  let items : Array[Expr] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_expr())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_recursive_bindings(
  self : @bytecodec.ByteWriter,
  items : Array[RecursiveBinding],
) -> Unit {
  self.write_u32_le_int(items.length())
  for item in items {
    self.write_value_id(item.id)
    self.write_expr(item.rhs)
  }
}

///|
fn @bytecodec.ByteReader::read_recursive_bindings(
  self : @bytecodec.ByteReader,
) -> Array[RecursiveBinding] raise BuslaneDecodeError {
  let items : Array[RecursiveBinding] = []
  for _ in 0..<read_u32_le(self) {
    items.push({ id: self.read_value_id(), rhs: self.read_expr() })
  }
  items
}
