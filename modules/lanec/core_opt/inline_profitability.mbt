///|
/// Profitability is structural and is evaluated only after contextual local
/// reduction. Legality is owned by InlinePlan and is never inferred from this
/// comparison.
fn inline_is_profitable(
  original : @buslane.Expr,
  candidate : @buslane.Expr,
  callable : KnownCallable,
  analysis : InterproceduralAnalysis,
  preserved_roots : Array[@buslane.ValueId],
) -> Bool {
  let mut original_size = core_expression_size(original)
  if callable.occurrence.use_count == 1 &&
    !preserved_roots.contains(callable.value) &&
    analysis.core.find_top_definition(callable.value) is Some(definition) {
    original_size = original_size + core_expression_size(definition)
  }
  core_expression_size(candidate) < original_size ||
  is_straight_line_value(candidate)
}

///|
/// A straight-line value has no dynamic call, branch, effect operation, or
/// handler dispatch. Inlining it removes a call boundary without duplicating
/// control-flow work; code-size comparison handles every other candidate.
fn is_straight_line_value(expression : @buslane.Expr) -> Bool {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => true
    Function(_) => true
    TypeLambda(_, body) => is_straight_line_value(body)
    TypeApply(callee, _) => is_straight_line_value(callee)
    Construct(construct) =>
      construct.payloads.all(payload => is_straight_line_value(payload))
    Let(_, initializer, body) =>
      is_straight_line_value(initializer) && is_straight_line_value(body)
    LetRec(_, _) | Call(_, _) | Match(_) | Perform(_) | Handle(_) => false
  }
}
