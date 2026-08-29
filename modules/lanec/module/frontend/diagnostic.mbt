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
pub(all) enum ModuleDependencyFailureKind {
  DuplicateModuleInput(String)
  MissingImportWithCandidates(
    module_~ : String,
    source_modules~ : Array[String],
    interface_modules~ : Array[String]
  )
  ImportCycle(String)
} derive(Debug, Eq)

///|
pub(all) enum ModuleDependencyProvenance {
  SourceInput(source_id~ : String, span~ : @basic.SourceSpan?)
  InterfaceArtifact(
    source_id~ : String,
    importer_module_path_text~ : String,
    span~ : @basic.SourceSpan?
  )
} derive(Debug, Eq)

///|
pub(all) struct ModuleDependencyFailure {
  kind : ModuleDependencyFailureKind
  provenance : ModuleDependencyProvenance
} derive(Debug, Eq)

///|
priv enum ModuleFrontendDiagnosticKind {
  ParserProducedNoSourceFile
}

///|
priv struct ModuleFrontendDiagnostic {
  kind : ModuleFrontendDiagnosticKind
  span : @basic.SourceSpan?
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
fn module_frontend_diagnostic(
  kind : ModuleFrontendDiagnosticKind,
  span : @basic.SourceSpan?,
) -> CompilerDiagnostic {
  let diagnostic : ModuleFrontendDiagnostic = { kind, span, }
  @compiler_diag.ToCompilerDiagnostic::to_compiler_diagnostic(
    diagnostic,
    DiagnosticContext(),
  )
}

///|
pub fn ModuleDependencyFailure::duplicate_module(
  module_path_text : String,
  provenance : ModuleDependencyProvenance,
) -> ModuleDependencyFailure {
  { kind: DuplicateModuleInput(module_path_text), provenance, }
}

///|
pub fn ModuleDependencyFailure::missing_import(
  module_path_text : String,
  source_modules~ : Array[String],
  interface_modules~ : Array[String],
  provenance~ : ModuleDependencyProvenance,
) -> ModuleDependencyFailure {
  {
    kind: MissingImportWithCandidates(
      module_=module_path_text,
      source_modules~,
      interface_modules~,
    ),
    provenance,
  }
}

///|
pub fn ModuleDependencyFailure::import_cycle(
  module_path_text : String,
  provenance : ModuleDependencyProvenance,
) -> ModuleDependencyFailure {
  { kind: ImportCycle(module_path_text), provenance, }
}

///|
pub fn ModuleDependencyFailure::diagnostic(
  self : ModuleDependencyFailure,
) -> CompilerDiagnostic {
  let (source_id, span) = match self.provenance {
    SourceInput(source_id~, span~) => (Some(source_id), span)
    InterfaceArtifact(source_id~, span~, ..) => (Some(source_id), span)
  }
  let diagnostic = match self.kind {
    DuplicateModuleInput(module_) =>
      module_frontend_report(
        "duplicate module input `\{module_}`",
        span,
        code="E4001",
        label="this module was supplied more than once",
        note="a module input set cannot contain two sources with the same module name",
        help="remove one source file or rename one of the modules",
      )
    MissingImportWithCandidates(module_~, source_modules~, interface_modules~) =>
      missing_import_diagnostic(
        module_, span, source_modules, interface_modules,
      )
    ImportCycle(module_) =>
      module_frontend_report(
        "import cycle involving `\{module_}`",
        span,
        code="E4003",
        label="module imports must form an acyclic graph",
        note="cyclic module dependencies cannot be typechecked in a stable order",
        help="move shared declarations into a separate module imported by both sides",
      )
  }
  match source_id {
    Some(source_id) => diagnostic.with_source_id(source_id)
    None => diagnostic
  }
}

///|
fn parser_produced_no_source_file_diagnostic() -> CompilerDiagnostic {
  module_frontend_diagnostic(ParserProducedNoSourceFile, None)
}

///|
impl @compiler_diag.ToCompilerDiagnostic for ModuleFrontendDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : ModuleFrontendDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    ParserProducedNoSourceFile =>
      module_frontend_report(
        "parser produced no source file",
        diagnostic_.span,
        code="E1102",
        label="parser produced no source file",
        note="the parser returned neither a source tree nor a concrete parse error",
        help="report this as a compiler bug with the input that triggered it",
      )
  }
}

///|
fn missing_import_diagnostic(
  module_ : String,
  span : @basic.SourceSpan?,
  source_modules : Array[String],
  interface_modules : Array[String],
) -> CompilerDiagnostic {
  let facts : Array[CompilerDiagnosticFact] = []
  for source_module in source_modules {
    facts.push({
      name: "considered source module",
      value: "`\{source_module}`",
      span: None,
    })
  }
  for interface_module in interface_modules {
    facts.push({
      name: "considered interface artifact",
      value: "declares module `\{interface_module}`",
      span: None,
    })
  }
  if source_modules.is_empty() && interface_modules.is_empty() {
    facts.push({
      name: "considered inputs",
      value: "no library source or interface artifact was available",
      span: None,
    })
  }
  diagnostic(
    "missing imported module `\{module_}`",
    span~,
    severity=Error,
    code=Some("E4002"),
    labels=primary_label(span, "no explicit input provides this module"),
    notes=[
      "Lane only compiles explicitly provided source files and interface artifacts",
    ],
    helps=[
      "pass an input whose declared module is `\{module_}`, or change the import to one of the listed modules",
    ],
    facts~,
    suggestions=[
      {
        message: "check the imported module name against the listed explicit inputs",
        edits: [],
        applicability: MaybeIncorrect,
      },
    ],
  )
}

///|
fn module_frontend_report(
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
  for error in result.lexical_errors() {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors() {
    diagnostics.push(parse_diagnostic(error))
  }
  diagnostics
}

///|
fn lex_diagnostic(error : @lexer.LexError) -> CompilerDiagnostic {
  let span = Some(error.span)
  let presentation = error.error.presentation()
  diagnostic(
    presentation.title,
    span~,
    severity=Error,
    code=Some(presentation.code),
    labels=[
      {
        span: compiler_local_span(error.span),
        message: presentation.label,
        style: Primary,
      },
    ],
    notes=presentation.notes,
    helps=presentation.helps,
  )
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompilerDiagnostic {
  error.to_compiler_diagnostic(DiagnosticContext())
}
