///|
priv enum ArtifactDiagnosticKind {
  DuplicateModuleInterfaceArtifact(String)
  UnsupportedModuleInterfaceArtifactSchema(String)
  InvalidModuleInterfaceArtifact(module_path_text~ : String, reason~ : String)
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
  UnsupportedLinkedProgramArtifactSchema
  InvalidLinkedBuslaneProgram
  DuplicateLinkedModule(String)
  LinkedEntryUnknownValue(String)
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
  let diagnostic : ArtifactDiagnostic = { kind, span }
  diagnostic.to_compiler_diagnostic(DiagnosticContext())
}

///|
impl @compiler_diag.ToCompilerDiagnostic for ArtifactDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : ArtifactDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    DuplicateModuleInterfaceArtifact(module_) =>
      compile_report(
        "duplicate interface artifact for `\{module_}`",
        diagnostic_.span,
        code="E4100",
        label="two interface artifacts describe the same module",
        note="compile uses one interface per imported module",
        help="remove the duplicate `--interface` input",
      )
    UnsupportedModuleInterfaceArtifactSchema(module_) =>
      compile_report(
        "unsupported module interface artifact schema",
        diagnostic_.span,
        code="E4101",
        label="unsupported module interface artifact schema \{module_}",
        note="this `.lmi` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the provider module with the current `lane compile`",
      )
    InvalidModuleInterfaceArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid module interface artifact",
        diagnostic_.span,
        code="E4102",
        label="module interface artifact \{reason} \{module_path_text}",
        note="the interface artifact metadata does not match its embedded module interface",
        help="recompile the provider module and pass the fresh `.lmi` file",
      )
    DuplicateModuleObjectArtifact(module_) =>
      compile_report(
        "duplicate object artifact for `\{module_}`",
        diagnostic_.span,
        code="E4200",
        label="two object artifacts define the same module",
        note="linking requires one object artifact per module",
        help="remove the duplicate `.lmo` input",
      )
    UnsupportedModuleObjectArtifactSchema(schema~, module_path_text~) =>
      compile_report(
        "unsupported module object artifact schema",
        diagnostic_.span,
        code="E4201",
        label="unsupported module object artifact schema \{schema} for \{module_path_text}",
        note="this `.lmo` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the module with the current `lane compile`",
      )
    InvalidModuleObjectArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid module object artifact",
        diagnostic_.span,
        code="E4202",
        label="module object artifact \{reason} \{module_path_text}",
        note="the object artifact metadata does not match its embedded interface or fingerprints",
        help="recompile the module and pass the fresh `.lmo` file",
      )
    UnsupportedModuleArtifactSchema(module_) =>
      compile_report(
        "unsupported compiled module artifact schema",
        diagnostic_.span,
        code="E4301",
        label=unsupported_module_artifact_schema_label(module_),
        note="this compiled module artifact is not compatible with the current compiler",
        help="recompile all modules with the current compiler",
      )
    InvalidModuleArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid compiled module artifact",
        diagnostic_.span,
        code="E4302",
        label="module artifact \{reason} \{module_path_text}",
        note="the compiled module artifact has inconsistent interface/object metadata",
        help="recompile the module instead of mixing old interface and object files",
      )
    ArtifactImportedInterfaceFingerprintMismatch(importer~, imported~) =>
      compile_report(
        "stale imported interface",
        diagnostic_.span,
        code="E4103",
        label="imported interface fingerprint mismatch \{importer} -> \{imported}",
        note="the importer was compiled against a different interface fingerprint",
        help="recompile the importer and provider modules together",
      )
    UnsupportedLinkedProgramArtifactSchema =>
      compile_report(
        "unsupported linked program artifact schema",
        diagnostic_.span,
        code="E4400",
        label="unsupported linked program artifact schema",
        note="this linked program artifact is not compatible with the current runtime",
        help="link the program again with the current `lane link`",
      )
    InvalidLinkedBuslaneProgram =>
      compile_report(
        "linked program contains invalid Buslane",
        diagnostic_.span,
        code="E4401",
        label="the Buslane verifier rejected the linked program",
        note="this usually means the compiler or linker emitted inconsistent core terms",
        help="recompile and relink; if the error remains, report it as a compiler bug",
      )
    DuplicateLinkedModule(module_) =>
      compile_report(
        "duplicate linked module `\{module_}`",
        diagnostic_.span,
        code="E4402",
        label="the linked program lists this module more than once",
        note="linked program metadata must contain each module once",
        help="relink from a deduplicated object input set",
      )
    LinkedEntryUnknownValue(entry) =>
      compile_report(
        "linked entry `\{entry}` points to an unknown value",
        diagnostic_.span,
        code="E4403",
        label="entry metadata references a value that is not in the Buslane program",
        note="entry metadata is produced by the linker from public Lane entries",
        help="relink the program; if the error remains, report it as a compiler bug",
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
