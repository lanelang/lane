///|
pub(all) struct TypeId {
  index : Int
} derive(Debug, Eq, Compare, FromJson, ToJson)

///|
pub(all) struct TypeParameterId {
  index : Int
} derive(Debug, Eq, Compare, FromJson, ToJson)

///|
pub(all) struct ValueId {
  index : Int
} derive(Debug, Eq, Compare, FromJson, ToJson)

///|
pub(all) struct DataConId {
  index : Int
} derive(Debug, Eq, Compare, FromJson, ToJson)

///|
pub(all) enum Kind {
  Type
  Function(Array[Kind], Kind)
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum PrimitiveType {
  Unit
  Bool
  Int
  String
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum Type {
  Primitive(PrimitiveType)
  Parameter(TypeParameterId)
  Constructor(TypeId)
  Apply(Type, Array[Type])
  TypeLambda(Array[TypeParameterId], Type)
  Function(Array[Type], Type)
  Forall(Array[TypeParameterId], Type)
} derive(Debug, FromJson, ToJson)

///|
pub(all) enum Literal {
  Unit
  Bool(Bool)
  Int(Int64)
  String(String)
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum ValueKind {
  Function
  Value
  External
  Parameter
  Local
  MatchBinder
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct TypeInfo {
  parameters : Array[TypeParameterId]
  constructors : Array[DataConId]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct TypeParameterInfo {
  kind : Kind
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct ValueInfo {
  kind : ValueKind
  type_ : Type
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct DataConInfo {
  owner : TypeId
  hidden_type_parameters : Array[TypeParameterId]
  payload_types : Array[Type]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub struct MetadataRegistry {
  types : Array[TypeInfo]
  type_parameters : Array[TypeParameterInfo]
  values : Array[ValueInfo]
  data_constructors : Array[DataConInfo]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct Program {
  metadata : MetadataRegistry
  terms : Array[TopTerm]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum TopTerm {
  Let(ValueId, Expr)
  LetRec(Array[RecursiveBinding])
  External(ValueId)
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct RecursiveBinding {
  id : ValueId
  rhs : Expr
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct FunctionExpr {
  parameters : Array[ValueId]
  result_type : Type
  body : Expr
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct ConstructExpr {
  data_constructor : DataConId
  type_arguments : Array[Type]
  hidden_witnesses : Array[Type]
  payloads : Array[Expr]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct MatchExpr {
  scrutinee : Expr
  binder : ValueId
  result_type : Type
  alternatives : Array[Alternative]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct Alternative {
  alt_constructor : AltCon
  type_binders : Array[TypeParameterId]
  value_binders : Array[ValueId]
  body : Expr
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum AltCon {
  Default
  Literal(Literal)
  DataCon(DataConId)
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum Expr {
  Ref(ValueId)
  Literal(Literal)
  Function(FunctionExpr)
  Call(Expr, Array[Expr])
  TypeLambda(Array[TypeParameterId], Expr)
  TypeApply(Expr, Array[Type])
  Construct(ConstructExpr)
  Let(ValueId, Expr, Expr)
  LetRec(Array[RecursiveBinding], Expr)
  Match(MatchExpr)
} derive(Debug, Eq, FromJson, ToJson)

///|
/// Creates an empty Buslane metadata registry.
pub fn MetadataRegistry::MetadataRegistry() -> MetadataRegistry {
  { types: [], type_parameters: [], values: [], data_constructors: [] }
}

///|
/// Defines a Buslane type parameter and returns its identity.
pub fn MetadataRegistry::define_type_parameter(
  self : MetadataRegistry,
  kind : Kind,
) -> TypeParameterId {
  let id = TypeParameterId::{ index: self.type_parameters.length() }
  self.type_parameters.push({ kind, })
  id
}

///|
/// Defines a Buslane nominal type and returns its identity.
pub fn MetadataRegistry::define_type(
  self : MetadataRegistry,
  parameters : Array[TypeParameterId],
) -> TypeId {
  let id = TypeId::{ index: self.types.length() }
  self.types.push({ parameters, constructors: [] })
  id
}

///|
/// Defines a Buslane data constructor and attaches it to its owner type.
pub fn MetadataRegistry::define_data_constructor(
  self : MetadataRegistry,
  owner : TypeId,
  hidden_type_parameters : Array[TypeParameterId],
  payload_types : Array[Type],
) -> DataConId {
  let id = DataConId::{ index: self.data_constructors.length() }
  self.data_constructors.push({ owner, hidden_type_parameters, payload_types })
  guard self.types.get(owner.index) is Some(info) else { return id }
  info.constructors.push(id)
  id
}

///|
/// Defines a Buslane value and returns its identity.
pub fn MetadataRegistry::define_value(
  self : MetadataRegistry,
  kind : ValueKind,
  type_ : Type,
) -> ValueId {
  let id = ValueId::{ index: self.values.length() }
  self.values.push({ kind, type_ })
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
/// Returns whether two Buslane types are definitionally equal.
pub fn Type::equals(self : Type, other : Type) -> Bool {
  alpha_equal_with([], self.normalize(), other.normalize())
}

///|
pub impl Eq for Type with fn equal(self : Type, other : Type) -> Bool {
  self.equals(other)
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
      same_length_alpha_equal(bindings, left_args, right_args)
    (TypeLambda(left_params, left_body), TypeLambda(right_params, right_body)) =>
      alpha_equal_binders(
        bindings, left_params, right_params, left_body, right_body,
      )
    (Function(left_params, left_result), Function(right_params, right_result)) =>
      same_length_alpha_equal(bindings, left_params, right_params) &&
      alpha_equal_with(bindings, left_result, right_result)
    (Forall(left_params, left_body), Forall(right_params, right_body)) =>
      alpha_equal_binders(
        bindings, left_params, right_params, left_body, right_body,
      )
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
  replacement : Type
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
  self.entries.push({ parameter, replacement })
}

///|
fn TypeSubstitution::lookup(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> Type? {
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
              substitution.insert(
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
    Function(parameters, result) =>
      Function(
        parameters.map(fn(parameter) { parameter.normalize_with_fuel(fuel - 1) }),
        result.normalize_with_fuel(fuel - 1),
      )
    Forall(parameters, body) =>
      Forall(parameters, body.normalize_with_fuel(fuel - 1))
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
      match substitution.lookup(parameter, bound) {
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
    Function(parameters, result) =>
      Function(
        parameters.map(fn(parameter) {
          parameter.substitute_with_bound(substitution, bound)
        }),
        result.substitute_with_bound(substitution, bound),
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
