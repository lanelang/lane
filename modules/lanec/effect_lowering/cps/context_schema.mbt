///|
pub(all) struct EffectCompanionBinding {
  source : @buslane.TypeParameterId
  companion : @buslane.TypeParameterId
} derive(Debug, Eq)

///|
priv struct DictionaryHeader {
  effect : @buslane.EffectId
  type_id : @buslane.TypeId
  answer_parameter : @buslane.TypeParameterId
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
}

///|
fn build_dictionary_cps_schema_or_raise(
  metadata : @buslane.MetadataRegistry,
) -> DictionaryCpsSchema raise SynthesisError {
  let companions = define_effect_companions(metadata)
  let headers = define_dictionary_headers(metadata, companions)
  let schema = DictionaryCpsSchema::{
    metadata,
    companions,
    dictionaries: headers,
    context_packs: [],
  }
  for header in headers {
    let field_types = define_operation_field_types(schema, header)
    ignore(
      metadata.define_data_constructor(
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
) -> Array[EffectCompanionBinding] {
  let companions = []
  let source_parameter_count = metadata.type_parameters.length()
  for index in 0..<source_parameter_count {
    let source = @buslane.TypeParameterId::{ index, }
    let info = metadata.type_parameters[index]
    if info.kind == Effect {
      companions.push(EffectCompanionBinding::{
        source,
        companion: metadata.define_type_parameter(
          info.name.occurrence + "%context",
          Type,
        ),
      })
    }
  }
  companions
}

///|
fn define_dictionary_headers(
  metadata : @buslane.MetadataRegistry,
  companions : Array[EffectCompanionBinding],
) -> Array[DictionaryHeader] raise SynthesisError {
  let headers = []
  let effect_count = metadata.effects.length()
  for index in 0..<effect_count {
    let effect = @buslane.EffectId::{ index, }
    guard metadata.effect_info(effect) is Some(info) else {
      raise UnknownEffect(effect)
    }
    let parameters = info.parameters.map(parameter => {
      companion_parameter(companions, parameter)
    })
    let answer_parameter = metadata.define_type_parameter(
      info.name.occurrence + "%answer",
      Type,
    )
    let type_id = metadata.define_type(
      info.name.occurrence + "%dictionary",
      parameters + [answer_parameter],
    )
    headers.push({ effect, type_id, answer_parameter })
  }
  headers
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
  let fields = []
  for operation in info.operations {
    guard schema.metadata.operation_info(operation) is Some(operation_info) else {
      raise UnknownOperation(operation)
    }
    let payload_types = operation_info.payload_types.map(type_ => {
      schema.rewrite_type(type_)
    })
    let result_type = schema.rewrite_type(operation_info.result_type)
    let resume_type = @buslane.Type::Function([result_type], answer_type, Empty)
    let callable = @buslane.Type::Function(
      payload_types + [resume_type],
      answer_type,
      Empty,
    )
    let hidden_parameters = operation_info.hidden_type_parameters.map(parameter => {
      schema.companion_parameter(parameter)
    })
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
fn companion_parameter(
  companions : Array[EffectCompanionBinding],
  source : @buslane.TypeParameterId,
) -> @buslane.TypeParameterId {
  for entry in companions {
    if entry.source == source {
      return entry.companion
    }
  }
  source
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
        parameters.map(parameter => self.companion_parameter(parameter)),
        self.rewrite_type(body),
      )
    Function(parameters, result, effect) => {
      let rewritten_parameters = parameters.map(parameter => {
        self.rewrite_type(parameter)
      })
      let rewritten_result = self.rewrite_type(result)
      if effect.canonicalize() == Empty {
        Function(rewritten_parameters, rewritten_result, Empty)
      } else {
        let answer_parameter = self.metadata.define_type_parameter(
          "%answer",
          Type,
        )
        let answer_type = @buslane.Type::Parameter(answer_parameter)
        let context_types = self.context_argument_types(effect, answer_type)
        let continuation_type = @buslane.Type::Function(
          [rewritten_result],
          answer_type,
          Empty,
        )
        Forall(
          [answer_parameter],
          Function(
            context_types + rewritten_parameters + [continuation_type],
            answer_type,
            Empty,
          ),
        )
      }
    }
    Forall(parameters, body) =>
      Forall(
        parameters.map(parameter => self.companion_parameter(parameter)),
        self.rewrite_type(body),
      )
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
fn DictionaryCpsSchema::context_argument_types(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
  answer_type : @buslane.Type,
) -> Array[@buslane.Type] raise SynthesisError {
  effect_terms(effect).map(term => self.context_term_type(term, answer_type))
}

///|
fn DictionaryCpsSchema::packed_context_type(
  self : DictionaryCpsSchema,
  effect : @buslane.Effect,
  answer_type : @buslane.Type,
) -> @buslane.Type raise SynthesisError {
  let context_types = self.context_argument_types(effect, answer_type)
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
) -> @buslane.Type raise SynthesisError {
  match term {
    Io => abort("Io has no effect dictionary")
    Singleton(effect, arguments) => {
      let dictionary = self.dictionary(effect)
      Apply(
        Constructor(dictionary.type_id),
        arguments.map(argument => {
          self.rewrite_context_argument(argument, answer_type)
        }) +
        [TypeArgument(answer_type)],
      )
    }
    Parameter(parameter) => Parameter(self.companion_parameter(parameter))
    Empty | Union(_) => abort("canonical effect term expected")
  }
}

///|
fn DictionaryCpsSchema::rewrite_context_argument(
  self : DictionaryCpsSchema,
  argument : @buslane.GenericArgument,
  answer_type : @buslane.Type,
) -> @buslane.GenericArgument raise SynthesisError {
  match argument {
    TypeArgument(type_) => TypeArgument(self.rewrite_type(type_))
    EffectArgument(effect) =>
      TypeArgument(self.packed_context_type(effect, answer_type))
  }
}

///|
fn DictionaryCpsSchema::context_pack(
  self : DictionaryCpsSchema,
  arity : Int,
) -> ContextPackSchema {
  for pack in self.context_packs {
    if pack.arity == arity {
      return pack
    }
  }
  let parameters = []
  for index in 0..<arity {
    parameters.push(
      self.metadata.define_type_parameter("%context" + index.to_string(), Type),
    )
  }
  let type_id = self.metadata.define_type("%context_pack", parameters)
  ignore(
    self.metadata.define_data_constructor(
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
