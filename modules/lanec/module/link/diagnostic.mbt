///|
using @compiler_diag {
  type CompilerDiagnostic,
  type CompilerDiagnosticLabel,
  compiler_diagnostic,
  compiler_primary_labels,
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
  compiler_diagnostic(
    title,
    span~,
    severity=Error,
    code=Some(code),
    labels=primary_labels(span, label),
    notes=[note],
    helps=[help],
    facts=[],
    suggestions=[],
  )
}

///|
fn primary_labels(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompilerDiagnosticLabel] {
  compiler_primary_labels(span, message)
}

///|
priv enum LinkDiagnosticKind {
  DuplicateModuleArtifact(String)
  LinkImportCycle(String)
  MissingObject(String)
  MissingImportedObject(String)
  LinkImportedInterfaceFingerprintMismatch(
    importer~ : String,
    imported~ : String
  )
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
}

///|
priv struct LinkDiagnostic {
  kind : LinkDiagnosticKind
  span : @basic.SourceSpan?
}

///|
fn link_diagnostic(
  kind : LinkDiagnosticKind,
  span : @basic.SourceSpan?,
) -> CompilerDiagnostic {
  let diagnostic : LinkDiagnostic = { kind, span }
  @compiler_diag.ToCompilerDiagnostic::to_compiler_diagnostic(
    diagnostic,
    DiagnosticContext(),
  )
}

///|
impl @compiler_diag.ToCompilerDiagnostic for LinkDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : LinkDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    DuplicateModuleArtifact(module_) =>
      compile_report(
        "duplicate compiled module `\{module_}`",
        diagnostic_.span,
        code="E4300",
        label="two compiled modules have the same module name",
        note="linking requires one compiled module for each module name",
        help="remove the duplicate module artifact",
      )
    LinkImportCycle(module_) =>
      compile_report(
        "import cycle involving `\{module_}`",
        diagnostic_.span,
        code="E4003",
        label="module imports must form an acyclic graph",
        note="cyclic module dependencies cannot be typechecked in a stable order",
        help="move shared declarations into a separate module imported by both sides",
      )
    MissingObject(module_) =>
      compile_report(
        "missing object artifact for `\{module_}`",
        diagnostic_.span,
        code="E4203",
        label="the linker needs this module object but it was not provided",
        note="module objects contain the compiled Buslane terms used by the linker",
        help="compile `\{module_}` and pass its `.lmo` to `lane link`",
      )
    MissingImportedObject(module_) =>
      compile_report(
        "missing imported object artifact for `\{module_}`",
        diagnostic_.span,
        code="E4204",
        label="an object imports this module but the linker cannot find its object",
        note="linking follows object dependencies recorded during compile",
        help="pass the missing module's `.lmo` to `lane link`",
      )
    LinkImportedInterfaceFingerprintMismatch(importer~, imported~) =>
      compile_report(
        "stale imported interface",
        diagnostic_.span,
        code="E4103",
        label="imported interface fingerprint mismatch \{importer} -> \{imported}",
        note="the importer was compiled against a different interface fingerprint",
        help="recompile the importer and provider modules together",
      )
    ImportedReferenceFingerprintMismatch(importer~, imported~, name~) =>
      compile_report(
        "stale imported reference",
        diagnostic_.span,
        code="E4205",
        label="imported reference fingerprint mismatch \{importer} -> \{imported}::\{name}",
        note="an object refers to an exported symbol shape that no longer matches its provider",
        help="recompile the importing module against the current provider object",
      )
    ImportedReferenceMismatch(importer~, imported~, name~) =>
      compile_report(
        "stale imported reference",
        diagnostic_.span,
        code="E4205",
        label="imported reference mismatch \{importer} -> \{imported}::\{name}",
        note="an object refers to an exported symbol shape that no longer matches its provider",
        help="recompile the importing module against the current provider object",
      )
    MissingExported(kind~, provider~, name~, importer~) =>
      compile_report(
        "object artifact does not satisfy its interface",
        diagnostic_.span,
        code="E4206",
        label="missing exported \{kind} \{provider}::\{name} imported by \{importer}",
        note="the imported interface advertises a public item that the object does not export",
        help="recompile the provider module and use matching `.lmi` and `.lmo` artifacts",
      )
    StaleModuleObject(module_path_text~, reason~) =>
      compile_report(
        "stale module object",
        diagnostic_.span,
        code="E4207",
        label="\{reason} \{module_path_text}",
        note="the compiled object fingerprint does not match the module interface metadata",
        help="recompile the module before linking",
      )
  }
}
