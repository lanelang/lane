///|
fn @bytecodec.ByteReader::read_externals(
  self : @bytecodec.ByteReader,
) -> @buslane_lowering.BuslaneExternalMap raise {
  let builtins : Array[@buslane_lowering.BuslaneBuiltinExternal] = []
  for _ in 0..<self.read_u32_le_int() {
    builtins.push({
      value: self.read_buslane_value_id(),
      intrinsic: self.read_intrinsic(),
      type_: self.read_buslane_type(),
    })
  }
  let runtime_imports : Array[@buslane_lowering.BuslaneRuntimeImport] = []
  for _ in 0..<self.read_u32_le_int() {
    runtime_imports.push({
      value: self.read_buslane_value_id(),
      symbol: self.read_string(),
      signature: self.read_host_signature(),
      type_: self.read_buslane_type(),
    })
  }
  { builtins, runtime_imports }
}

///|
fn @bytecodec.ByteReader::read_intrinsic(
  self : @bytecodec.ByteReader,
) -> @abi.Intrinsic raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      I64Add
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      I64Sub
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      I64Mul
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      I64Div
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      I64Rem
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      I64Neg
    }
    [u8be(6), .. rest] => {
      self.update_view(rest)
      I64Equal
    }
    [u8be(7), .. rest] => {
      self.update_view(rest)
      I64Less
    }
    [u8be(8), .. rest] => {
      self.update_view(rest)
      F64Add
    }
    [u8be(9), .. rest] => {
      self.update_view(rest)
      F64Sub
    }
    [u8be(10), .. rest] => {
      self.update_view(rest)
      F64Mul
    }
    [u8be(11), .. rest] => {
      self.update_view(rest)
      F64Div
    }
    [u8be(12), .. rest] => {
      self.update_view(rest)
      F64Neg
    }
    [u8be(13), .. rest] => {
      self.update_view(rest)
      F64Equal
    }
    [u8be(14), .. rest] => {
      self.update_view(rest)
      F64Less
    }
    [u8be(15), .. rest] => {
      self.update_view(rest)
      F64Inf
    }
    [u8be(16), .. rest] => {
      self.update_view(rest)
      F64NegativeInf
    }
    [u8be(17), .. rest] => {
      self.update_view(rest)
      F64Nan
    }
    [u8be(18), .. rest] => {
      self.update_view(rest)
      StringEqual
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="Intrinsic",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteReader::read_host_signature(
  self : @bytecodec.ByteReader,
) -> @abi.HostSignature raise {
  let parameters = []
  for _ in 0..<self.read_u32_le_int() {
    parameters.push(self.read_host_value_kind())
  }
  { parameters, result: self.read_host_value_kind() }
}

///|
fn @bytecodec.ByteReader::read_host_value_kind(
  self : @bytecodec.ByteReader,
) -> @abi.ValueKind raise {
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
    [u8be(5), .. rest] => {
      self.update_view(rest)
      Opaque
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="HostValueKind",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteReader::read_entries(
  self : @bytecodec.ByteReader,
) -> Array[@buslane_lowering.BuslaneEntry] raise {
  let entries : Array[@buslane_lowering.BuslaneEntry] = []
  for _ in 0..<self.read_u32_le_int() {
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
  for _ in 0..<self.read_u32_le_int() {
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
  for _ in 0..<self.read_u32_le_int() {
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
