///|
test "successful elaboration owns one complete semantic result" {
  guard @module_frontend.parse_source({
      source_id: "file:///Main.lane",
      text: "module Main\npub let answer : I64 = 42",
    })
    is Available(input) else {
    fail("expected parsed source")
  }
  let registry = @symbol.SymbolIdentityAllocator::SymbolIdentityAllocator().registry()
  let imports = @module_interface.ModuleImportEnvironments::from_pool(
    [],
    ModuleInterfaceCatalog(),
  )
  let outcome = elaborate_source(input, registry, imports)
  guard outcome is Succeeded(success) else {
    fail("expected successful source elaboration")
  }
  assert_eq(outcome.resolved_source().symbols, registry)
  assert_eq(success.module_interface().source_id, Some("file:///Main.lane"))
  assert_eq(success.warnings(), [])
}
