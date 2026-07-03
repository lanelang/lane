///|
pub(all) struct ImportedEnvironment {
  modules : Array[ModuleInterface]
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterface {
  module_path : String
  types : Array[ModuleInterfaceType]
  effects : Array[ModuleInterfaceEffect]
  type_aliases : Array[ModuleInterfaceTypeAlias]
  values : Array[ModuleInterfaceValue]
  optimization_hints : Array[OptimizationHint]
} derive(Debug, Eq)

///|
pub(all) enum ModuleInterfaceType {
  Struct(ModuleInterfaceStruct)
  Enum(ModuleInterfaceEnum)
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceStruct {
  symbol : TypeSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  type_members : Array[ModuleInterfaceTypeMember]
  fields : Array[ModuleInterfaceField]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceTypeMember {
  symbol : TypeMemberSymbolId
  type_parameter : @types.TypeParameter
  name : String
  kind : @types.Kind
  index : Int
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceField {
  symbol : FieldSymbolId
  is_offered : Bool
  name : String
  index : Int
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceEnum {
  symbol : TypeSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  variants : Array[ModuleInterfaceVariant]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceVariant {
  symbol : VariantSymbolId
  name : String
  index : Int
  type_parameters : Array[@types.TypeParameter]
  payload : Array[@types.Type]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceEffect {
  symbol : EffectSymbolId
  name : String
  type_parameters : Array[@types.TypeParameter]
  operations : Array[ModuleInterfaceOperation]
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceOperation {
  symbol : OperationSymbolId
  name : String
  index : Int
  type_parameters : Array[@types.TypeParameter]
  payload : Array[@types.Type]
  result : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceTypeAlias {
  name : String
  type_parameters : Array[@types.TypeParameter]
  body : ModuleInterfaceTypeAliasBody
  kind : @types.Kind
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ModuleInterfaceTypeAliasBody {
  TypeBody(@types.Type)
  EffectBody(@types.Effect)
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceValue {
  symbol : ValueSymbolId
  kind : ModuleInterfaceValueKind
  name : String
  type_ : @types.Type
  parameters : Array[ModuleInterfaceValueParameter]?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) enum ModuleInterfaceValueKind {
  Function
  Let
  Offer
} derive(Debug, Eq)

///|
pub(all) struct ModuleInterfaceValueParameter {
  symbol : ValueSymbolId
  is_auto : Bool
  is_offered : Bool
  name : String
  type_ : @types.Type
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct OptimizationHint {
  name : String
} derive(Debug, Eq)

///|
pub fn ImportedEnvironment::ImportedEnvironment() -> ImportedEnvironment {
  { modules: [] }
}

///|
pub fn ImportedEnvironment::find(
  self : ImportedEnvironment,
  module_path : String,
) -> ModuleInterface? {
  for interface in self.modules {
    if interface.module_path == module_path {
      return Some(interface)
    }
  }
  None
}

///|
pub fn module_path_text(path : @syntax.ModulePath) -> String {
  path.components.join(".")
}
