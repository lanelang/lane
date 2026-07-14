///|
fn synthesize_expr_or_raise(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> ExprFacts raise SynthesisError {
  match @effect_lowering.synthesize_expr({ metadata, terms: [] }, expression) {
    Ok(facts) => facts
    Err(error) => raise error
  }
}

///|
fn validate_mon_trans_output_or_raise(
  program : Program,
) -> Unit raise SynthesisError {
  match @effect_lowering.validate_mon_trans_output(program) {
    Ok(_) => ()
    Err(error) => raise error
  }
}

///|
fn value_type(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
) -> @buslane.Type raise SynthesisError {
  guard metadata.value_info(id) is Some(info) else { raise UnknownValue(id) }
  info.type_
}

///|
fn effect_terms(effect : @buslane.Effect) -> Array[@buslane.Effect] {
  match effect.canonicalize() {
    Empty => []
    Union(effects) => effects
    effect => [effect]
  }
}

///|
fn effect_has_parameter(effect : @buslane.Effect) -> Bool {
  effect_terms(effect).any(term => term is Parameter(_))
}

///|
fn require_arity(expected : Int, actual : Int) -> Unit raise SynthesisError {
  if expected != actual {
    raise ArityMismatch(expected~, actual~)
  }
}

///|
fn set_source_resume_effect(
  metadata : @buslane.MetadataRegistry,
  resume_binder : @buslane.ValueId,
  effect : @buslane.Effect,
) -> Unit raise SynthesisError {
  guard metadata.value_info(resume_binder) is Some(info) else {
    raise UnknownValue(resume_binder)
  }
  guard info.type_ is Function([parameter], result, _) else {
    raise ExpectedFunction(info.type_)
  }
  metadata.values[resume_binder.index] = {
    name: info.name,
    kind: info.kind,
    type_: Function([parameter], result, effect),
  }
}
