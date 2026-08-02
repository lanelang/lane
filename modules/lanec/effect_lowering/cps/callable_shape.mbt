///|
priv enum CpsCallableMode {
  Direct
  Monadic(
    answer_parameter~ : @buslane.TypeParameterId,
    residual_parameter~ : @buslane.TypeParameterId,
    context_terms~ : Array[@buslane.Effect],
    context_parameter_types~ : Array[@buslane.Type],
    continuation_type~ : @buslane.Type
  )
}

///|
/// The one lowering decision shared by a callable's target type and body.
///
/// Declaration metadata consumes `target_type` once. Body lowering consumes
/// the remaining fields without reconstructing the ABI from expression syntax.
priv struct CpsCallableShape {
  source_type : @buslane.Type
  target_type : @buslane.Type
  value_parameter_types : Array[@buslane.Type]
  result_type : @buslane.Type
  target_effect : @buslane.Effect
  mode : CpsCallableMode
}

///|
fn CpsCallableShape::source_effect(self : CpsCallableShape) -> @buslane.Effect {
  guard self.source_type is Function(_, _, effect) else {
    abort("CPS callable shape lost its source function type")
  }
  effect
}

///|
fn CpsCallableShape::align_value_parameters(
  self : CpsCallableShape,
  metadata : @buslane.MetadataRegistry,
  parameters : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] raise SynthesisError {
  require_arity(self.value_parameter_types.length(), parameters.length())
  for index, parameter in parameters {
    let actual = value_type(metadata, parameter)
    let expected = self.value_parameter_types[index]
    if !metadata.types_definitionally_equal(actual, expected) {
      raise BindingTypeMismatch(value=parameter, expected~, actual~)
    }
  }
  parameters
}

///|
fn DictionaryCpsSchema::plan_callable_shape(
  self : DictionaryCpsSchema,
  source_type : @buslane.Type,
) -> CpsCallableShape raise SynthesisError {
  guard source_type is Function(source_parameters, source_result, latent_effect) else {
    raise ExpectedFunction(source_type)
  }
  let value_parameter_types = source_parameters.map(parameter => {
    self.rewrite_type(parameter)
  })
  let rewritten_result = self.rewrite_type(source_result)
  if !is_mon_effect(self.metadata, latent_effect) {
    let target_effect = residual_effect_part(self.metadata, latent_effect)
    let target_type = @buslane.Type::Function(
      value_parameter_types, rewritten_result, target_effect,
    )
    {
      source_type,
      target_type,
      value_parameter_types,
      result_type: rewritten_result,
      target_effect,
      mode: Direct,
    }
  } else {
    let answer_parameter = self.metadata.define_type_parameter("%answer", Type)
    let residual_parameter = self.metadata.define_type_parameter(
      "%residual",
      Effect,
      flavor=External,
    )
    let answer_type = @buslane.Type::Parameter(answer_parameter)
    let target_effect = self.cps_residual_effect(
      latent_effect,
      Parameter(residual_parameter),
    )
    let context_terms = effect_terms(
      self.metadata,
      mon_effect_part(self.metadata, latent_effect),
    )
    let context_parameter_types = self.context_argument_types(
      latent_effect, answer_type, target_effect,
    )
    let continuation_type = @buslane.Type::Function(
      [rewritten_result],
      answer_type,
      target_effect,
    )
    let target_type = @buslane.Type::Forall(
      [answer_parameter, residual_parameter],
      Function(
        context_parameter_types + value_parameter_types + [continuation_type],
        answer_type,
        target_effect,
      ),
    )
    {
      source_type,
      target_type,
      value_parameter_types,
      result_type: answer_type,
      target_effect,
      mode: Monadic(
        answer_parameter~,
        residual_parameter~,
        context_terms~,
        context_parameter_types~,
        continuation_type~,
      ),
    }
  }
}

///|
fn DictionaryCpsSchema::rewrite_value_type(
  self : DictionaryCpsSchema,
  source_type : @buslane.Type,
) -> (@buslane.Type, CpsCallableShape?) raise SynthesisError {
  match source_type {
    Forall(parameters, body) => {
      let (target_body, shape) = self.rewrite_value_type(body)
      (Forall(self.rewrite_cps_parameters(parameters), target_body), shape)
    }
    Function(_, _, _) => {
      let shape = self.plan_callable_shape(source_type)
      (shape.target_type, Some(shape))
    }
    _ => (self.rewrite_type(source_type), None)
  }
}
