///|
pub(all) enum ResourceLimitKind {
  LiveHeapBytes
} derive(Debug, Eq)

///|
pub(all) suberror ExecutionError {
  Fatal(message~ : String)
  ExecutionResourceLimit(kind~ : ResourceLimitKind)
  Interrupted
  EngineTrap(detail~ : String)
  InternalRuntimeFailure(detail~ : String)
  InstanceNotReady
} derive(Debug, Eq)

///|
pub(all) struct ExecutionConfig {
  max_live_heap_bytes : Int?
} derive(Debug, Eq)

///|
pub fn ExecutionConfig::defaults() -> ExecutionConfig {
  { max_live_heap_bytes: None, }
}
