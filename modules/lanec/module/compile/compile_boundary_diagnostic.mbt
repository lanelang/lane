///|
priv enum CompileBoundaryDiagnosticKind {
  InitializationCycle(names~ : Array[String])
  CompiledModuleSetMissingRoot
}

///|
pub fn compiled_module_set_missing_root_diagnostic() -> CompilerDiagnostic {
  compile_boundary_diagnostic(CompiledModuleSetMissingRoot, None)
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
  let diagnostic : CompileBoundaryDiagnostic = { kind, span, }
  @compiler_diag.ToCompilerDiagnostic::to_compiler_diagnostic(
    diagnostic,
    DiagnosticContext(),
  )
}

///|
/// Reports top-level values whose initializers cannot be put in any order.
///
/// The span is the first member's name, so the report points at a declaration
/// the author can move or rewrite.
fn initialization_cycle_diagnostic(
  members : Array[@checked.CheckedInitializationCycleMember],
) -> CompilerDiagnostic {
  compile_boundary_diagnostic(
    InitializationCycle(names=members.map(entry => entry.name)),
    members.get(0).map(entry => entry.name_loc),
  )
}

///|
fn buslane_lowering_diagnostic(
  importer : String,
  error : @buslane_lowering.BuslaneLoweringError,
) -> CompilerDiagnostic {
  let dependency = match error {
    MissingTypeReference(symbol) => "unresolved type symbol \{Repr(symbol)}"
    MissingEffectReference(symbol) => "unresolved effect symbol \{Repr(symbol)}"
    MissingTypeDependency(module_path, name) => "type `\{module_path}.\{name}`"
    MissingEffectDependency(module_path, name) =>
      "effect `\{module_path}.\{name}`"
    MetadataAllocationCompilerDefect(allocation_error) =>
      return compile_report(
        "internal compiler error while lowering Buslane metadata",
        None,
        code="E4599",
        label="Buslane metadata identity allocation failed",
        note="metadata lowering exhausted its identity space: \{Repr(allocation_error)}",
        help="report this compiler defect with the input module sources",
      )
  }
  compile_report(
    "missing Buslane interface dependency",
    None,
    code="E4501",
    label="`\{importer}` cannot lower \{dependency}",
    note="a public imported signature references an unavailable interface dependency",
    help="provide the complete transitive interface closure and report this if all source dependencies are present",
  )
}

///|
impl @compiler_diag.ToCompilerDiagnostic for CompileBoundaryDiagnostic with fn to_compiler_diagnostic(
  diagnostic_ : CompileBoundaryDiagnostic,
  _context : @compiler_diag.DiagnosticContext,
) -> CompilerDiagnostic {
  match diagnostic_.kind {
    InitializationCycle(names~) =>
      compile_report(
        "initialization cycle between `\{names.join("`, `")}`",
        diagnostic_.span,
        code="E4004",
        label="this initializer depends on its own value",
        note="a top-level value is initialized after every value its initializer reads, directly or through the functions it calls",
        help="break the cycle by moving the shared computation into a function each initializer calls",
      )
    CompiledModuleSetMissingRoot =>
      compile_report(
        "internal compiler error while selecting the root module",
        diagnostic_.span,
        code="E4599",
        label="the compiled module set does not contain its declared root",
        note="Module Graph validation guarantees that the root is compiled exactly once",
        help="report this compiler defect with the input module sources",
      )
  }
}
