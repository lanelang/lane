///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticFact,
  type CompilerDiagnosticLabel,
  type CompilerDiagnosticSeverity,
  type CompilerDiagnosticSuggestion,
  compiler_diagnostic,
  compiler_local_span,
  compiler_primary_labels,
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompilerDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompilerDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
  facts? : Array[CompilerDiagnosticFact] = [],
  suggestions? : Array[CompilerDiagnosticSuggestion] = [],
) -> CompilerDiagnostic {
  compiler_diagnostic(
    message,
    span~,
    severity~,
    code~,
    labels~,
    notes~,
    helps~,
    facts~,
    suggestions~,
  )
}

///|
fn primary_label(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompilerDiagnosticLabel] {
  compiler_primary_labels(span, message)
}

///|
fn checked_unused_local_value_binding_diagnostics(
  source : @checked.CheckedSourceFile,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  source
  .value_use_analysis()
  .unused_binders()
  .filter(fn(binder) { !binder.name.has_prefix("_") })
  .map(fn(binder) { unused_local_value_binding_diagnostic(binder, source_text) })
}

///|
fn unused_local_value_binding_diagnostic(
  binder : @checked.CheckedValueUseBinder,
  source_text : String,
) -> CompilerDiagnostic {
  let binder_loc = name_span(source_text, binder.name, binder.loc)
  diagnostic(
    "unused local value binding",
    span=Some(binder_loc),
    severity=Warning,
    code=Some("W2001"),
    labels=[
      {
        span: compiler_local_span(binder_loc),
        message: "`\{binder.name}` is never used",
        style: Primary,
      },
    ],
    notes=[],
    helps=["prefix the name with `_` if this is intentional"],
  )
}

///|
fn unused_private_top_level_declaration_diagnostics(
  source : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  source
  .top_level_use_analysis(checked)
  .unused_private_declarations()
  .map(fn(declaration) {
    unused_private_top_level_declaration_diagnostic(declaration, source_text)
  })
}

///|
fn unused_private_top_level_declaration_diagnostic(
  declaration : TopLevelUseDeclaration,
  source_text : String,
) -> CompilerDiagnostic {
  let declaration_loc = name_span(
    source_text,
    declaration.name,
    declaration.loc,
  )
  let kind = declaration.kind.text()
  diagnostic(
    "unused private top-level declaration",
    span=Some(declaration_loc),
    severity=Warning,
    code=Some("W2002"),
    labels=[
      {
        span: compiler_local_span(declaration_loc),
        message: "private \{kind} `\{declaration.name}` is never used",
        style: Primary,
      },
    ],
    notes=[],
    helps=[
      "remove it, make it public if it is part of the module API, or prefix the name with `_` if this is intentional",
    ],
  )
}

///|
fn unused_generic_parameter_diagnostics(
  source : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  source
  .generic_parameter_use_analysis(checked)
  .unused_binders()
  .map(fn(binder) { unused_generic_parameter_diagnostic(binder, source_text) })
}

///|
fn unused_generic_parameter_diagnostic(
  binder : GenericParameterUseBinder,
  source_text : String,
) -> CompilerDiagnostic {
  let binder_loc = name_span(source_text, binder.name, binder.loc)
  let kind = binder.kind.text()
  diagnostic(
    "unused \{kind}",
    span=Some(binder_loc),
    severity=Warning,
    code=Some("W2003"),
    labels=[
      {
        span: compiler_local_span(binder_loc),
        message: "`\{binder.name}` is never used",
        style: Primary,
      },
    ],
    notes=[],
    helps=["prefix the name with `_` if this is intentional"],
  )
}

///|
fn unused_import_exposure_diagnostics(
  source : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
) -> Array[CompilerDiagnostic] {
  source.unused_import_exposures(checked).map(unused_import_exposure_diagnostic)
}

///|
fn unused_import_exposure_diagnostic(
  exposure : @resolve.ResolvedImportExposure,
) -> CompilerDiagnostic {
  let (message, label) = match exposure.kind {
    QualifiedModuleBinding =>
      (
        "unused import",
        "imported module `\{exposure.module_path_text}` is never used",
      )
    OpenBinding =>
      (
        "unused open import",
        "open import `\{exposure.module_path_text}.*` contributes no used names",
      )
    SelectiveBinding(name~) =>
      (
        "unused import item",
        "imported item `\{name}` from `\{exposure.module_path_text}` is never used",
      )
    ImportedModuleBinding =>
      (
        "unused import",
        "imported module `\{exposure.module_path_text}` is never used",
      )
  }
  diagnostic(
    message,
    span=Some(exposure.loc),
    severity=Warning,
    code=Some("W2004"),
    labels=[
      {
        span: compiler_local_span(exposure.loc),
        message: label,
        style: Primary,
      },
    ],
    notes=[],
    helps=["remove the import or use a name provided by it"],
  )
}

///|
fn compile_report(
  title : String,
  span : @basic.SourceSpan?,
  code~ : String,
  label~ : String,
  note~ : String,
  help~ : String,
) -> CompilerDiagnostic {
  diagnostic(
    title,
    span~,
    severity=Error,
    code=Some(code),
    labels=primary_label(span, label),
    notes=[note],
    helps=[help],
  )
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompilerDiagnostic] {
  let diagnostics = []
  for error in result.lexical_errors {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors {
    diagnostics.push(parse_diagnostic(error))
  }
  diagnostics
}

///|
fn resolve_diagnostic(
  diagnostic_ : @resolve.ResolveDiagnostic,
  _display : @typecheck.TypeDisplayContext,
) -> CompilerDiagnostic {
  ignore(_display)
  diagnostic_.to_compiler_diagnostic(DiagnosticContext())
}

///|
fn typecheck_diagnostic(
  diagnostic_ : @typecheck.TypeCheckDiagnostic,
  display : @typecheck.TypeDisplayContext,
) -> CompilerDiagnostic {
  diagnostic_.with_display(display).to_compiler_diagnostic(DiagnosticContext())
}

///|
fn lex_diagnostic(error : @lexer.LexError) -> CompilerDiagnostic {
  let span = Some(error.span)
  diagnostic(
    lex_error_title(error.error),
    span~,
    severity=Error,
    code=Some(lex_error_code(error.error)),
    labels=[
      {
        span: compiler_local_span(error.span),
        message: lex_error_label(error.error),
        style: Primary,
      },
    ],
    notes=lex_error_notes(error.error),
    helps=lex_error_helps(error.error),
  )
}

///|
fn lex_error_code(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "E1000"
    UnterminatedString => "E1002"
    InvalidStringEscape(_) => "E1003"
    InvalidHexEscape(_) => "E1004"
    NonAsciiStringCharacter => "E1005"
  }
}

///|
fn lex_error_title(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "illegal character in source"
    UnterminatedString => "unterminated string literal"
    InvalidStringEscape(_) => "invalid string escape"
    InvalidHexEscape(_) => "invalid hexadecimal escape"
    NonAsciiStringCharacter => "non-ASCII character in string literal"
  }
}

///|
fn lex_error_label(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(value) => "`\{value}` is not valid Lane syntax"
    UnterminatedString => "this string literal is never closed"
    InvalidStringEscape(value) =>
      "`\{value}` is not a supported escape sequence"
    InvalidHexEscape(value) => "`\{value}` is not a valid hexadecimal escape"
    NonAsciiStringCharacter =>
      "Lane string literals currently accept ASCII characters only"
  }
}

///|
fn lex_error_notes(error : @lexer.LexicalError) -> Array[String] {
  match error {
    NonAsciiStringCharacter =>
      [
        "the lexer rejects non-ASCII bytes inside string literals in the current language version",
      ]
    _ => []
  }
}

///|
fn lex_error_helps(error : @lexer.LexicalError) -> Array[String] {
  match error {
    IllegalCharacter(_) =>
      ["remove this character or replace it with a valid Lane token"]
    UnterminatedString => ["add a closing `\"` before the end of the line"]
    InvalidStringEscape(_) =>
      ["use a supported escape such as `\\n`, `\\t`, `\\\"`, or `\\\\`"]
    InvalidHexEscape(_) =>
      ["write hexadecimal escapes with exactly two hexadecimal digits"]
    NonAsciiStringCharacter =>
      ["replace the character with ASCII text or an explicit supported escape"]
  }
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompilerDiagnostic {
  error.to_compiler_diagnostic(DiagnosticContext())
}
