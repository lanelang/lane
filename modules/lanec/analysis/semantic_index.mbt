///|
priv enum SemanticBindingIdentity {
  ValueBinding(@symbol.ValueSymbolId)
  TypeBinding(@symbol.TypeSymbolId)
  EffectBinding(@symbol.EffectSymbolId)
  TypeParameterBinding(@symbol.TypeParameterId)
  AliasBinding(@symbol.TypeAliasSymbolId)
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
}

///|
priv struct SemanticBindingFact {
  identity : SemanticBindingIdentity
  name : String
  kind : SemanticBindingKind
  is_offered : Bool
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
  mut navigation_detail : String
  mut completion_detail : String
  payload_count : Int?
}

///|
priv struct ParameterHintParameter {
  name : String
  is_auto : Bool
}

///|
priv struct SemanticModuleBindingFact {
  symbol : AnalysisSymbol
  name : String
  module_path : String
  name_loc : @basic.SourceSpan
  detail : String
}

///|
priv struct SemanticIndex {
  registry : @symbol.SymbolRegistry
  source_id : String
  has_checked_source : Bool
  bindings : Array[SemanticBindingFact]
  members : Array[SemanticMemberFact]
  annotated_values : Array[@symbol.ValueSymbolId]
  module_bindings : Map[Int, SemanticModuleBindingFact]
  definitions : Array[DefinitionEntry]
  references : Array[ReferenceEntry]
  hovers : Array[HoverEntry]
  inlay_hints : Array[InlayHintFact]
  parameter_signatures : Map[Int, Array[ParameterHintParameter]]
}

///|
fn SemanticIndex::from_sources(
  resolved : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile?,
  direct_imports : @module_interface.ImportedEnvironment,
  display : @typecheck.TypeDisplayContext,
  source_id : String,
  _source_text : String,
) -> SemanticIndex {
  let module_bindings = semantic_module_binding_facts(
    source_id,
    resolved.import_exposures,
  )
  let index = SemanticIndex::{
    registry: resolved.symbols,
    source_id,
    has_checked_source: checked is Some(_),
    bindings: [],
    members: [],
    annotated_values: [],
    module_bindings,
    definitions: [],
    references: [],
    hovers: [],
    inlay_hints: [],
    parameter_signatures: Map([]),
  }
  index.add_module_bindings(resolved.module_binding_references)
  for interface in direct_imports.modules {
    for value in interface.values {
      if value.parameters is Some(parameters) {
        index.add_parameter_signature(
          value.symbol,
          parameters.map(parameter => {
            name: parameter.name,
            is_auto: parameter.is_auto,
          }),
        )
      }
    }
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
fn SemanticIndex::add_module_bindings(
  self : SemanticIndex,
  references : Array[@resolve.ResolvedModuleBindingReference],
) -> Unit {
  for _, binding in self.module_bindings {
    self.add_definition(
      binding.symbol,
      binding.name_loc,
      binding.name,
      binding.detail,
    )
  }
  for reference in references {
    guard self.module_bindings.get(reference.exposure_id) is Some(binding) else {
      abort("resolved module binding reference must target a module binding")
    }
    self.add_reference(binding.symbol, reference.loc, Some(binding.detail))
  }
}

///|
fn semantic_module_binding_facts(
  source_id : String,
  exposures : Array[@resolve.ResolvedImportExposure],
) -> Map[Int, SemanticModuleBindingFact] {
  let bindings : Map[Int, SemanticModuleBindingFact] = Map([])
  for exposure in exposures {
    match exposure.kind {
      QualifiedModuleBinding(name~, name_loc~) => {
        let detail = if name == exposure.module_path_text {
          "module \{name}"
        } else {
          "module \{name} = \{exposure.module_path_text}"
        }
        bindings[exposure.id] = {
          symbol: ModuleBinding(source_id~, exposure_id=exposure.id),
          name,
          module_path: exposure.module_path_text,
          name_loc,
          detail,
        }
      }
      OpenBinding | SelectiveBinding(_) => ()
    }
  }
  bindings
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
