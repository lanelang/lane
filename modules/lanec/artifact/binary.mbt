///|
let artifact_binary_version = 1

///|
let artifact_binary_kind_interface = 1

///|
let artifact_binary_kind_object = 2

///|
let artifact_binary_kind_program = 3

///|
/// Selects the only linked-program payload accepted or emitted by this codec.
let linked_program_artifact_schema_version = 17

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
/// Decodes any Lane artifact container and renders its payload for inspection.
/// This checks binary framing, version, kind, and payload syntax; it does not
/// make decoded compiler metadata trusted for linking or execution.
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
/// Deterministically encodes an interface artifact using the current container
/// and payload schema. Callers are responsible for supplying a valid artifact.
pub fn module_interface_artifact_to_binary(
  artifact : ModuleInterfaceArtifact,
) -> Bytes {
  artifact_payload_to_binary(
    artifact_binary_kind_interface,
    encode_module_interface_artifact_payload(artifact),
  )
}

///|
/// Decodes interface framing and payload syntax. Semantic schema, identity, and
/// fingerprint validation occurs when the artifact is consumed for compilation.
pub fn parse_module_interface_artifact_binary(
  bytes : Bytes,
) -> Result[ModuleInterfaceArtifact, String] {
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
/// Deterministically encodes a module object using the current binary schema.
pub fn module_object_artifact_to_binary(
  artifact : ModuleObjectArtifact,
) -> Bytes {
  artifact_payload_to_binary(
    artifact_binary_kind_object,
    encode_module_object_artifact_payload(artifact),
  )
}

///|
/// Decodes object framing and payload syntax without trusting its metadata.
/// Linking performs the schema and fingerprint validation boundary.
pub fn parse_module_object_artifact_binary(
  bytes : Bytes,
) -> Result[ModuleObjectArtifact, String] {
  artifact_binary_decode_result(fn() raise {
    decode_module_object_artifact_payload(
      binary_artifact_payload(bytes, expected_kind=artifact_binary_kind_object),
    )
  })
}

///|
/// Deterministically encodes the final Wasm module and its semantic host-import
/// manifest. Wasm validation belongs to executable production and loading.
pub fn linked_program_artifact_to_binary(
  artifact : LinkedProgramArtifact,
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(linked_program_artifact_schema_version)
  writer.write_u32_le_int(artifact.runtime_imports.length())
  for import_ in artifact.runtime_imports {
    writer.write_runtime_import(import_)
  }
  writer.write_bytes(artifact.wasm)
  artifact_payload_to_binary(artifact_binary_kind_program, writer.to_bytes())
}

///|
/// Decodes linked-program framing. Wasm parsing, validation and import binding
/// are performed atomically by the execution target when the artifact is used.
pub fn parse_linked_program_artifact_binary(
  bytes : Bytes,
) -> Result[LinkedProgramArtifact, String] {
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
  { kind, payload, }
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
  artifact : ModuleInterfaceArtifact,
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(artifact.schema_version)
  writer.write_string(artifact.module_path_text)
  writer.write_module_interface(artifact.interface)
  write_compilation_fingerprint(writer, artifact.interface_fingerprint)
  write_compilation_fingerprint(writer, artifact.module_fingerprint)
  write_imported_interface_fingerprints(
    writer,
    artifact.imported_interface_fingerprints,
  )
  writer.to_bytes()
}

///|
fn decode_module_interface_artifact_payload(
  payload : Bytes,
) -> ModuleInterfaceArtifact raise {
  let reader = @bytecodec.ByteReader::from_bytes(payload)
  let schema_version = reader.read_u32_le_int()
  if schema_version != module_interface_artifact_schema_version {
    raise UnsupportedArtifactSchema(kind="interface", version=schema_version)
  }
  let artifact : ModuleInterfaceArtifact = {
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
  artifact : ModuleObjectArtifact,
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(artifact.schema_version)
  writer.write_string(artifact.module_path_text)
  write_compilation_fingerprint(writer, artifact.interface_fingerprint)
  write_canonical_basic_abi_runtime_contract(
    writer,
    artifact.canonical_basic_abi,
  )
  write_buslane_program_section(writer, {
    metadata: artifact.metadata,
    terms: artifact.terms,
  })
  write_externals(writer, artifact.externals)
  write_entries(writer, artifact.entries)
  write_exports(writer, artifact.exports)
  write_imports(writer, artifact.imports)
  write_compilation_fingerprint(writer, artifact.module_fingerprint)
  write_compilation_fingerprint(writer, artifact.object_fingerprint)
  write_imported_interface_fingerprints(
    writer,
    artifact.imported_interface_fingerprints,
  )
  writer.to_bytes()
}

///|
fn decode_module_object_artifact_payload(
  payload : Bytes,
) -> ModuleObjectArtifact raise {
  let reader = @bytecodec.ByteReader::from_bytes(payload)
  let schema_version = reader.read_u32_le_int()
  if schema_version != module_object_artifact_schema_version {
    raise UnsupportedArtifactSchema(kind="object", version=schema_version)
  }
  let module_path_text = reader.read_string()
  let interface_fingerprint = reader.read_compilation_fingerprint()
  let canonical_basic_abi = reader.read_canonical_basic_abi_runtime_contract()
  let program = reader.read_buslane_program_section()
  let artifact : ModuleObjectArtifact = {
    schema_version,
    module_path_text,
    interface_fingerprint,
    canonical_basic_abi,
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
fn decode_linked_program_artifact_payload(
  payload : Bytes,
) -> LinkedProgramArtifact raise {
  let reader = @bytecodec.ByteReader::from_bytes(payload)
  let schema_version = reader.read_u32_le_int()
  if schema_version != linked_program_artifact_schema_version {
    raise UnsupportedArtifactSchema(kind="program", version=schema_version)
  }
  let runtime_imports = []
  for _ in 0..<reader.read_u32_le_int() {
    runtime_imports.push(reader.read_runtime_import())
  }
  let wasm = reader.read_bytes()
  reader.expect_end()
  { wasm, runtime_imports, }
}

///|
fn @bytecodec.ByteWriter::write_runtime_import(
  self : @bytecodec.ByteWriter,
  import_ : @lane_runtime.RuntimeImport,
) -> Unit {
  self.write_u32_le_int(import_.abi_major)
  self.write_u32_le_int(import_.parameters.length())
  for parameter in import_.parameters {
    self.write_runtime_value_kind(parameter)
  }
  self.write_runtime_value_kind(import_.result)
  self.write_string(import_.symbol)
}

///|
fn @bytecodec.ByteWriter::write_runtime_value_kind(
  self : @bytecodec.ByteWriter,
  kind : @lane_runtime.RuntimeValueKind,
) -> Unit {
  self.write_u8(
    match kind {
      Unit => 0x00
      Bool => 0x01
      I64 => 0x02
      F64 => 0x03
      String => 0x04
      Opaque => 0x05
      F32 => 0x06
    },
  )
}

///|
fn @bytecodec.ByteReader::read_runtime_import(
  self : @bytecodec.ByteReader,
) -> @lane_runtime.RuntimeImport raise {
  let abi_major = self.read_u32_le_int()
  let parameters = []
  for _ in 0..<self.read_u32_le_int() {
    parameters.push(self.read_runtime_value_kind())
  }
  {
    abi_major,
    parameters,
    result: self.read_runtime_value_kind(),
    symbol: self.read_string(),
  }
}

///|
fn @bytecodec.ByteReader::read_runtime_value_kind(
  self : @bytecodec.ByteReader,
) -> @lane_runtime.RuntimeValueKind raise {
  let offset = self.offset()
  match self.read_u8() {
    0x00 => Unit
    0x01 => Bool
    0x02 => I64
    0x03 => F64
    0x04 => String
    0x05 => Opaque
    0x06 => F32
    tag => invalid_binary_tag(offset~, domain="runtime value kind", tag~)
  }
}
