///|
/// Elaborates a linked entry into the deterministic whole-program form required
/// by physical lowering. The entry must belong to `linked`; every intermediate IR
/// is verified and no executable is returned after a failed stage.
pub fn elaborate(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  profile : ExecutionProfile,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  Ok(elaborate_or_raise(linked, selected_entry, profile, None)) catch {
    error => Err(error)
  }
}

///|
/// Stable observation points in the exact order used by executable elaboration.
/// A variant is emitted only after that stage has passed its verifier.
pub(all) enum ExecutableElaborationStage {
  EffectSpecialized(@buslane.VerifiedProgram)
  CoreOptimized(@buslane.VerifiedProgram)
  EffectLowering(@effect_lowering.EffectLoweringSnapshot)
  MonadicContinuationsLifted(@buslane.VerifiedProgram)
  CpsCoreOptimized(@buslane.VerifiedProgram)
}

///|
/// Elaborates while synchronously reporting each verified stage. Observation
/// stops at the first failure and does not transfer ownership of compiler state.
pub fn elaborate_observed(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  profile : ExecutionProfile,
  observe : (ExecutableElaborationStage) -> Unit,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  Ok(elaborate_or_raise(linked, selected_entry, profile, Some(observe))) catch {
    error => Err(error)
  }
}

///|
fn elaborate_or_raise(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  profile : ExecutionProfile,
  observe : ((ExecutableElaborationStage) -> Unit)?,
) -> ExecutableProgram raise ExecutableElaborationError {
  if !linked.entries.any(entry => entry == selected_entry) {
    raise EntryNotLinked(selected_entry.value)
  }
  validate_executable_entry(
    linked.program.program().metadata,
    selected_entry,
    profile,
  )
  let program = linked.program
  let externals = linked.externals
  let entry = selected_entry
  let program = @effect_specialization.specialize(program, entry.value) catch {
    error => raise effect_specialization_elaboration_error(error)
  }
  observe_executable_stage(observe, EffectSpecialized(program))
  let initializer_roots = collect_reachable_initializer_roots(
    program.program(),
    entry.value,
  )
  let program = match
    @core_opt.optimize({
      program,
      entry: entry.value,
      roots: initializer_roots,
    }) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  observe_executable_stage(observe, CoreOptimized(program))
  let lowered = lower_effects(program, entry.value, observe)
  let program = lowered.program
  let raw_program = program.program()
  let initializer_roots = collect_initializer_roots(raw_program)
  let retained_values = collect_retained_values(
    raw_program,
    entry.value,
    initializer_roots,
  )
  {
    program,
    externals,
    entry,
    retained_values,
    function_origins: lowered.function_origins,
  }
}

///|
fn collect_retained_values(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let occurrence = @occurrence.analyze({ program, entry, roots, })
  let retained = []
  for term in program.terms {
    match term {
      Let(value, _) | External(value) =>
        if occurrence_value_is_reachable(occurrence, value) {
          retained.push(value)
        }
      LetRec(bindings) =>
        for binding in bindings {
          if occurrence_value_is_reachable(occurrence, binding.id) {
            retained.push(binding.id)
          }
        }
    }
  }
  retained
}

///|
fn effect_specialization_elaboration_error(
  error : @effect_specialization.SpecializationError,
) -> ExecutableElaborationError {
  match error {
    UnsupportedProgram(context) =>
      UnsupportedEffectSpecialization(detail=context.detail)
    error => EffectSpecializationCompilerDefect(error)
  }
}

///|
fn lower_effects(
  program : @buslane.VerifiedProgram,
  entry : @buslane.ValueId,
  observe : ((ExecutableElaborationStage) -> Unit)?,
) -> @effect_lowering.EffectLoweringResult raise ExecutableElaborationError {
  let lifted = match observe {
    None => unwrap_effect_lowering(@effect_lowering.lower_effects(program))
    Some(emit) =>
      unwrap_effect_lowering(
        @effect_lowering.lower_effects_observed(program, snapshot => {
          emit(EffectLowering(snapshot))
        }),
      )
  }
  observe_executable_stage(observe, MonadicContinuationsLifted(lifted.program))
  let initializer_roots = collect_reachable_initializer_roots(
    lifted.program.program(),
    entry,
  )
  let optimized = match
    @core_opt.optimize_preserving_function_origins(
      { program: lifted.program, entry, roots: initializer_roots, },
      lifted.function_origins,
    ) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  observe_executable_stage(observe, CpsCoreOptimized(optimized))
  { ..lifted, program: optimized, }
}

///|
fn observe_executable_stage(
  observe : ((ExecutableElaborationStage) -> Unit)?,
  stage : ExecutableElaborationStage,
) -> Unit {
  if observe is Some(emit) {
    emit(stage)
  }
}

///|
fn[T] unwrap_effect_lowering(
  result : Result[T, @effect_lowering.SynthesisError],
) -> T raise ExecutableElaborationError {
  match result {
    Ok(value) => value
    Err(error) => raise EffectLoweringError(error)
  }
}

///|
fn collect_reachable_initializer_roots(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> Array[@buslane.ValueId] {
  let occurrence = @occurrence.analyze({ program, entry, roots: [], })
  let roots = []
  for term in program.terms {
    match term {
      Let(value, expression) =>
        if !is_static_top_level_expression(program, expression) &&
          occurrence_value_is_reachable(occurrence, value) {
          roots.push(value)
        }
      LetRec(bindings) =>
        if !bindings.all(binding => {
            is_static_top_level_expression(program, binding.rhs)
          }) {
          for binding in bindings {
            if occurrence_value_is_reachable(occurrence, binding.id) {
              roots.push(binding.id)
            }
          }
        }
      External(_) => ()
    }
  }
  roots
}

///|
fn occurrence_value_is_reachable(
  occurrence : @occurrence.OccurrenceSummary,
  value : @buslane.ValueId,
) -> Bool {
  match occurrence.facts.get(value.index) {
    Some(fact) => fact.reachable_from_entry
    None => false
  }
}

///|
fn collect_initializer_roots(
  program : @buslane.Program,
) -> Array[@buslane.ValueId] {
  let roots = []
  for term in program.terms {
    match term {
      Let(value, expression) =>
        if !is_static_top_level_expression(program, expression) {
          roots.push(value)
        }
      LetRec(bindings) =>
        if !bindings.all(binding => {
            is_static_top_level_expression(program, binding.rhs)
          }) {
          for binding in bindings {
            roots.push(binding.id)
          }
        }
      External(_) => ()
    }
  }
  roots
}

///|
fn is_static_top_level_expression(
  program : @buslane.Program,
  expression : @buslane.Expr,
) -> Bool {
  match expression {
    Function(_) => true
    Ref(value) =>
      match program.metadata.value_info(value) {
        Some(info) => top_level_type_is_callable(info.type_)
        None => false
      }
    TypeLambda(_, body) | TypeApply(body, _) =>
      is_static_top_level_expression(program, body)
    _ => false
  }
}

///|
fn top_level_type_is_callable(type_ : @buslane.Type) -> Bool {
  match type_ {
    Function(_, _, _) => true
    Forall(_, body) | TypeLambda(_, body) => top_level_type_is_callable(body)
    _ => false
  }
}
