///|
/// Captures the symbol metadata needed to consume this module interface without
/// retaining the module's full revision metadata.
pub fn ModuleInterface::exported_symbol_metadata(
  self : ModuleInterface,
  registry : @symbol.SymbolRegistry,
) -> @symbol.SymbolMetadataArena {
  let symbols : Array[@symbol.SymbolId] = []
  for reference in self.type_references {
    symbols.push(Type(reference.symbol))
  }
  for reference in self.effect_references {
    symbols.push(Effect(reference.symbol))
  }
  for declaration in self.types {
    match declaration {
      Struct(declaration) => {
        symbols.push(Type(declaration.symbol))
        collect_type_parameters(declaration.type_parameters, symbols)
        for type_member in declaration.type_members {
          symbols.push(TypeMember(type_member.symbol))
          symbols.push(TypeParameter(type_member.type_parameter.id))
        }
        for field in declaration.fields {
          symbols.push(Field(field.symbol))
          collect_type_symbols(field.type_, symbols)
        }
      }
      Enum(declaration) => {
        symbols.push(Type(declaration.symbol))
        collect_type_parameters(declaration.type_parameters, symbols)
        for variant in declaration.variants {
          symbols.push(Variant(variant.symbol))
          collect_type_parameters(variant.type_parameters, symbols)
          for payload in variant.payload {
            collect_type_symbols(payload, symbols)
          }
        }
      }
      External(declaration) => symbols.push(Type(declaration.symbol))
    }
  }
  for effect in self.effects {
    symbols.push(Effect(effect.symbol))
    collect_type_parameters(effect.type_parameters, symbols)
    for operation in effect.operations {
      symbols.push(Operation(operation.symbol))
      collect_type_parameters(operation.type_parameters, symbols)
      for payload in operation.payload {
        collect_type_symbols(payload, symbols)
      }
      collect_type_symbols(operation.result, symbols)
    }
  }
  for type_alias in self.type_aliases {
    collect_type_parameters(type_alias.type_parameters, symbols)
    match type_alias.body {
      TypeBody(type_) => collect_type_symbols(type_, symbols)
      EffectBody(effect) => collect_effect_symbols(effect, symbols)
    }
  }
  for value in self.values {
    symbols.push(Value(value.symbol))
    collect_type_symbols(value.type_, symbols)
    if value.parameters is Some(parameters) {
      for parameter in parameters {
        symbols.push(Value(parameter.symbol))
        collect_type_symbols(parameter.type_, symbols)
      }
    }
  }
  registry.metadata_for(symbols)
}

///|
fn collect_type_parameters(
  parameters : Array[@types.TypeParameter],
  symbols : Array[@symbol.SymbolId],
) -> Unit {
  for parameter in parameters {
    symbols.push(TypeParameter(parameter.id))
  }
}

///|
fn collect_type_symbols(
  type_ : @types.Type,
  symbols : Array[@symbol.SymbolId],
) -> Unit {
  match type_ {
    Error | Primitive(_) => ()
    Constructor(symbol) => symbols.push(Type(symbol))
    Apply(callee, arguments) => {
      collect_type_symbols(callee, symbols)
      for argument in arguments {
        collect_generic_argument_symbols(argument, symbols)
      }
    }
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      collect_type_parameters(parameters, symbols)
      collect_type_symbols(body, symbols)
    }
    Parameter(id) => symbols.push(TypeParameter(id))
    Function(parameters, result, effect) => {
      for parameter in parameters {
        collect_type_symbols(parameter, symbols)
      }
      collect_type_symbols(result, symbols)
      collect_effect_symbols(effect, symbols)
    }
  }
}

///|
fn collect_effect_symbols(
  effect : @types.Effect,
  symbols : Array[@symbol.SymbolId],
) -> Unit {
  match effect {
    Empty | Io => ()
    Singleton(symbol, arguments) => {
      symbols.push(Effect(symbol))
      for argument in arguments {
        collect_generic_argument_symbols(argument, symbols)
      }
    }
    Parameter(id) => symbols.push(TypeParameter(id))
    Union(effects) =>
      for effect in effects {
        collect_effect_symbols(effect, symbols)
      }
  }
}

///|
fn collect_generic_argument_symbols(
  argument : @types.GenericArgument,
  symbols : Array[@symbol.SymbolId],
) -> Unit {
  match argument {
    TypeArgument(type_) => collect_type_symbols(type_, symbols)
    EffectArgument(effect) => collect_effect_symbols(effect, symbols)
  }
}
