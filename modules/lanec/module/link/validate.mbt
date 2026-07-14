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
            None => ()
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
  }
}

///|
fn interface_type_constructors(
  type_ : @module_interface.ModuleInterfaceType,
) -> Array[String] {
  match type_ {
    Struct(declaration) => [declaration.name]
    Enum(declaration) => declaration.variants.map(fn(variant) { variant.name })
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
