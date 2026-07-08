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
) -> @basic.SourceSpan raise ArtifactBinaryDecodeError {
  {
    start_offset: read_u32_le(self),
    end_offset: read_u32_le(self),
    start_line: read_u32_le(self),
    start_column: read_u32_le(self),
    end_line: read_u32_le(self),
    end_column: read_u32_le(self),
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
) -> Array[String] raise ArtifactBinaryDecodeError {
  let items : Array[String] = []
  for _ in 0..<read_u32_le(self) {
    items.push(read_string(self))
  }
  items
}

///|
fn @bytecodec.ByteWriter::write_compilation_fingerprint(
  self : @bytecodec.ByteWriter,
  fingerprint : CompilationFingerprint,
) -> Unit {
  self.write_string(fingerprint.value)
}

///|
fn @bytecodec.ByteReader::read_compilation_fingerprint(
  self : @bytecodec.ByteReader,
) -> CompilationFingerprint raise ArtifactBinaryDecodeError {
  { value: read_string(self) }
}

///|
fn @bytecodec.ByteWriter::write_imported_interface_fingerprints(
  self : @bytecodec.ByteWriter,
  fingerprints : Array[ImportedInterfaceFingerprint],
) -> Unit {
  self.write_u32_le(fingerprints.length())
  for fingerprint in fingerprints {
    self.write_string(fingerprint.module_path_text)
    self.write_compilation_fingerprint(fingerprint.fingerprint)
  }
}

///|
fn @bytecodec.ByteReader::read_imported_interface_fingerprints(
  self : @bytecodec.ByteReader,
) -> Array[ImportedInterfaceFingerprint] raise ArtifactBinaryDecodeError {
  let fingerprints : Array[ImportedInterfaceFingerprint] = []
  for _ in 0..<read_u32_le(self) {
    fingerprints.push({
      module_path_text: read_string(self),
      fingerprint: self.read_compilation_fingerprint(),
    })
  }
  fingerprints
}
