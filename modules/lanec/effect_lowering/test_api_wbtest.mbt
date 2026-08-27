///|
fn rewrite_selective_cps_abis(
  program : Program,
) -> Result[Program, SynthesisError] {
  Ok(rewrite_selective_cps_abis_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn introduce_monadic_binds(
  program : Program,
) -> Result[Program, SynthesisError] {
  Ok(introduce_monadic_binds_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn validate_mon_trans_output(program : Program) -> Result[Unit, SynthesisError] {
  Ok(validate_mon_trans_output_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn resolve_open_contexts(program : Program) -> Result[Program, SynthesisError] {
  Ok(resolve_open_contexts_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn validate_open_resolve_output(
  program : Program,
) -> Result[Unit, SynthesisError] {
  Ok(validate_open_resolve_output_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn lift_monadic_continuations(
  program : Program,
) -> Result[@buslane.Program, SynthesisError] {
  Ok(lift_monadic_continuations_or_raise(program).program) catch {
    error => Err(error)
  }
}

///|
fn synthesize_expr(
  program : Program,
  expression : Expr,
) -> Result[ExprFacts, SynthesisError] {
  Ok(synthesize_expr_or_raise(program.metadata, expression)) catch {
    error => Err(error)
  }
}

///|
impl Eq for ExprFacts with fn equal(self : ExprFacts, other : ExprFacts) -> Bool {
  self.type_ == other.type_ && self.effect == other.effect
}

///|
impl Debug for ExprFacts with fn to_repr(self : ExprFacts) -> Repr {
  Repr::ctor("ExprFacts", [
    (Some("type_"), self.type_.to_repr()),
    (Some("effect"), self.effect.to_repr()),
  ])
}

///|
fn verify_program(
  program : Program,
) -> Result[@buslane.VerifyResult, SynthesisError] {
  Ok(verify_program_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
impl @prettyprinter.Pretty for Program with fn pretty(program : Program) {
  @prettyprinter.text("buslane") +
  @prettyprinter.space +
  @pretty.braced_block(
    [
      program.metadata.pretty(),
      ..program.terms.map(@prettyprinter.Pretty::pretty),
    ],
  )
}

///|
impl Eq for TopTerm with fn equal(self : TopTerm, other : TopTerm) -> Bool {
  match (self, other) {
    (Let(left_id, left), Let(right_id, right)) =>
      left_id == right_id && left == right
    (LetRec(left), LetRec(right)) => left == right
    (External(left), External(right)) => left == right
    _ => false
  }
}

///|
impl Debug for TopTerm with fn to_repr(self : TopTerm) -> Repr {
  Repr::string(@prettyprinter.render(self, width=100))
}

///|
impl Eq for Program with fn equal(self : Program, other : Program) -> Bool {
  self.metadata == other.metadata && self.terms == other.terms
}

///|
impl Debug for Program with fn to_repr(self : Program) -> Repr {
  Repr::string(@prettyprinter.render(self, width=100))
}
