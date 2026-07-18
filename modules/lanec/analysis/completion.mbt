///|
pub(all) enum CompletionTrigger {
  Manual
  TriggerCharacter(String)
} derive(Debug, Eq)

///|
pub(all) enum CompletionKind {
  Value
  Function
  Type
  TypeParameter
  Effect
  Operation
  Field
  Variant
  Module
  Offer
} derive(Debug, Eq)

///|
pub(all) struct CompletionEntry {
  label : String
  kind : CompletionKind
  detail : String?
  documentation : String?
  insert_text : String?
  replace : AnalysisLocation?
  sort_text : String?
} derive(Debug, Eq)

///|
priv enum CompletionSpace {
  AnySpace
  TypeSpace
  EffectSpace
  ImportSpace
}

///|
priv enum CompletionContext {
  Identifier(
    prefix~ : String,
    replace~ : @basic.SourceSpan,
    space~ : CompletionSpace
  )
  ImportPath(prefix~ : String, replace~ : @basic.SourceSpan)
  ModuleQualified(
    owner~ : String,
    prefix~ : String,
    replace~ : @basic.SourceSpan
  )
  OwnerQualified(
    owner~ : String,
    prefix~ : String,
    replace~ : @basic.SourceSpan
  )
  ReceiverSelector(
    receiver~ : String,
    prefix~ : String,
    replace~ : @basic.SourceSpan
  )
  Unsupported
}

///|
priv struct CompletionModule {
  input : @module_frontend.ParsedModuleInput
  imported : @module_interface.ImportedEnvironment
  index : SemanticIndex
}

///|
priv struct CompletionWorld {
  display : @typecheck.TypeDisplayContext
  modules : Array[CompletionModule]
}

///|
pub fn complete_source_inputs(
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  match
    @module_frontend.parse_module_input_set_from_inputs(
      root_source, library_sources,
    ) {
    Err(_) => []
    Ok(inputs) =>
      complete_module_input_set(inputs, source_id, line, column, trigger)
  }
}

///|
pub fn complete_import_reachable_source_inputs(
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  match
    @module_frontend.parse_import_reachable_module_input_set_from_inputs(
      root_source, library_sources,
    ) {
    Err(_) => []
    Ok(inputs) =>
      complete_module_input_set(inputs, source_id, line, column, trigger)
  }
}

///|
fn complete_module_input_set(
  inputs : @module_frontend.ModuleInputSet,
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  match @module_frontend.build_module_graph(inputs) {
    Err(_) => []
    Ok(graph) => {
      let world = CompletionWorld::from_graph(graph)
      match world.module_for_source(source_id) {
        None => []
        Some(module_) => {
          let context = completion_context(
            module_.input.text,
            line,
            column,
            trigger,
            module_.input.header.imports.map(fn(import_) {
              import_.module_path_text
            }),
          )
          world.entries_for_context(module_, source_id, context, line, column)
        }
      }
    }
  }
}

///|
fn CompletionWorld::from_graph(
  graph : @module_frontend.ModuleGraph,
) -> CompletionWorld {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let display = @typecheck.TypeDisplayContext::from_registry(registry)
  let compiled : Array[AnalysisModuleSummary] = []
  let modules : Array[CompletionModule] = []
  for input in graph.modules {
    let imported = analysis_imported_interfaces(input.header, compiled)
    let resolved = @resolve.resolve_source_file_with_imports_result(
      input.source,
      registry,
      imported,
    )
    let mut checked_source = None
    let mut interface = None
    if resolved.diagnostics.is_empty() {
      let checked = @typecheck.typecheck_checked_source_file_with_imported_environment(
        resolved.source,
        imported,
      )
      if checked.diagnostics.is_empty() {
        checked_source = checked.source
        interface = checked.module_interface
      }
    }
    if interface is Some(module_interface) && checked_source is Some(_) {
      compiled.push({
        module_path_text: input.header.module_path_text,
        interface: { ..module_interface, source_id: Some(input.source_id) },
      })
    }
    modules.push({
      input,
      imported,
      index: SemanticIndex::from_sources(
        resolved.source,
        checked_source,
        display,
        input.source_id,
        input.text,
      ),
    })
  }
  { display, modules }
}

///|
fn CompletionWorld::module_for_source(
  self : CompletionWorld,
  source_id : String,
) -> CompletionModule? {
  for module_ in self.modules {
    if module_.input.source_id == source_id {
      return Some(module_)
    }
  }
  None
}

///|
fn CompletionWorld::entries_for_context(
  self : CompletionWorld,
  module_ : CompletionModule,
  source_id : String,
  context : CompletionContext,
  line : Int,
  column : Int,
) -> Array[CompletionEntry] {
  let entries : Array[CompletionEntry] = []
  match context {
    Identifier(prefix~, replace~, space~) =>
      self.add_identifier_entries(
        entries, module_, source_id, prefix, replace, space, line, column,
      )
    ImportPath(prefix~, replace~) =>
      self.add_import_entries(entries, module_, source_id, prefix, replace)
    ModuleQualified(owner~, prefix~, replace~) =>
      self.add_module_surface_entries(
        entries, module_, source_id, owner, prefix, replace,
      )
    OwnerQualified(owner~, prefix~, replace~) =>
      self.add_owner_entries(
        entries, module_, source_id, owner, prefix, replace,
      )
    ReceiverSelector(receiver~, prefix~, replace~) =>
      self.add_receiver_entries(
        entries, module_, source_id, receiver, prefix, replace, line, column,
      )
    Unsupported => ()
  }
  entries.sort_by(fn(left, right) {
    String::compare(completion_sort_key(left), completion_sort_key(right))
  })
  entries
}

///|
fn completion_sort_key(entry : CompletionEntry) -> String {
  match entry.sort_text {
    Some(text) => text
    None => "\{completion_kind_rank(entry.kind)}:\{entry.label}"
  }
}

///|
fn completion_kind_rank(kind : CompletionKind) -> String {
  match kind {
    Value => "20"
    Function => "21"
    Offer => "22"
    Field => "23"
    Variant => "24"
    Type => "30"
    TypeParameter => "31"
    Effect => "32"
    Operation => "33"
    Module => "40"
  }
}

///|
fn add_completion_entry(
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  label : String,
  kind : CompletionKind,
  detail : String?,
  rank : String,
) -> Unit {
  add_completion_entry_with_insert_text(
    entries,
    source_id,
    prefix,
    replace,
    label,
    kind,
    detail,
    insert_text=None,
    rank,
  )
}

///|
fn add_completion_entry_with_insert_text(
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  label : String,
  kind : CompletionKind,
  detail : String?,
  insert_text~ : String?,
  rank : String,
) -> Unit {
  if !label.has_prefix(prefix) {
    return
  }
  for entry in entries {
    if entry.label == label && entry.kind == kind && entry.detail == detail {
      return
    }
  }
  entries.push({
    label,
    kind,
    detail,
    documentation: None,
    insert_text,
    replace: Some({ source_id, span: replace }),
    sort_text: Some("\{rank}:\{label}"),
  })
}

///|
fn effect_completion_detail(
  name : String,
  flavor : @symbol.EffectFlavor,
) -> String {
  if flavor is External {
    "extern type \{name} : Effect"
  } else {
    "effect \{name}"
  }
}

///|
fn payloadless_variant_insert_text(
  name : String,
  payload_count : Int,
) -> String? {
  if payload_count == 0 {
    Some("\{name}()")
  } else {
    None
  }
}

///|
fn CompletionWorld::add_identifier_entries(
  _self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  space : CompletionSpace,
  line : Int,
  column : Int,
) -> Unit {
  for binding in module_.index.visible_bindings(line, column) {
    let allowed = match binding.kind {
      ValueBindingKind | FunctionBindingKind | OfferBindingKind =>
        completion_allows_value(space)
      TypeBindingKind | TypeParameterBindingKind =>
        completion_allows_type(space)
      EffectBindingKind => completion_allows_effect(space)
    }
    if allowed {
      add_completion_entry(
        entries,
        source_id,
        prefix,
        replace,
        binding.name,
        semantic_binding_completion_kind(binding.kind),
        Some(binding.detail),
        semantic_binding_sort_text(binding),
      )
    }
  }
  add_module_binding_entries(entries, module_, source_id, prefix, replace)
}

///|
fn semantic_binding_completion_kind(
  kind : SemanticBindingKind,
) -> CompletionKind {
  match kind {
    ValueBindingKind => Value
    FunctionBindingKind => Function
    TypeBindingKind => Type
    TypeParameterBindingKind => TypeParameter
    EffectBindingKind => Effect
    OfferBindingKind => Offer
  }
}

///|
fn semantic_binding_sort_text(binding : SemanticBindingFact) -> String {
  match binding.kind {
    ValueBindingKind | FunctionBindingKind =>
      match binding.visibility {
        GlobalBinding => "20"
        ScopedBinding(_) => "00"
        OrderedBinding(_) => "02"
      }
    TypeBindingKind => "30"
    TypeParameterBindingKind => "01"
    EffectBindingKind => "32"
    OfferBindingKind =>
      match binding.visibility {
        GlobalBinding => "22"
        ScopedBinding(_) | OrderedBinding(_) => "02"
      }
  }
}

///|
fn completion_allows_value(space : CompletionSpace) -> Bool {
  match space {
    AnySpace => true
    TypeSpace | EffectSpace | ImportSpace => false
  }
}

///|
fn completion_allows_type(space : CompletionSpace) -> Bool {
  match space {
    AnySpace | TypeSpace => true
    EffectSpace | ImportSpace => false
  }
}

///|
fn completion_allows_effect(space : CompletionSpace) -> Bool {
  match space {
    AnySpace | TypeSpace | EffectSpace => true
    ImportSpace => false
  }
}

///|
fn add_module_binding_entries(
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
) -> Unit {
  for import_ in module_.input.header.imports {
    let label = module_binding_label(import_.module_path_text)
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      label,
      Module,
      Some("module \{import_.module_path_text}"),
      "40",
    )
  }
}

///|
fn module_binding_label(module_path_text : String) -> String {
  let components = module_path_text.split(".").collect()
  match components.last() {
    Some(component) => component.to_owned()
    None => module_path_text
  }
}

///|
fn CompletionWorld::add_import_entries(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
) -> Unit {
  for candidate in self.modules {
    if candidate.input.source_id != module_.input.source_id {
      add_completion_entry(
        entries,
        source_id,
        prefix,
        replace,
        candidate.input.header.module_path_text,
        Module,
        Some("module \{candidate.input.header.module_path_text}"),
        "10",
      )
    }
  }
}

///|
fn CompletionWorld::add_module_surface_entries(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  owner : String,
  prefix : String,
  replace : @basic.SourceSpan,
) -> Unit {
  guard imported_interface_for_owner(module_, owner) is Some(interface) else {
    return
  }
  self.add_interface_surface_entries(
    entries, source_id, prefix, replace, interface,
  )
}

///|
fn imported_interface_for_owner(
  module_ : CompletionModule,
  owner : String,
) -> @module_interface.ModuleInterface? {
  for import_ in module_.input.header.imports {
    if module_binding_label(import_.module_path_text) == owner ||
      import_.module_path_text == owner {
      return module_.imported.find(import_.module_path_text)
    }
  }
  None
}

///|
fn CompletionWorld::add_interface_surface_entries(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  for value in interface.values {
    let kind = match value.kind {
      Function => Function
      Let => Value
      Offer => Offer
    }
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      value.name,
      kind,
      Some("\{value.name} : \{self.display.type_text(value.type_)}"),
      "20",
    )
  }
  for type_ in interface.types {
    match type_ {
      Struct(struct_) =>
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          struct_.name,
          Type,
          Some("struct \{struct_.name}"),
          "30",
        )
      Enum(enum_) =>
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          enum_.name,
          Type,
          Some("enum \{enum_.name}"),
          "30",
        )
      External(external) =>
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          external.name,
          Type,
          Some("extern type \{external.name} : Type"),
          "30",
        )
    }
  }
  for type_alias in interface.type_aliases {
    let kind = match type_alias.kind {
      Effect => CompletionKind::Effect
      _ => Type
    }
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      type_alias.name,
      kind,
      Some("type \{type_alias.name}"),
      "30",
    )
  }
  for effect in interface.effects {
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      effect.name,
      Effect,
      Some(effect_completion_detail(effect.name, effect.flavor)),
      "32",
    )
  }
}

///|
fn CompletionWorld::add_owner_entries(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  owner : String,
  prefix : String,
  replace : @basic.SourceSpan,
) -> Unit {
  match split_qualified_owner(owner) {
    Some((module_owner, member_owner)) =>
      if imported_interface_for_owner(module_, module_owner) is Some(interface) {
        self.add_interface_owner_entries(
          entries, source_id, prefix, replace, interface, member_owner,
        )
      }
    None =>
      self.add_local_owner_entries(
        entries, module_, source_id, prefix, replace, owner,
      )
  }
}

///|
fn split_qualified_owner(owner : String) -> (String, String)? {
  match string_last_index(owner, ".") {
    Some(index) =>
      Some(
        (
          owner.unsafe_substring(start=0, end=index),
          owner.unsafe_substring(start=index + 1, end=owner.length()),
        ),
      )
    None => None
  }
}

///|
fn string_last_index(text : String, needle : String) -> Int? {
  let mut search_start = 0
  let mut last = None
  while search_start < text.length() {
    let rest = text.unsafe_substring(start=search_start, end=text.length())
    match rest.find(needle) {
      Some(relative) => {
        let index = search_start + relative
        last = Some(index)
        search_start = index + needle.length()
      }
      None => search_start = text.length()
    }
  }
  last
}

///|
fn CompletionWorld::add_interface_owner_entries(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  interface : @module_interface.ModuleInterface,
  owner : String,
) -> Unit {
  for type_ in interface.types {
    match type_ {
      Enum(enum_) if enum_.name == owner =>
        for variant in enum_.variants {
          add_completion_entry_with_insert_text(
            entries,
            source_id,
            prefix,
            replace,
            variant.name,
            Variant,
            Some("variant \{interface.module_path}.\{owner}::\{variant.name}"),
            insert_text=payloadless_variant_insert_text(
              variant.name,
              variant.payload.length(),
            ),
            "20",
          )
        }
      Struct(struct_) if struct_.name == owner =>
        for type_member in struct_.type_members {
          add_completion_entry(
            entries,
            source_id,
            prefix,
            replace,
            type_member.name,
            TypeParameter,
            Some(
              "\{type_member.name} : \{self.display.kind_text(type_member.kind)}",
            ),
            "21",
          )
        }
      _ => ()
    }
  }
  for effect in interface.effects {
    if effect.name == owner {
      for operation in effect.operations {
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          operation.name,
          Operation,
          Some(self.operation_detail(effect.name, operation)),
          "20",
        )
      }
    }
  }
}

///|
fn CompletionWorld::add_local_owner_entries(
  _self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  owner : String,
) -> Unit {
  for fact in module_.index.owner_members(owner) {
    add_completion_entry_with_insert_text(
      entries,
      source_id,
      prefix,
      replace,
      fact.name,
      semantic_member_completion_kind(fact.kind),
      Some(fact.detail),
      insert_text=semantic_member_insert_text(fact),
      semantic_member_sort_text(fact.kind),
    )
  }
}

///|
fn semantic_member_completion_kind(kind : SemanticMemberKind) -> CompletionKind {
  match kind {
    FieldMemberKind => Field
    TypeMemberKind => TypeParameter
    VariantMemberKind => Variant
    OperationMemberKind => Operation
  }
}

///|
fn semantic_member_sort_text(kind : SemanticMemberKind) -> String {
  match kind {
    TypeMemberKind => "21"
    FieldMemberKind | VariantMemberKind | OperationMemberKind => "20"
  }
}

///|
fn semantic_member_insert_text(fact : SemanticMemberFact) -> String? {
  if fact.kind is VariantMemberKind && fact.payload_count == Some(0) {
    Some("\{fact.name}()")
  } else {
    None
  }
}

///|
fn CompletionWorld::operation_detail(
  self : CompletionWorld,
  effect_name : String,
  operation : @module_interface.ModuleInterfaceOperation,
) -> String {
  let payload = operation.payload
    .map(fn(type_) { self.display.type_text(type_) })
    .join(", ")
  "\{effect_name}::\{operation.name}(\{payload}) -> \{self.display.type_text(operation.result)}"
}

///|
fn CompletionWorld::add_receiver_entries(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  receiver : String,
  prefix : String,
  replace : @basic.SourceSpan,
  line : Int,
  column : Int,
) -> Unit {
  guard module_.index.receiver_type(receiver, line, column) is Some(type_) else {
    return
  }
  guard nominal_constructor(type_) is Some(symbol) else { return }
  for field in module_.index.fields_for_type(symbol) {
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      field.name,
      semantic_member_completion_kind(field.kind),
      Some(field.detail),
      semantic_member_sort_text(field.kind),
    )
  }
  self.add_imported_fields_for_type(
    entries, module_, source_id, prefix, replace, symbol,
  )
}

///|
fn nominal_constructor(type_ : @types.Type) -> @symbol.TypeSymbolId? {
  match type_ {
    Constructor(symbol) => Some(symbol)
    Apply(Constructor(symbol), _) => Some(symbol)
    _ => None
  }
}

///|
fn CompletionWorld::add_imported_fields_for_type(
  self : CompletionWorld,
  entries : Array[CompletionEntry],
  module_ : CompletionModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  symbol : @symbol.TypeSymbolId,
) -> Unit {
  for interface in module_.imported.modules {
    for type_ in interface.types {
      match type_ {
        Struct(struct_) if struct_.symbol == symbol =>
          for field in struct_.fields {
            add_completion_entry(
              entries,
              source_id,
              prefix,
              replace,
              field.name,
              Field,
              Some("\{field.name} : \{self.display.type_text(field.type_)}"),
              "20",
            )
          }
        _ => ()
      }
    }
  }
}

///|
fn completion_context(
  source_text : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
  imported_modules : Array[String],
) -> CompletionContext {
  let offset = source_offset(source_text, line, column)
  let prefix_start = identifier_prefix_start(source_text, offset)
  let prefix = source_text.unsafe_substring(start=prefix_start, end=offset)
  let replace = span_from_offsets(source_text, prefix_start, offset)
  let line_text = line_prefix(source_text, line, column)
  if line_text.trim().has_prefix("import ") {
    return ImportPath(prefix~, replace~)
  }
  if prefix_start >= 2 &&
    source_text.unsafe_substring(start=prefix_start - 2, end=prefix_start) ==
    "::" {
    let owner = qualified_token_before(source_text, prefix_start - 2)
    if owner != "" {
      return OwnerQualified(owner~, prefix~, replace~)
    }
  }
  if prefix_start >= 1 &&
    source_text.unsafe_substring(start=prefix_start - 1, end=prefix_start) ==
    "." {
    let owner = qualified_token_before(source_text, prefix_start - 1)
    if owner != "" {
      if module_owner_visible(owner, imported_modules) {
        return ModuleQualified(owner~, prefix~, replace~)
      }
      return ReceiverSelector(receiver=owner, prefix~, replace~)
    }
  }
  match trigger {
    TriggerCharacter(".") | TriggerCharacter(":") if prefix == "" => Unsupported
    _ => Identifier(prefix~, replace~, space=completion_space(line_text))
  }
}

///|
fn completion_space(line_text : String) -> CompletionSpace {
  let trimmed = line_text.trim()
  if trimmed.has_prefix("import ") {
    ImportSpace
  } else if trimmed.has_prefix("type ") || trimmed.contains(" : ") {
    TypeSpace
  } else if trimmed.contains("!") || trimmed.contains("{") {
    EffectSpace
  } else {
    AnySpace
  }
}

///|
fn module_owner_visible(owner : String, modules : Array[String]) -> Bool {
  for module_path in modules {
    if module_binding_label(module_path) == owner || module_path == owner {
      return true
    }
  }
  false
}

///|
fn source_offset(source_text : String, line : Int, column : Int) -> Int {
  let lines = source_text.split("\n").collect()
  line_start_offset(lines, line) + column - 1
}

///|
fn line_prefix(source_text : String, line : Int, column : Int) -> String {
  let lines = source_text.split("\n").collect()
  match lines.get(line - 1) {
    Some(view) => {
      let text = view.to_owned()
      let end = minimum_int(column - 1, text.length())
      text.unsafe_substring(start=0, end~)
    }
    None => ""
  }
}

///|
fn identifier_prefix_start(source_text : String, offset : Int) -> Int {
  let mut index = minimum_int(offset, source_text.length())
  while index > 0 &&
        is_identifier_part(
          source_text.unsafe_substring(start=index - 1, end=index),
        ) {
    index = index - 1
  }
  index
}

///|
fn qualified_token_before(source_text : String, offset : Int) -> String {
  let mut end = offset
  while end > 0 && source_text.unsafe_substring(start=end - 1, end~) == " " {
    end = end - 1
  }
  let mut start = end
  while start > 0 {
    let ch = source_text.unsafe_substring(start=start - 1, end=start)
    if is_identifier_part(ch) || ch == "." {
      start = start - 1
    } else {
      break
    }
  }
  source_text.unsafe_substring(start~, end~)
}

///|
fn is_identifier_part(text : String) -> Bool {
  text.length() == 1 &&
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".contains(
    text,
  )
}

///|
fn span_from_offsets(
  source_text : String,
  start_offset : Int,
  end_offset : Int,
) -> @basic.SourceSpan {
  let start = line_column_at_offset(source_text, start_offset)
  let end = line_column_at_offset(source_text, end_offset)
  {
    start_offset,
    end_offset,
    start_line: start.0,
    start_column: start.1,
    end_line: end.0,
    end_column: end.1,
  }
}

///|
fn line_column_at_offset(source_text : String, offset : Int) -> (Int, Int) {
  let mut line = 1
  let mut column = 1
  let mut index = 0
  let safe_offset = minimum_int(offset, source_text.length())
  while index < safe_offset {
    let ch = source_text.unsafe_substring(start=index, end=index + 1)
    if ch == "\n" {
      line = line + 1
      column = 1
    } else {
      column = column + 1
    }
    index = index + 1
  }
  (line, column)
}

///|
fn minimum_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}
