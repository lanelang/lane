///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticFact,
  type CompilerDiagnosticLabel,
  type CompilerDiagnosticSeverity,
  type CompilerDiagnosticSuggestion,
  compiler_diagnostic,
  compiler_local_span,
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
pub fn checked_unused_local_value_binding_diagnostics(
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
pub fn checked_semantic_warning_diagnostics(
  source : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  let display = @typecheck.TypeDisplayContext::from_registry(source.symbols)
  let index = SemanticIndex::from_sources(
    source,
    Some(checked),
    display,
    "<diagnostic>",
    source_text,
  )
  semantic_warning_diagnostics_from_index(index, source, source_text)
}

///|
fn semantic_warning_diagnostics_from_index(
  index : SemanticIndex,
  source : @resolve.ResolvedSourceFile,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  let diagnostics = unused_private_top_level_declaration_diagnostics_from_index(
    index, source_text,
  )
  diagnostics.append(
    unused_generic_parameter_diagnostics_from_index(index, source_text),
  )
  diagnostics.append(
    unused_import_exposure_diagnostics_from_index(index, source),
  )
  diagnostics
}

///|
fn unused_private_top_level_declaration_diagnostics_from_index(
  index : SemanticIndex,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  index
  .unused_private_top_level_declarations()
  .map(fn(declaration) {
    unused_private_top_level_declaration_diagnostic(declaration, source_text)
  })
}

///|
fn unused_private_top_level_declaration_diagnostic(
  declaration : TopLevelDeclarationFact,
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
fn unused_generic_parameter_diagnostics_from_index(
  index : SemanticIndex,
  source_text : String,
) -> Array[CompilerDiagnostic] {
  index
  .unused_generic_parameters()
  .map(fn(binder) { unused_generic_parameter_diagnostic(binder, source_text) })
}

///|
fn unused_generic_parameter_diagnostic(
  binder : GenericParameterFact,
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
fn unused_import_exposure_diagnostics_from_index(
  index : SemanticIndex,
  source : @resolve.ResolvedSourceFile,
) -> Array[CompilerDiagnostic] {
  index.unused_import_exposures(source).map(unused_import_exposure_diagnostic)
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
