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
fn @bytecodec.ByteReader::read_canonical_basic_abi_runtime_contract(
  self : @bytecodec.ByteReader,
) -> @canonical_basic_abi.CanonicalBasicAbiRuntimeContract raise {
  match self.read_u8() {
    0 => @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::empty()
    1 =>
      @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::from_void_type(
        Some(self.read_buslane_type_id()),
      )
    tag =>
      invalid_binary_tag(
        offset=self.offset() - 1,
        domain="canonical Basic ABI runtime contract",
        tag~,
      )
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
