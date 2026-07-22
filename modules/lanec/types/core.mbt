///|
pub(all) enum PrimitiveType {
  Int
  Double
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
  Apply(Type, Array[GenericArgument])
  TypeLambda(Array[TypeParameter], Type)
  Parameter(TypeParameterId)
  Function(Array[Type], Type, Effect)
  Forall(Array[TypeParameter], Type)
} derive(Debug)

///|
pub(all) enum Effect {
  Empty
  Io
  Singleton(EffectSymbolId, Array[GenericArgument])
  Parameter(TypeParameterId)
  Union(Array[Effect])
} derive(Debug)

///|
pub(all) enum GenericArgument {
  TypeArgument(Type)
  EffectArgument(Effect)
} derive(Debug, Eq)

///|
pub(all) suberror TypeComputationError {
  TypeNormalizationFuelExhausted
  EffectNormalizationFuelExhausted
} derive(Debug, Eq)

///|
const NORMALIZATION_DEPTH_LIMIT : Int = 256

///|
pub fn TypeParameter::generic_argument(self : TypeParameter) -> GenericArgument {
  match self.kind {
    Effect => EffectArgument(Parameter(self.id))
    Type | Function(_) => TypeArgument(Parameter(self.id))
  }
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
  { entries: [{ parameter, replacement: TypeArgument(replacement) }] }
}

///|
/// Adds or appends a type-parameter replacement to this substitution.
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
      match substitution.lookup_type(id, bound) {
        Some(replacement) => replacement
        None => self
      }
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) {
          parameter.substitute_with_bound(substitution, bound)
        }),
        result.substitute_with_bound(substitution, bound),
        effect.substitute_with_bound(substitution, bound),
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
pub fn Effect::substitute(
  self : Effect,
  substitution : TypeSubstitution,
) -> Effect {
  self.substitute_with_bound(substitution, [])
}

///|
fn Effect::substitute_with_bound(
  self : Effect,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> Effect {
  match self {
    Empty | Io => self
    Singleton(symbol, arguments) =>
      Singleton(
        symbol,
        arguments.map(fn(argument) {
          argument.substitute_with_bound(substitution, bound)
        }),
      )
    Parameter(id) =>
      match substitution.lookup_effect(id, bound) {
        Some(replacement) => replacement
        None => self
      }
    Union(effects) =>
      Union(
        effects.map(fn(effect) {
          effect.substitute_with_bound(substitution, bound)
        }),
      )
  }
}

///|
pub fn GenericArgument::substitute(
  self : GenericArgument,
  substitution : TypeSubstitution,
) -> GenericArgument {
  self.substitute_with_bound(substitution, [])
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
      EffectArgument(effect.substitute_with_bound(substitution, bound))
  }
}

///|
pub fn GenericArgument::try_normalize(
  self : GenericArgument,
) -> GenericArgument raise TypeComputationError {
  self.normalize_with_fuel(NORMALIZATION_DEPTH_LIMIT)
}

///|
fn GenericArgument::normalize_with_fuel(
  self : GenericArgument,
  fuel : Int,
) -> GenericArgument raise TypeComputationError {
  match self {
    TypeArgument(type_) => TypeArgument(type_.normalize_with_fuel(fuel))
    EffectArgument(effect) => EffectArgument(effect.normalize_with_fuel(fuel))
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
///
/// Raises when type-level computation cannot be normalized within the compiler
/// fuel limit. Use `alpha_equal` when the inputs are already normalized or only
/// structural equality is required.
pub fn Type::equals(
  self : Type,
  other : Type,
) -> Bool raise TypeComputationError {
  self.try_normalize().alpha_equal(other.try_normalize())
}

///|
pub impl Eq for Type with fn equal(self : Type, other : Type) -> Bool {
  self.alpha_equal(other)
}

///|
/// Returns whether two effects are equal under Lane2 effect equality.
///
/// Raises when type-level computation in an effect argument cannot be normalized
/// within the compiler fuel limit. Use `alpha_equal` for structural effect-row
/// equality without type-level computation.
pub fn Effect::equals(
  self : Effect,
  other : Effect,
) -> Bool raise TypeComputationError {
  self.try_normalize().alpha_equal(other.try_normalize())
}

///|
/// Returns whether two effects are equal up to binder renaming.
pub fn Effect::alpha_equal(self : Effect, other : Effect) -> Bool {
  effect_alpha_equal_with([], self, other)
}

///|
/// Flattens unions and removes structurally alpha-equivalent duplicate terms.
/// This operation does not perform type-level computation in generic arguments.
pub fn Effect::canonicalize(self : Effect) -> Effect {
  match canonical_effect_terms([], self) {
    [] => Empty
    [term] => term
    terms => Union(terms)
  }
}

///|
pub impl Eq for Effect with fn equal(self : Effect, other : Effect) -> Bool {
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
      same_length_generic_argument_alpha_equal(bindings, left_args, right_args)
    (TypeLambda(left_params, left_body), TypeLambda(right_params, right_body)) =>
      alpha_equal_type_parameters(
        bindings, left_params, right_params, left_body, right_body,
      )
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(bindings, left, right)
    (
      Function(left_params, left_result, left_effect),
      Function(right_params, right_result, right_effect),
    ) =>
      same_length_alpha_equal(bindings, left_params, right_params) &&
      alpha_equal_with(bindings, left_result, right_result) &&
      effect_alpha_equal_with(bindings, left_effect, right_effect)
    (Forall(left_params, left_body), Forall(right_params, right_body)) =>
      alpha_equal_type_parameters(
        bindings, left_params, right_params, left_body, right_body,
      )
    _ => false
  }
}

///|
fn effect_alpha_equal_with(
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
        effect_term_alpha_equal_with(bindings, left_term, right_term)
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
    Singleton(_, _) => push_unique_effect_term(bindings, terms, effect)
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
      effect_term_alpha_equal_with(bindings, existing, term)
    }) {
    return
  }
  terms.push(term)
}

///|
fn effect_term_alpha_equal_with(
  bindings : Array[AlphaBinding],
  left : Effect,
  right : Effect,
) -> Bool {
  match (left, right) {
    (Empty, Empty) => true
    (Io, Io) => true
    (
      Singleton(left_symbol, left_arguments),
      Singleton(right_symbol, right_arguments),
    ) =>
      left_symbol == right_symbol &&
      same_length_generic_argument_alpha_equal(
        bindings, left_arguments, right_arguments,
      )
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(bindings, left, right)
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
      effect_alpha_equal_with(bindings, left, right)
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
pub fn Type::try_normalize(self : Type) -> Type raise TypeComputationError {
  self.normalize_with_fuel(NORMALIZATION_DEPTH_LIMIT)
}

///|
fn Type::normalize_with_fuel(
  self : Type,
  fuel : Int,
) -> Type raise TypeComputationError {
  if fuel <= 0 {
    raise TypeNormalizationFuelExhausted
  }
  match self {
    Error | Primitive(_) | Constructor(_) | Parameter(_) => self
    Apply(callee, arguments) => {
      let normalized_callee = callee.normalize_with_fuel(fuel - 1)
      let normalized_arguments = arguments.map(argument => {
        argument.normalize_with_fuel(fuel - 1)
      })
      match normalized_callee {
        TypeLambda(parameters, body) =>
          if parameters.length() == normalized_arguments.length() {
            let substitution = TypeSubstitution::TypeSubstitution()
            for index in 0..<parameters.length() {
              substitution.insert_argument(
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
    Function(parameters, result, effect) =>
      Function(
        parameters.map(parameter => parameter.normalize_with_fuel(fuel - 1)),
        result.normalize_with_fuel(fuel - 1),
        effect.normalize_with_fuel(fuel - 1),
      )
    Forall(parameters, body) =>
      Forall(parameters, body.normalize_with_fuel(fuel - 1))
  }
}

///|
pub fn Effect::try_normalize(
  self : Effect,
) -> Effect raise TypeComputationError {
  self.normalize_with_fuel(NORMALIZATION_DEPTH_LIMIT).canonicalize()
}

///|
fn Effect::normalize_with_fuel(
  self : Effect,
  fuel : Int,
) -> Effect raise TypeComputationError {
  if fuel <= 0 {
    raise EffectNormalizationFuelExhausted
  }
  match self {
    Empty | Io | Parameter(_) => self
    Singleton(symbol, arguments) =>
      Singleton(
        symbol,
        arguments.map(argument => argument.normalize_with_fuel(fuel - 1)),
      )
    Union(effects) =>
      Union(effects.map(effect => effect.normalize_with_fuel(fuel - 1)))
  }
}

///|
pub fn type_arguments(arguments : Array[Type]) -> Array[GenericArgument] {
  arguments.map(fn(argument) { TypeArgument(argument) })
}

///|
pub fn nominal_type(symbol : TypeSymbolId, arguments : Array[Type]) -> Type {
  nominal_type_generic(symbol, type_arguments(arguments))
}

///|
pub fn nominal_type_generic(
  symbol : TypeSymbolId,
  arguments : Array[GenericArgument],
) -> Type {
  if arguments.is_empty() {
    Constructor(symbol)
  } else {
    Apply(Constructor(symbol), arguments)
  }
}

///|
/// Decomposes an already-normalized nominal type without running type-level
/// computation.
pub fn Type::decompose_nominal(
  self : Type,
) -> (TypeSymbolId, Array[GenericArgument])? {
  match self {
    Constructor(symbol) => Some((symbol, []))
    Apply(Constructor(symbol), arguments) => Some((symbol, arguments))
    _ => None
  }
}
