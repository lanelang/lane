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
fn validate_buslane_object(
  object : LinkModuleObject,
) -> Array[CompilerDiagnostic] {
  let metadata = object.metadata.snapshot()
  for builtin in object.externals.builtins {
    ignore(metadata.define_value("<builtin-side-type>", Value, builtin.type_))
  }
  for import_ in object.externals.runtime_imports {
    ignore(
      metadata.define_value("<runtime-import-side-type>", Value, import_.type_),
    )
  }
  for entry in object.entries {
    ignore(metadata.define_value("<entry-side-type>", Value, entry.type_))
  }
  let terms = object.terms.copy()
  for import_ in object.imports {
    if import_.value is Some(value) {
      terms.push(Let(value, Ref(value)))
    }
  }
  let result = @buslane.verify_program({ metadata, terms })
  result.diagnostics.filter_map(diagnostic => {
    match diagnostic.kind {
      UnknownTypeParameter(id) if object.metadata.type_parameter_info(id)
        is Some(_) => None
      _ =>
        Some(
          invalid_module_object(
            object,
            "Buslane verification failed: \{Repr(diagnostic.kind)}",
          ),
        )
    }
  })
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
    if import_.value is Some(value) && !external_values.contains(value) {
      external_values.push(value)
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
  if !module_reference_shape_is_exact(
      export_.kind,
      export_.type_id,
      export_.data_constructor,
      export_.effect_id,
      export_.operation,
      export_.value,
    ) {
    return [
      invalid_module_object(
        object,
        "export `\{export_.name}` has an invalid identity shape",
      ),
    ]
  }
  validate_reference_identity(
    object,
    export_.kind,
    export_.name,
    export_.type_id,
    export_.data_constructor,
    export_.effect_id,
    export_.operation,
    export_.value,
    "export",
  )
}

///|
fn validate_import_reference(
  object : LinkModuleObject,
  import_ : @artifact_core.ModuleImportedReference,
) -> Array[CompilerDiagnostic] {
  if !module_reference_shape_is_exact(
      import_.kind,
      import_.type_id,
      import_.data_constructor,
      import_.effect_id,
      import_.operation,
      import_.value,
    ) {
    return [
      invalid_module_object(
        object,
        "import `\{import_.module_path_text}::\{import_.name}` has an invalid identity shape",
      ),
    ]
  }
  validate_reference_identity(
    object,
    import_.kind,
    import_.name,
    import_.type_id,
    import_.data_constructor,
    import_.effect_id,
    import_.operation,
    import_.value,
    "import",
  )
}

///|
fn module_reference_shape_is_exact(
  kind : @buslane_lowering.BuslaneModuleExportKind,
  type_id : @buslane.TypeId?,
  data_constructor : @buslane.DataConId?,
  effect_id : @buslane.EffectId?,
  operation : @buslane.OperationId?,
  value : @buslane.ValueId?,
) -> Bool {
  match kind {
    Type =>
      type_id is Some(_) &&
      data_constructor is None &&
      effect_id is None &&
      operation is None &&
      value is None
    DataConstructor =>
      type_id is None &&
      data_constructor is Some(_) &&
      effect_id is None &&
      operation is None &&
      value is None
    Effect =>
      type_id is None &&
      data_constructor is None &&
      effect_id is Some(_) &&
      operation is None &&
      value is None
    Operation =>
      type_id is None &&
      data_constructor is None &&
      effect_id is None &&
      operation is Some(_) &&
      value is None
    FieldSelector | Value =>
      type_id is None &&
      data_constructor is None &&
      effect_id is None &&
      operation is None &&
      value is Some(_)
  }
}

///|
fn validate_reference_identity(
  object : LinkModuleObject,
  kind : @buslane_lowering.BuslaneModuleExportKind,
  name : String,
  type_id : @buslane.TypeId?,
  data_constructor : @buslane.DataConId?,
  effect_id : @buslane.EffectId?,
  operation : @buslane.OperationId?,
  value : @buslane.ValueId?,
  role : String,
) -> Array[CompilerDiagnostic] {
  let valid = match kind {
    Type => type_id is Some(id) && object.metadata.type_info(id) is Some(_)
    DataConstructor =>
      data_constructor is Some(id) &&
      object.metadata.data_constructor_info(id) is Some(_)
    Effect =>
      effect_id is Some(id) && object.metadata.effect_info(id) is Some(_)
    Operation =>
      operation is Some(id) && object.metadata.operation_info(id) is Some(_)
    FieldSelector | Value =>
      value is Some(id) && object.metadata.value_info(id) is Some(_)
  }
  if valid {
    []
  } else {
    [
      invalid_module_object(
        object,
        "\{role} `\{name}` references an unknown \{module_reference_kind_name(kind)} identity",
      ),
    ]
  }
}

///|
fn module_reference_kind_name(
  kind : @buslane_lowering.BuslaneModuleExportKind,
) -> String {
  match kind {
    Type => "type"
    DataConstructor => "data constructor"
    Effect => "effect"
    Operation => "operation"
    FieldSelector | Value => "value"
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
        } else {
          match
            find_module_export(
              imported_module.exports,
              imported.kind,
              imported.name,
            ) {
            Some(item) =>
              if !imported_reference_shape_matches_export(imported, item) {
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
                  ImportedReferenceMismatch(
                    importer=object.module_path_text,
                    imported=imported.module_path_text,
                    name=imported.name,
                  ),
                  None,
                ),
              )
          }
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
fn find_module_export(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  kind : @buslane_lowering.BuslaneModuleExportKind,
  name : String,
) -> @buslane_lowering.BuslaneModuleExport? {
  for item in exports {
    if item.kind == kind && item.name == name {
      return Some(item)
    }
  }
  None
}

///|
fn imported_reference_shape_matches_export(
  imported : @artifact_core.ModuleImportedReference,
  item : @buslane_lowering.BuslaneModuleExport,
) -> Bool {
  if imported.kind != item.kind {
    return false
  }
  match imported.kind {
    Type => imported.type_id is Some(_) && item.type_id is Some(_)
    DataConstructor =>
      imported.data_constructor is Some(_) && item.data_constructor is Some(_)
    Effect => imported.effect_id is Some(_) && item.effect_id is Some(_)
    Operation => imported.operation is Some(_) && item.operation is Some(_)
    FieldSelector | Value => imported.value is Some(_) && item.value is Some(_)
  }
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
        imported_module.interface is Some(interface) {
        diagnostics.append(
          validate_imported_exports(
            importer=module_.module_path_text,
            provider=imported_module.module_path_text,
            interface~,
            exports=imported_module.exports,
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
  exports~ : Array[@buslane_lowering.BuslaneModuleExport],
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for value in interface.values {
    if !module_exports_value(exports, value.name) {
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
    if !module_exports_type(exports, name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(kind="type", provider~, name~, importer~),
          None,
        ),
      )
    }
    let constructor_names = interface_type_constructors(type_)
    for constructor_name in constructor_names {
      if !module_exports_data_constructor(exports, constructor_name) {
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
      if !module_exports_field_selector(exports, field_selector_name) {
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
    if !module_exports_effect(exports, effect.name) {
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
      if !module_exports_operation(exports, operation_name) {
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
fn module_exports_value(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Value && item.name == name })
}

///|
fn module_exports_type(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Type && item.name == name })
}

///|
fn module_exports_data_constructor(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is DataConstructor && item.name == name })
}

///|
fn module_exports_effect(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Effect && item.name == name })
}

///|
fn module_exports_operation(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Operation && item.name == name })
}

///|
fn module_exports_field_selector(
  exports : Array[@buslane_lowering.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is FieldSelector && item.name == name })
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
