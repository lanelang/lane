///|
pub(all) struct EffectCompanionBinding {
  source : @buslane.TypeParameterId
  companion : @buslane.TypeParameterId
  residual : @buslane.TypeParameterId
} derive(Debug, Eq)

// A source effect parameter becomes two independent CPS facts: a context type
// function, which alone determines runtime representation, and an external
// residual-effect projection, which remains purely static. A CPS'd function
// does not perform the residual effects its dictionary and continuation
// perform; it only propagates them. Its type says so: every dictionary is
// parameterised over the residual its operations run under, and every CPS'd
// callable binds that residual alongside its answer type. The alternative, one
// dictionary per concrete residual, forces one CPS form of a function per
// residual it is ever installed under, which no separately compiled definition
// can know.

///|
priv struct DictionaryHeader {
  effect : @buslane.EffectId
  type_id : @buslane.TypeId
  answer_parameter : @buslane.TypeParameterId
  residual_parameter : @buslane.TypeParameterId
}

///|
priv struct ContextPackSchema {
  arity : Int
  type_id : @buslane.TypeId
}

///|
priv struct DictionaryCpsSchema {
  metadata : @buslane.MetadataRegistry
  companions : Array[EffectCompanionBinding]
  dictionaries : Array[DictionaryHeader]
  context_packs : Array[ContextPackSchema]
  callable_shapes : Array[CpsCallableShape?]
}

///|
fn build_dictionary_cps_schema_or_raise(
  metadata : @buslane.MetadataRegistry,
) -> DictionaryCpsSchema raise SynthesisError {
  let companions = define_effect_companions(metadata)
  let headers = []
  let effect_count = metadata.effects.length()
  for index in 0..<effect_count {
    headers.push(define_dictionary_header(metadata, companions, { index, }))
  }
  let schema = DictionaryCpsSchema::{
    metadata,
    companions,
    dictionaries: headers,
    context_packs: [],
    callable_shapes: Array::make(metadata.values.length(), None),
  }
  for header in headers {
    let field_types = define_operation_field_types(schema, header)
    ignore(
      metadata.define_cps_data_constructor(
        "%effect_dictionary",
        header.type_id,
        [],
        field_types,
      ),
    )
  }
  schema
}

///|
fn define_effect_companions(
  metadata : @buslane.MetadataRegistry,
) -> Array[EffectCompanionBinding] raise SynthesisError {
  let companions = []
  let source_parameter_count = metadata.type_parameters.length()
  for index in 0..<source_parameter_count {
    let source = @buslane.TypeParameterId::{ index, }
    let info = metadata.type_parameters[index]
    if info.kind == Effect {
      companions.push(EffectCompanionBinding::{
        source,
        companion: metadata.define_cps_type_parameter(
          info.name.occurrence + "%context",
          Function([Type, Effect], Type),
        ),
        residual: metadata.define_cps_type_parameter(
          info.name.occurrence + "%residual",
          Effect,
          flavor=External,
        ),
      })
    }
  }
  companions
}

///|
fn define_dictionary_header(
  metadata : @buslane.MetadataRegistry,
  companions : Array[EffectCompanionBinding],
  effect : @buslane.EffectId,
) -> DictionaryHeader raise SynthesisError {
  guard metadata.effect_info(effect) is Some(info) else {
    raise UnknownEffect(effect)
  }
  let parameters = rewrite_cps_parameters(companions, info.parameters)
  let answer_parameter = metadata.define_cps_type_parameter(
    info.name.occurrence + "%answer",
    Type,
  )
  let residual_parameter = metadata.define_cps_type_parameter(
    info.name.occurrence + "%residual",
    Effect,
    flavor=External,
  )
  let type_id = metadata.define_cps_type(
    info.name.occurrence + "%dictionary",
    parameters + [answer_parameter, residual_parameter],
  )
  { effect, type_id, answer_parameter, residual_parameter }
}

///|
fn define_operation_field_types(
  schema : DictionaryCpsSchema,
  header : DictionaryHeader,
) -> Array[@buslane.Type] raise SynthesisError {
  guard schema.metadata.effect_info(header.effect) is Some(info) else {
    raise UnknownEffect(header.effect)
  }
  let answer_type = @buslane.Type::Parameter(header.answer_parameter)
  let residual_effect = @buslane.Effect::Parameter(header.residual_parameter)
  let fields = []
  for operation in info.operations {
    guard schema.metadata.operation_info(operation) is Some(operation_info) else {
      raise UnknownOperation(operation)
    }
    let payload_types = operation_info.payload_types.map(type_ => {
      schema.rewrite_type(type_)
    })
    let result_type = schema.rewrite_type(operation_info.result_type)
    let resume_type = @buslane.Type::Function(
      [result_type],
      answer_type,
      residual_effect,
    )
    let callable = @buslane.Type::Function(
      payload_types + [resume_type],
      answer_type,
      residual_effect,
    )
    let hidden_parameters = schema.rewrite_cps_parameters(
      operation_info.hidden_type_parameters,
    )
    fields.push(
      if hidden_parameters.is_empty() {
        callable
      } else {
        Forall(hidden_parameters, callable)
      },
    )
  }
  fields
}

///|
fn DictionaryCpsSchema::companion_parameter(
  self : DictionaryCpsSchema,
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  companion_parameter(self.companions, source)
}

///|
fn DictionaryCpsSchema::residual_parameter(
  self : DictionaryCpsSchema,
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  residual_parameter(self.companions, source)
}

///|
fn DictionaryCpsSchema::rewrite_cps_parameters(
  self : DictionaryCpsSchema,
  parameters : Array[@buslane.TypeParameterId],
) -> Array[@buslane.TypeParameterId] {
  rewrite_cps_parameters(self.companions, parameters)
}

///|
fn rewrite_cps_parameters(
  companions : Array[EffectCompanionBinding],
  parameters : Array[@buslane.TypeParameterId],
) -> Array[@buslane.TypeParameterId] {
  let rewritten = []
  for parameter in parameters {
    match effect_companion(companions, parameter) {
      Some(binding) => {
        // Effect binders become two independent CPS facts.
        rewritten.push(binding.companion)
        rewritten.push(binding.residual)
      }
      None => rewritten.push(parameter)
    }
  }
  rewritten
}

///|
fn companion_parameter(
  companions : Array[EffectCompanionBinding],
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  match effect_companion(companions, source) {
    Some(entry) => entry.companion
    None => source
  }
}

///|
fn residual_parameter(
  companions : Array[EffectCompanionBinding],
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  match effect_companion(companions, source) {
    Some(entry) => entry.residual
    None => source
  }
}

///|
fn effect_companion(
  companions : Array[EffectCompanionBinding],
  source : @buslane.TypeParameterId,
) -> EffectCompanionBinding? {
  for entry in companions {
    if entry.source == source {
      return Some(entry)
    }
  }
  None
}

///|
fn DictionaryCpsSchema::dictionary(
  self : DictionaryCpsSchema,
  effect : @buslane.EffectId,
) -> DictionaryHeader raise SynthesisError {
  for dictionary in self.dictionaries {
    if dictionary.effect == effect {
      return dictionary
    }
  }
  raise UnknownEffect(effect)
}

///|
fn DictionaryCpsSchema::rewrite_type(
  self : DictionaryCpsSchema,
  type_ : @buslane.Type,
) -> @buslane.Type raise SynthesisError {
  match type_ {
    Primitive(_) | Constructor(_) => type_
    Parameter(parameter) => Parameter(self.companion_parameter(parameter))
    Apply(callee, arguments) =>
      Apply(
        self.rewrite_type(callee),
        arguments.map(argument => self.rewrite_generic_argument(argument)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(
        self.rewrite_cps_parameters(parameters),
        self.rewrite_type(body),
      )
    Function(_, _, _) => self.plan_callable_shape(type_).target_type
    Forall(parameters, body) =>
      Forall(self.rewrite_cps_parameters(parameters), self.rewrite_type(body))
  }
}

///|
fn DictionaryCpsSchema::rewrite_generic_argument(
  self : DictionaryCpsSchema,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise SynthesisError {
  match argument {
    TypeArgument(type_) => TypeArgument(self.rewrite_type(type_))
    EffectArgument(effect) => EffectArgument(effect)
  }
}

///|
fn DictionaryCpsSchema::rewrite_residual_generic_argument(
  self : DictionaryCpsSchema,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise SynthesisError {
  match argument {
    TypeArgument(type_) => TypeArgument(self.rewrite_type(type_))
    EffectArgument(effect) =>
      EffectArgument(self.rewrite_residual_effect(effect))
  }
}

///|
fn DictionaryCpsSchema::rewrite_cps_application_arguments(
  self : DictionaryCpsSchema,
  parameter : @buslane.TypeParameterId,
  argument : @buslane.GenericArgument,
) -> Array[@buslane.GenericArgument] raise SynthesisError {
  guard self.metadata.type_parameter_info(parameter) is Some(info) else {
    return [self.rewrite_generic_argument(argument)]
  }
  match (effect_companion(self.companions, parameter), info.kind, argument) {
    (Some(_), Effect, EffectArgument(Parameter(source))) =>
      [
        // Forward both facts from the enclosing scope. In particular, keep the
        // existing companion parameter so its explicit layout witness follows it.
        TypeArgument(Parameter(self.companion_parameter(source))),
        EffectArgument(Parameter(self.residual_parameter(source))),
      ]
    (Some(_), Effect, EffectArgument(effect)) =>
      [
        // Concrete and composite effects define the two facts independently;
        // neither can be reconstructed from the other.
        TypeArgument(self.companion_context_argument(effect)),
        EffectArgument(self.rewrite_residual_effect(effect)),
      ]
    (_, _, TypeArgument(type_)) => [TypeArgument(self.rewrite_type(type_))]
    (_, _, EffectArgument(effect)) => [EffectArgument(effect)]
  }
}

///|
fn DictionaryCpsSchema::rewrite_cps_application_argument_list(
  self : DictionaryCpsSchema,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Array[@buslane.GenericArgument] raise SynthesisError {
  let rewritten = []
  for index, argument in arguments {
    rewritten.append(
      self.rewrite_cps_application_arguments(parameters[index], argument),
    )
  }
  rewritten
}

///|
fn DictionaryCpsSchema::context_argument_types(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
  answer_type : @buslane.Type,
  residual_effect : @buslane.Effect,
) -> Array[@buslane.Type] raise SynthesisError {
  effect_terms(self.metadata, mon_effect_part(self.metadata, effect)).map(term => {
    self.context_term_type(term, answer_type, residual_effect)
  })
}

///|
fn DictionaryCpsSchema::packed_context_type(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
  answer_type : @buslane.Type,
  residual_effect : @buslane.Effect,
) -> @buslane.Type raise SynthesisError {
  let context_types = self.context_argument_types(
    effect, answer_type, residual_effect,
  )
  match context_types {
    [] => Primitive(Unit)
    [context_type] => context_type
    context_types => {
      let pack = self.context_pack(context_types.length())
      Apply(
        Constructor(pack.type_id),
        context_types.map(type_ => TypeArgument(type_)),
      )
    }
  }
}

///|
fn DictionaryCpsSchema::context_term_type(
  self : DictionaryCpsSchema,
  term : @buslane.Effect,
  answer_type : @buslane.Type,
  residual_effect : @buslane.Effect,
) -> @buslane.Type raise SynthesisError {
  match term {
    Builtin(_) => abort("builtin effects have no effect dictionary")
    Singleton(effect, arguments) => {
      let dictionary = self.dictionary(effect)
      guard self.metadata.effect_info(effect) is Some(info) else {
        raise UnknownEffect(effect)
      }
      Apply(
        Constructor(dictionary.type_id),
        self.rewrite_cps_application_argument_list(info.parameters, arguments) +
        [TypeArgument(answer_type), EffectArgument(residual_effect)],
      )
    }
    Parameter(parameter) => {
      let companion = self.companion_parameter(parameter)
      Apply(Parameter(companion), [
        TypeArgument(answer_type),
        EffectArgument(residual_effect),
      ])
    }
    Empty | Union(_) => abort("canonical effect term expected")
  }
}

///|
/// The packed context supplied for an effect, abstracted over the answer and
/// residual at each use of its companion.
fn DictionaryCpsSchema::companion_context_argument(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
) -> @buslane.Type raise SynthesisError {
  let answer_parameter = self.metadata.define_cps_type_parameter(
    "%companion_answer",
    Type,
  )
  let residual_parameter = self.metadata.define_cps_type_parameter(
    "%companion_residual",
    Effect,
    flavor=External,
  )
  TypeLambda(
    [answer_parameter, residual_parameter],
    self.packed_context_type(
      effect,
      Parameter(answer_parameter),
      Parameter(residual_parameter),
    ),
  )
}

///|
/// The residual a CPS'd callable runs under: what the source function performs
/// itself, plus whatever the dictionary and continuation it is handed perform.
///
/// Callers instantiate `parameter` with their own residual. Keeping the
/// function's own residual in the type means the union collapses back to the
/// caller's residual, because source typing already makes a callee's residual a
/// subeffect of its caller's.
fn DictionaryCpsSchema::cps_residual_effect(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
  parameter : @buslane.Effect,
) -> @buslane.Effect raise SynthesisError {
  cps_canonicalize_effect(
    self.metadata,
    Union([self.rewrite_residual_effect(effect), parameter]),
  )
}

///|
fn DictionaryCpsSchema::rewrite_residual_effect(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
) -> @buslane.Effect raise SynthesisError {
  match effect {
    Empty | Builtin(_) => effect
    Parameter(parameter) => Parameter(self.residual_parameter(parameter))
    Singleton(effect, arguments) => {
      guard self.metadata.effect_info(effect) is Some(info) else {
        raise UnknownEffect(effect)
      }
      if info.flavor is Algebraic {
        Empty
      } else {
        Singleton(
          effect,
          arguments.map(argument => {
            self.rewrite_residual_generic_argument(argument)
          }),
        )
      }
    }
    Union(effects) =>
      cps_canonicalize_effect(
        self.metadata,
        Union(effects.map(effect => self.rewrite_residual_effect(effect))),
      )
  }
}

///|
fn DictionaryCpsSchema::context_pack(
  self : DictionaryCpsSchema,
  arity : Int,
) -> ContextPackSchema raise SynthesisError {
  for pack in self.context_packs {
    if pack.arity == arity {
      return pack
    }
  }
  let parameters = []
  for index in 0..<arity {
    parameters.push(
      self.metadata.define_cps_type_parameter(
        "%context" + index.to_string(),
        Type,
      ),
    )
  }
  let type_id = self.metadata.define_cps_type("%context_pack", parameters)
  ignore(
    self.metadata.define_cps_data_constructor(
      "%context_pack",
      type_id,
      [],
      parameters.map(parameter => Parameter(parameter)),
    ),
  )
  let pack = ContextPackSchema::{ arity, type_id }
  self.context_packs.push(pack)
  pack
}
