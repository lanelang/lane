///|
fn @bytecodec.ByteWriter::write_source_span(
  self : @bytecodec.ByteWriter,
  span : @basic.SourceSpan,
) -> Unit {
  self.write_u32_le(span.start_offset)
  self.write_u32_le(span.end_offset)
  self.write_u32_le(span.start_line)
  self.write_u32_le(span.start_column)
  self.write_u32_le(span.end_line)
  self.write_u32_le(span.end_column)
}

///|
fn @bytecodec.ByteReader::read_source_span(
  self : @bytecodec.ByteReader,
) -> @basic.SourceSpan raise {
  {
    start_offset: self.read_u32_le(),
    end_offset: self.read_u32_le(),
    start_line: self.read_u32_le(),
    start_column: self.read_u32_le(),
    end_line: self.read_u32_le(),
    end_column: self.read_u32_le(),
  }
}

///|
fn @bytecodec.ByteWriter::write_string_array(
  self : @bytecodec.ByteWriter,
  items : Array[String],
) -> Unit {
  self.write_u32_le(items.length())
  for item in items {
    self.write_string(item)
  }
}

///|
fn @bytecodec.ByteReader::read_string_array(
  self : @bytecodec.ByteReader,
) -> Array[String] raise {
  let items : Array[String] = []
  for _ in 0..<self.read_u32_le() {
    items.push(self.read_string())
  }
  items
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
  for _ in 0..<self.read_u32_le() {
    fingerprints.push({
      module_path_text: self.read_string(),
      fingerprint: self.read_compilation_fingerprint(),
    })
  }
  fingerprints
}
