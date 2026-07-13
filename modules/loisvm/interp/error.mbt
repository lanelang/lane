///|
priv suberror ExecutionFailure {
  ImportFailure(symbol~ : String, message~ : String)
  ResourceLimit(@runtime.ResourceLimitKind)
  Trap(detail~ : String)
  InternalFailure(detail~ : String)
} derive(Debug)
