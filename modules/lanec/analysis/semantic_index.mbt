///|
priv enum SemanticBindingIdentity {
  ValueBinding(@symbol.ValueSymbolId)
  TypeBinding(@symbol.TypeSymbolId)
  EffectBinding(@symbol.EffectSymbolId)
  TypeParameterBinding(@symbol.TypeParameterId)
  AliasBinding(String)
} derive(Eq)

///|
priv enum SemanticBindingVisibility {
  GlobalBinding
  ScopedBinding(@basic.SourceSpan)
  OrderedBinding(scope~ : @basic.SourceSpan, declaration~ : @basic.SourceSpan)
}

///|
priv enum SemanticBindingKind {
  ValueBindingKind
  FunctionBindingKind
  TypeBindingKind
  TypeParameterBindingKind
  EffectBindingKind
  OfferBindingKind
}

///|
priv struct SemanticBindingFact {
  identity : SemanticBindingIdentity
  name : String
  kind : SemanticBindingKind
  mut detail : String
  mut type_ : @types.Type?
  visibility : SemanticBindingVisibility
}

///|
priv enum SemanticMemberIdentity {
  FieldMember(@symbol.FieldSymbolId)
  TypeMember(@symbol.TypeMemberSymbolId)
  VariantMember(@symbol.VariantSymbolId)
  OperationMember(@symbol.OperationSymbolId)
} derive(Eq)

///|
priv enum SemanticMemberKind {
  FieldMemberKind
  TypeMemberKind
  VariantMemberKind
  OperationMemberKind
}

///|
priv struct SemanticMemberFact {
  identity : SemanticMemberIdentity
  owner_name : String
  owner_type : @symbol.TypeSymbolId?
  name : String
  kind : SemanticMemberKind
  mut detail : String
  payload_count : Int?
}

///|
priv enum GenericParameterKind {
  GenericTypeParameter
  GenericEffectParameter
}

///|
priv struct GenericParameterFact {
  symbol : @symbol.TypeParameterId
  name : String
  kind : GenericParameterKind
  loc : @basic.SourceSpan
}

///|
priv enum TopLevelSymbol {
  TopLevelValue(@symbol.ValueSymbolId)
  TopLevelType(@symbol.TypeSymbolId)
  TopLevelEffect(@symbol.EffectSymbolId)
  TopLevelAlias(String)
} derive(Eq)

///|
priv enum TopLevelDeclarationKind {
  ValueDeclaration
  FunctionDeclaration
  StructDeclaration
  EnumDeclaration
  ExternalTypeDeclaration
  EffectDeclaration
  TypeAliasDeclaration
  EffectAliasDeclaration
}

///|
priv struct TopLevelDeclarationFact {
  symbol : TopLevelSymbol
  name : String
  kind : TopLevelDeclarationKind
  is_public : Bool
  loc : @basic.SourceSpan
}

///|
priv struct TopLevelReferenceFact {
  from : TopLevelSymbol
  to : TopLevelSymbol
}

///|
priv struct ParameterHintSignature {
  symbol : AnalysisSymbol
  parameters : Array[ParameterHintParameter]
}

///|
priv struct ParameterHintParameter {
  name : String
  is_auto : Bool
}

///|
priv struct SemanticIndex {
  registry : @symbol.SymbolRegistry
  source_id : String
  source_text : String
  has_checked_source : Bool
  bindings : Array[SemanticBindingFact]
  members : Array[SemanticMemberFact]
  annotated_values : Array[@symbol.ValueSymbolId]
  generic_parameters : Array[GenericParameterFact]
  generic_parameter_references : Array[@symbol.TypeParameterId]
  used_import_symbols : Array[@resolve.ResolvedImportSymbol]
  top_level_declarations : Array[TopLevelDeclarationFact]
  top_level_references : Array[TopLevelReferenceFact]
  definitions : Array[DefinitionEntry]
  references : Array[ReferenceEntry]
  hovers : Array[HoverEntry]
  inlay_hints : Array[InlayHintEntry]
  parameter_signatures : Array[ParameterHintSignature]
  mut current_top_level : TopLevelSymbol?
}

///|
fn SemanticIndex::from_sources(
  resolved : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile?,
  display : @typecheck.TypeDisplayContext,
  source_id : String,
  source_text : String,
) -> SemanticIndex {
  let index = SemanticIndex::{
    registry: resolved.symbols,
    source_id,
    source_text,
    has_checked_source: checked is Some(_),
    bindings: [],
    members: [],
    annotated_values: [],
    generic_parameters: [],
    generic_parameter_references: [],
    used_import_symbols: [],
    top_level_declarations: [],
    top_level_references: [],
    definitions: [],
    references: [],
    hovers: [],
    inlay_hints: [],
    parameter_signatures: [],
    current_top_level: None,
  }
  for declaration in resolved.declarations {
    index.add_top_level_declaration(declaration)
  }
  for declaration in resolved.declarations {
    index.collect_resolved_declaration(declaration)
  }
  if checked is Some(source) {
    for declaration in source.declarations {
      index.enrich_checked_declaration_header(declaration, display)
    }
    for declaration in source.declarations {
      index.enrich_checked_declaration(declaration, display)
    }
  }
  index
}

///|
fn SemanticIndex::unused_private_top_level_declarations(
  self : SemanticIndex,
) -> Array[TopLevelDeclarationFact] {
  let reachable = []
  for declaration in self.top_level_declarations {
    if declaration.is_public {
      self.mark_top_level_reachable(declaration.symbol, reachable)
    }
  }
  let unused = self.top_level_declarations.filter(fn(declaration) {
    !declaration.is_public &&
    !declaration.name.has_prefix("_") &&
    !reachable.contains(declaration.symbol)
  })
  unused.sort_by(fn(left, right) {
    let by_start = left.loc.start_offset - right.loc.start_offset
    if by_start != 0 {
      by_start
    } else {
      left.loc.end_offset - right.loc.end_offset
    }
  })
  unused
}

///|
fn SemanticIndex::owner_members(
  self : SemanticIndex,
  owner : String,
) -> Array[SemanticMemberFact] {
  self.members.filter(fn(fact) {
    fact.owner_name == owner &&
    (match fact.kind {
      TypeMemberKind | VariantMemberKind | OperationMemberKind => true
      _ => false
    })
  })
}

///|
fn SemanticIndex::fields_for_type(
  self : SemanticIndex,
  owner : @symbol.TypeSymbolId,
) -> Array[SemanticMemberFact] {
  self.members.filter(fn(fact) {
    fact.kind is FieldMemberKind && fact.owner_type == Some(owner)
  })
}

///|
fn SemanticIndex::add_member(
  self : SemanticIndex,
  identity : SemanticMemberIdentity,
  owner_name : String,
  owner_type : @symbol.TypeSymbolId?,
  name : String,
  kind : SemanticMemberKind,
  detail : String,
  payload_count : Int?,
  loc : @basic.SourceSpan,
) -> Unit {
  self.members.push({
    identity,
    owner_name,
    owner_type,
    name,
    kind,
    detail,
    payload_count,
  })
  let symbol = match identity {
    FieldMember(symbol) => AnalysisSymbol::Field(symbol)
    TypeMember(symbol) => TypeMember(symbol)
    VariantMember(symbol) => Variant(symbol)
    OperationMember(symbol) => Operation(symbol)
  }
  self.add_definition(
    symbol,
    name_span(self.source_text, name, loc),
    name,
    detail,
  )
}

///|
fn SemanticIndex::enrich_member(
  self : SemanticIndex,
  identity : SemanticMemberIdentity,
  detail : String,
) -> Unit {
  for fact in self.members {
    if fact.identity == identity {
      fact.detail = detail
    }
  }
  let symbol = match identity {
    FieldMember(symbol) => AnalysisSymbol::Field(symbol)
    TypeMember(symbol) => TypeMember(symbol)
    VariantMember(symbol) => Variant(symbol)
    OperationMember(symbol) => Operation(symbol)
  }
  self.enrich_definition(symbol, detail)
}

///|
fn SemanticIndex::mark_top_level_reachable(
  self : SemanticIndex,
  symbol : TopLevelSymbol,
  reachable : Array[TopLevelSymbol],
) -> Unit {
  if reachable.contains(symbol) {
    return
  }
  reachable.push(symbol)
  for reference in self.top_level_references {
    if reference.from == symbol {
      self.mark_top_level_reachable(reference.to, reachable)
    }
  }
}

///|
fn SemanticIndex::add_top_level_declaration(
  self : SemanticIndex,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  match declaration {
    Struct(declaration) =>
      self.top_level_declarations.push({
        symbol: TopLevelType(declaration.symbol),
        name: declaration.name,
        kind: StructDeclaration,
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
    Enum(declaration) =>
      self.top_level_declarations.push({
        symbol: TopLevelType(declaration.symbol),
        name: declaration.name,
        kind: EnumDeclaration,
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
    ExternalType(declaration) =>
      self.top_level_declarations.push({
        symbol: TopLevelType(declaration.symbol),
        name: declaration.name,
        kind: ExternalTypeDeclaration,
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
    Effect(declaration) =>
      self.top_level_declarations.push({
        symbol: TopLevelEffect(declaration.symbol),
        name: declaration.name,
        kind: EffectDeclaration,
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
    TypeAlias(declaration) =>
      self.top_level_declarations.push({
        symbol: TopLevelAlias(declaration.name),
        name: declaration.name,
        kind: match declaration.body {
          TypeBody(_) => TypeAliasDeclaration
          EffectBody(_) => EffectAliasDeclaration
        },
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
    Function(declaration) => {
      self.top_level_declarations.push({
        symbol: TopLevelValue(declaration.symbol),
        name: declaration.name,
        kind: FunctionDeclaration,
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
      self.add_parameter_signature(declaration.symbol, declaration.parameters)
    }
    Let(declaration) =>
      if declaration.name is Some(name) {
        self.top_level_declarations.push({
          symbol: TopLevelValue(declaration.symbol),
          name,
          kind: ValueDeclaration,
          is_public: declaration.is_public,
          loc: declaration.loc,
        })
      }
    Offer(declaration) =>
      self.top_level_declarations.push({
        symbol: TopLevelValue(declaration.symbol),
        name: declaration.name,
        kind: ValueDeclaration,
        is_public: declaration.is_public,
        loc: declaration.loc,
      })
  }
}

///|
fn SemanticIndex::top_level_symbol(
  _self : SemanticIndex,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> TopLevelSymbol? {
  match declaration {
    Struct(declaration) => Some(TopLevelType(declaration.symbol))
    Enum(declaration) => Some(TopLevelType(declaration.symbol))
    ExternalType(declaration) => Some(TopLevelType(declaration.symbol))
    Effect(declaration) => Some(TopLevelEffect(declaration.symbol))
    TypeAlias(declaration) => Some(TopLevelAlias(declaration.name))
    Function(declaration) => Some(TopLevelValue(declaration.symbol))
    Let(declaration) =>
      if declaration.name is Some(_) {
        Some(TopLevelValue(declaration.symbol))
      } else {
        None
      }
    Offer(declaration) => Some(TopLevelValue(declaration.symbol))
  }
}

///|
fn SemanticIndex::with_top_level(
  self : SemanticIndex,
  symbol : TopLevelSymbol,
  collect : (SemanticIndex) -> Unit,
) -> Unit {
  let previous = self.current_top_level
  self.current_top_level = Some(symbol)
  collect(self)
  self.current_top_level = previous
}

///|
fn SemanticIndex::add_top_level_reference(
  self : SemanticIndex,
  target : TopLevelSymbol,
) -> Unit {
  if self.current_top_level is Some(from) &&
    self.top_level_declarations.any(fn(declaration) {
      declaration.symbol == target
    }) {
    self.top_level_references.push({ from, to: target })
  }
}

///|
fn SemanticIndex::unused_generic_parameters(
  self : SemanticIndex,
) -> Array[GenericParameterFact] {
  let unused = self.generic_parameters.filter(fn(parameter) {
    !parameter.name.has_prefix("_") &&
    !self.generic_parameter_references.contains(parameter.symbol)
  })
  unused.sort_by(fn(left, right) {
    let by_start = left.loc.start_offset - right.loc.start_offset
    if by_start != 0 {
      by_start
    } else {
      left.loc.end_offset - right.loc.end_offset
    }
  })
  unused
}

///|
fn SemanticIndex::unused_import_exposures(
  self : SemanticIndex,
  source : @resolve.ResolvedSourceFile,
) -> Array[@resolve.ResolvedImportExposure] {
  let used_exposure_ids = []
  for use_ in source.import_uses {
    add_unique_int(used_exposure_ids, use_.exposure_id)
  }
  for exposure_symbol in source.import_symbols {
    if self.used_import_symbols.contains(exposure_symbol.symbol) {
      add_unique_int(used_exposure_ids, exposure_symbol.exposure_id)
    }
  }
  source.import_exposures.filter(fn(exposure) {
    match exposure.kind {
      ImportedModuleBinding => false
      _ => !used_exposure_ids.contains(exposure.id)
    }
  })
}

///|
fn add_unique_int(values : Array[Int], value : Int) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn SemanticIndex::use_import_symbol(
  self : SemanticIndex,
  symbol : @resolve.ResolvedImportSymbol,
) -> Unit {
  if !self.used_import_symbols.contains(symbol) {
    self.used_import_symbols.push(symbol)
  }
}

///|
fn SemanticIndex::visible_bindings(
  self : SemanticIndex,
  line : Int,
  column : Int,
) -> Array[SemanticBindingFact] {
  self.bindings.filter(fn(binding) {
    binding.visibility.is_visible_at(line, column)
  })
}

///|
fn SemanticBindingVisibility::is_visible_at(
  self : SemanticBindingVisibility,
  line : Int,
  column : Int,
) -> Bool {
  match self {
    GlobalBinding => true
    ScopedBinding(scope) => scope.contains_completion_position(line, column)
    OrderedBinding(scope~, declaration~) =>
      scope.contains_completion_position(line, column) &&
      (
        declaration.start_line < line ||
        (declaration.start_line == line && declaration.start_column < column)
      )
  }
}

///|
fn @basic.SourceSpan::contains_completion_position(
  self : @basic.SourceSpan,
  line : Int,
  column : Int,
) -> Bool {
  self.contains_position(line, column) ||
  (line == self.end_line && column == self.end_column)
}

///|
fn SemanticIndex::receiver_type(
  self : SemanticIndex,
  name : String,
  line : Int,
  column : Int,
) -> @types.Type? {
  for index = self.bindings.length(); index > 0; index = index - 1 {
    let binding = self.bindings[index - 1]
    if binding.name == name &&
      binding.visibility.is_visible_at(line, column) &&
      binding.type_ is Some(type_) {
      return Some(type_)
    }
  }
  None
}

///|
fn SemanticIndex::add_binding(
  self : SemanticIndex,
  identity : SemanticBindingIdentity,
  name : String,
  kind : SemanticBindingKind,
  detail : String,
  visibility : SemanticBindingVisibility,
  loc? : @basic.SourceSpan,
) -> Unit {
  self.bindings.push({ identity, name, kind, detail, type_: None, visibility })
  if loc is Some(loc) {
    let symbol = match identity {
      ValueBinding(symbol) => Some(AnalysisSymbol::Value(symbol))
      TypeBinding(symbol) => Some(Type(symbol))
      EffectBinding(symbol) => Some(Effect(symbol))
      TypeParameterBinding(symbol) => Some(TypeParameter(symbol))
      AliasBinding(_) => None
    }
    if symbol is Some(symbol) {
      self.add_definition(symbol, loc, name, detail)
    }
  }
}

///|
fn SemanticIndex::enrich_binding(
  self : SemanticIndex,
  identity : SemanticBindingIdentity,
  detail : String,
  type_ : @types.Type?,
) -> Unit {
  for binding in self.bindings {
    if binding.identity == identity {
      binding.detail = detail
      binding.type_ = type_
    }
  }
  let symbol = match identity {
    ValueBinding(symbol) => Some(AnalysisSymbol::Value(symbol))
    TypeBinding(symbol) => Some(Type(symbol))
    EffectBinding(symbol) => Some(Effect(symbol))
    TypeParameterBinding(symbol) => Some(TypeParameter(symbol))
    AliasBinding(_) => None
  }
  if symbol is Some(symbol) {
    self.enrich_definition(symbol, detail)
  }
}

///|
fn SemanticIndex::collect_resolved_declaration(
  self : SemanticIndex,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  match self.top_level_symbol(declaration) {
    Some(symbol) =>
      self.with_top_level(symbol, fn(index) {
        index.collect_resolved_declaration_body(declaration)
      })
    None => self.collect_resolved_declaration_body(declaration)
  }
}

///|
fn SemanticIndex::collect_resolved_declaration_body(
  self : SemanticIndex,
  declaration : @resolve.ResolvedTopLevelDeclaration,
) -> Unit {
  match declaration {
    Struct(declaration) => {
      self.add_binding(
        TypeBinding(declaration.symbol),
        declaration.name,
        TypeBindingKind,
        "struct \{declaration.name}",
        GlobalBinding,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.add_resolved_type_parameters(
        declaration.type_parameters,
        ScopedBinding(declaration.loc),
      )
      for struct_member in declaration.members {
        match struct_member {
          TypeMember(type_member) =>
            self.add_member(
              TypeMember(type_member.symbol),
              declaration.name,
              Some(declaration.symbol),
              type_member.name,
              TypeMemberKind,
              "type \{type_member.name}",
              None,
              type_member.loc,
            )
          Field(field) => {
            self.add_member(
              FieldMember(field.symbol),
              declaration.name,
              Some(declaration.symbol),
              field.name,
              FieldMemberKind,
              "field \{field.name}",
              None,
              field.loc,
            )
            self.collect_resolved_type(field.type_)
          }
        }
      }
    }
    Enum(declaration) => {
      self.add_binding(
        TypeBinding(declaration.symbol),
        declaration.name,
        TypeBindingKind,
        "enum \{declaration.name}",
        GlobalBinding,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.add_resolved_type_parameters(
        declaration.type_parameters,
        ScopedBinding(declaration.loc),
      )
      for variant in declaration.variants {
        self.add_member(
          VariantMember(variant.symbol),
          declaration.name,
          Some(declaration.symbol),
          variant.name,
          VariantMemberKind,
          "variant \{declaration.name}::\{variant.name}",
          Some(variant.payload.length()),
          variant.loc,
        )
        self.add_resolved_type_parameters(
          variant.type_parameters,
          ScopedBinding(variant.loc),
        )
        for payload in variant.payload {
          self.collect_resolved_type(payload)
        }
      }
    }
    ExternalType(declaration) => {
      self.add_binding(
        TypeBinding(declaration.symbol),
        declaration.name,
        TypeBindingKind,
        "extern type \{declaration.name} : Type",
        GlobalBinding,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.add_resolved_type_parameters(
        declaration.type_parameters,
        ScopedBinding(declaration.loc),
      )
    }
    Effect(declaration) => {
      self.add_binding(
        EffectBinding(declaration.symbol),
        declaration.name,
        EffectBindingKind,
        effect_completion_detail(declaration.name, declaration.flavor),
        GlobalBinding,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      if declaration.flavor is Algebraic {
        self.add_resolved_type_parameters(
          declaration.type_parameters,
          ScopedBinding(declaration.loc),
        )
        for operation in declaration.operations {
          self.add_member(
            OperationMember(operation.symbol),
            declaration.name,
            None,
            operation.name,
            OperationMemberKind,
            "operation \{declaration.name}::\{operation.name}",
            None,
            operation.loc,
          )
          self.add_resolved_type_parameters(
            operation.type_parameters,
            ScopedBinding(operation.loc),
          )
          for payload in operation.payload {
            self.collect_resolved_type(payload)
          }
          self.collect_resolved_type(operation.result)
        }
      } else {
        self.add_completion_type_parameters(
          declaration.type_parameters,
          ScopedBinding(declaration.loc),
        )
      }
    }
    TypeAlias(declaration) => {
      let (kind, detail) = match declaration.body {
        TypeBody(_) => (TypeBindingKind, "type \{declaration.name}")
        EffectBody(_) => (EffectBindingKind, "effect alias \{declaration.name}")
      }
      self.add_binding(
        AliasBinding(declaration.name),
        declaration.name,
        kind,
        detail,
        GlobalBinding,
      )
      self.add_resolved_type_parameters(
        declaration.type_parameters,
        ScopedBinding(declaration.loc),
      )
      match declaration.body {
        TypeBody(type_) => self.collect_resolved_type(type_)
        EffectBody(effect) => self.collect_resolved_effect(effect)
      }
    }
    Function(declaration) => {
      self.add_binding(
        ValueBinding(declaration.symbol),
        declaration.name,
        FunctionBindingKind,
        "fn \{declaration.name}",
        GlobalBinding,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.add_resolved_type_parameters(
        declaration.type_parameters,
        ScopedBinding(declaration.loc),
      )
      for parameter in declaration.parameters {
        self.annotated_values.push(parameter.symbol)
        self.add_binding(
          ValueBinding(parameter.symbol),
          parameter.name,
          ValueBindingKind,
          "parameter \{parameter.name}",
          ScopedBinding(declaration.body.loc()),
          loc=name_span(self.source_text, parameter.name, parameter.loc),
        )
        self.collect_resolved_type(parameter.type_)
      }
      self.collect_resolved_type(declaration.return_type)
      self.collect_resolved_effect(declaration.effect)
      self.collect_resolved_expr(declaration.body)
    }
    Let(declaration) => {
      if declaration.type_annotation is Some(_) {
        self.annotated_values.push(declaration.symbol)
      }
      if declaration.type_annotation is Some(type_) {
        self.collect_resolved_type(type_)
      }
      if declaration.name is Some(name) {
        self.add_binding(
          ValueBinding(declaration.symbol),
          name,
          ValueBindingKind,
          "let \{name}",
          GlobalBinding,
          loc=name_span(self.source_text, name, declaration.loc),
        )
      }
      self.collect_resolved_expr(declaration.initializer)
    }
    Offer(declaration) => {
      self.annotated_values.push(declaration.symbol)
      self.collect_resolved_type(declaration.type_annotation)
      self.add_binding(
        ValueBinding(declaration.symbol),
        declaration.name,
        OfferBindingKind,
        "offer \{declaration.name}",
        GlobalBinding,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.collect_resolved_expr(declaration.initializer)
    }
  }
}

///|
fn SemanticIndex::add_resolved_type_parameters(
  self : SemanticIndex,
  parameters : Array[@resolve.ResolvedTypeParameter],
  visibility : SemanticBindingVisibility,
) -> Unit {
  self.add_generic_parameters(parameters)
  self.add_completion_type_parameters(parameters, visibility)
}

///|
fn SemanticIndex::add_generic_parameters(
  self : SemanticIndex,
  parameters : Array[@resolve.ResolvedTypeParameter],
) -> Unit {
  for parameter in parameters {
    self.generic_parameters.push({
      symbol: parameter.symbol,
      name: parameter.name,
      kind: match parameter.kind {
        Some(Effect(_)) => GenericEffectParameter
        _ => GenericTypeParameter
      },
      loc: parameter.loc,
    })
  }
}

///|
fn SemanticIndex::add_completion_type_parameters(
  self : SemanticIndex,
  parameters : Array[@resolve.ResolvedTypeParameter],
  visibility : SemanticBindingVisibility,
) -> Unit {
  for parameter in parameters {
    self.add_binding(
      TypeParameterBinding(parameter.symbol),
      parameter.name,
      TypeParameterBindingKind,
      "type parameter \{parameter.name}",
      visibility,
      loc=parameter.loc,
    )
  }
}

///|
fn SemanticIndex::collect_resolved_local_item(
  self : SemanticIndex,
  item : @resolve.ResolvedLocalItem,
  scope : @basic.SourceSpan,
) -> Unit {
  let visibility = OrderedBinding(
    scope~,
    declaration=resolved_local_item_loc(item),
  )
  match item {
    Let(declaration) => {
      if declaration.type_annotation is Some(_) {
        self.annotated_values.push(declaration.symbol)
      }
      if declaration.type_annotation is Some(type_) {
        self.collect_resolved_type(type_)
      }
      if declaration.name is Some(name) {
        self.add_binding(
          ValueBinding(declaration.symbol),
          name,
          ValueBindingKind,
          "let \{name}",
          visibility,
          loc=name_span(self.source_text, name, declaration.loc),
        )
      }
      self.collect_resolved_expr(declaration.initializer)
    }
    PatternLet(declaration) => {
      if declaration.type_annotation is Some(type_) {
        self.collect_resolved_type(type_)
      }
      self.collect_resolved_expr(declaration.initializer)
      self.collect_resolved_pattern(declaration.pattern, visibility)
    }
    Function(declaration) => {
      self.add_binding(
        ValueBinding(declaration.symbol),
        declaration.name,
        FunctionBindingKind,
        "fn \{declaration.name}",
        visibility,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.add_parameter_signature(declaration.symbol, declaration.parameters)
      self.add_resolved_type_parameters(
        declaration.type_parameters,
        ScopedBinding(declaration.body.loc()),
      )
      for parameter in declaration.parameters {
        self.annotated_values.push(parameter.symbol)
        self.add_binding(
          ValueBinding(parameter.symbol),
          parameter.name,
          ValueBindingKind,
          "parameter \{parameter.name}",
          ScopedBinding(declaration.body.loc()),
          loc=name_span(self.source_text, parameter.name, parameter.loc),
        )
        self.collect_resolved_type(parameter.type_)
      }
      self.collect_resolved_type(declaration.return_type)
      self.collect_resolved_effect(declaration.effect)
      self.collect_resolved_expr(declaration.body)
    }
    Offer(declaration) => {
      self.annotated_values.push(declaration.symbol)
      self.collect_resolved_type(declaration.type_annotation)
      self.add_binding(
        ValueBinding(declaration.symbol),
        declaration.name,
        OfferBindingKind,
        "offer \{declaration.name}",
        visibility,
        loc=name_span(self.source_text, declaration.name, declaration.loc),
      )
      self.collect_resolved_expr(declaration.initializer)
    }
  }
}

///|
fn resolved_local_item_loc(
  item : @resolve.ResolvedLocalItem,
) -> @basic.SourceSpan {
  match item {
    Let(declaration) => declaration.loc
    PatternLet(declaration) => declaration.loc
    Function(declaration) => declaration.loc
    Offer(declaration) => declaration.loc
  }
}

///|
fn SemanticIndex::collect_resolved_expr(
  self : SemanticIndex,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  self.collect_resolved_expr_types(expr)
  self.collect_resolved_expr_symbols(expr)
  match expr {
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      ..
    ) => {
      let scope = ScopedBinding(body.loc())
      self.add_resolved_type_parameters(type_parameters, scope)
      for parameter in parameters {
        if parameter.type_annotation is Some(_) {
          self.annotated_values.push(parameter.symbol)
        }
        self.add_binding(
          ValueBinding(parameter.symbol),
          parameter.name,
          ValueBindingKind,
          "parameter \{parameter.name}",
          scope,
          loc=name_span(self.source_text, parameter.name, parameter.loc),
        )
        if parameter.type_annotation is Some(type_) {
          self.collect_resolved_type(type_)
        }
      }
      if return_type is Some(type_) {
        self.collect_resolved_type(type_)
      }
      if effect is Some(effect) {
        self.collect_resolved_effect(effect)
      }
      self.collect_resolved_expr(body)
    }
    Block(items~, result~, loc~) => {
      for item in items {
        self.collect_resolved_local_item(item, loc)
      }
      self.collect_resolved_expr(result)
    }
    Match(scrutinee~, arms~, ..) => {
      self.collect_resolved_expr(scrutinee)
      for arm in arms {
        let visibility = ScopedBinding(arm.body.loc())
        self.collect_resolved_pattern(arm.pattern, visibility)
        self.collect_resolved_expr(arm.body)
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      self.collect_resolved_expr(body)
      for handler in handlers {
        for arm in handler.arms {
          let visibility = ScopedBinding(arm.body.loc())
          self.add_resolved_type_parameters(arm.type_binders, visibility)
          for pattern in arm.payload_patterns {
            self.collect_resolved_pattern(pattern, visibility)
          }
          self.add_binding(
            ValueBinding(arm.resume_symbol),
            arm.resume_binder,
            ValueBindingKind,
            "resume \{arm.resume_binder}",
            visibility,
            loc=name_span(self.source_text, arm.resume_binder, arm.resume_loc),
          )
          self.collect_resolved_expr(arm.body)
        }
      }
      self.add_binding(
        ValueBinding(final_branch.binder_symbol),
        final_branch.binder,
        ValueBindingKind,
        "final \{final_branch.binder}",
        ScopedBinding(final_branch.body.loc()),
        loc=name_span(
          self.source_text,
          final_branch.binder,
          final_branch.binder_loc,
        ),
      )
      self.collect_resolved_expr(final_branch.body)
    }
    _ =>
      expr.for_each_child_expr(fn(child) { self.collect_resolved_expr(child) })
  }
}

///|
fn SemanticIndex::collect_resolved_expr_types(
  self : SemanticIndex,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  match expr {
    QualifiedVariant(generic_arguments~, variant_generic_arguments~, ..) => {
      for argument in generic_arguments {
        self.collect_resolved_generic_argument(argument)
      }
      for argument in variant_generic_arguments {
        self.collect_resolved_generic_argument(argument)
      }
    }
    UnqualifiedVariant(variant_generic_arguments~, ..) =>
      for argument in variant_generic_arguments {
        self.collect_resolved_generic_argument(argument)
      }
    StructLiteral(generic_arguments~, fields~, ..) => {
      for argument in generic_arguments {
        self.collect_resolved_generic_argument(argument)
      }
      for field in fields {
        if field is TypeWitness(witness~, ..) {
          self.collect_resolved_type(witness)
        }
      }
    }
    EffectOperationCall(generic_witnesses~, ..) =>
      for witness in generic_witnesses {
        self.collect_resolved_generic_argument(witness)
      }
    GenericApplication(arguments~, ..) =>
      for argument in arguments {
        self.collect_resolved_generic_argument(argument)
      }
    _ => ()
  }
}

///|
fn SemanticIndex::collect_resolved_expr_symbols(
  self : SemanticIndex,
  expr : @resolve.ResolvedExpr,
) -> Unit {
  match expr {
    Var(name~, reference~, loc~) => {
      self.collect_resolved_value_reference(reference)
      if !self.has_checked_source && reference is Symbol(symbol) {
        self.add_reference(Value(symbol), loc, Some(name))
      }
    }
    QualifiedVariant(reference~, loc~, ..)
    | UnqualifiedVariant(reference~, loc~, ..) => {
      self.collect_resolved_variant_reference(reference)
      if !self.has_checked_source && reference is Symbol(symbol) {
        self.add_reference(
          Variant(symbol),
          self.definition_span(Variant(symbol), loc),
          self.definition_detail(Variant(symbol)),
        )
      }
    }
    ListLiteral(empty_reference~, cons_reference~, ..) => {
      self.collect_resolved_variant_reference(empty_reference)
      if cons_reference is Some(reference) {
        self.collect_resolved_variant_reference(reference)
      }
    }
    StructLiteral(fields~, ..) =>
      for field in fields {
        if field is Value(name~, value~, punned_reference=Some(reference), loc~) {
          self.collect_resolved_value_reference(reference)
          if !self.has_checked_source && reference is Symbol(symbol) {
            let span = match value {
              Some(value) => value.loc()
              None => loc
            }
            self.add_reference(Value(symbol), span, Some(name))
          }
        }
      }
    EffectOperationCall(name~, ..) => {
      self.collect_resolved_operation_name(name)
      if !self.has_checked_source {
        self.add_resolved_operation_reference(name)
      }
    }
    Handler(handlers~, ..) =>
      for handler in handlers {
        for arm in handler.arms {
          self.collect_resolved_operation_name(arm.name)
          if !self.has_checked_source {
            self.add_resolved_operation_reference(arm.name)
          }
        }
      }
    Field(reference~, name~, loc~, ..) => {
      self.collect_resolved_field_reference(reference)
      if !self.has_checked_source && reference is Symbol(symbol) {
        self.add_reference(Field(symbol), loc, Some(name))
      }
    }
    Unary(reference~, loc~, ..) | Binary(reference~, loc~, ..) => {
      self.collect_resolved_value_reference(reference)
      if !self.has_checked_source && reference is Symbol(symbol) {
        self.add_reference(Value(symbol), loc, None)
      }
    }
    _ => ()
  }
}

///|
fn SemanticIndex::add_resolved_operation_reference(
  self : SemanticIndex,
  name : @resolve.ResolvedEffectOperationName,
) -> Unit {
  let (operation, reference, loc) = match name {
    Qualified(operation~, reference~, loc~, ..) => (operation, reference, loc)
    Unqualified(operation~, reference~, loc~) => (operation, reference, loc)
  }
  if reference is Symbol(symbol) {
    self.add_reference(
      Operation(symbol),
      name_span(self.source_text, operation, loc),
      Some("operation \{operation}"),
    )
  }
}

///|
fn SemanticIndex::collect_resolved_value_reference(
  self : SemanticIndex,
  reference : @resolve.ResolvedValueReference,
) -> Unit {
  if reference is Symbol(symbol) {
    self.add_top_level_reference(TopLevelValue(symbol))
  }
}

///|
fn SemanticIndex::collect_resolved_field_reference(
  self : SemanticIndex,
  reference : @resolve.ResolvedFieldReference,
) -> Unit {
  if reference is Symbol(symbol) {
    if self.registry.field_metadata(symbol) is Some(metadata) {
      self.add_top_level_reference(TopLevelType(metadata.owner))
    }
  }
}

///|
fn SemanticIndex::collect_resolved_variant_reference(
  self : SemanticIndex,
  reference : @resolve.ResolvedVariantReference,
) -> Unit {
  match reference {
    Symbol(symbol) =>
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
    Ambiguous(candidates~, ..) =>
      for candidate in candidates {
        if self.registry.variant_metadata(candidate) is Some(metadata) {
          self.add_top_level_reference(TopLevelType(metadata.owner))
        }
      }
    Unresolved(_) | UnresolvedUnqualified(_) => ()
  }
}

///|
fn SemanticIndex::collect_resolved_operation_name(
  self : SemanticIndex,
  name : @resolve.ResolvedEffectOperationName,
) -> Unit {
  match name {
    Qualified(owner~, reference~, ..) => {
      self.collect_resolved_effect(owner)
      self.collect_resolved_operation_reference(reference)
    }
    Unqualified(reference~, ..) =>
      self.collect_resolved_operation_reference(reference)
  }
}

///|
fn SemanticIndex::collect_resolved_operation_reference(
  self : SemanticIndex,
  reference : @resolve.ResolvedOperationReference,
) -> Unit {
  match reference {
    Symbol(symbol) =>
      if self.registry.operation_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelEffect(metadata.owner))
      }
    Ambiguous(candidates~, ..) =>
      for candidate in candidates {
        if self.registry.operation_metadata(candidate) is Some(metadata) {
          self.add_top_level_reference(TopLevelEffect(metadata.owner))
        }
      }
    Unresolved(_) => ()
  }
}

///|
fn SemanticIndex::collect_resolved_pattern(
  self : SemanticIndex,
  pattern : @resolve.ResolvedPattern,
  visibility : SemanticBindingVisibility,
) -> Unit {
  match pattern {
    QualifiedVariant(type_binders~, reference~, arguments~, loc~, ..) => {
      self.add_resolved_type_parameters(type_binders, visibility)
      self.collect_resolved_variant_reference(reference)
      if !self.has_checked_source && reference is Symbol(symbol) {
        self.add_reference(
          Variant(symbol),
          self.definition_span(Variant(symbol), loc),
          self.definition_detail(Variant(symbol)),
        )
      }
      for argument in arguments {
        self.collect_resolved_pattern(argument, visibility)
      }
    }
    UnqualifiedVariant(type_binders~, arguments~, ..) => {
      self.add_resolved_type_parameters(type_binders, visibility)
      for argument in arguments {
        self.collect_resolved_pattern(argument, visibility)
      }
    }
    Struct(fields~, ..) =>
      for field in fields {
        match field {
          Value(pattern~, ..) =>
            self.collect_resolved_pattern(pattern, visibility)
          TypeBinder(type_parameter~, ..) | TypeWildcard(type_parameter~, ..) =>
            self.add_resolved_type_parameters([type_parameter], visibility)
        }
      }
    Binding(name~, symbol~, loc~) =>
      self.add_binding(
        ValueBinding(symbol),
        name,
        ValueBindingKind,
        "pattern \{name}",
        visibility,
        loc~,
      )
    Wildcard(_)
    | IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_) => ()
  }
}

///|
fn SemanticIndex::collect_resolved_type(
  self : SemanticIndex,
  type_ : @resolve.ResolvedType,
) -> Unit {
  match type_ {
    Primitive(_) => ()
    Constructor(symbol~, name~, loc~) => {
      self.add_reference(Type(symbol), loc, Some("type \{name}"))
      self.add_top_level_reference(TopLevelType(symbol))
    }
    Alias(name~, loc~) => {
      self.add_top_level_reference(TopLevelAlias(name))
      self.hovers.push({
        location: { source_id: self.source_id, span: loc },
        contents: "type alias \{name}",
      })
    }
    Apply(callee~, arguments~, ..) => {
      self.collect_resolved_type(callee)
      for argument in arguments {
        self.collect_resolved_generic_argument(argument)
      }
    }
    TypeLambda(parameters~, body~, ..) => {
      self.add_generic_parameters(parameters)
      self.collect_resolved_type(body)
    }
    Parameter(symbol~, name~, loc~) => {
      self.generic_parameter_references.push(symbol)
      self.add_reference(TypeParameter(symbol), loc, Some("type \{name}"))
    }
    Function(type_parameters~, parameters~, result~, effect~, ..) => {
      self.add_generic_parameters(type_parameters)
      for parameter in parameters {
        self.collect_resolved_type(parameter)
      }
      self.collect_resolved_type(result)
      self.collect_resolved_effect(effect)
    }
    Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_resolved_generic_argument(argument)
      }
  }
}

///|
fn SemanticIndex::collect_resolved_effect(
  self : SemanticIndex,
  effect : @resolve.ResolvedEffectTerm,
) -> Unit {
  match effect {
    Empty(_) => ()
    Io(arguments~, ..) | Unresolved(arguments~, ..) =>
      for argument in arguments {
        self.collect_resolved_generic_argument(argument)
      }
    Singleton(symbol~, name~, arguments~, loc~) => {
      self.add_reference(Effect(symbol), loc, Some("effect \{name}"))
      self.add_top_level_reference(TopLevelEffect(symbol))
      for argument in arguments {
        self.collect_resolved_generic_argument(argument)
      }
    }
    Parameter(symbol~, name~, loc~) => {
      self.generic_parameter_references.push(symbol)
      self.add_reference(TypeParameter(symbol), loc, Some("effect \{name}"))
    }
    Alias(name~, arguments~, loc~) => {
      self.add_top_level_reference(TopLevelAlias(name))
      self.hovers.push({
        location: { source_id: self.source_id, span: loc },
        contents: "effect alias \{name}",
      })
      for argument in arguments {
        match argument {
          TypeArgument(type_) => self.collect_resolved_type(type_)
          EffectArgument(effect) => self.collect_resolved_effect(effect)
        }
      }
    }
    Union(items~, ..) =>
      for item in items {
        self.collect_resolved_effect(item)
      }
  }
}

///|
fn SemanticIndex::collect_resolved_generic_argument(
  self : SemanticIndex,
  argument : @resolve.ResolvedGenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_resolved_type(type_)
    EffectArgument(effect) => self.collect_resolved_effect(effect)
  }
}

///|
fn SemanticIndex::enrich_checked_declaration(
  self : SemanticIndex,
  declaration : @checked.CheckedTopLevelDeclaration,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  let symbol = match declaration {
    Struct(declaration) => TopLevelType(declaration.symbol)
    Enum(declaration) => TopLevelType(declaration.symbol)
    ExternalType(declaration) => TopLevelType(declaration.symbol)
    Effect(declaration) => TopLevelEffect(declaration.symbol)
    Function(declaration) => TopLevelValue(declaration.symbol)
    Let(declaration) => TopLevelValue(declaration.symbol)
  }
  self.with_top_level(symbol, fn(index) {
    index.enrich_checked_declaration_body(declaration, display)
  })
}

///|
fn SemanticIndex::enrich_checked_declaration_header(
  self : SemanticIndex,
  declaration : @checked.CheckedTopLevelDeclaration,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  match declaration {
    Struct(declaration) => {
      self.enrich_binding(
        TypeBinding(declaration.symbol),
        "type \{declaration.name} : Type",
        None,
      )
      self.enrich_checked_type_parameters(declaration.type_parameters, display)
      for type_member in declaration.type_members {
        self.enrich_member(
          TypeMember(type_member.symbol),
          "\{type_member.name} : \{display.kind_text(type_member.kind)}",
        )
      }
      for field in declaration.fields {
        self.enrich_member(
          FieldMember(field.symbol),
          "\{field.name} : \{display.type_text(field.type_)}",
        )
      }
    }
    Enum(declaration) => {
      self.enrich_binding(
        TypeBinding(declaration.symbol),
        "type \{declaration.name} : Type",
        None,
      )
      self.enrich_checked_type_parameters(declaration.type_parameters, display)
      for variant in declaration.variants {
        let payload = variant.payload
          .map(fn(type_) { display.type_text(type_) })
          .join(", ")
        self.enrich_member(
          VariantMember(variant.symbol),
          if payload == "" {
            variant.name
          } else {
            "\{variant.name}(\{payload})"
          },
        )
      }
    }
    ExternalType(declaration) =>
      self.enrich_binding(
        TypeBinding(declaration.symbol),
        "extern type \{declaration.name} : Type",
        None,
      )
    Effect(declaration) => {
      self.enrich_binding(
        EffectBinding(declaration.symbol),
        checked_effect_detail(declaration, display),
        None,
      )
      self.enrich_checked_type_parameters(declaration.type_parameters, display)
      for operation in declaration.operations {
        self.enrich_checked_type_parameters(operation.type_parameters, display)
        let payload = operation.payload
          .map(fn(type_) { display.type_text(type_) })
          .join(", ")
        self.enrich_member(
          OperationMember(operation.symbol),
          "\{declaration.name}::\{operation.name}(\{payload}) -> \{display.type_text(operation.result)}",
        )
      }
    }
    Function(declaration) => {
      self.enrich_binding(
        ValueBinding(declaration.symbol),
        "\{declaration.name} : \{display.type_text(declaration.type_)}",
        Some(declaration.type_),
      )
      self.enrich_checked_type_parameters(declaration.type_parameters, display)
      for parameter in declaration.parameters {
        self.enrich_checked_parameter(parameter, display)
      }
    }
    Let(declaration) =>
      if declaration.name is Some(name) {
        self.enrich_binding(
          ValueBinding(declaration.symbol),
          "\{name} : \{display.type_text(declaration.type_)}",
          Some(declaration.type_),
        )
      }
  }
}

///|
fn SemanticIndex::enrich_checked_declaration_body(
  self : SemanticIndex,
  declaration : @checked.CheckedTopLevelDeclaration,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  match declaration {
    Struct(declaration) =>
      for field in declaration.fields {
        self.collect_checked_type(field.type_)
      }
    Enum(declaration) =>
      for variant in declaration.variants {
        for payload in variant.payload {
          self.collect_checked_type(payload)
        }
      }
    ExternalType(_) => ()
    Effect(declaration) =>
      for operation in declaration.operations {
        for payload in operation.payload {
          self.collect_checked_type(payload)
        }
        self.collect_checked_type(operation.result)
      }
    Function(declaration) => {
      for parameter in declaration.parameters {
        self.collect_checked_type(parameter.type_)
      }
      self.collect_checked_type(declaration.return_type)
      self.collect_checked_type(declaration.type_)
      self.enrich_checked_expr(declaration.body, display)
    }
    Let(declaration) => {
      if declaration.name is Some(name) {
        if !self.annotated_values.contains(declaration.symbol) {
          self.add_type_inlay_hint(
            name_span(self.source_text, name, declaration.loc),
            display,
            declaration.type_,
          )
        }
      }
      self.collect_checked_type(declaration.type_)
      self.enrich_checked_expr(declaration.initializer, display)
    }
  }
}

///|
fn SemanticIndex::enrich_checked_type_parameters(
  self : SemanticIndex,
  parameters : Array[@types.TypeParameter],
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  for parameter in parameters {
    self.enrich_binding(
      TypeParameterBinding(parameter.id),
      "\{parameter.name} : \{display.kind_text(parameter.kind)}",
      None,
    )
  }
}

///|
fn SemanticIndex::enrich_checked_parameter(
  self : SemanticIndex,
  parameter : @checked.CheckedValueParameter,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  self.enrich_binding(
    ValueBinding(parameter.symbol),
    "\{parameter.name} : \{display.type_text(parameter.type_)}",
    Some(parameter.type_),
  )
}

///|
fn SemanticIndex::enrich_checked_local_item(
  self : SemanticIndex,
  item : @checked.CheckedLocalItem,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  match item {
    Let(declaration) => {
      if declaration.name is Some(name) {
        self.enrich_binding(
          ValueBinding(declaration.symbol),
          "\{name} : \{display.type_text(declaration.type_)}",
          Some(declaration.type_),
        )
        if !self.annotated_values.contains(declaration.symbol) {
          self.add_type_inlay_hint(
            name_span(self.source_text, name, declaration.loc),
            display,
            declaration.type_,
          )
        }
      }
      self.collect_checked_type(declaration.type_)
      self.enrich_checked_expr(declaration.initializer, display)
    }
    PatternLet(declaration) => {
      self.enrich_checked_pattern(declaration.pattern, display)
      self.enrich_checked_expr(declaration.initializer, display)
    }
    Function(declaration) => {
      self.enrich_binding(
        ValueBinding(declaration.symbol),
        "\{declaration.name} : \{display.type_text(declaration.type_)}",
        Some(declaration.type_),
      )
      self.enrich_checked_type_parameters(declaration.type_parameters, display)
      for parameter in declaration.parameters {
        self.enrich_checked_parameter(parameter, display)
        self.collect_checked_type(parameter.type_)
      }
      self.collect_checked_type(declaration.return_type)
      self.collect_checked_type(declaration.type_)
      self.enrich_checked_expr(declaration.body, display)
    }
  }
}

///|
fn SemanticIndex::enrich_checked_expr(
  self : SemanticIndex,
  expr : @checked.CheckedExpr,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  self.collect_checked_expr_types(expr)
  match expr {
    Value(name~, symbol~, type_~, loc~) =>
      self.add_reference(
        Value(symbol),
        loc,
        Some(value_detail(name, type_, display)),
      )
    FunctionLiteral(type_parameters~, parameters~, body~, ..) => {
      self.enrich_checked_type_parameters(type_parameters, display)
      for parameter in parameters {
        self.enrich_checked_parameter(parameter, display)
        if !self.annotated_values.contains(parameter.symbol) {
          self.add_type_inlay_hint(
            name_span(self.source_text, parameter.name, parameter.loc),
            display,
            parameter.type_,
          )
        }
      }
      self.enrich_checked_expr(body, display)
    }
    Block(items~, result~, ..) => {
      for item in items {
        self.enrich_checked_local_item(item, display)
      }
      self.enrich_checked_expr(result, display)
    }
    Match(scrutinee~, arms~, ..) => {
      self.enrich_checked_expr(scrutinee, display)
      for arm in arms {
        self.enrich_checked_pattern(arm.pattern, display)
        self.enrich_checked_expr(arm.body, display)
      }
    }
    Call(callee~, arguments~, loc~, ..) => {
      self.add_call_inlay_hints(callee, arguments, loc)
      self.enrich_checked_expr(callee, display)
      for argument in arguments {
        self.enrich_checked_expr(argument.value, display)
      }
    }
    OperationCall(operation~, arguments~, loc~, ..) => {
      self.add_operation_reference(operation, loc)
      for argument in arguments {
        self.enrich_checked_expr(argument, display)
      }
    }
    Handler(body~, handlers~, final_branch~, ..) => {
      if body is Some(body) {
        self.enrich_checked_expr(body, display)
      }
      for handler in handlers {
        for arm in handler.operations {
          self.add_operation_reference(arm.operation, arm.loc)
          self.enrich_binding(
            ValueBinding(arm.resume_symbol),
            "\{arm.resume_binder} : \{display.type_text(arm.resume_type)}",
            Some(arm.resume_type),
          )
          for pattern in arm.payload_patterns {
            self.enrich_checked_pattern(pattern, display)
          }
          if arm.body is Some(body) {
            self.enrich_checked_expr(body, display)
          }
        }
      }
      self.enrich_binding(
        ValueBinding(final_branch.binder_symbol),
        "\{final_branch.binder} : \{display.type_text(final_branch.binder_type)}",
        Some(final_branch.binder_type),
      )
      if final_branch.body is Some(body) {
        self.enrich_checked_expr(body, display)
      }
    }
    Field(base~, field~, name~, type_~, loc~) => {
      self.enrich_checked_expr(base, display)
      self.add_reference(
        Field(field),
        loc,
        Some(field_detail(name, type_, display)),
      )
    }
    StructLiteral(symbol~, type_witnesses~, fields~, loc~, ..) => {
      self.add_reference(
        Type(symbol),
        self.definition_span(Type(symbol), loc),
        Some(type_reference_detail(Constructor(symbol), display)),
      )
      for witness in type_witnesses {
        self.add_reference(
          TypeMember(witness.symbol),
          witness.loc,
          Some(type_member_witness_detail(witness.name, witness.type_, display)),
        )
      }
      for field in fields {
        self.add_reference(
          Field(field.symbol),
          field.loc,
          Some(field_detail(field.name, field.value.type_(), display)),
        )
        self.enrich_checked_expr(field.value, display)
      }
    }
    Variant(symbol~, arguments~, loc~, ..) => {
      self.add_reference(
        Variant(symbol),
        self.definition_span(Variant(symbol), loc),
        self.definition_detail(Variant(symbol)),
      )
      for argument in arguments {
        self.enrich_checked_expr(argument, display)
      }
    }
    _ =>
      expr.for_each_child_expr(fn(child) {
        self.enrich_checked_expr(child, display)
      })
  }
}

///|
fn SemanticIndex::enrich_checked_pattern(
  self : SemanticIndex,
  pattern : @checked.CheckedPattern,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  self.collect_checked_pattern_types(pattern)
  match pattern {
    Binding(symbol~, name~, type_~, ..) => {
      self.enrich_binding(
        ValueBinding(symbol),
        "\{name} : \{display.type_text(type_)}",
        Some(type_),
      )
      if !self.annotated_values.contains(symbol) {
        let span = self.definition_span(Value(symbol), pattern.loc())
        self.add_type_inlay_hint(span, display, type_)
      }
    }
    Variant(symbol~, arguments~, loc~, ..) => {
      self.add_reference(
        Variant(symbol),
        self.definition_span(Variant(symbol), loc),
        self.definition_detail(Variant(symbol)),
      )
      for argument in arguments {
        self.enrich_checked_pattern(argument, display)
      }
    }
    Struct(symbol~, type_binders~, fields~, loc~, ..) => {
      self.add_reference(
        Type(symbol),
        self.definition_span(Type(symbol), loc),
        Some(type_reference_detail(Constructor(symbol), display)),
      )
      for binder in type_binders {
        if binder.type_parameter is Some(parameter) {
          self.enrich_binding(
            TypeParameterBinding(parameter.id),
            type_parameter_detail(parameter, display),
            None,
          )
        }
      }
      for field in fields {
        self.add_reference(Field(field.symbol), field.loc, Some(field.name))
        self.enrich_checked_pattern(field.pattern, display)
      }
    }
    Wildcard(_) | Literal(_) => ()
  }
}

///|
fn SemanticIndex::collect_checked_expr_types(
  self : SemanticIndex,
  expr : @checked.CheckedExpr,
) -> Unit {
  match expr {
    Literal(type_~, ..)
    | CompilerIntrinsic(type_~, ..)
    | ExternBinding(type_~, ..)
    | Block(type_~, ..)
    | If(type_~, ..)
    | Match(type_~, ..)
    | Call(type_~, ..) => self.collect_checked_type(type_)
    Field(field~, type_~, ..) => {
      if self.registry.field_metadata(field) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
      self.collect_checked_type(type_)
    }
    Value(symbol~, type_~, ..) => {
      self.add_top_level_reference(TopLevelValue(symbol))
      self.collect_checked_type(type_)
    }
    FunctionLiteral(parameters~, return_type~, type_~, ..) => {
      for parameter in parameters {
        self.collect_checked_type(parameter.type_)
      }
      self.collect_checked_type(return_type)
      self.collect_checked_type(type_)
    }
    GenericApplication(arguments~, type_~, ..) => {
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
    }
    OperationCall(operation~, generic_witnesses~, effect~, type_~, ..) => {
      if self.registry.operation_metadata(operation) is Some(metadata) {
        self.add_top_level_reference(TopLevelEffect(metadata.owner))
      }
      for witness in generic_witnesses {
        self.collect_checked_generic_argument(witness)
      }
      self.collect_checked_effect(effect)
      self.collect_checked_type(type_)
    }
    Handler(handlers~, final_branch~, type_~, ..) => {
      for handler in handlers {
        self.collect_checked_effect(handler.handled_effect)
        for arm in handler.operations {
          if self.registry.operation_metadata(arm.operation) is Some(metadata) {
            self.add_top_level_reference(TopLevelEffect(metadata.owner))
          }
          for payload_type in arm.payload_types {
            self.collect_checked_type(payload_type)
          }
          self.collect_checked_type(arm.resume_type)
        }
      }
      self.collect_checked_type(final_branch.binder_type)
      self.collect_checked_type(type_)
    }
    StructLiteral(symbol~, generic_arguments~, type_witnesses~, type_~, ..) => {
      self.add_top_level_reference(TopLevelType(symbol))
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      for witness in type_witnesses {
        self.collect_checked_type(witness.type_)
      }
      self.collect_checked_type(type_)
    }
    Variant(symbol~, generic_arguments~, type_~, ..) => {
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
    }
  }
}

///|
fn SemanticIndex::collect_checked_pattern_types(
  self : SemanticIndex,
  pattern : @checked.CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(type_~, ..) | Binding(type_~, ..) | Literal(type_~, ..) =>
      self.collect_checked_type(type_)
    Variant(symbol~, generic_arguments~, type_~, ..) => {
      if self.registry.variant_metadata(symbol) is Some(metadata) {
        self.add_top_level_reference(TopLevelType(metadata.owner))
      }
      for argument in generic_arguments {
        self.collect_checked_generic_argument(argument)
      }
      self.collect_checked_type(type_)
    }
    Struct(symbol~, type_~, ..) => {
      self.add_top_level_reference(TopLevelType(symbol))
      self.collect_checked_type(type_)
    }
  }
}

///|
fn SemanticIndex::collect_checked_type(
  self : SemanticIndex,
  type_ : @types.Type,
) -> Unit {
  match type_ {
    Constructor(symbol) => {
      self.use_import_symbol(TypeSymbol(symbol))
      self.add_top_level_reference(TopLevelType(symbol))
    }
    Error | Primitive(_) => ()
    Apply(callee, arguments) => {
      self.collect_checked_type(callee)
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    TypeLambda(_, body) | Forall(_, body) => self.collect_checked_type(body)
    Parameter(symbol) => self.generic_parameter_references.push(symbol)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.collect_checked_type(parameter)
      }
      self.collect_checked_type(result)
      self.collect_checked_effect(effect)
    }
  }
}

///|
fn SemanticIndex::collect_checked_effect(
  self : SemanticIndex,
  effect : @types.Effect,
) -> Unit {
  match effect {
    Empty | Io => ()
    Singleton(symbol, arguments) => {
      self.use_import_symbol(EffectSymbol(symbol))
      self.add_top_level_reference(TopLevelEffect(symbol))
      for argument in arguments {
        self.collect_checked_generic_argument(argument)
      }
    }
    Parameter(symbol) => self.generic_parameter_references.push(symbol)
    Union(effects) =>
      for effect in effects {
        self.collect_checked_effect(effect)
      }
  }
}

///|
fn SemanticIndex::collect_checked_generic_argument(
  self : SemanticIndex,
  argument : @types.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.collect_checked_type(type_)
    EffectArgument(effect) => self.collect_checked_effect(effect)
  }
}

///|
fn GenericParameterKind::text(self : GenericParameterKind) -> String {
  match self {
    GenericTypeParameter => "type parameter"
    GenericEffectParameter => "effect parameter"
  }
}

///|
fn TopLevelDeclarationKind::text(self : TopLevelDeclarationKind) -> String {
  match self {
    ValueDeclaration => "value"
    FunctionDeclaration => "function"
    StructDeclaration => "struct"
    EnumDeclaration => "enum"
    ExternalTypeDeclaration => "external type"
    EffectDeclaration => "effect"
    TypeAliasDeclaration => "type alias"
    EffectAliasDeclaration => "effect alias"
  }
}
