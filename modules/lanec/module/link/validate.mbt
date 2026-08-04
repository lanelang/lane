///|
fn validate_link_object(
  index : LinkModuleIndex,
  object : LinkModuleObject,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
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
  diagnostics.append(validate_object_side_tables(object))
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
  diagnostics
}

///|
fn validate_object_side_tables(
  object : LinkModuleObject,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  let external_values : Array[@buslane.ValueId] = []
  for builtin in object.externals.builtins {
    diagnostics.append(
      validate_external_reference(
        object,
        builtin.value,
        builtin.type_,
        "builtin external",
      ),
    )
    if external_values.contains(builtin.value) {
      diagnostics.push(
        invalid_module_object(
          object,
          "duplicate external value \{Repr(builtin.value)}",
        ),
      )
    } else {
      external_values.push(builtin.value)
    }
  }
  for import_ in object.externals.runtime_imports {
    diagnostics.append(
      validate_external_reference(
        object,
        import_.value,
        import_.type_,
        "runtime import",
      ),
    )
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
  for term in object.terms {
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
    diagnostics.append(
      validate_value_reference(object, entry.value, entry.type_, "entry"),
    )
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
fn validate_external_reference(
  object : LinkModuleObject,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
  role : String,
) -> Array[CompilerDiagnostic] {
  let diagnostics = validate_value_reference(object, value, type_, role)
  if object.metadata.value_info(value) is Some(info) && info.kind != External {
    diagnostics.push(
      invalid_module_object(
        object,
        "\{role} \{Repr(value)} does not name an external value",
      ),
    )
  }
  if !object.terms.any(term => term == External(value)) {
    diagnostics.push(
      invalid_module_object(
        object,
        "\{role} \{Repr(value)} has no external term",
      ),
    )
  }
  diagnostics
}

///|
fn validate_value_reference(
  object : LinkModuleObject,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
  role : String,
) -> Array[CompilerDiagnostic] {
  match object.metadata.value_info(value) {
    None =>
      [
        invalid_module_object(
          object,
          "\{role} references unknown value \{Repr(value)}",
        ),
      ]
    Some(info) =>
      if info.type_ == type_ {
        []
      } else {
        [
          invalid_module_object(
            object,
            "\{role} type does not match metadata for \{Repr(value)}",
          ),
        ]
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
    Type(id) => object.metadata.type_info(id) is Some(_)
    DataConstructor(id) => object.metadata.data_constructor_info(id) is Some(_)
    Effect(id) => object.metadata.effect_info(id) is Some(_)
    Operation(id) => object.metadata.operation_info(id) is Some(_)
    FieldSelector(id) | Value(id) => object.metadata.value_info(id) is Some(_)
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
