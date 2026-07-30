///|
fn refingerprint_test_object(
  object : @module_compile.ModuleObjectArtifact,
) -> @module_compile.ModuleObjectArtifact {
  {
    ..object,
    object_fingerprint: @module_compile.module_object_fingerprint(
      object.module_fingerprint,
      object.interface_fingerprint,
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
) -> @module_compile.ModuleObjectArtifact {
  let compiled = compile_modules(source, [])
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard modules.modules.get(0) is Some(module_) else {
    abort("expected compiled module")
  }
  module_.to_object_artifact()
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
  let unknown_type : @buslane.TypeId = { index: 1000 }
  let unknown_parameter : @buslane.TypeParameterId = { index: 1001 }
  let unknown_value : @buslane.ValueId = { index: 1002 }
  let unknown_constructor : @buslane.DataConId = { index: 1003 }
  let unknown_effect : @buslane.EffectId = { index: 1004 }
  let unknown_operation : @buslane.OperationId = { index: 1005 }
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
  let malformed = refingerprint_test_object({ ..object, metadata, terms })
  debug_inspect(
    @module_compile.link_module_object_artifacts([malformed]),
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
      #|      notes: ["Buslane verification failed: UnknownType({ index: 1000 }); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: UnknownTypeParameter({ index: 1001 }); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: UnknownEffect({ index: 1004 }); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: UnknownDataConstructor({ index: 1003 }); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: TypeMismatch(expected=Primitive(I64), actual=Primitive(Unit)); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: UnknownOperation({ index: 1005 }); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: TypeMismatch(expected=Primitive(I64), actual=Primitive(Unit)); module objects must be internally valid before identity remapping begins"],
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
      #|      notes: ["Buslane verification failed: UnknownValue({ index: 1002 }); module objects must be internally valid before identity remapping begins"],
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
  let unknown_value : @buslane.ValueId = { index: 1000 }
  let unknown_type : @buslane.TypeId = { index: 1001 }
  let builtins = object.externals.builtins.copy()
  builtins[0] = { ..builtins[0], value: unknown_value }
  let entries = object.entries.copy()
  entries[0] = { ..entries[0], value: unknown_value }
  let exports = object.exports.copy()
  exports[0] = {
    kind: Type,
    name: exports[0].name,
    type_id: Some(unknown_type),
    data_constructor: None,
    effect_id: None,
    operation: None,
    value: None,
  }
  let malformed = refingerprint_test_object({
    ..object,
    externals: { ..object.externals, builtins, },
    entries,
    exports,
  })
  debug_inspect(
    @module_compile.link_module_object_artifacts([malformed]),
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
  let compiled = compile_modules(
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
      objects[index] = refingerprint_test_object({ ..object, exports: [] })
    }
  }
  debug_inspect(
    @module_compile.link_module_object_artifacts(objects),
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
