///|
/// Elaborates a linked entry into the deterministic whole-program form required
/// by LoisVM lowering. The entry must belong to `linked`; every intermediate IR
/// is verified and no executable is returned after a failed stage.
pub fn elaborate(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  profile : ExecutionProfile,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  elaborate_observed(linked, selected_entry, profile, _ => ())
}

///|
/// Stable observation points in the exact order used by executable elaboration.
/// A variant is emitted only after that stage has passed its verifier.
pub(all) enum ExecutableElaborationStage {
  EffectSpecialized(@buslane.Program)
  CoreOptimized(@buslane.Program)
  EffectLowering(@effect_lowering.EffectLoweringSnapshot)
  MonadicContinuationsLifted(@buslane.Program)
  CpsCoreOptimized(@buslane.Program)
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
  Ok(elaborate_or_raise(linked, selected_entry, profile, observe)) catch {
    error => Err(error)
  }
}

///|
fn elaborate_or_raise(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  profile : ExecutionProfile,
  observe : (ExecutableElaborationStage) -> Unit,
) -> ExecutableProgram raise ExecutableElaborationError {
  if !linked.entries.any(entry => entry == selected_entry) {
    raise EntryNotLinked(selected_entry.value)
  }
  validate_executable_entry(linked.program.metadata, selected_entry, profile)
  let program = linked.program
  let externals = linked.externals
  let entry = selected_entry
  let program = @effect_specialization.specialize(program, entry.value) catch {
    error => raise effect_specialization_elaboration_error(error)
  }
  require_verified("effect specialization", program)
  observe(EffectSpecialized(program))
  let initializer_roots = collect_reachable_initializer_roots(
    program,
    entry.value,
  )
  let program = match
    @core_opt.optimize({ program, entry: entry.value, roots: initializer_roots }) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  require_verified("core optimization", program)
  observe(CoreOptimized(program))
  let program = lower_effects(program, entry.value, observe)
  let initializer_roots = collect_initializer_roots(program)
  { program, externals, entry, initializer_roots }
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
  program : @buslane.Program,
  entry : @buslane.ValueId,
  observe : (ExecutableElaborationStage) -> Unit,
) -> @buslane.Program raise ExecutableElaborationError {
  let lifted = unwrap_effect_lowering(
    @effect_lowering.lower_effects(program, snapshot => {
      observe(EffectLowering(snapshot))
    }),
  )
  observe(MonadicContinuationsLifted(lifted))
  let initializer_roots = collect_reachable_initializer_roots(lifted, entry)
  let optimized = match
    @core_opt.optimize({ program: lifted, entry, roots: initializer_roots }) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  require_verified("CPS core optimization", optimized)
  observe(CpsCoreOptimized(optimized))
  optimized
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
  let occurrence = @occurrence.analyze({ program, entry, roots: [] })
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

///|
/// Rejects a program the Buslane verifier does not accept.
///
/// Effect lowering assumes its input is well typed, and every later stage
/// assumes the same of what it produces. Nothing checked either until now,
/// which is how a representation that lied about effects survived long enough
/// to delete a handler installation.
fn require_verified(
  stage : String,
  program : @buslane.Program,
) -> Unit raise ExecutableElaborationError {
  let result = @buslane.verify_program(program)
  if !result.is_ok() {
    raise UnverifiedProgram(stage~, result~)
  }
}
