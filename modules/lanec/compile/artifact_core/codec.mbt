///|
pub fn write_compilation_fingerprint(
  writer : @bytecodec.ByteWriter,
  fingerprint : CompilationFingerprint,
) -> Unit {
  writer.write_string(fingerprint.value)
}

///|
pub fn write_imported_interface_fingerprints(
  writer : @bytecodec.ByteWriter,
  fingerprints : Array[ImportedInterfaceFingerprint],
) -> Unit {
  writer.write_u32_le_int(fingerprints.length())
  for fingerprint in fingerprints {
    writer.write_string(fingerprint.module_path_text)
    write_compilation_fingerprint(writer, fingerprint.fingerprint)
  }
}

///|
pub fn write_buslane_program_section(
  writer : @bytecodec.ByteWriter,
  program : @buslane.Program,
) -> Unit {
  writer.write_bytes(@buslane_codec.encode_program(program))
}

///|
pub fn write_buslane_type(
  writer : @bytecodec.ByteWriter,
  type_ : @buslane.Type,
) -> Unit {
  @buslane_codec.write_type(writer, type_)
}

///|
pub fn write_buslane_value_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.ValueId,
) -> Unit {
  @buslane_codec.write_value_id(writer, id)
}

///|
pub fn write_buslane_type_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.TypeId,
) -> Unit {
  @buslane_codec.write_type_id(writer, id)
}

///|
pub fn write_buslane_data_con_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.DataConId,
) -> Unit {
  @buslane_codec.write_data_con_id(writer, id)
}

///|
pub fn write_buslane_effect_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.EffectId,
) -> Unit {
  @buslane_codec.write_effect_id(writer, id)
}

///|
pub fn write_buslane_operation_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.OperationId,
) -> Unit {
  @buslane_codec.write_operation_id(writer, id)
}

///|
pub fn write_externals(
  writer : @bytecodec.ByteWriter,
  externals : @buslane_lowering.BuslaneExternalMap,
) -> Unit {
  writer.write_u32_le_int(externals.builtins.length())
  for external in externals.builtins {
    write_buslane_value_id(writer, external.value)
    write_intrinsic(writer, external.intrinsic)
    write_buslane_type(writer, external.type_)
  }
  writer.write_u32_le_int(externals.runtime_imports.length())
  for import_ in externals.runtime_imports {
    write_buslane_value_id(writer, import_.value)
    writer.write_string(import_.symbol)
    write_host_signature(writer, import_.signature)
    write_buslane_type(writer, import_.type_)
  }
}

///|
fn write_intrinsic(
  writer : @bytecodec.ByteWriter,
  intrinsic : @abi.Intrinsic,
) -> Unit {
  writer.write_u8(
    match intrinsic {
      I64Add => 0
      I64Sub => 1
      I64Mul => 2
      I64Div => 3
      I64Rem => 4
      I64Neg => 5
      I64Equal => 6
      I64Less => 7
      F64Add => 8
      F64Sub => 9
      F64Mul => 10
      F64Div => 11
      F64Neg => 12
      F64Equal => 13
      F64Less => 14
      F64Inf => 15
      F64NegativeInf => 16
      F64Nan => 17
      StringEqual => 18
    },
  )
}

///|
fn write_host_signature(
  writer : @bytecodec.ByteWriter,
  signature : @abi.HostSignature,
) -> Unit {
  writer.write_u32_le_int(signature.parameters.length())
  for parameter in signature.parameters {
    write_host_value_kind(writer, parameter)
  }
  write_host_value_kind(writer, signature.result)
}

///|
fn write_host_value_kind(
  writer : @bytecodec.ByteWriter,
  kind : @abi.ValueKind,
) -> Unit {
  writer.write_u8(
    match kind {
      Unit => 0
      Bool => 1
      Int => 2
      Double => 3
      String => 4
      Opaque => 5
    },
  )
}

///|
pub fn write_entries(
  writer : @bytecodec.ByteWriter,
  entries : Array[@buslane_lowering.BuslaneEntry],
) -> Unit {
  writer.write_u32_le_int(entries.length())
  for entry in entries {
    write_entry(writer, entry)
  }
}

///|
pub fn write_entry(
  writer : @bytecodec.ByteWriter,
  entry : @buslane_lowering.BuslaneEntry,
) -> Unit {
  writer.write_string(entry.module_path_text)
  writer.write_string(entry.name)
  write_buslane_value_id(writer, entry.value)
  write_buslane_type(writer, entry.type_)
}

///|
pub fn write_export_kind(
  writer : @bytecodec.ByteWriter,
  kind : @buslane_lowering.BuslaneModuleExportKind,
) -> Unit {
  writer.write_u8(
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
pub fn write_optional_type_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.TypeId?,
) -> Unit {
  if id is Some(id) {
    writer.write_bool(true)
    write_buslane_type_id(writer, id)
  } else {
    writer.write_bool(false)
  }
}

///|
pub fn write_optional_data_con_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.DataConId?,
) -> Unit {
  if id is Some(id) {
    writer.write_bool(true)
    write_buslane_data_con_id(writer, id)
  } else {
    writer.write_bool(false)
  }
}

///|
pub fn write_optional_effect_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.EffectId?,
) -> Unit {
  if id is Some(id) {
    writer.write_bool(true)
    write_buslane_effect_id(writer, id)
  } else {
    writer.write_bool(false)
  }
}

///|
pub fn write_optional_operation_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.OperationId?,
) -> Unit {
  if id is Some(id) {
    writer.write_bool(true)
    write_buslane_operation_id(writer, id)
  } else {
    writer.write_bool(false)
  }
}

///|
pub fn write_optional_value_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.ValueId?,
) -> Unit {
  if id is Some(id) {
    writer.write_bool(true)
    write_buslane_value_id(writer, id)
  } else {
    writer.write_bool(false)
  }
}

///|
pub fn write_exports(
  writer : @bytecodec.ByteWriter,
  exports : Array[@buslane_lowering.BuslaneModuleExport],
) -> Unit {
  writer.write_u32_le_int(exports.length())
  for export_ in exports {
    write_export_kind(writer, export_.kind)
    writer.write_string(export_.name)
    write_optional_type_id(writer, export_.type_id)
    write_optional_data_con_id(writer, export_.data_constructor)
    write_optional_effect_id(writer, export_.effect_id)
    write_optional_operation_id(writer, export_.operation)
    write_optional_value_id(writer, export_.value)
  }
}

///|
pub fn write_imports(
  writer : @bytecodec.ByteWriter,
  imports : Array[ModuleImportedReference],
) -> Unit {
  writer.write_u32_le_int(imports.length())
  for import_ in imports {
    writer.write_string(import_.module_path_text)
    write_export_kind(writer, import_.kind)
    writer.write_string(import_.name)
    write_compilation_fingerprint(writer, import_.fingerprint)
    write_optional_type_id(writer, import_.type_id)
    write_optional_data_con_id(writer, import_.data_constructor)
    write_optional_effect_id(writer, import_.effect_id)
    write_optional_operation_id(writer, import_.operation)
    write_optional_value_id(writer, import_.value)
  }
}
