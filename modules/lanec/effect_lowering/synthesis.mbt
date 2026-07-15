///|
pub using @effect_lowering_core {type ExprFacts, type SynthesisError}

///|
pub fn synthesize_expr(
  program : Program,
  expression : Expr,
) -> Result[ExprFacts, SynthesisError] {
  @effect_lowering_core.synthesize_expr(program, expression)
}
