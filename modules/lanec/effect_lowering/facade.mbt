///|
pub fn elaborate_handlers(program : @buslane.Program) -> Program {
  @effect_lowering_core.elaborate_handlers(program)
}

///|
pub fn introduce_monadic_binds(
  program : Program,
) -> Result[Program, SynthesisError] {
  @effect_lowering_core.introduce_monadic_binds(program)
}

///|
pub fn lift_monadic_continuations(
  program : Program,
) -> Result[@buslane.Program, SynthesisError] {
  @effect_lowering_core.lift_monadic_continuations(program)
}

///|
pub fn resolve_open_contexts(
  program : Program,
) -> Result[Program, SynthesisError] {
  @effect_lowering_core.resolve_open_contexts(program)
}

///|
pub fn validate_mon_trans_output(
  program : Program,
) -> Result[Unit, SynthesisError] {
  @effect_lowering_core.validate_mon_trans_output(program)
}

///|
pub fn validate_open_resolve_output(
  program : Program,
) -> Result[Unit, SynthesisError] {
  @effect_lowering_core.validate_open_resolve_output(program)
}
