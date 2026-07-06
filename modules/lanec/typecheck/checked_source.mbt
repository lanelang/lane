///|
/// Checks a resolved source file and returns a complete Checked Source AST when
/// every top-level body can currently be represented in `lanec/checked`.
pub fn typecheck_checked_source_file(
  source : @resolve.ResolvedSourceFile,
) -> CheckedSourceTypeCheckResult {
  typecheck_checked_source_file_with_imported_environment(
    source,
    empty_imported_environment(),
  )
}

///|
/// Checks one resolved module against already checked imported module interfaces.
pub fn typecheck_checked_source_file_with_imported_environment(
  source : @resolve.ResolvedSourceFile,
  imported_environment : @module_interface.ImportedEnvironment,
) -> CheckedSourceTypeCheckResult {
  let declaration_result = typecheck_declarations_with_imported_environment(
    source, imported_environment,
  )
  let resolved_source = source
  let current_source = @desugar.desugar_source_file(source)
  let checker = SemanticChecker::{
    resolved_source,
    source: current_source,
    imported_environment,
    declarations: declaration_result.declarations,
    diagnostics: declaration_result.diagnostics.copy(),
    values: [],
    value_types: [],
    ordered_value_types: [],
    offers: [],
    ordered_offers: [],
  }
  checker.seed_imported_top_level_value_types(imported_environment)
  checker.collect_top_level_value_types()
  let checked_declarations : Array[@checked.CheckedTopLevelDeclaration] = []
  let mut complete = true
  for declaration in current_source.declarations {
    match checker.check_checked_top_level_declaration(declaration) {
      Some(declaration) => checked_declarations.push(declaration)
      None => complete = false
    }
  }
  let checked_source = if complete && checker.diagnostics.is_empty() {
    Some(@checked.CheckedSourceFile::{
      module_path: resolved_source.module_path,
      declarations: checked_declarations,
      loc: resolved_source.loc,
    })
  } else {
    None
  }
  let module_interface = match checked_source {
    Some(checked_source) if checker.diagnostics.is_empty() =>
      Some(checker.module_interface(checked_source))
    _ => None
  }
  {
    source: checked_source,
    module_interface,
    diagnostics: deduplicate_typecheck_diagnostics(checker.diagnostics),
  }
}

///|
fn SemanticChecker::check_checked_top_level_declaration(
  self : SemanticChecker,
  declaration : @desugar.DesugaredTopLevelDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  match declaration {
    Struct(declaration) => self.checked_top_level_struct(declaration)
    Enum(declaration) => self.checked_top_level_enum(declaration)
    Effect(declaration) => self.checked_top_level_effect(declaration)
    Function(declaration) => self.checked_top_level_function(declaration)
    Let(declaration) => self.checked_top_level_let(declaration)
    Offer(declaration) => self.checked_top_level_offer(declaration)
  }
}

///|
fn SemanticChecker::checked_top_level_struct(
  self : SemanticChecker,
  declaration : @resolve.ResolvedStructDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  guard self.declarations.checked_struct(declaration.symbol) is Some(checked) else {
    self.diagnostics.push({
      kind: InternalTypecheckFailure(label="checked struct " + declaration.name),
      loc: declaration.loc,
    })
    return None
  }
  Some(Struct(checked.to_checked_struct_declaration()))
}

///|
fn SemanticChecker::checked_top_level_enum(
  self : SemanticChecker,
  declaration : @resolve.ResolvedEnumDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  guard self.declarations.checked_enum(declaration.symbol) is Some(checked) else {
    self.diagnostics.push({
      kind: InternalTypecheckFailure(label="checked enum " + declaration.name),
      loc: declaration.loc,
    })
    return None
  }
  Some(Enum(checked.to_checked_enum_declaration()))
}

///|
fn SemanticChecker::checked_top_level_effect(
  self : SemanticChecker,
  declaration : @resolve.ResolvedEffectDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  guard self.declarations.checked_effect(declaration.symbol) is Some(checked) else {
    self.diagnostics.push({
      kind: InternalTypecheckFailure(label="checked effect " + declaration.name),
      loc: declaration.loc,
    })
    return None
  }
  Some(Effect(checked.to_checked_effect_declaration()))
}

///|
fn SemanticChecker::checked_top_level_function(
  self : SemanticChecker,
  declaration : @desugar.DesugaredFunctionDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  let body_scope = self.root_scope()
  let parameters = declaration.parameters.map(fn(parameter) {
    self.checked_value_parameter(parameter)
  })
  for parameter in parameters {
    body_scope.bind(parameter.symbol, parameter.type_)
    if parameter.is_offered {
      self.offer_symbol(
        body_scope.offers,
        parameter.symbol,
        parameter.type_,
        parameter.loc,
      )
    }
  }
  let return_type = self.check_type(declaration.return_type)
  let checked_body = self.check_checked_expr(
    body_scope,
    declaration.body,
    return_type,
  )
  let effect = self.check_effect(declaration.effect)
  self.expect_effect(effect, checked_body.effect, declaration.body.loc())
  guard self.require_checked_expression(
      checked_body,
      declaration.body.loc(),
      "function body",
    )
    is Some(body) else {
    return None
  }
  Some(
    Function({
      is_public: declaration.is_public,
      symbol: declaration.symbol,
      name: declaration.name,
      type_parameters: declaration.type_parameters.map(checked_type_parameter),
      parameters,
      return_type,
      body,
      type_: self.function_type(
        declaration.type_parameters,
        declaration.parameters,
        declaration.return_type,
        declaration.effect,
      ),
      loc: declaration.loc,
    }),
  )
}

///|
fn SemanticChecker::checked_top_level_let(
  self : SemanticChecker,
  declaration : @desugar.DesugaredLetDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  let scope = self.ordered_root_scope()
  let (type_, checked_initializer) = match declaration.type_annotation {
    Some(type_annotation) => {
      let type_ = match self.value_type(declaration.symbol) {
        Some(type_) => type_
        None => self.check_type(type_annotation)
      }
      (type_, self.check_checked_expr(scope, declaration.initializer, type_))
    }
    None => {
      self.diagnostics.push({
        kind: MissingTopLevelLetAnnotation,
        loc: declaration.loc,
      })
      let checked_initializer = self.synthesize_checked_expr(
        scope,
        declaration.initializer,
      )
      (checked_initializer.type_, checked_initializer)
    }
  }
  self.expect_effect(
    Empty,
    checked_initializer.effect,
    declaration.initializer.loc(),
  )
  self.ordered_value_types.push({
    symbol: declaration.symbol,
    type_,
    parameters: None,
  })
  self.values.push(
    Let({
      is_public: declaration.is_public,
      symbol: declaration.symbol,
      name: declaration.name,
      type_,
      loc: declaration.loc,
    }),
  )
  guard self.require_checked_expression(
      checked_initializer,
      declaration.initializer.loc(),
      "let initializer",
    )
    is Some(initializer) else {
    return None
  }
  Some(
    Let({
      is_public: declaration.is_public,
      symbol: declaration.symbol,
      name: declaration.name,
      initializer,
      type_,
      loc: declaration.loc,
    }),
  )
}

///|
fn SemanticChecker::checked_top_level_offer(
  self : SemanticChecker,
  declaration : @desugar.DesugaredOfferDeclaration,
) -> @checked.CheckedTopLevelDeclaration? {
  let type_ = match self.value_type(declaration.symbol) {
    Some(type_) => type_
    None => self.check_type(declaration.type_annotation)
  }
  let checked_initializer = self.check_checked_expr(
    self.ordered_root_scope(),
    declaration.initializer,
    type_,
  )
  self.expect_effect(
    Empty,
    checked_initializer.effect,
    declaration.initializer.loc(),
  )
  self.ordered_value_types.push({
    symbol: declaration.symbol,
    type_,
    parameters: None,
  })
  self.offer_symbol(
    self.ordered_offers,
    declaration.symbol,
    type_,
    declaration.loc,
  )
  self.values.push(
    Let({
      is_public: declaration.is_public,
      symbol: declaration.symbol,
      name: Some(declaration.name),
      type_,
      loc: declaration.loc,
    }),
  )
  guard self.require_checked_expression(
      checked_initializer,
      declaration.initializer.loc(),
      "offer initializer",
    )
    is Some(initializer) else {
    return None
  }
  Some(
    Let({
      is_public: declaration.is_public,
      symbol: declaration.symbol,
      name: Some(declaration.name),
      initializer,
      type_,
      loc: declaration.loc,
    }),
  )
}

///|
priv struct CheckedLocalLetSynthesis {
  declaration : @checked.CheckedLetDeclaration
  effect : @types.Effect
}

///|
priv struct CheckedLocalPatternLetSynthesis {
  declaration : @checked.CheckedPatternLetDeclaration
  effect : @types.Effect
}

///|
fn SemanticChecker::check_checked_local_let(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : @desugar.DesugaredLetDeclaration,
) -> CheckedLocalLetSynthesis? {
  let (type_, checked_initializer) = if declaration.type_annotation
    is Some(type_annotation) {
    let type_ = self.check_type(type_annotation)
    (type_, self.check_checked_expr(scope, declaration.initializer, type_))
  } else {
    let checked_initializer = self.synthesize_checked_expr(
      scope,
      declaration.initializer,
    )
    (checked_initializer.type_, checked_initializer)
  }
  scope.bind(declaration.symbol, type_)
  guard self.require_checked_expression(
      checked_initializer,
      declaration.initializer.loc(),
      "local let initializer",
    )
    is Some(initializer) else {
    return None
  }
  Some({
    declaration: {
      is_public: false,
      symbol: declaration.symbol,
      name: declaration.name,
      initializer,
      type_,
      loc: declaration.loc,
    },
    effect: checked_initializer.effect,
  })
}

///|
fn SemanticChecker::check_checked_local_offer(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : @desugar.DesugaredOfferDeclaration,
) -> CheckedLocalLetSynthesis? {
  let type_ = self.check_type(declaration.type_annotation)
  let checked_initializer = self.check_checked_expr(
    scope,
    declaration.initializer,
    type_,
  )
  scope.bind(declaration.symbol, type_)
  self.offer_symbol(scope.offers, declaration.symbol, type_, declaration.loc)
  guard self.require_checked_expression(
      checked_initializer,
      declaration.initializer.loc(),
      "local offer initializer",
    )
    is Some(initializer) else {
    return None
  }
  Some({
    declaration: {
      is_public: false,
      symbol: declaration.symbol,
      name: Some(declaration.name),
      initializer,
      type_,
      loc: declaration.loc,
    },
    effect: checked_initializer.effect,
  })
}

///|
fn SemanticChecker::check_checked_local_pattern_let(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : @desugar.DesugaredPatternLetDeclaration,
) -> CheckedLocalPatternLetSynthesis? {
  let (type_, checked_initializer) = if declaration.type_annotation
    is Some(type_annotation) {
    let type_ = self.check_type(type_annotation)
    (type_, self.check_checked_expr(scope, declaration.initializer, type_))
  } else {
    let checked_initializer = self.synthesize_checked_expr(
      scope,
      declaration.initializer,
    )
    (checked_initializer.type_, checked_initializer)
  }
  let pattern = self.check_pattern(scope, declaration.pattern, type_, [])
  self.check_irrefutable_pattern_let(pattern)
  guard self.require_checked_expression(
      checked_initializer,
      declaration.initializer.loc(),
      "pattern let initializer",
    )
    is Some(initializer) else {
    return None
  }
  Some({
    declaration: { pattern, initializer, loc: declaration.loc },
    effect: checked_initializer.effect,
  })
}

///|
fn SemanticChecker::check_checked_local_function(
  self : SemanticChecker,
  scope : TypeScope,
  declaration : @desugar.DesugaredFunctionDeclaration,
) -> @checked.CheckedFunctionDeclaration? {
  let type_ = self.function_type(
    declaration.type_parameters,
    declaration.parameters,
    declaration.return_type,
    declaration.effect,
  )
  scope.bind_function(
    declaration.symbol,
    type_,
    declaration.parameters.map(fn(parameter) {
      self.checked_value_parameter(parameter)
    }),
  )
  let body_scope = scope.copy()
  let parameters = declaration.parameters.map(fn(parameter) {
    self.checked_value_parameter(parameter)
  })
  for parameter in parameters {
    body_scope.bind(parameter.symbol, parameter.type_)
    if parameter.is_offered {
      self.offer_symbol(
        body_scope.offers,
        parameter.symbol,
        parameter.type_,
        parameter.loc,
      )
    }
  }
  let return_type = self.check_type(declaration.return_type)
  let checked_body = self.check_checked_expr(
    body_scope,
    declaration.body,
    return_type,
  )
  let effect = self.check_effect(declaration.effect)
  self.expect_effect(effect, checked_body.effect, declaration.body.loc())
  guard self.require_checked_expression(
      checked_body,
      declaration.body.loc(),
      "local function body",
    )
    is Some(body) else {
    return None
  }
  Some({
    is_public: false,
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters.map(checked_type_parameter),
    parameters,
    return_type,
    body,
    type_,
    loc: declaration.loc,
  })
}

///|
fn SemanticChecker::checked_value_parameter(
  self : SemanticChecker,
  parameter : @resolve.ResolvedValueParameter,
) -> @checked.CheckedValueParameter {
  {
    symbol: parameter.symbol,
    is_auto: parameter.is_auto,
    is_offered: parameter.is_offered,
    name: parameter.name,
    type_: self.check_type(parameter.type_),
    loc: parameter.loc,
  }
}

///|
fn CheckedStructDeclaration::to_checked_struct_declaration(
  self : CheckedStructDeclaration,
) -> @checked.CheckedStructDeclaration {
  {
    symbol: self.symbol,
    is_public: self.is_public,
    name: self.name,
    type_parameters: self.type_parameters,
    type_members: self.type_members.map(
      CheckedTypeMemberDeclaration::to_checked_type_member_declaration,
    ),
    fields: self.fields.map(
      CheckedFieldDeclaration::to_checked_field_declaration,
    ),
    loc: self.loc,
  }
}

///|
fn CheckedTypeMemberDeclaration::to_checked_type_member_declaration(
  self : CheckedTypeMemberDeclaration,
) -> @checked.CheckedTypeMemberDeclaration {
  {
    symbol: self.symbol,
    type_parameter: self.type_parameter,
    name: self.name,
    kind: self.kind,
    index: self.index,
    loc: self.loc,
  }
}

///|
fn CheckedFieldDeclaration::to_checked_field_declaration(
  self : CheckedFieldDeclaration,
) -> @checked.CheckedFieldDeclaration {
  {
    symbol: self.symbol,
    is_offered: self.is_offered,
    name: self.name,
    index: self.index,
    type_: self.type_,
    loc: self.loc,
  }
}

///|
fn CheckedEnumDeclaration::to_checked_enum_declaration(
  self : CheckedEnumDeclaration,
) -> @checked.CheckedEnumDeclaration {
  {
    symbol: self.symbol,
    is_public: self.is_public,
    name: self.name,
    type_parameters: self.type_parameters,
    variants: self.variants.map(
      CheckedVariantDeclaration::to_checked_variant_declaration,
    ),
    loc: self.loc,
  }
}

///|
fn CheckedVariantDeclaration::to_checked_variant_declaration(
  self : CheckedVariantDeclaration,
) -> @checked.CheckedVariantDeclaration {
  {
    symbol: self.symbol,
    name: self.name,
    index: self.index,
    type_parameters: self.type_parameters,
    payload: self.payload,
    loc: self.loc,
  }
}

///|
fn CheckedEffectDeclaration::to_checked_effect_declaration(
  self : CheckedEffectDeclaration,
) -> @checked.CheckedEffectDeclaration {
  {
    symbol: self.symbol,
    is_public: self.is_public,
    name: self.name,
    type_parameters: self.type_parameters,
    operations: self.operations.map(
      CheckedEffectOperationDeclaration::to_checked_effect_operation_declaration,
    ),
    loc: self.loc,
  }
}

///|
fn CheckedEffectOperationDeclaration::to_checked_effect_operation_declaration(
  self : CheckedEffectOperationDeclaration,
) -> @checked.CheckedEffectOperationDeclaration {
  {
    symbol: self.symbol,
    name: self.name,
    index: self.index,
    type_parameters: self.type_parameters,
    payload: self.payload,
    result: self.result,
    loc: self.loc,
  }
}
