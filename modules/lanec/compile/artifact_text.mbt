///|
priv suberror ArtifactTextError {
  InvalidBuslaneBlock(String)
  ExpectedArtifactEntry(String)
  InvalidArtifactValue(String)
  UnknownArtifactValue(String)
  UnsupportedArtifactSchema(String)
  UnexpectedArtifactEntry(String)
} derive(Debug)

///|
priv struct ArtifactTextReader {
  entries : Array[@artifact_parser.ArtifactEntry]
  mut index : Int
}

///|
priv struct ArtifactTextWriter {
  lines : Array[String]
}

///|
pub fn module_interface_artifact_to_text(
  artifact : ModuleInterfaceArtifact,
) -> String {
  let writer = ArtifactTextWriter::start("interface")
  writer.write_module_interface_artifact(artifact)
  writer.finish()
}

///|
pub fn parse_module_interface_artifact_text(
  text : String,
) -> Result[ModuleInterfaceArtifact, String] {
  try {
    let document = match @artifact_parser.parse_text(text) {
      Ok(document) => document
      Err(message) => return Err(message)
    }
    if document.kind != "interface" {
      return Err(artifact_kind_error("interface", document.kind))
    }
    let reader = ArtifactTextReader::{ entries: document.entries, index: 0 }
    let artifact = reader.read_module_interface_artifact()
    reader.expect_end()
    Ok(artifact)
  } catch {
    error => Err(artifact_text_error(error))
  }
}

///|
pub fn module_object_artifact_to_text(
  artifact : ModuleObjectArtifact,
) -> String {
  let writer = ArtifactTextWriter::start("object")
  writer.write_module_object_artifact(artifact)
  writer.finish()
}

///|
pub fn parse_module_object_artifact_text(
  text : String,
) -> Result[ModuleObjectArtifact, String] {
  try {
    let document = match @artifact_parser.parse_text(text) {
      Ok(document) => document
      Err(message) => return Err(message)
    }
    if document.kind != "object" {
      return Err(artifact_kind_error("object", document.kind))
    }
    let reader = ArtifactTextReader::{ entries: document.entries, index: 0 }
    let artifact = reader.read_module_object_artifact()
    reader.expect_end()
    Ok(artifact)
  } catch {
    error => Err(artifact_text_error(error))
  }
}

///|
pub fn linked_program_artifact_to_text(
  artifact : LinkedProgramArtifact,
) -> String {
  let writer = ArtifactTextWriter::start("program")
  writer.write_linked_program_artifact(artifact)
  writer.finish()
}

///|
pub fn parse_linked_program_artifact_text(
  text : String,
) -> Result[LinkedProgramArtifact, String] {
  try {
    let document = match @artifact_parser.parse_text(text) {
      Ok(document) => document
      Err(message) => return Err(message)
    }
    if document.kind != "program" {
      return Err(artifact_kind_error("program", document.kind))
    }
    let reader = ArtifactTextReader::{ entries: document.entries, index: 0 }
    let artifact = reader.read_linked_program_artifact()
    reader.expect_end()
    Ok(artifact)
  } catch {
    error => Err(artifact_text_error(error))
  }
}

///|
fn[T] fail_invalid_buslane_block(message : String) -> T raise ArtifactTextError {
  raise InvalidBuslaneBlock(message)
}

///|
fn[T] fail_expected(message : String) -> T raise ArtifactTextError {
  raise ExpectedArtifactEntry(message)
}

///|
fn[T] fail_invalid(message : String) -> T raise ArtifactTextError {
  raise InvalidArtifactValue(message)
}

///|
fn[T] fail_unknown(message : String) -> T raise ArtifactTextError {
  raise UnknownArtifactValue(message)
}

///|
fn[T] fail_unsupported(message : String) -> T raise ArtifactTextError {
  raise UnsupportedArtifactSchema(message)
}

///|
fn[T] fail_unexpected(message : String) -> T raise ArtifactTextError {
  raise UnexpectedArtifactEntry(message)
}

///|
fn artifact_kind_error(expected : String, actual : String) -> String {
  artifact_error(
    "E5005",
    "wrong artifact kind",
    "expected `\{expected}` artifact, got `\{actual}`",
    "different Lane commands consume different artifact kinds",
    artifact_kind_help(expected),
  )
}

///|
fn artifact_kind_help(expected : String) -> String {
  if expected == "interface" {
    "pass an `.lmi` file produced by `lane compile --emit-interface`"
  } else if expected == "object" {
    "pass an `.lmo` file produced by `lane compile --emit-object`"
  } else {
    "pass an `.lbp` file produced by `lane link`"
  }
}

///|
fn artifact_text_error(error : ArtifactTextError) -> String {
  match error {
    InvalidBuslaneBlock(message) =>
      artifact_error(
        "E5010", "invalid embedded Buslane block", message, "module object and linked program artifacts embed Buslane text blocks",
        "regenerate the artifact from Lane source instead of editing the Buslane block",
      )
    ExpectedArtifactEntry(message) =>
      artifact_error(
        "E5011", "missing or misplaced artifact field", message, "the artifact reader expected a specific field, tag, or block at this position",
        "regenerate the artifact with the current Lane compiler",
      )
    InvalidArtifactValue(message) =>
      artifact_error(
        "E5012", "invalid artifact field value", message, "one field has the right name but a value that cannot be decoded",
        "regenerate the artifact or restore the field value emitted by Lane",
      )
    UnknownArtifactValue(message) =>
      artifact_error(
        "E5013", "unknown artifact field value", message, "the artifact contains a tag or enum value not understood by this compiler",
        "recompile with the current Lane compiler and avoid mixing artifact versions",
      )
    UnsupportedArtifactSchema(message) =>
      artifact_error(
        "E5016", "unsupported artifact schema", message, "this artifact was produced by an incompatible Lane compiler or old schema",
        "regenerate the artifact with the current Lane compiler",
      )
    UnexpectedArtifactEntry(message) =>
      artifact_error(
        "E5014", "unexpected artifact entry", message, "the artifact contains extra data or ended while a required entry was being read",
        "regenerate the artifact instead of editing it by hand",
      )
  }
}

///|
fn artifact_error(
  code : String,
  title : String,
  label : String,
  note : String,
  help : String,
) -> String {
  "error[\{code}]: \{title}\n  = label: \{label}\n  = note: \{note}\n  = help: \{help}"
}

///|
fn ArtifactTextReader::expect_end(
  self : ArtifactTextReader,
) -> Unit raise ArtifactTextError {
  if self.index != self.entries.length() {
    fail_unexpected("unexpected trailing artifact entry")
  }
}

///|
fn ArtifactTextReader::expect_tag(
  self : ArtifactTextReader,
  tag : String,
) -> Unit raise ArtifactTextError {
  match self.take_entry() {
    Tag(actual) if actual == tag => ()
    _ => fail_expected("expected tag \{tag}")
  }
}

///|
fn ArtifactTextReader::expect_atom(
  self : ArtifactTextReader,
  tag : String,
) -> String raise ArtifactTextError {
  match self.take_entry() {
    Value(actual, Atom(value)) if actual == tag => value
    _ => fail_expected("expected atom field \{tag}")
  }
}

///|
fn ArtifactTextReader::expect_string(
  self : ArtifactTextReader,
  tag : String,
) -> String raise ArtifactTextError {
  match self.take_entry() {
    Value(actual, Text(value)) if actual == tag => value
    _ => fail_expected("expected string field \{tag}")
  }
}

///|
fn ArtifactTextReader::expect_int(
  self : ArtifactTextReader,
  tag : String,
) -> Int raise ArtifactTextError {
  let text = self.expect_atom(tag)
  @string.parse_int(text, base=10) catch {
    _ => fail_invalid("invalid integer for \{tag}: \{text}")
  }
}

///|
fn ArtifactTextReader::expect_bool(
  self : ArtifactTextReader,
  tag : String,
) -> Bool raise ArtifactTextError {
  match self.expect_atom(tag) {
    "true" => true
    "false" => false
    value => fail_invalid("invalid boolean for \{tag}: \{value}")
  }
}

///|
fn ArtifactTextWriter::start(kind : String) -> ArtifactTextWriter {
  { lines: ["lane-artifact-text-v1 \{kind} {"] }
}

///|
fn ArtifactTextWriter::finish(self : ArtifactTextWriter) -> String {
  self.lines.push("}")
  "\{self.lines.join("\n")}\n"
}

///|
fn ArtifactTextWriter::write_atom(
  self : ArtifactTextWriter,
  tag : String,
  atom : String,
) -> Unit {
  self.lines.push("  \{tag}: \{atom};")
}

///|
fn ArtifactTextWriter::write_string(
  self : ArtifactTextWriter,
  tag : String,
  value : String,
) -> Unit {
  self.lines.push("  \{tag}: \{quote_string(value)};")
}

///|
fn ArtifactTextWriter::write_int(
  self : ArtifactTextWriter,
  tag : String,
  value : Int,
) -> Unit {
  self.write_atom(tag, "\{value}")
}

///|
fn ArtifactTextWriter::write_bool(
  self : ArtifactTextWriter,
  tag : String,
  value : Bool,
) -> Unit {
  self.write_atom(tag, if value { "true" } else { "false" })
}

///|
fn ArtifactTextWriter::write_tag(
  self : ArtifactTextWriter,
  tag : String,
) -> Unit {
  self.lines.push("  \{tag};")
}

///|
fn ArtifactTextReader::take_entry(
  self : ArtifactTextReader,
) -> @artifact_parser.ArtifactEntry raise ArtifactTextError {
  guard self.index < self.entries.length() else {
    fail_unexpected("unexpected end of artifact")
  }
  let entry = self.entries[self.index]
  self.index = self.index + 1
  entry
}

///|
fn ArtifactTextWriter::write_buslane_program_block(
  self : ArtifactTextWriter,
  program : @buslane.Program,
) -> Unit {
  let text = @text.CanonicalTextWriter::CanonicalTextWriter().write_program(
    program,
  )
  for line in text.split("\n") {
    self.lines.push("  \{line}")
  }
}

///|
fn ArtifactTextReader::read_buslane_program_block(
  self : ArtifactTextReader,
) -> @buslane.Program raise ArtifactTextError {
  match self.take_entry() {
    Block("buslane", text) =>
      match @text.parse_program_text(text) {
        Ok(program) => program
        Err(message) => fail_invalid_buslane_block(message)
      }
    Block(name, _) => fail_expected("expected buslane block, got block \{name}")
    Tag(name) => fail_expected("expected buslane block, got tag \{name}")
    Value(name, _) => fail_expected("expected buslane block, got field \{name}")
  }
}

///|
fn quote_string(value : String) -> String {
  let output = [b'"']
  for byte in @utf8.encode(value) {
    match byte {
      b'"' => {
        output.push(b'\\')
        output.push(b'"')
      }
      b'\\' => {
        output.push(b'\\')
        output.push(b'\\')
      }
      b'\n' => {
        output.push(b'\\')
        output.push(b'n')
      }
      b'\r' => {
        output.push(b'\\')
        output.push(b'r')
      }
      b'\t' => {
        output.push(b'\\')
        output.push(b't')
      }
      _ => output.push(byte)
    }
  }
  output.push(b'"')
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => "\"\""
  }
}

///|

///|
fn ArtifactTextWriter::write_module_interface_artifact(
  self : ArtifactTextWriter,
  artifact : ModuleInterfaceArtifact,
) -> Unit {
  self.write_int("schema_version", artifact.schema_version)
  self.write_string("module_path_text", artifact.module_path_text)
  self.write_module_interface(artifact.interface)
  self.write_compilation_fingerprint(
    "interface_fingerprint",
    artifact.interface_fingerprint,
  )
  self.write_compilation_fingerprint(
    "module_fingerprint",
    artifact.module_fingerprint,
  )
  self.write_imported_interface_fingerprints(
    artifact.imported_interface_fingerprints,
  )
}

///|
fn ArtifactTextReader::read_module_interface_artifact(
  self : ArtifactTextReader,
) -> ModuleInterfaceArtifact raise ArtifactTextError {
  let schema_version = self.expect_int("schema_version")
  let module_path_text = self.expect_string("module_path_text")
  let interface = self.read_module_interface()
  let interface_fingerprint = self.read_compilation_fingerprint(
    "interface_fingerprint",
  )
  let module_fingerprint = self.read_compilation_fingerprint(
    "module_fingerprint",
  )
  let imported_interface_fingerprints = self.read_imported_interface_fingerprints()
  {
    schema_version,
    module_path_text,
    interface,
    interface_fingerprint,
    module_fingerprint,
    imported_interface_fingerprints,
  }
}

///|
fn ArtifactTextWriter::write_module_object_artifact(
  self : ArtifactTextWriter,
  artifact : ModuleObjectArtifact,
) -> Unit {
  self.write_int("schema_version", artifact.schema_version)
  self.write_string("module_path_text", artifact.module_path_text)
  self.write_module_interface(artifact.interface)
  self.write_compilation_fingerprint(
    "interface_fingerprint",
    artifact.interface_fingerprint,
  )
  self.write_buslane_program_block({
    metadata: artifact.metadata,
    terms: artifact.terms,
  })
  self.write_externals(artifact.externals)
  self.write_entries(artifact.entries)
  self.write_exports(artifact.exports)
  self.write_imports(artifact.imports)
  self.write_compilation_fingerprint(
    "module_fingerprint",
    artifact.module_fingerprint,
  )
  self.write_compilation_fingerprint(
    "object_fingerprint",
    artifact.object_fingerprint,
  )
  self.write_imported_interface_fingerprints(
    artifact.imported_interface_fingerprints,
  )
}

///|
fn ArtifactTextReader::read_module_object_artifact(
  self : ArtifactTextReader,
) -> ModuleObjectArtifact raise ArtifactTextError {
  let schema_version = self.expect_int("schema_version")
  let module_path_text = self.expect_string("module_path_text")
  if schema_version != module_object_artifact_schema_version {
    fail_unsupported(
      "unsupported module object artifact schema \{schema_version} for \{module_path_text}",
    )
  }
  let interface = self.read_module_interface()
  let interface_fingerprint = self.read_compilation_fingerprint(
    "interface_fingerprint",
  )
  let program = self.read_buslane_program_block()
  let metadata = program.metadata
  let terms = program.terms
  let externals = self.read_externals()
  let entries = self.read_entries()
  let exports = self.read_exports()
  let imports = self.read_imports()
  let module_fingerprint = self.read_compilation_fingerprint(
    "module_fingerprint",
  )
  let object_fingerprint = self.read_compilation_fingerprint(
    "object_fingerprint",
  )
  let imported_interface_fingerprints = self.read_imported_interface_fingerprints()
  {
    schema_version,
    module_path_text,
    interface,
    interface_fingerprint,
    metadata,
    terms,
    externals,
    entries,
    exports,
    imports,
    module_fingerprint,
    object_fingerprint,
    imported_interface_fingerprints,
  }
}

///|
fn ArtifactTextWriter::write_linked_program_artifact(
  self : ArtifactTextWriter,
  artifact : LinkedProgramArtifact,
) -> Unit {
  self.write_int("schema_version", artifact.schema_version)
  self.write_int("module_path_texts", artifact.module_path_texts.length())
  for module_path_text in artifact.module_path_texts {
    self.write_string("module_path_text", module_path_text)
  }
  self.write_buslane_program_block(artifact.program)
  self.write_externals(artifact.externals)
  self.write_entries(artifact.entries)
  self.write_runtime_effect_operations(artifact.runtime_effect_operations)
}

///|
fn ArtifactTextReader::read_linked_program_artifact(
  self : ArtifactTextReader,
) -> LinkedProgramArtifact raise ArtifactTextError {
  let schema_version = self.expect_int("schema_version")
  let module_path_texts = []
  for _ in 0..<self.expect_int("module_path_texts") {
    module_path_texts.push(self.expect_string("module_path_text"))
  }
  let program = self.read_buslane_program_block()
  let externals = self.read_externals()
  let entries = self.read_entries()
  let runtime_effect_operations = self.read_runtime_effect_operations()
  {
    schema_version,
    module_path_texts,
    program,
    externals,
    entries,
    runtime_effect_operations,
  }
}

///|
fn ArtifactTextWriter::write_compilation_fingerprint(
  self : ArtifactTextWriter,
  tag : String,
  fingerprint : CompilationFingerprint,
) -> Unit {
  self.write_string(tag, fingerprint.value)
}

///|
fn ArtifactTextReader::read_compilation_fingerprint(
  self : ArtifactTextReader,
  tag : String,
) -> CompilationFingerprint raise ArtifactTextError {
  { value: self.expect_string(tag) }
}

///|
fn ArtifactTextWriter::write_imported_interface_fingerprints(
  self : ArtifactTextWriter,
  fingerprints : Array[ImportedInterfaceFingerprint],
) -> Unit {
  self.write_int("imported_interface_fingerprints", fingerprints.length())
  for fingerprint in fingerprints {
    self.write_string("imported_module_path", fingerprint.module_path_text)
    self.write_compilation_fingerprint(
      "imported_fingerprint",
      fingerprint.fingerprint,
    )
  }
}

///|
fn ArtifactTextReader::read_imported_interface_fingerprints(
  self : ArtifactTextReader,
) -> Array[ImportedInterfaceFingerprint] raise ArtifactTextError {
  let count = self.expect_int("imported_interface_fingerprints")
  let fingerprints = []
  for _ in 0..<count {
    let module_path_text = self.expect_string("imported_module_path")
    let fingerprint = self.read_compilation_fingerprint("imported_fingerprint")
    fingerprints.push({ module_path_text, fingerprint })
  }
  fingerprints
}

///|
fn ArtifactTextWriter::write_module_interface(
  self : ArtifactTextWriter,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  self.write_string("interface.module_path", interface.module_path)
  self.write_int("interface.types", interface.types.length())
  for type_ in interface.types {
    self.write_module_interface_type(type_)
  }
  self.write_int("interface.effects", interface.effects.length())
  for effect in interface.effects {
    self.write_interface_effect(effect)
  }
  self.write_int("interface.type_aliases", interface.type_aliases.length())
  for alias_ in interface.type_aliases {
    self.write_type_alias(alias_)
  }
  self.write_int("interface.values", interface.values.length())
  for value in interface.values {
    self.write_interface_value(value)
  }
  self.write_int(
    "interface.optimization_hints",
    interface.optimization_hints.length(),
  )
  for hint in interface.optimization_hints {
    self.write_string("optimization_hint.name", hint.name)
  }
}

///|
fn ArtifactTextReader::read_module_interface(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterface raise ArtifactTextError {
  let module_path = self.expect_string("interface.module_path")
  let types = []
  for _ in 0..<self.expect_int("interface.types") {
    types.push(self.read_module_interface_type())
  }
  let effects = []
  for _ in 0..<self.expect_int("interface.effects") {
    effects.push(self.read_interface_effect())
  }
  let type_aliases = []
  for _ in 0..<self.expect_int("interface.type_aliases") {
    type_aliases.push(self.read_type_alias())
  }
  let values = []
  for _ in 0..<self.expect_int("interface.values") {
    values.push(self.read_interface_value())
  }
  let optimization_hints : Array[@module_interface.OptimizationHint] = []
  for _ in 0..<self.expect_int("interface.optimization_hints") {
    optimization_hints.push({
      name: self.expect_string("optimization_hint.name"),
    })
  }
  { module_path, types, effects, type_aliases, values, optimization_hints }
}

///|
fn ArtifactTextWriter::write_module_interface_type(
  self : ArtifactTextWriter,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit {
  match type_ {
    Struct(declaration) => {
      self.write_tag("interface_type.struct")
      self.write_type_symbol_id("type.symbol", declaration.symbol)
      self.write_string("type.name", declaration.name)
      self.write_type_parameters(
        "type.type_parameters",
        declaration.type_parameters,
      )
      self.write_int("type.type_members", declaration.type_members.length())
      for member_ in declaration.type_members {
        self.write_type_member(member_)
      }
      self.write_int("type.fields", declaration.fields.length())
      for field in declaration.fields {
        self.write_field(field)
      }
      self.write_source_span("type.loc", declaration.loc)
    }
    Enum(declaration) => {
      self.write_tag("interface_type.enum")
      self.write_type_symbol_id("type.symbol", declaration.symbol)
      self.write_string("type.name", declaration.name)
      self.write_type_parameters(
        "type.type_parameters",
        declaration.type_parameters,
      )
      self.write_int("type.variants", declaration.variants.length())
      for variant in declaration.variants {
        self.write_variant(variant)
      }
      self.write_source_span("type.loc", declaration.loc)
    }
  }
}

///|
fn ArtifactTextReader::read_module_interface_type(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceType raise ArtifactTextError {
  let tag = self.next_tag()
  match tag {
    "interface_type.struct" => {
      let symbol = self.read_type_symbol_id("type.symbol")
      let name = self.expect_string("type.name")
      let type_parameters = self.read_type_parameters("type.type_parameters")
      let type_members = []
      for _ in 0..<self.expect_int("type.type_members") {
        type_members.push(self.read_type_member())
      }
      let fields = []
      for _ in 0..<self.expect_int("type.fields") {
        fields.push(self.read_field())
      }
      let loc = self.read_source_span("type.loc")
      Struct({ symbol, name, type_parameters, type_members, fields, loc })
    }
    "interface_type.enum" => {
      let symbol = self.read_type_symbol_id("type.symbol")
      let name = self.expect_string("type.name")
      let type_parameters = self.read_type_parameters("type.type_parameters")
      let variants = []
      for _ in 0..<self.expect_int("type.variants") {
        variants.push(self.read_variant())
      }
      let loc = self.read_source_span("type.loc")
      Enum({ symbol, name, type_parameters, variants, loc })
    }
    _ => fail_unknown("unknown interface type tag \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_interface_effect(
  self : ArtifactTextWriter,
  effect : @module_interface.ModuleInterfaceEffect,
) -> Unit {
  self.write_effect_symbol_id("effect.symbol", effect.symbol)
  self.write_string("effect.name", effect.name)
  self.write_type_parameters("effect.type_parameters", effect.type_parameters)
  self.write_int("effect.operations", effect.operations.length())
  for operation in effect.operations {
    self.write_interface_operation(operation)
  }
  self.write_source_span("effect.loc", effect.loc)
}

///|
fn ArtifactTextReader::read_interface_effect(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceEffect raise ArtifactTextError {
  let symbol = self.read_effect_symbol_id("effect.symbol")
  let name = self.expect_string("effect.name")
  let type_parameters = self.read_type_parameters("effect.type_parameters")
  let operations = []
  for _ in 0..<self.expect_int("effect.operations") {
    operations.push(self.read_interface_operation())
  }
  let loc = self.read_source_span("effect.loc")
  { symbol, name, type_parameters, operations, loc }
}

///|
fn ArtifactTextWriter::write_interface_operation(
  self : ArtifactTextWriter,
  operation : @module_interface.ModuleInterfaceOperation,
) -> Unit {
  self.write_operation_symbol_id("operation.symbol", operation.symbol)
  self.write_string("operation.name", operation.name)
  self.write_int("operation.index", operation.index)
  self.write_type_parameters(
    "operation.type_parameters",
    operation.type_parameters,
  )
  self.write_lane_types("operation.payload", operation.payload)
  self.write_lane_type(operation.result)
  self.write_source_span("operation.loc", operation.loc)
}

///|
fn ArtifactTextReader::read_interface_operation(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceOperation raise ArtifactTextError {
  let symbol = self.read_operation_symbol_id("operation.symbol")
  let name = self.expect_string("operation.name")
  let index = self.expect_int("operation.index")
  let type_parameters = self.read_type_parameters("operation.type_parameters")
  let payload = self.read_lane_types("operation.payload")
  let result = self.read_lane_type()
  let loc = self.read_source_span("operation.loc")
  { symbol, name, index, type_parameters, payload, result, loc }
}

///|
fn ArtifactTextReader::next_tag(
  self : ArtifactTextReader,
) -> String raise ArtifactTextError {
  match self.take_entry() {
    Tag(name) => name
    Value(name, _) =>
      fail_expected("expected tag-only entry, got value field \{name}")
    Block(name, _) =>
      fail_expected("expected tag-only entry, got block \{name}")
  }
}

///|
fn ArtifactTextWriter::write_type_member(
  self : ArtifactTextWriter,
  member_ : @module_interface.ModuleInterfaceTypeMember,
) -> Unit {
  self.write_type_member_symbol_id("type_member.symbol", member_.symbol)
  self.write_type_parameter(
    "type_member.type_parameter",
    member_.type_parameter,
  )
  self.write_string("type_member.name", member_.name)
  self.write_lane_kind("type_member.kind", member_.kind)
  self.write_int("type_member.index", member_.index)
  self.write_source_span("type_member.loc", member_.loc)
}

///|
fn ArtifactTextReader::read_type_member(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceTypeMember raise ArtifactTextError {
  let symbol = self.read_type_member_symbol_id("type_member.symbol")
  let type_parameter = self.read_type_parameter("type_member.type_parameter")
  let name = self.expect_string("type_member.name")
  let kind = self.read_lane_kind("type_member.kind")
  let index = self.expect_int("type_member.index")
  let loc = self.read_source_span("type_member.loc")
  { symbol, type_parameter, name, kind, index, loc }
}

///|
fn ArtifactTextWriter::write_field(
  self : ArtifactTextWriter,
  field : @module_interface.ModuleInterfaceField,
) -> Unit {
  self.write_field_symbol_id("field.symbol", field.symbol)
  self.write_bool("field.is_offered", field.is_offered)
  self.write_string("field.name", field.name)
  self.write_int("field.index", field.index)
  self.write_lane_type(field.type_)
  self.write_source_span("field.loc", field.loc)
}

///|
fn ArtifactTextReader::read_field(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceField raise ArtifactTextError {
  let symbol = self.read_field_symbol_id("field.symbol")
  let is_offered = self.expect_bool("field.is_offered")
  let name = self.expect_string("field.name")
  let index = self.expect_int("field.index")
  let type_ = self.read_lane_type()
  let loc = self.read_source_span("field.loc")
  { symbol, is_offered, name, index, type_, loc }
}

///|
fn ArtifactTextWriter::write_variant(
  self : ArtifactTextWriter,
  variant : @module_interface.ModuleInterfaceVariant,
) -> Unit {
  self.write_variant_symbol_id("variant.symbol", variant.symbol)
  self.write_string("variant.name", variant.name)
  self.write_int("variant.index", variant.index)
  self.write_type_parameters("variant.type_parameters", variant.type_parameters)
  self.write_lane_types("variant.payload", variant.payload)
  self.write_source_span("variant.loc", variant.loc)
}

///|
fn ArtifactTextReader::read_variant(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceVariant raise ArtifactTextError {
  let symbol = self.read_variant_symbol_id("variant.symbol")
  let name = self.expect_string("variant.name")
  let index = self.expect_int("variant.index")
  let type_parameters = self.read_type_parameters("variant.type_parameters")
  let payload = self.read_lane_types("variant.payload")
  let loc = self.read_source_span("variant.loc")
  { symbol, name, index, type_parameters, payload, loc }
}

///|
fn ArtifactTextWriter::write_type_alias(
  self : ArtifactTextWriter,
  alias_ : @module_interface.ModuleInterfaceTypeAlias,
) -> Unit {
  self.write_string("type_alias.name", alias_.name)
  self.write_type_parameters(
    "type_alias.type_parameters",
    alias_.type_parameters,
  )
  self.write_type_alias_body(alias_.body)
  self.write_lane_kind("type_alias.kind", alias_.kind)
  self.write_source_span("type_alias.loc", alias_.loc)
}

///|
fn ArtifactTextWriter::write_type_alias_body(
  self : ArtifactTextWriter,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> Unit {
  match body {
    TypeBody(type_) => {
      self.write_tag("type_alias.body.type")
      self.write_lane_type(type_)
    }
    EffectBody(effect) => {
      self.write_tag("type_alias.body.effect")
      self.write_lane_effect(effect)
    }
  }
}

///|
fn ArtifactTextReader::read_type_alias(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceTypeAlias raise ArtifactTextError {
  let name = self.expect_string("type_alias.name")
  let type_parameters = self.read_type_parameters("type_alias.type_parameters")
  let body = self.read_type_alias_body()
  let kind = self.read_lane_kind("type_alias.kind")
  let loc = self.read_source_span("type_alias.loc")
  { name, type_parameters, body, kind, loc }
}

///|
fn ArtifactTextReader::read_type_alias_body(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceTypeAliasBody raise ArtifactTextError {
  match self.next_tag() {
    "type_alias.body.type" => TypeBody(self.read_lane_type())
    "type_alias.body.effect" => EffectBody(self.read_lane_effect())
    tag => fail_unknown("unknown type alias body tag \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_interface_value(
  self : ArtifactTextWriter,
  value : @module_interface.ModuleInterfaceValue,
) -> Unit {
  self.write_value_symbol_id("value.symbol", value.symbol)
  self.write_interface_value_kind(value.kind)
  self.write_string("value.name", value.name)
  self.write_lane_type(value.type_)
  match value.parameters {
    None => self.write_tag("value.parameters.none")
    Some(parameters) => {
      self.write_int("value.parameters", parameters.length())
      for parameter in parameters {
        self.write_value_parameter(parameter)
      }
    }
  }
  self.write_source_span("value.loc", value.loc)
}

///|
fn ArtifactTextReader::read_interface_value(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceValue raise ArtifactTextError {
  let symbol = self.read_value_symbol_id("value.symbol")
  let kind = self.read_interface_value_kind()
  let name = self.expect_string("value.name")
  let type_ = self.read_lane_type()
  let parameters = match self.peek_tag() {
    "value.parameters.none" => {
      self.expect_tag("value.parameters.none")
      None
    }
    "value.parameters" => {
      let items = []
      for _ in 0..<self.expect_int("value.parameters") {
        items.push(self.read_value_parameter())
      }
      Some(items)
    }
    tag => fail_expected("expected value parameters, got \{tag}")
  }
  let loc = self.read_source_span("value.loc")
  { symbol, kind, name, type_, parameters, loc }
}

///|
fn ArtifactTextReader::peek_tag(
  self : ArtifactTextReader,
) -> String raise ArtifactTextError {
  guard self.index < self.entries.length() else {
    fail_expected("expected tag, reached end of artifact")
  }
  match self.entries[self.index] {
    Tag(name) => name
    Value(name, _) => name
    Block(name, _) => name
  }
}

///|
fn ArtifactTextWriter::write_interface_value_kind(
  self : ArtifactTextWriter,
  kind : @module_interface.ModuleInterfaceValueKind,
) -> Unit {
  self.write_atom(
    "value.kind",
    match kind {
      Function => "function"
      Let => "let"
      Offer => "offer"
    },
  )
}

///|
fn ArtifactTextReader::read_interface_value_kind(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceValueKind raise ArtifactTextError {
  match self.expect_atom("value.kind") {
    "function" => Function
    "let" => Let
    "offer" => Offer
    value => fail_unknown("unknown interface value kind \{value}")
  }
}

///|
fn ArtifactTextWriter::write_value_parameter(
  self : ArtifactTextWriter,
  parameter : @module_interface.ModuleInterfaceValueParameter,
) -> Unit {
  self.write_value_symbol_id("value_parameter.symbol", parameter.symbol)
  self.write_bool("value_parameter.is_auto", parameter.is_auto)
  self.write_bool("value_parameter.is_offered", parameter.is_offered)
  self.write_string("value_parameter.name", parameter.name)
  self.write_lane_type(parameter.type_)
  self.write_source_span("value_parameter.loc", parameter.loc)
}

///|
fn ArtifactTextReader::read_value_parameter(
  self : ArtifactTextReader,
) -> @module_interface.ModuleInterfaceValueParameter raise ArtifactTextError {
  let symbol = self.read_value_symbol_id("value_parameter.symbol")
  let is_auto = self.expect_bool("value_parameter.is_auto")
  let is_offered = self.expect_bool("value_parameter.is_offered")
  let name = self.expect_string("value_parameter.name")
  let type_ = self.read_lane_type()
  let loc = self.read_source_span("value_parameter.loc")
  { symbol, is_auto, is_offered, name, type_, loc }
}

///|
fn ArtifactTextWriter::write_lane_kind(
  self : ArtifactTextWriter,
  tag : String,
  kind : @types.Kind,
) -> Unit {
  match kind {
    Type => self.write_atom(tag, "type")
    Effect => self.write_atom(tag, "effect")
    Function(parameters, result) => {
      self.write_atom(tag, "function")
      self.write_int("\{tag}.parameters", parameters.length())
      for parameter in parameters {
        self.write_lane_kind("\{tag}.parameter", parameter)
      }
      self.write_lane_kind("\{tag}.result", result)
    }
  }
}

///|
fn ArtifactTextReader::read_lane_kind(
  self : ArtifactTextReader,
  tag : String,
) -> @types.Kind raise ArtifactTextError {
  match self.expect_atom(tag) {
    "type" => Type
    "effect" => Effect
    "function" => {
      let parameters = []
      for _ in 0..<self.expect_int("\{tag}.parameters") {
        parameters.push(self.read_lane_kind("\{tag}.parameter"))
      }
      let result = self.read_lane_kind("\{tag}.result")
      Function(parameters, result)
    }
    value => fail_unknown("unknown Lane kind \{value}")
  }
}

///|
fn ArtifactTextWriter::write_type_parameters(
  self : ArtifactTextWriter,
  tag : String,
  parameters : Array[@types.TypeParameter],
) -> Unit {
  self.write_int(tag, parameters.length())
  for parameter in parameters {
    self.write_type_parameter("\{tag}.item", parameter)
  }
}

///|
fn ArtifactTextReader::read_type_parameters(
  self : ArtifactTextReader,
  tag : String,
) -> Array[@types.TypeParameter] raise ArtifactTextError {
  let parameters = []
  for _ in 0..<self.expect_int(tag) {
    parameters.push(self.read_type_parameter("\{tag}.item"))
  }
  parameters
}

///|
fn ArtifactTextWriter::write_type_parameter(
  self : ArtifactTextWriter,
  tag : String,
  parameter : @types.TypeParameter,
) -> Unit {
  self.write_type_parameter_id("\{tag}.id", parameter.id)
  self.write_string("\{tag}.name", parameter.name)
  self.write_lane_kind("\{tag}.kind", parameter.kind)
}

///|
fn ArtifactTextReader::read_type_parameter(
  self : ArtifactTextReader,
  tag : String,
) -> @types.TypeParameter raise ArtifactTextError {
  let id = self.read_type_parameter_id("\{tag}.id")
  let name = self.expect_string("\{tag}.name")
  let kind = self.read_lane_kind("\{tag}.kind")
  { id, name, kind }
}

///|
fn ArtifactTextWriter::write_lane_types(
  self : ArtifactTextWriter,
  tag : String,
  types : Array[@types.Type],
) -> Unit {
  self.write_int(tag, types.length())
  for type_ in types {
    self.write_lane_type(type_)
  }
}

///|
fn ArtifactTextReader::read_lane_types(
  self : ArtifactTextReader,
  tag : String,
) -> Array[@types.Type] raise ArtifactTextError {
  let types = []
  for _ in 0..<self.expect_int(tag) {
    types.push(self.read_lane_type())
  }
  types
}

///|
fn ArtifactTextWriter::write_lane_type(
  self : ArtifactTextWriter,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Error => self.write_tag("lane_type.error")
    Primitive(primitive) => {
      self.write_tag("lane_type.primitive")
      self.write_lane_primitive_type(primitive)
    }
    Constructor(symbol) => {
      self.write_tag("lane_type.constructor")
      self.write_type_symbol_id("lane_type.constructor.symbol", symbol)
    }
    Apply(callee, arguments) => {
      self.write_tag("lane_type.apply")
      self.write_lane_type(callee)
      self.write_lane_types("lane_type.apply.arguments", arguments)
    }
    TypeLambda(parameters, body) => {
      self.write_tag("lane_type.type_lambda")
      self.write_type_parameters("lane_type.binders", parameters)
      self.write_lane_type(body)
    }
    Parameter(id) => {
      self.write_tag("lane_type.parameter")
      self.write_type_parameter_id("lane_type.parameter.id", id)
    }
    Function(parameters, result, effect) => {
      self.write_tag("lane_type.function")
      self.write_lane_types("lane_type.function.parameters", parameters)
      self.write_lane_type(result)
      self.write_lane_effect(effect)
    }
    Forall(parameters, body) => {
      self.write_tag("lane_type.forall")
      self.write_type_parameters("lane_type.binders", parameters)
      self.write_lane_type(body)
    }
  }
}

///|
fn ArtifactTextReader::read_lane_type(
  self : ArtifactTextReader,
) -> @types.Type raise ArtifactTextError {
  match self.next_tag() {
    "lane_type.error" => Error
    "lane_type.primitive" => Primitive(self.read_lane_primitive_type())
    "lane_type.constructor" =>
      Constructor(self.read_type_symbol_id("lane_type.constructor.symbol"))
    "lane_type.apply" => {
      let callee = self.read_lane_type()
      let arguments = self.read_lane_types("lane_type.apply.arguments")
      Apply(callee, arguments)
    }
    "lane_type.type_lambda" => {
      let parameters = self.read_type_parameters("lane_type.binders")
      let body = self.read_lane_type()
      TypeLambda(parameters, body)
    }
    "lane_type.parameter" =>
      Parameter(self.read_type_parameter_id("lane_type.parameter.id"))
    "lane_type.function" => {
      let parameters = self.read_lane_types("lane_type.function.parameters")
      let result = self.read_lane_type()
      let effect = self.read_lane_effect()
      Function(parameters, result, effect)
    }
    "lane_type.forall" => {
      let parameters = self.read_type_parameters("lane_type.binders")
      let body = self.read_lane_type()
      Forall(parameters, body)
    }
    tag => fail_unknown("unknown Lane type tag \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_lane_effect(
  self : ArtifactTextWriter,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty => self.write_tag("lane_effect.empty")
    Singleton(symbol, arguments) => {
      self.write_tag("lane_effect.singleton")
      self.write_effect_symbol_id("lane_effect.singleton.symbol", symbol)
      self.write_lane_types("lane_effect.singleton.arguments", arguments)
    }
    Parameter(id) => {
      self.write_tag("lane_effect.parameter")
      self.write_type_parameter_id("lane_effect.parameter.id", id)
    }
    Union(effects) => {
      self.write_tag("lane_effect.union")
      self.write_int("lane_effect.union.items", effects.length())
      for effect in effects {
        self.write_lane_effect(effect)
      }
    }
  }
}

///|
fn ArtifactTextReader::read_lane_effect(
  self : ArtifactTextReader,
) -> @types.Effect raise ArtifactTextError {
  match self.next_tag() {
    "lane_effect.empty" => Empty
    "lane_effect.singleton" => {
      let symbol = self.read_effect_symbol_id("lane_effect.singleton.symbol")
      let arguments = self.read_lane_types("lane_effect.singleton.arguments")
      Singleton(symbol, arguments)
    }
    "lane_effect.parameter" =>
      Parameter(self.read_type_parameter_id("lane_effect.parameter.id"))
    "lane_effect.union" => {
      let effects = []
      for _ in 0..<self.expect_int("lane_effect.union.items") {
        effects.push(self.read_lane_effect())
      }
      Union(effects)
    }
    tag => fail_unknown("unknown Lane effect tag \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_lane_primitive_type(
  self : ArtifactTextWriter,
  primitive : @types.PrimitiveType,
) -> Unit {
  self.write_atom(
    "lane_primitive",
    match primitive {
      Int => "int"
      Bool => "bool"
      String => "string"
      Unit => "unit"
    },
  )
}

///|
fn ArtifactTextReader::read_lane_primitive_type(
  self : ArtifactTextReader,
) -> @types.PrimitiveType raise ArtifactTextError {
  match self.expect_atom("lane_primitive") {
    "int" => Int
    "bool" => Bool
    "string" => String
    "unit" => Unit
    value => fail_unknown("unknown Lane primitive type \{value}")
  }
}

///|
fn ArtifactTextWriter::write_source_span(
  self : ArtifactTextWriter,
  tag : String,
  span : @basic.SourceSpan,
) -> Unit {
  self.write_int("\{tag}.start_offset", span.start_offset)
  self.write_int("\{tag}.end_offset", span.end_offset)
  self.write_int("\{tag}.start_line", span.start_line)
  self.write_int("\{tag}.start_column", span.start_column)
  self.write_int("\{tag}.end_line", span.end_line)
  self.write_int("\{tag}.end_column", span.end_column)
}

///|
fn ArtifactTextReader::read_source_span(
  self : ArtifactTextReader,
  tag : String,
) -> @basic.SourceSpan raise ArtifactTextError {
  {
    start_offset: self.expect_int("\{tag}.start_offset"),
    end_offset: self.expect_int("\{tag}.end_offset"),
    start_line: self.expect_int("\{tag}.start_line"),
    start_column: self.expect_int("\{tag}.start_column"),
    end_line: self.expect_int("\{tag}.end_line"),
    end_column: self.expect_int("\{tag}.end_column"),
  }
}

///|
fn ArtifactTextWriter::write_type_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.TypeSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_type_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.TypeSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_type_parameter_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.TypeParameterId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_type_parameter_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.TypeParameterId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_type_member_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.TypeMemberSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_type_member_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.TypeMemberSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_value_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.ValueSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_value_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.ValueSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_field_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.FieldSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_field_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.FieldSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_variant_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.VariantSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_variant_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.VariantSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_effect_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.EffectSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_effect_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.EffectSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_operation_symbol_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @symbol.OperationSymbolId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_operation_symbol_id(
  self : ArtifactTextReader,
  tag : String,
) -> @symbol.OperationSymbolId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_buslane_type(
  self : ArtifactTextWriter,
  tag : String,
  type_ : @buslane.Type,
) -> Unit {
  self.write_string(
    tag,
    @text.CanonicalTextWriter::CanonicalTextWriter().write_type(type_),
  )
}

///|
fn ArtifactTextReader::read_buslane_type(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.Type raise ArtifactTextError {
  let text = self.expect_string(tag)
  match @text.parse_type_text(text) {
    Ok(type_) => type_
    Err(message) => fail_invalid("invalid Buslane type for \{tag}: \{message}")
  }
}

///|
fn ArtifactTextWriter::write_buslane_value_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.ValueId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_buslane_value_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.ValueId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_operation_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.OperationId,
) -> Unit {
  self.write_int(tag, id.index)
}

///|
fn ArtifactTextReader::read_operation_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.OperationId raise ArtifactTextError {
  { index: self.expect_int(tag) }
}

///|
fn ArtifactTextWriter::write_optional_type_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.TypeId?,
) -> Unit {
  match id {
    None => self.write_atom(tag, "none")
    Some(id) => self.write_atom(tag, "some_\{id.index}")
  }
}

///|
fn ArtifactTextReader::read_optional_type_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.TypeId? raise ArtifactTextError {
  let atom = self.expect_atom(tag)
  if atom == "none" {
    None
  } else if atom.has_prefix("some_") {
    let value = atom.unsafe_substring(start=5, end=atom.length())
    Some({ index: parse_atom_int(tag, value) })
  } else {
    fail_invalid("invalid optional type id for \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_optional_data_con_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.DataConId?,
) -> Unit {
  match id {
    None => self.write_atom(tag, "none")
    Some(id) => self.write_atom(tag, "some_\{id.index}")
  }
}

///|
fn ArtifactTextReader::read_optional_data_con_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.DataConId? raise ArtifactTextError {
  let atom = self.expect_atom(tag)
  if atom == "none" {
    None
  } else if atom.has_prefix("some_") {
    let value = atom.unsafe_substring(start=5, end=atom.length())
    Some({ index: parse_atom_int(tag, value) })
  } else {
    fail_invalid("invalid optional data constructor id for \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_optional_effect_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.EffectId?,
) -> Unit {
  match id {
    None => self.write_atom(tag, "none")
    Some(id) => self.write_atom(tag, "some_\{id.index}")
  }
}

///|
fn ArtifactTextReader::read_optional_effect_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.EffectId? raise ArtifactTextError {
  let atom = self.expect_atom(tag)
  if atom == "none" {
    None
  } else if atom.has_prefix("some_") {
    let value = atom.unsafe_substring(start=5, end=atom.length())
    Some({ index: parse_atom_int(tag, value) })
  } else {
    fail_invalid("invalid optional effect id for \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_optional_operation_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.OperationId?,
) -> Unit {
  match id {
    None => self.write_atom(tag, "none")
    Some(id) => self.write_atom(tag, "some_\{id.index}")
  }
}

///|
fn ArtifactTextReader::read_optional_operation_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.OperationId? raise ArtifactTextError {
  let atom = self.expect_atom(tag)
  if atom == "none" {
    None
  } else if atom.has_prefix("some_") {
    let value = atom.unsafe_substring(start=5, end=atom.length())
    Some({ index: parse_atom_int(tag, value) })
  } else {
    fail_invalid("invalid optional operation id for \{tag}")
  }
}

///|
fn ArtifactTextWriter::write_optional_value_id(
  self : ArtifactTextWriter,
  tag : String,
  id : @buslane.ValueId?,
) -> Unit {
  match id {
    None => self.write_atom(tag, "none")
    Some(id) => self.write_atom(tag, "some_\{id.index}")
  }
}

///|
fn ArtifactTextReader::read_optional_value_id(
  self : ArtifactTextReader,
  tag : String,
) -> @buslane.ValueId? raise ArtifactTextError {
  let atom = self.expect_atom(tag)
  if atom == "none" {
    None
  } else if atom.has_prefix("some_") {
    let value = atom.unsafe_substring(start=5, end=atom.length())
    Some({ index: parse_atom_int(tag, value) })
  } else {
    fail_invalid("invalid optional value id for \{tag}")
  }
}

///|
fn parse_atom_int(tag : String, value : String) -> Int raise ArtifactTextError {
  @string.parse_int(value, base=10) catch {
    _ => fail_invalid("invalid integer for \{tag}: \{value}")
  }
}

///|
fn ArtifactTextWriter::write_externals(
  self : ArtifactTextWriter,
  externals : @elaborate.BuslaneExternalMap,
) -> Unit {
  self.write_int("externals.builtins", externals.builtins.length())
  for external in externals.builtins {
    self.write_buslane_value_id("external.value", external.value)
    self.write_string("external.name", external.name)
    self.write_buslane_type("external.type", external.type_)
  }
}

///|
fn ArtifactTextReader::read_externals(
  self : ArtifactTextReader,
) -> @elaborate.BuslaneExternalMap raise ArtifactTextError {
  let builtins : Array[@elaborate.BuslaneBuiltinExternal] = []
  for _ in 0..<self.expect_int("externals.builtins") {
    let value = self.read_buslane_value_id("external.value")
    let name = self.expect_string("external.name")
    let type_ = self.read_buslane_type("external.type")
    builtins.push({ value, name, type_ })
  }
  { builtins, }
}

///|
fn ArtifactTextWriter::write_entries(
  self : ArtifactTextWriter,
  entries : Array[@elaborate.BuslaneEntry],
) -> Unit {
  self.write_int("entries", entries.length())
  for entry in entries {
    self.write_string("entry.name", entry.name)
    self.write_buslane_value_id("entry.value", entry.value)
    self.write_buslane_type("entry.type", entry.type_)
  }
}

///|
fn ArtifactTextReader::read_entries(
  self : ArtifactTextReader,
) -> Array[@elaborate.BuslaneEntry] raise ArtifactTextError {
  let entries : Array[@elaborate.BuslaneEntry] = []
  for _ in 0..<self.expect_int("entries") {
    let name = self.expect_string("entry.name")
    let value = self.read_buslane_value_id("entry.value")
    let type_ = self.read_buslane_type("entry.type")
    entries.push({ name, value, type_ })
  }
  entries
}

///|
fn ArtifactTextWriter::write_runtime_effect_operations(
  self : ArtifactTextWriter,
  operations : Array[LinkedRuntimeEffectOperation],
) -> Unit {
  self.write_int("runtime_effect_operations", operations.length())
  for operation in operations {
    self.write_string(
      "runtime_effect_operation.module_path_text",
      operation.module_path_text,
    )
    self.write_string(
      "runtime_effect_operation.effect_name",
      operation.effect_name,
    )
    self.write_string(
      "runtime_effect_operation.operation_name",
      operation.operation_name,
    )
    self.write_lane_types("runtime_effect_operation.payload", operation.payload)
    self.write_lane_type(operation.result)
    self.write_operation_id(
      "runtime_effect_operation.operation",
      operation.operation,
    )
  }
}

///|
fn ArtifactTextReader::read_runtime_effect_operations(
  self : ArtifactTextReader,
) -> Array[LinkedRuntimeEffectOperation] raise ArtifactTextError {
  let operations : Array[LinkedRuntimeEffectOperation] = []
  for _ in 0..<self.expect_int("runtime_effect_operations") {
    let module_path_text = self.expect_string(
      "runtime_effect_operation.module_path_text",
    )
    let effect_name = self.expect_string("runtime_effect_operation.effect_name")
    let operation_name = self.expect_string(
      "runtime_effect_operation.operation_name",
    )
    let payload = self.read_lane_types("runtime_effect_operation.payload")
    let result = self.read_lane_type()
    let operation = self.read_operation_id("runtime_effect_operation.operation")
    operations.push({
      module_path_text,
      effect_name,
      operation_name,
      payload,
      result,
      operation,
    })
  }
  operations
}

///|
fn ArtifactTextWriter::write_exports(
  self : ArtifactTextWriter,
  exports : Array[@elaborate.BuslaneModuleExport],
) -> Unit {
  self.write_int("exports", exports.length())
  for export_ in exports {
    self.write_export_kind("export.kind", export_.kind)
    self.write_string("export.name", export_.name)
    self.write_optional_type_id("export.type_id", export_.type_id)
    self.write_optional_data_con_id(
      "export.data_constructor",
      export_.data_constructor,
    )
    self.write_optional_effect_id("export.effect_id", export_.effect_id)
    self.write_optional_operation_id("export.operation", export_.operation)
    self.write_optional_value_id("export.value", export_.value)
  }
}

///|
fn ArtifactTextReader::read_exports(
  self : ArtifactTextReader,
) -> Array[@elaborate.BuslaneModuleExport] raise ArtifactTextError {
  let exports : Array[@elaborate.BuslaneModuleExport] = []
  for _ in 0..<self.expect_int("exports") {
    let kind = self.read_export_kind("export.kind")
    let name = self.expect_string("export.name")
    let type_id = self.read_optional_type_id("export.type_id")
    let data_constructor = self.read_optional_data_con_id(
      "export.data_constructor",
    )
    let effect_id = self.read_optional_effect_id("export.effect_id")
    let operation = self.read_optional_operation_id("export.operation")
    let value = self.read_optional_value_id("export.value")
    exports.push({
      kind,
      name,
      type_id,
      data_constructor,
      effect_id,
      operation,
      value,
    })
  }
  exports
}

///|
fn ArtifactTextWriter::write_imports(
  self : ArtifactTextWriter,
  imports : Array[ModuleImportedReference],
) -> Unit {
  self.write_int("imports", imports.length())
  for import_ in imports {
    self.write_string("import.module_path_text", import_.module_path_text)
    self.write_export_kind("import.kind", import_.kind)
    self.write_string("import.name", import_.name)
    self.write_compilation_fingerprint(
      "import.fingerprint",
      import_.fingerprint,
    )
    self.write_optional_type_id("import.type_id", import_.type_id)
    self.write_optional_data_con_id(
      "import.data_constructor",
      import_.data_constructor,
    )
    self.write_optional_effect_id("import.effect_id", import_.effect_id)
    self.write_optional_operation_id("import.operation", import_.operation)
    self.write_optional_value_id("import.value", import_.value)
  }
}

///|
fn ArtifactTextReader::read_imports(
  self : ArtifactTextReader,
) -> Array[ModuleImportedReference] raise ArtifactTextError {
  let imports : Array[ModuleImportedReference] = []
  for _ in 0..<self.expect_int("imports") {
    let module_path_text = self.expect_string("import.module_path_text")
    let kind = self.read_export_kind("import.kind")
    let name = self.expect_string("import.name")
    let fingerprint = self.read_compilation_fingerprint("import.fingerprint")
    let type_id = self.read_optional_type_id("import.type_id")
    let data_constructor = self.read_optional_data_con_id(
      "import.data_constructor",
    )
    let effect_id = self.read_optional_effect_id("import.effect_id")
    let operation = self.read_optional_operation_id("import.operation")
    let value = self.read_optional_value_id("import.value")
    imports.push({
      module_path_text,
      kind,
      name,
      fingerprint,
      type_id,
      data_constructor,
      effect_id,
      operation,
      value,
    })
  }
  imports
}

///|
fn ArtifactTextWriter::write_export_kind(
  self : ArtifactTextWriter,
  tag : String,
  kind : @elaborate.BuslaneModuleExportKind,
) -> Unit {
  self.write_atom(
    tag,
    match kind {
      Type => "type"
      DataConstructor => "data_constructor"
      Effect => "effect"
      Operation => "operation"
      FieldSelector => "field_selector"
      Value => "value"
    },
  )
}

///|
fn ArtifactTextReader::read_export_kind(
  self : ArtifactTextReader,
  tag : String,
) -> @elaborate.BuslaneModuleExportKind raise ArtifactTextError {
  match self.expect_atom(tag) {
    "type" => Type
    "data_constructor" => DataConstructor
    "effect" => Effect
    "operation" => Operation
    "field_selector" => FieldSelector
    "value" => Value
    value => fail_unknown("unknown export kind \{value}")
  }
}
