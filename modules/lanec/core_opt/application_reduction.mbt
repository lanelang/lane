///|
priv struct MaterializedApplicationArgument {
  parameter : @buslane.ValueId
  argument : @buslane.Expr
}

///|
priv struct ReducedApplication {
  expression : @buslane.Expr
  empty_argument_count : Int
  materialized_argument_count : Int
}

///|
/// Reduces one materialized application according to Lane's effect contract.
/// Empty arguments whose type already matches the parameter become
/// substitutions. Every other argument receives one binding, preserving both
/// observable evaluation order and parameter-owned representation adaptation.
fn reduce_application(
  program : @buslane.Program,
  facts : @buslane.ExpressionFactsQuery,
  analysis : CoreAnalysis,
  inherited_substitutions : Array[ValueSubstitution],
  parameters : Array[@buslane.ValueId],
  arguments : Array[@buslane.Expr],
  body : @buslane.Expr,
  observe : (CoreOptimizationObservation) -> Unit,
) -> ReducedApplication raise CoreOptimizeError {
  if parameters.length() != arguments.length() {
    raise ApplicationArityCompilerDefect(
      expected=parameters.length(),
      actual=arguments.length(),
    )
  }
  let substitutions = inherited_substitutions.copy()
  let materialized : Array[MaterializedApplicationArgument] = []
  let mut empty_argument_count = 0
  for index in 0..<arguments.length() {
    let parameter = parameters[index]
    let argument = arguments[index]
    guard program.metadata.value_info(parameter) is Some(parameter_info) else {
      raise MissingApplicationParameterMetadataCompilerDefect(parameter)
    }
    let argument_facts = expression_facts(facts, argument)
    let has_empty_effect = core_effects_definitionally_equal(
      program.metadata,
      argument_facts.effect(),
      Empty,
    )
    let requires_parameter_boundary = !core_types_definitionally_equal(
      program.metadata,
      argument_facts.type_(),
      parameter_info.type_,
    )
    if has_empty_effect && !requires_parameter_boundary {
      empty_argument_count += 1
      substitutions.push({ value: parameter, replacement: argument, })
    } else {
      materialized.push({ parameter, argument, })
    }
  }
  let mut reduced = body
  for binding in materialized.rev_iter() {
    reduced = Let(binding.parameter, binding.argument, reduced)
  }
  {
    expression: simplify_expr(
      program, facts, analysis, substitutions, reduced, observe,
    ),
    empty_argument_count,
    materialized_argument_count: materialized.length(),
  }
}
