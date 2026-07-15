///|
fn synthesize_cps_callee_or_raise(
  metadata : @buslane.MetadataRegistry,
  callee : Expr,
) -> ExprFacts raise SynthesisError {
  let argument_groups = []
  let base = collect_cps_type_applications(callee, argument_groups)
  if !argument_groups.is_empty() {
    let base_facts = synthesize_expr_or_raise(metadata, base)
    if base_facts.type_ is Function(_, _, _) {
      return base_facts
    }
  }
  synthesize_expr_or_raise(metadata, callee)
}

///|
fn validate_mon_trans_output_or_raise(
  program : Program,
) -> Unit raise SynthesisError {
  match @effect_lowering_core.validate_mon_trans_output(program) {
    Ok(_) => ()
    Err(error) => raise error
  }
}
