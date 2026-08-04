///|
fn module_fingerprint(path : String) -> @artifact_model.CompilationFingerprint {
  { value: "module:\{path}" }
}

///|
fn interface_fingerprint(
  path : String,
) -> @artifact_model.CompilationFingerprint {
  { value: "interface:\{path}" }
}

///|
fn test_link_object(
  path : String,
  imports : Array[String],
  value_count : Int,
) -> LinkModuleObject raise @buslane.MetadataAllocationError {
  let metadata = @buslane.MetadataRegistry()
  let terms : Array[@buslane.TopTerm] = []
  for index in 0..<value_count {
    let value = metadata.define_value("value_\{index}", Value, Primitive(I64))
    terms.push(Let(value, Literal(I64(0L))))
  }
  {
    module_path_text: path,
    interface: None,
    interface_fingerprint: interface_fingerprint(path),
    metadata,
    terms,
    externals: { builtins: [], runtime_imports: [] },
    entries: [],
    exports: [],
    imports: [],
    fingerprint: module_fingerprint(path),
    object_fingerprint_valid: true,
    imported_interface_fingerprints: imports.map(imported => {
      module_path_text: imported,
      fingerprint: interface_fingerprint(imported),
    }),
  }
}

///|
fn exported_value_modules(
  value_count : Int,
) -> Array[LinkModuleObject] raise @buslane.MetadataAllocationError {
  let provider_metadata = @buslane.MetadataRegistry()
  let provider_terms : Array[@buslane.TopTerm] = []
  let provider_exports : Array[@buslane_lowering.BuslaneModuleExport] = []
  let provider_fingerprint = module_fingerprint("Provider")
  for index in 0..<value_count {
    let value = provider_metadata.define_value(
      "value_\{index}",
      Value,
      Primitive(I64),
    )
    provider_terms.push(Let(value, Literal(I64(0L))))
    provider_exports.push({ name: "value_\{index}", reference: Value(value) })
  }
  let provider : LinkModuleObject = {
    module_path_text: "Provider",
    interface: None,
    interface_fingerprint: interface_fingerprint("Provider"),
    metadata: provider_metadata,
    terms: provider_terms,
    externals: { builtins: [], runtime_imports: [] },
    entries: [],
    exports: provider_exports,
    imports: [],
    fingerprint: provider_fingerprint,
    object_fingerprint_valid: true,
    imported_interface_fingerprints: [],
  }
  let importer_metadata = @buslane.MetadataRegistry()
  let imported_values = []
  let imports : Array[@artifact_model.ModuleImportedReference] = []
  for index in 0..<value_count {
    let imported = importer_metadata.define_value(
      "imported_\{index}",
      External,
      Primitive(I64),
    )
    imported_values.push(imported)
    imports.push({
      module_path_text: "Provider",
      name: "value_\{index}",
      fingerprint: provider_fingerprint,
      reference: Value(imported),
    })
  }
  let importer_terms : Array[@buslane.TopTerm] = []
  for index, imported in imported_values {
    let copied = importer_metadata.define_value(
      "copied_\{index}",
      Value,
      Primitive(I64),
    )
    importer_terms.push(Let(copied, Ref(imported)))
  }
  let importer : LinkModuleObject = {
    module_path_text: "Importer",
    interface: None,
    interface_fingerprint: interface_fingerprint("Importer"),
    metadata: importer_metadata,
    terms: importer_terms,
    externals: { builtins: [], runtime_imports: [] },
    entries: [],
    exports: [],
    imports,
    fingerprint: module_fingerprint("Importer"),
    object_fingerprint_valid: true,
    imported_interface_fingerprints: [
      {
        module_path_text: "Provider",
        fingerprint: interface_fingerprint("Provider"),
      },
    ],
  }
  [importer, provider]
}

///|
test "reachable linking remains deterministic for many modules and symbols" {
  let module_count = 48
  let values_per_module = 48
  let modules = []
  for index in 0..<module_count {
    let imports = if index + 1 < module_count {
      ["Module\{index + 1}"]
    } else {
      []
    }
    modules.push(test_link_object("Module\{index}", imports, values_per_module))
  }
  let reversed_modules = [
    for index in 0..<module_count => modules[module_count - index - 1]
  ]
  let forward = link_reachable_modules(modules, "Module0")
  let reversed = link_reachable_modules(reversed_modules, "Module0")
  assert_eq(forward, reversed)
  assert_eq(forward.diagnostics, [])
  guard forward.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(
    program.module_path_texts,
    [
      for index in 0..<module_count => "Module\{module_count - index - 1}"
    ],
  )
  assert_eq(
    (
      program.program.metadata.values.length(),
      program.program.terms.length(),
      @buslane.verify_program(program.program).is_ok(),
    ),
    (module_count * values_per_module, module_count * values_per_module, true),
  )
}

///|
test "symbol-rich imports reuse indexed provider exports" {
  let value_count = 512
  let result = link_reachable_modules(
    exported_value_modules(value_count),
    "Importer",
  )
  assert_eq(result.diagnostics, [])
  guard result.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(
    (
      program.module_path_texts,
      program.program.metadata.values.length(),
      program.program.terms.length(),
      @buslane.verify_program(program.program).is_ok(),
    ),
    (["Provider", "Importer"], value_count * 2, value_count * 2, true),
  )
}

///|
test "duplicate modules retain a structured linker diagnostic" {
  let result = link_modules([
    test_link_object("Duplicate", [], 0),
    test_link_object("Duplicate", [], 0),
    test_link_object("Duplicate", [], 0),
  ])
  debug_inspect(
    result,
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "duplicate compiled module `Duplicate`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4300"),
      #|      labels: [],
      #|      notes: ["linking requires one compiled module for each module name"],
      #|      helps: ["remove the duplicate module artifact"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "duplicate compiled module `Duplicate`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4300"),
      #|      labels: [],
      #|      notes: ["linking requires one compiled module for each module name"],
      #|      helps: ["remove the duplicate module artifact"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "import cycles retain a structured linker diagnostic" {
  let result = link_reachable_modules(
    [test_link_object("A", ["B"], 0), test_link_object("B", ["A"], 0)],
    "A",
  )
  debug_inspect(
    result,
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "import cycle involving `A`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4003"),
      #|      labels: [],
      #|      notes: ["cyclic module dependencies cannot be typechecked in a stable order"],
      #|      helps: ["move shared declarations into a separate module imported by both sides"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}
