///|
fn @bytecodec.ByteWriter::write_buslane_program_section(
  self : @bytecodec.ByteWriter,
  program : @buslane.Program,
) -> Unit {
  self.write_bytes(@buslane_codec.encode_program(program))
}

///|
fn @bytecodec.ByteReader::read_buslane_program_section(
  self : @bytecodec.ByteReader,
) -> @buslane.Program raise {
  let bytes = self.read_bytes()
  @buslane_codec.decode_program(bytes) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteWriter::write_buslane_type(
  self : @bytecodec.ByteWriter,
  type_ : @buslane.Type,
) -> Unit {
  @buslane_codec.write_type(self, type_)
}

///|
fn @bytecodec.ByteReader::read_buslane_type(
  self : @bytecodec.ByteReader,
) -> @buslane.Type raise {
  @buslane_codec.read_type(self) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteWriter::write_buslane_value_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.ValueId,
) -> Unit {
  @buslane_codec.write_value_id(self, id)
}

///|
fn @bytecodec.ByteReader::read_buslane_value_id(
  self : @bytecodec.ByteReader,
) -> @buslane.ValueId raise {
  @buslane_codec.read_value_id(self) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteWriter::write_buslane_type_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.TypeId,
) -> Unit {
  @buslane_codec.write_type_id(self, id)
}

///|
fn @bytecodec.ByteReader::read_buslane_type_id(
  self : @bytecodec.ByteReader,
) -> @buslane.TypeId raise {
  @buslane_codec.read_type_id(self) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteWriter::write_buslane_data_con_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.DataConId,
) -> Unit {
  @buslane_codec.write_data_con_id(self, id)
}

///|
fn @bytecodec.ByteReader::read_buslane_data_con_id(
  self : @bytecodec.ByteReader,
) -> @buslane.DataConId raise {
  @buslane_codec.read_data_con_id(self) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteWriter::write_buslane_effect_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.EffectId,
) -> Unit {
  @buslane_codec.write_effect_id(self, id)
}

///|
fn @bytecodec.ByteReader::read_buslane_effect_id(
  self : @bytecodec.ByteReader,
) -> @buslane.EffectId raise {
  @buslane_codec.read_effect_id(self) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteWriter::write_buslane_operation_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.OperationId,
) -> Unit {
  @buslane_codec.write_operation_id(self, id)
}

///|
fn @bytecodec.ByteReader::read_buslane_operation_id(
  self : @bytecodec.ByteReader,
) -> @buslane.OperationId raise {
  @buslane_codec.read_operation_id(self) catch {
    error => raise BuslaneError(error)
  }
}
