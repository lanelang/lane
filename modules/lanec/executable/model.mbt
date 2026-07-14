///|
pub(all) struct ExecutableProgram {
  module_path_texts : Array[String]
  program : @buslane.Program
  externals : @buslane_lowering.BuslaneExternalMap
  entry : @buslane_lowering.BuslaneEntry
  initializers : Array[TopLevelInitializer]
  runtime_boundary : RuntimeBoundary
  execution_roots : Array[ExecutionRoot]
} derive(Debug, Eq)

///|
pub(all) enum TopLevelInitializer {
  Value(@buslane.ValueId, @buslane.Expr)
  Recursive(Array[@buslane.RecursiveBinding])
} derive(Debug, Eq)

///|
pub(all) enum ExecutionRoot {
  Initializer(Int)
  Entry(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) struct RuntimeBoundary {
  effect_operations : Array[@module_link.LinkedRuntimeEffectOperation]
} derive(Debug, Eq)

///|
pub(all) suberror ExecutableElaborationError {
  EntryNotLinked(@buslane.ValueId)
  InvalidEntryFunction(value~ : @buslane.ValueId, type_~ : @buslane.Type)
  UnsupportedRuntimeBoundary(detail~ : String)
  EffectLoweringError(@effect_lowering.SynthesisError)
} derive(Debug, Eq)
