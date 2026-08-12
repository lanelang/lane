///|
pub(all) struct CoreOptimizeRequest {
  program : @buslane.Program
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
} derive(Debug, Eq)

///|
pub(all) enum ApplicationReductionSite {
  DirectFunction
  KnownCallable(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) enum ApplicationReductionRejection {
  Recursive
  Profitability
} derive(Debug, Eq)

///|
pub(all) enum CoreOptimizationObservation {
  ApplicationConsidered(ApplicationReductionSite)
  ApplicationAccepted(
    site~ : ApplicationReductionSite,
    empty_arguments~ : Int,
    materialized_arguments~ : Int
  )
  ApplicationRejected(ApplicationReductionSite, ApplicationReductionRejection)
  ProgramChanged(net_calls_removed~ : Int, net_top_terms_removed~ : Int)
} derive(Debug, Eq)

///|
pub(all) suberror CoreOptimizeError {
  UnknownRoot(@buslane.ValueId)
  ApplicationArityCompilerDefect(expected~ : Int, actual~ : Int)
  MissingApplicationParameterMetadataCompilerDefect(@buslane.ValueId)
  ExpressionFactsCompilerDefect(@buslane.VerifyResult)
  TypeNormalizationCompilerDefect(@buslane.TypeNormalizationError)
  MetadataAllocationCompilerDefect(@buslane.MetadataAllocationError)
} derive(Debug, Eq)

///|
fn core_types_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Type,
  right : @buslane.Type,
) -> Bool raise CoreOptimizeError {
  metadata.types_definitionally_equal(left, right) catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
}

///|
fn core_canonicalize_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect raise CoreOptimizeError {
  metadata.canonicalize_effect(effect) catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
}

///|
fn core_effects_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Effect,
  right : @buslane.Effect,
) -> Bool raise CoreOptimizeError {
  metadata.effects_definitionally_equal(left, right) catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
}

///|
pub fn optimize(
  request : CoreOptimizeRequest,
) -> Result[@buslane.Program, CoreOptimizeError] {
  optimize_observed(request, _ => ())
}

///|
/// Optimizes while reporting typed semantic and profitability decisions.
/// Observations are synchronous, ordered, and stop at the first failure.
pub fn optimize_observed(
  request : CoreOptimizeRequest,
  observe : (CoreOptimizationObservation) -> Unit,
) -> Result[@buslane.Program, CoreOptimizeError] {
  try optimize_or_raise(request, observe) catch {
    error => Err(error)
  } noraise {
    program => Ok(program)
  }
}

///|
fn optimize_or_raise(
  request : CoreOptimizeRequest,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.Program raise CoreOptimizeError {
  if request.program.metadata.value_info(request.entry) is None {
    raise UnknownRoot(request.entry)
  }
  for root in request.roots {
    if request.program.metadata.value_info(root) is None {
      raise UnknownRoot(root)
    }
  }
  let program : @buslane.Program = {
    metadata: request.program.metadata.snapshot(),
    terms: request.program.terms,
  }
  let simplified = cleanup_core(program, request.entry, request.roots, observe)
  let optimized = execute_inline_pipeline(
    simplified,
    request.entry,
    request.roots,
    observe,
  )
  observe(
    ProgramChanged(
      net_calls_removed=core_program_call_count(request.program) -
        core_program_call_count(optimized),
      net_top_terms_removed=request.program.terms.length() -
        optimized.terms.length(),
    ),
  )
  optimized
}
