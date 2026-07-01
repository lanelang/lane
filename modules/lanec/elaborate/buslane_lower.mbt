///|
priv struct TypeMapEntry {
  source : @symbol.TypeSymbolId
  target : @buslane.TypeId
}

///|
priv struct TypeParameterMapEntry {
  source : @symbol.TypeParameterId
  target : @buslane.TypeParameterId
}

///|
priv struct ValueMapEntry {
  source : @symbol.ValueSymbolId
  target : @buslane.ValueId
}

///|
priv struct DataConMapEntry {
  source : @symbol.VariantSymbolId
  target : @buslane.DataConId
}

///|
priv struct EffectMapEntry {
  source : @symbol.EffectSymbolId
  target : @buslane.EffectId
}

///|
priv struct OperationMapEntry {
  source : @symbol.OperationSymbolId
  target : @buslane.OperationId
}

///|
priv struct StructConMapEntry {
  source : @symbol.TypeSymbolId
  target : @buslane.DataConId
}

///|
priv struct FieldSelectorMapEntry {
  source : @symbol.FieldSymbolId
  target : @buslane.ValueId
}

///|
priv struct SelectorTermEntry {
  module_path_text : String
  term : @buslane.TopTerm
}

///|
priv struct ModuleEntries {
  module_path_text : String
  entries : Array[BuslaneEntry]
}

///|
priv struct BuslaneLowerer {
  metadata : @buslane.MetadataRegistry
  type_symbols : Array[TypeMapEntry]
  type_parameters : Array[TypeParameterMapEntry]
  values : Array[ValueMapEntry]
  data_constructors : Array[DataConMapEntry]
  effects : Array[EffectMapEntry]
  operations : Array[OperationMapEntry]
  struct_constructors : Array[StructConMapEntry]
  field_selectors : Array[FieldSelectorMapEntry]
  selector_terms : Array[SelectorTermEntry]
  external_terms : Array[@buslane.TopTerm]
  builtin_externals : Array[BuslaneBuiltinExternal]
  entries : Array[BuslaneEntry]
  imports : Array[BuslaneModuleImport]
}

///|
priv struct LowerPatternRow {
  patterns : Array[@checked.CheckedPattern]
  body : @buslane.Expr
}

///|
priv struct LoweredHandlerTable {
  handled_effect : @types.Effect
  operations : Array[LoweredOperationAlternative]
}

///|
priv struct LoweredOperationAlternative {
  operation : @symbol.OperationSymbolId
  payload_binders : Array[@buslane.ValueId]
  resume_binder : @buslane.ValueId
  body : @buslane.Expr
}

///|
priv struct LowerHandlerOperationGroup {
  operation : @symbol.OperationSymbolId
  payload_types : Array[@types.Type]
  resume_type : @types.Type
  arms : Array[@checked.CheckedHandlerOperationArm]
}

///|
priv struct LowerConstructorSignature {
  alt_constructor : @buslane.AltCon
  argument_types : Array[@types.Type]
  type_binders : Array[@buslane.TypeParameterId]
}

///|
fn BuslaneLowerer::BuslaneLowerer() -> BuslaneLowerer {
  {
    metadata: MetadataRegistry(),
    type_symbols: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    effects: [],
    operations: [],
    struct_constructors: [],
    field_selectors: [],
    selector_terms: [],
    external_terms: [],
    builtin_externals: [],
    entries: [],
    imports: [],
  }
}

///|
/// Lowers Checked Source into the Buslane Core Language.
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
  let mut entries : Array[BuslaneEntry] = []
  for object in object_set.objects {
    terms.append(object.terms)
    builtins.append(object.externals.builtins)
    if object.module_path_text == root_module_path_text {
      entries = object.entries
    }
  }
  {
    program: { metadata: object_set.objects[0].metadata, terms },
    externals: { builtins, },
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
  imported : @module_interface.ImportedEnvironment,
) -> BuslaneModuleObject {
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  lowerer.seed_imported_interfaces(imported)
  lowerer.collect_type_headers(source)
  lowerer.collect_effect_headers(source)
  lowerer.collect_data_constructors(source)
  lowerer.collect_effect_operations(source)
  lowerer.collect_field_selectors(source)
  lowerer.collect_top_values(source, include_entries=true)
  let external_start = lowerer.external_terms.length()
  let builtin_start = lowerer.builtin_externals.length()
  let terms = lowerer.lower_top_terms(source)
  let external_terms = buslane_top_terms_from(
    lowerer.external_terms,
    external_start,
  )
  external_terms.append(terms)
  {
    module_path_text: checked_module_path_text(source),
    metadata: lowerer.metadata,
    terms: external_terms,
    externals: {
      builtins: buslane_builtins_from(lowerer.builtin_externals, builtin_start),
    },
    entries: lowerer.entries,
    exports: lowerer.module_exports(source),
    imports: lowerer.imports,
  }
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
          value: None,
        })
        exports.push({
          kind: DataConstructor,
          name: declaration.name,
          type_id: None,
          data_constructor: Some(self.struct_constructor_id(declaration.symbol)),
          value: None,
        })
        for field in declaration.fields {
          exports.push({
            kind: FieldSelector,
            name: field_selector_export_name(declaration.name, field.name),
            type_id: None,
            data_constructor: None,
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
          value: None,
        })
        for variant in declaration.variants {
          exports.push({
            kind: DataConstructor,
            name: variant.name,
            type_id: None,
            data_constructor: Some(self.data_constructor_id(variant.symbol)),
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
          value: Some(self.value_id(declaration.symbol)),
        })
      Let(declaration) if declaration.is_public &&
        declaration.name is Some(name) =>
        exports.push({
          kind: Value,
          name,
          type_id: None,
          data_constructor: None,
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
fn BuslaneLowerer::seed_imported_interfaces(
  self : BuslaneLowerer,
  imported : @module_interface.ImportedEnvironment,
) -> Unit {
  for interface in imported.modules {
    for type_ in interface.types {
      self.seed_imported_type_header(interface.module_path, type_)
    }
  }
  for interface in imported.modules {
    for type_ in interface.types {
      self.seed_imported_type_constructors(interface.module_path, type_)
    }
  }
  for interface in imported.modules {
    for effect in interface.effects {
      self.seed_imported_effect_header(interface.module_path, effect)
    }
  }
  for interface in imported.modules {
    for effect in interface.effects {
      self.seed_imported_effect_operations(interface.module_path, effect)
    }
  }
  for interface in imported.modules {
    for value in interface.values {
      self.seed_imported_value(interface.module_path, value)
    }
  }
}

///|
fn BuslaneLowerer::seed_imported_type_header(
  self : BuslaneLowerer,
  module_path_text : String,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit {
  match type_ {
    Struct(declaration) => {
      let parameters = declaration.type_parameters.map(fn(parameter) {
        self.define_type_parameter(parameter)
      })
      for type_member in declaration.type_members {
        ignore(self.define_type_parameter(type_member.type_parameter))
      }
      let target = self.metadata.define_type(parameters)
      self.type_symbols.push({ source: declaration.symbol, target })
      self.imports.push({
        module_path_text,
        kind: Type,
        name: declaration.name,
        type_id: Some(target),
        data_constructor: None,
        value: None,
      })
    }
    Enum(declaration) => {
      let parameters = declaration.type_parameters.map(fn(parameter) {
        self.define_type_parameter(parameter)
      })
      for variant in declaration.variants {
        for parameter in variant.type_parameters {
          ignore(self.define_type_parameter(parameter))
        }
      }
      let target = self.metadata.define_type(parameters)
      self.type_symbols.push({ source: declaration.symbol, target })
      self.imports.push({
        module_path_text,
        kind: Type,
        name: declaration.name,
        type_id: Some(target),
        data_constructor: None,
        value: None,
      })
    }
  }
}

///|
fn BuslaneLowerer::seed_imported_type_constructors(
  self : BuslaneLowerer,
  module_path_text : String,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit {
  match type_ {
    Struct(declaration) => {
      let owner = self.type_id(declaration.symbol)
      let hidden_type_parameters = declaration.type_members.map(fn(
        type_member,
      ) {
        self.define_type_parameter(type_member.type_parameter)
      })
      let payload_types = declaration.fields.map(fn(field) {
        self.lower_type(field.type_)
      })
      let data_constructor = self.metadata.define_data_constructor(
        owner, hidden_type_parameters, payload_types,
      )
      self.struct_constructors.push({
        source: declaration.symbol,
        target: data_constructor,
      })
      self.imports.push({
        module_path_text,
        kind: DataConstructor,
        name: declaration.name,
        type_id: None,
        data_constructor: Some(data_constructor),
        value: None,
      })
      for field in declaration.fields {
        self.seed_imported_field_selector(module_path_text, declaration, field)
      }
    }
    Enum(declaration) => {
      let owner = self.type_id(declaration.symbol)
      for variant in declaration.variants {
        let hidden_type_parameters = variant.type_parameters.map(fn(parameter) {
          self.define_type_parameter(parameter)
        })
        let payload_types = variant.payload.map(fn(type_) {
          self.lower_type(type_)
        })
        let data_constructor = self.metadata.define_data_constructor(
          owner, hidden_type_parameters, payload_types,
        )
        self.data_constructors.push({
          source: variant.symbol,
          target: data_constructor,
        })
        self.imports.push({
          module_path_text,
          kind: DataConstructor,
          name: variant.name,
          type_id: None,
          data_constructor: Some(data_constructor),
          value: None,
        })
      }
    }
  }
}

///|
fn BuslaneLowerer::seed_imported_field_selector(
  self : BuslaneLowerer,
  module_path_text : String,
  declaration : @module_interface.ModuleInterfaceStruct,
  field : @module_interface.ModuleInterfaceField,
) -> Unit {
  let selector_type = self.imported_selector_type(declaration, field)
  let selector = self.metadata.define_value(Function, selector_type)
  self.field_selectors.push({ source: field.symbol, target: selector })
  self.imports.push({
    module_path_text,
    kind: FieldSelector,
    name: field_selector_export_name(declaration.name, field.name),
    type_id: None,
    data_constructor: None,
    value: Some(selector),
  })
}

///|
fn BuslaneLowerer::imported_selector_type(
  self : BuslaneLowerer,
  declaration : @module_interface.ModuleInterfaceStruct,
  field : @module_interface.ModuleInterfaceField,
) -> @buslane.Type {
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    type_parameters.push(self.define_type_parameter(type_member.type_parameter))
  }
  let receiver = buslane_nominal_type(
    self.type_id(declaration.symbol),
    declaration.type_parameters.map(fn(parameter) {
      Parameter(self.type_parameter_id(parameter.id))
    }),
  )
  let function = @buslane.Type::Function(
    [receiver],
    self.lower_type(field.type_),
    Empty,
  )
  if type_parameters.is_empty() {
    function
  } else {
    Forall(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::seed_imported_effect_header(
  self : BuslaneLowerer,
  module_path_text : String,
  effect : @module_interface.ModuleInterfaceEffect,
) -> Unit {
  let parameters = effect.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  let target = self.metadata.define_effect(parameters)
  self.effects.push({ source: effect.symbol, target })
  ignore(module_path_text)
}

///|
fn BuslaneLowerer::seed_imported_effect_operations(
  self : BuslaneLowerer,
  module_path_text : String,
  effect : @module_interface.ModuleInterfaceEffect,
) -> Unit {
  let owner = self.effect_id(effect.symbol)
  for operation in effect.operations {
    ignore(
      self.define_operation(
        operation.symbol,
        owner,
        operation.type_parameters,
        operation.payload,
        operation.result,
      ),
    )
  }
  ignore(module_path_text)
}

///|
fn BuslaneLowerer::seed_imported_value(
  self : BuslaneLowerer,
  module_path_text : String,
  value : @module_interface.ModuleInterfaceValue,
) -> Unit {
  let type_ = self.lower_type(value.type_)
  let kind : @buslane.ValueKind = match value.kind {
    Function => Function
    Let | Offer => Value
  }
  let target = self.define_value(value.symbol, kind, type_)
  self.imports.push({
    module_path_text,
    kind: Value,
    name: value.name,
    type_id: None,
    data_constructor: None,
    value: Some(target),
  })
}

///|
fn BuslaneLowerer::collect_type_headers(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => self.collect_struct_header(declaration)
      Enum(declaration) => self.collect_enum_header(declaration)
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::add_entry(
  self : BuslaneLowerer,
  name : String,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> Unit {
  self.entries.push({ name, value, type_ })
}

///|
fn BuslaneLowerer::collect_struct_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    ignore(self.define_type_parameter(type_member.type_parameter))
  }
  let target = self.metadata.define_type(parameters)
  self.type_symbols.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_enum_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEnumDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for variant in declaration.variants {
    for parameter in variant.type_parameters {
      ignore(self.define_type_parameter(parameter))
    }
  }
  let target = self.metadata.define_type(parameters)
  self.type_symbols.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_effect_headers(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    if declaration is Effect(declaration) {
      self.collect_effect_header(declaration)
    }
  }
}

///|
fn BuslaneLowerer::collect_effect_header(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEffectDeclaration,
) -> Unit {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  let target = self.metadata.define_effect(parameters)
  self.effects.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_data_constructors(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => self.collect_struct_constructor(declaration)
      Enum(declaration) => self.collect_enum_constructors(declaration)
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::collect_struct_constructor(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Unit {
  let owner = self.type_id(declaration.symbol)
  let hidden_type_parameters = declaration.type_members.map(fn(type_member) {
    self.define_type_parameter(type_member.type_parameter)
  })
  let payload_types = declaration.fields.map(fn(field) {
    self.lower_type(field.type_)
  })
  let target = self.metadata.define_data_constructor(
    owner, hidden_type_parameters, payload_types,
  )
  self.struct_constructors.push({ source: declaration.symbol, target })
}

///|
fn BuslaneLowerer::collect_enum_constructors(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEnumDeclaration,
) -> Unit {
  let owner = self.type_id(declaration.symbol)
  for variant in declaration.variants {
    let hidden_type_parameters = variant.type_parameters.map(fn(parameter) {
      self.define_type_parameter(parameter)
    })
    let payload_types = variant.payload.map(fn(type_) { self.lower_type(type_) })
    let target = self.metadata.define_data_constructor(
      owner, hidden_type_parameters, payload_types,
    )
    self.data_constructors.push({ source: variant.symbol, target })
  }
}

///|
fn BuslaneLowerer::collect_effect_operations(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  for declaration in source.declarations {
    if declaration is Effect(declaration) {
      self.collect_effect_operation_declarations(declaration)
    }
  }
}

///|
fn BuslaneLowerer::collect_effect_operation_declarations(
  self : BuslaneLowerer,
  declaration : @checked.CheckedEffectDeclaration,
) -> Unit {
  let owner = self.effect_id(declaration.symbol)
  for operation in declaration.operations {
    ignore(
      self.define_operation(
        operation.symbol,
        owner,
        operation.type_parameters,
        operation.payload,
        operation.result,
      ),
    )
  }
}

///|
fn BuslaneLowerer::collect_field_selectors(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Unit {
  let module_path_text = checked_module_path_text(source)
  for declaration in source.declarations {
    if declaration is Struct(declaration) {
      for index in 0..<declaration.fields.length() {
        self.collect_field_selector(module_path_text, declaration, index)
      }
    }
  }
}

///|
fn BuslaneLowerer::collect_field_selector(
  self : BuslaneLowerer,
  module_path_text : String,
  declaration : @checked.CheckedStructDeclaration,
  field_index : Int,
) -> Unit {
  let field = declaration.fields[field_index]
  let type_parameters = self.selector_type_parameters(declaration)
  let selector_type = self.selector_type(declaration, field)
  let selector = self.metadata.define_value(Function, selector_type)
  self.field_selectors.push({ source: field.symbol, target: selector })
  self.selector_terms.push({
    module_path_text,
    term: Let(
      selector,
      self.selector_body(declaration, field_index, type_parameters),
    ),
  })
}

///|
fn BuslaneLowerer::selector_type_parameters(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> Array[@buslane.TypeParameterId] {
  let parameters = declaration.type_parameters.map(fn(parameter) {
    self.define_type_parameter(parameter)
  })
  for type_member in declaration.type_members {
    parameters.push(self.define_type_parameter(type_member.type_parameter))
  }
  parameters
}

///|
fn BuslaneLowerer::selector_type(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field : @checked.CheckedFieldDeclaration,
) -> @buslane.Type {
  let function = @buslane.Type::Function(
    [self.selector_receiver_type(declaration)],
    self.lower_type(field.type_),
    Empty,
  )
  let type_parameters = self.selector_type_parameters(declaration)
  if type_parameters.is_empty() {
    function
  } else {
    Forall(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::selector_receiver_type(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
) -> @buslane.Type {
  buslane_nominal_type(
    self.type_id(declaration.symbol),
    declaration.type_parameters.map(fn(parameter) {
      Parameter(self.type_parameter_id(parameter.id))
    }),
  )
}

///|
fn BuslaneLowerer::selector_body(
  self : BuslaneLowerer,
  declaration : @checked.CheckedStructDeclaration,
  field_index : Int,
  type_parameters : Array[@buslane.TypeParameterId],
) -> @buslane.Expr {
  let receiver_type = self.selector_receiver_type(declaration)
  let receiver = self.metadata.define_value(Parameter, receiver_type)
  let result_type = self.lower_type(declaration.fields[field_index].type_)
  let match_binder = self.metadata.define_value(MatchBinder, receiver_type)
  let value_binders = declaration.fields.map(fn(field) {
    self.metadata.define_value(MatchBinder, self.lower_type(field.type_))
  })
  let function = @buslane.Expr::Function({
    parameters: [receiver],
    result_type,
    body: Match({
      scrutinee: Ref(receiver),
      binder: match_binder,
      result_type,
      alternatives: [
        {
          alt_constructor: DataCon(
            self.struct_constructor_id(declaration.symbol),
          ),
          type_binders: declaration.type_members.map(fn(type_member) {
            self.type_parameter_id(type_member.type_parameter.id)
          }),
          value_binders,
          body: Ref(value_binders[field_index]),
        },
      ],
    }),
  })
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::collect_top_values(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
  include_entries~ : Bool,
) -> Unit {
  for declaration in source.declarations {
    match declaration {
      Function(declaration) => {
        for parameter in declaration.type_parameters {
          ignore(self.define_type_parameter(parameter))
        }
        let type_ = self.lower_type(declaration.type_)
        let value = self.define_value(declaration.symbol, Function, type_)
        if include_entries && declaration.is_public {
          self.add_entry(declaration.name, value, type_)
        }
      }
      Let(declaration) => {
        let type_ = self.lower_type(declaration.type_)
        let value = self.define_value(declaration.symbol, Value, type_)
        if include_entries && declaration.is_public {
          if declaration.name is Some(name) {
            self.add_entry(name, value, type_)
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn BuslaneLowerer::lower_top_terms(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
) -> Array[@buslane.TopTerm] {
  let terms : Array[@buslane.TopTerm] = []
  for selector in self.selector_terms {
    if selector.module_path_text == checked_module_path_text(source) {
      terms.push(selector.term)
    }
  }
  let recursive_functions : Array[@buslane.RecursiveBinding] = []
  for declaration in source.declarations {
    if declaration is Function(function) {
      recursive_functions.push(self.lower_recursive_function(function))
    }
  }
  if !recursive_functions.is_empty() {
    terms.push(LetRec(recursive_functions))
  }
  for declaration in source.declarations {
    if declaration is Let(declaration) {
      terms.push(
        Let(
          self.value_id(declaration.symbol),
          self.lower_expr(declaration.initializer),
        ),
      )
    }
  }
  terms
}

///|
fn BuslaneLowerer::lower_recursive_function(
  self : BuslaneLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> @buslane.RecursiveBinding {
  {
    id: self.value_id(declaration.symbol),
    rhs: self.lower_function_declaration(declaration),
  }
}

///|
fn BuslaneLowerer::lower_function_declaration(
  self : BuslaneLowerer,
  declaration : @checked.CheckedFunctionDeclaration,
) -> @buslane.Expr {
  for parameter in declaration.type_parameters {
    ignore(self.define_type_parameter(parameter))
  }
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.type_parameter_id(parameter.id)
  })
  let function = @buslane.Expr::Function({
    parameters: declaration.parameters.map(fn(parameter) {
      self.define_value(
        parameter.symbol,
        Parameter,
        self.lower_type(parameter.type_),
      )
    }),
    result_type: self.lower_type(declaration.return_type),
    body: self.lower_expr(declaration.body),
  })
  if type_parameters.is_empty() {
    function
  } else {
    TypeLambda(type_parameters, function)
  }
}

///|
fn BuslaneLowerer::lower_expr(
  self : BuslaneLowerer,
  expression : @checked.CheckedExpr,
) -> @buslane.Expr {
  match expression {
    Literal(literal~, ..) => Literal(lower_literal(literal))
    Value(symbol~, ..) => Ref(self.value_id(symbol))
    UnsafeBuiltin(name~, type_~, ..) =>
      Ref(self.define_builtin_external(name, self.lower_type(type_)))
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) =>
      self.lower_function_literal(
        type_parameters, parameters, return_type, body,
      )
    TypeApplication(callee~, arguments~, ..) =>
      TypeApply(
        self.lower_expr(callee),
        arguments.map(fn(argument) { self.lower_type(argument) }),
      )
    Block(items~, result~, ..) => self.lower_items(items, 0, result)
    If(condition~, then_branch~, else_branch~, type_~, ..) =>
      self.lower_if(condition, then_branch, else_branch, type_)
    Match(scrutinee~, arms~, type_~, ..) =>
      self.lower_match(scrutinee, arms, type_)
    Call(callee~, arguments~, ..) =>
      Call(
        self.lower_expr(callee),
        arguments.map(fn(argument) { self.lower_expr(argument) }),
      )
    OperationCall(operation~, arguments~, effect~, ..) =>
      Perform({
        operation: self.operation_id(operation),
        type_arguments: self.perform_type_arguments(effect),
        payloads: arguments.map(fn(argument) { self.lower_expr(argument) }),
      })
    Handler(handlers~, type_~, ..) => {
      lower_handler_tables_boundary(
        self.lower_handler_tables_for_alternatives(handlers, type_),
      )
      abort("Lane handler lowering to Buslane is not implemented yet")
    }
    Field(base~, field~, ..) => self.lower_field(base, field)
    StructLiteral(symbol~, type_arguments~, type_witnesses~, fields~, ..) =>
      Construct({
        data_constructor: self.struct_constructor_id(symbol),
        type_arguments: type_arguments.map(fn(argument) {
          self.lower_type(argument)
        }),
        hidden_witnesses: type_witnesses.map(fn(witness) {
          self.lower_type(witness.type_)
        }),
        payloads: fields.map(fn(field) { self.lower_expr(field.value) }),
      })
    Variant(symbol~, type_arguments~, arguments~, type_~, ..) =>
      Construct({
        data_constructor: self.data_constructor_id(symbol),
        type_arguments: self.nominal_type_arguments(type_),
        hidden_witnesses: type_arguments.map(fn(argument) {
          self.lower_type(argument)
        }),
        payloads: arguments.map(fn(argument) { self.lower_expr(argument) }),
      })
  }
}

///|
fn BuslaneLowerer::lower_handler_tables_for_alternatives(
  self : BuslaneLowerer,
  handlers : Array[@checked.CheckedHandlerTable],
  result_type : @types.Type,
) -> Array[LoweredHandlerTable] {
  handlers.map(fn(handler) {
    {
      handled_effect: handler.handled_effect,
      operations: self.lower_handler_operation_groups(
        lower_handler_operation_groups(handler.operations),
        result_type,
      ),
    }
  })
}

///|
fn lower_handler_tables_boundary(tables : Array[LoweredHandlerTable]) -> Unit {
  for table in tables {
    ignore(table.handled_effect)
    for operation in table.operations {
      ignore(operation.operation)
      ignore(operation.payload_binders)
      ignore(operation.resume_binder)
      ignore(operation.body)
    }
  }
}

///|
fn lower_handler_operation_groups(
  operations : Array[@checked.CheckedHandlerOperationArm],
) -> Array[LowerHandlerOperationGroup] {
  let groups = []
  for operation in operations {
    match lower_handler_operation_group_index(groups, operation.operation) {
      Some(index) => groups[index].arms.push(operation)
      None =>
        groups.push({
          operation: operation.operation,
          payload_types: operation.payload_types,
          resume_type: operation.resume_type,
          arms: [operation],
        })
    }
  }
  groups
}

///|
fn lower_handler_operation_group_index(
  groups : Array[LowerHandlerOperationGroup],
  operation : @symbol.OperationSymbolId,
) -> Int? {
  for index in 0..<groups.length() {
    if groups[index].operation == operation {
      return Some(index)
    }
  }
  None
}

///|
fn BuslaneLowerer::lower_handler_operation_groups(
  self : BuslaneLowerer,
  groups : Array[LowerHandlerOperationGroup],
  result_type : @types.Type,
) -> Array[LoweredOperationAlternative] {
  groups.map(fn(group) {
    self.lower_handler_operation_group(group, result_type)
  })
}

///|
fn BuslaneLowerer::lower_handler_operation_group(
  self : BuslaneLowerer,
  group : LowerHandlerOperationGroup,
  result_type : @types.Type,
) -> LoweredOperationAlternative {
  let payload_binders = group.payload_types.map(fn(type_) {
    self.define_fresh_value(Parameter, self.lower_type(type_))
  })
  let resume_binder = self.define_fresh_value(
    Parameter,
    self.lower_type(group.resume_type),
  )
  let rows = group.arms.map(fn(arm) {
    self.bind_value_alias(arm.resume_symbol, resume_binder)
    for pattern in arm.payload_patterns {
      self.define_pattern_binders(pattern)
    }
    guard arm.body is Some(body) else {
      abort("unchecked handler operation body")
    }
    { patterns: arm.payload_patterns, body: self.lower_expr(body) }
  })
  {
    operation: group.operation,
    payload_binders,
    resume_binder,
    body: self.lower_pattern_decision(
      payload_binders.map(fn(binder) { Ref(binder) }),
      payload_binders,
      rows,
      group.payload_types,
      self.lower_type(result_type),
    ),
  }
}

///|
fn BuslaneLowerer::lower_function_literal(
  self : BuslaneLowerer,
  type_parameters : Array[@types.TypeParameter],
  parameters : Array[@checked.CheckedValueParameter],
  return_type : @types.Type,
  body : @checked.CheckedExpr,
) -> @buslane.Expr {
  for parameter in type_parameters {
    ignore(self.define_type_parameter(parameter))
  }
  let lowered_type_parameters = type_parameters.map(fn(parameter) {
    self.type_parameter_id(parameter.id)
  })
  let function = @buslane.Expr::Function({
    parameters: parameters.map(fn(parameter) {
      self.define_value(
        parameter.symbol,
        Local,
        self.lower_type(parameter.type_),
      )
    }),
    result_type: self.lower_type(return_type),
    body: self.lower_expr(body),
  })
  if lowered_type_parameters.is_empty() {
    function
  } else {
    TypeLambda(lowered_type_parameters, function)
  }
}

///|
fn BuslaneLowerer::lower_items(
  self : BuslaneLowerer,
  items : Array[@checked.CheckedLocalItem],
  index : Int,
  result : @checked.CheckedExpr,
) -> @buslane.Expr {
  if index >= items.length() {
    self.lower_expr(result)
  } else {
    match items[index] {
      Let(declaration) => {
        let id = self.define_value(
          declaration.symbol,
          Local,
          self.lower_type(declaration.type_),
        )
        Let(
          id,
          self.lower_expr(declaration.initializer),
          self.lower_items(items, index + 1, result),
        )
      }
      Function(declaration) => {
        let id = self.define_value(
          declaration.symbol,
          Local,
          self.lower_type(declaration.type_),
        )
        LetRec(
          [{ id, rhs: self.lower_function_declaration(declaration) }],
          self.lower_items(items, index + 1, result),
        )
      }
      PatternLet(declaration) => {
        self.define_pattern_binders(declaration.pattern)
        let initializer = self.lower_expr(declaration.initializer)
        let result_type = self.lower_type(result.type_())
        let body = self.lower_items(items, index + 1, result)
        self.lower_pattern_as_match(
          declaration.pattern,
          initializer,
          body,
          result_type,
        )
      }
    }
  }
}

///|
fn BuslaneLowerer::lower_if(
  self : BuslaneLowerer,
  condition : @checked.CheckedExpr,
  then_branch : @checked.CheckedExpr,
  else_branch : @checked.CheckedExpr,
  result_type : @types.Type,
) -> @buslane.Expr {
  let binder = self.define_fresh_value(MatchBinder, Primitive(Bool))
  Match({
    scrutinee: self.lower_expr(condition),
    binder,
    result_type: self.lower_type(result_type),
    alternatives: [
      {
        alt_constructor: Literal(Bool(true)),
        type_binders: [],
        value_binders: [],
        body: self.lower_expr(then_branch),
      },
      {
        alt_constructor: Literal(Bool(false)),
        type_binders: [],
        value_binders: [],
        body: self.lower_expr(else_branch),
      },
    ],
  })
}

///|
fn BuslaneLowerer::lower_match(
  self : BuslaneLowerer,
  scrutinee : @checked.CheckedExpr,
  arms : Array[@checked.CheckedMatchArm],
  result_type : @types.Type,
) -> @buslane.Expr {
  let binder = self.define_fresh_value(
    MatchBinder,
    self.lower_type(scrutinee.type_()),
  )
  let rows = arms.map(fn(arm) {
    self.define_pattern_binders(arm.pattern)
    { patterns: [arm.pattern], body: self.lower_expr(arm.body) }
  })
  self.lower_pattern_decision(
    [self.lower_expr(scrutinee)],
    [binder],
    rows,
    [scrutinee.type_()],
    self.lower_type(result_type),
  )
}

///|
fn BuslaneLowerer::lower_pattern_as_match(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
  initializer : @buslane.Expr,
  body : @buslane.Expr,
  result_type : @buslane.Type,
) -> @buslane.Expr {
  self.define_pattern_binders(pattern)
  let binder = self.define_fresh_value(
    MatchBinder,
    self.lower_type(pattern.type_()),
  )
  self.lower_pattern_decision(
    [initializer],
    [binder],
    [{ patterns: [pattern], body }],
    [pattern.type_()],
    result_type,
  )
}

///|
fn BuslaneLowerer::lower_pattern_decision(
  self : BuslaneLowerer,
  scrutinees : Array[@buslane.Expr],
  binders : Array[@buslane.ValueId],
  rows : Array[LowerPatternRow],
  types : Array[@types.Type],
  result_type : @buslane.Type,
) -> @buslane.Expr {
  if types.is_empty() {
    guard rows.get(0) is Some(row) else { abort("empty pattern decision") }
    return row.body
  }
  guard scrutinees.get(0) is Some(scrutinee) else {
    abort("missing pattern scrutinee")
  }
  guard binders.get(0) is Some(binder) else { abort("missing pattern binder") }
  guard types.get(0) is Some(type_) else { abort("missing pattern type") }
  let constructors = self.lower_first_column_signatures(rows)
  if constructors.is_empty() {
    return self.lower_pattern_decision(
      buslane_expr_tail(scrutinees),
      buslane_value_tail(binders),
      self.lower_default_rows(rows, binder),
      lower_type_tail(types),
      result_type,
    )
  }
  let alternatives = constructors.map(fn(signature) {
    self.lower_constructor_decision_alternative(
      signature, scrutinees, binders, rows, types, result_type,
    )
  })
  if !self.lower_constructor_set_complete(type_, constructors) {
    let default_rows = self.lower_default_rows(rows, binder)
    if !default_rows.is_empty() {
      alternatives.push({
        alt_constructor: Default,
        type_binders: [],
        value_binders: [],
        body: self.lower_pattern_decision(
          buslane_expr_tail(scrutinees),
          buslane_value_tail(binders),
          default_rows,
          lower_type_tail(types),
          result_type,
        ),
      })
    }
  }
  Match({ scrutinee, binder, result_type, alternatives })
}

///|
fn BuslaneLowerer::lower_constructor_decision_alternative(
  self : BuslaneLowerer,
  signature : LowerConstructorSignature,
  scrutinees : Array[@buslane.Expr],
  binders : Array[@buslane.ValueId],
  rows : Array[LowerPatternRow],
  types : Array[@types.Type],
  result_type : @buslane.Type,
) -> @buslane.Alternative {
  guard binders.get(0) is Some(binder) else {
    abort("missing constructor binder")
  }
  let value_binders = signature.argument_types.map(fn(type_) {
    self.define_fresh_value(MatchBinder, self.lower_type(type_))
  })
  let payload_refs = value_binders.map(fn(value) { @buslane.Expr::Ref(value) })
  {
    alt_constructor: signature.alt_constructor,
    type_binders: signature.type_binders,
    value_binders,
    body: self.lower_pattern_decision(
      buslane_expr_concat(payload_refs, buslane_expr_tail(scrutinees)),
      buslane_value_concat(value_binders, buslane_value_tail(binders)),
      self.lower_specialized_rows(rows, binder, signature),
      lower_type_concat(signature.argument_types, lower_type_tail(types)),
      result_type,
    ),
  }
}

///|
fn BuslaneLowerer::lower_first_column_signatures(
  self : BuslaneLowerer,
  rows : Array[LowerPatternRow],
) -> Array[LowerConstructorSignature] {
  let signatures = []
  for row in rows {
    guard row.patterns.get(0) is Some(pattern) else { continue }
    guard self.lower_signature_for_pattern(pattern) is Some(signature) else {
      continue
    }
    if !lower_signature_contains(signatures, signature.alt_constructor) {
      signatures.push(signature)
    }
  }
  signatures
}

///|
fn BuslaneLowerer::lower_specialized_rows(
  self : BuslaneLowerer,
  rows : Array[LowerPatternRow],
  binder : @buslane.ValueId,
  signature : LowerConstructorSignature,
) -> Array[LowerPatternRow] {
  let specialized = []
  for row in rows {
    if self.lower_specialized_row(row, binder, signature) is Some(row) {
      specialized.push(row)
    }
  }
  specialized
}

///|
fn BuslaneLowerer::lower_specialized_row(
  self : BuslaneLowerer,
  row : LowerPatternRow,
  binder : @buslane.ValueId,
  signature : LowerConstructorSignature,
) -> LowerPatternRow? {
  guard row.patterns.get(0) is Some(head) else { return None }
  let tail = checked_pattern_tail(row.patterns)
  match head {
    Wildcard(..) =>
      Some({
        patterns: checked_pattern_concat(
          wildcard_checked_patterns(signature.argument_types),
          tail,
        ),
        body: row.body,
      })
    Binding(..) =>
      Some({
        patterns: checked_pattern_concat(
          wildcard_checked_patterns(signature.argument_types),
          tail,
        ),
        body: self.lower_bind_whole_pattern(head, binder, row.body),
      })
    _ if self.lower_signature_for_pattern(head) is Some(head_signature) &&
      head_signature.alt_constructor == signature.alt_constructor =>
      Some({
        patterns: checked_pattern_concat(
          lower_constructor_arguments_for_pattern(head),
          tail,
        ),
        body: row.body,
      })
    _ => None
  }
}

///|
fn BuslaneLowerer::lower_default_rows(
  self : BuslaneLowerer,
  rows : Array[LowerPatternRow],
  binder : @buslane.ValueId,
) -> Array[LowerPatternRow] {
  let default_rows = []
  for row in rows {
    guard row.patterns.get(0) is Some(pattern) else { continue }
    if pattern is Wildcard(..) {
      default_rows.push({
        patterns: checked_pattern_tail(row.patterns),
        body: row.body,
      })
    } else if pattern is Binding(..) {
      default_rows.push({
        patterns: checked_pattern_tail(row.patterns),
        body: self.lower_bind_whole_pattern(pattern, binder, row.body),
      })
    }
  }
  default_rows
}

///|
fn BuslaneLowerer::lower_bind_whole_pattern(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
  binder : @buslane.ValueId,
  body : @buslane.Expr,
) -> @buslane.Expr {
  if pattern is Binding(symbol~, ..) && self.value_id(symbol) != binder {
    Let(self.value_id(symbol), Ref(binder), body)
  } else {
    body
  }
}

///|
fn BuslaneLowerer::lower_signature_for_pattern(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
) -> LowerConstructorSignature? {
  match pattern {
    Wildcard(..) | Binding(..) => None
    Literal(literal~, ..) =>
      Some({
        alt_constructor: Literal(lower_literal(literal)),
        argument_types: [],
        type_binders: [],
      })
    Variant(symbol~, type_arguments~, arguments~, ..) => {
      let data_constructor = self.data_constructor_id(symbol)
      Some({
        alt_constructor: DataCon(data_constructor),
        argument_types: arguments.map(fn(argument) { argument.type_() }),
        type_binders: self.lower_pattern_type_binders(
          data_constructor, type_arguments,
        ),
      })
    }
    Struct(symbol~, type_binders~, fields~, ..) => {
      let lowered_type_binders : Array[@buslane.TypeParameterId] = []
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          lowered_type_binders.push(self.define_type_parameter(parameter))
        }
      }
      Some({
        alt_constructor: DataCon(self.struct_constructor_id(symbol)),
        argument_types: fields.map(fn(field) { field.pattern.type_() }),
        type_binders: lowered_type_binders,
      })
    }
  }
}

///|
fn lower_constructor_arguments_for_pattern(
  pattern : @checked.CheckedPattern,
) -> Array[@checked.CheckedPattern] {
  match pattern {
    Variant(arguments~, ..) => arguments
    Struct(fields~, ..) => fields.map(fn(field) { field.pattern })
    _ => []
  }
}

///|
fn BuslaneLowerer::lower_constructor_set_complete(
  self : BuslaneLowerer,
  type_ : @types.Type,
  constructors : Array[LowerConstructorSignature],
) -> Bool {
  if self.complete_alt_constructors_for_type(type_) is Some(complete) {
    !complete.is_empty() &&
    complete.all(fn(alt_constructor) {
      lower_signature_contains(constructors, alt_constructor)
    })
  } else {
    false
  }
}

///|
fn BuslaneLowerer::complete_alt_constructors_for_type(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> Array[@buslane.AltCon]? {
  if type_.decompose_nominal() is Some((symbol, _)) {
    if self.metadata.type_info(self.type_id(symbol)) is Some(info) {
      return Some(
        info.constructors.map(fn(data_constructor) { DataCon(data_constructor) }),
      )
    }
    return None
  }
  match type_ {
    Error => Some([])
    Primitive(Bool) => Some([Literal(Bool(false)), Literal(Bool(true))])
    Primitive(Unit) => Some([Literal(Unit)])
    Primitive(Int) | Primitive(String) => None
    _ => None
  }
}

///|
fn lower_signature_contains(
  signatures : Array[LowerConstructorSignature],
  alt_constructor : @buslane.AltCon,
) -> Bool {
  signatures.any(fn(signature) { signature.alt_constructor == alt_constructor })
}

///|
fn wildcard_checked_patterns(
  types : Array[@types.Type],
) -> Array[@checked.CheckedPattern] {
  types.map(fn(type_) { Wildcard(type_~, loc=@basic.SourceSpan::dummy()) })
}

///|
fn checked_pattern_tail(
  patterns : Array[@checked.CheckedPattern],
) -> Array[@checked.CheckedPattern] {
  let tail = []
  for index in 1..<patterns.length() {
    tail.push(patterns[index])
  }
  tail
}

///|
fn checked_pattern_concat(
  head : Array[@checked.CheckedPattern],
  tail : Array[@checked.CheckedPattern],
) -> Array[@checked.CheckedPattern] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn lower_type_tail(types : Array[@types.Type]) -> Array[@types.Type] {
  let tail = []
  for index in 1..<types.length() {
    tail.push(types[index])
  }
  tail
}

///|
fn lower_type_concat(
  head : Array[@types.Type],
  tail : Array[@types.Type],
) -> Array[@types.Type] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn buslane_expr_tail(
  expressions : Array[@buslane.Expr],
) -> Array[@buslane.Expr] {
  let tail = []
  for index in 1..<expressions.length() {
    tail.push(expressions[index])
  }
  tail
}

///|
fn buslane_expr_concat(
  head : Array[@buslane.Expr],
  tail : Array[@buslane.Expr],
) -> Array[@buslane.Expr] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn buslane_value_tail(
  values : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let tail = []
  for index in 1..<values.length() {
    tail.push(values[index])
  }
  tail
}

///|
fn buslane_value_concat(
  head : Array[@buslane.ValueId],
  tail : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let result = head.copy()
  result.append(tail)
  result
}

///|
fn BuslaneLowerer::lower_pattern_type_binders(
  self : BuslaneLowerer,
  data_constructor : @buslane.DataConId,
  type_arguments : Array[@types.Type],
) -> Array[@buslane.TypeParameterId] {
  let lowered : Array[@buslane.TypeParameterId] = []
  let hidden_parameters = match
    self.metadata.data_constructor_info(data_constructor) {
    Some(info) => info.hidden_type_parameters
    None => []
  }
  for index in 0..<type_arguments.length() {
    let argument = type_arguments[index]
    if argument is Parameter(parameter) {
      let kind = match hidden_parameters.get(index) {
        Some(hidden) =>
          match self.metadata.type_parameter_info(hidden) {
            Some(info) => info.kind
            None => Type
          }
        None => Type
      }
      lowered.push(self.define_type_parameter_with_kind(parameter, kind))
    }
  }
  lowered
}

///|
fn BuslaneLowerer::define_pattern_binders(
  self : BuslaneLowerer,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(..) | Literal(..) => ()
    Binding(symbol~, type_~, ..) =>
      ignore(self.define_value(symbol, MatchBinder, self.lower_type(type_)))
    Variant(symbol~, type_arguments~, arguments~, ..) => {
      ignore(
        self.lower_pattern_type_binders(
          self.data_constructor_id(symbol),
          type_arguments,
        ),
      )
      for argument in arguments {
        self.define_pattern_binders(argument)
      }
    }
    Struct(type_binders~, fields~, ..) => {
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          ignore(self.define_type_parameter(parameter))
        }
      }
      for field in fields {
        self.define_pattern_binders(field.pattern)
      }
    }
  }
}

///|
fn BuslaneLowerer::lower_field(
  self : BuslaneLowerer,
  base : @checked.CheckedExpr,
  field : @symbol.FieldSymbolId,
) -> @buslane.Expr {
  let selector : @buslane.Expr = Ref(self.field_selector_id(field))
  let callee = match base.type_().decompose_nominal() {
    Some((_, arguments)) =>
      if arguments.is_empty() {
        selector
      } else {
        TypeApply(
          selector,
          arguments.map(fn(argument) { self.lower_type(argument) }),
        )
      }
    _ => selector
  }
  Call(callee, [self.lower_expr(base)])
}

///|
fn lower_literal(literal : @checked.CheckedLiteral) -> @buslane.Literal {
  match literal {
    Int(literal) => Int(literal.value)
    String(value) => String(value)
    Bool(value) => Bool(value)
    Unit => Unit
  }
}

///|
fn BuslaneLowerer::lower_type(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> @buslane.Type {
  match type_ {
    Error => Primitive(Unit)
    Primitive(primitive) => Primitive(lower_primitive_type(primitive))
    Constructor(symbol) => Constructor(self.type_id(symbol))
    Apply(callee, arguments) =>
      Apply(
        self.lower_type(callee),
        arguments.map(fn(argument) { self.lower_type(argument) }),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        parameters.map(fn(parameter) { self.define_type_parameter(parameter) }),
        self.lower_type(body),
      )
    Parameter(parameter) => Parameter(self.type_parameter_id(parameter))
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) { self.lower_type(parameter) }),
        self.lower_type(result),
        self.lower_effect(effect),
      )
    Forall(parameters, body) =>
      Forall(
        parameters.map(fn(parameter) { self.define_type_parameter(parameter) }),
        self.lower_type(body),
      )
  }
}

///|
fn BuslaneLowerer::lower_effect(
  self : BuslaneLowerer,
  effect : @types.Effect,
) -> @buslane.Effect {
  match effect {
    Empty => Empty
    Singleton(symbol, arguments) =>
      Singleton(
        self.effect_id(symbol),
        arguments.map(fn(argument) { self.lower_type(argument) }),
      )
    Parameter(parameter) => Parameter(self.type_parameter_id(parameter))
    Union(effects) =>
      Union(effects.map(fn(effect) { self.lower_effect(effect) }))
  }
}

///|
fn BuslaneLowerer::perform_type_arguments(
  self : BuslaneLowerer,
  effect : @types.Effect,
) -> Array[@buslane.Type] {
  guard effect is Singleton(_, arguments) else {
    abort("checked effect operation call must carry singleton owner effect")
  }
  arguments.map(fn(argument) { self.lower_type(argument) })
}

///|
fn BuslaneLowerer::nominal_type_arguments(
  self : BuslaneLowerer,
  type_ : @types.Type,
) -> Array[@buslane.Type] {
  match type_.decompose_nominal() {
    Some((_, arguments)) =>
      arguments.map(fn(argument) { self.lower_type(argument) })
    None => []
  }
}

///|
fn buslane_nominal_type(
  symbol : @buslane.TypeId,
  arguments : Array[@buslane.Type],
) -> @buslane.Type {
  if arguments.is_empty() {
    Constructor(symbol)
  } else {
    Apply(Constructor(symbol), arguments)
  }
}

///|
fn lower_primitive_type(
  primitive : @types.PrimitiveType,
) -> @buslane.PrimitiveType {
  match primitive {
    Int => Int
    Bool => Bool
    String => String
    Unit => Unit
  }
}

///|
fn lower_kind(kind : @types.Kind) -> @buslane.Kind {
  match kind {
    Type => Type
    Effect => Effect
    Function(parameters, result) =>
      Function(parameters.map(lower_kind), lower_kind(result))
  }
}

///|
fn BuslaneLowerer::define_external(
  self : BuslaneLowerer,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  let id = self.metadata.define_value(External, type_)
  self.external_terms.push(External(id))
  id
}

///|
fn BuslaneLowerer::define_builtin_external(
  self : BuslaneLowerer,
  name : String,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  let value = self.define_external(type_)
  self.builtin_externals.push({ value, name, type_ })
  value
}

///|
fn BuslaneLowerer::define_fresh_value(
  self : BuslaneLowerer,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  self.metadata.define_value(kind, type_)
}

///|
fn BuslaneLowerer::define_value(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
  kind : @buslane.ValueKind,
  type_ : @buslane.Type,
) -> @buslane.ValueId {
  for entry in self.values {
    if entry.source == source {
      return entry.target
    }
  }
  let target = self.metadata.define_value(kind, type_)
  self.values.push({ source, target })
  target
}

///|
fn BuslaneLowerer::define_operation(
  self : BuslaneLowerer,
  source : @symbol.OperationSymbolId,
  owner : @buslane.EffectId,
  type_parameters : Array[@types.TypeParameter],
  payload : Array[@types.Type],
  result : @types.Type,
) -> @buslane.OperationId {
  for entry in self.operations {
    if entry.source == source {
      return entry.target
    }
  }
  for parameter in type_parameters {
    ignore(self.define_type_parameter(parameter))
  }
  let target = self.metadata.define_operation(
    owner,
    payload.map(fn(type_) { self.lower_type(type_) }),
    self.lower_type(result),
  )
  self.operations.push({ source, target })
  target
}

///|
fn BuslaneLowerer::bind_value_alias(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
  target : @buslane.ValueId,
) -> Unit {
  for entry in self.values {
    if entry.source == source {
      return
    }
  }
  self.values.push({ source, target })
}

///|
fn BuslaneLowerer::define_type_parameter(
  self : BuslaneLowerer,
  parameter : @types.TypeParameter,
) -> @buslane.TypeParameterId {
  self.define_type_parameter_with_kind(parameter.id, lower_kind(parameter.kind))
}

///|
fn BuslaneLowerer::define_type_parameter_with_kind(
  self : BuslaneLowerer,
  source : @symbol.TypeParameterId,
  kind : @buslane.Kind,
) -> @buslane.TypeParameterId {
  for entry in self.type_parameters {
    if entry.source == source {
      return entry.target
    }
  }
  let target = self.metadata.define_type_parameter(kind)
  self.type_parameters.push({ source, target })
  target
}

///|
fn BuslaneLowerer::type_id(
  self : BuslaneLowerer,
  source : @symbol.TypeSymbolId,
) -> @buslane.TypeId {
  for entry in self.type_symbols {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane type id")
}

///|
fn BuslaneLowerer::type_parameter_id(
  self : BuslaneLowerer,
  source : @symbol.TypeParameterId,
) -> @buslane.TypeParameterId {
  for entry in self.type_parameters {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane type parameter id")
}

///|
fn BuslaneLowerer::value_id(
  self : BuslaneLowerer,
  source : @symbol.ValueSymbolId,
) -> @buslane.ValueId {
  for entry in self.values {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane value id")
}

///|
fn BuslaneLowerer::data_constructor_id(
  self : BuslaneLowerer,
  source : @symbol.VariantSymbolId,
) -> @buslane.DataConId {
  for entry in self.data_constructors {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane data constructor id")
}

///|
fn BuslaneLowerer::effect_id(
  self : BuslaneLowerer,
  source : @symbol.EffectSymbolId,
) -> @buslane.EffectId {
  for entry in self.effects {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane effect id")
}

///|
fn BuslaneLowerer::operation_id(
  self : BuslaneLowerer,
  source : @symbol.OperationSymbolId,
) -> @buslane.OperationId {
  for entry in self.operations {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane operation id")
}

///|
fn BuslaneLowerer::struct_constructor_id(
  self : BuslaneLowerer,
  source : @symbol.TypeSymbolId,
) -> @buslane.DataConId {
  for entry in self.struct_constructors {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane struct constructor id")
}

///|
fn BuslaneLowerer::field_selector_id(
  self : BuslaneLowerer,
  source : @symbol.FieldSymbolId,
) -> @buslane.ValueId {
  for entry in self.field_selectors {
    if entry.source == source {
      return entry.target
    }
  }
  abort("unknown Buslane field selector id")
}
