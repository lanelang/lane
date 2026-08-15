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
priv struct CompletionIndex {
  graph : CachedModuleGraph?
  modules : SnapshotTree[CachedSemanticSlot]
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
        module_.index.module_bindings,
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
    if space.allows(binding.kind) {
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
  match space {
    AnySpace | TypeSpace =>
      for primitive in @types.PrimitiveType::all() {
        let name = primitive.name()
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          name,
          Type,
          Some("primitive type \{name}"),
          "30",
        )
      }
    _ => ()
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
fn CompletionSpace::allows(
  self : CompletionSpace,
  kind : SemanticBindingKind,
) -> Bool {
  match (self, kind) {
    (AnySpace, _) => true
    (
      ValueSpace,
      ValueBindingKind
      | FunctionBindingKind
      | TypeBindingKind
      | EffectBindingKind,
    ) => true
    (PatternSpace, TypeBindingKind) => true
    (TypeSpace, TypeBindingKind | TypeParameterBindingKind | EffectBindingKind) =>
      true
    (EffectSpace, EffectBindingKind) => true
    _ => false
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
  for _, binding in module_.index.module_bindings {
    add_completion_entry(
      entries,
      source_id,
      prefix,
      replace,
      binding.name,
      Module,
      Some(binding.detail),
      "40",
    )
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
  guard imported_exports_for_owner(module_, owner) is Some((_, bindings)) else {
    return
  }
  self.add_interface_surface_entries(
    entries, source_id, prefix, replace, bindings, display,
  )
}

///|
fn imported_exports_for_owner(
  module_ : CachedSemanticModule,
  owner : String,
) -> (String, Array[@module_interface.ResolvedModuleInterfaceExport])? {
  for _, binding in module_.index.module_bindings {
    if binding.name == owner {
      return Some(
        (
          binding.module_path,
          module_.imports.available.public_exports(binding.module_path),
        ),
      )
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
  bindings : Array[@module_interface.ResolvedModuleInterfaceExport],
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  for binding in bindings {
    let exposed_name = binding.export_.exposed_name
    match binding.declaration {
      Value(value) => {
        let kind = match value.kind {
          Function => Function
          Let => Value
        }
        let type_text = display.type_text(value.type_)
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          exposed_name,
          kind,
          Some("\{exposed_name} : \{type_text}"),
          "20",
          is_offered=value.is_offered,
        )
      }
      NominalType(type_) => {
        let detail = match type_ {
          Struct(_) => "struct \{exposed_name}"
          Enum(_) => "enum \{exposed_name}"
          External(_) => "extern type \{exposed_name} : Type"
        }
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          exposed_name,
          Type,
          Some(detail),
          "30",
        )
      }
      TypeAlias(type_alias) => {
        let kind = match type_alias.kind {
          Effect => CompletionKind::Effect
          _ => Type
        }
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          exposed_name,
          kind,
          Some("type \{exposed_name}"),
          "30",
        )
      }
      Effect(effect) =>
        add_completion_entry(
          entries,
          source_id,
          prefix,
          replace,
          exposed_name,
          Effect,
          Some(effect_completion_detail(exposed_name, effect.flavor)),
          "32",
        )
    }
  }
}

///|
fn CompletionIndex::add_owner_entries(
  self : CompletionIndex,
  entries : Array[CompletionEntry],
  module_ : CachedSemanticModule,
  source_id : String,
  owner : @resolve.ResolvedNominalName,
  prefix : String,
  replace : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  match owner {
    Qualified(owner) =>
      if imported_exports_for_owner(module_, owner.module_binding)
        is Some((module_path, bindings)) {
        self.add_interface_owner_entries(
          entries,
          source_id,
          prefix,
          replace,
          module_path,
          bindings,
          owner.name,
          display,
        )
      }
    Unqualified(owner) =>
      self.add_local_owner_entries(
        entries, module_, source_id, prefix, replace, owner,
      )
  }
}

///|
fn CompletionIndex::add_interface_owner_entries(
  _self : CompletionIndex,
  entries : Array[CompletionEntry],
  source_id : String,
  prefix : String,
  replace : @basic.SourceSpan,
  module_path : String,
  bindings : Array[@module_interface.ResolvedModuleInterfaceExport],
  owner : String,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  for binding in bindings {
    if binding.export_.exposed_name != owner {
      continue
    }
    match binding.declaration {
      NominalType(type_) =>
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
                Some("variant \{module_path}.\{owner}::\{variant.name}"),
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
                  "\{type_member.name} : \{display.kind_text(type_member.kind)}",
                ),
                "21",
              )
            }
          _ => ()
        }
      Effect(effect) =>
        for operation in effect.operations {
          add_completion_entry(
            entries,
            source_id,
            prefix,
            replace,
            operation.name,
            Operation,
            Some(operation_detail(display, owner, operation)),
            "20",
          )
        }
      TypeAlias(_) | Value(_) => ()
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
  // Fields are owner-visible members, so they are offered for any type the
  // module can reach, not only for types it imported by name.
  for interface in module_.imports.available.modules {
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
