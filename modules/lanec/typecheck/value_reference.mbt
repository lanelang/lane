///|
fn SemanticChecker::synthesize_value_reference(
  self : SemanticChecker,
  scope : TypeScope,
  reference : @resolve.ResolvedValueReference,
  name : String,
  loc : SourceSpan,
) -> @types.Type {
  match reference {
    Symbol(symbol) =>
      match scope.lookup(symbol) {
        Some(type_) => type_
        None => {
          self.diagnostics.push({ kind: UnresolvedValue(name), loc })
          Error
        }
      }
    Unresolved(name) => {
      self.diagnostics.push({ kind: UnresolvedValue(name), loc })
      Error
    }
  }
}
