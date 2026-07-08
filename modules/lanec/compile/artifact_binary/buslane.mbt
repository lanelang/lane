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
fn @bytecodec.ByteReader::read_buslane_type(
  self : @bytecodec.ByteReader,
) -> @buslane.Type raise {
  @buslane_codec.read_type(self) catch {
    error => raise BuslaneError(error)
  }
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
fn @bytecodec.ByteReader::read_buslane_type_id(
  self : @bytecodec.ByteReader,
) -> @buslane.TypeId raise {
  @buslane_codec.read_type_id(self) catch {
    error => raise BuslaneError(error)
  }
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
fn @bytecodec.ByteReader::read_buslane_effect_id(
  self : @bytecodec.ByteReader,
) -> @buslane.EffectId raise {
  @buslane_codec.read_effect_id(self) catch {
    error => raise BuslaneError(error)
  }
}

///|
fn @bytecodec.ByteReader::read_buslane_operation_id(
  self : @bytecodec.ByteReader,
) -> @buslane.OperationId raise {
  @buslane_codec.read_operation_id(self) catch {
    error => raise BuslaneError(error)
  }
}
