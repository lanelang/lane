///|
let artifact_binary_version = 1

///|
let artifact_binary_kind_interface = 1

///|
let artifact_binary_kind_object = 2

///|
let artifact_binary_kind_program = 3

///|
priv struct BinaryArtifactPayload {
  kind : Int
  payload : Bytes
}

///|
priv struct BinaryArtifactHeader {
  version : Int
  kind : Int
  payload_length : Int
  body : BytesView
}

///|
fn artifact_binary_magic() -> Bytes {
  Bytes::from_array([b'L', b'A', b'N', b'E', b'A', b'R', b'T', b'\x00'])
}

///|
pub fn artifact_binary_to_inspect_text(bytes : Bytes) -> Result[String, String] {
  artifact_binary_decode_result(fn() raise {
    let decoded = decode_artifact_container(bytes)
    match decoded.kind {
      kind if kind == artifact_binary_kind_interface =>
        artifact_to_inspect_text(
          decode_module_interface_artifact_payload(decoded.payload),
        )
      kind if kind == artifact_binary_kind_object =>
        artifact_to_inspect_text(
          decode_module_object_artifact_payload(decoded.payload),
        )
      kind if kind == artifact_binary_kind_program =>
        artifact_to_inspect_text(
          decode_linked_program_artifact_payload(decoded.payload),
        )
      kind => raise InvalidKind(kind~)
    }
  })
}

///|
fn[T : @prettyprinter.Pretty] artifact_to_inspect_text(artifact : T) -> String {
  @prettyprinter.render(artifact, width=100) + "\n"
}

///|
pub fn module_interface_artifact_to_binary(
  artifact : @module_compile.ModuleInterfaceArtifact,
) -> Bytes {
  artifact_payload_to_binary(
    artifact_binary_kind_interface,
    encode_module_interface_artifact_payload(artifact),
  )
}

///|
pub fn parse_module_interface_artifact_binary(
  bytes : Bytes,
) -> Result[@module_compile.ModuleInterfaceArtifact, String] {
  artifact_binary_decode_result(fn() raise {
    decode_module_interface_artifact_payload(
      binary_artifact_payload(
        bytes,
        expected_kind=artifact_binary_kind_interface,
      ),
    )
  })
}

///|
pub fn module_object_artifact_to_binary(
  artifact : @module_compile.ModuleObjectArtifact,
) -> Bytes {
  artifact_payload_to_binary(
    artifact_binary_kind_object,
    encode_module_object_artifact_payload(artifact),
  )
}

///|
pub fn parse_module_object_artifact_binary(
  bytes : Bytes,
) -> Result[@module_compile.ModuleObjectArtifact, String] {
  artifact_binary_decode_result(fn() raise {
    decode_module_object_artifact_payload(
      binary_artifact_payload(bytes, expected_kind=artifact_binary_kind_object),
    )
  })
}

///|
pub fn linked_program_artifact_to_binary(
  artifact : @module_compile.LinkedProgramArtifact,
) -> Bytes {
  artifact_payload_to_binary(
    artifact_binary_kind_program,
    encode_linked_program_artifact_payload(artifact),
  )
}

///|
pub fn parse_linked_program_artifact_binary(
  bytes : Bytes,
) -> Result[@module_compile.LinkedProgramArtifact, String] {
  artifact_binary_decode_result(fn() raise {
    decode_linked_program_artifact_payload(
      binary_artifact_payload(bytes, expected_kind=artifact_binary_kind_program),
    )
  })
}

///|
fn artifact_payload_to_binary(kind : Int, payload : Bytes) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_raw_bytes(artifact_binary_magic())
  writer.write_u8(artifact_binary_version)
  writer.write_u8(kind)
  writer.write_u32_le_int(payload.length())
  writer.write_raw_bytes(payload)
  writer.to_bytes()
}

///|
fn binary_artifact_payload(bytes : Bytes, expected_kind~ : Int) -> Bytes raise {
  let decoded = decode_artifact_container(bytes)
  if decoded.kind != expected_kind {
    raise WrongKind(expected=expected_kind, actual=decoded.kind)
  }
  decoded.payload
}

///|
fn decode_artifact_container(bytes : Bytes) -> BinaryArtifactPayload raise {
  let header = decode_artifact_header(bytes)
  if header.version != artifact_binary_version {
    raise UnsupportedContainerVersion(version=header.version)
  }
  let kind = header.kind
  if kind != artifact_binary_kind_interface &&
    kind != artifact_binary_kind_object &&
    kind != artifact_binary_kind_program {
    raise InvalidKind(kind~)
  }
  if header.payload_length < 0 || header.body.length() < header.payload_length {
    raise ByteError(
      UnexpectedEnd(
        offset=artifact_binary_header_length(),
        expected="artifact payload",
        available=header.body.length(),
      ),
    )
  }
  let remaining = header.body.length() - header.payload_length
  if remaining != 0 {
    raise ByteError(
      TrailingBytes(
        offset=artifact_binary_header_length() + header.payload_length,
        remaining~,
      ),
    )
  }
  let payload = header.body[:header.payload_length].to_owned()
  { kind, payload }
}

///|
fn decode_artifact_header(bytes : Bytes) -> BinaryArtifactHeader raise {
  match bytes[:] {
    [
      .. b"LANEART\x00",
      u8be(version),
      u8be(kind),
      i32le(payload_length),
      .. body,
    ] =>
      {
        version: version.reinterpret_as_int(),
        kind: kind.reinterpret_as_int(),
        payload_length,
        body,
      }
    _ =>
      if bytes.length() >= artifact_binary_magic().length() {
        raise InvalidMagic(offset=first_artifact_magic_mismatch(bytes))
      } else {
        raise ByteError(
          UnexpectedEnd(
            offset=bytes.length(),
            expected="artifact header",
            available=bytes.length(),
          ),
        )
      }
  }
}

///|
fn artifact_binary_header_length() -> Int {
  14
}

///|
fn first_artifact_magic_mismatch(bytes : Bytes) -> Int {
  match bytes[:] {
    [.. b"LANEART\x00", ..] => 8
    [u8be(tag), ..] if tag != 76 => 0
    [.. b"L", u8be(tag), ..] if tag != 65 => 1
    [.. b"LA", u8be(tag), ..] if tag != 78 => 2
    [.. b"LAN", u8be(tag), ..] if tag != 69 => 3
    [.. b"LANE", u8be(tag), ..] if tag != 65 => 4
    [.. b"LANEA", u8be(tag), ..] if tag != 82 => 5
    [.. b"LANEAR", u8be(tag), ..] if tag != 84 => 6
    [.. b"LANEART", u8be(tag), ..] if tag != 0 => 7
    _ => bytes.length()
  }
}

///|
fn artifact_binary_kind_name(kind : Int) -> String {
  if kind == artifact_binary_kind_interface {
    "interface"
  } else if kind == artifact_binary_kind_object {
    "object"
  } else if kind == artifact_binary_kind_program {
    "program"
  } else {
    "unknown(\{kind})"
  }
}

///|
fn encode_module_interface_artifact_payload(
  artifact : @module_compile.ModuleInterfaceArtifact,
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(artifact.schema_version)
  writer.write_string(artifact.module_path_text)
  writer.write_module_interface(artifact.interface)
  @artifact_core.write_compilation_fingerprint(
    writer,
    artifact.interface_fingerprint,
  )
  @artifact_core.write_compilation_fingerprint(
    writer,
    artifact.module_fingerprint,
  )
  @artifact_core.write_imported_interface_fingerprints(
    writer,
    artifact.imported_interface_fingerprints,
  )
  writer.to_bytes()
}

///|
fn decode_module_interface_artifact_payload(
  payload : Bytes,
) -> @module_compile.ModuleInterfaceArtifact raise {
  let reader = @bytecodec.ByteReader::from_bytes(payload)
  let schema_version = reader.read_u32_le_int()
  if schema_version != @module_compile.module_interface_artifact_schema_version {
    raise UnsupportedArtifactSchema(kind="interface", version=schema_version)
  }
  let artifact : @module_compile.ModuleInterfaceArtifact = {
    schema_version,
    module_path_text: reader.read_string(),
    interface: reader.read_module_interface(),
    interface_fingerprint: reader.read_compilation_fingerprint(),
    module_fingerprint: reader.read_compilation_fingerprint(),
    imported_interface_fingerprints: reader.read_imported_interface_fingerprints(),
  }
  reader.expect_end()
  artifact
}

///|
fn encode_module_object_artifact_payload(
  artifact : @module_compile.ModuleObjectArtifact,
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(artifact.schema_version)
  writer.write_string(artifact.module_path_text)
  @artifact_core.write_compilation_fingerprint(
    writer,
    artifact.interface_fingerprint,
  )
  @artifact_core.write_buslane_program_section(writer, {
    metadata: artifact.metadata,
    terms: artifact.terms,
  })
  @artifact_core.write_externals(writer, artifact.externals)
  @artifact_core.write_entries(writer, artifact.entries)
  @artifact_core.write_exports(writer, artifact.exports)
  @artifact_core.write_imports(writer, artifact.imports)
  @artifact_core.write_compilation_fingerprint(
    writer,
    artifact.module_fingerprint,
  )
  @artifact_core.write_compilation_fingerprint(
    writer,
    artifact.object_fingerprint,
  )
  @artifact_core.write_imported_interface_fingerprints(
    writer,
    artifact.imported_interface_fingerprints,
  )
  writer.to_bytes()
}

///|
fn decode_module_object_artifact_payload(
  payload : Bytes,
) -> @module_compile.ModuleObjectArtifact raise {
  let reader = @bytecodec.ByteReader::from_bytes(payload)
  let schema_version = reader.read_u32_le_int()
  if schema_version != @module_compile.module_object_artifact_schema_version {
    raise UnsupportedArtifactSchema(kind="object", version=schema_version)
  }
  let module_path_text = reader.read_string()
  let interface_fingerprint = reader.read_compilation_fingerprint()
  let program = reader.read_buslane_program_section()
  let artifact : @module_compile.ModuleObjectArtifact = {
    schema_version,
    module_path_text,
    interface_fingerprint,
    metadata: program.metadata,
    terms: program.terms,
    externals: reader.read_externals(),
    entries: reader.read_entries(),
    exports: reader.read_exports(),
    imports: reader.read_imports(),
    module_fingerprint: reader.read_compilation_fingerprint(),
    object_fingerprint: reader.read_compilation_fingerprint(),
    imported_interface_fingerprints: reader.read_imported_interface_fingerprints(),
  }
  reader.expect_end()
  artifact
}

///|
fn encode_linked_program_artifact_payload(
  artifact : @module_compile.LinkedProgramArtifact,
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(artifact.schema_version)
  writer.write_raw_bytes(
    @loisvm_bytecode.bytecode_image_to_binary(artifact.bytecode),
  )
  writer.to_bytes()
}

///|
fn decode_linked_program_artifact_payload(
  payload : Bytes,
) -> @module_compile.LinkedProgramArtifact raise {
  let reader = @bytecodec.ByteReader::from_bytes(payload)
  let schema_version = reader.read_u32_le_int()
  if schema_version != @module_compile.linked_program_artifact_schema_version {
    raise UnsupportedArtifactSchema(kind="program", version=schema_version)
  }
  let bytes = reader.read_raw_bytes(reader.remaining())
  let bytecode = match @loisvm_bytecode.parse_bytecode_image_binary(bytes) {
    Ok(bytecode) => bytecode
    Err(error) => raise LoisvmBytecodeError(error)
  }
  { schema_version, bytecode }
}
