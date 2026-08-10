///|
priv suberror ExecutionFailure {
  FatalExecution(message~ : String)
  ImportFailure(symbol~ : String, message~ : String)
  ResourceLimit(@runtime.ResourceLimitKind)
  InterruptedExecution
  Trap(detail~ : String)
  InvalidCallable(@runtime.CallableInvocationError)
  InternalFailure(detail~ : String)
} derive(Debug)
