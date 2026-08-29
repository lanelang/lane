///|
test "invalid resolved metadata remains a typed compiler defect" {
  guard @module_frontend.parse_source({
      source_id: "file:///Main.lane",
      text: "module Main\npub let answer : I64 = missing",
    })
    is Available(input) else {
    fail("expected parsed source")
  }
  let registry = @symbol.SymbolIdentityAllocator::SymbolIdentityAllocator().registry()
  let imports = @module_interface.ModuleImportEnvironments::from_pool(
    [],
    ModuleInterfaceCatalog(),
  )
  let resolved = @resolve.resolve_source_file_with_imports_result(
    input.source,
    registry,
    imports.available,
  )
  guard finish_source_elaboration(input, resolved.source, imports)
    is CompilerDefect(defect) else {
    fail("expected invalid input metadata to remain a compiler defect")
  }
  assert_true(defect.cause() is InvalidTypecheckInput(InvalidInputMetadata(_)))
  assert_eq(defect.diagnostic().code, Some("E4599"))
}
