///|
priv suberror ExecutionFailure {
  ImportFailure(symbol~ : String, message~ : String)
  ResourceLimit(@runtime.ResourceLimitKind)
  InterruptedExecution
  Trap(detail~ : String)
  InternalFailure(detail~ : String)
} derive(Debug)
