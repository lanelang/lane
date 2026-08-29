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
/// A nonnegative program-wide Buslane name identity.
///
/// Construction is checked so text, binary, and programmatic producers share
/// the same numeric domain.
pub struct BuslaneUnique {
  value : Int
} derive(Debug, Eq, Hash, Compare)

///|
fn BuslaneUnique::is_valid(self : BuslaneUnique) -> Bool {
  self.value >= 0
}

///|
fn BuslaneUnique::successor(self : BuslaneUnique) -> BuslaneUnique? {
  if self.value == 0x7FFFFFFF {
    None
  } else {
    Some({ value: self.value + 1, })
  }
}

///|
/// Constructs a Buslane unique when the value belongs to its legal domain.
pub fn BuslaneUnique::from_int(value : Int) -> BuslaneUnique? {
  let unique = BuslaneUnique::{ value, }
  if unique.is_valid() {
    Some(unique)
  } else {
    None
  }
}

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
pub(all) enum BuiltinEffect {
  Io
  Panic
} derive(Debug, Eq)

///|
pub(all) enum PrimitiveType {
  Unit
  Bool
  I64
  I32
  Char
  F64
  F32
  String
  Byte
  Bytes
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
} derive(Debug, Eq)

///|
pub(all) enum Effect {
  Empty
  Builtin(BuiltinEffect)
  Singleton(EffectId, Array[GenericArgument])
  Parameter(TypeParameterId)
  Union(Array[Effect])
} derive(Debug, Eq)

///|
pub(all) enum GenericArgument {
  TypeArgument(Type)
  EffectArgument(Effect)
} derive(Debug, Eq)

///|
pub(all) enum Literal {
  Unit
  Bool(Bool)
  I64(Int64)
  I32(Int)
  Char(Int)
  F64(Double)
  F32(Float)
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
/// An `Effect`-kind parameter carries the same flavor an effect declaration
/// does, saying what the rows it ranges over may contain. `Algebraic` admits
/// any row; `External` admits only residual ones, so a consumer that must
/// eliminate algebraic effects can tell the two apart. The field is inert for
/// parameters of other kinds.
pub(all) struct TypeParameterInfo {
  name : BuslaneName
  kind : Kind
  flavor : EffectFlavor
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
/// The state of the program-wide Buslane name allocator.
pub(all) enum MetadataNameAllocator {
  Fresh(BuslaneUnique)
  Exhausted
} derive(Debug, Eq)

///|
pub(all) struct MetadataRegistry {
  mut name_allocator : MetadataNameAllocator
  types : Array[TypeInfo]
  type_parameters : Array[TypeParameterInfo]
  values : Array[ValueInfo]
  data_constructors : Array[DataConInfo]
  effects : Array[EffectInfo]
  operations : Array[OperationInfo]
} derive(Debug, Eq)

///|
pub(all) enum MetadataIdentityError {
  NegativeUnique(BuslaneUnique)
  DuplicateUnique(BuslaneUnique)
  NegativeNextUnique(BuslaneUnique)
  NextUniqueNotFresh(next~ : BuslaneUnique, maximum~ : BuslaneUnique)
  AllocatorExhaustedBeforeMaximum(maximum_unique~ : BuslaneUnique?)
} derive(Debug, Eq)

///|
/// A Buslane metadata identity could not be allocated.
pub suberror MetadataAllocationError {
  MetadataNameExhausted
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
    name_allocator: Fresh({ value: 0, }),
    types: [],
    type_parameters: [],
    values: [],
    data_constructors: [],
    effects: [],
    operations: [],
  }
}

///|
/// Returns a recursively independent metadata snapshot.
pub fn MetadataRegistry::snapshot(self : MetadataRegistry) -> MetadataRegistry {
  {
    name_allocator: self.name_allocator,
    types: self.types.map(info => info.snapshot()),
    type_parameters: self.type_parameters.map(info => info.snapshot()),
    values: self.values.map(info => info.snapshot()),
    data_constructors: self.data_constructors.map(info => info.snapshot()),
    effects: self.effects.map(info => info.snapshot()),
    operations: self.operations.map(info => info.snapshot()),
  }
}

///|
/// Returns violations of the registry's program-wide name allocation
/// invariant.
pub fn MetadataRegistry::identity_errors(
  self : MetadataRegistry,
) -> Array[MetadataIdentityError] {
  let seen : @hashset.HashSet[BuslaneUnique] = HashSet([])
  let errors = []
  let mut maximum_unique : BuslaneUnique? = None
  let inspect_name = fn(name : BuslaneName) {
    if !name.unique.is_valid() {
      errors.push(NegativeUnique(name.unique))
    }
    if !seen.add_and_check(name.unique) {
      errors.push(DuplicateUnique(name.unique))
    }
    maximum_unique = match maximum_unique {
      None => Some(name.unique)
      Some(maximum) =>
        if name.unique.compare(maximum) > 0 {
          Some(name.unique)
        } else {
          Some(maximum)
        }
    }
  }
  for info in self.types {
    inspect_name(info.name)
  }
  for info in self.type_parameters {
    inspect_name(info.name)
  }
  for info in self.values {
    inspect_name(info.name)
  }
  for info in self.data_constructors {
    inspect_name(info.name)
  }
  for info in self.effects {
    inspect_name(info.name)
  }
  for info in self.operations {
    inspect_name(info.name)
  }
  match self.name_allocator {
    Fresh(next) =>
      if !next.is_valid() {
        errors.push(NegativeNextUnique(next))
      } else if maximum_unique is Some(maximum) && next.compare(maximum) <= 0 {
        errors.push(NextUniqueNotFresh(next~, maximum~))
      }
    Exhausted =>
      if maximum_unique
        .map(maximum => maximum.successor() is Some(_))
        .unwrap_or(true) {
        errors.push(AllocatorExhaustedBeforeMaximum(maximum_unique~))
      }
  }
  errors
}

///|
fn MetadataRegistry::fresh_name(
  self : MetadataRegistry,
  name_space : NameNamespace,
  occurrence : String,
) -> BuslaneName raise MetadataAllocationError {
  let unique = match self.name_allocator {
    Fresh(unique) => unique
    Exhausted => raise MetadataNameExhausted
  }
  self.name_allocator = match unique.successor() {
    Some(next) => Fresh(next)
    None => Exhausted
  }
  { name_space, occurrence, unique, }
}

///|
/// Defines a Buslane type parameter and returns its identity.
pub fn MetadataRegistry::define_type_parameter(
  self : MetadataRegistry,
  occurrence : String,
  kind : Kind,
  flavor? : EffectFlavor = Algebraic,
) -> TypeParameterId raise MetadataAllocationError {
  let id = TypeParameterId::{ index: self.type_parameters.length(), }
  self.type_parameters.push({
    name: self.fresh_name(TypeParameterName, occurrence),
    kind,
    flavor,
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
) -> TypeId raise MetadataAllocationError {
  let id = TypeId::{ index: self.types.length(), }
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
) -> DataConId raise MetadataAllocationError {
  let id = DataConId::{ index: self.data_constructors.length(), }
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
) -> EffectId raise MetadataAllocationError {
  let id = EffectId::{ index: self.effects.length(), }
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
) -> OperationId raise MetadataAllocationError {
  let id = OperationId::{ index: self.operations.length(), }
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
) -> ValueId raise MetadataAllocationError {
  let id = ValueId::{ index: self.values.length(), }
  self.values.push({
    name: self.fresh_name(ValueName, occurrence),
    kind,
    type_,
  })
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
fn MetadataRegistry::definitional_equality_context(
  self : MetadataRegistry,
) -> AlphaContext {
  {
    bindings: [],
    binders_compatible: fn(left, right) {
      guard self.type_parameter_info(left) is Some(left_info) else {
        return false
      }
      guard self.type_parameter_info(right) is Some(right_info) else {
        return false
      }
      // Effect-kind binders must also agree on flavor: an External row
      // variable ranges over fewer rows than an Algebraic one, so pairing
      // them would launder the flavor through an equality-gated position.
      left_info.kind == right_info.kind &&
      (left_info.kind != Effect || left_info.flavor == right_info.flavor)
    },
  }
}

///|
/// Returns whether two Buslane types are definitionally equal.
///
/// Raises `TypeNormalizationError` when either type cannot be normalized within
/// the bounded beta-reduction safeguard.
pub fn MetadataRegistry::types_definitionally_equal(
  self : MetadataRegistry,
  left : Type,
  right : Type,
) -> Bool raise TypeNormalizationError {
  alpha_equal_with(
    self.definitional_equality_context(),
    left.normalize(),
    right.normalize(),
  )
}

///|
/// Returns whether an effect term denotes a handleable effect.
///
/// Algebraic terms are the ones a consumer may still have to eliminate; `Io`,
/// External Effects, and row variables that range only over them are already
/// residual. An unknown identity is treated as algebraic, since assuming less
/// would let an unresolved reference pass a check it should not.
pub fn MetadataRegistry::effect_term_is_algebraic(
  self : MetadataRegistry,
  term : Effect,
) -> Bool {
  match term {
    Empty | Builtin(_) => false
    Singleton(effect, _) =>
      self
      .effect_info(effect)
      .map_or(true, fn(info) { info.flavor is Algebraic })
    Parameter(parameter) =>
      self
      .type_parameter_info(parameter)
      .map_or(true, fn(info) { info.flavor is Algebraic })
    Union(terms) => terms.any(fn(term) { self.effect_term_is_algebraic(term) })
  }
}

///|
/// Returns whether a value of type `actual` may be consumed where `expected` is
/// required.
///
/// Unlike definitional equality this is directed, because a consumer that
/// allows for a latent effect is not harmed by a value that performs less. It
/// widens only by residual terms: an Algebraic Effect changes how a callable is
/// lowered, so relabelling a callable to claim one would be a different value,
/// not the same one seen through a weaker type. Parameters are contravariant,
/// so the direction flips under them, and type arguments stay invariant since a
/// constructor's variance in its own parameters is not knowable here.
///
/// Definitional equality remains the relation for deciding whether two types
/// denote the same thing; this one decides whether a value fits a position.
/// Raises `TypeNormalizationError` when either type cannot be normalized.
pub fn MetadataRegistry::type_is_consumable_as(
  self : MetadataRegistry,
  actual : Type,
  expected : Type,
) -> Bool raise TypeNormalizationError {
  self.consumable_with(
    self.definitional_equality_context(),
    actual.normalize(),
    expected.normalize(),
  )
}

///|
fn MetadataRegistry::consumable_with(
  self : MetadataRegistry,
  context : AlphaContext,
  actual : Type,
  expected : Type,
) -> Bool {
  match (actual, expected) {
    (
      Function(actual_parameters, actual_result, actual_effect),
      Function(expected_parameters, expected_result, expected_effect),
    ) => {
      if actual_parameters.length() != expected_parameters.length() {
        return false
      }
      for index in 0..<actual_parameters.length() {
        // Contravariant: the value is handed arguments the consumer chooses, so
        // it must accept everything the consumer may pass.
        if !self.consumable_with(
            context.flip(),
            expected_parameters[index],
            actual_parameters[index],
          ) {
          return false
        }
      }
      self.consumable_with(context, actual_result, expected_result) &&
      self.effect_is_consumable_with(context, actual_effect, expected_effect)
    }
    (
      Forall(actual_parameters, actual_body),
      Forall(expected_parameters, expected_body),
    ) =>
      match context.with_binders(actual_parameters, expected_parameters) {
        Some(next) => self.consumable_with(next, actual_body, expected_body)
        None => false
      }
    (
      TypeLambda(actual_parameters, actual_body),
      TypeLambda(expected_parameters, expected_body),
    ) =>
      match context.with_binders(actual_parameters, expected_parameters) {
        Some(next) => self.consumable_with(next, actual_body, expected_body)
        None => false
      }
    _ => alpha_equal_with(context, actual, expected)
  }
}

///|
fn MetadataRegistry::effect_is_consumable_with(
  self : MetadataRegistry,
  context : AlphaContext,
  actual : Effect,
  expected : Effect,
) -> Bool {
  let actual_terms = canonical_effect_terms(context, actual)
  let expected_terms = canonical_effect_terms(context, expected)
  for actual_term in actual_terms {
    if !expected_terms.any(fn(expected_term) {
        alpha_equal_effect_term_with(context, actual_term, expected_term)
      }) {
      return false
    }
  }
  for expected_term in expected_terms {
    if self.effect_term_is_algebraic(expected_term) &&
      !actual_terms.any(fn(actual_term) {
        alpha_equal_effect_term_with(context, actual_term, expected_term)
      }) {
      return false
    }
  }
  true
}

///|
/// Returns whether two Buslane effects are definitionally equal.
/// Raises `TypeNormalizationError` when a generic argument cannot be normalized.
pub fn MetadataRegistry::effects_definitionally_equal(
  self : MetadataRegistry,
  left : Effect,
  right : Effect,
) -> Bool raise TypeNormalizationError {
  alpha_equal_effect_with(
    self.definitional_equality_context(),
    left.normalize(),
    right.normalize(),
  )
}

///|
/// Returns whether every effect term in `lower` occurs in `upper`.
///
/// This is plain effect-set inclusion, so both algebraic and residual terms may
/// widen. Use it where an owning declaration admits an implementation effect;
/// callable value compatibility instead belongs to `type_is_consumable_as`,
/// whose ABI rule forbids adding algebraic effects.
/// Raises `TypeNormalizationError` when a generic argument cannot be normalized.
pub fn MetadataRegistry::effect_is_subeffect_of(
  self : MetadataRegistry,
  lower : Effect,
  upper : Effect,
) -> Bool raise TypeNormalizationError {
  effect_is_subeffect_with(
    self.definitional_equality_context(),
    lower.normalize(),
    upper.normalize(),
  )
}

///|
/// Returns the canonical effect shape under metadata-aware alpha equivalence.
/// Raises `TypeNormalizationError` when a generic argument cannot be normalized.
pub fn MetadataRegistry::canonicalize_effect(
  self : MetadataRegistry,
  effect : Effect,
) -> Effect raise TypeNormalizationError {
  canonicalize_effect_with(
    self.definitional_equality_context(),
    effect.normalize(),
  )
}

///|
fn effect_is_subeffect_with(
  context : AlphaContext,
  lower : Effect,
  upper : Effect,
) -> Bool {
  let lower_terms = canonical_effect_terms(context, lower)
  let upper_terms = canonical_effect_terms(context, upper)
  lower_terms.all(fn(lower_term) {
    upper_terms.any(fn(upper_term) {
      alpha_equal_effect_term_with(context, lower_term, upper_term)
    })
  })
}

///|
fn canonicalize_effect_with(context : AlphaContext, effect : Effect) -> Effect {
  let terms = canonical_effect_terms(context, effect)
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
priv struct AlphaContext {
  bindings : Array[AlphaBinding]
  binders_compatible : (TypeParameterId, TypeParameterId) -> Bool
}

///|
/// Swaps the sides of every recorded binding.
///
/// Alpha bindings are oriented, so a relation that recurses with its arguments
/// exchanged — as contravariance requires — has to exchange the context with
/// them, or a renamed binder stops matching its counterpart.
fn AlphaContext::flip(self : AlphaContext) -> AlphaContext {
  {
    ..self,
    bindings: self.bindings.map(fn(binding) {
      { left: binding.right, right: binding.left, }
    }),
  }
}

///|
/// Views the context from one side alone: the cross-side bindings are dropped
/// while binder compatibility stays.
///
/// Whether two terms of a single row are the same term is a question about
/// that row only; letting the oriented cross-side bindings participate makes a
/// term unequal to itself and the resulting equality intransitive.
fn AlphaContext::same_side(self : AlphaContext) -> AlphaContext {
  { ..self, bindings: [], }
}

///|
fn AlphaContext::with_binders(
  self : AlphaContext,
  left : Array[TypeParameterId],
  right : Array[TypeParameterId],
) -> AlphaContext? {
  if left.length() != right.length() {
    return None
  }
  let next = self.bindings.copy()
  for index in 0..<left.length() {
    if !(self.binders_compatible)(left[index], right[index]) {
      return None
    }
    next.push({ left: left[index], right: right[index], })
  }
  Some({ ..self, bindings: next, })
}

///|
fn alpha_equal_with(context : AlphaContext, left : Type, right : Type) -> Bool {
  match (left, right) {
    (Primitive(left), Primitive(right)) => left == right
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(context.bindings, left, right)
    (Constructor(left_id), Constructor(right_id)) => left_id == right_id
    (Apply(left_callee, left_args), Apply(right_callee, right_args)) =>
      alpha_equal_with(context, left_callee, right_callee) &&
      same_length_generic_argument_alpha_equal(context, left_args, right_args)
    (TypeLambda(left_params, left_body), TypeLambda(right_params, right_body)) =>
      alpha_equal_binders(
        context, left_params, right_params, left_body, right_body,
      )
    (
      Function(left_params, left_result, left_effect),
      Function(right_params, right_result, right_effect),
    ) =>
      same_length_alpha_equal(context, left_params, right_params) &&
      alpha_equal_with(context, left_result, right_result) &&
      alpha_equal_effect_with(context, left_effect, right_effect)
    (Forall(left_params, left_body), Forall(right_params, right_body)) =>
      alpha_equal_binders(
        context, left_params, right_params, left_body, right_body,
      )
    _ => false
  }
}

///|
fn alpha_equal_effect_with(
  context : AlphaContext,
  left : Effect,
  right : Effect,
) -> Bool {
  let left_terms = canonical_effect_terms(context, left)
  let right_terms = canonical_effect_terms(context, right)
  if left_terms.length() != right_terms.length() {
    return false
  }
  for left_term in left_terms {
    if !right_terms.any(fn(right_term) {
        alpha_equal_effect_term_with(context, left_term, right_term)
      }) {
      return false
    }
  }
  true
}

///|
fn canonical_effect_terms(
  context : AlphaContext,
  effect : Effect,
) -> Array[Effect] {
  let terms : Array[Effect] = []
  collect_effect_terms(context.same_side(), effect, terms)
  terms
}

///|
fn collect_effect_terms(
  context : AlphaContext,
  effect : Effect,
  terms : Array[Effect],
) -> Unit {
  match effect {
    Empty => ()
    Builtin(_) => push_unique_effect_term(context, terms, effect)
    Singleton(id, arguments) =>
      push_unique_effect_term(context, terms, Singleton(id, arguments))
    Parameter(_) => push_unique_effect_term(context, terms, effect)
    Union(effects) =>
      for nested in effects {
        collect_effect_terms(context, nested, terms)
      }
  }
}

///|
fn push_unique_effect_term(
  context : AlphaContext,
  terms : Array[Effect],
  term : Effect,
) -> Unit {
  if terms.any(fn(existing) {
      alpha_equal_effect_term_with(context, existing, term)
    }) {
    return
  }
  terms.push(term)
}

///|
fn alpha_equal_effect_term_with(
  context : AlphaContext,
  left : Effect,
  right : Effect,
) -> Bool {
  match (left, right) {
    (Builtin(left), Builtin(right)) => left == right
    (Singleton(left_id, left_arguments), Singleton(right_id, right_arguments)) =>
      left_id == right_id &&
      same_length_generic_argument_alpha_equal(
        context, left_arguments, right_arguments,
      )
    (Parameter(left), Parameter(right)) =>
      alpha_equal_parameter(context.bindings, left, right)
    _ => false
  }
}

///|
fn alpha_equal_binders(
  context : AlphaContext,
  left_params : Array[TypeParameterId],
  right_params : Array[TypeParameterId],
  left_body : Type,
  right_body : Type,
) -> Bool {
  match context.with_binders(left_params, right_params) {
    Some(next) => alpha_equal_with(next, left_body, right_body)
    None => false
  }
}

///|
fn same_length_alpha_equal(
  context : AlphaContext,
  left : Array[Type],
  right : Array[Type],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !alpha_equal_with(context, left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn same_length_generic_argument_alpha_equal(
  context : AlphaContext,
  left : Array[GenericArgument],
  right : Array[GenericArgument],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !generic_argument_alpha_equal_with(context, left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn generic_argument_alpha_equal_with(
  context : AlphaContext,
  left : GenericArgument,
  right : GenericArgument,
) -> Bool {
  match (left, right) {
    (TypeArgument(left), TypeArgument(right)) =>
      alpha_equal_with(context, left, right)
    (EffectArgument(left), EffectArgument(right)) =>
      alpha_equal_effect_with(context, left, right)
    _ => false
  }
}

///|
/// Resolves a parameter pair against the innermost binding that mentions
/// either id. A rebound id belongs to its nearest enclosing binder — the same
/// reading substitution's bound-list enforces — so the scan runs inside-out.
fn alpha_equal_parameter(
  bindings : Array[AlphaBinding],
  left : TypeParameterId,
  right : TypeParameterId,
) -> Bool {
  for binding in bindings.rev_iter() {
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
pub(all) suberror TypeSubstitutionError {
  ArgumentCountMismatch(expected~ : Int, actual~ : Int)
  MissingParameterMetadata(parameter~ : TypeParameterId)
  ExpectedTypeArgument(parameter~ : TypeParameterId)
  ExpectedEffectArgument(parameter~ : TypeParameterId)
  CapturedTypeParameter(parameter~ : TypeParameterId, binder~ : TypeParameterId)
} derive(Debug, Eq)

///|
/// Controlled failures while computing a Buslane type's beta-normal form.
pub(all) suberror TypeNormalizationError {
  BetaReductionLimitExceeded(limit~ : Int)
  InvalidBetaSubstitution(TypeSubstitutionError)
} derive(Debug, Eq)

///|
const TYPE_NORMALIZATION_BETA_LIMIT : Int = 1024

///|
priv struct TypeNormalizationBudget {
  mut remaining : Int
}

///|
fn TypeNormalizationBudget::consume_beta(
  self : TypeNormalizationBudget,
) -> Unit raise TypeNormalizationError {
  if self.remaining <= 0 {
    raise BetaReductionLimitExceeded(limit=TYPE_NORMALIZATION_BETA_LIMIT)
  }
  self.remaining -= 1
}

///|
pub fn TypeSubstitution::TypeSubstitution() -> TypeSubstitution {
  { entries: [], }
}

///|
pub fn TypeSubstitution::from_arguments(
  metadata : MetadataRegistry,
  parameters : Array[TypeParameterId],
  arguments : Array[GenericArgument],
) -> TypeSubstitution raise TypeSubstitutionError {
  if parameters.length() != arguments.length() {
    raise ArgumentCountMismatch(
      expected=parameters.length(),
      actual=arguments.length(),
    )
  }
  let substitution = TypeSubstitution::TypeSubstitution()
  for index, parameter in parameters {
    let kind = match metadata.type_parameter_info(parameter) {
      Some(info) => info.kind
      None => raise MissingParameterMetadata(parameter~)
    }
    let argument = arguments[index]
    match (kind, argument) {
      (Effect, EffectArgument(_)) | (Type | Function(_), TypeArgument(_)) =>
        substitution.insert_argument(parameter, argument)
      (Effect, TypeArgument(_)) => raise ExpectedEffectArgument(parameter~)
      (Type | Function(_), EffectArgument(_)) =>
        raise ExpectedTypeArgument(parameter~)
    }
  }
  substitution
}

///|
pub fn TypeSubstitution::insert(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  replacement : Type,
) -> Unit {
  self.entries.push({ parameter, replacement: TypeArgument(replacement), })
}

///|
pub fn TypeSubstitution::insert_effect(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  replacement : Effect,
) -> Unit {
  self.entries.push({ parameter, replacement: EffectArgument(replacement), })
}

///|
pub fn TypeSubstitution::insert_argument(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  replacement : GenericArgument,
) -> Unit {
  self.entries.push({ parameter, replacement, })
}

///|
pub fn TypeSubstitution::overlay(
  self : TypeSubstitution,
  shadowing : TypeSubstitution,
) -> TypeSubstitution {
  let entries = shadowing.entries.copy()
  entries.append(self.entries)
  { entries, }
}

///|
pub fn TypeSubstitution::type_argument(
  self : TypeSubstitution,
  parameter : TypeParameterId,
) -> Type? raise TypeSubstitutionError {
  self.lookup_type(parameter, [])
}

///|
pub fn TypeSubstitution::effect_argument(
  self : TypeSubstitution,
  parameter : TypeParameterId,
) -> Effect? raise TypeSubstitutionError {
  self.lookup_effect(parameter, [])
}

///|
/// Returns the replacement for a parameter occurrence, refusing to capture:
/// substitution never places a replacement's free parameter under a binder of
/// the same id. This is the binder-freshness law, enforced at the one point
/// every substitution in the system flows through.
fn TypeSubstitution::lookup_argument(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> GenericArgument? raise TypeSubstitutionError {
  if bound.contains(parameter) {
    return None
  }
  for entry in self.entries {
    if entry.parameter == parameter {
      for binder in bound {
        if entry.replacement.mentions_free(binder) {
          raise CapturedTypeParameter(parameter~, binder~)
        }
      }
      return Some(entry.replacement)
    }
  }
  None
}

///|
fn GenericArgument::mentions_free(
  self : GenericArgument,
  id : TypeParameterId,
) -> Bool {
  match self {
    TypeArgument(type_) => type_.mentions_free(id)
    EffectArgument(effect) => effect.mentions_free(id)
  }
}

///|
fn Type::mentions_free(self : Type, id : TypeParameterId) -> Bool {
  match self {
    Primitive(_) | Constructor(_) => false
    Parameter(parameter) => parameter == id
    Apply(callee, arguments) =>
      callee.mentions_free(id) ||
      arguments.any(argument => argument.mentions_free(id))
    TypeLambda(parameters, body) | Forall(parameters, body) =>
      !parameters.contains(id) && body.mentions_free(id)
    Function(parameters, result, effect) =>
      parameters.any(parameter => parameter.mentions_free(id)) ||
      result.mentions_free(id) ||
      effect.mentions_free(id)
  }
}

///|
fn Effect::mentions_free(self : Effect, id : TypeParameterId) -> Bool {
  match self {
    Empty | Builtin(_) => false
    Parameter(parameter) => parameter == id
    Singleton(_, arguments) =>
      arguments.any(argument => argument.mentions_free(id))
    Union(effects) => effects.any(effect => effect.mentions_free(id))
  }
}

///|
fn TypeSubstitution::lookup_type(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> Type? raise TypeSubstitutionError {
  match self.lookup_argument(parameter, bound) {
    Some(TypeArgument(type_)) => Some(type_)
    Some(EffectArgument(_)) => raise ExpectedTypeArgument(parameter~)
    None => None
  }
}

///|
fn TypeSubstitution::lookup_effect(
  self : TypeSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> Effect? raise TypeSubstitutionError {
  match self.lookup_argument(parameter, bound) {
    Some(EffectArgument(effect)) => Some(effect)
    Some(TypeArgument(_)) => raise ExpectedEffectArgument(parameter~)
    None => None
  }
}

///|
pub fn GenericArgument::normalize(
  self : GenericArgument,
) -> GenericArgument raise TypeNormalizationError {
  self.normalize_with_budget({ remaining: TYPE_NORMALIZATION_BETA_LIMIT, })
}

///|
fn GenericArgument::normalize_with_budget(
  self : GenericArgument,
  budget : TypeNormalizationBudget,
) -> GenericArgument raise TypeNormalizationError {
  match self {
    TypeArgument(type_) => TypeArgument(type_.normalize_with_budget(budget))
    EffectArgument(effect) =>
      EffectArgument(effect.normalize_with_budget(budget))
  }
}

///|
pub fn GenericArgument::try_substitute(
  self : GenericArgument,
  substitution : TypeSubstitution,
) -> GenericArgument raise TypeSubstitutionError {
  self.substitute_with_bound(substitution, [])
}

///|
fn GenericArgument::substitute_with_bound(
  self : GenericArgument,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> GenericArgument raise TypeSubstitutionError {
  match self {
    TypeArgument(type_) =>
      TypeArgument(type_.substitute_with_bound(substitution, bound))
    EffectArgument(effect) =>
      EffectArgument(effect.substitute_with_bound(substitution, bound))
  }
}

///|
/// Returns the full beta-normal form of a Buslane type.
///
/// Type lambdas remain first-class type functions; only saturated applications
/// are reduced. Substitution is capture-rejecting, not capture-avoiding: a
/// reduction that would bind a replacement's free parameter raises instead of
/// producing the captured type. Ordinary structural descent does not consume
/// the beta-reduction budget.
///
/// Raises `TypeNormalizationError` when beta reduction does not converge within
/// the compiler safeguard, when a malformed application cannot be reduced, or
/// when a reduction would capture.
pub fn Type::normalize(self : Type) -> Type raise TypeNormalizationError {
  self.normalize_with_budget({ remaining: TYPE_NORMALIZATION_BETA_LIMIT, })
}

///|
/// Returns the full beta-normal form of a Buslane effect's generic arguments.
pub fn Effect::normalize(self : Effect) -> Effect raise TypeNormalizationError {
  self.normalize_with_budget({ remaining: TYPE_NORMALIZATION_BETA_LIMIT, })
}

///|
fn Type::normalize_with_budget(
  self : Type,
  budget : TypeNormalizationBudget,
) -> Type raise TypeNormalizationError {
  match self {
    Primitive(_) | Parameter(_) | Constructor(_) => self
    Apply(callee, arguments) => {
      let normalized_callee = callee.normalize_with_budget(budget)
      let normalized_arguments = arguments.map(argument => {
        argument.normalize_with_budget(budget)
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
            budget.consume_beta()
            let reduced = body.try_substitute(substitution) catch {
              error => raise InvalidBetaSubstitution(error)
            }
            reduced.normalize_with_budget(budget)
          }
        _ => Apply(normalized_callee, normalized_arguments)
      }
    }
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, body.normalize_with_budget(budget))
    Function(parameters, result, effect) =>
      Function(
        parameters.map(parameter => parameter.normalize_with_budget(budget)),
        result.normalize_with_budget(budget),
        effect.normalize_with_budget(budget),
      )
    Forall(parameters, body) =>
      Forall(parameters, body.normalize_with_budget(budget))
  }
}

///|
fn Effect::normalize_with_budget(
  self : Effect,
  budget : TypeNormalizationBudget,
) -> Effect raise TypeNormalizationError {
  match self {
    Empty | Builtin(_) | Parameter(_) => self
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(argument => argument.normalize_with_budget(budget)),
      )
    Union(effects) =>
      Union(effects.map(effect => effect.normalize_with_budget(budget)))
  }
}

///|
/// Applies a well-formed substitution, aborting if an entry has the wrong
/// generic-argument kind or if a replacement would be captured by a binder it
/// crosses. Use `try_substitute` when malformed or capturing substitutions are
/// an expected input.
pub fn Type::substitute(self : Type, substitution : TypeSubstitution) -> Type {
  try! self.substitute_with_bound(substitution, [])
}

///|
pub fn Type::try_substitute(
  self : Type,
  substitution : TypeSubstitution,
) -> Type raise TypeSubstitutionError {
  self.substitute_with_bound(substitution, [])
}

///|
fn Type::substitute_with_bound(
  self : Type,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> Type raise TypeSubstitutionError {
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
        arguments.map(argument => {
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
        parameters.map(parameter => {
          parameter.substitute_with_bound(substitution, bound)
        }),
        result.substitute_with_bound(substitution, bound),
        effect.substitute_with_bound(substitution, bound),
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
/// Applies a well-formed substitution, aborting if an entry has the wrong generic-argument kind. Use `try_substitute` when malformed substitutions are an expected input.
pub fn Effect::substitute(
  self : Effect,
  substitution : TypeSubstitution,
) -> Effect {
  try! self.substitute_with_bound(substitution, [])
}

///|
pub fn Effect::try_substitute(
  self : Effect,
  substitution : TypeSubstitution,
) -> Effect raise TypeSubstitutionError {
  self.substitute_with_bound(substitution, [])
}

///|
fn Effect::substitute_with_bound(
  self : Effect,
  substitution : TypeSubstitution,
  bound : Array[TypeParameterId],
) -> Effect raise TypeSubstitutionError {
  match self {
    Empty | Builtin(_) => self
    Parameter(parameter) =>
      match substitution.lookup_effect(parameter, bound) {
        Some(replacement) => replacement
        None => self
      }
    Singleton(id, arguments) =>
      Singleton(
        id,
        arguments.map(argument => {
          argument.substitute_with_bound(substitution, bound)
        }),
      )
    Union(effects) =>
      Union(
        effects.map(effect => effect.substitute_with_bound(substitution, bound)),
      )
  }
}
