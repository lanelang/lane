///|
pub fn CanonicalBasicAbiRuntimeContractError::object_diagnostic(
  self : CanonicalBasicAbiRuntimeContractError,
  module_path_text : String,
) -> @compiler_diag.CompilerDiagnostic {
  let detail = match self {
    MissingDeclaration(provider~) =>
      "canonical Basic provider `\{provider.qualified_name()}` is not bound to the certified runtime identity"
    InvalidDeclaration(provider~, reason~) =>
      "canonical Basic provider `\{provider.qualified_name()}` is invalid: \{reason}"
  }
  @compiler_diag.compiler_error(
    "invalid canonical Basic ABI in module object `\{module_path_text}`",
    span=None,
    code=Some("E4208"),
    labels=[],
    notes=[
      detail, "module objects must carry the certified canonical Basic runtime contract before identity remapping begins",
    ],
    helps=["recompile the module object from valid Lane source"],
    context=DiagnosticContext(),
  )
}
