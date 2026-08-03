///|
/// The source identity most relevant to a specialization failure.
pub(all) enum SpecializationSource {
  Value(@buslane.ValueId)
  TypeParameter(@buslane.TypeParameterId)
  Type(@buslane.TypeId)
  DataConstructor(@buslane.DataConId)
  Effect(@buslane.EffectId)
  Operation(@buslane.OperationId)
} derive(Debug, Eq)

///|
/// Structured context retained across specialization phase adapters.
///
/// An invariant variant supplies the phase. `site` locates the callable being
/// processed, `source` locates the metadata identity involved, and
/// `specialization_key` records the concrete effect arguments selecting an
/// instance.
pub(all) struct SpecializationErrorContext {
  detail : String
  site : SpecializationDefinitionSite?
  source : SpecializationSource?
  specialization_key : Array[EffectSpecializationBinding]
} derive(Debug, Eq)

///|
fn specialization_error_context(
  detail : String,
  site? : SpecializationDefinitionSite,
  source? : SpecializationSource,
  specialization_key? : Array[EffectSpecializationBinding],
) -> SpecializationErrorContext {
  { detail, site, source, specialization_key: specialization_key.unwrap_or([]) }
}

///|
fn SpecializationErrorContext::at_planner_visit(
  self : SpecializationErrorContext,
  site : SpecializationDefinitionSite,
  specialization_key : Array[EffectSpecializationBinding],
) -> SpecializationErrorContext {
  { ..self, site: Some(site), specialization_key: specialization_key.copy() }
}

///|
fn contextualize_planner_error(
  error : SpecializationError,
  site : SpecializationDefinitionSite,
  specialization_key : Array[EffectSpecializationBinding],
) -> SpecializationError {
  match error {
    UnsupportedProgram(context) =>
      UnsupportedProgram(context.at_planner_visit(site, specialization_key))
    InvalidInputMetadata(context) =>
      InvalidInputMetadata(context.at_planner_visit(site, specialization_key))
    TypeNormalizationCompilerDefect(context, error) =>
      TypeNormalizationCompilerDefect(
        context.at_planner_visit(site, specialization_key),
        error,
      )
    PlannerInvariant(context) =>
      PlannerInvariant(context.at_planner_visit(site, specialization_key))
    AllocatorInvariant(context) => AllocatorInvariant(context)
    RewriterInvariant(context) => RewriterInvariant(context)
  }
}

///|
fn normalize_specialization_input_type(
  type_ : @buslane.Type,
) -> @buslane.Type raise SpecializationError {
  type_.normalize() catch {
    error =>
      raise TypeNormalizationCompilerDefect(
        specialization_error_context(
          "Buslane type normalization failed: \{Repr(error)}",
        ),
        error,
      )
  }
}

///|
fn canonicalize_specialization_input_effect(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
) -> @buslane.Effect raise SpecializationError {
  metadata.canonicalize_effect(effect) catch {
    error =>
      raise TypeNormalizationCompilerDefect(
        specialization_error_context(
          "Buslane effect normalization failed: \{Repr(error)}",
        ),
        error,
      )
  }
}

///|
fn specialization_types_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Type,
  right : @buslane.Type,
) -> Bool raise SpecializationError {
  metadata.types_definitionally_equal(left, right) catch {
    error =>
      raise TypeNormalizationCompilerDefect(
        specialization_error_context(
          "Buslane type normalization failed: \{Repr(error)}",
        ),
        error,
      )
  }
}

///|
fn specialization_effects_definitionally_equal(
  metadata : @buslane.MetadataRegistry,
  left : @buslane.Effect,
  right : @buslane.Effect,
) -> Bool raise SpecializationError {
  metadata.effects_definitionally_equal(left, right) catch {
    error =>
      raise TypeNormalizationCompilerDefect(
        specialization_error_context(
          "Buslane effect normalization failed: \{Repr(error)}",
        ),
        error,
      )
  }
}

///|
/// Failures owned by source-effect specialization.
///
/// Only `UnsupportedProgram` describes an ordinary source-program limitation.
/// Every other variant is a compiler defect when reached through the normal
/// executable pipeline.
pub(all) suberror SpecializationError {
  UnsupportedProgram(SpecializationErrorContext)
  InvalidInputMetadata(SpecializationErrorContext)
  TypeNormalizationCompilerDefect(
    SpecializationErrorContext,
    @buslane.TypeNormalizationError
  )
  PlannerInvariant(SpecializationErrorContext)
  AllocatorInvariant(SpecializationErrorContext)
  RewriterInvariant(SpecializationErrorContext)
} derive(Debug, Eq)
