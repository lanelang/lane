///|
let artifact_binary_version = 1

///|
let artifact_binary_kind_interface = 1

///|
let artifact_binary_kind_object = 2

///|
let artifact_binary_kind_program = 3

///|
priv struct BinaryArtifactText {
  kind : Int
  text : String
}

///|
fn artifact_binary_magic() -> Bytes {
  Bytes::from_array([b'L', b'A', b'N', b'E', b'A', b'R', b'T', b'\x00'])
}

///|
pub fn artifact_binary_to_text(bytes : Bytes) -> Result[String, String] {
  match decode_binary_artifact_text(bytes, subject="Lane") {
    Ok(decoded) =>
      match decoded.kind {
        kind if kind == artifact_binary_kind_interface =>
          match parse_module_interface_artifact_text(decoded.text) {
            Ok(_) => Ok(decoded.text)
            Err(message) => Err(message)
          }
        kind if kind == artifact_binary_kind_object =>
          match parse_module_object_artifact_text(decoded.text) {
            Ok(_) => Ok(decoded.text)
            Err(message) => Err(message)
          }
        kind if kind == artifact_binary_kind_program =>
          match parse_linked_program_artifact_text(decoded.text) {
            Ok(_) => Ok(decoded.text)
            Err(message) => Err(message)
          }
        kind =>
          Err("unknown artifact binary kind \{artifact_binary_kind_name(kind)}")
      }
    Err(message) => Err(message)
  }
}

///|
pub fn artifact_binary_to_inspect_text(bytes : Bytes) -> Result[String, String] {
  match decode_binary_artifact_text(bytes, subject="Lane") {
    Ok(decoded) =>
      match decoded.kind {
        kind if kind == artifact_binary_kind_interface =>
          match parse_module_interface_artifact_text(decoded.text) {
            Ok(artifact) =>
              Ok(module_interface_artifact_to_inspect_text(artifact))
            Err(message) => Err(message)
          }
        kind if kind == artifact_binary_kind_object =>
          match parse_module_object_artifact_text(decoded.text) {
            Ok(artifact) => Ok(module_object_artifact_to_inspect_text(artifact))
            Err(message) => Err(message)
          }
        kind if kind == artifact_binary_kind_program =>
          match parse_linked_program_artifact_text(decoded.text) {
            Ok(artifact) =>
              Ok(linked_program_artifact_to_inspect_text(artifact))
            Err(message) => Err(message)
          }
        kind =>
          Err("unknown artifact binary kind \{artifact_binary_kind_name(kind)}")
      }
    Err(message) => Err(message)
  }
}

///|
pub fn module_interface_artifact_to_binary(
  artifact : ModuleInterfaceArtifact,
) -> Bytes {
  artifact_text_to_binary(
    artifact_binary_kind_interface,
    module_interface_artifact_to_text(artifact),
  )
}

///|
pub fn parse_module_interface_artifact_binary(
  bytes : Bytes,
) -> Result[ModuleInterfaceArtifact, String] {
  match
    binary_artifact_text(
      bytes,
      expected_kind=artifact_binary_kind_interface,
      expected_name="interface",
    ) {
    Ok(text) => parse_module_interface_artifact_text(text)
    Err(message) => Err(message)
  }
}

///|
pub fn module_object_artifact_to_binary(
  artifact : ModuleObjectArtifact,
) -> Bytes {
  artifact_text_to_binary(
    artifact_binary_kind_object,
    module_object_artifact_to_text(artifact),
  )
}

///|
pub fn parse_module_object_artifact_binary(
  bytes : Bytes,
) -> Result[ModuleObjectArtifact, String] {
  match
    binary_artifact_text(
      bytes,
      expected_kind=artifact_binary_kind_object,
      expected_name="object",
    ) {
    Ok(text) => parse_module_object_artifact_text(text)
    Err(message) => Err(message)
  }
}

///|
pub fn linked_program_artifact_to_binary(
  artifact : LinkedProgramArtifact,
) -> Bytes {
  artifact_text_to_binary(
    artifact_binary_kind_program,
    linked_program_artifact_to_text(artifact),
  )
}

///|
pub fn parse_linked_program_artifact_binary(
  bytes : Bytes,
) -> Result[LinkedProgramArtifact, String] {
  match
    binary_artifact_text(
      bytes,
      expected_kind=artifact_binary_kind_program,
      expected_name="program",
    ) {
    Ok(text) => parse_linked_program_artifact_text(text)
    Err(message) => Err(message)
  }
}

///|
fn artifact_text_to_binary(kind : Int, text : String) -> Bytes {
  let payload = @utf8.encode(text)
  let output = artifact_binary_magic().to_array()
  output.push(artifact_binary_version.to_byte())
  output.push(kind.to_byte())
  push_u32_le(output, payload.length())
  for byte in payload {
    output.push(byte)
  }
  Bytes::from_array(output)
}

///|
fn binary_artifact_text(
  bytes : Bytes,
  expected_kind~ : Int,
  expected_name~ : String,
) -> Result[String, String] {
  match decode_binary_artifact_text(bytes, subject=expected_name) {
    Ok(decoded) =>
      if decoded.kind == expected_kind {
        Ok(decoded.text)
      } else {
        Err(
          "wrong artifact binary kind: expected \{expected_name}, got \{artifact_binary_kind_name(decoded.kind)}",
        )
      }
    Err(message) => Err(message)
  }
}

///|
fn decode_binary_artifact_text(
  bytes : Bytes,
  subject~ : String,
) -> Result[BinaryArtifactText, String] {
  let magic = artifact_binary_magic()
  let min_size = magic.length() + 6
  if bytes.length() < min_size {
    return Err("invalid \{subject} artifact binary: file is too short")
  }
  for index in 0..<magic.length() {
    if bytes[index] != magic[index] {
      return Err(
        "invalid \{subject} artifact binary: expected Lane artifact binary magic",
      )
    }
  }
  let version_offset = magic.length()
  let version = bytes[version_offset].to_int()
  if version != artifact_binary_version {
    return Err("unsupported \{subject} artifact binary version \{version}")
  }
  let kind = bytes[version_offset + 1].to_int()
  let length_offset = version_offset + 2
  let payload_length = read_u32_le(bytes, length_offset)
  let payload_offset = length_offset + 4
  if bytes.length() != payload_offset + payload_length {
    return Err(
      "invalid \{subject} artifact binary: payload length does not match file size",
    )
  }
  let payload = []
  for index in payload_offset..<bytes.length() {
    payload.push(bytes[index])
  }
  let text = @utf8.decode(Bytes::from_array(payload)) catch {
    _ =>
      return Err(
        "invalid \{subject} artifact binary: payload is not valid UTF-8 artifact text",
      )
  }
  Ok({ kind, text })
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
fn push_u32_le(output : Array[Byte], value : Int) -> Unit {
  output.push((value & 0xFF).to_byte())
  output.push(((value >> 8) & 0xFF).to_byte())
  output.push(((value >> 16) & 0xFF).to_byte())
  output.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn read_u32_le(bytes : Bytes, offset : Int) -> Int {
  bytes[offset].to_int() |
  (bytes[offset + 1].to_int() << 8) |
  (bytes[offset + 2].to_int() << 16) |
  (bytes[offset + 3].to_int() << 24)
}
