///|
fn BuslaneLowerer::seed_imported_dependency_headers(
  self : BuslaneLowerer,
  interface : @module_interface.ModuleInterface,
  available : @module_interface.ImportedEnvironment,
) -> Unit raise BuslaneLoweringError {
  let { types: type_symbols, effects: effect_symbols } = interface.dependency_symbols()
  for symbol in type_symbols {
    if self.registry.find_type(symbol) is Some(_) {
      continue
    }
    guard find_interface_type_reference(interface, symbol) is Some(reference) else {
      raise MissingTypeReference(symbol)
    }
    guard find_available_interface_type(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(type_) else {
      raise MissingTypeDependency(reference.module_path, reference.name)
    }
    self.seed_imported_type_dependency(reference.module_path, type_, available)
  }
  for symbol in effect_symbols {
    if self.registry.find_effect(symbol) is Some(_) {
      continue
    }
    guard find_interface_effect_reference(interface, symbol) is Some(reference) else {
      raise MissingEffectReference(symbol)
    }
    guard find_available_interface_effect(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(effect) else {
      raise MissingEffectDependency(reference.module_path, reference.name)
    }
    self.seed_imported_effect_header(reference.module_path, effect)
  }
}

///|
fn BuslaneLowerer::seed_imported_type_dependency(
  self : BuslaneLowerer,
  module_path : String,
  type_ : @module_interface.ModuleInterfaceType,
  available : @module_interface.ImportedEnvironment,
) -> Unit raise BuslaneLoweringError {
  self.seed_imported_type_header(module_path, type_)
  guard available.find(module_path) is Some(interface) else {
    raise MissingTypeDependency(module_path, interface_type_name(type_))
  }
  let { types: type_symbols, effects: effect_symbols } = type_.dependency_symbols()
  for symbol in type_symbols {
    if self.registry.find_type(symbol) is Some(_) {
      continue
    }
    guard find_interface_type_reference(interface, symbol) is Some(reference) else {
      raise MissingTypeReference(symbol)
    }
    guard find_available_interface_type(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(dependency) else {
      raise MissingTypeDependency(reference.module_path, reference.name)
    }
    self.seed_imported_type_dependency(
      reference.module_path,
      dependency,
      available,
    )
  }
  for symbol in effect_symbols {
    if self.registry.find_effect(symbol) is Some(_) {
      continue
    }
    guard find_interface_effect_reference(interface, symbol) is Some(reference) else {
      raise MissingEffectReference(symbol)
    }
    guard find_available_interface_effect(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(effect) else {
      raise MissingEffectDependency(reference.module_path, reference.name)
    }
    self.seed_imported_effect_header(reference.module_path, effect)
  }
  self.seed_unimported_owner_visible_members(module_path, type_)
}

///|
/// Seeds the members of a type reached through the interface closure that stay
/// usable without importing the module that declares it.
///
/// Field projection and unqualified variant patterns both reach owner-visible
/// members of a type the current module never imported, so field selectors and
/// variant data constructors must exist. Building a value names the type
/// itself, which requires an import, so a struct's data constructor is left to
/// the direct-import path and does not become a link edge here.
fn BuslaneLowerer::seed_unimported_owner_visible_members(
  self : BuslaneLowerer,
  module_path_text : String,
  type_ : @module_interface.ModuleInterfaceType,
) -> Unit raise BuslaneLoweringError {
  match type_ {
    Struct(declaration) =>
      for field in declaration.fields {
        self.seed_imported_field_selector(module_path_text, declaration, field)
      }
    Enum(declaration) =>
      self.seed_imported_variant_constructors(module_path_text, declaration)
    External(_) => ()
  }
}

///|
fn BuslaneLowerer::seed_structural_derive_dependencies(
  self : BuslaneLowerer,
  source : @checked.CheckedSourceFile,
  available : @module_interface.ImportedEnvironment,
) -> Unit raise BuslaneLoweringError {
  let symbols : Array[@symbol.TypeSymbolId] = []
  for declaration in source.declarations {
    match declaration {
      Function(declaration) =>
        collect_structural_derive_target_symbols(declaration.body, symbols)
      Let(declaration) =>
        collect_structural_derive_target_symbols(
          declaration.initializer,
          symbols,
        )
      _ => ()
    }
  }
  for symbol in symbols {
    if checked_source_declares_type(source, symbol) {
      continue
    }
    guard find_available_interface_type_by_symbol(available, symbol)
      is Some((module_path, type_)) else {
      abort("checked derive target is missing from the lowering environment")
    }
    match type_ {
      Struct(declaration) =>
        if self.registry.find_struct_constructor(declaration.symbol) is None {
          self.seed_imported_type_constructors(module_path, type_)
        }
      Enum(declaration) => {
        if declaration.variants.is_empty() {
          continue
        }
        let mut present = 0
        for variant in declaration.variants {
          if self.registry.find_data_constructor(variant.symbol) is Some(_) {
            present += 1
          }
        }
        if present == declaration.variants.length() {
          continue
        }
        if present != 0 {
          abort("partially seeded imported enum constructors")
        }
        self.seed_imported_type_constructors(module_path, type_)
      }
      External(_) => ()
    }
  }
}

///|
fn checked_source_declares_type(
  source : @checked.CheckedSourceFile,
  symbol : @symbol.TypeSymbolId,
) -> Bool {
  source.declarations.any(fn(declaration) {
    match declaration {
      Struct(declaration) => declaration.symbol == symbol
      Enum(declaration) => declaration.symbol == symbol
      ExternalType(declaration) => declaration.symbol == symbol
      _ => false
    }
  })
}

///|
fn collect_structural_derive_target_symbols(
  expression : @checked.CheckedExpr,
  symbols : Array[@symbol.TypeSymbolId],
) -> Unit {
  if expression is Derive(plan~, ..) {
    let symbol = match plan.target {
      Constructor(symbol) => symbol
      Apply(Constructor(symbol), _) => symbol
      _ => abort("checked derive target must be a normalized nominal type")
    }
    append_type_symbol(symbols, symbol)
  }
  expression.for_each_child_expr(fn(child) {
    collect_structural_derive_target_symbols(child, symbols)
  })
}

///|
fn append_type_symbol(
  symbols : Array[@symbol.TypeSymbolId],
  symbol : @symbol.TypeSymbolId,
) -> Unit {
  if !symbols.contains(symbol) {
    symbols.push(symbol)
  }
}

///|
fn find_interface_type_reference(
  interface : @module_interface.ModuleInterface,
  symbol : @symbol.TypeSymbolId,
) -> @module_interface.ModuleInterfaceTypeReference? {
  for reference in interface.type_references {
    if reference.symbol == symbol {
      return Some(reference)
    }
  }
  None
}

///|
fn find_interface_effect_reference(
  interface : @module_interface.ModuleInterface,
  symbol : @symbol.EffectSymbolId,
) -> @module_interface.ModuleInterfaceEffectReference? {
  for reference in interface.effect_references {
    if reference.symbol == symbol {
      return Some(reference)
    }
  }
  None
}

///|
fn find_available_interface_type(
  available : @module_interface.ImportedEnvironment,
  module_path : String,
  name : String,
) -> @module_interface.ModuleInterfaceType? {
  guard available.find(module_path) is Some(interface) else { return None }
  for type_ in interface.types {
    let type_name = match type_ {
      Struct(declaration) => declaration.name
      Enum(declaration) => declaration.name
      External(declaration) => declaration.name
    }
    if type_name == name {
      return Some(type_)
    }
  }
  None
}

///|
fn find_available_interface_type_by_symbol(
  available : @module_interface.ImportedEnvironment,
  symbol : @symbol.TypeSymbolId,
) -> (String, @module_interface.ModuleInterfaceType)? {
  for interface in available.modules {
    for type_ in interface.types {
      if interface_type_symbol(type_) == symbol {
        return Some((interface.module_path, type_))
      }
    }
  }
  None
}

///|
fn find_available_interface_effect(
  available : @module_interface.ImportedEnvironment,
  module_path : String,
  name : String,
) -> @module_interface.ModuleInterfaceEffect? {
  guard available.find(module_path) is Some(interface) else { return None }
  for effect in interface.effects {
    if effect.name == name {
      return Some(effect)
    }
  }
  None
}
