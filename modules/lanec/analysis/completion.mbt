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
} derive(Debug, Eq)

///|
pub(all) struct CompletionEntry {
  label : String
  kind : CompletionKind
  is_offered : Bool
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
priv struct CompletionIndex {
  graph : CachedModuleGraph?
  modules : SnapshotTree[CachedSemanticSlot]
}

///|
priv struct CompletionSource {
  text : String
  tokens : Array[(@lexer.Token, @basic.SourceSpan)]
  line_starts : Array[Int]
  syntax_identifiers : @syntax.SyntacticIdentifierIndex
}

///|
fn CompletionSource::from_input(
  input : @module_frontend.ParsedModuleInput,
) -> CompletionSource {
  CompletionSource::from_syntax(
    input.text,
    input.concrete,
    input.source.syntactic_identifier_index(),
  )
}

///|
fn CompletionSource::from_source_syntax(
  input : @module_frontend.SourceSyntaxInput,
) -> CompletionSource {
  CompletionSource::from_syntax(input.text, input.concrete, input.identifiers)
}

///|
fn CompletionSource::from_syntax(
  text : String,
  concrete : @lexer.ConcreteSyntax,
  syntax_identifiers : @syntax.SyntacticIdentifierIndex,
) -> CompletionSource {
  let line_starts = [0]
  for trivia in concrete.trivia {
    if trivia.kind is Newline {
      line_starts.push(trivia.span.end_offset)
    }
  }
  { text, tokens: concrete.tokens, line_starts, syntax_identifiers }
}

///|
fn CompletionIndex::complete(
  self : CompletionIndex,
  source_id : String,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
) -> Array[CompletionEntry] {
  match self.module_for_source(source_id) {
    None => []
    Some(module_) => {
      let display = @typecheck.TypeDisplayContext::from_registry(
        module_.index.registry,
      )
      let context = completion_context(
        module_.completion_source,
        line,
        column,
        trigger,
        module_.input.header.imports.map(fn(import_) {
          import_.module_path_text
        }),
      )
      self.entries_for_context(
        module_, source_id, context, display, line, column,
      )
    }
  }
}

///|
fn CompletionIndex::module_for_source(
  self : CompletionIndex,
  source_id : String,
) -> CachedSemanticModule? {
  guard self.graph is Some(graph) else { return None }
  guard graph.module_slot_for_source(source_id) is Some(slot) else {
    return None
  }
  match self.modules.get(slot) {
    Some(Available(module_)) => Some(module_)
    _ => None
  }
}

///|
fn CompletionIndex::entries_for_context(
  self : CompletionIndex,
  module_ : CachedSemanticModule,
  source_id : String,
  context : CompletionContext,
  display : @typecheck.TypeDisplayContext,
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
        entries, module_, source_id, owner, prefix, replace, display,
      )
    OwnerQualified(owner~, prefix~, replace~) =>
      self.add_owner_entries(
        entries, module_, source_id, owner, prefix, replace, display,
      )
    ReceiverSelector(receiver~, prefix~, replace~) =>
      self.add_receiver_entries(
        entries, module_, source_id, receiver, prefix, replace, display, line, column,
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
  is_offered? : Bool = false,
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
    is_offered~,
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
  is_offered? : Bool = false,
) -> Unit {
  if !label.has_prefix(prefix) {
    return
  }
  for entry in entries {
    if entry.label == label &&
      entry.kind == kind &&
      entry.is_offered == is_offered &&
      entry.detail == detail {
      return
    }
  }
  entries.push({
    label,
    kind,
    is_offered,
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
fn CompletionIndex::add_identifier_entries(
  _self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  space : CompletionSpace,
  line : Int,
  column : Int,
) -> Unit {
  for binding in module_.index.visible_bindings(line, column) {
    let allowed = match binding.kind {
      ValueBindingKind | FunctionBindingKind => completion_allows_value(space)
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
        is_offered=binding.is_offered,
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
  }
}

///|
fn completion_allows_value(space : CompletionSpace) -> Bool {
  match space {
    AnySpace => true
    TypeSpace | EffectSpace => false
  }
}

///|
fn completion_allows_type(space : CompletionSpace) -> Bool {
  match space {
    AnySpace | TypeSpace => true
    EffectSpace => false
  }
}

///|
fn completion_allows_effect(space : CompletionSpace) -> Bool {
  match space {
    AnySpace | TypeSpace | EffectSpace => true
  }
}

///|
fn add_module_binding_entries(
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
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
fn CompletionIndex::add_import_entries(
  self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
) -> Unit {
  self.modules.each(fn(slot) {
    if slot is Available(candidate) &&
      candidate.input.source_id != module_.input.source_id {
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
  })
}

///|
fn CompletionIndex::add_module_surface_entries(
  self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  owner : String,
  prefix : String,
  replace : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  guard imported_interface_for_owner(module_, owner) is Some(interface) else {
    return
  }
  self.add_interface_surface_entries(
    entries, source_id, prefix, replace, interface, display,
  )
}

///|
fn imported_interface_for_owner(
  module_ : CachedSemanticModule,
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
fn CompletionIndex::add_interface_surface_entries(
  _self : CompletionIndex,
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  interface : @module_interface.ModuleInterface,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  for value in interface.values {
    let kind = match value.kind {
      Function => Function
      Let => Value
    }
    let type_text = value.type_presentation.unwrap_or_else(fn() {
      display.type_text(value.type_)
    })
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      value.name,
      kind,
      Some("\{value.name} : \{type_text}"),
      "20",
      is_offered=value.is_offered,
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
fn CompletionIndex::add_owner_entries(
  self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  owner : String,
  prefix : String,
  replace : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  match split_qualified_owner(owner) {
    Some((module_owner, member_owner)) =>
      if imported_interface_for_owner(module_, module_owner) is Some(interface) {
        self.add_interface_owner_entries(
          entries, source_id, prefix, replace, interface, member_owner, display,
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
fn CompletionIndex::add_interface_owner_entries(
  _self : CompletionIndex,
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  interface : @module_interface.ModuleInterface,
  owner : String,
  display : @typecheck.TypeDisplayContext,
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
            Some("\{type_member.name} : \{display.kind_text(type_member.kind)}"),
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
          Some(operation_detail(display, effect.name, operation)),
          "20",
        )
      }
    }
  }
}

///|
fn CompletionIndex::add_local_owner_entries(
  _self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
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
      Some(fact.completion_detail),
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
fn operation_detail(
  display : @typecheck.TypeDisplayContext,
  effect_name : String,
  operation : @module_interface.ModuleInterfaceOperation,
) -> String {
  operation_signature_detail(
    effect_name,
    operation.name,
    operation.type_parameters,
    operation.payload,
    operation.result,
    display,
  )
}

///|
fn CompletionIndex::add_receiver_entries(
  self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  receiver : String,
  prefix : String,
  replace : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
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
      Some(field.completion_detail),
      semantic_member_sort_text(field.kind),
    )
  }
  self.add_imported_fields_for_type(
    entries, module_, source_id, prefix, replace, symbol, display,
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
fn CompletionIndex::add_imported_fields_for_type(
  _self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  symbol : @symbol.TypeSymbolId,
  display : @typecheck.TypeDisplayContext,
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
              Some("\{field.name} : \{display.type_text(field.type_)}"),
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
  source : CompletionSource,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
  imported_modules : Array[String],
) -> CompletionContext {
  let offset = source.offset(line, column)
  let prefix_start = identifier_prefix_start(source.text, offset)
  let prefix = source.text.unsafe_substring(start=prefix_start, end=offset)
  let replace = source.span(prefix_start, offset)
  let token_count = source.token_count_before(prefix_start)
  if source.line_starts_with_import(line, token_count) {
    return ImportPath(prefix~, replace~)
  }
  if source.tokens.get(token_count - 1)
    is Some((TIGHT_COLONCOLON | COLONCOLON, _)) {
    let owner = completion_owner_before_separator(source.tokens, token_count)
    if owner != "" {
      return OwnerQualified(owner~, prefix~, replace~)
    }
  }
  if source.tokens.get(token_count - 1) is Some((DOT, _)) {
    let owner = completion_owner_before_separator(source.tokens, token_count)
    if owner != "" {
      if module_owner_visible(owner, imported_modules) {
        return ModuleQualified(owner~, prefix~, replace~)
      }
      return ReceiverSelector(receiver=owner, prefix~, replace~)
    }
  }
  match trigger {
    TriggerCharacter(".") | TriggerCharacter(":") if prefix == "" => Unsupported
    _ =>
      Identifier(
        prefix~,
        replace~,
        space=completion_space_from_syntax_role(
          source.syntax_identifiers.role_at(offset),
        ),
      )
  }
}

///|
fn completion_space_from_syntax_role(
  role : @syntax.SyntacticIdentifierRole?,
) -> CompletionSpace {
  match role {
    Some(TypeIdentifier) => TypeSpace
    Some(EffectIdentifier) => EffectSpace
    Some(ValueIdentifier) | Some(PatternIdentifier) | None => AnySpace
  }
}

///|
fn CompletionSource::offset(
  self : CompletionSource,
  line : Int,
  column : Int,
) -> Int {
  let line_index = if line > 0 { line - 1 } else { 0 }
  let line_start = self.line_starts
    .get(line_index)
    .unwrap_or(self.text.length())
  let column_offset = if column > 1 { column - 1 } else { 0 }
  minimum_int(line_start + column_offset, self.text.length())
}

///|
fn CompletionSource::span(
  self : CompletionSource,
  start_offset : Int,
  end_offset : Int,
) -> @basic.SourceSpan {
  let start = self.position(start_offset)
  let end = self.position(end_offset)
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
fn CompletionSource::position(
  self : CompletionSource,
  offset : Int,
) -> (Int, Int) {
  let safe_offset = if offset < 0 {
    0
  } else {
    minimum_int(offset, self.text.length())
  }
  let mut low = 0
  let mut high = self.line_starts.length()
  while low < high {
    let middle = low + (high - low) / 2
    if self.line_starts[middle] <= safe_offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  let line_index = if low > 0 { low - 1 } else { 0 }
  (line_index + 1, safe_offset - self.line_starts[line_index] + 1)
}

///|
fn CompletionSource::token_count_before(
  self : CompletionSource,
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = self.tokens.length()
  while low < high {
    let middle = low + (high - low) / 2
    if self.tokens[middle].1.end_offset <= offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn CompletionSource::line_starts_with_import(
  self : CompletionSource,
  line : Int,
  token_count : Int,
) -> Bool {
  guard self.line_starts.get(line - 1) is Some(line_start) else { return false }
  let mut low = 0
  let mut high = token_count
  while low < high {
    let middle = low + (high - low) / 2
    if self.tokens[middle].1.start_offset < line_start {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low < token_count && self.tokens[low].0 is IMPORT
}

///|
fn completion_owner_before_separator(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  token_count : Int,
) -> String {
  let mut index = token_count - 2
  let mut owner = ""
  let mut expect_identifier = true
  while index >= 0 {
    let token = tokens[index].0
    if expect_identifier {
      guard token is IDENT(name) else { break }
      owner = if owner == "" { name } else { "\{name}.\{owner}" }
      expect_identifier = false
    } else {
      guard token is DOT else { break }
      expect_identifier = true
    }
    index -= 1
  }
  owner
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
fn is_identifier_part(text : String) -> Bool {
  text.length() == 1 &&
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".contains(
    text,
  )
}

///|
fn minimum_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}
