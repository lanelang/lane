///|
/// Resolves, checks, certifies, and lints one parsed module in source order.
/// Declaration identity reuse is optional policy supplied by an incremental
/// caller; every other semantic fact is produced here exactly once.
pub fn elaborate_source(
  input : @module_frontend.ParsedModuleInput,
  registry : @symbol.SymbolRegistry,
  imports : @module_interface.ModuleImportEnvironments,
  previous_declarations? : @symbol.DeclarationIdentities? = None,
) -> SourceElaborationOutcome {
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imports.available,
    previous_declarations~,
  )
  if !resolved.diagnostics.is_empty() {
    return ResolutionFailed({
      resolved: resolved.source,
      diagnostics: resolve_diagnostics(resolved.diagnostics, input.source_id),
    })
  }
  finish_source_elaboration(input, resolved.source, imports)
}

///|
fn finish_source_elaboration(
  input : @module_frontend.ParsedModuleInput,
  resolved : @resolve.ResolvedSourceFile,
  imports : @module_interface.ModuleImportEnvironments,
) -> SourceElaborationOutcome {
  let checked = match
    @typecheck.typecheck_checked_source_file_with_imported_environment(
      resolved,
      imports.typecheck_environment(),
    ) {
    Ok(checked) => checked
    Err(error) =>
      return CompilerDefect({
        source_id: input.source_id,
        resolved,
        cause: InvalidTypecheckInput(error),
      })
  }
  let display = @typecheck.TypeDisplayContext::from_registry(resolved.symbols)
  if !checked.diagnostics.is_empty() {
    return TypecheckFailed({
      resolved,
      diagnostics: typecheck_diagnostics(
        checked.diagnostics,
        display,
        input.source_id,
      ),
    })
  }
  guard (checked.source, checked.module_interface)
    is (Some(source), Some(interface)) else {
    return CompilerDefect({
      source_id: input.source_id,
      resolved,
      cause: IncompleteTypecheckOutput,
    })
  }
  let interface = { ..interface, source_id: Some(input.source_id), }
  let warnings = @lint.checked_unused_local_value_binding_diagnostics(
    source,
    resolved.symbols,
    input.text,
  )
  warnings.append(
    @lint.checked_semantic_warning_diagnostics(resolved, source, input.text),
  )
  Succeeded({
    resolved,
    checked: source,
    interface,
    exported_symbols: interface.exported_symbol_metadata(resolved.symbols),
    warnings: warnings.map(fn(diagnostic) {
      diagnostic.with_source_id(input.source_id)
    }),
  })
}
