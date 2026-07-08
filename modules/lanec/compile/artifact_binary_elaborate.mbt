///|
fn @bytecodec.ByteWriter::write_externals(
  self : @bytecodec.ByteWriter,
  externals : @elaborate.BuslaneExternalMap,
) -> Unit {
  self.write_u32_le(externals.builtins.length())
  for external in externals.builtins {
    self.write_buslane_value_id(external.value)
    self.write_string(external.name)
    self.write_buslane_type(external.type_)
  }
}

///|
fn @bytecodec.ByteReader::read_externals(
  self : @bytecodec.ByteReader,
) -> @elaborate.BuslaneExternalMap raise {
  let builtins : Array[@elaborate.BuslaneBuiltinExternal] = []
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
fn @bytecodec.ByteWriter::write_entries(
  self : @bytecodec.ByteWriter,
  entries : Array[@elaborate.BuslaneEntry],
) -> Unit {
  self.write_u32_le(entries.length())
  for entry in entries {
    self.write_entry(entry)
  }
}

///|
fn @bytecodec.ByteReader::read_entries(
  self : @bytecodec.ByteReader,
) -> Array[@elaborate.BuslaneEntry] raise {
  let entries : Array[@elaborate.BuslaneEntry] = []
  for _ in 0..<self.read_u32_le() {
    entries.push(self.read_entry())
  }
  entries
}

///|
fn @bytecodec.ByteWriter::write_entry(
  self : @bytecodec.ByteWriter,
  entry : @elaborate.BuslaneEntry,
) -> Unit {
  self.write_string(entry.module_path_text)
  self.write_string(entry.name)
  self.write_buslane_value_id(entry.value)
  self.write_buslane_type(entry.type_)
}

///|
fn @bytecodec.ByteReader::read_entry(
  self : @bytecodec.ByteReader,
) -> @elaborate.BuslaneEntry raise {
  {
    module_path_text: self.read_string(),
    name: self.read_string(),
    value: self.read_buslane_value_id(),
    type_: self.read_buslane_type(),
  }
}

///|
fn @bytecodec.ByteWriter::write_export_kind(
  self : @bytecodec.ByteWriter,
  kind : @elaborate.BuslaneModuleExportKind,
) -> Unit {
  self.write_u8(
    match kind {
      Type => 0
      DataConstructor => 1
      Effect => 2
      Operation => 3
      FieldSelector => 4
      Value => 5
    },
  )
}

///|
fn @bytecodec.ByteReader::read_export_kind(
  self : @bytecodec.ByteReader,
) -> @elaborate.BuslaneModuleExportKind raise {
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
fn @bytecodec.ByteWriter::write_optional_type_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.TypeId?,
) -> Unit {
  match id {
    None => self.write_bool(false)
    Some(id) => {
      self.write_bool(true)
      self.write_buslane_type_id(id)
    }
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
fn @bytecodec.ByteWriter::write_optional_data_con_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.DataConId?,
) -> Unit {
  match id {
    None => self.write_bool(false)
    Some(id) => {
      self.write_bool(true)
      self.write_buslane_data_con_id(id)
    }
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
fn @bytecodec.ByteWriter::write_optional_effect_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.EffectId?,
) -> Unit {
  match id {
    None => self.write_bool(false)
    Some(id) => {
      self.write_bool(true)
      self.write_buslane_effect_id(id)
    }
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
fn @bytecodec.ByteWriter::write_optional_operation_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.OperationId?,
) -> Unit {
  match id {
    None => self.write_bool(false)
    Some(id) => {
      self.write_bool(true)
      self.write_buslane_operation_id(id)
    }
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
fn @bytecodec.ByteWriter::write_optional_value_id(
  self : @bytecodec.ByteWriter,
  id : @buslane.ValueId?,
) -> Unit {
  match id {
    None => self.write_bool(false)
    Some(id) => {
      self.write_bool(true)
      self.write_buslane_value_id(id)
    }
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
fn @bytecodec.ByteWriter::write_exports(
  self : @bytecodec.ByteWriter,
  exports : Array[@elaborate.BuslaneModuleExport],
) -> Unit {
  self.write_u32_le(exports.length())
  for export_ in exports {
    self.write_export_kind(export_.kind)
    self.write_string(export_.name)
    self.write_optional_type_id(export_.type_id)
    self.write_optional_data_con_id(export_.data_constructor)
    self.write_optional_effect_id(export_.effect_id)
    self.write_optional_operation_id(export_.operation)
    self.write_optional_value_id(export_.value)
  }
}

///|
fn @bytecodec.ByteReader::read_exports(
  self : @bytecodec.ByteReader,
) -> Array[@elaborate.BuslaneModuleExport] raise {
  let exports : Array[@elaborate.BuslaneModuleExport] = []
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
fn @bytecodec.ByteWriter::write_imports(
  self : @bytecodec.ByteWriter,
  imports : Array[ModuleImportedReference],
) -> Unit {
  self.write_u32_le(imports.length())
  for import_ in imports {
    self.write_string(import_.module_path_text)
    self.write_export_kind(import_.kind)
    self.write_string(import_.name)
    self.write_compilation_fingerprint(import_.fingerprint)
    self.write_optional_type_id(import_.type_id)
    self.write_optional_data_con_id(import_.data_constructor)
    self.write_optional_effect_id(import_.effect_id)
    self.write_optional_operation_id(import_.operation)
    self.write_optional_value_id(import_.value)
  }
}

///|
fn @bytecodec.ByteReader::read_imports(
  self : @bytecodec.ByteReader,
) -> Array[ModuleImportedReference] raise {
  let imports : Array[ModuleImportedReference] = []
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
fn @bytecodec.ByteWriter::write_runtime_effect_operations(
  self : @bytecodec.ByteWriter,
  operations : Array[LinkedRuntimeEffectOperation],
) -> Unit {
  self.write_u32_le(operations.length())
  for operation in operations {
    self.write_string(operation.module_path_text)
    self.write_string(operation.effect_name)
    self.write_string(operation.operation_name)
    self.write_lane_types(operation.payload)
    self.write_lane_type(operation.result)
    self.write_buslane_operation_id(operation.operation)
  }
}

///|
fn @bytecodec.ByteReader::read_runtime_effect_operations(
  self : @bytecodec.ByteReader,
) -> Array[LinkedRuntimeEffectOperation] raise {
  let operations : Array[LinkedRuntimeEffectOperation] = []
  for _ in 0..<self.read_u32_le() {
    operations.push({
      module_path_text: self.read_string(),
      effect_name: self.read_string(),
      operation_name: self.read_string(),
      payload: self.read_lane_types(),
      result: self.read_lane_type(),
      operation: self.read_buslane_operation_id(),
    })
  }
  operations
}
