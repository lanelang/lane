///|
priv enum CompileBoundaryDiagnosticKind {
  NoRootSourceModule
  DuplicateModuleInput(String)
  MissingImportWithCandidates(
    module_~ : String,
    source_modules~ : Array[String],
    interface_modules~ : Array[String]
  )
  ImportCycle(String)
  CheckedSourceConstructionFailed
  ParserProducedNoSourceFile
}

///|
priv struct CompileBoundaryDiagnostic {
  kind : CompileBoundaryDiagnosticKind
  span : @basic.SourceSpan?
}

///|
fn compile_boundary_diagnostic(
  kind : CompileBoundaryDiagnosticKind,
  span : @basic.SourceSpan?,
) -> CompilerDiagnostic {
  let diagnostic : CompileBoundaryDiagnostic = { kind, span }
  diagnostic.to_compiler_diagnostic(DiagnosticContext())
}

///|
impl @compiler_diag.ToCompilerDiagnostic for CompileBoundaryDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : CompileBoundaryDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    NoRootSourceModule =>
      compile_report(
        "no root source module",
        diagnostic_.span,
        code="E4000",
        label="the compiler did not receive a root Lane module",
        note="Lane compile/check needs exactly one root source module",
        help="pass a source file that starts with a `module` declaration",
      )
    DuplicateModuleInput(module_) =>
      compile_report(
        "duplicate module input `\{module_}`",
        diagnostic_.span,
        code="E4001",
        label="this module was supplied more than once",
        note="a module input set cannot contain two sources with the same module name",
        help="remove one source file or rename one of the modules",
      )
    MissingImportWithCandidates(module_~, source_modules~, interface_modules~) =>
      missing_import_diagnostic(
        module_,
        diagnostic_.span,
        source_modules,
        interface_modules,
      )
    ImportCycle(module_) =>
      compile_report(
        "import cycle involving `\{module_}`",
        diagnostic_.span,
        code="E4003",
        label="module imports must form an acyclic graph",
        note="cyclic module dependencies cannot be typechecked in a stable order",
        help="move shared declarations into a separate module imported by both sides",
      )
    CheckedSourceConstructionFailed =>
      compile_report(
        "compiler produced no checked source",
        diagnostic_.span,
        code="E4500",
        label="checked source construction failed",
        note="type checking finished without a checked source tree",
        help="report this as a compiler bug with the input that triggered it",
      )
    ParserProducedNoSourceFile =>
      compile_report(
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
