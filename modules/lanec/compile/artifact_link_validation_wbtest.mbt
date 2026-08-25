///|
fn refingerprint_test_object(
  object : @artifact.ModuleObjectArtifact,
) -> @artifact.ModuleObjectArtifact {
  {
    ..object,
    object_fingerprint: @artifact.module_object_fingerprint(
      object.module_fingerprint,
      object.interface_fingerprint,
      object.canonical_basic_abi,
      object.metadata,
      object.terms,
      object.externals,
      object.entries,
      object.exports,
      object.imports,
      object.imported_interface_fingerprints,
    ),
  }
}

///|
fn compiled_test_object(
  source : String,
  library_sources? : Array[String] = [],
) -> @artifact.ModuleObjectArtifact {
  let compiled = compile_modules_for_test(source, library_sources)
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  for module_ in modules.modules {
    let object = module_.to_object_artifact()
    if object.module_path_text == modules.root_module_path_text {
      return object
    }
  }
  abort("expected compiled root module")
}

///|
test "builtin external contract rejects metadata signature drift" {
  let object = compiled_test_object(
    (
      #|module Basic.Data.Void
      #|pub enum Void {}
      #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
    ),
  )
  guard object.externals.builtins is [builtin] else {
    abort("expected one builtin external")
  }
  let metadata = object.metadata.snapshot()
  let value = builtin.value()
  let info = metadata.values[value.index]
  metadata.values[value.index] = { ..info, type_: Primitive(I64), }
  let malformed = refingerprint_test_object({ ..object, metadata, })
  debug_inspect(
    @artifact.link_module_object_artifacts([malformed]),
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Basic.Data.Void`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["builtin `%panic` does not match its canonical source contract; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "runtime import host signature is certified against metadata source type" {
  let object = compiled_test_object(
    (
      #|module Main
      #|pub let observe : (String) -> Unit ! Io = extern("observe")
    ),
  )
  guard object.externals.runtime_imports is [runtime_import] else {
    abort("expected one runtime import")
  }
  let malformed = refingerprint_test_object({
    ..object,
    externals: {
      ..object.externals,
      runtime_imports: [
        { ..runtime_import, signature: { parameters: [I64], result: Unit, }, },
      ],
    },
  })
  debug_inspect(
    @artifact.link_module_object_artifacts([malformed]),
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Main`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["runtime import `observe` host signature does not match its source type; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "linker consumes the certified canonical Basic runtime identity" {
  let object = compiled_test_object(
    (
      #|module Basic.Data.Void
      #|pub enum Void {}
      #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
    ),
  )
  let malformed = refingerprint_test_object({
    ..object,
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbiRuntimeContract::empty(),
  })
  debug_inspect(
    @artifact.link_module_object_artifacts([malformed]).diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: None,
      #|    message: "invalid module object `Basic.Data.Void`",
      #|    span: None,
      #|    severity: Error,
      #|    code: Some("E4208"),
      #|    labels: [],
      #|    notes: ["builtin `%panic` does not match its canonical source contract; module objects must be internally valid before identity remapping begins"],
      #|    helps: ["recompile the module object from valid Lane source"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "canonical Basic owner certifies the persisted Void shape" {
  let object = compiled_test_object(
    (
      #|module Basic.Data.Void
      #|pub enum Void {}
      #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
    ),
  )
  guard object.canonical_basic_abi.void_type() is Some(void_type) else {
    abort("expected the certified canonical Void identity")
  }
  let metadata = object.metadata.snapshot()
  let info = metadata.types[void_type.index]
  metadata.types[void_type.index] = { ..info, flavor: External, }
  let malformed = refingerprint_test_object({ ..object, metadata, })
  debug_inspect(
    @artifact.link_module_object_artifacts([malformed]).diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: None,
      #|    message: "invalid canonical Basic ABI in module object `Basic.Data.Void`",
      #|    span: None,
      #|    severity: Error,
      #|    code: Some("E4208"),
      #|    labels: [],
      #|    notes: [
      #|      "canonical Basic provider `Basic.Data.Void.Void` is invalid: the declaration must lower to an empty data type",
      #|      "module objects must carry the certified canonical Basic runtime contract before identity remapping begins",
      #|    ],
      #|    helps: ["recompile the module object from valid Lane source"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "object artifact validation rejects every unknown Buslane identity namespace" {
  let object = compiled_test_object(
    (
      #|module Invalid
      #|pub let value : I64 = 1
    ),
  )
  let metadata = object.metadata.snapshot()
  let terms = object.terms.copy()
  let unknown_type : @buslane.TypeId = { index: 1000, }
  let unknown_parameter : @buslane.TypeParameterId = { index: 1001, }
  let unknown_value : @buslane.ValueId = { index: 1002, }
  let unknown_constructor : @buslane.DataConId = { index: 1003, }
  let unknown_effect : @buslane.EffectId = { index: 1004, }
  let unknown_operation : @buslane.OperationId = { index: 1005, }
  ignore(
    metadata.define_value("unknown_type", Value, Constructor(unknown_type)),
  )
  ignore(
    metadata.define_value(
      "unknown_parameter",
      Value,
      Parameter(unknown_parameter),
    ),
  )
  ignore(
    metadata.define_value(
      "unknown_effect",
      Value,
      Function([], Primitive(I64), Singleton(unknown_effect, [])),
    ),
  )
  let constructed = metadata.define_value(
    "unknown_constructor",
    Value,
    Primitive(I64),
  )
  terms.push(
    Let(
      constructed,
      Construct({
        data_constructor: unknown_constructor,
        type_arguments: [],
        hidden_witnesses: [],
        payloads: [],
      }),
    ),
  )
  let performed = metadata.define_value(
    "unknown_operation",
    Value,
    Primitive(I64),
  )
  terms.push(
    Let(
      performed,
      Perform({
        operation: unknown_operation,
        effect_arguments: [],
        hidden_witnesses: [],
        payloads: [],
      }),
    ),
  )
  terms.push(External(unknown_value))
  let malformed = refingerprint_test_object({ ..object, metadata, terms, })
  debug_inspect(
    @artifact.link_module_object_artifacts([malformed]),
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["unknown Buslane type identity { index: 1000 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["unknown Buslane type-parameter identity { index: 1001 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["unknown Buslane effect identity { index: 1004 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["unknown Buslane data-constructor identity { index: 1003 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["unknown Buslane operation identity { index: 1005 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["unknown Buslane value identity { index: 1002 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["external term { index: 1002 } has no external descriptor; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "object artifact validation rejects malformed side table references" {
  let object = compiled_test_object(
    (
      #|module Invalid
      #|pub let add : (I64, I64) -> I64 = builtin("%i64_add")
    ),
  )
  let unknown_value : @buslane.ValueId = { index: 1000, }
  let unknown_type : @buslane.TypeId = { index: 1001, }
  let builtins = object.externals.builtins.copy()
  builtins[0] = @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
    unknown_value,
    builtins[0].intrinsic(),
  )
  let entries = object.entries.copy()
  entries[0] = { ..entries[0], value: unknown_value, }
  let exports = object.exports.copy()
  exports[0] = { name: exports[0].name, reference: Type(unknown_type), }
  let malformed = refingerprint_test_object({
    ..object,
    externals: { ..object.externals, builtins, },
    entries,
    exports,
  })
  debug_inspect(
    @artifact.link_module_object_artifacts([malformed]),
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["builtin external references unknown value { index: 1000 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["builtin external { index: 1000 } has no external term; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["external term { index: 1 } has no external descriptor; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["entry references unknown value { index: 1000 }; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|    {
      #|      source_id: None,
      #|      message: "invalid module object `Invalid`",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4208"),
      #|      labels: [],
      #|      notes: ["export `add` references an unknown type identity; module objects must be internally valid before identity remapping begins"],
      #|      helps: ["recompile the module object from valid Lane source"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "object-only linking rejects an imported name missing from its provider" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.{ value }
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let objects = modules.modules.map(module_ => module_.to_object_artifact())
  for index, object in objects {
    if object.module_path_text == "Lib" {
      objects[index] = refingerprint_test_object({ ..object, exports: [], })
    }
  }
  debug_inspect(
    @artifact.link_module_object_artifacts(objects),
    content=(
      #|{
      #|  program: None,
      #|  diagnostics: [
      #|    {
      #|      source_id: None,
      #|      message: "stale imported reference",
      #|      span: None,
      #|      severity: Error,
      #|      code: Some("E4205"),
      #|      labels: [],
      #|      notes: ["an object refers to an exported symbol shape that no longer matches its provider"],
      #|      helps: ["recompile the importing module against the current provider object"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "compile module with interface artifact then link object artifacts" {
  let lib_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  debug_inspect(lib_compiled.diagnostics, content="[]")
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let main_compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = box.value
    ),
    [lib_artifact.interface],
  )
  debug_inspect(main_compiled.diagnostics, content="[]")
  guard main_compiled.modules is Some(main_modules) else {
    abort("expected main modules")
  }
  guard main_modules.modules.get(0) is Some(main_module) else {
    abort("expected Main module")
  }
  let main_artifact = main_module.to_artifact()
  let linked = @artifact.link_module_object_artifacts([
    lib_artifact.object,
    main_artifact.object,
  ])
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(entry_display_name).join(","),
    content="Lib.box,Main.answer",
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "compile module freshens independently compiled interface symbols" {
  let left_compiled = compile_modules_for_test(
    (
      #|module Left
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub let left : Box = Box::{ value: 1 }
    ),
    [],
  )
  debug_inspect(left_compiled.diagnostics, content="[]")
  guard left_compiled.modules is Some(left_modules) else {
    abort("expected Left modules")
  }
  guard left_modules.modules.get(0) is Some(left_module) else {
    abort("expected Left module")
  }
  let left_artifact = left_module.to_artifact()
  let right_compiled = compile_modules_for_test(
    (
      #|module Right
      #|pub struct Box {
      #|  item : I64
      #|}
      #|pub let right : Box = Box::{ item: 2 }
    ),
    [],
  )
  debug_inspect(right_compiled.diagnostics, content="[]")
  guard right_compiled.modules is Some(right_modules) else {
    abort("expected Right modules")
  }
  guard right_modules.modules.get(0) is Some(right_module) else {
    abort("expected Right module")
  }
  let right_artifact = right_module.to_artifact()
  let main_compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Left.*
      #|import Right.*
      #|pub fn answer() -> I64 {
      #|  let _left = left.value
      #|  right.item
      #|}
    ),
    [left_artifact.interface, right_artifact.interface],
  )
  debug_inspect(main_compiled.diagnostics, content="[]")
  guard main_compiled.modules is Some(main_modules) else {
    abort("expected Main modules")
  }
  guard main_modules.modules.get(0) is Some(main_module) else {
    abort("expected Main module")
  }
  let main_artifact = main_module.to_artifact()
  let linked = @artifact.link_module_artifacts({
    schema_version: 3,
    root_module_path_text: "Main",
    modules: [left_artifact, right_artifact, main_artifact],
  })
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile module follows transitive interface dependencies without extra pollution" {
  let extra_compiled = compile_modules_for_test(
    (
      #|module Extra
      #|pub struct Noise {
      #|  value : I64
      #|}
    ),
    [],
  )
  debug_inspect(extra_compiled.diagnostics, content="[]")
  guard extra_compiled.modules is Some(extra_modules) else {
    abort("expected Extra modules")
  }
  guard extra_modules.modules.get(0) is Some(extra_module) else {
    abort("expected Extra module")
  }
  let extra_artifact = extra_module.to_artifact()
  let a_compiled = compile_modules_for_test(
    (
      #|module A
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  debug_inspect(a_compiled.diagnostics, content="[]")
  guard a_compiled.modules is Some(a_modules) else {
    abort("expected A modules")
  }
  guard a_modules.modules.get(0) is Some(a_module) else {
    abort("expected A module")
  }
  let a_artifact = a_module.to_artifact()
  let b_compiled = compile_module_with_interfaces_for_test(
    (
      #|module B
      #|import A.*
      #|pub let forwarded : Box = box
    ),
    [extra_artifact.interface, a_artifact.interface],
  )
  debug_inspect(b_compiled.diagnostics, content="[]")
  guard b_compiled.modules is Some(b_modules) else {
    abort("expected B modules")
  }
  guard b_modules.modules.get(0) is Some(b_module) else {
    abort("expected B module")
  }
  let b_artifact = b_module.to_artifact()
  let c_compiled = compile_module_with_interfaces_for_test(
    (
      #|module C
      #|import B.*
      #|pub let answer : I64 = forwarded.value
    ),
    [b_artifact.interface, a_artifact.interface],
  )
  debug_inspect(c_compiled.diagnostics, content="[]")
  guard c_compiled.modules is Some(c_modules) else {
    abort("expected C modules")
  }
  guard c_modules.modules.get(0) is Some(c_module) else {
    abort("expected C module")
  }
  let c_artifact = c_module.to_artifact()
  let linked = @artifact.link_module_artifacts({
    schema_version: 3,
    root_module_path_text: "C",
    modules: [c_artifact, b_artifact, a_artifact],
  })
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile module reports missing transitive interface dependency" {
  let a_compiled = compile_modules_for_test(
    (
      #|module A
      #|pub struct Box {
      #|  value : I64
      #|}
      #|pub let box : Box = Box::{ value: 42 }
    ),
    [],
  )
  guard a_compiled.modules is Some(a_modules) else {
    abort("expected A modules")
  }
  guard a_modules.modules.get(0) is Some(a_module) else {
    abort("expected A module")
  }
  let a_artifact = a_module.to_artifact()
  let b_compiled = compile_module_with_interfaces_for_test(
    (
      #|module B
      #|import A.*
      #|pub let forwarded : Box = box
    ),
    [a_artifact.interface],
  )
  guard b_compiled.modules is Some(b_modules) else {
    abort("expected B modules")
  }
  guard b_modules.modules.get(0) is Some(b_module) else {
    abort("expected B module")
  }
  let b_artifact = b_module.to_artifact()
  let c_compiled = compile_module_with_interfaces_for_test(
    (
      #|module C
      #|import B.*
      #|pub let answer : I64 = forwarded.value
    ),
    [b_artifact.interface],
  )
  debug_inspect(
    c_compiled.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["missing imported module `A`"]
    ),
  )
}

///|
test "compile module rejects interface artifact name mismatch" {
  let lib_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub let value : I64 = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let interface = lib_artifact.interface.interface
  let damaged_interface : @module_interface.ModuleInterface = {
    module_path: "Other",
    source_id: None,
    type_references: interface.type_references,
    effect_references: interface.effect_references,
    types: interface.types,
    effects: interface.effects,
    type_aliases: interface.type_aliases,
    values: interface.values,
    exports: interface.exports,
    optimization_hints: interface.optimization_hints,
  }
  let damaged : @artifact.ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: damaged_interface,
    interface_fingerprint: lib_artifact.interface.interface_fingerprint,
    module_fingerprint: lib_artifact.interface.module_fingerprint,
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [damaged],
  )
  debug_inspect(
    compiled.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["invalid module interface artifact"]
    ),
  )
}

///|
test "compile module rejects stale interface artifact fingerprint" {
  let lib_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub let value : I64 = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let damaged : @artifact.ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: lib_artifact.interface.interface,
    interface_fingerprint: { value: "stale", },
    module_fingerprint: lib_artifact.interface.module_fingerprint,
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [damaged],
  )
  debug_inspect(
    compiled.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["invalid module interface artifact"]
    ),
  )
}

///|
test "compile module rejects stale interface artifact module fingerprint" {
  let lib_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub let value : I64 = 42
    ),
    [],
  )
  guard lib_compiled.modules is Some(lib_modules) else {
    abort("expected Lib modules")
  }
  guard lib_modules.modules.get(0) is Some(lib_module) else {
    abort("expected Lib module")
  }
  let lib_artifact = lib_module.to_artifact()
  let damaged : @artifact.ModuleInterfaceArtifact = {
    schema_version: lib_artifact.interface.schema_version,
    module_path_text: lib_artifact.interface.module_path_text,
    interface: lib_artifact.interface.interface,
    interface_fingerprint: lib_artifact.interface.interface_fingerprint,
    module_fingerprint: { value: "stale", },
    imported_interface_fingerprints: lib_artifact.interface.imported_interface_fingerprints,
  }
  let compiled = compile_module_with_interfaces_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [damaged],
  )
  debug_inspect(
    compiled.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["invalid module interface artifact"]
    ),
  )
}

///|
test "module object fingerprint changes on implementation-only changes" {
  let first_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub let value : I64 = 1
    ),
    [],
  )
  let second_compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub let value : I64 = 2
    ),
    [],
  )
  guard first_compiled.modules is Some(first_modules) else {
    abort("expected first modules")
  }
  guard second_compiled.modules is Some(second_modules) else {
    abort("expected second modules")
  }
  guard first_modules.modules.get(0) is Some(first_module) else {
    abort("expected first module")
  }
  guard second_modules.modules.get(0) is Some(second_module) else {
    abort("expected second module")
  }
  let first_artifact = first_module.to_artifact()
  let second_artifact = second_module.to_artifact()
  debug_inspect(
    [
      first_artifact.interface.interface_fingerprint ==
      second_artifact.interface.interface_fingerprint,
      first_artifact.interface.module_fingerprint ==
      second_artifact.interface.module_fingerprint,
      first_artifact.object.object_fingerprint ==
      second_artifact.object.object_fingerprint,
    ],
    content="[true, true, false]",
  )
}

///|
test "link object artifacts rejects stale object fingerprint" {
  let compiled = compile_modules_for_test(
    (
      #|module Lib
      #|pub let value : I64 = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected module")
  }
  let object = module_.to_object_artifact()
  let damaged : @artifact.ModuleObjectArtifact = {
    schema_version: object.schema_version,
    module_path_text: object.module_path_text,
    interface_fingerprint: object.interface_fingerprint,
    canonical_basic_abi: object.canonical_basic_abi,
    metadata: object.metadata,
    terms: object.terms,
    externals: object.externals,
    entries: object.entries,
    exports: object.exports,
    imports: object.imports,
    module_fingerprint: object.module_fingerprint,
    object_fingerprint: { value: "stale", },
    imported_interface_fingerprints: object.imported_interface_fingerprints,
  }
  let linked = @artifact.link_module_object_artifacts([damaged])
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["invalid module object artifact"]
    ),
  )
}

///|
test "link module artifacts rejects interface object fingerprint mismatch" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged = artifact.modules.map(fn(module_) {
    if module_.interface.module_path_text == "Lib" {
      let object : @artifact.ModuleObjectArtifact = {
        schema_version: module_.object.schema_version,
        module_path_text: module_.object.module_path_text,
        interface_fingerprint: module_.object.interface_fingerprint,
        canonical_basic_abi: module_.object.canonical_basic_abi,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports: module_.object.imports,
        module_fingerprint: { value: "stale", },
        object_fingerprint: module_.object.object_fingerprint,
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @artifact.CompiledModuleArtifact::{
        schema_version: module_.schema_version,
        interface: module_.interface,
        object,
      }
    } else {
      module_
    }
  })
  let linked = @artifact.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged,
  })
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["invalid compiled module artifact"]
    ),
  )
}

///|
test "link module artifacts rejects interface object name mismatch" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged = artifact.modules.map(fn(module_) {
    if module_.interface.module_path_text == "Lib" {
      let interface : @artifact.ModuleInterfaceArtifact = {
        schema_version: module_.interface.schema_version,
        module_path_text: "Other",
        interface: module_.interface.interface,
        interface_fingerprint: module_.interface.interface_fingerprint,
        module_fingerprint: module_.interface.module_fingerprint,
        imported_interface_fingerprints: module_.interface.imported_interface_fingerprints,
      }
      @artifact.CompiledModuleArtifact::{
        schema_version: module_.schema_version,
        interface,
        object: module_.object,
      }
    } else {
      module_
    }
  })
  let linked = @artifact.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged,
  })
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["invalid module interface artifact"]
    ),
  )
}

///|
test "link module artifacts rejects stale imported reference fingerprint" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged_modules = artifact.modules.map(fn(module_) {
    if module_.object.module_path_text == "Main" {
      let imports : Array[@artifact.ModuleImportedReference] = module_.object.imports.map(fn(
          imported,
        ) {
          {
            module_path_text: imported.module_path_text,
            name: imported.name,
            fingerprint: { value: "stale", },
            reference: imported.reference,
          }
        },
      )
      let object : @artifact.ModuleObjectArtifact = {
        schema_version: module_.object.schema_version,
        module_path_text: module_.object.module_path_text,
        interface_fingerprint: module_.object.interface_fingerprint,
        canonical_basic_abi: module_.object.canonical_basic_abi,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports: module_.object.exports,
        imports,
        module_fingerprint: module_.object.module_fingerprint,
        object_fingerprint: @artifact.module_object_fingerprint(
          module_.object.module_fingerprint,
          module_.object.interface_fingerprint,
          module_.object.canonical_basic_abi,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          module_.object.exports,
          imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @artifact.CompiledModuleArtifact::{
        schema_version: module_.schema_version,
        interface: module_.interface,
        object,
      }
    } else {
      module_
    }
  })
  let linked = @artifact.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged_modules,
  })
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["stale imported reference"]
    ),
  )
}

///|
test "link module artifacts rejects missing exported object value" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let artifact = modules.to_artifact()
  let damaged_modules = artifact.modules.map(fn(module_) {
    if module_.object.module_path_text == "Lib" {
      let exports = []
      let object : @artifact.ModuleObjectArtifact = {
        schema_version: module_.object.schema_version,
        module_path_text: module_.object.module_path_text,
        interface_fingerprint: module_.object.interface_fingerprint,
        canonical_basic_abi: module_.object.canonical_basic_abi,
        metadata: module_.object.metadata,
        terms: module_.object.terms,
        externals: module_.object.externals,
        entries: module_.object.entries,
        exports,
        imports: module_.object.imports,
        module_fingerprint: module_.object.module_fingerprint,
        object_fingerprint: @artifact.module_object_fingerprint(
          module_.object.module_fingerprint,
          module_.object.interface_fingerprint,
          module_.object.canonical_basic_abi,
          module_.object.metadata,
          module_.object.terms,
          module_.object.externals,
          module_.object.entries,
          exports,
          module_.object.imports,
          module_.object.imported_interface_fingerprints,
        ),
        imported_interface_fingerprints: module_.object.imported_interface_fingerprints,
      }
      @artifact.CompiledModuleArtifact::{
        schema_version: module_.schema_version,
        interface: module_.interface,
        object,
      }
    } else {
      module_
    }
  })
  let linked = @artifact.link_module_artifacts({
    schema_version: artifact.schema_version,
    root_module_path_text: artifact.root_module_path_text,
    modules: damaged_modules,
  })
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["object artifact does not satisfy its interface"]
    ),
  )
}

///|
test "link modules rejects compiled artifact import cycle" {
  let compiled_a = compile_modules_for_test(
    (
      #|module A
      #|pub let a : I64 = 1
    ),
    [],
  )
  let compiled_b = compile_modules_for_test(
    (
      #|module B
      #|pub let b : I64 = 2
    ),
    [],
  )
  guard compiled_a.modules is Some(modules_a) else {
    abort("expected A modules")
  }
  guard compiled_b.modules is Some(modules_b) else {
    abort("expected B modules")
  }
  guard modules_a.modules.get(0) is Some(module_a) else {
    abort("expected A module")
  }
  guard modules_b.modules.get(0) is Some(module_b) else {
    abort("expected B module")
  }
  let module_a = artifact_with_imported_interfaces(module_a, [
    {
      module_path_text: "B",
      fingerprint: @artifact.interface_fingerprint(module_b.interface),
    },
  ])
  let module_b = artifact_with_imported_interfaces(module_b, [
    {
      module_path_text: "A",
      fingerprint: module_a.interface.interface_fingerprint,
    },
  ])
  let linked = @artifact.link_module_artifacts({
    schema_version: 3,
    root_module_path_text: "A",
    modules: [module_a, module_b],
  })
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["import cycle involving `A`"]
    ),
  )
}

///|
test "link modules rejects missing compiled artifact import" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|pub let answer : I64 = 42
    ),
    [],
  )
  guard compiled.modules is Some(modules) else { abort("expected modules") }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected Main module")
  }
  let module_ = artifact_with_imported_interfaces(module_, [
    { module_path_text: "Missing", fingerprint: { value: "missing", }, },
  ])
  let linked = @artifact.link_module_artifacts({
    schema_version: 3,
    root_module_path_text: "Main",
    modules: [module_],
  })
  debug_inspect(
    linked.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["missing object artifact for `Missing`"]
    ),
  )
}

///|
fn entry_display_name(entry : @buslane_lowering.BuslaneEntry) -> String {
  "\{entry.module_path_text}.\{entry.name}"
}

///|
fn artifact_with_imported_interfaces(
  module_ : @module_compile.CompiledModule,
  imported : Array[@artifact.ImportedInterfaceFingerprint],
) -> @artifact.CompiledModuleArtifact {
  let artifact = module_.to_artifact()
  let module_fingerprint = @artifact.module_fingerprint(
    module_.interface,
    imported,
  )
  let interface : @artifact.ModuleInterfaceArtifact = {
    ..artifact.interface,
    module_fingerprint,
    imported_interface_fingerprints: imported,
  }
  let object : @artifact.ModuleObjectArtifact = {
    ..artifact.object,
    module_fingerprint,
    object_fingerprint: @artifact.module_object_fingerprint(
      module_fingerprint,
      artifact.object.interface_fingerprint,
      artifact.object.canonical_basic_abi,
      artifact.object.metadata,
      artifact.object.terms,
      artifact.object.externals,
      artifact.object.entries,
      artifact.object.exports,
      artifact.object.imports,
      imported,
    ),
    imported_interface_fingerprints: imported,
  }
  { schema_version: artifact.schema_version, interface, object, }
}
