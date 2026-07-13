///|
fn @bytecodec.ByteReader::read_externals(
  self : @bytecodec.ByteReader,
) -> @buslane_lowering.BuslaneExternalMap raise {
  let builtins : Array[@buslane_lowering.BuslaneBuiltinExternal] = []
  for _ in 0..<self.read_u32_le() {
    builtins.push({
      value: self.read_buslane_value_id(),
      name: self.read_string(),
      type_: self.read_buslane_type(),
    })
  }
  { builtins, }
}

///|
fn @bytecodec.ByteReader::read_entries(
  self : @bytecodec.ByteReader,
) -> Array[@buslane_lowering.BuslaneEntry] raise {
  let entries : Array[@buslane_lowering.BuslaneEntry] = []
  for _ in 0..<self.read_u32_le() {
    entries.push(self.read_entry())
  }
  entries
}

///|
fn @bytecodec.ByteReader::read_entry(
  self : @bytecodec.ByteReader,
) -> @buslane_lowering.BuslaneEntry raise {
  {
    module_path_text: self.read_string(),
    name: self.read_string(),
    value: self.read_buslane_value_id(),
    type_: self.read_buslane_type(),
  }
}

///|
fn @bytecodec.ByteReader::read_export_kind(
  self : @bytecodec.ByteReader,
) -> @buslane_lowering.BuslaneModuleExportKind raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Type
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      DataConstructor
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Effect
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Operation
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      FieldSelector
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      Value
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="BuslaneModuleExportKind",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteReader::read_optional_type_id(
  self : @bytecodec.ByteReader,
) -> @buslane.TypeId? raise {
  if self.read_bool() {
    Some(self.read_buslane_type_id())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteReader::read_optional_data_con_id(
  self : @bytecodec.ByteReader,
) -> @buslane.DataConId? raise {
  if self.read_bool() {
    Some(self.read_buslane_data_con_id())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteReader::read_optional_effect_id(
  self : @bytecodec.ByteReader,
) -> @buslane.EffectId? raise {
  if self.read_bool() {
    Some(self.read_buslane_effect_id())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteReader::read_optional_operation_id(
  self : @bytecodec.ByteReader,
) -> @buslane.OperationId? raise {
  if self.read_bool() {
    Some(self.read_buslane_operation_id())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteReader::read_optional_value_id(
  self : @bytecodec.ByteReader,
) -> @buslane.ValueId? raise {
  if self.read_bool() {
    Some(self.read_buslane_value_id())
  } else {
    None
  }
}

///|
fn @bytecodec.ByteReader::read_exports(
  self : @bytecodec.ByteReader,
) -> Array[@buslane_lowering.BuslaneModuleExport] raise {
  let exports : Array[@buslane_lowering.BuslaneModuleExport] = []
  for _ in 0..<self.read_u32_le() {
    exports.push({
      kind: self.read_export_kind(),
      name: self.read_string(),
      type_id: self.read_optional_type_id(),
      data_constructor: self.read_optional_data_con_id(),
      effect_id: self.read_optional_effect_id(),
      operation: self.read_optional_operation_id(),
      value: self.read_optional_value_id(),
    })
  }
  exports
}

///|
fn @bytecodec.ByteReader::read_imports(
  self : @bytecodec.ByteReader,
) -> Array[@artifact_core.ModuleImportedReference] raise {
  let imports : Array[@artifact_core.ModuleImportedReference] = []
  for _ in 0..<self.read_u32_le() {
    imports.push({
      module_path_text: self.read_string(),
      kind: self.read_export_kind(),
      name: self.read_string(),
      fingerprint: self.read_compilation_fingerprint(),
      type_id: self.read_optional_type_id(),
      data_constructor: self.read_optional_data_con_id(),
      effect_id: self.read_optional_effect_id(),
      operation: self.read_optional_operation_id(),
      value: self.read_optional_value_id(),
    })
  }
  imports
}

///|
fn @bytecodec.ByteWriter::write_runtime_effect_operation_signatures(
  self : @bytecodec.ByteWriter,
  operations : Array[@module_compile.RuntimeEffectOperationSignature],
) -> Unit {
  self.write_u32_le(operations.length())
  for operation in operations {
    self.write_string(operation.module_path_text)
    self.write_string(operation.effect_name)
    self.write_string(operation.operation_name)
    self.write_lane_types(operation.payload)
    self.write_lane_type(operation.result)
  }
}

///|
fn @bytecodec.ByteReader::read_runtime_effect_operation_signatures(
  self : @bytecodec.ByteReader,
) -> Array[@module_compile.RuntimeEffectOperationSignature] raise {
  let operations : Array[@module_compile.RuntimeEffectOperationSignature] = []
  for _ in 0..<self.read_u32_le() {
    operations.push({
      module_path_text: self.read_string(),
      effect_name: self.read_string(),
      operation_name: self.read_string(),
      payload: self.read_lane_types(),
      result: self.read_lane_type(),
    })
  }
  operations
}
