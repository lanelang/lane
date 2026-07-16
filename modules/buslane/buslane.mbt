///|
pub(all) struct TypeId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct TypeParameterId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct ValueId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct DataConId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct EffectId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct OperationId {
  index : Int
} derive(Debug, Eq, Compare)

///|
pub(all) enum NameNamespace {
  TypeName
  TypeParameterName
  ValueName
  DataConstructorName
  EffectName
  OperationName
} derive(Debug, Eq)

///|
pub(all) struct BuslaneUnique {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct BuslaneName {
  name_space : NameNamespace
  occurrence : String
  unique : BuslaneUnique
} derive(Debug, Eq)

///|
pub(all) enum Kind {
  Type
  Effect
  Function(Array[Kind], Kind)
} derive(Debug, Eq)

///|
pub(all) enum PrimitiveType {
  Unit
  Bool
  Int
  Double
  String
} derive(Debug, Eq)

///|
pub(all) enum Type {
  Primitive(PrimitiveType)
  Parameter(TypeParameterId)
  Constructor(TypeId)
  Apply(Type, Array[GenericArgument])
  TypeLambda(Array[TypeParameterId], Type)
  Function(Array[Type], Type, Effect)
  Forall(Array[TypeParameterId], Type)
} derive(Debug)

///|
pub(all) enum Effect {
  Empty
  Io
  Singleton(EffectId, Array[GenericArgument])
  Parameter(TypeParameterId)
  Union(Array[Effect])
} derive(Debug)

///|
pub(all) enum GenericArgument {
  TypeArgument(Type)
  EffectArgument(Effect)
} derive(Debug, Eq)

///|
pub(all) enum Literal {
  Unit
  Bool(Bool)
  Int(Int64)
  Double(Double)
  String(String)
} derive(Debug, Eq)

///|
pub(all) enum ValueKind {
  Function
  Value
  External
  Parameter
  Local
  MatchBinder
} derive(Debug, Eq)

///|
pub(all) enum TypeFlavor {
  Data
  External
} derive(Debug, Eq)

///|
pub(all) enum EffectFlavor {
  Algebraic
  External
} derive(Debug, Eq)

///|
pub(all) struct TypeInfo {
  name : BuslaneName
  flavor : TypeFlavor
  parameters : Array[TypeParameterId]
  constructors : Array[DataConId]
} derive(Debug, Eq)

///|
pub(all) struct TypeParameterInfo {
  name : BuslaneName
  kind : Kind
} derive(Debug, Eq)

///|
pub(all) struct ValueInfo {
  name : BuslaneName
  kind : ValueKind
  type_ : Type
} derive(Debug, Eq)

///|
pub(all) struct DataConInfo {
  name : BuslaneName
  owner : TypeId
  hidden_type_parameters : Array[TypeParameterId]
  payload_types : Array[Type]
} derive(Debug, Eq)

///|
pub(all) struct EffectInfo {
  name : BuslaneName
  flavor : EffectFlavor
  parameters : Array[TypeParameterId]
  operations : Array[OperationId]
} derive(Debug, Eq)

///|
pub(all) struct OperationInfo {
  name : BuslaneName
  owner : EffectId
  hidden_type_parameters : Array[TypeParameterId]
  payload_types : Array[Type]
  result_type : Type
} derive(Debug, Eq)

///|
pub(all) struct MetadataRegistry {
  mut next_unique : Int
  types : Array[TypeInfo]
  type_parameters : Array[TypeParameterInfo]
  values : Array[ValueInfo]
  data_constructors : Array[DataConInfo]
  effects : Array[EffectInfo]
  operations : Array[OperationInfo]
} derive(Debug, Eq)

///|
pub(all) struct Program {
  metadata : MetadataRegistry
  terms : Array[TopTerm]
} derive(Debug, Eq)

///|
pub(all) enum TopTerm {
  Let(ValueId, Expr)
  LetRec(Array[RecursiveBinding])
  External(ValueId)
} derive(Debug, Eq)

///|
pub(all) struct RecursiveBinding {
  id : ValueId
  rhs : Expr
} derive(Debug, Eq)

///|
pub(all) struct FunctionExpr {
  parameters : Array[ValueId]
  result_type : Type
  body : Expr
} derive(Debug, Eq)

///|
pub(all) struct ConstructExpr {
  data_constructor : DataConId
  type_arguments : Array[GenericArgument]
  hidden_witnesses : Array[GenericArgument]
  payloads : Array[Expr]
} derive(Debug, Eq)

///|
pub(all) struct MatchExpr {
  scrutinee : Expr
  binder : ValueId
  result_type : Type
  alternatives : Array[Alternative]
} derive(Debug, Eq)

///|
pub(all) struct PerformExpr {
  operation : OperationId
  effect_arguments : Array[GenericArgument]
  hidden_witnesses : Array[GenericArgument]
  payloads : Array[Expr]
} derive(Debug, Eq)

///|
pub(all) struct HandleExpr {
  body : Expr
  result_binder : ValueId
  result_type : Type
  final_body : Expr
  handlers : Array[HandlerTable]
} derive(Debug, Eq)

///|
pub(all) struct HandlerTable {
  handled_effect : Effect
  operations : Array[OperationAlternative]
} derive(Debug, Eq)

///|
pub(all) struct OperationAlternative {
  operation : OperationId
  type_binders : Array[TypeParameterId]
  payload_binders : Array[ValueId]
  resume_binder : ValueId
  body : Expr
} derive(Debug, Eq)

///|
pub(all) struct Alternative {
  alt_constructor : AltCon
  type_binders : Array[TypeParameterId]
  value_binders : Array[ValueId]
  body : Expr
} derive(Debug, Eq)

///|
pub(all) enum AltCon {
  Default
  Literal(Literal)
  DataCon(DataConId)
} derive(Debug, Eq)

///|
pub(all) enum Expr {
  Ref(ValueId)
  Literal(Literal)
  Function(FunctionExpr)
  Call(Expr, Array[Expr])
  TypeLambda(Array[TypeParameterId], Expr)
  TypeApply(Expr, Array[GenericArgument])
  Construct(ConstructExpr)
  Let(ValueId, Expr, Expr)
  LetRec(Array[RecursiveBinding], Expr)
  Match(MatchExpr)
  Perform(PerformExpr)
  Handle(HandleExpr)
  Resume(ValueId)
} derive(Debug, Eq)

///|
/// Creates an empty Buslane metadata registry.
pub fn MetadataRegistry::MetadataRegistry() -> MetadataRegistry {
  {
    next_unique: 0,
    types: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    effects: [],
    operations: [],
  }
}

///|
fn MetadataRegistry::fresh_name(
  self : MetadataRegistry,
  name_space : NameNamespace,
  occurrence : String,
) -> BuslaneName {
  let unique = BuslaneUnique::{ value: self.next_unique }
  self.next_unique = self.next_unique + 1
  { name_space, occurrence, unique }
}

///|
/// Defines a Buslane type parameter and returns its identity.
pub fn MetadataRegistry::define_type_parameter(
  self : MetadataRegistry,
  occurrence : String,
  kind : Kind,
) -> TypeParameterId {
  let id = TypeParameterId::{ index: self.type_parameters.length() }
  self.type_parameters.push({
    name: self.fresh_name(TypeParameterName, occurrence),
    kind,
  })
  id
}

///|
/// Defines a Buslane nominal type and returns its identity.
pub fn MetadataRegistry::define_type(
  self : MetadataRegistry,
  occurrence : String,
  parameters : Array[TypeParameterId],
  flavor? : TypeFlavor = Data,
) -> TypeId {
  let id = TypeId::{ index: self.types.length() }
  self.types.push({
    name: self.fresh_name(TypeName, occurrence),
    flavor,
    parameters,
    constructors: [],
  })
  id
}

///|
/// Defines a Buslane data constructor and attaches it to its owner type.
pub fn MetadataRegistry::define_data_constructor(
  self : MetadataRegistry,
  occurrence : String,
  owner : TypeId,
  hidden_type_parameters : Array[TypeParameterId],
  payload_types : Array[Type],
) -> DataConId {
  let id = DataConId::{ index: self.data_constructors.length() }
  self.data_constructors.push({
    name: self.fresh_name(DataConstructorName, occurrence),
    owner,
    hidden_type_parameters,
    payload_types,
  })
  guard self.types.get(owner.index) is Some(info) else { return id }
  info.constructors.push(id)
  id
}

///|
/// Defines a Buslane effect constructor and returns its identity.
pub fn MetadataRegistry::define_effect(
  self : MetadataRegistry,
  occurrence : String,
  parameters : Array[TypeParameterId],
  flavor? : EffectFlavor = Algebraic,
) -> EffectId {
  let id = EffectId::{ index: self.effects.length() }
  self.effects.push({
    name: self.fresh_name(EffectName, occurrence),
    flavor,
    parameters,
    operations: [],
  })
  id
}

///|
/// Defines a Buslane effect operation and attaches it to its owner effect.
pub fn MetadataRegistry::define_operation(
  self : MetadataRegistry,
  occurrence : String,
  owner : EffectId,
  hidden_type_parameters : Array[TypeParameterId],
  payload_types : Array[Type],
  result_type : Type,
) -> OperationId {
  let id = OperationId::{ index: self.operations.length() }
  self.operations.push({
    name: self.fresh_name(OperationName, occurrence),
    owner,
    hidden_type_parameters,
    payload_types,
    result_type,
  })
  guard self.effects.get(owner.index) is Some(info) else { return id }
  info.operations.push(id)
  id
}

///|
/// Defines a Buslane value and returns its identity.
pub fn MetadataRegistry::define_value(
  self : MetadataRegistry,
  occurrence : String,
  kind : ValueKind,
  type_ : Type,
) -> ValueId {
  let id = ValueId::{ index: self.values.length() }
  self.values.push({ name: self.fresh_name(ValueName, occurrence), kind, type_ })
  id
}

///|
/// Looks up metadata for a Buslane nominal type.
pub fn MetadataRegistry::type_info(
  self : MetadataRegistry,
  id : TypeId,
) -> TypeInfo? {
  self.types.get(id.index)
}

///|
/// Looks up metadata for a Buslane type parameter.
pub fn MetadataRegistry::type_parameter_info(
  self : MetadataRegistry,
  id : TypeParameterId,
) -> TypeParameterInfo? {
  self.type_parameters.get(id.index)
}

///|
/// Looks up metadata for a Buslane value.
pub fn MetadataRegistry::value_info(
  self : MetadataRegistry,
  id : ValueId,
) -> ValueInfo? {
  self.values.get(id.index)
}

///|
/// Looks up metadata for a Buslane data constructor.
pub fn MetadataRegistry::data_constructor_info(
  self : MetadataRegistry,
  id : DataConId,
) -> DataConInfo? {
  self.data_constructors.get(id.index)
}

///|
/// Looks up metadata for a Buslane effect constructor.
pub fn MetadataRegistry::effect_info(
  self : MetadataRegistry,
  id : EffectId,
) -> EffectInfo? {
  self.effects.get(id.index)
}

///|
/// Looks up metadata for a Buslane effect operation.
pub fn MetadataRegistry::operation_info(
  self : MetadataRegistry,
  id : OperationId,
) -> OperationInfo? {
  self.operations.get(id.index)
}

///|
/// Returns whether two Buslane types are definitionally equal.
pub fn Type::equals(self : Type, other : Type) -> Bool {
  alpha_equal_with([], self.normalize(), other.normalize())
}

///|
/// Returns whether two Buslane effects are canonically equal.
pub fn Effect::equals(self : Effect, other : Effect) -> Bool {
  alpha_equal_effect_with([], self, other)
}

///|
pub impl Eq for Type with fn equal(self : Type, other : Type) -> Bool {
  self.equals(other)
}

///|
pub impl Eq for Effect with fn equal(self : Effect, other : Effect) -> Bool {
  self.equals(other)
}

///|
/// Returns the canonical effect shape used for equality and diagnostics.
pub fn Effect::canonicalize(self : Effect) -> Effect {
  let terms = canonical_effect_terms([], self)
  match terms {
    [] => Empty
    [term] => term
    terms => Union(terms)
  }
}

///|
priv struct AlphaBinding {
  left : TypeParameterId
  right : TypeParameterId
}

///|
fn alpha_equal_with(
  bindings : Array[AlphaBinding],
  left : Type,
  right : Type,
) -> Bool {
  match (left, right) {
    (Primitive(left), Primitive(right)) => left == right
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(bindings, left, right)
    (Constructor(left_id), Constructor(right_id)) => left_id == right_id
    (Apply(left_callee, left_args), Apply(right_callee, right_args)) =>
      alpha_equal_with(bindings, left_callee, right_callee) &&
      same_length_generic_argument_alpha_equal(bindings, left_args, right_args)
    (TypeLambda(left_params, left_body), TypeLambda(right_params, right_body)) =>
      alpha_equal_binders(
        bindings, left_params, right_params, left_body, right_body,
      )
    (
      Function(left_params, left_result, left_effect),
      Function(right_params, right_result, right_effect),
    ) =>
      same_length_alpha_equal(bindings, left_params, right_params) &&
      alpha_equal_with(bindings, left_result, right_result) &&
      alpha_equal_effect_with(bindings, left_effect, right_effect)
    (Forall(left_params, left_body), Forall(right_params, right_body)) =>
      alpha_equal_binders(
        bindings, left_params, right_params, left_body, right_body,
      )
    _ => false
  }
}

///|
fn alpha_equal_effect_with(
  bindings : Array[AlphaBinding],
  left : Effect,
  right : Effect,
) -> Bool {
  let left_terms = canonical_effect_terms(bindings, left)
  let right_terms = canonical_effect_terms(bindings, right)
  if left_terms.length() != right_terms.length() {
    return false
  }
  for left_term in left_terms {
    if !right_terms.any(fn(right_term) {
        alpha_equal_effect_term_with(bindings, left_term, right_term)
      }) {
      return false
    }
  }
  true
}

///|
fn canonical_effect_terms(
  bindings : Array[AlphaBinding],
  effect : Effect,
) -> Array[Effect] {
  let terms : Array[Effect] = []
  collect_effect_terms(bindings, effect, terms)
  terms
}

///|
fn collect_effect_terms(
  bindings : Array[AlphaBinding],
  effect : Effect,
  terms : Array[Effect],
) -> Unit {
  match effect {
    Empty => ()
    Io => push_unique_effect_term(bindings, terms, Io)
    Singleton(id, arguments) => {
      let term = Singleton(
        id,
        arguments.map(fn(argument) { argument.normalize() }),
      )
      push_unique_effect_term(bindings, terms, term)
    }
    Parameter(_) => push_unique_effect_term(bindings, terms, effect)
    Union(effects) =>
      for nested in effects {
        collect_effect_terms(bindings, nested, terms)
      }
  }
}

///|
fn push_unique_effect_term(
  bindings : Array[AlphaBinding],
  terms : Array[Effect],
  term : Effect,
) -> Unit {
  if terms.any(fn(existing) {
      alpha_equal_effect_term_with(bindings, existing, term)
    }) {
    return
  }
  terms.push(term)
}

///|
fn alpha_equal_effect_term_with(
  bindings : Array[AlphaBinding],
  left : Effect,
  right : Effect,
) -> Bool {
  match (left, right) {
    (Io, Io) => true
    (Singleton(left_id, left_arguments), Singleton(right_id, right_arguments)) =>
      left_id == right_id &&
      same_length_generic_argument_alpha_equal(
        bindings, left_arguments, right_arguments,
      )
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(bindings, left, right)
    _ => false
  }
}

///|
fn alpha_equal_binders(
  bindings : Array[AlphaBinding],
  left_params : Array[TypeParameterId],
  right_params : Array[TypeParameterId],
  left_body : Type,
  right_body : Type,
) -> Bool {
  if left_params.length() != right_params.length() {
    return false
  }
  let next = bindings.copy()
  for index in 0..<left_params.length() {
    next.push({ left: left_params[index], right: right_params[index] })
  }
  alpha_equal_with(next, left_body, right_body)
}

///|
fn same_length_alpha_equal(
  bindings : Array[AlphaBinding],
  left : Array[Type],
  right : Array[Type],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !alpha_equal_with(bindings, left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn same_length_generic_argument_alpha_equal(
  bindings : Array[AlphaBinding],
  left : Array[GenericArgument],
  right : Array[GenericArgument],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !generic_argument_alpha_equal_with(bindings, left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn generic_argument_alpha_equal_with(
  bindings : Array[AlphaBinding],
  left : GenericArgument,
  right : GenericArgument,
) -> Bool {
  match (left, right) {
    (TypeArgument(left), TypeArgument(right)) =>
      alpha_equal_with(bindings, left, right)
    (EffectArgument(left), EffectArgument(right)) =>
      alpha_equal_effect_with(bindings, left, right)
    _ => false
  }
}

///|
fn alpha_equal_parameter(
  bindings : Array[AlphaBinding],
  left : TypeParameterId,
  right : TypeParameterId,
) -> Bool {
  for binding in bindings {
    if binding.left == left || binding.right == right {
      return binding.left == left && binding.right == right
    }
  }
  left == right
}

///|
pub struct TypeSubstitutionEntry {
  parameter : TypeParameterId
  replacement : GenericArgument
} derive(Debug, Eq)

///|
pub struct TypeSubstitution {
  entries : Array[TypeSubstitutionEntry]
} derive(Debug, Eq)

///|
pub fn TypeSubstitution::TypeSubstitution() -> TypeSubstitution {
  { entries: [] }
}

///|
pub fn TypeSubstitution::insert(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  replacement : Type,
) -> Unit {
  self.entries.push({ parameter, replacement: TypeArgument(replacement) })
}

///|
pub fn TypeSubstitution::insert_effect(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  replacement : Effect,
) -> Unit {
  self.entries.push({ parameter, replacement: EffectArgument(replacement) })
}

///|
pub fn TypeSubstitution::insert_argument(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  replacement : GenericArgument,
) -> Unit {
  self.entries.push({ parameter, replacement })
}

///|
fn TypeSubstitution::lookup_argument(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> GenericArgument? {
  if bound.contains(parameter) {
    return None
  }
  for entry in self.entries {
    if entry.parameter == parameter {
      return Some(entry.replacement)
    }
  }
  None
}

///|
fn TypeSubstitution::lookup_type(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> Type? {
  match self.lookup_argument(parameter, bound) {
    Some(TypeArgument(type_)) => Some(type_)
    _ => None
  }
}

///|
fn TypeSubstitution::lookup_effect(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> Effect? {
  match self.lookup_argument(parameter, bound) {
    Some(EffectArgument(effect)) => Some(effect)
    _ => None
  }
}

///|
pub fn GenericArgument::normalize(self : GenericArgument) -> GenericArgument {
  self.normalize_with_fuel(1024)
}

///|
fn GenericArgument::normalize_with_fuel(
  self : GenericArgument,
  fuel : Int,
) -> GenericArgument {
  match self {
    TypeArgument(type_) => TypeArgument(type_.normalize_with_fuel(fuel))
    EffectArgument(effect) => EffectArgument(effect.normalize_with_fuel(fuel))
  }
}

///|
fn GenericArgument::substitute_with_bound(
  self : GenericArgument,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> GenericArgument {
  match self {
    TypeArgument(type_) =>
      TypeArgument(type_.substitute_with_bound(substitution, bound))
    EffectArgument(effect) =>
      EffectArgument(effect.substitute_types_with_bound(substitution, bound))
  }
}

///|
fn Type::normalize(self : Type) -> Type {
  self.normalize_with_fuel(1024)
}

///|
fn Type::normalize_with_fuel(self : Type, fuel : Int) -> Type {
  if fuel <= 0 {
    abort("Buslane type normalization fuel exhausted")
  }
  match self {
    Primitive(_) | Parameter(_) | Constructor(_) => self
    Apply(callee, arguments) => {
      let normalized_callee = callee.normalize_with_fuel(fuel - 1)
      let normalized_arguments = arguments.map(fn(argument) {
        argument.normalize_with_fuel(fuel - 1)
      })
      match normalized_callee {
        TypeLambda(parameters, body) =>
          if parameters.length() != normalized_arguments.length() {
            Apply(normalized_callee, normalized_arguments)
          } else {
            let substitution = TypeSubstitution::TypeSubstitution()
            for index in 0..<parameters.length() {
              substitution.insert_argument(
                parameters[index],
                normalized_arguments[index],
              )
            }
            body.substitute(substitution).normalize_with_fuel(fuel - 1)
          }
        _ => Apply(normalized_callee, normalized_arguments)
      }
    }
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, body.normalize_with_fuel(fuel - 1))
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) { parameter.normalize_with_fuel(fuel - 1) }),
        result.normalize_with_fuel(fuel - 1),
        effect.normalize_with_fuel(fuel - 1),
      )
    Forall(parameters, body) =>
      Forall(parameters, body.normalize_with_fuel(fuel - 1))
  }
}

///|
fn Effect::normalize_with_fuel(self : Effect, fuel : Int) -> Effect {
  if fuel <= 0 {
    abort("Buslane effect normalization fuel exhausted")
  }
  match self {
    Empty | Io | Parameter(_) => self
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(fn(argument) { argument.normalize_with_fuel(fuel - 1) }),
      )
    Union(effects) =>
      Union(effects.map(fn(effect) { effect.normalize_with_fuel(fuel - 1) }))
  }
}

///|
pub fn Type::substitute(self : Type, substitution : TypeSubstitution) -> Type {
  self.substitute_with_bound(substitution, [])
}

///|
fn Type::substitute_with_bound(
  self : Type,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> Type {
  match self {
    Primitive(_) | Constructor(_) => self
    Parameter(parameter) =>
      match substitution.lookup_type(parameter, bound) {
        Some(replacement) => replacement
        None => self
      }
    Apply(callee, arguments) =>
      Apply(
        callee.substitute_with_bound(substitution, bound),
        arguments.map(fn(argument) {
          argument.substitute_with_bound(substitution, bound)
        }),
      )
    TypeLambda(parameters, body) => {
      let next_bound = bound.copy()
      for parameter in parameters {
        next_bound.push(parameter)
      }
      TypeLambda(
        parameters,
        body.substitute_with_bound(substitution, next_bound),
      )
    }
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) {
          parameter.substitute_with_bound(substitution, bound)
        }),
        result.substitute_with_bound(substitution, bound),
        effect.substitute_types_with_bound(substitution, bound),
      )
    Forall(parameters, body) => {
      let next_bound = bound.copy()
      for parameter in parameters {
        next_bound.push(parameter)
      }
      Forall(parameters, body.substitute_with_bound(substitution, next_bound))
    }
  }
}

///|
fn Effect::substitute_types_with_bound(
  self : Effect,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> Effect {
  match self {
    Empty | Io => self
    Parameter(parameter) =>
      match substitution.lookup_effect(parameter, bound) {
        Some(replacement) => replacement
        None => self
      }
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(fn(argument) {
          argument.substitute_with_bound(substitution, bound)
        }),
      )
    Union(effects) =>
      Union(
        effects.map(fn(effect) {
          effect.substitute_types_with_bound(substitution, bound)
        }),
      )
  }
}
