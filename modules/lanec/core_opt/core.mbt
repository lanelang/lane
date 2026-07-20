///|
pub(all) struct CoreOptimizeRequest {
  program : @buslane.Program
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
} derive(Debug, Eq)

///|
pub(all) suberror CoreOptimizeError {
  UnknownRoot(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub fn optimize(
  request : CoreOptimizeRequest,
) -> Result[@buslane.Program, CoreOptimizeError] {
  if request.program.metadata.value_info(request.entry) is None {
    return Err(UnknownRoot(request.entry))
  }
  for root in request.roots {
    if request.program.metadata.value_info(root) is None {
      return Err(UnknownRoot(root))
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
  Ok(prune_unreachable(simplified, request.entry, request.roots))
}
