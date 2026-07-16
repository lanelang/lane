///|
fn @bytecodec.ByteWriter::write_source_span(
  self : @bytecodec.ByteWriter,
  span : @basic.SourceSpan,
) -> Unit {
  self.write_u32_le_int(span.start_offset)
  self.write_u32_le_int(span.end_offset)
  self.write_u32_le_int(span.start_line)
  self.write_u32_le_int(span.start_column)
  self.write_u32_le_int(span.end_line)
  self.write_u32_le_int(span.end_column)
}

///|
fn @bytecodec.ByteReader::read_source_span(
  self : @bytecodec.ByteReader,
) -> @basic.SourceSpan raise {
  {
    start_offset: self.read_u32_le_int(),
    end_offset: self.read_u32_le_int(),
    start_line: self.read_u32_le_int(),
    start_column: self.read_u32_le_int(),
    end_line: self.read_u32_le_int(),
    end_column: self.read_u32_le_int(),
  }
}

///|
fn @bytecodec.ByteReader::read_compilation_fingerprint(
  self : @bytecodec.ByteReader,
) -> @artifact_core.CompilationFingerprint raise {
  { value: self.read_string() }
}

///|
fn @bytecodec.ByteReader::read_imported_interface_fingerprints(
  self : @bytecodec.ByteReader,
) -> Array[@artifact_core.ImportedInterfaceFingerprint] raise {
  let fingerprints : Array[@artifact_core.ImportedInterfaceFingerprint] = []
  for _ in 0..<self.read_u32_le_int() {
    fingerprints.push({
      module_path_text: self.read_string(),
      fingerprint: self.read_compilation_fingerprint(),
    })
  }
  fingerprints
}
