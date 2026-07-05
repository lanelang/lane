///|
priv struct SemanticChecker {
  resolved_source : @resolve.ResolvedSourceFile
  source : @desugar.DesugaredSourceFile
  imported_environment : @module_interface.ImportedEnvironment
  declarations : CheckedDeclarationEnvironment
  diagnostics : Array[TypeCheckDiagnostic]
  values : Array[CheckedValueDeclaration]
  value_types : Array[ValueTypeBinding]
  ordered_value_types : Array[ValueTypeBinding]
  offers : Array[ContextualOffer]
  ordered_offers : Array[ContextualOffer]
}

///|
/// Checks a resolved source file and returns checked declarations, values, and diagnostics.
pub fn typecheck_source_file(
  source : @resolve.ResolvedSourceFile,
) -> TypeCheckResult {
  let declaration_result = typecheck_declarations(source)
  let resolved_source = source
  let source = @desugar.desugar_source_file(resolved_source)
  let checker = SemanticChecker::{
    resolved_source,
    source,
    imported_environment: empty_imported_environment(),
    declarations: declaration_result.declarations,
    diagnostics: declaration_result.diagnostics.copy(),
    values: [],
    value_types: [],
    ordered_value_types: [],
    offers: [],
    ordered_offers: [],
  }
  checker.collect_top_level_value_types()
  for declaration in source.declarations {
    match declaration {
      Function(declaration) => checker.check_top_level_function(declaration)
      Let(declaration) => checker.check_top_level_let(declaration)
      Offer(declaration) => checker.check_top_level_offer(declaration)
      _ => ()
    }
  }
  {
    declarations: checker.declarations,
    values: { values: checker.values },
    diagnostics: checker.diagnostics,
  }
}

///|
fn SemanticChecker::collect_top_level_value_types(
  self : SemanticChecker,
) -> Unit {
  for declaration in self.source.declarations {
    match declaration {
      Function(declaration) => self.collect_top_level_function_type(declaration)
      Let(declaration) => self.collect_top_level_let_type(declaration)
      Offer(declaration) => self.collect_top_level_offer_type(declaration)
      _ => ()
    }
  }
}

///|
fn SemanticChecker::seed_imported_top_level_value_types(
  self : SemanticChecker,
  imported_environment : @module_interface.ImportedEnvironment,
) -> Unit {
  for module_ in imported_environment.modules {
    for value in module_.values {
      self.seed_imported_top_level_value_type(value)
    }
  }
}

///|
fn SemanticChecker::seed_imported_top_level_value_type(
  self : SemanticChecker,
  value : @module_interface.ModuleInterfaceValue,
) -> Unit {
  let parameters = value.parameters.map(fn(parameters) {
    parameters.map(checked_value_parameter_from_interface)
  })
  let binding = { symbol: value.symbol, type_: value.type_, parameters }
  self.value_types.push(binding)
  self.ordered_value_types.push(binding)
  match value.kind {
    Function =>
      self.values.push(
        Function({
          is_public: true,
          symbol: value.symbol,
          name: value.name,
          type_: value.type_,
          parameters: parameters.unwrap_or([]),
          loc: value.loc,
        }),
      )
    Let =>
      self.values.push(
        Let({
          is_public: true,
          symbol: value.symbol,
          name: Some(value.name),
          type_: value.type_,
          loc: value.loc,
        }),
      )
    Offer => {
      self.offer_symbol(self.offers, value.symbol, value.type_, value.loc)
      self.offer_symbol(
        self.ordered_offers,
        value.symbol,
        value.type_,
        value.loc,
      )
      self.values.push(
        Let({
          is_public: true,
          symbol: value.symbol,
          name: Some(value.name),
          type_: value.type_,
          loc: value.loc,
        }),
      )
    }
  }
}

///|
fn checked_value_parameter_from_interface(
  parameter : @module_interface.ModuleInterfaceValueParameter,
) -> @checked.CheckedValueParameter {
  {
    symbol: parameter.symbol,
    is_auto: parameter.is_auto,
    is_offered: parameter.is_offered,
    name: parameter.name,
    type_: parameter.type_,
    loc: parameter.loc,
  }
}

///|
fn SemanticChecker::collect_top_level_function_type(
  self : SemanticChecker,
  declaration : @desugar.DesugaredFunctionDeclaration,
) -> Unit {
  let type_ = self.function_type(
    declaration.type_parameters,
    declaration.parameters,
    declaration.return_type,
    declaration.effect,
  )
  let parameters = declaration.parameters.map(fn(parameter) {
    self.checked_value_parameter(parameter)
  })
  let binding = {
    symbol: declaration.symbol,
    type_,
    parameters: Some(parameters),
  }
  self.value_types.push(binding)
  self.ordered_value_types.push(binding)
  self.values.push(
    Function({
      is_public: declaration.is_public,
      symbol: declaration.symbol,
      name: declaration.name,
      type_,
      parameters,
      loc: declaration.loc,
    }),
  )
}

///|
fn SemanticChecker::collect_top_level_let_type(
  self : SemanticChecker,
  declaration : @desugar.DesugaredLetDeclaration,
) -> Unit {
  if declaration.type_annotation is Some(type_annotation) {
    let type_ = self.check_type(type_annotation)
    self.value_types.push({
      symbol: declaration.symbol,
      type_,
      parameters: None,
    })
  }
}

///|
fn SemanticChecker::collect_top_level_offer_type(
  self : SemanticChecker,
  declaration : @desugar.DesugaredOfferDeclaration,
) -> Unit {
  let type_ = self.check_type(declaration.type_annotation)
  self.value_types.push({ symbol: declaration.symbol, type_, parameters: None })
  self.offer_symbol(self.offers, declaration.symbol, type_, declaration.loc)
}

///|
fn SemanticChecker::check_top_level_function(
  self : SemanticChecker,
  declaration : @desugar.DesugaredFunctionDeclaration,
) -> Unit {
  let scope = self.root_scope()
  for parameter in declaration.parameters {
    let type_ = self.check_type(parameter.type_)
    scope.bind(parameter.symbol, type_)
    if parameter.is_offered {
      self.offer_symbol(scope.offers, parameter.symbol, type_, parameter.loc)
    }
  }
  let body = self.check_checked_expr(
    scope,
    declaration.body,
    self.check_type(declaration.return_type),
  )
  self.expect_effect(
    self.check_effect(declaration.effect),
    body.effect,
    declaration.body.loc(),
  )
}

///|
fn SemanticChecker::check_top_level_let(
  self : SemanticChecker,
  declaration : @desugar.DesugaredLetDeclaration,
) -> Unit {
  let type_ = if declaration.type_annotation is Some(type_annotation) {
    let type_ = match self.value_type(declaration.symbol) {
      Some(type_) => type_
      None => self.check_type(type_annotation)
    }
    let scope = self.ordered_root_scope()
    let initializer = self.check_checked_expr(
      scope,
      declaration.initializer,
      type_,
    )
    self.expect_effect(Empty, initializer.effect, declaration.initializer.loc())
    type_
  } else {
    self.diagnostics.push({
      kind: MissingTopLevelLetAnnotation,
      loc: declaration.loc,
    })
    self.synthesize_expr(self.ordered_root_scope(), declaration.initializer)
  }
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
}

///|
fn SemanticChecker::check_top_level_offer(
  self : SemanticChecker,
  declaration : @desugar.DesugaredOfferDeclaration,
) -> Unit {
  let type_ = match self.value_type(declaration.symbol) {
    Some(type_) => type_
    None => self.check_type(declaration.type_annotation)
  }
  let scope = self.ordered_root_scope()
  let initializer = self.check_checked_expr(
    scope,
    declaration.initializer,
    type_,
  )
  self.expect_effect(Empty, initializer.effect, declaration.initializer.loc())
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
}

///|
fn SemanticChecker::function_type(
  self : SemanticChecker,
  type_parameters : Array[@resolve.ResolvedTypeParameter],
  parameters : Array[@resolve.ResolvedValueParameter],
  return_type : @resolve.ResolvedType,
  effect : @resolve.ResolvedEffectTerm,
) -> @types.Type {
  let parameters = parameters.map(fn(parameter) {
    self.check_type(parameter.type_)
  })
  let result = self.check_type(return_type)
  let type_ = @types.Type::Function(
    parameters,
    result,
    self.check_effect(effect),
  )
  if type_parameters.is_empty() {
    type_
  } else {
    Forall(check_type_parameters(self.diagnostics, type_parameters), type_)
  }
}

///|
fn SemanticChecker::check_type(
  self : SemanticChecker,
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  check_resolved_type_with_imported_environment(
    self.resolved_source,
    self.imported_environment,
    self.diagnostics,
    type_,
  )
}

///|
fn SemanticChecker::value_type(
  self : SemanticChecker,
  symbol : ValueSymbolId,
) -> @types.Type? {
  for index = self.value_types.length() - 1; index >= 0; index = index - 1 {
    let binding = self.value_types[index]
    if binding.symbol == symbol {
      return Some(binding.type_)
    }
  }
  None
}
