///|
fn SemanticIndex::enrich_member(
  self : SemanticIndex,
  identity : SemanticMemberIdentity,
  navigation_detail : String,
  completion_detail? : String,
) -> Unit {
  for fact in self.members {
    if fact.identity == identity {
      fact.navigation_detail = navigation_detail
      fact.completion_detail = completion_detail.unwrap_or(navigation_detail)
    }
  }
  let symbol = match identity {
    FieldMember(symbol) => AnalysisSymbol::Field(symbol)
    TypeMember(symbol) => TypeMember(symbol)
    VariantMember(symbol) => Variant(symbol)
    OperationMember(symbol) => Operation(symbol)
  }
  self.enrich_definition(symbol, navigation_detail)
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
        self.enrich_member(
          OperationMember(operation.symbol),
          checked_operation_detail(declaration.name, operation, display),
          completion_detail=operation_signature_detail(
            declaration.name,
            operation.name,
            operation.type_parameters,
            operation.payload,
            operation.result,
            display,
          ),
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
      self.use_import_symbol(ValueSymbol(symbol))
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
