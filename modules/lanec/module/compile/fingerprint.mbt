///|
fn imported_environment_fingerprints(
  imported : @module_interface.ImportedEnvironment,
) -> Array[@artifact_core.ImportedInterfaceFingerprint] {
  imported.modules.map(fn(interface) {
    {
      module_path_text: interface.module_path,
      fingerprint: interface_fingerprint(interface),
    }
  })
}

///|
pub fn module_fingerprint(
  interface : @module_interface.ModuleInterface,
  imported : Array[@artifact_core.ImportedInterfaceFingerprint],
) -> @artifact_core.CompilationFingerprint {
  module_fingerprint_from_interface_fingerprint(
    interface_fingerprint(interface),
    imported,
  )
}

///|
fn module_fingerprint_from_interface_fingerprint(
  interface_fingerprint : @artifact_core.CompilationFingerprint,
  imported : Array[@artifact_core.ImportedInterfaceFingerprint],
) -> @artifact_core.CompilationFingerprint {
  let writer = @bytecodec.ByteWriter::new()
  @artifact_core.write_compilation_fingerprint(writer, interface_fingerprint)
  @artifact_core.write_imported_interface_fingerprints(writer, imported)
  fingerprint_hash_bytes("lane-module-fingerprint-v2", writer.to_bytes())
}

///|
pub fn module_object_fingerprint(
  module_fingerprint : @artifact_core.CompilationFingerprint,
  interface_fingerprint : @artifact_core.CompilationFingerprint,
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
  externals : @buslane_lowering.BuslaneExternalMap,
  entries : Array[@buslane_lowering.BuslaneEntry],
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  imports : Array[@artifact_core.ModuleImportedReference],
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ],
) -> @artifact_core.CompilationFingerprint {
  fingerprint_hash_bytes(
    "lane-object-fingerprint-v2",
    module_object_fingerprint_payload_bytes(
      module_fingerprint, interface_fingerprint, metadata, terms, externals, entries,
      exports, imports, imported_interface_fingerprints,
    ),
  )
}

///|
fn module_object_fingerprint_payload_bytes(
  module_fingerprint : @artifact_core.CompilationFingerprint,
  interface_fingerprint : @artifact_core.CompilationFingerprint,
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
  externals : @buslane_lowering.BuslaneExternalMap,
  entries : Array[@buslane_lowering.BuslaneEntry],
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  imports : Array[@artifact_core.ModuleImportedReference],
  imported_interface_fingerprints : Array[
    @artifact_core.ImportedInterfaceFingerprint,
  ],
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  @artifact_core.write_compilation_fingerprint(writer, module_fingerprint)
  @artifact_core.write_compilation_fingerprint(writer, interface_fingerprint)
  @artifact_core.write_buslane_program_section(writer, { metadata, terms })
  @artifact_core.write_externals(writer, externals)
  @artifact_core.write_entries(writer, entries)
  @artifact_core.write_exports(writer, exports)
  @artifact_core.write_imports(writer, imports)
  @artifact_core.write_imported_interface_fingerprints(
    writer, imported_interface_fingerprints,
  )
  writer.to_bytes()
}

///|
pub fn interface_fingerprint(
  interface : @module_interface.ModuleInterface,
) -> @artifact_core.CompilationFingerprint {
  match interface_fingerprint_result(interface) {
    Ok(fingerprint) => fingerprint
    Err(message) => abort("invalid module interface: " + message)
  }
}

///|
fn interface_fingerprint_result(
  interface : @module_interface.ModuleInterface,
) -> Result[@artifact_core.CompilationFingerprint, String] {
  match interface.semantic_fingerprint() {
    Ok(fingerprint) => Ok({ value: fingerprint.value })
    Err(message) => Err(message)
  }
}

///|
fn fingerprint_hash_bytes(
  tag : String,
  payload : Bytes,
) -> @artifact_core.CompilationFingerprint {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_string(tag)
  writer.write_raw_bytes(payload)
  {
    value: "sha256:\{@crypto.bytes_to_hex_string(@crypto.sha256(writer.to_bytes()))}",
  }
}
