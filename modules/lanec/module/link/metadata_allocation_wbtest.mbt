///|
fn allocation_test_link_object(
  module_path_text : String,
) -> ValidatedLinkModuleObject raise @buslane.MetadataAllocationError {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(Unit))
  {
    object: {
      module_path_text,
      interface: None,
      interface_fingerprint: { value: "interface:\{module_path_text}" },
      canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::empty(),
      program: { metadata, terms: [Let(value, Literal(Unit))] },
      externals: { builtins: [], runtime_imports: [] },
      entries: [],
      exports: [],
      imports: [],
      fingerprint: { value: "module:\{module_path_text}" },
      object_fingerprint_valid: true,
      imported_interface_fingerprints: [],
    },
  }
}

///|
test "linker reports allocation failure without a partial linked program" {
  let remapper = BuslaneLinker::BuslaneLinker()
  remapper.metadata.name_allocator = Exhausted
  let result = link_ordered_modules_with_remapper(
    remapper,
    [allocation_test_link_object("Main")],
    QualifiedEntries,
    None,
  )
  assert_eq(result, {
    program: None,
    diagnostics: [
      {
        source_id: None,
        message: "internal compiler error while linking",
        span: None,
        severity: Error,
        code: Some("E4999"),
        labels: [],
        notes: [
          "the linker exhausted its metadata identity space: MetadataNameExhausted",
        ],
        helps: ["report this compiler defect with the input module artifacts"],
        facts: [],
        suggestions: [],
      },
    ],
  })
}
