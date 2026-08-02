///|
/// Failures owned by source-effect specialization.
pub(all) suberror SpecializationError {
  Unsupported(detail~ : String)
} derive(Debug, Eq)
