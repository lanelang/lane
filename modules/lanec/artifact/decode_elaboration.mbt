///|
fn @bytecodec.ByteReader::read_externals(
  self : @bytecodec.ByteReader,
) -> @buslane_lowering.BuslaneExternalMap raise {
  let builtins : Array[@buslane_lowering.BuslaneBuiltinExternal] = []
  for _ in 0..<self.read_u32_le_int() {
    builtins.push(
      @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
        self.read_buslane_value_id(),
        self.read_intrinsic(),
        self.read_buslane_type(),
      ),
    )
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
      Panic
    }
    [u8be(19), .. rest] => {
      self.update_view(rest)
      ByteToI64
    }
    [u8be(20), .. rest] => {
      self.update_view(rest)
      I64ToByte
    }
    [u8be(21), .. rest] => {
      self.update_view(rest)
      BytesMake
    }
    [u8be(22), .. rest] => {
      self.update_view(rest)
      BytesLength
    }
    [u8be(23), .. rest] => {
      self.update_view(rest)
      BytesGet
    }
    [u8be(24), .. rest] => {
      self.update_view(rest)
      BytesSet
    }
    [u8be(25), .. rest] => {
      self.update_view(rest)
      I32Add
    }
    [u8be(26), .. rest] => {
      self.update_view(rest)
      I32Sub
    }
    [u8be(27), .. rest] => {
      self.update_view(rest)
      I32Mul
    }
    [u8be(28), .. rest] => {
      self.update_view(rest)
      I32Div
    }
    [u8be(29), .. rest] => {
      self.update_view(rest)
      I32Rem
    }
    [u8be(30), .. rest] => {
      self.update_view(rest)
      I32Neg
    }
    [u8be(31), .. rest] => {
      self.update_view(rest)
      I32Equal
    }
    [u8be(32), .. rest] => {
      self.update_view(rest)
      I32Less
    }
    [u8be(33), .. rest] => {
      self.update_view(rest)
      I32ToI64
    }
    [u8be(34), .. rest] => {
      self.update_view(rest)
      I64ToI32
    }
    [u8be(35), .. rest] => {
      self.update_view(rest)
      CharToI32
    }
    [u8be(36), .. rest] => {
      self.update_view(rest)
      I32ToChar
    }
    [u8be(37), .. rest] => {
      self.update_view(rest)
      StringToBytes
    }
    [u8be(38), .. rest] => {
      self.update_view(rest)
      BytesIsValidUtf8
    }
    [u8be(39), .. rest] => {
      self.update_view(rest)
      BytesToString
    }
    [u8be(40), .. rest] => {
      self.update_view(rest)
      BytesEqual
    }
    [u8be(41), .. rest] => {
      self.update_view(rest)
      BytesConcat
    }
    [u8be(42), .. rest] => {
      self.update_view(rest)
      BytesSlice
    }
    [u8be(43), .. rest] => {
      self.update_view(rest)
      F32Add
    }
    [u8be(44), .. rest] => {
      self.update_view(rest)
      F32Sub
    }
    [u8be(45), .. rest] => {
      self.update_view(rest)
      F32Mul
    }
    [u8be(46), .. rest] => {
      self.update_view(rest)
      F32Div
    }
    [u8be(47), .. rest] => {
      self.update_view(rest)
      F32Neg
    }
    [u8be(48), .. rest] => {
      self.update_view(rest)
      F32Equal
    }
    [u8be(49), .. rest] => {
      self.update_view(rest)
      F32Less
    }
    [u8be(50), .. rest] => {
      self.update_view(rest)
      F32Inf
    }
    [u8be(51), .. rest] => {
      self.update_view(rest)
      F32NegativeInf
    }
    [u8be(52), .. rest] => {
      self.update_view(rest)
      F32Nan
    }
    [u8be(53), .. rest] => {
      self.update_view(rest)
      I64ToF32
    }
    [u8be(54), .. rest] => {
      self.update_view(rest)
      F32ToI64
    }
    [u8be(55), .. rest] => {
      self.update_view(rest)
      F32ToF64
    }
    [u8be(56), .. rest] => {
      self.update_view(rest)
      F64ToF32
    }
    [u8be(57), .. rest] => {
      self.update_view(rest)
      I64ToF64
    }
    [u8be(58), .. rest] => {
      self.update_view(rest)
      F64ToI64
    }
    [u8be(59), .. rest] => {
      self.update_view(rest)
      F32ToString
    }
    [u8be(60), .. rest] => {
      self.update_view(rest)
      F64ToString
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
      I64
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      F64
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      String
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      Opaque
    }
    [u8be(6), .. rest] => {
      self.update_view(rest)
      F32
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
fn @bytecodec.ByteReader::read_module_reference(
  self : @bytecodec.ByteReader,
) -> @buslane_lowering.BuslaneModuleReference raise {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Type(self.read_buslane_type_id())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      DataConstructor(self.read_buslane_data_con_id())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Effect(self.read_buslane_effect_id())
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Operation(self.read_buslane_operation_id())
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      FieldSelector(self.read_buslane_value_id())
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      Value(self.read_buslane_value_id())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_binary_tag(
        offset~,
        domain="BuslaneModuleReference",
        tag=tag.reinterpret_as_int(),
      )
    }
    _ => unexpected_u8(self)
  }
}

///|
fn @bytecodec.ByteReader::read_exports(
  self : @bytecodec.ByteReader,
) -> Array[@buslane_lowering.BuslaneModuleExport] raise {
  let exports : Array[@buslane_lowering.BuslaneModuleExport] = []
  for _ in 0..<self.read_u32_le_int() {
    exports.push({
      name: self.read_string(),
      reference: self.read_module_reference(),
    })
  }
  exports
}

///|
fn @bytecodec.ByteReader::read_imports(
  self : @bytecodec.ByteReader,
) -> Array[@artifact_model.ModuleImportedReference] raise {
  let imports : Array[@artifact_model.ModuleImportedReference] = []
  for _ in 0..<self.read_u32_le_int() {
    imports.push({
      module_path_text: self.read_string(),
      name: self.read_string(),
      fingerprint: self.read_compilation_fingerprint(),
      reference: self.read_module_reference(),
    })
  }
  imports
}
