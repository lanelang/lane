///|
fn SemanticChecker::module_interface(
  self : SemanticChecker,
  checked_source : @checked.CheckedSourceFile,
) -> @module_interface.ModuleInterface {
  {
    module_path: @module_interface.module_path_text(checked_source.module_path),
    types: checked_source.declarations.filter_map(interface_type),
    type_aliases: self.interface_type_aliases(),
    values: checked_source.declarations.filter_map(fn(declaration) {
      self.interface_value(declaration)
    }),
    optimization_hints: [],
  }
}

///|
fn interface_type(
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceType? {
  match declaration {
    Struct(declaration) if declaration.is_public =>
      Some(Struct(interface_struct(declaration)))
    Enum(declaration) if declaration.is_public =>
      Some(Enum(interface_enum(declaration)))
    _ => None
  }
}

///|
fn interface_struct(
  declaration : @checked.CheckedStructDeclaration,
) -> @module_interface.ModuleInterfaceStruct {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    type_members: declaration.type_members.map(interface_type_member),
    fields: declaration.fields.map(interface_field),
    loc: declaration.loc,
  }
}

///|
fn interface_type_member(
  declaration : @checked.CheckedTypeMemberDeclaration,
) -> @module_interface.ModuleInterfaceTypeMember {
  {
    symbol: declaration.symbol,
    type_parameter: declaration.type_parameter,
    name: declaration.name,
    kind: declaration.kind,
    index: declaration.index,
    loc: declaration.loc,
  }
}

///|
fn interface_field(
  declaration : @checked.CheckedFieldDeclaration,
) -> @module_interface.ModuleInterfaceField {
  {
    symbol: declaration.symbol,
    is_offered: declaration.is_offered,
    name: declaration.name,
    index: declaration.index,
    type_: declaration.type_,
    loc: declaration.loc,
  }
}

///|
fn interface_enum(
  declaration : @checked.CheckedEnumDeclaration,
) -> @module_interface.ModuleInterfaceEnum {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters,
    variants: declaration.variants.map(interface_variant),
    loc: declaration.loc,
  }
}

///|
fn interface_variant(
  declaration : @checked.CheckedVariantDeclaration,
) -> @module_interface.ModuleInterfaceVariant {
  {
    symbol: declaration.symbol,
    name: declaration.name,
    index: declaration.index,
    type_parameters: declaration.type_parameters,
    payload: declaration.payload,
    loc: declaration.loc,
  }
}

///|
fn SemanticChecker::interface_type_aliases(
  self : SemanticChecker,
) -> Array[@module_interface.ModuleInterfaceTypeAlias] {
  let aliases : Array[@module_interface.ModuleInterfaceTypeAlias] = []
  for declaration in self.resolved_source.declarations {
    match declaration {
      TypeAlias(declaration) if declaration.is_public => {
        let checker = TypeExpressionChecker::{
          source: self.resolved_source,
          imported_environment: self.imported_environment,
          diagnostics: self.diagnostics,
          expanding: [declaration.name],
        }
        let result = checker.synthesize_type(declaration.body)
        aliases.push({
          name: declaration.name,
          body: result.type_.normalize(),
          kind: result.kind,
          loc: declaration.loc,
        })
      }
      _ => ()
    }
  }
  aliases
}

///|
fn SemanticChecker::interface_value(
  self : SemanticChecker,
  declaration : @checked.CheckedTopLevelDeclaration,
) -> @module_interface.ModuleInterfaceValue? {
  match declaration {
    Function(declaration) if declaration.is_public =>
      Some({
        symbol: declaration.symbol,
        kind: Function,
        name: declaration.name,
        type_: declaration.type_,
        parameters: Some(declaration.parameters.map(interface_value_parameter)),
        loc: declaration.loc,
      })
    Let(declaration) if declaration.is_public && declaration.name is Some(name) =>
      Some({
        symbol: declaration.symbol,
        kind: self.interface_value_kind(declaration.symbol),
        name,
        type_: declaration.type_,
        parameters: None,
        loc: declaration.loc,
      })
    _ => None
  }
}

///|
fn interface_value_parameter(
  parameter : @checked.CheckedValueParameter,
) -> @module_interface.ModuleInterfaceValueParameter {
  {
    symbol: parameter.symbol,
    is_auto: parameter.is_auto,
    is_offered: parameter.is_offered,
    name: parameter.name,
    type_: parameter.type_,
    loc: parameter.loc,
  }
}

///|
fn SemanticChecker::interface_value_kind(
  self : SemanticChecker,
  symbol : ValueSymbolId,
) -> @module_interface.ModuleInterfaceValueKind {
  for declaration in self.resolved_source.declarations {
    match declaration {
      Offer(declaration) if declaration.symbol == symbol => return Offer
      _ => ()
    }
  }
  Let
}
