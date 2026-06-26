///|
fn SemanticChecker::type_symbol_for_name(
  self : SemanticChecker,
  name : String,
) -> TypeSymbolId? {
  match self.source.symbols.type_named(name) {
    Some(symbol) => Some(symbol)
    None =>
      match qualified_type_name(name) {
        Some(qualified) =>
          match self.imported_environment.find(qualified.module_path) {
            Some(module_) => module_.type_symbol_named(qualified.name)
            None => None
          }
        None => None
      }
  }
}

///|
fn @module_interface.ModuleInterface::type_symbol_named(
  self : @module_interface.ModuleInterface,
  name : String,
) -> TypeSymbolId? {
  for type_ in self.types {
    match type_ {
      Struct(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      Enum(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      _ => ()
    }
  }
  None
}

///|
fn qualified_type_name(name : String) -> QualifiedAliasName? {
  let parts = name.split(".").map(StringView::to_owned).collect()
  if parts.length() < 2 {
    return None
  }
  let module_segments = []
  for index in 0..<(parts.length() - 1) {
    module_segments.push(parts[index])
  }
  Some({
    module_path: module_segments.join("."),
    name: parts[parts.length() - 1],
  })
}
