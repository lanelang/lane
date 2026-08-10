///|
fn write_compilation_fingerprint(
  writer : @bytecodec.ByteWriter,
  fingerprint : CompilationFingerprint,
) -> Unit {
  writer.write_string(fingerprint.value)
}

///|
fn write_imported_interface_fingerprints(
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
fn write_buslane_program_section(
  writer : @bytecodec.ByteWriter,
  program : @buslane.Program,
) -> Unit {
  writer.write_bytes(@buslane_codec.encode_program(program))
}

///|
fn write_buslane_type(
  writer : @bytecodec.ByteWriter,
  type_ : @buslane.Type,
) -> Unit {
  @buslane_codec.write_type(writer, type_)
}

///|
fn write_buslane_value_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.ValueId,
) -> Unit {
  @buslane_codec.write_value_id(writer, id)
}

///|
fn write_buslane_type_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.TypeId,
) -> Unit {
  @buslane_codec.write_type_id(writer, id)
}

///|
fn write_buslane_data_con_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.DataConId,
) -> Unit {
  @buslane_codec.write_data_con_id(writer, id)
}

///|
fn write_buslane_effect_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.EffectId,
) -> Unit {
  @buslane_codec.write_effect_id(writer, id)
}

///|
fn write_buslane_operation_id(
  writer : @bytecodec.ByteWriter,
  id : @buslane.OperationId,
) -> Unit {
  @buslane_codec.write_operation_id(writer, id)
}

///|
fn write_externals(
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
      Panic => 18
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
      ByteToI64 => 19
      I64ToByte => 20
      BytesMake => 21
      BytesLength => 22
      BytesGet => 23
      BytesSet => 24
      I32Add => 25
      I32Sub => 26
      I32Mul => 27
      I32Div => 28
      I32Rem => 29
      I32Neg => 30
      I32Equal => 31
      I32Less => 32
      I32ToI64 => 33
      I64ToI32 => 34
      CharToI32 => 35
      I32ToChar => 36
      StringToBytes => 37
      BytesIsValidUtf8 => 38
      BytesToString => 39
      BytesEqual => 40
      BytesConcat => 41
      BytesSlice => 42
      F32Add => 43
      F32Sub => 44
      F32Mul => 45
      F32Div => 46
      F32Neg => 47
      F32Equal => 48
      F32Less => 49
      F32Inf => 50
      F32NegativeInf => 51
      F32Nan => 52
      I64ToF32 => 53
      F32ToI64 => 54
      F32ToF64 => 55
      F64ToF32 => 56
      I64ToF64 => 57
      F64ToI64 => 58
      F32ToString => 59
      F64ToString => 60
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
      I64 => 2
      F64 => 3
      String => 4
      Opaque => 5
      F32 => 6
    },
  )
}

///|
fn write_entries(
  writer : @bytecodec.ByteWriter,
  entries : Array[@buslane_lowering.BuslaneEntry],
) -> Unit {
  writer.write_u32_le_int(entries.length())
  for entry in entries {
    write_entry(writer, entry)
  }
}

///|
fn write_entry(
  writer : @bytecodec.ByteWriter,
  entry : @buslane_lowering.BuslaneEntry,
) -> Unit {
  writer.write_string(entry.module_path_text)
  writer.write_string(entry.name)
  write_buslane_value_id(writer, entry.value)
  write_buslane_type(writer, entry.type_)
}

///|
fn write_module_reference(
  writer : @bytecodec.ByteWriter,
  reference : @buslane_lowering.BuslaneModuleReference,
) -> Unit {
  match reference {
    Type(id) => {
      writer.write_u8(0)
      write_buslane_type_id(writer, id)
    }
    DataConstructor(id) => {
      writer.write_u8(1)
      write_buslane_data_con_id(writer, id)
    }
    Effect(id) => {
      writer.write_u8(2)
      write_buslane_effect_id(writer, id)
    }
    Operation(id) => {
      writer.write_u8(3)
      write_buslane_operation_id(writer, id)
    }
    FieldSelector(id) => {
      writer.write_u8(4)
      write_buslane_value_id(writer, id)
    }
    Value(id) => {
      writer.write_u8(5)
      write_buslane_value_id(writer, id)
    }
  }
}

///|
fn write_exports(
  writer : @bytecodec.ByteWriter,
  exports : Array[@buslane_lowering.BuslaneModuleExport],
) -> Unit {
  writer.write_u32_le_int(exports.length())
  for export_ in exports {
    writer.write_string(export_.name)
    write_module_reference(writer, export_.reference)
  }
}

///|
fn write_imports(
  writer : @bytecodec.ByteWriter,
  imports : Array[ModuleImportedReference],
) -> Unit {
  writer.write_u32_le_int(imports.length())
  for import_ in imports {
    writer.write_string(import_.module_path_text)
    writer.write_string(import_.name)
    write_compilation_fingerprint(writer, import_.fingerprint)
    write_module_reference(writer, import_.reference)
  }
}
