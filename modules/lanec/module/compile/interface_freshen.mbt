///|
priv struct TypeSymbolMapEntry {
  source : @symbol.TypeSymbolId
  target : @symbol.TypeSymbolId
}

///|
priv struct TypeParameterMapEntry {
  source : @symbol.TypeParameterId
  target : @symbol.TypeParameterId
}

///|
priv struct EffectSymbolMapEntry {
  source : @symbol.EffectSymbolId
  target : @symbol.EffectSymbolId
}

///|
priv struct StableTypeSymbolEntry {
  module_path : String
  name : String
  target : @symbol.TypeSymbolId
}

///|
priv struct StableEffectSymbolEntry {
  module_path : String
  name : String
  target : @symbol.EffectSymbolId
}

///|
priv struct InterfaceFresheningEnvironment {
  registry : @symbol.SymbolRegistry
  types : Array[StableTypeSymbolEntry]
  effects : Array[StableEffectSymbolEntry]
}

///|
priv struct InterfaceSymbolFreshener {
  environment : InterfaceFresheningEnvironment
  interface : @module_interface.ModuleInterface
  types : Array[TypeSymbolMapEntry]
  type_parameters : Array[TypeParameterMapEntry]
  effects : Array[EffectSymbolMapEntry]
}

///|
fn freshen_module_interface_artifacts(
  registry : @symbol.SymbolRegistry,
  artifacts : Array[ModuleInterfaceArtifact],
) -> @module_interface.ImportedEnvironment {
  let environment = InterfaceFresheningEnvironment::{
    registry,
    types: [],
    effects: [],
  }
  let modules = []
  for artifact in artifacts {
    modules.push(freshen_module_interface(environment, artifact.interface))
  }
  { modules, }
}

///|
fn freshen_module_interface(
  environment : InterfaceFresheningEnvironment,
  interface : @module_interface.ModuleInterface,
) -> @module_interface.ModuleInterface {
  let freshener = InterfaceSymbolFreshener::InterfaceSymbolFreshener(
    environment, interface,
  )
  freshener.predeclare_nominal_types(interface)
  freshener.predeclare_effects(interface)
  {
    module_path: interface.module_path,
    source_id: interface.source_id,
    type_references: interface.type_references.map(fn(reference) {
      {
        symbol: freshener.remap_type_symbol(reference.symbol),
        module_path: reference.module_path,
        name: reference.name,
      }
    }),
    effect_references: interface.effect_references.map(fn(reference) {
      {
        symbol: freshener.remap_effect_symbol(reference.symbol),
        module_path: reference.module_path,
        name: reference.name,
      }
    }),
    types: interface.types.map(fn(type_) { freshener.freshen_type(type_) }),
    effects: interface.effects.map(fn(effect) {
      freshener.freshen_effect(effect)
    }),
    type_aliases: interface.type_aliases.map(fn(type_alias) {
      freshener.freshen_type_alias(type_alias)
    }),
    values: interface.values.map(fn(value) { freshener.freshen_value(value) }),
    optimization_hints: interface.optimization_hints,
  }
}

///|
fn InterfaceSymbolFreshener::InterfaceSymbolFreshener(
  environment : InterfaceFresheningEnvironment,
  interface : @module_interface.ModuleInterface,
) -> InterfaceSymbolFreshener {
  { environment, interface, types: [], type_parameters: [], effects: [] }
}

///|
fn InterfaceSymbolFreshener::predeclare_nominal_types(
  self : InterfaceSymbolFreshener,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  for type_ in interface.types {
    match type_ {
      Struct(declaration) =>
        ignore(
          self.define_type(
            declaration.symbol,
            declaration.name,
            Struct,
            declaration.type_parameters.length(),
            declaration.loc,
          ),
        )
      Enum(declaration) =>
        ignore(
          self.define_type(
            declaration.symbol,
            declaration.name,
            Enum,
            declaration.type_parameters.length(),
            declaration.loc,
          ),
        )
      External(declaration) =>
        ignore(
          self.define_type(
            declaration.symbol,
            declaration.name,
            External,
            0,
            declaration.loc,
          ),
        )
    }
  }
}

///|
fn InterfaceSymbolFreshener::predeclare_effects(
  self : InterfaceSymbolFreshener,
  interface : @module_interface.ModuleInterface,
) -> Unit {
  for effect in interface.effects {
    ignore(
      self.define_effect(
        effect.symbol,
        effect.name,
        effect.type_parameters.length(),
        effect.flavor,
        effect.loc,
      ),
    )
  }
}

///|
fn InterfaceSymbolFreshener::freshen_type(
  self : InterfaceSymbolFreshener,
  type_ : @module_interface.ModuleInterfaceType,
) -> @module_interface.ModuleInterfaceType {
  match type_ {
    Struct(declaration) => Struct(self.freshen_struct_interface(declaration))
    Enum(declaration) => Enum(self.freshen_enum_interface(declaration))
    External(declaration) =>
      External({
        symbol: self.remap_type_symbol(declaration.symbol),
        name: declaration.name,
        loc: declaration.loc,
      })
  }
}

///|
fn InterfaceSymbolFreshener::freshen_struct_interface(
  self : InterfaceSymbolFreshener,
  declaration : @module_interface.ModuleInterfaceStruct,
) -> @module_interface.ModuleInterfaceStruct {
  let symbol = self.remap_type_symbol(declaration.symbol)
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.freshen_type_parameter(parameter)
  })
  let type_members = declaration.type_members.map(fn(type_member) {
    self.freshen_type_member(symbol, type_member)
  })
  let fields = declaration.fields.map(fn(field) {
    self.freshen_field(symbol, field)
  })
  {
    symbol,
    name: declaration.name,
    type_parameters,
    type_members,
    fields,
    loc: declaration.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_enum_interface(
  self : InterfaceSymbolFreshener,
  declaration : @module_interface.ModuleInterfaceEnum,
) -> @module_interface.ModuleInterfaceEnum {
  let symbol = self.remap_type_symbol(declaration.symbol)
  let type_parameters = declaration.type_parameters.map(fn(parameter) {
    self.freshen_type_parameter(parameter)
  })
  let variants = declaration.variants.map(fn(variant) {
    self.freshen_variant(symbol, variant)
  })
  {
    symbol,
    name: declaration.name,
    type_parameters,
    variants,
    loc: declaration.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_type_member(
  self : InterfaceSymbolFreshener,
  owner : @symbol.TypeSymbolId,
  type_member : @module_interface.ModuleInterfaceTypeMember,
) -> @module_interface.ModuleInterfaceTypeMember {
  let type_parameter = self.freshen_type_parameter(type_member.type_parameter)
  let symbol = self.environment.registry.define_type_member(
    owner,
    type_member.name,
    type_member.index,
    type_parameter.id,
    type_member.loc,
  )
  {
    symbol,
    type_parameter,
    name: type_member.name,
    kind: type_member.kind,
    index: type_member.index,
    loc: type_member.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_field(
  self : InterfaceSymbolFreshener,
  owner : @symbol.TypeSymbolId,
  field : @module_interface.ModuleInterfaceField,
) -> @module_interface.ModuleInterfaceField {
  let symbol = self.environment.registry.define_field(
    owner,
    field.name,
    field.index,
    field.loc,
  )
  {
    symbol,
    name: field.name,
    index: field.index,
    type_: self.freshen_lane_type(field.type_),
    loc: field.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_variant(
  self : InterfaceSymbolFreshener,
  owner : @symbol.TypeSymbolId,
  variant : @module_interface.ModuleInterfaceVariant,
) -> @module_interface.ModuleInterfaceVariant {
  let type_parameters = variant.type_parameters.map(fn(parameter) {
    self.freshen_type_parameter(parameter)
  })
  let symbol = self.environment.registry.define_variant(
    owner,
    variant.name,
    variant.index,
    variant.payload.length(),
    variant.loc,
  )
  {
    symbol,
    name: variant.name,
    index: variant.index,
    type_parameters,
    payload: variant.payload.map(fn(type_) { self.freshen_lane_type(type_) }),
    loc: variant.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_effect(
  self : InterfaceSymbolFreshener,
  effect : @module_interface.ModuleInterfaceEffect,
) -> @module_interface.ModuleInterfaceEffect {
  let symbol = self.remap_effect_symbol(effect.symbol)
  let type_parameters = effect.type_parameters.map(fn(parameter) {
    self.freshen_type_parameter(parameter)
  })
  let operations = effect.operations.map(fn(operation) {
    self.freshen_operation(symbol, operation)
  })
  {
    symbol,
    name: effect.name,
    flavor: effect.flavor,
    type_parameters,
    operations,
    loc: effect.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_operation(
  self : InterfaceSymbolFreshener,
  owner : @symbol.EffectSymbolId,
  operation : @module_interface.ModuleInterfaceOperation,
) -> @module_interface.ModuleInterfaceOperation {
  let type_parameters = operation.type_parameters.map(fn(parameter) {
    self.freshen_type_parameter(parameter)
  })
  let symbol = self.environment.registry.define_operation(
    owner,
    operation.name,
    operation.index,
    operation.payload.length(),
    operation.loc,
  )
  {
    symbol,
    name: operation.name,
    index: operation.index,
    type_parameters,
    payload: operation.payload.map(fn(type_) { self.freshen_lane_type(type_) }),
    result: self.freshen_lane_type(operation.result),
    loc: operation.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_type_alias(
  self : InterfaceSymbolFreshener,
  type_alias : @module_interface.ModuleInterfaceTypeAlias,
) -> @module_interface.ModuleInterfaceTypeAlias {
  {
    name: type_alias.name,
    type_parameters: type_alias.type_parameters.map(fn(parameter) {
      self.freshen_type_parameter(parameter)
    }),
    body: self.freshen_type_alias_body(type_alias.body),
    kind: type_alias.kind,
    loc: type_alias.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_type_alias_body(
  self : InterfaceSymbolFreshener,
  body : @module_interface.ModuleInterfaceTypeAliasBody,
) -> @module_interface.ModuleInterfaceTypeAliasBody {
  match body {
    TypeBody(type_) => TypeBody(self.freshen_lane_type(type_))
    EffectBody(effect) => EffectBody(self.freshen_lane_effect(effect))
  }
}

///|
fn InterfaceSymbolFreshener::freshen_value(
  self : InterfaceSymbolFreshener,
  value : @module_interface.ModuleInterfaceValue,
) -> @module_interface.ModuleInterfaceValue {
  let symbol = self.environment.registry.define_value(
    value.name,
    value_symbol_kind_from_interface(value.kind),
    value.loc,
  )
  {
    symbol,
    kind: value.kind,
    is_offered: value.is_offered,
    name: value.name,
    type_: self.freshen_lane_type(value.type_),
    tuple_presentations: value.tuple_presentations,
    parameters: value.parameters.map(fn(parameters) {
      parameters.map(fn(parameter) { self.freshen_value_parameter(parameter) })
    }),
    loc: value.loc,
  }
}

///|
fn InterfaceSymbolFreshener::freshen_value_parameter(
  self : InterfaceSymbolFreshener,
  parameter : @module_interface.ModuleInterfaceValueParameter,
) -> @module_interface.ModuleInterfaceValueParameter {
  let symbol = self.environment.registry.define_value(
    parameter.name,
    Parameter,
    parameter.loc,
  )
  {
    symbol,
    is_auto: parameter.is_auto,
    is_offered: parameter.is_offered,
    name: parameter.name,
    type_: self.freshen_lane_type(parameter.type_),
    loc: parameter.loc,
  }
}

///|
fn value_symbol_kind_from_interface(
  kind : @module_interface.ModuleInterfaceValueKind,
) -> @symbol.ValueSymbolKind {
  match kind {
    Function => TopLevelFunction
    Let => TopLevelValue
  }
}

///|
fn InterfaceSymbolFreshener::freshen_type_parameter(
  self : InterfaceSymbolFreshener,
  parameter : @types.TypeParameter,
) -> @types.TypeParameter {
  match self.lookup_type_parameter(parameter.id) {
    Some(id) => { id, name: parameter.name, kind: parameter.kind }
    None => {
      let id = self.environment.registry.define_type_parameter(
        parameter.name,
        @basic.SourceSpan::dummy(),
      )
      self.type_parameters.push({ source: parameter.id, target: id })
      { id, name: parameter.name, kind: parameter.kind }
    }
  }
}

///|
fn InterfaceSymbolFreshener::freshen_lane_type(
  self : InterfaceSymbolFreshener,
  type_ : @types.Type,
) -> @types.Type {
  match type_ {
    Error => Error
    Primitive(primitive) => Primitive(primitive)
    Constructor(symbol) => Constructor(self.remap_type_symbol(symbol))
    Apply(callee, arguments) =>
      Apply(
        self.freshen_lane_type(callee),
        arguments.map(fn(argument) {
          self.freshen_lane_generic_argument(argument)
        }),
      )
    TypeLambda(parameters, body) => {
      let parameters = parameters.map(fn(parameter) {
        self.freshen_type_parameter(parameter)
      })
      TypeLambda(parameters, self.freshen_lane_type(body))
    }
    Parameter(id) => Parameter(self.remap_type_parameter(id))
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) { self.freshen_lane_type(parameter) }),
        self.freshen_lane_type(result),
        self.freshen_lane_effect(effect),
      )
    Forall(parameters, body) => {
      let parameters = parameters.map(fn(parameter) {
        self.freshen_type_parameter(parameter)
      })
      Forall(parameters, self.freshen_lane_type(body))
    }
  }
}

///|
fn InterfaceSymbolFreshener::freshen_lane_effect(
  self : InterfaceSymbolFreshener,
  effect : @types.Effect,
) -> @types.Effect {
  match effect {
    Empty => Empty
    Io => Io
    Singleton(symbol, arguments) =>
      Singleton(
        self.remap_effect_symbol(symbol),
        arguments.map(fn(argument) {
          self.freshen_lane_generic_argument(argument)
        }),
      )
    Parameter(id) => Parameter(self.remap_type_parameter(id))
    Union(effects) =>
      Union(effects.map(fn(effect) { self.freshen_lane_effect(effect) }))
  }
}

///|
fn InterfaceSymbolFreshener::freshen_lane_generic_argument(
  self : InterfaceSymbolFreshener,
  argument : @types.GenericArgument,
) -> @types.GenericArgument {
  match argument {
    TypeArgument(type_) => TypeArgument(self.freshen_lane_type(type_))
    EffectArgument(effect) => EffectArgument(self.freshen_lane_effect(effect))
  }
}

///|
fn InterfaceSymbolFreshener::define_type(
  self : InterfaceSymbolFreshener,
  source : @symbol.TypeSymbolId,
  name : String,
  kind : @symbol.NominalTypeKind,
  arity : Int,
  loc : @basic.SourceSpan,
) -> @symbol.TypeSymbolId {
  match self.lookup_type_symbol(source) {
    Some(symbol) => symbol
    None => {
      let target = self.environment.define_type(
        self.interface.module_path,
        name,
        kind,
        arity,
        loc,
      )
      self.types.push({ source, target })
      target
    }
  }
}

///|
fn InterfaceSymbolFreshener::define_effect(
  self : InterfaceSymbolFreshener,
  source : @symbol.EffectSymbolId,
  name : String,
  arity : Int,
  flavor : @symbol.EffectFlavor,
  loc : @basic.SourceSpan,
) -> @symbol.EffectSymbolId {
  match self.lookup_effect_symbol(source) {
    Some(symbol) => symbol
    None => {
      let target = self.environment.define_effect(
        self.interface.module_path,
        name,
        arity,
        flavor,
        loc,
      )
      self.effects.push({ source, target })
      target
    }
  }
}

///|
fn InterfaceSymbolFreshener::remap_type_symbol(
  self : InterfaceSymbolFreshener,
  source : @symbol.TypeSymbolId,
) -> @symbol.TypeSymbolId {
  match self.lookup_type_symbol(source) {
    Some(target) => target
    None => {
      for reference in self.interface.type_references {
        if reference.symbol == source {
          match
            self.environment.find_type(reference.module_path, reference.name) {
            Some(target) => return target
            None =>
              abort(
                "missing interface type dependency \{reference.module_path}.\{reference.name}",
              )
          }
        }
      }
      abort("missing canonical interface type reference")
    }
  }
}

///|
fn InterfaceSymbolFreshener::remap_type_parameter(
  self : InterfaceSymbolFreshener,
  source : @symbol.TypeParameterId,
) -> @symbol.TypeParameterId {
  match self.lookup_type_parameter(source) {
    Some(target) => target
    None =>
      abort(
        "missing canonical interface type parameter mapping for \{source.index}",
      )
  }
}

///|
fn InterfaceSymbolFreshener::remap_effect_symbol(
  self : InterfaceSymbolFreshener,
  source : @symbol.EffectSymbolId,
) -> @symbol.EffectSymbolId {
  match self.lookup_effect_symbol(source) {
    Some(target) => target
    None => {
      for reference in self.interface.effect_references {
        if reference.symbol == source {
          match
            self.environment.find_effect(reference.module_path, reference.name) {
            Some(target) => return target
            None =>
              abort(
                "missing interface effect dependency \{reference.module_path}.\{reference.name}",
              )
          }
        }
      }
      abort("missing canonical interface effect reference")
    }
  }
}

///|
fn InterfaceFresheningEnvironment::define_type(
  self : InterfaceFresheningEnvironment,
  module_path : String,
  name : String,
  kind : @symbol.NominalTypeKind,
  arity : Int,
  loc : @basic.SourceSpan,
) -> @symbol.TypeSymbolId {
  match self.find_type(module_path, name) {
    Some(target) => target
    None => {
      let target = self.registry.define_type(name, kind, arity, loc)
      self.types.push({ module_path, name, target })
      target
    }
  }
}

///|
fn InterfaceFresheningEnvironment::find_type(
  self : InterfaceFresheningEnvironment,
  module_path : String,
  name : String,
) -> @symbol.TypeSymbolId? {
  for entry in self.types {
    if entry.module_path == module_path && entry.name == name {
      return Some(entry.target)
    }
  }
  None
}

///|
fn InterfaceFresheningEnvironment::define_effect(
  self : InterfaceFresheningEnvironment,
  module_path : String,
  name : String,
  arity : Int,
  flavor : @symbol.EffectFlavor,
  loc : @basic.SourceSpan,
) -> @symbol.EffectSymbolId {
  match self.find_effect(module_path, name) {
    Some(target) => target
    None => {
      let target = self.registry.define_effect(name, arity, loc, flavor~)
      self.effects.push({ module_path, name, target })
      target
    }
  }
}

///|
fn InterfaceFresheningEnvironment::find_effect(
  self : InterfaceFresheningEnvironment,
  module_path : String,
  name : String,
) -> @symbol.EffectSymbolId? {
  for entry in self.effects {
    if entry.module_path == module_path && entry.name == name {
      return Some(entry.target)
    }
  }
  None
}

///|
fn InterfaceSymbolFreshener::lookup_type_symbol(
  self : InterfaceSymbolFreshener,
  source : @symbol.TypeSymbolId,
) -> @symbol.TypeSymbolId? {
  for entry in self.types {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn InterfaceSymbolFreshener::lookup_effect_symbol(
  self : InterfaceSymbolFreshener,
  source : @symbol.EffectSymbolId,
) -> @symbol.EffectSymbolId? {
  for entry in self.effects {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}

///|
fn InterfaceSymbolFreshener::lookup_type_parameter(
  self : InterfaceSymbolFreshener,
  source : @symbol.TypeParameterId,
) -> @symbol.TypeParameterId? {
  for entry in self.type_parameters {
    if entry.source == source {
      return Some(entry.target)
    }
  }
  None
}
