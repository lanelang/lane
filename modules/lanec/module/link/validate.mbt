///|
fn validate_link_object(
  index : LinkModuleIndex,
  object : LinkModuleObject,
) -> Result[ValidatedLinkModuleObject, Array[CompilerDiagnostic]] {
  let diagnostics = []
  let certified_canonical_basic_abi = match
    object.canonical_basic_abi.certify(
      object.canonical_basic_type_declarations(),
      object.program.metadata,
    ) {
    Ok(contract) => Some(contract)
    Err(error) => {
      diagnostics.push(error.object_diagnostic(object.module_path_text))
      None
    }
  }
  if !object.object_fingerprint_valid {
    diagnostics.push(
      link_diagnostic(
        StaleModuleObject(
          module_path_text=object.module_path_text,
          reason="object fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  diagnostics.append(validate_buslane_object(object))
  diagnostics.append(
    validate_object_side_tables(object, certified_canonical_basic_abi),
  )
  for imported in object.imported_interface_fingerprints {
    match index.find(imported.module_path_text) {
      Some(imported_module) =>
        if imported_module.interface_fingerprint != imported.fingerprint {
          diagnostics.push(
            link_diagnostic(
              LinkImportedInterfaceFingerprintMismatch(
                importer=object.module_path_text,
                imported=imported.module_path_text,
              ),
              None,
            ),
          )
        }
      None =>
        diagnostics.push(
          link_diagnostic(
            MissingImportedObject(imported.module_path_text),
            None,
          ),
        )
    }
  }
  diagnostics.append(validate_imported_references(object, index))
  match (diagnostics, certified_canonical_basic_abi) {
    ([], Some(_)) => Ok({ object, })
    (diagnostics, _) => Err(diagnostics)
  }
}

///|
fn LinkModuleObject::canonical_basic_type_declarations(
  self : LinkModuleObject,
) -> Array[@canonical_basic_abi.CanonicalBasicAbiObjectTypeDeclaration] {
  let declarations : Array[
    @canonical_basic_abi.CanonicalBasicAbiObjectTypeDeclaration,
  ] = []
  for export_ in self.exports {
    if export_.reference is Type(type_id) {
      declarations.push({
        module_path: self.module_path_text,
        name: export_.name,
        type_id,
      })
    }
  }
  for import_ in self.imports {
    if import_.reference is Type(type_id) {
      declarations.push({
        module_path: import_.module_path_text,
        name: import_.name,
        type_id,
      })
    }
  }
  declarations
}

///|
fn validate_object_side_tables(
  object : LinkModuleObject,
  canonical_basic_abi : @canonical_basic_abi.CertifiedCanonicalBasicAbiRuntimeContract?,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  let external_values : Array[@buslane.ValueId] = []
  for builtin in object.externals.builtins {
    let source_type = validate_external_reference(
      object,
      builtin.value(),
      "builtin external",
      diagnostics,
    )
    if canonical_basic_abi is Some(canonical_basic_abi) &&
      source_type is Some(source_type) &&
      !builtin_contract_matches(
        canonical_basic_abi,
        builtin.intrinsic(),
        source_type,
      ) {
      diagnostics.push(
        invalid_module_object(
          object,
          "builtin `\{builtin.intrinsic().name()}` does not match its canonical source contract",
        ),
      )
    }
    if external_values.contains(builtin.value()) {
      diagnostics.push(
        invalid_module_object(
          object,
          "duplicate external value \{Repr(builtin.value())}",
        ),
      )
    } else {
      external_values.push(builtin.value())
    }
  }
  for import_ in object.externals.runtime_imports {
    let source_type = validate_external_reference(
      object,
      import_.value,
      "runtime import",
      diagnostics,
    )
    if source_type is Some(source_type) {
      validate_runtime_import_signature(
        object, import_, source_type, diagnostics,
      )
    }
    if external_values.contains(import_.value) {
      diagnostics.push(
        invalid_module_object(
          object,
          "duplicate external value \{Repr(import_.value)}",
        ),
      )
    } else {
      external_values.push(import_.value)
    }
  }
  for import_ in object.imports {
    match import_.reference {
      FieldSelector(value) | Value(value) =>
        if !external_values.contains(value) {
          external_values.push(value)
        }
      _ => ()
    }
  }
  for term in object.program.terms {
    if term is External(value) && !external_values.contains(value) {
      diagnostics.push(
        invalid_module_object(
          object,
          "external term \{Repr(value)} has no external descriptor",
        ),
      )
    }
  }
  for entry in object.entries {
    if entry.module_path_text != object.module_path_text {
      diagnostics.push(
        invalid_module_object(
          object,
          "entry `\{entry.name}` belongs to `\{entry.module_path_text}`",
        ),
      )
    }
    validate_value_reference(object, entry.value, "entry", diagnostics)
  }
  for export_ in object.exports {
    diagnostics.append(validate_export_reference(object, export_))
  }
  for import_ in object.imports {
    diagnostics.append(validate_import_reference(object, import_))
  }
  diagnostics
}

///|
fn builtin_contract_matches(
  canonical_basic_abi : @canonical_basic_abi.CertifiedCanonicalBasicAbiRuntimeContract,
  intrinsic : @abi.Intrinsic,
  source_type : @buslane.Type,
) -> Bool {
  match (intrinsic.signature(), source_type) {
    (Value(kind), type_) =>
      intrinsic_value_type_matches(canonical_basic_abi, kind, type_)
    (
      Function(parameters~, result~, effect~, ..),
      Function(actual_parameters, actual_result, actual_effect),
    ) =>
      intrinsic_parameters_match(
        canonical_basic_abi, parameters, actual_parameters,
      ) &&
      intrinsic_value_type_matches(canonical_basic_abi, result, actual_result) &&
      intrinsic_effect_matches(effect, actual_effect)
    _ => false
  }
}

///|
fn intrinsic_parameters_match(
  canonical_basic_abi : @canonical_basic_abi.CertifiedCanonicalBasicAbiRuntimeContract,
  expected : Array[@abi.IntrinsicType],
  actual : Array[@buslane.Type],
) -> Bool {
  if expected.length() != actual.length() {
    return false
  }
  for index, kind in expected {
    if !intrinsic_value_type_matches(canonical_basic_abi, kind, actual[index]) {
      return false
    }
  }
  true
}

///|
fn intrinsic_value_type_matches(
  canonical_basic_abi : @canonical_basic_abi.CertifiedCanonicalBasicAbiRuntimeContract,
  kind : @abi.IntrinsicType,
  type_ : @buslane.Type,
) -> Bool {
  match kind {
    Unit => type_ == Primitive(Unit)
    Bool => type_ == Primitive(Bool)
    I64 => type_ == Primitive(I64)
    I32 => type_ == Primitive(I32)
    Char => type_ == Primitive(Char)
    F64 => type_ == Primitive(F64)
    F32 => type_ == Primitive(F32)
    String => type_ == Primitive(String)
    Byte => type_ == Primitive(Byte)
    Bytes => type_ == Primitive(Bytes)
    CanonicalBasicVoid =>
      match canonical_basic_abi.void_type() {
        Some(type_id) => type_ == Constructor(type_id)
        None => false
      }
  }
}

///|
fn intrinsic_effect_matches(
  expected : @abi.IntrinsicEffect,
  actual : @buslane.Effect,
) -> Bool {
  match expected {
    Pure => actual == Empty
    BuiltinIo => actual == Builtin(Io)
    BuiltinPanic => actual == Builtin(Panic)
  }
}

///|
fn validate_runtime_import_signature(
  object : LinkModuleObject,
  import_ : @buslane_lowering.BuslaneRuntimeImport,
  source_type : @buslane.Type,
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  let normalized = source_type.normalize() catch {
    error => {
      diagnostics.push(
        link_diagnostic(
          InvalidModuleObjectTypeNormalization(
            module_path_text=object.module_path_text,
            role="runtime import",
            value=import_.value,
            error~,
          ),
          None,
        ),
      )
      return
    }
  }
  guard normalized is Function(parameters, result, effect) else {
    diagnostics.push(
      invalid_module_object(
        object,
        "runtime import `\{import_.symbol}` source type is not a function",
      ),
    )
    return
  }
  let parameter_kinds = parameters.map(type_ => {
    runtime_import_source_kind(object.program.metadata, type_)
  })
  let result_kind = runtime_import_source_kind(object.program.metadata, result)
  if parameter_kinds.any(kind => kind is None) ||
    result_kind is None ||
    parameter_kinds.filter_map(kind => kind) != import_.signature.parameters ||
    result_kind != Some(import_.signature.result) ||
    !runtime_import_effect_is_admissible(object.program.metadata, effect) {
    diagnostics.push(
      invalid_module_object(
        object,
        "runtime import `\{import_.symbol}` host signature does not match its source type",
      ),
    )
  }
}

///|
fn runtime_import_source_kind(
  metadata : @buslane.MetadataRegistry,
  type_ : @buslane.Type,
) -> @abi.ValueKind? {
  match type_ {
    Primitive(Unit) => Some(Unit)
    Primitive(Bool) => Some(Bool)
    Primitive(I64) => Some(I64)
    Primitive(F32) => Some(F32)
    Primitive(F64) => Some(F64)
    Primitive(String) => Some(String)
    Constructor(type_id) =>
      if metadata
        .type_info(type_id)
        .map_or(false, info => info.flavor is External) {
        Some(Opaque)
      } else {
        None
      }
    _ => None
  }
}

///|
fn runtime_import_effect_is_admissible(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> Bool {
  match effect {
    Empty | Builtin(_) => true
    Singleton(effect_id, _) =>
      metadata
      .effect_info(effect_id)
      .map_or(false, info => info.flavor is External)
    Union(effects) =>
      effects.all(effect => {
        runtime_import_effect_is_admissible(metadata, effect)
      })
    Parameter(_) => false
  }
}

///|
fn validate_external_reference(
  object : LinkModuleObject,
  value : @buslane.ValueId,
  role : String,
  diagnostics : Array[CompilerDiagnostic],
) -> @buslane.Type? {
  let source_type = certify_source_value_type(object, value, role, diagnostics)
  if object.program.metadata.value_info(value) is Some(info) &&
    info.kind != External {
    diagnostics.push(
      invalid_module_object(
        object,
        "\{role} \{Repr(value)} does not name an external value",
      ),
    )
  }
  if !object.program.terms.any(term => term == External(value)) {
    diagnostics.push(
      invalid_module_object(
        object,
        "\{role} \{Repr(value)} has no external term",
      ),
    )
  }
  source_type
}

///|
fn validate_value_reference(
  object : LinkModuleObject,
  value : @buslane.ValueId,
  role : String,
  diagnostics : Array[CompilerDiagnostic],
) -> Unit {
  ignore(certify_source_value_type(object, value, role, diagnostics))
}

///|
fn certify_source_value_type(
  object : LinkModuleObject,
  value : @buslane.ValueId,
  role : String,
  diagnostics : Array[CompilerDiagnostic],
) -> @buslane.Type? {
  Some(@buslane_lowering.source_value_type(object.program.metadata, value)) catch {
    MissingValueMetadata(_) => {
      diagnostics.push(
        invalid_module_object(
          object,
          "\{role} references unknown value \{Repr(value)}",
        ),
      )
      None
    }
  }
}

///|
fn validate_export_reference(
  object : LinkModuleObject,
  export_ : @buslane_lowering.BuslaneModuleExport,
) -> Array[CompilerDiagnostic] {
  validate_reference_identity(object, export_.name, export_.reference, "export")
}

///|
fn validate_import_reference(
  object : LinkModuleObject,
  import_ : @artifact_model.ModuleImportedReference,
) -> Array[CompilerDiagnostic] {
  validate_reference_identity(object, import_.name, import_.reference, "import")
}

///|
fn validate_reference_identity(
  object : LinkModuleObject,
  name : String,
  reference : @buslane_lowering.BuslaneModuleReference,
  role : String,
) -> Array[CompilerDiagnostic] {
  let valid = match reference {
    Type(id) => object.program.metadata.type_info(id) is Some(_)
    DataConstructor(id) =>
      object.program.metadata.data_constructor_info(id) is Some(_)
    Effect(id) => object.program.metadata.effect_info(id) is Some(_)
    Operation(id) => object.program.metadata.operation_info(id) is Some(_)
    FieldSelector(id) | Value(id) =>
      object.program.metadata.value_info(id) is Some(_)
  }
  if valid {
    []
  } else {
    [
      invalid_module_object(
        object,
        "\{role} `\{name}` references an unknown \{module_reference_kind_name(reference)} identity",
      ),
    ]
  }
}

///|
fn module_reference_kind_name(
  reference : @buslane_lowering.BuslaneModuleReference,
) -> String {
  match reference {
    Type(_) => "type"
    DataConstructor(_) => "data constructor"
    Effect(_) => "effect"
    Operation(_) => "operation"
    FieldSelector(_) | Value(_) => "value"
  }
}

///|
fn invalid_module_object(
  object : LinkModuleObject,
  reason : String,
) -> CompilerDiagnostic {
  link_diagnostic(
    InvalidModuleObject(module_path_text=object.module_path_text, reason~),
    None,
  )
}

///|
fn validate_imported_references(
  object : LinkModuleObject,
  index : LinkModuleIndex,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for imported in object.imports {
    match index.find(imported.module_path_text) {
      Some(imported_module) =>
        if imported.fingerprint != imported_module.fingerprint {
          diagnostics.push(
            link_diagnostic(
              ImportedReferenceFingerprintMismatch(
                importer=object.module_path_text,
                imported=imported.module_path_text,
                name=imported.name,
              ),
              None,
            ),
          )
        } else if index.export_index(imported.module_path_text) is Some(exports) &&
          exports.find(imported.reference, imported.name) is Some(_) {
          ()
        } else {
          diagnostics.push(
            link_diagnostic(
              ImportedReferenceMismatch(
                importer=object.module_path_text,
                imported=imported.module_path_text,
                name=imported.name,
              ),
              None,
            ),
          )
        }
      None =>
        diagnostics.push(
          link_diagnostic(
            MissingImportedObject(imported.module_path_text),
            None,
          ),
        )
    }
  }
  diagnostics
}

///|
fn validate_module_exports_for_link_order(
  ordered : Array[LinkModuleObject],
  index : LinkModuleIndex,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for module_ in ordered {
    for imported in module_.imported_interface_fingerprints {
      if index.find(imported.module_path_text) is Some(imported_module) &&
        imported_module.interface is Some(interface) &&
        index.export_index(imported.module_path_text) is Some(exports) {
        diagnostics.append(
          validate_imported_exports(
            importer=module_.module_path_text,
            provider=imported_module.module_path_text,
            interface~,
            exports~,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn validate_imported_exports(
  importer~ : String,
  provider~ : String,
  interface~ : @module_interface.ModuleInterface,
  exports~ : LinkExportIndex,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for value in interface.values {
    if !exports.contains(ValueReference, value.name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(kind="value", provider~, name=value.name, importer~),
          None,
        ),
      )
    }
  }
  for type_ in interface.types {
    let name = interface_type_name(type_)
    if !exports.contains(TypeReference, name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(kind="type", provider~, name~, importer~),
          None,
        ),
      )
    }
    let constructor_names = interface_type_constructors(type_)
    for constructor_name in constructor_names {
      if !exports.contains(DataConstructorReference, constructor_name) {
        diagnostics.push(
          link_diagnostic(
            MissingExported(
              kind="constructor",
              provider~,
              name=constructor_name,
              importer~,
            ),
            None,
          ),
        )
      }
    }
    for field_selector_name in interface_type_field_selectors(type_) {
      if !exports.contains(FieldSelectorReference, field_selector_name) {
        diagnostics.push(
          link_diagnostic(
            MissingExported(
              kind="field selector",
              provider~,
              name=field_selector_name,
              importer~,
            ),
            None,
          ),
        )
      }
    }
  }
  for effect in interface.effects {
    if !exports.contains(EffectReference, effect.name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(kind="effect", provider~, name=effect.name, importer~),
          None,
        ),
      )
    }
    for operation in effect.operations {
      let operation_name = effect_operation_export_name(
        effect.name,
        operation.name,
      )
      if !exports.contains(OperationReference, operation_name) {
        diagnostics.push(
          link_diagnostic(
            MissingExported(
              kind="operation",
              provider~,
              name=operation_name,
              importer~,
            ),
            None,
          ),
        )
      }
    }
  }
  diagnostics
}

///|
fn interface_type_name(type_ : @module_interface.ModuleInterfaceType) -> String {
  match type_ {
    Struct(declaration) => declaration.name
    Enum(declaration) => declaration.name
    External(declaration) => declaration.name
  }
}

///|
fn interface_type_constructors(
  type_ : @module_interface.ModuleInterfaceType,
) -> Array[String] {
  match type_ {
    Struct(declaration) => [declaration.name]
    Enum(declaration) => declaration.variants.map(fn(variant) { variant.name })
    External(_) => []
  }
}

///|
fn interface_type_field_selectors(
  type_ : @module_interface.ModuleInterfaceType,
) -> Array[String] {
  match type_ {
    Struct(declaration) =>
      declaration.fields.map(fn(field) {
        field_selector_export_name(declaration.name, field.name)
      })
    Enum(_) => []
    External(_) => []
  }
}

///|
fn field_selector_export_name(
  type_name : String,
  field_name : String,
) -> String {
  "\{type_name}.\{field_name}"
}

///|
fn effect_operation_export_name(
  effect_name : String,
  operation_name : String,
) -> String {
  "\{effect_name}.\{operation_name}"
}
