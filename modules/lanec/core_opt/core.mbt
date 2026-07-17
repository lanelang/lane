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
  let preserved_roots = request.roots.copy()
  preserved_roots.push(request.entry)
  let simplified = simplify_program(request.program, preserved_roots)
  Ok(prune_unreachable(simplified, request.entry, request.roots))
}
