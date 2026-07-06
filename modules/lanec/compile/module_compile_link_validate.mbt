///|
fn validate_link_object(
  modules : Array[CompiledModule],
  module_ : CompiledModule,
  object : ModuleObject,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  if module_.module_path_text != object.module_path_text {
    diagnostics.push(
      link_diagnostic(
        StaleModuleObject(
          module_path_text=module_.module_path_text,
          reason="module object mismatch",
        ),
        None,
      ),
    )
  }
  if module_.fingerprint != object.fingerprint {
    diagnostics.push(
      link_diagnostic(
        StaleModuleObject(
          module_path_text=module_.module_path_text,
          reason="module fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  if object.object_fingerprint !=
    module_object_fingerprint(
      object.fingerprint,
      object.metadata,
      object.terms,
      object.externals,
      object.entries,
      object.exports,
      object.imports,
      object.imported_interface_fingerprints,
    ) {
    diagnostics.push(
      link_diagnostic(
        StaleModuleObject(
          module_path_text=module_.module_path_text,
          reason="object fingerprint mismatch",
        ),
        None,
      ),
    )
  }
  for imported in object.imported_interface_fingerprints {
    match find_compiled_module(modules, imported.module_path_text) {
      Some(imported_module) => {
        if interface_fingerprint(imported_module.interface) !=
          imported.fingerprint {
          diagnostics.push(
            link_diagnostic(
              LinkImportedInterfaceFingerprintMismatch(
                importer=module_.module_path_text,
                imported=imported.module_path_text,
              ),
              None,
            ),
          )
        }
        diagnostics.append(validate_imported_exports(module_, imported_module))
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
  diagnostics.append(validate_imported_references(module_, object, modules))
  diagnostics
}

///|
fn validate_imported_references(
  module_ : CompiledModule,
  object : ModuleObject,
  modules : Array[CompiledModule],
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for imported in object.imports {
    match find_compiled_module(modules, imported.module_path_text) {
      Some(imported_module) =>
        if imported.fingerprint != imported_module.fingerprint {
          diagnostics.push(
            link_diagnostic(
              ImportedReferenceFingerprintMismatch(
                importer=module_.module_path_text,
                imported=imported.module_path_text,
                name=imported.name,
              ),
              None,
            ),
          )
        } else {
          match
            find_module_export(
              imported_module.object.exports,
              imported.kind,
              imported.name,
            ) {
            Some(item) =>
              if !imported_reference_shape_matches_export(imported, item) {
                diagnostics.push(
                  link_diagnostic(
                    ImportedReferenceMismatch(
                      importer=module_.module_path_text,
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
fn imported_reference_shape_matches_export(
  imported : ModuleImportedReference,
  item : @elaborate.BuslaneModuleExport,
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
fn validate_imported_exports(
  module_ : CompiledModule,
  imported : CompiledModule,
) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for value in imported.interface.values {
    if !module_exports_value(imported.object.exports, value.name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(
            kind="value",
            provider=imported.module_path_text,
            name=value.name,
            importer=module_.module_path_text,
          ),
          None,
        ),
      )
    }
  }
  for type_ in imported.interface.types {
    let name = interface_type_name(type_)
    if !module_exports_type(imported.object.exports, name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(
            kind="type",
            provider=imported.module_path_text,
            name~,
            importer=module_.module_path_text,
          ),
          None,
        ),
      )
    }
    let constructor_names = interface_type_constructors(type_)
    for constructor_name in constructor_names {
      if !module_exports_data_constructor(
          imported.object.exports,
          constructor_name,
        ) {
        diagnostics.push(
          link_diagnostic(
            MissingExported(
              kind="constructor",
              provider=imported.module_path_text,
              name=constructor_name,
              importer=module_.module_path_text,
            ),
            None,
          ),
        )
      }
    }
    for field_selector_name in interface_type_field_selectors(type_) {
      if !module_exports_field_selector(
          imported.object.exports,
          field_selector_name,
        ) {
        diagnostics.push(
          link_diagnostic(
            MissingExported(
              kind="field selector",
              provider=imported.module_path_text,
              name=field_selector_name,
              importer=module_.module_path_text,
            ),
            None,
          ),
        )
      }
    }
  }
  for effect in imported.interface.effects {
    if !module_exports_effect(imported.object.exports, effect.name) {
      diagnostics.push(
        link_diagnostic(
          MissingExported(
            kind="effect",
            provider=imported.module_path_text,
            name=effect.name,
            importer=module_.module_path_text,
          ),
          None,
        ),
      )
    }
    for operation in effect.operations {
      let operation_name = effect_operation_export_name(
        effect.name,
        operation.name,
      )
      if !module_exports_operation(imported.object.exports, operation_name) {
        diagnostics.push(
          link_diagnostic(
            MissingExported(
              kind="operation",
              provider=imported.module_path_text,
              name=operation_name,
              importer=module_.module_path_text,
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
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Value && item.name == name })
}

///|
fn module_exports_type(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Type && item.name == name })
}

///|
fn module_exports_data_constructor(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is DataConstructor && item.name == name })
}

///|
fn module_exports_effect(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Effect && item.name == name })
}

///|
fn module_exports_operation(
  exports : Array[@elaborate.BuslaneModuleExport],
  name : String,
) -> Bool {
  exports.any(fn(item) { item.kind is Operation && item.name == name })
}

///|
fn module_exports_field_selector(
  exports : Array[@elaborate.BuslaneModuleExport],
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
