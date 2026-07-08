///|
pub fn write_type(writer : @bytecodec.ByteWriter, type_ : Type) -> Unit {
  writer.write_type(type_)
}

///|
pub fn read_type(
  reader : @bytecodec.ByteReader,
) -> Type raise BuslaneDecodeError {
  reader.read_type()
}

///|
pub fn write_value_id(writer : @bytecodec.ByteWriter, id : ValueId) -> Unit {
  writer.write_value_id(id)
}

///|
pub fn read_value_id(
  reader : @bytecodec.ByteReader,
) -> ValueId raise BuslaneDecodeError {
  reader.read_value_id()
}

///|
pub fn write_type_id(writer : @bytecodec.ByteWriter, id : TypeId) -> Unit {
  writer.write_type_id(id)
}

///|
pub fn read_type_id(
  reader : @bytecodec.ByteReader,
) -> TypeId raise BuslaneDecodeError {
  reader.read_type_id()
}

///|
pub fn write_data_con_id(
  writer : @bytecodec.ByteWriter,
  id : DataConId,
) -> Unit {
  writer.write_data_con_id(id)
}

///|
pub fn read_data_con_id(
  reader : @bytecodec.ByteReader,
) -> DataConId raise BuslaneDecodeError {
  reader.read_data_con_id()
}

///|
pub fn write_effect_id(writer : @bytecodec.ByteWriter, id : EffectId) -> Unit {
  writer.write_effect_id(id)
}

///|
pub fn read_effect_id(
  reader : @bytecodec.ByteReader,
) -> EffectId raise BuslaneDecodeError {
  reader.read_effect_id()
}

///|
pub fn write_operation_id(
  writer : @bytecodec.ByteWriter,
  id : OperationId,
) -> Unit {
  writer.write_operation_id(id)
}

///|
pub fn read_operation_id(
  reader : @bytecodec.ByteReader,
) -> OperationId raise BuslaneDecodeError {
  reader.read_operation_id()
}
