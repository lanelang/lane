///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() || !result.parse_errors().is_empty() {
    abort(
      "expected parse success: " + parse_error_summary(result.parse_errors()),
    )
  }
  guard result.syntax() is Some(file) else { abort("expected source file") }
  file
}

///|
fn parse_error_summary(errors : Array[@parser.ParseError]) -> String {
  if errors.is_empty() {
    return "no parse errors"
  }
  let error = errors[0]
  match error.kind {
    UnexpectedToken(actual, expected) =>
      "unexpected " +
      actual.label +
      " expected " +
      expected.map(fn(item) { item.label }).join(",")
    UnexpectedEndOfInput(expected) =>
      "unexpected eof expected " +
      expected.map(fn(item) { item.label }).join(",")
    EmptyGenericArgumentList => "empty generic argument list"
    EmptyTypeParameterList => "empty type parameter list"
    MissingTupleItem => "missing tuple item"
  }
}

///|
fn expect_declaration_typecheck_result(
  source : String,
) -> DeclarationTypeCheckResult {
  let file = expect_parse_ok(source)
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  typecheck_declarations(resolution.source).unwrap()
}

///|
fn expect_typecheck_result(source : String) -> TypeCheckResult {
  let file = expect_parse_ok(source)
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  typecheck_source_file(resolution.source).unwrap()
}

///|
fn expect_checked_source_result(
  source : String,
) -> CheckedSourceTypeCheckResult {
  let file = expect_parse_ok(source)
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  typecheck_checked_source_file(resolution.source).unwrap()
}

///|
fn checked_function_effect(
  result : TypeCheckResult,
  name : String,
) -> @types.Effect {
  for value in result.values.values {
    if value is Function(declaration) && declaration.name == name {
      guard declaration.type_ is Function(_, _, effect) else {
        abort("expected function type")
      }
      return effect
    }
  }
  abort("expected function " + name)
}

///|
fn semantic_checker_for_test_source(source : String) -> SemanticChecker {
  let file = expect_parse_ok(source)
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  let resolved = resolution.source
  let declaration_result = typecheck_declarations(resolved).unwrap()
  let source = @desugar.desugar_source_file(resolved)
  let checker = SemanticChecker::{
    resolved_source: resolved,
    source,
    imported_environment: empty_imported_environment(),
    declarations: declaration_result.declarations,
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbi::from_identities(
      resolved.canonical_basic_abi,
      declaration_result.declarations.canonical_basic_abi_types(),
    ),
    diagnostics: declaration_result.diagnostics.copy(),
    values: [],
    value_types: [],
    ordered_value_types: [],
    offers: ContextualOfferScope(),
    ordered_offers: ContextualOfferScope(),
  }
  checker.collect_top_level_value_types()
  checker
}

///|
fn expect_checked_let_initializer(
  source : String,
  name : String,
  expected : @types.Type,
) -> @checked.CheckedExpr {
  let checker = semantic_checker_for_test_source(source)
  for declaration in checker.source.declarations {
    match declaration {
      Let(declaration) =>
        if declaration.name == name {
          let checked = checker.check_checked_expr(
            checker.root_scope(),
            declaration.initializer,
            expected,
          )
          guard checked.expression is Some(expression) else {
            abort(@prettyprinter.render(checker.diagnostics, width=100))
          }
          return expression
        } else {
          checker.check_top_level_let(declaration)
        }
      _ => ()
    }
  }
  abort("expected named let")
}

///|
fn expect_first_checked_match_pattern(
  source : String,
  name : String,
) -> @checked.CheckedPattern {
  let checker = semantic_checker_for_test_source(source)
  for declaration in checker.source.declarations {
    if declaration is Function(declaration) && declaration.name == name {
      let scope = checker.root_scope()
      for parameter in declaration.parameters {
        scope.bind(
          parameter.symbol,
          parameter.name,
          checker.check_type(parameter.type_),
        )
      }
      let body = match declaration.body {
        Block(items=[], result~, ..) => result
        _ => declaration.body
      }
      guard body is Match(scrutinee~, arms~, ..) else {
        abort("expected match body")
      }
      guard !arms.is_empty() else { abort("expected match arm") }
      let scrutinee_type = checker.synthesize_expr(scope, scrutinee)
      let arm_scope = scope.copy()
      return checker.check_match_pattern(
        arm_scope,
        arms[0].pattern,
        scrutinee_type,
      )
    }
  }
  abort("expected function")
}
