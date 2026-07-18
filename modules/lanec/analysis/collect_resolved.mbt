///|
fn SemanticIndex::add_member(
  self : SemanticIndex,
  identity : SemanticMemberIdentity,
  owner_name : String,
  owner_type : @symbol.TypeSymbolId?,
  name : String,
  kind : SemanticMemberKind,
  navigation_detail : String,
  payload_count : Int?,
  loc : @basic.SourceSpan,
) -> Unit {
  self.members.push({
    identity,
    owner_name,
    owner_type,
    name,
    kind,
    navigation_detail,
    completion_detail: navigation_detail,
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
    navigation_detail,
  )
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
