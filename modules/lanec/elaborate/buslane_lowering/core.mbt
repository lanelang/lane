///|
pub fn lower_checked_source_file_to_buslane(
  source : @checked.CheckedSourceFile,
) -> @buslane.Program {
  lower_checked_source_file_to_buslane_result(source).program
}

///|
/// Lowers Checked Source into Buslane and returns compiler-owned side tables.
pub fn lower_checked_source_file_to_buslane_result(
  source : @checked.CheckedSourceFile,
) -> BuslaneLowerResult {
  lower_checked_source_files_to_buslane_result(source, [])
}

///|
/// Lowers a root checked module and already checked library modules into one
/// linked Buslane program. Only the root module contributes public entries.
pub fn lower_checked_source_files_to_buslane_result(
  root : @checked.CheckedSourceFile,
  libraries : Array[@checked.CheckedSourceFile],
) -> BuslaneLowerResult {
  let object_set = lower_checked_source_files_to_buslane_objects(
    libraries + [root],
  )
  let root_module_path_text = checked_module_path_text(root)
  let terms = []
  let builtins = []
  let runtime_imports = []
  let mut entries : Array[BuslaneEntry] = []
  for object in object_set.objects {
    terms.append(object.terms)
    builtins.append(object.externals.builtins)
    runtime_imports.append(object.externals.runtime_imports)
    if object.module_path_text == root_module_path_text {
      entries = object.entries
    }
  }
  {
    program: { metadata: object_set.objects[0].metadata, terms },
    externals: { builtins, runtime_imports },
    entries,
  }
}

///|
pub fn lower_checked_source_files_to_buslane_objects(
  sources : Array[@checked.CheckedSourceFile],
) -> BuslaneModuleObjectSet {
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  let module_entries : Array[ModuleEntries] = []
  for source in sources {
    lowerer.collect_type_headers(source)
  }
  for source in sources {
    lowerer.collect_effect_headers(source)
  }
  for source in sources {
    lowerer.collect_data_constructors(source)
  }
  for source in sources {
    lowerer.collect_effect_operations(source)
  }
  for source in sources {
    lowerer.collect_field_selectors(source)
  }
  for source in sources {
    let entry_start = lowerer.entries.length()
    lowerer.collect_top_values(source, include_entries=true)
    module_entries.push({
      module_path_text: checked_module_path_text(source),
      entries: buslane_entries_from(lowerer.entries, entry_start),
    })
  }
  let objects = []
  for source in sources {
    let external_start = lowerer.external_terms.length()
    let builtin_start = lowerer.builtin_externals.length()
    let runtime_import_start = lowerer.runtime_imports.length()
    let terms = lowerer.lower_top_terms(source)
    let external_terms = buslane_top_terms_from(
      lowerer.external_terms,
      external_start,
    )
    external_terms.append(terms)
    let module_path_text = checked_module_path_text(source)
    objects.push({
      module_path_text,
      metadata: lowerer.metadata,
      terms: external_terms,
      externals: {
        builtins: buslane_builtins_from(
          lowerer.builtin_externals,
          builtin_start,
        ),
        runtime_imports: buslane_runtime_imports_from(
          lowerer.runtime_imports,
          runtime_import_start,
        ),
      },
      entries: find_module_entries(module_entries, module_path_text),
      exports: lowerer.module_exports(source),
      imports: [],
    })
  }
  { objects, }
}

///|
pub fn lower_checked_source_file_to_buslane_object_with_imports(
  source : @checked.CheckedSourceFile,
  imported : BuslaneLoweringImports,
) -> Result[BuslaneModuleObject, BuslaneLoweringError] {
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  match lowerer.seed_imported_interfaces(imported) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  lowerer.collect_type_headers(source)
  lowerer.collect_effect_headers(source)
  lowerer.collect_data_constructors(source)
  lowerer.collect_effect_operations(source)
  lowerer.collect_field_selectors(source)
  lowerer.collect_top_values(source, include_entries=true)
  let external_start = lowerer.external_terms.length()
  let builtin_start = lowerer.builtin_externals.length()
  let runtime_import_start = lowerer.runtime_imports.length()
  let terms = lowerer.lower_top_terms(source)
  let external_terms = buslane_top_terms_from(
    lowerer.external_terms,
    external_start,
  )
  external_terms.append(terms)
  Ok({
    module_path_text: checked_module_path_text(source),
    metadata: lowerer.metadata,
    terms: external_terms,
    externals: {
      builtins: buslane_builtins_from(lowerer.builtin_externals, builtin_start),
      runtime_imports: buslane_runtime_imports_from(
        lowerer.runtime_imports,
        runtime_import_start,
      ),
    },
    entries: lowerer.entries,
    exports: lowerer.module_exports(source),
    imports: lowerer.imports,
  })
}

///|
fn checked_module_path_text(source : @checked.CheckedSourceFile) -> String {
  source.module_path.components.join(".")
}

///|
fn find_module_entries(
  module_entries : Array[ModuleEntries],
  module_path_text : String,
) -> Array[BuslaneEntry] {
  for entries in module_entries {
    if entries.module_path_text == module_path_text {
      return entries.entries
    }
  }
  []
}

///|
fn buslane_entries_from(
  entries : Array[BuslaneEntry],
  start : Int,
) -> Array[BuslaneEntry] {
  let result = []
  for index in start..<entries.length() {
    result.push(entries[index])
  }
  result
}

///|
fn buslane_top_terms_from(
  terms : Array[@buslane.TopTerm],
  start : Int,
) -> Array[@buslane.TopTerm] {
  let result = []
  for index in start..<terms.length() {
    result.push(terms[index])
  }
  result
}

///|
fn buslane_builtins_from(
  builtins : Array[BuslaneBuiltinExternal],
  start : Int,
) -> Array[BuslaneBuiltinExternal] {
  let result = []
  for index in start..<builtins.length() {
    result.push(builtins[index])
  }
  result
}

///|
fn buslane_runtime_imports_from(
  imports : Array[BuslaneRuntimeImport],
  start : Int,
) -> Array[BuslaneRuntimeImport] {
  let result = []
  for index in start..<imports.length() {
    result.push(imports[index])
  }
  result
}

///|
fn BuslaneLowerer::module_exports(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Array[BuslaneModuleExport] {
  let exports = []
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) if declaration.is_public => {
        exports.push({
          kind: Type,
          name: declaration.name,
          type_id: Some(self.type_id(declaration.symbol)),
          data_constructor: None,
          effect_id: None,
          operation: None,
          value: None,
        })
        exports.push({
          kind: DataConstructor,
          name: declaration.name,
          type_id: None,
          data_constructor: Some(self.struct_constructor_id(declaration.symbol)),
          effect_id: None,
          operation: None,
          value: None,
        })
        for field in declaration.fields {
          exports.push({
            kind: FieldSelector,
            name: field_selector_export_name(declaration.name, field.name),
            type_id: None,
            data_constructor: None,
            effect_id: None,
            operation: None,
            value: Some(self.field_selector_id(field.symbol)),
          })
        }
      }
      Enum(declaration) if declaration.is_public => {
        exports.push({
          kind: Type,
          name: declaration.name,
          type_id: Some(self.type_id(declaration.symbol)),
          data_constructor: None,
          effect_id: None,
          operation: None,
          value: None,
        })
        for variant in declaration.variants {
          exports.push({
            kind: DataConstructor,
            name: variant.name,
            type_id: None,
            data_constructor: Some(self.data_constructor_id(variant.symbol)),
            effect_id: None,
            operation: None,
            value: None,
          })
        }
      }
      ExternalType(declaration) if declaration.is_public =>
        exports.push({
          kind: Type,
          name: declaration.name,
          type_id: Some(self.type_id(declaration.symbol)),
          data_constructor: None,
          effect_id: None,
          operation: None,
          value: None,
        })
      Effect(declaration) if declaration.is_public => {
        exports.push({
          kind: Effect,
          name: declaration.name,
          type_id: None,
          data_constructor: None,
          effect_id: Some(self.effect_id(declaration.symbol)),
          operation: None,
          value: None,
        })
        for operation in declaration.operations {
          exports.push({
            kind: Operation,
            name: effect_operation_export_name(declaration.name, operation.name),
            type_id: None,
            data_constructor: None,
            effect_id: None,
            operation: Some(self.operation_id(operation.symbol)),
            value: None,
          })
        }
      }
      Function(declaration) if declaration.is_public =>
        exports.push({
          kind: Value,
          name: declaration.name,
          type_id: None,
          data_constructor: None,
          effect_id: None,
          operation: None,
          value: Some(self.value_id(declaration.symbol)),
        })
      Let(declaration) if declaration.is_public &&
        declaration.name is Some(name) =>
        exports.push({
          kind: Value,
          name,
          type_id: None,
          data_constructor: None,
          effect_id: None,
          operation: None,
          value: Some(self.value_id(declaration.symbol)),
        })
      _ => ()
    }
  }
  exports
}

///|
fn field_selector_export_name(
  type_name : String,
  field_name : String,
) -> String {
  type_name + "." + field_name
}

///|
fn effect_operation_export_name(
  effect_name : String,
  operation_name : String,
) -> String {
  effect_name + "." + operation_name
}
