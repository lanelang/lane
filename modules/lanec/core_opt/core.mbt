///|
pub(all) struct CoreOptimizeRequest {
  program : @buslane.Program
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
} derive(Debug, Eq)

///|
pub(all) suberror CoreOptimizeError {
  UnknownRoot(@buslane.ValueId)
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
pub fn optimize(
  request : CoreOptimizeRequest,
) -> Result[@buslane.Program, CoreOptimizeError] {
  try optimize_or_raise(request) catch {
    error => Err(error)
  } noraise {
    program => Ok(program)
  }
}

///|
fn optimize_or_raise(
  request : CoreOptimizeRequest,
) -> @buslane.Program raise CoreOptimizeError {
  if request.program.metadata.value_info(request.entry) is None {
    raise UnknownRoot(request.entry)
  }
  for root in request.roots {
    if request.program.metadata.value_info(root) is None {
      raise UnknownRoot(root)
    }
  }
  let simplified = simplify_program(
    request.program,
    request.entry,
    request.roots,
  )
  let reachable = prune_unreachable(simplified, request.entry, request.roots)
  let evaluated = partially_evaluate_program(
    reachable,
    request.entry,
    request.roots,
  )
  let simplified = simplify_program(evaluated, request.entry, request.roots)
  prune_unreachable(simplified, request.entry, request.roots)
}
