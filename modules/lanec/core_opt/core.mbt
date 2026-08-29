///|
pub(all) struct CoreOptimizeRequest {
  program : @buslane.VerifiedProgram
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
  MissingFunctionOriginCompilerDefect
  ConflictingFunctionOriginCompilerDefect
  OutputVerificationCompilerDefect(@buslane.VerifyResult)
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
) -> Result[@buslane.VerifiedProgram, CoreOptimizeError] {
  optimize_observed_with_origins(request, None, _ => ())
}

///|
/// Optimizes while reporting typed semantic and profitability decisions.
/// Observations are synchronous, ordered, and stop at the first failure.
pub fn optimize_observed(
  request : CoreOptimizeRequest,
  observe : (CoreOptimizationObservation) -> Unit,
) -> Result[@buslane.VerifiedProgram, CoreOptimizeError] {
  optimize_observed_with_origins(request, None, observe)
}

///|
/// Optimizes CPS Core while transferring transformation-owned provenance to
/// every rebuilt or cloned function object.
pub fn optimize_preserving_function_origins(
  request : CoreOptimizeRequest,
  function_origins : @function_origin.FunctionOriginCatalog,
) -> Result[@buslane.VerifiedProgram, CoreOptimizeError] {
  optimize_observed_with_origins(request, Some(function_origins), _ => ())
}

///|
fn optimize_observed_with_origins(
  request : CoreOptimizeRequest,
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> Result[@buslane.VerifiedProgram, CoreOptimizeError] {
  try optimize_or_raise(request, function_origins, observe) catch {
    error => Err(error)
  } noraise {
    program => Ok(program)
  }
}

///|
fn optimize_or_raise(
  request : CoreOptimizeRequest,
  function_origins : @function_origin.FunctionOriginCatalog?,
  observe : (CoreOptimizationObservation) -> Unit,
) -> @buslane.VerifiedProgram raise CoreOptimizeError {
  let (input, input_function_clones) = request.program.program_with_function_clones()
  if function_origins is Some(catalog) &&
    !catalog.transfer_clones(input_function_clones[:]) {
    raise MissingFunctionOriginCompilerDefect
  }
  if input.metadata.value_info(request.entry) is None {
    raise UnknownRoot(request.entry)
  }
  for root in request.roots {
    if input.metadata.value_info(root) is None {
      raise UnknownRoot(root)
    }
  }
  let program : @buslane.Program = {
    metadata: input.metadata.snapshot(),
    terms: input.terms,
  }
  let simplified = cleanup_core(
    program,
    request.entry,
    request.roots,
    function_origins,
    observe,
  )
  let optimized = execute_inline_pipeline(
    simplified,
    request.entry,
    request.roots,
    function_origins,
    observe,
  )
  observe(
    ProgramChanged(
      net_calls_removed=core_program_call_count(input) -
        core_program_call_count(optimized),
      net_top_terms_removed=input.terms.length() - optimized.terms.length(),
    ),
  )
  match optimized.certify_with_function_clones() {
    Ok((program, output_function_clones)) => {
      if function_origins is Some(catalog) &&
        !catalog.transfer_clones(output_function_clones[:]) {
        raise MissingFunctionOriginCompilerDefect
      }
      program
    }
    Err(result) => raise OutputVerificationCompilerDefect(result)
  }
}

///|
fn transfer_function_origin(
  function_origins : @function_origin.FunctionOriginCatalog?,
  source : @buslane.FunctionExpr,
  target : @buslane.FunctionExpr,
) -> Unit raise CoreOptimizeError {
  if function_origins is Some(catalog) {
    guard catalog.origin(source) is Some(_) else {
      raise MissingFunctionOriginCompilerDefect
    }
    if !catalog.transfer(source, target) {
      raise ConflictingFunctionOriginCompilerDefect
    }
  }
}
