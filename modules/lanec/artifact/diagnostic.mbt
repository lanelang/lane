///|
using @compiler_diag {
  type CompilerDiagnostic,
  compiler_diagnostic,
  compiler_primary_labels,
}

///|
fn artifact_report(
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
    labels=compiler_primary_labels(span, label),
    notes=[note],
    helps=[help],
    facts=[],
    suggestions=[],
  )
}

///|
priv enum ArtifactDiagnosticKind {
  DuplicateModuleInterfaceArtifact(String)
  UnsupportedModuleInterfaceArtifactSchema(String)
  InvalidModuleInterfaceArtifact(module_path_text~ : String, reason~ : String)
  DuplicateModuleInterfaceExport(
    module_path_text~ : String,
    exposed_name~ : String
  )
  InvalidModuleInterfaceExport(
    module_path_text~ : String,
    exposed_name~ : String,
    reason~ : String
  )
  DuplicateModuleObjectArtifact(String)
  UnsupportedModuleObjectArtifactSchema(
    schema~ : Int,
    module_path_text~ : String
  )
  InvalidModuleObjectArtifact(module_path_text~ : String, reason~ : String)
  UnsupportedModuleArtifactSchema(String?)
  InvalidModuleArtifact(module_path_text~ : String, reason~ : String)
  ArtifactImportedInterfaceFingerprintMismatch(
    importer~ : String,
    imported~ : String
  )
}

///|
priv struct ArtifactDiagnostic {
  kind : ArtifactDiagnosticKind
  span : @basic.SourceSpan?
}

///|
fn artifact_diagnostic(
  kind : ArtifactDiagnosticKind,
  span : @basic.SourceSpan?,
) -> CompilerDiagnostic {
  let diagnostic : ArtifactDiagnostic = { kind, span, }
  @compiler_diag.ToCompilerDiagnostic::to_compiler_diagnostic(
    diagnostic,
    DiagnosticContext(),
  )
}

///|
impl @compiler_diag.ToCompilerDiagnostic for ArtifactDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : ArtifactDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    DuplicateModuleInterfaceArtifact(module_) =>
      artifact_report(
        "duplicate interface artifact for `\{module_}`",
        diagnostic_.span,
        code="E4100",
        label="two interface artifacts describe the same module",
        note="compile uses one interface per imported module",
        help="remove the duplicate `--interface` input",
      )
    UnsupportedModuleInterfaceArtifactSchema(module_) =>
      artifact_report(
        "unsupported module interface artifact schema",
        diagnostic_.span,
        code="E4101",
        label="unsupported module interface artifact schema \{module_}",
        note="this `.lmi` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the provider module with the current `lane compile`",
      )
    InvalidModuleInterfaceArtifact(module_path_text~, reason~) =>
      artifact_report(
        "invalid module interface artifact",
        diagnostic_.span,
        code="E4102",
        label="module interface artifact \{reason} \{module_path_text}",
        note="the interface artifact metadata does not match its embedded module interface",
        help="recompile the provider module and pass the fresh `.lmi` file",
      )
    DuplicateModuleInterfaceExport(module_path_text~, exposed_name~) =>
      artifact_report(
        "duplicate module interface export",
        diagnostic_.span,
        code="E4104",
        label="`\{module_path_text}` exports `\{exposed_name}` more than once in one namespace",
        note="each public export key must have exactly one declaration target",
        help="remove the duplicate export and recompile the module",
      )
    InvalidModuleInterfaceExport(module_path_text~, exposed_name~, reason~) =>
      artifact_report(
        "invalid module interface export",
        diagnostic_.span,
        code="E4105",
        label="export `\{module_path_text}.\{exposed_name}` \{reason}",
        note="public exports must resolve to the exact provider declaration recorded by the interface",
        help="recompile the facade and provider modules together",
      )
    DuplicateModuleObjectArtifact(module_) =>
      artifact_report(
        "duplicate object artifact for `\{module_}`",
        diagnostic_.span,
        code="E4200",
        label="two object artifacts define the same module",
        note="linking requires one object artifact per module",
        help="remove the duplicate `.lmo` input",
      )
    UnsupportedModuleObjectArtifactSchema(schema~, module_path_text~) =>
      artifact_report(
        "unsupported module object artifact schema",
        diagnostic_.span,
        code="E4201",
        label="unsupported module object artifact schema \{schema} for \{module_path_text}",
        note="this `.lmo` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the module with the current `lane compile`",
      )
    InvalidModuleObjectArtifact(module_path_text~, reason~) =>
      artifact_report(
        "invalid module object artifact",
        diagnostic_.span,
        code="E4202",
        label="module object artifact \{reason} \{module_path_text}",
        note="the object artifact metadata does not match its embedded interface or fingerprints",
        help="recompile the module and pass the fresh `.lmo` file",
      )
    UnsupportedModuleArtifactSchema(module_) =>
      artifact_report(
        "unsupported compiled module artifact schema",
        diagnostic_.span,
        code="E4301",
        label=unsupported_module_artifact_schema_label(module_),
        note="this compiled module artifact is not compatible with the current compiler",
        help="recompile all modules with the current compiler",
      )
    InvalidModuleArtifact(module_path_text~, reason~) =>
      artifact_report(
        "invalid compiled module artifact",
        diagnostic_.span,
        code="E4302",
        label="module artifact \{reason} \{module_path_text}",
        note="the compiled module artifact has inconsistent interface/object metadata",
        help="recompile the module instead of mixing old interface and object files",
      )
    ArtifactImportedInterfaceFingerprintMismatch(importer~, imported~) =>
      artifact_report(
        "stale imported interface",
        diagnostic_.span,
        code="E4103",
        label="imported interface fingerprint mismatch \{importer} -> \{imported}",
        note="the importer was compiled against a different interface fingerprint",
        help="recompile the importer and provider modules together",
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
