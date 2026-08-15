///|
/// The type and effect symbols a **Module Interface** references.
///
/// Symbols the interface owns appear alongside foreign ones; callers that want
/// only foreign dependencies filter by owner through
/// `dependency_module_paths`.
pub(all) struct InterfaceDependencySymbols {
  types : Array[TypeSymbolId]
  effects : Array[EffectSymbolId]
} derive(Debug, Eq)

///|
/// Every symbol reachable from this interface's content.
///
/// This walks the interface itself rather than reading `type_references`,
/// which is an owner lookup table accumulated from imported interfaces and is
/// therefore a strict over-approximation. Only what the content mentions
/// constrains a consumer.
///
/// `optimization_hints` carry no symbols today. They are covered by this rule
/// so that a hint which later embeds a body cannot silently escape it.
pub fn ModuleInterface::dependency_symbols(
  self : ModuleInterface,
) -> InterfaceDependencySymbols {
  let symbols = { types: [], effects: [] }
  for type_ in self.types {
    collect_nominal_dependencies(type_, symbols)
  }
  for effect in self.effects {
    for operation in effect.operations {
      for payload in operation.payload {
        collect_type_dependencies(payload, symbols)
      }
      collect_type_dependencies(operation.result, symbols)
    }
  }
  for type_alias in self.type_aliases {
    match type_alias.body {
      TypeBody(type_) => collect_type_dependencies(type_, symbols)
      EffectBody(effect) => collect_effect_dependencies(effect, symbols)
    }
  }
  for value in self.values {
    collect_type_dependencies(value.type_, symbols)
  }
  symbols
}

///|
/// The **Module Paths** whose declarations this interface's content depends on.
///
/// This is the **Reachable Interface Closure** contribution of one interface:
/// a consumer that resolves declarations against this interface needs exactly
/// these modules, not everything the module happened to import. Owners are read
/// from the interface's own reference tables, so a symbol whose owner is
/// unrecorded contributes nothing rather than guessing.
pub fn ModuleInterface::dependency_module_paths(
  self : ModuleInterface,
) -> Array[String] {
  // Every reference this interface records is, by construction, the owner of a
  // symbol its own content mentions, so the tables already answer the question
  // without walking the surface again.
  let paths = []
  for reference in self.type_references {
    push_unique_path(paths, self.module_path, reference.module_path)
  }
  for reference in self.effect_references {
    push_unique_path(paths, self.module_path, reference.module_path)
  }
  for export_ in self.exports {
    push_unique_path(paths, self.module_path, export_.target.provider_module)
  }
  paths
}

///|
fn push_unique_path(
  paths : Array[String],
  owner : String,
  module_path : String,
) -> Unit {
  if module_path != owner && !paths.contains(module_path) {
    paths.push(module_path)
  }
}

///|
/// Every symbol reachable from one exported nominal shape.
///
/// Fields and variant payloads count because they are **Owner-Visible
/// Members**: a consumer can project them without importing their owner, so
/// their types must be resolvable.
pub fn ModuleInterfaceType::dependency_symbols(
  self : ModuleInterfaceType,
) -> InterfaceDependencySymbols {
  let symbols = { types: [], effects: [] }
  collect_nominal_dependencies(self, symbols)
  symbols
}

///|
pub fn ModuleInterfaceDeclaration::dependency_symbols(
  self : ModuleInterfaceDeclaration,
) -> InterfaceDependencySymbols {
  let symbols = { types: [], effects: [] }
  match self {
    NominalType(type_) => collect_nominal_dependencies(type_, symbols)
    TypeAlias(alias_) =>
      match alias_.body {
        TypeBody(type_) => collect_type_dependencies(type_, symbols)
        EffectBody(effect) => collect_effect_dependencies(effect, symbols)
      }
    Effect(effect) =>
      for operation in effect.operations {
        for payload in operation.payload {
          collect_type_dependencies(payload, symbols)
        }
        collect_type_dependencies(operation.result, symbols)
      }
    Value(value) => collect_type_dependencies(value.type_, symbols)
  }
  symbols
}

///|
fn collect_nominal_dependencies(
  type_ : ModuleInterfaceType,
  symbols : InterfaceDependencySymbols,
) -> Unit {
  match type_ {
    Struct(declaration) =>
      for field in declaration.fields {
        collect_type_dependencies(field.type_, symbols)
      }
    Enum(declaration) =>
      for variant in declaration.variants {
        for payload in variant.payload {
          collect_type_dependencies(payload, symbols)
        }
      }
    External(_) => ()
  }
}

///|
fn collect_type_dependencies(
  type_ : @types.Type,
  symbols : InterfaceDependencySymbols,
) -> Unit {
  match type_ {
    Error | Primitive(_) | Parameter(_) => ()
    Constructor(symbol) => push_unique_type_symbol(symbols.types, symbol)
    Apply(callee, arguments) => {
      collect_type_dependencies(callee, symbols)
      for argument in arguments {
        collect_generic_dependencies(argument, symbols)
      }
    }
    TypeLambda(_, body) | Forall(_, body) =>
      collect_type_dependencies(body, symbols)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        collect_type_dependencies(parameter, symbols)
      }
      collect_type_dependencies(result, symbols)
      collect_effect_dependencies(effect, symbols)
    }
  }
}

///|
fn collect_effect_dependencies(
  effect : @types.Effect,
  symbols : InterfaceDependencySymbols,
) -> Unit {
  match effect {
    Empty | Builtin(_) | Parameter(_) => ()
    Singleton(symbol, arguments) => {
      push_unique_effect_symbol(symbols.effects, symbol)
      for argument in arguments {
        collect_generic_dependencies(argument, symbols)
      }
    }
    Union(effects) =>
      for nested in effects {
        collect_effect_dependencies(nested, symbols)
      }
  }
}

///|
fn collect_generic_dependencies(
  argument : @types.GenericArgument,
  symbols : InterfaceDependencySymbols,
) -> Unit {
  match argument {
    TypeArgument(type_) => collect_type_dependencies(type_, symbols)
    EffectArgument(effect) => collect_effect_dependencies(effect, symbols)
  }
}

///|
fn push_unique_type_symbol(
  symbols : Array[TypeSymbolId],
  symbol : TypeSymbolId,
) -> Unit {
  if !symbols.contains(symbol) {
    symbols.push(symbol)
  }
}

///|
fn push_unique_effect_symbol(
  symbols : Array[EffectSymbolId],
  symbol : EffectSymbolId,
) -> Unit {
  if !symbols.contains(symbol) {
    symbols.push(symbol)
  }
}
