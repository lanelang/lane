///|
/// Physical-Lowering-owned handle for the Runtime-ANF-owned type catalog.
/// Derived expressions remain local to one lowering run, while instantiation
/// semantics stay in the Runtime ANF package.
priv struct RuntimeTypeArena {
  catalog : @anf.RuntimeTypeCatalog
}

///|
fn RuntimeTypeArena::from_metadata(
  metadata : @anf.RuntimeMetadata,
) -> RuntimeTypeArena {
  { catalog: metadata.runtime_type_catalog(), }
}

///|
fn RuntimeTypeArena::type_expression(
  self : RuntimeTypeArena,
  expression : @anf.RuntimeTypeExpressionId,
) -> @anf.RuntimeTypeExpression? {
  self.catalog.type_expression(expression)
}

///|
fn RuntimeTypeArena::intern(
  self : RuntimeTypeArena,
  expression : @anf.RuntimeTypeExpression,
) -> @anf.RuntimeTypeExpressionId {
  self.catalog.intern(expression)
}
