///|
pub fn imported_environment_fingerprints(
  imported : @module_interface.ModuleInterfaceCatalog,
) -> Array[@artifact_model.ImportedInterfaceFingerprint] {
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
  imported : Array[@artifact_model.ImportedInterfaceFingerprint],
) -> @artifact_model.CompilationFingerprint {
  module_fingerprint_from_interface_fingerprint(
    interface_fingerprint(interface),
    imported,
  )
}

///|
fn module_fingerprint_from_interface_fingerprint(
  interface_fingerprint : @artifact_model.CompilationFingerprint,
  imported : Array[@artifact_model.ImportedInterfaceFingerprint],
) -> @artifact_model.CompilationFingerprint {
  let writer = @bytecodec.ByteWriter::new()
  write_compilation_fingerprint(writer, interface_fingerprint)
  write_imported_interface_fingerprints(writer, imported)
  fingerprint_hash_bytes("lane-module-fingerprint-v2", writer.to_bytes())
}

///|
pub fn module_object_fingerprint(
  module_fingerprint : @artifact_model.CompilationFingerprint,
  interface_fingerprint : @artifact_model.CompilationFingerprint,
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
  externals : @buslane_lowering.BuslaneExternalMap,
  entries : Array[@buslane_lowering.BuslaneEntry],
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  imports : Array[@artifact_model.ModuleImportedReference],
  imported_interface_fingerprints : Array[
    @artifact_model.ImportedInterfaceFingerprint,
  ],
) -> @artifact_model.CompilationFingerprint {
  fingerprint_hash_bytes(
    "lane-object-fingerprint-v3",
    module_object_fingerprint_payload_bytes(
      module_fingerprint, interface_fingerprint, metadata, terms, externals, entries,
      exports, imports, imported_interface_fingerprints,
    ),
  )
}

///|
fn module_object_fingerprint_payload_bytes(
  module_fingerprint : @artifact_model.CompilationFingerprint,
  interface_fingerprint : @artifact_model.CompilationFingerprint,
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
  externals : @buslane_lowering.BuslaneExternalMap,
  entries : Array[@buslane_lowering.BuslaneEntry],
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  imports : Array[@artifact_model.ModuleImportedReference],
  imported_interface_fingerprints : Array[
    @artifact_model.ImportedInterfaceFingerprint,
  ],
) -> Bytes {
  let writer = @bytecodec.ByteWriter::new()
  write_compilation_fingerprint(writer, module_fingerprint)
  write_compilation_fingerprint(writer, interface_fingerprint)
  write_buslane_program_section(writer, { metadata, terms })
  write_externals(writer, externals)
  write_entries(writer, entries)
  write_exports(writer, exports)
  write_imports(writer, imports)
  write_imported_interface_fingerprints(writer, imported_interface_fingerprints)
  writer.to_bytes()
}

///|
pub fn interface_fingerprint(
  interface : @module_interface.ModuleInterface,
) -> @artifact_model.CompilationFingerprint {
  match interface_fingerprint_result(interface) {
    Ok(fingerprint) => fingerprint
    Err(message) => abort("invalid module interface: " + message)
  }
}

///|
fn interface_fingerprint_result(
  interface : @module_interface.ModuleInterface,
) -> Result[@artifact_model.CompilationFingerprint, String] {
  match interface.semantic_fingerprint_result() {
    Ok(fingerprint) => Ok({ value: fingerprint.value })
    Err(message) => Err(message)
  }
}

///|
fn fingerprint_hash_bytes(
  tag : String,
  payload : Bytes,
) -> @artifact_model.CompilationFingerprint {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_string(tag)
  writer.write_raw_bytes(payload)
  {
    value: "sha256:\{@crypto.bytes_to_hex_string(@crypto.sha256(writer.to_bytes()))}",
  }
}
