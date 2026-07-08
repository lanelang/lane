///|
fn @bytecodec.ByteWriter::write_value_ids(
  self : @bytecodec.ByteWriter,
  items : Array[ValueId],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_value_id(item)
  }
}

///|
fn @bytecodec.ByteReader::read_value_ids(
  self : @bytecodec.ByteReader,
) -> Array[ValueId] raise BuslaneDecodeError {
  let items : Array[ValueId] = []
  for _ in 0..<read_u32_le(self) {
    items.push(self.read_value_id())
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_alternatives(
  self : @bytecodec.ByteWriter,
  items : Array[Alternative],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_alt_con(item.alt_constructor)
    self.write_type_parameter_ids(item.type_binders)
    self.write_value_ids(item.value_binders)
    self.write_expr(item.body)
  }
}

///|
fn @bytecodec.ByteReader::read_alternatives(
  self : @bytecodec.ByteReader,
) -> Array[Alternative] raise BuslaneDecodeError {
  let items : Array[Alternative] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      alt_constructor: self.read_alt_con(),
      type_binders: self.read_type_parameter_ids(),
      value_binders: self.read_value_ids(),
      body: self.read_expr(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_alt_con(
  self : @bytecodec.ByteWriter,
  value : AltCon,
) -> Unit {
  match value {
    Default => self.write_u8(0)
    Literal(literal) => {
      self.write_u8(1)
      self.write_literal(literal)
    }
    DataCon(id) => {
      self.write_u8(2)
      self.write_data_con_id(id)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_alt_con(
  self : @bytecodec.ByteReader,
) -> AltCon raise BuslaneDecodeError {
  let offset = self.offset()
  match read_u8(self) {
    0 => Default
    1 => Literal(self.read_literal())
    2 => DataCon(self.read_data_con_id())
    tag => invalid_tag(offset~, domain="AltCon", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_handler_tables(
  self : @bytecodec.ByteWriter,
  items : Array[HandlerTable],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_effect(item.handled_effect)
    self.write_operation_alternatives(item.operations)
  }
}

///|
fn @bytecodec.ByteReader::read_handler_tables(
  self : @bytecodec.ByteReader,
) -> Array[HandlerTable] raise BuslaneDecodeError {
  let items : Array[HandlerTable] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      handled_effect: self.read_effect(),
      operations: self.read_operation_alternatives(),
    })
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_operation_alternatives(
  self : @bytecodec.ByteWriter,
  items : Array[OperationAlternative],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_operation_id(item.operation)
    self.write_type_parameter_ids(item.type_binders)
    self.write_value_ids(item.payload_binders)
    self.write_value_id(item.resume_binder)
    self.write_expr(item.body)
  }
}

///|
fn @bytecodec.ByteReader::read_operation_alternatives(
  self : @bytecodec.ByteReader,
) -> Array[OperationAlternative] raise BuslaneDecodeError {
  let items : Array[OperationAlternative] = []
  for _ in 0..<read_u32_le(self) {
    items.push({
      operation: self.read_operation_id(),
      type_binders: self.read_type_parameter_ids(),
      payload_binders: self.read_value_ids(),
      resume_binder: self.read_value_id(),
      body: self.read_expr(),
    })
  }
  items
}
