///|
pub(all) enum PrimitiveType {
  Int
  Bool
  String
  Unit
} derive(Debug, Eq)

///|
pub(all) enum Kind {
  Type
  Effect
  Function(Array[Kind], Kind)
} derive(Debug, Eq)

///|
pub(all) struct TypeParameter {
  id : TypeParameterId
  name : String
  kind : Kind
} derive(Debug, Eq)

///|
pub(all) enum Type {
  Error
  Primitive(PrimitiveType)
  Constructor(TypeSymbolId)
  Apply(Type, Array[Type])
  TypeLambda(Array[TypeParameter], Type)
  Parameter(TypeParameterId)
  Function(Array[Type], Type)
  Forall(Array[TypeParameter], Type)
} derive(Debug)

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
/// Creates an empty type substitution.
pub fn TypeSubstitution::TypeSubstitution() -> TypeSubstitution {
  { entries: [] }
}

///|
/// Creates a substitution containing one type-parameter replacement.
pub fn TypeSubstitution::single(
  parameter : TypeParameterId,
  replacement : Type,
) -> TypeSubstitution {
  { entries: [{ parameter, replacement }] }
}

///|
/// Adds or appends a type-parameter replacement to this substitution.
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
/// Applies a type substitution to this type.
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
    Error => self
    Primitive(_) => self
    Constructor(_) => self
    Apply(callee, arguments) =>
      Apply(
        callee.substitute_with_bound(substitution, bound),
        arguments.map(fn(argument) {
          argument.substitute_with_bound(substitution, bound)
        }),
      )
    TypeLambda(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter.id)
      }
      TypeLambda(
        type_parameters,
        body.substitute_with_bound(substitution, next_bound),
      )
    }
    Parameter(id) =>
      match substitution.lookup(id, bound) {
        Some(replacement) => replacement
        None => self
      }
    Function(parameters, result) =>
      Function(
        parameters.map(fn(parameter) {
          parameter.substitute_with_bound(substitution, bound)
        }),
        result.substitute_with_bound(substitution, bound),
      )
    Forall(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter.id)
      }
      Forall(
        type_parameters,
        body.substitute_with_bound(substitution, next_bound),
      )
    }
  }
}

///|
priv struct AlphaBinding {
  left : TypeParameterId
  right : TypeParameterId
}

///|
/// Returns whether two types are equal up to binder renaming.
pub fn Type::alpha_equal(self : Type, other : Type) -> Bool {
  alpha_equal_with([], self, other)
}

///|
/// Returns whether two types are equal under Lane2 type equality.
pub fn Type::equals(self : Type, other : Type) -> Bool {
  self.normalize().alpha_equal(other.normalize())
}

///|
pub impl Eq for Type with fn equal(self : Type, other : Type) -> Bool {
  self.alpha_equal(other)
}

///|
fn alpha_equal_with(
  bindings : Array[AlphaBinding],
  left : Type,
  right : Type,
) -> Bool {
  match (left, right) {
    (Error, Error) => true
    (Primitive(left), Primitive(right)) => left == right
    (Constructor(left_symbol), Constructor(right_symbol)) =>
      left_symbol == right_symbol
    (Apply(left_callee, left_args), Apply(right_callee, right_args)) =>
      alpha_equal_with(bindings, left_callee, right_callee) &&
      same_length_alpha_equal(bindings, left_args, right_args)
    (TypeLambda(left_params, left_body), TypeLambda(right_params, right_body)) =>
      alpha_equal_type_parameters(
        bindings, left_params, right_params, left_body, right_body,
      )
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(bindings, left, right)
    (Function(left_params, left_result), Function(right_params, right_result)) =>
      same_length_alpha_equal(bindings, left_params, right_params) &&
      alpha_equal_with(bindings, left_result, right_result)
    (Forall(left_params, left_body), Forall(right_params, right_body)) =>
      alpha_equal_type_parameters(
        bindings, left_params, right_params, left_body, right_body,
      )
    _ => false
  }
}

///|
fn alpha_equal_type_parameters(
  bindings : Array[AlphaBinding],
  left_params : Array[TypeParameter],
  right_params : Array[TypeParameter],
  left_body : Type,
  right_body : Type,
) -> Bool {
  if left_params.length() != right_params.length() {
    return false
  }
  let next_bindings = bindings.copy()
  let mut ok = true
  for index in 0..<left_params.length() {
    let left_param = left_params[index]
    let right_param = right_params[index]
    if left_param.kind != right_param.kind {
      ok = false
    }
    next_bindings.push({ left: left_param.id, right: right_param.id })
  }
  ok && alpha_equal_with(next_bindings, left_body, right_body)
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
pub fn Type::normalize(self : Type) -> Type {
  self.normalize_with_fuel(1024)
}

///|
fn Type::normalize_with_fuel(self : Type, fuel : Int) -> Type {
  if fuel <= 0 {
    abort("Lane type normalization fuel exhausted")
  }
  match self {
    Error | Primitive(_) | Constructor(_) | Parameter(_) => self
    Apply(callee, arguments) => {
      let normalized_callee = callee.normalize_with_fuel(fuel - 1)
      let normalized_arguments = arguments.map(fn(argument) {
        argument.normalize_with_fuel(fuel - 1)
      })
      match normalized_callee {
        TypeLambda(parameters, body) =>
          if parameters.length() == normalized_arguments.length() {
            let substitution = TypeSubstitution::TypeSubstitution()
            for index in 0..<parameters.length() {
              substitution.insert(
                parameters[index].id,
                normalized_arguments[index],
              )
            }
            body.substitute(substitution).normalize_with_fuel(fuel - 1)
          } else {
            Apply(normalized_callee, normalized_arguments)
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
pub fn nominal_type(symbol : TypeSymbolId, arguments : Array[Type]) -> Type {
  if arguments.is_empty() {
    Constructor(symbol)
  } else {
    Apply(Constructor(symbol), arguments)
  }
}

///|
pub fn Type::decompose_nominal(self : Type) -> (TypeSymbolId, Array[Type])? {
  match self.normalize() {
    Constructor(symbol) => Some((symbol, []))
    Apply(Constructor(symbol), arguments) => Some((symbol, arguments))
    _ => None
  }
}
