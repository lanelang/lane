///|
fn BuslaneLowerer::seed_imported_dependency_headers(
  self : BuslaneLowerer,
  interface : @module_interface.ModuleInterface,
  available : @module_interface.ImportedEnvironment,
) -> Result[Unit, BuslaneLoweringError] {
  let type_symbols : Array[@symbol.TypeSymbolId] = []
  let effect_symbols : Array[@symbol.EffectSymbolId] = []
  collect_interface_dependency_symbols(interface, type_symbols, effect_symbols)
  for symbol in type_symbols {
    if self.registry.find_type(symbol) is Some(_) {
      continue
    }
    guard find_interface_type_reference(interface, symbol) is Some(reference) else {
      return Err(MissingTypeReference(symbol))
    }
    guard find_available_interface_type(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(type_) else {
      return Err(MissingTypeDependency(reference.module_path, reference.name))
    }
    match
      self.seed_imported_type_dependency(
        reference.module_path,
        type_,
        available,
      ) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  for symbol in effect_symbols {
    if self.registry.find_effect(symbol) is Some(_) {
      continue
    }
    guard find_interface_effect_reference(interface, symbol) is Some(reference) else {
      return Err(MissingEffectReference(symbol))
    }
    guard find_available_interface_effect(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(effect) else {
      return Err(MissingEffectDependency(reference.module_path, reference.name))
    }
    self.seed_imported_effect_header(reference.module_path, effect)
  }
  Ok(())
}

///|
fn BuslaneLowerer::seed_imported_type_dependency(
  self : BuslaneLowerer,
  module_path : String,
  type_ : @module_interface.ModuleInterfaceType,
  available : @module_interface.ImportedEnvironment,
) -> Result[Unit, BuslaneLoweringError] {
  self.seed_imported_type_header(module_path, type_)
  guard available.find(module_path) is Some(interface) else {
    return Err(MissingTypeDependency(module_path, interface_type_name(type_)))
  }
  let type_symbols : Array[@symbol.TypeSymbolId] = []
  let effect_symbols : Array[@symbol.EffectSymbolId] = []
  collect_interface_type_dependency_symbols(type_, type_symbols, effect_symbols)
  for symbol in type_symbols {
    if self.registry.find_type(symbol) is Some(_) {
      continue
    }
    guard find_interface_type_reference(interface, symbol) is Some(reference) else {
      return Err(MissingTypeReference(symbol))
    }
    guard find_available_interface_type(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(dependency) else {
      return Err(MissingTypeDependency(reference.module_path, reference.name))
    }
    match
      self.seed_imported_type_dependency(
        reference.module_path,
        dependency,
        available,
      ) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  for symbol in effect_symbols {
    if self.registry.find_effect(symbol) is Some(_) {
      continue
    }
    guard find_interface_effect_reference(interface, symbol) is Some(reference) else {
      return Err(MissingEffectReference(symbol))
    }
    guard find_available_interface_effect(
        available,
        reference.module_path,
        reference.name,
      )
      is Some(effect) else {
      return Err(MissingEffectDependency(reference.module_path, reference.name))
    }
    self.seed_imported_effect_header(reference.module_path, effect)
  }
  if type_ is Struct(declaration) {
    for field in declaration.fields {
      self.seed_imported_field_selector(module_path, declaration, field)
    }
  }
  Ok(())
}

///|
fn collect_interface_dependency_symbols(
  interface : @module_interface.ModuleInterface,
  type_symbols : Array[@symbol.TypeSymbolId],
  effect_symbols : Array[@symbol.EffectSymbolId],
) -> Unit {
  for type_ in interface.types {
    collect_interface_type_dependency_symbols(
      type_, type_symbols, effect_symbols,
    )
  }
  for effect in interface.effects {
    for operation in effect.operations {
      for payload in operation.payload {
        collect_type_dependency_symbols(payload, type_symbols, effect_symbols)
      }
      collect_type_dependency_symbols(
        operation.result,
        type_symbols,
        effect_symbols,
      )
    }
  }
  for type_alias in interface.type_aliases {
    match type_alias.body {
      TypeBody(type_) =>
        collect_type_dependency_symbols(type_, type_symbols, effect_symbols)
      EffectBody(effect) =>
        collect_effect_dependency_symbols(effect, type_symbols, effect_symbols)
    }
  }
  for value in interface.values {
    collect_type_dependency_symbols(value.type_, type_symbols, effect_symbols)
  }
}

///|
fn collect_interface_type_dependency_symbols(
  type_ : @module_interface.ModuleInterfaceType,
  type_symbols : Array[@symbol.TypeSymbolId],
  effect_symbols : Array[@symbol.EffectSymbolId],
) -> Unit {
  match type_ {
    Struct(declaration) =>
      for field in declaration.fields {
        collect_type_dependency_symbols(
          field.type_,
          type_symbols,
          effect_symbols,
        )
      }
    Enum(declaration) =>
      for variant in declaration.variants {
        for payload in variant.payload {
          collect_type_dependency_symbols(payload, type_symbols, effect_symbols)
        }
      }
    External(_) => ()
  }
}

///|
fn collect_type_dependency_symbols(
  type_ : @types.Type,
  type_symbols : Array[@symbol.TypeSymbolId],
  effect_symbols : Array[@symbol.EffectSymbolId],
) -> Unit {
  match type_ {
    Error | Primitive(_) | Parameter(_) => ()
    Constructor(symbol) => append_type_symbol(type_symbols, symbol)
    Apply(callee, arguments) => {
      collect_type_dependency_symbols(callee, type_symbols, effect_symbols)
      for argument in arguments {
        collect_generic_dependency_symbols(
          argument, type_symbols, effect_symbols,
        )
      }
    }
    TypeLambda(_, body) | Forall(_, body) =>
      collect_type_dependency_symbols(body, type_symbols, effect_symbols)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        collect_type_dependency_symbols(parameter, type_symbols, effect_symbols)
      }
      collect_type_dependency_symbols(result, type_symbols, effect_symbols)
      collect_effect_dependency_symbols(effect, type_symbols, effect_symbols)
    }
  }
}

///|
fn collect_effect_dependency_symbols(
  effect : @types.Effect,
  type_symbols : Array[@symbol.TypeSymbolId],
  effect_symbols : Array[@symbol.EffectSymbolId],
) -> Unit {
  match effect {
    Empty | Io | Parameter(_) => ()
    Singleton(symbol, arguments) => {
      append_effect_symbol(effect_symbols, symbol)
      for argument in arguments {
        collect_generic_dependency_symbols(
          argument, type_symbols, effect_symbols,
        )
      }
    }
    Union(effects) =>
      for nested in effects {
        collect_effect_dependency_symbols(nested, type_symbols, effect_symbols)
      }
  }
}

///|
fn collect_generic_dependency_symbols(
  argument : @types.GenericArgument,
  type_symbols : Array[@symbol.TypeSymbolId],
  effect_symbols : Array[@symbol.EffectSymbolId],
) -> Unit {
  match argument {
    TypeArgument(type_) =>
      collect_type_dependency_symbols(type_, type_symbols, effect_symbols)
    EffectArgument(effect) =>
      collect_effect_dependency_symbols(effect, type_symbols, effect_symbols)
  }
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
fn append_effect_symbol(
  symbols : Array[@symbol.EffectSymbolId],
  symbol : @symbol.EffectSymbolId,
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
