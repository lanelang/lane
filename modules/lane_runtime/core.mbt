///|
pub(all) enum ExecutionOutcome {
  ProcessExit(code~ : Int)
  Returned
} derive(Debug, Eq)

///|
pub(all) suberror ExecutionError {
  Interrupted
  EngineTrap(detail~ : String)
  InstanceNotReady
} derive(Debug, Eq)
