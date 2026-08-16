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
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::empty(),
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
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::empty(),
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
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::empty(),
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
test "linked tree shaking remains deterministic for many modules and symbols" {
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
    (module_count * values_per_module, 0, true),
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
    (["Provider", "Importer"], value_count * 2, value_count, true),
  )
}

///|
fn linked_term_names(program : @buslane.Program) -> Array[String] {
  let names = []
  let push_name = fn(prefix : String, value : @buslane.ValueId) {
    guard program.metadata.value_info(value) is Some(info) else { return }
    names.push(prefix + info.name.occurrence)
  }
  for term in program.terms {
    match term {
      Let(value, _) => push_name("let ", value)
      LetRec(bindings) =>
        for binding in bindings {
          push_name("letrec ", binding.id)
        }
      External(value) => push_name("external ", value)
    }
  }
  names
}

///|
fn test_entry(
  module_path_text : String,
  name : String,
  value : @buslane.ValueId,
) -> @buslane_lowering.BuslaneEntry {
  { module_path_text, name, value, type_: Primitive(I64) }
}

///|
test "linked tree shaking retains exports entries externals and metadata" {
  let provider_metadata = @buslane.MetadataRegistry()
  let effect = provider_metadata.define_effect("Runtime", [])
  let signal = provider_metadata.define_operation(
    "signal",
    effect,
    [],
    [],
    Primitive(Unit),
  )
  let helper = provider_metadata.define_value("helper", Value, Primitive(I64))
  let api = provider_metadata.define_value("api", Value, Primitive(I64))
  let provider_dead = provider_metadata.define_value(
    "provider_dead",
    Value,
    Primitive(I64),
  )
  let add = provider_metadata.define_value(
    "add",
    External,
    Function([Primitive(I64), Primitive(I64)], Primitive(I64), Empty),
  )
  let host_log = provider_metadata.define_value(
    "host_log",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let provider : LinkModuleObject = {
    ..test_link_object("Provider", [], 0),
    metadata: provider_metadata,
    terms: [
      Let(helper, Literal(I64(1L))),
      Let(api, Ref(helper)),
      Let(provider_dead, Literal(I64(2L))),
      External(add),
      External(host_log),
    ],
    externals: {
      builtins: [
        @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
          add,
          I64Add,
          Function([Primitive(I64), Primitive(I64)], Primitive(I64), Empty),
        ),
      ],
      runtime_imports: [
        {
          value: host_log,
          symbol: "host_log",
          signature: { parameters: [String], result: Unit },
          type_: Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
        },
      ],
    },
    exports: [
      { name: "api", reference: Value(api) },
      { name: "Runtime", reference: Effect(effect) },
      { name: "signal", reference: Operation(signal) },
    ],
  }
  let root_metadata = @buslane.MetadataRegistry()
  let imported_api = root_metadata.define_value(
    "imported_api",
    External,
    Primitive(I64),
  )
  let main = root_metadata.define_value("main", Value, Primitive(I64))
  let root_dead = root_metadata.define_value("root_dead", Value, Primitive(I64))
  let root : LinkModuleObject = {
    ..test_link_object("Root", ["Provider"], 0),
    metadata: root_metadata,
    terms: [Let(main, Ref(imported_api)), Let(root_dead, Literal(I64(3L)))],
    entries: [test_entry("Root", "main", main)],
    imports: [
      {
        module_path_text: "Provider",
        name: "api",
        fingerprint: module_fingerprint("Provider"),
        reference: Value(imported_api),
      },
    ],
  }
  let result = link_reachable_modules([root, provider], "Root")
  assert_eq(result.diagnostics, [])
  guard result.program is Some(linked) else { abort("expected linked program") }
  debug_inspect(
    (
      linked.module_path_texts,
      linked_term_names(linked.program),
      linked.entries.map(entry => (entry.module_path_text, entry.name)),
      linked.externals.builtins.map(builtin => builtin.intrinsic()),
      linked.externals.runtime_imports.map(import_ => import_.symbol),
      linked.program.metadata.effects.map(info => info.name.occurrence),
      linked.program.metadata.operations.map(info => info.name.occurrence),
      @buslane.verify_program(linked.program).is_ok(),
    ),
    content=(
      #|(
      #|  ["Provider", "Root"],
      #|  [
      #|    "let helper",
      #|    "let api",
      #|    "external add",
      #|    "external host_log",
      #|    "let main",
      #|  ],
      #|  [("Root", "main")],
      #|  [I64Add],
      #|  ["host_log"],
      #|  ["Runtime"],
      #|  ["signal"],
      #|  true,
      #|)
    ),
  )
}

///|
test "linked entry policy determines whole-program retention roots" {
  let dependency_metadata = @buslane.MetadataRegistry()
  let helper = dependency_metadata.define_value(
    "dependency_helper",
    Value,
    Primitive(I64),
  )
  let dependency_entry = dependency_metadata.define_value(
    "dependency_entry",
    Value,
    Primitive(I64),
  )
  let dependency : LinkModuleObject = {
    ..test_link_object("Dependency", [], 0),
    metadata: dependency_metadata,
    terms: [Let(helper, Literal(I64(1L))), Let(dependency_entry, Ref(helper))],
    entries: [test_entry("Dependency", "run", dependency_entry)],
  }
  let root_metadata = @buslane.MetadataRegistry()
  let root_entry = root_metadata.define_value(
    "root_entry",
    Value,
    Primitive(I64),
  )
  let root : LinkModuleObject = {
    ..test_link_object("Root", ["Dependency"], 0),
    metadata: root_metadata,
    terms: [Let(root_entry, Literal(I64(0L)))],
    entries: [test_entry("Root", "run", root_entry)],
  }
  let reachable = link_reachable_modules([root, dependency], "Root")
  let complete = link_modules([root, dependency])
  guard reachable.program is Some(reachable) else {
    abort("expected reachable linked program")
  }
  guard complete.program is Some(complete) else {
    abort("expected complete linked program")
  }
  assert_eq(
    (linked_term_names(reachable.program), linked_term_names(complete.program)),
    (
      ["let root_entry"],
      ["let dependency_helper", "let dependency_entry", "let root_entry"],
    ),
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
