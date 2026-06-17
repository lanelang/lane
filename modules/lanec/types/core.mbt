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
  Arrow(Kind, Kind)
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
  Nominal(TypeSymbolId, Array[Type])
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
    Nominal(symbol, arguments) =>
      Nominal(
        symbol,
        arguments.map(fn(argument) {
          argument.substitute_with_bound(substitution, bound)
        }),
      )
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
/// Returns whether two types are equal up to forall-bound parameter renaming.
pub fn Type::alpha_equal(self : Type, other : Type) -> Bool {
  alpha_equal_with([], self, other)
}

///|
/// Returns whether two types are equal under Lane2 type equality.
pub fn Type::equals(self : Type, other : Type) -> Bool {
  self.alpha_equal(other)
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
    (Nominal(left_symbol, left_args), Nominal(right_symbol, right_args)) =>
      left_symbol == right_symbol &&
      same_length_alpha_equal(bindings, left_args, right_args)
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(bindings, left, right)
    (Function(left_params, left_result), Function(right_params, right_result)) =>
      same_length_alpha_equal(bindings, left_params, right_params) &&
      alpha_equal_with(bindings, left_result, right_result)
    (Forall(left_params, left_body), Forall(right_params, right_body)) =>
      if left_params.length() != right_params.length() {
        false
      } else {
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
    _ => false
  }
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
