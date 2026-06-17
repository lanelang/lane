///|
priv struct SemanticChecker {
  source : @desugar.DesugaredSourceFile
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
  let source = @desugar.desugar_source_file(source)
  let checker = SemanticChecker::{
    source,
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
fn SemanticChecker::collect_top_level_function_type(
  self : SemanticChecker,
  declaration : @desugar.DesugaredFunctionDeclaration,
) -> Unit {
  let type_ = self.function_type(
    declaration.type_parameters,
    declaration.parameters,
    declaration.return_type,
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
  self.check_expr(
    scope,
    declaration.body,
    self.check_type(declaration.return_type),
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
    self.check_expr(self.ordered_root_scope(), declaration.initializer, type_)
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
  self.check_expr(self.ordered_root_scope(), declaration.initializer, type_)
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
) -> @types.Type {
  let parameters = parameters.map(fn(parameter) {
    self.check_type(parameter.type_)
  })
  let result = self.check_type(return_type)
  let type_ = @types.Type::Function(parameters, result)
  if type_parameters.is_empty() {
    type_
  } else {
    Forall(type_parameters.map(checked_type_parameter), type_)
  }
}

///|
fn SemanticChecker::check_type(
  self : SemanticChecker,
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  check_resolved_type(self.source.symbols, self.diagnostics, type_)
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
