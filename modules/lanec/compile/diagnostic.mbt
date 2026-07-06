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
priv enum CompileErrorKind {
  NoRootSourceModule
  DuplicateModuleInput(String)
  MissingImportWithCandidates(
    module_~ : String,
    source_modules~ : Array[String],
    interface_modules~ : Array[String]
  )
  ImportCycle(String)
  DuplicateModuleInterfaceArtifact(String)
  UnsupportedModuleInterfaceArtifactSchema(String)
  InvalidModuleInterfaceArtifact(module_path_text~ : String, reason~ : String)
  DuplicateModuleObjectArtifact(String)
  UnsupportedModuleObjectArtifactSchema(
    schema~ : Int,
    module_path_text~ : String
  )
  InvalidModuleObjectArtifact(module_path_text~ : String, reason~ : String)
  DuplicateModuleArtifact(String)
  UnsupportedModuleArtifactSchema(String?)
  InvalidModuleArtifact(module_path_text~ : String, reason~ : String)
  MissingObject(String)
  MissingImportedObject(String)
  ImportedInterfaceFingerprintMismatch(importer~ : String, imported~ : String)
  ImportedReferenceFingerprintMismatch(
    importer~ : String,
    imported~ : String,
    name~ : String
  )
  ImportedReferenceMismatch(
    importer~ : String,
    imported~ : String,
    name~ : String
  )
  MissingExported(
    kind~ : String,
    provider~ : String,
    name~ : String,
    importer~ : String
  )
  StaleModuleObject(module_path_text~ : String, reason~ : String)
  UnsupportedLinkedProgramArtifactSchema
  InvalidLinkedBuslaneProgram
  DuplicateLinkedModule(String)
  LinkedEntryUnknownValue(String)
  DuplicateLinkedEntry(String)
  CheckedSourceConstructionFailed
  ParserProducedNoSourceFile
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
fn CompileErrorKind::to_diagnostic(
  self : CompileErrorKind,
  span : @basic.SourceSpan?,
) -> CompilerDiagnostic {
  match self {
    NoRootSourceModule =>
      compile_report(
        "no root source module",
        span,
        code="E4000",
        label="the compiler did not receive a root Lane module",
        note="Lane compile/check needs exactly one root source module",
        help="pass a source file that starts with a `module` declaration",
      )
    DuplicateModuleInput(module_) =>
      compile_report(
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
      compile_report(
        "import cycle involving `\{module_}`",
        span,
        code="E4003",
        label="module imports must form an acyclic graph",
        note="cyclic module dependencies cannot be typechecked in a stable order",
        help="move shared declarations into a separate module imported by both sides",
      )
    DuplicateModuleInterfaceArtifact(module_) =>
      compile_report(
        "duplicate interface artifact for `\{module_}`",
        span,
        code="E4100",
        label="two interface artifacts describe the same module",
        note="compile uses one interface per imported module",
        help="remove the duplicate `--interface` input",
      )
    UnsupportedModuleInterfaceArtifactSchema(module_) =>
      compile_report(
        "unsupported module interface artifact schema",
        span,
        code="E4101",
        label="unsupported module interface artifact schema \{module_}",
        note="this `.lmi` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the provider module with the current `lane compile`",
      )
    InvalidModuleInterfaceArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid module interface artifact",
        span,
        code="E4102",
        label="module interface artifact \{reason} \{module_path_text}",
        note="the interface artifact metadata does not match its embedded module interface",
        help="recompile the provider module and pass the fresh `.lmi` file",
      )
    DuplicateModuleObjectArtifact(module_) =>
      compile_report(
        "duplicate object artifact for `\{module_}`",
        span,
        code="E4200",
        label="two object artifacts define the same module",
        note="linking requires one object artifact per module",
        help="remove the duplicate `.lmo` input",
      )
    UnsupportedModuleObjectArtifactSchema(schema~, module_path_text~) =>
      compile_report(
        "unsupported module object artifact schema",
        span,
        code="E4201",
        label="unsupported module object artifact schema \{schema} for \{module_path_text}",
        note="this `.lmo` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the module with the current `lane compile`",
      )
    InvalidModuleObjectArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid module object artifact",
        span,
        code="E4202",
        label="module object artifact \{reason} \{module_path_text}",
        note="the object artifact metadata does not match its embedded interface or fingerprints",
        help="recompile the module and pass the fresh `.lmo` file",
      )
    DuplicateModuleArtifact(module_) =>
      compile_report(
        "duplicate compiled module `\{module_}`",
        span,
        code="E4300",
        label="two compiled modules have the same module name",
        note="linking requires one compiled module for each module name",
        help="remove the duplicate module artifact",
      )
    UnsupportedModuleArtifactSchema(module_) =>
      compile_report(
        "unsupported compiled module artifact schema",
        span,
        code="E4301",
        label=unsupported_module_artifact_schema_label(module_),
        note="this compiled module artifact is not compatible with the current compiler",
        help="recompile all modules with the current compiler",
      )
    InvalidModuleArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid compiled module artifact",
        span,
        code="E4302",
        label="module artifact \{reason} \{module_path_text}",
        note="the compiled module artifact has inconsistent interface/object metadata",
        help="recompile the module instead of mixing old interface and object files",
      )
    MissingObject(module_) =>
      compile_report(
        "missing object artifact for `\{module_}`",
        span,
        code="E4203",
        label="the linker needs this module object but it was not provided",
        note="module objects contain the compiled Buslane terms used by the linker",
        help="compile `\{module_}` and pass its `.lmo` to `lane link`",
      )
    MissingImportedObject(module_) =>
      compile_report(
        "missing imported object artifact for `\{module_}`",
        span,
        code="E4204",
        label="an object imports this module but the linker cannot find its object",
        note="linking follows object dependencies recorded during compile",
        help="pass the missing module's `.lmo` to `lane link`",
      )
    ImportedInterfaceFingerprintMismatch(importer~, imported~) =>
      compile_report(
        "stale imported interface",
        span,
        code="E4103",
        label="imported interface fingerprint mismatch \{importer} -> \{imported}",
        note="the importer was compiled against a different interface fingerprint",
        help="recompile the importer and provider modules together",
      )
    ImportedReferenceFingerprintMismatch(importer~, imported~, name~) =>
      compile_report(
        "stale imported reference",
        span,
        code="E4205",
        label="imported reference fingerprint mismatch \{importer} -> \{imported}::\{name}",
        note="an object refers to an exported symbol shape that no longer matches its provider",
        help="recompile the importing module against the current provider object",
      )
    ImportedReferenceMismatch(importer~, imported~, name~) =>
      compile_report(
        "stale imported reference",
        span,
        code="E4205",
        label="imported reference mismatch \{importer} -> \{imported}::\{name}",
        note="an object refers to an exported symbol shape that no longer matches its provider",
        help="recompile the importing module against the current provider object",
      )
    MissingExported(kind~, provider~, name~, importer~) =>
      compile_report(
        "object artifact does not satisfy its interface",
        span,
        code="E4206",
        label="missing exported \{kind} \{provider}::\{name} imported by \{importer}",
        note="the imported interface advertises a public item that the object does not export",
        help="recompile the provider module and use matching `.lmi` and `.lmo` artifacts",
      )
    StaleModuleObject(module_path_text~, reason~) =>
      compile_report(
        "stale module object",
        span,
        code="E4207",
        label="\{reason} \{module_path_text}",
        note="the compiled object fingerprint does not match the module interface metadata",
        help="recompile the module before linking",
      )
    UnsupportedLinkedProgramArtifactSchema =>
      compile_report(
        "unsupported linked program artifact schema",
        span,
        code="E4400",
        label="unsupported linked program artifact schema",
        note="this linked program artifact is not compatible with the current runtime",
        help="link the program again with the current `lane link`",
      )
    InvalidLinkedBuslaneProgram =>
      compile_report(
        "linked program contains invalid Buslane",
        span,
        code="E4401",
        label="the Buslane verifier rejected the linked program",
        note="this usually means the compiler or linker emitted inconsistent core terms",
        help="recompile and relink; if the error remains, report it as a compiler bug",
      )
    DuplicateLinkedModule(module_) =>
      compile_report(
        "duplicate linked module `\{module_}`",
        span,
        code="E4402",
        label="the linked program lists this module more than once",
        note="linked program metadata must contain each module once",
        help="relink from a deduplicated object input set",
      )
    LinkedEntryUnknownValue(entry) =>
      compile_report(
        "linked entry `\{entry}` points to an unknown value",
        span,
        code="E4403",
        label="entry metadata references a value that is not in the Buslane program",
        note="entry metadata is produced by the linker from public Lane entries",
        help="relink the program; if the error remains, report it as a compiler bug",
      )
    DuplicateLinkedEntry(entry) =>
      compile_report(
        "duplicate linked entry `\{entry}`",
        span,
        code="E4404",
        label="the linked program exports this entry name more than once",
        note="entry lookup must resolve to exactly one linked value",
        help="rename one of the public entries or relink from a consistent object set",
      )
    CheckedSourceConstructionFailed =>
      compile_report(
        "compiler produced no checked source",
        span,
        code="E4500",
        label="checked source construction failed",
        note="type checking finished without a checked source tree",
        help="report this as a compiler bug with the input that triggered it",
      )
    ParserProducedNoSourceFile =>
      compile_report(
        "parser produced no source file",
        span,
        code="E1102",
        label="parser produced no source file",
        note="the parser returned neither a source tree nor a concrete parse error",
        help="report this as a compiler bug with the input that triggered it",
      )
  }
}

///|
fn unsupported_module_artifact_schema_label(module_ : String?) -> String {
  match module_ {
    Some(module_) => "unsupported module artifact schema \{module_}"
    None => "unsupported module artifact schema"
  }
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
    UnterminatedBlockComment => "E1001"
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
    UnterminatedBlockComment => "unterminated block comment"
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
    UnterminatedBlockComment => "this block comment is never closed"
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
    UnterminatedBlockComment => ["add a closing `*/` before the end of file"]
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
