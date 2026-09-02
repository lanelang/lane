///|
/// Elaborates linked exports into the deterministic whole-program form required
/// by physical lowering. Every export must belong to `linked`; every intermediate IR
/// is verified and no executable is returned after a failed stage.
pub fn elaborate(
  linked : @module_link.LinkedProgram,
  requests : Array[ExportRequest],
  profile : ExecutionProfile,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  Ok(elaborate_or_raise(linked, requests, profile, None)) catch {
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
  MonadicContinuationsLifted(@effect_lowering.CpsCoreProgram)
  CpsCoreOptimized(@effect_lowering.CpsCoreProgram)
}

///|
/// Elaborates while synchronously reporting each verified stage. Observation
/// stops at the first failure and does not transfer ownership of compiler state.
pub fn elaborate_observed(
  linked : @module_link.LinkedProgram,
  requests : Array[ExportRequest],
  profile : ExecutionProfile,
  observe : (ExecutableElaborationStage) -> Unit,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  Ok(elaborate_or_raise(linked, requests, profile, Some(observe))) catch {
    error => Err(error)
  }
}

///|
fn elaborate_or_raise(
  linked : @module_link.LinkedProgram,
  requests : Array[ExportRequest],
  profile : ExecutionProfile,
  observe : ((ExecutableElaborationStage) -> Unit)?,
) -> ExecutableProgram raise ExecutableElaborationError {
  if requests.is_empty() {
    raise NoExports
  }
  let exports = []
  let names = []
  for request in requests {
    if request.name == "memory" {
      raise ReservedExportName(request.name)
    }
    if names.contains(request.name) {
      raise DuplicateExportName(request.name)
    }
    names.push(request.name)
    if !linked.entries.any(entry => entry == request.entry) {
      raise EntryNotLinked(request.entry.value)
    }
    exports.push(
      validate_executable_entry(
        linked.program.program().metadata,
        request,
        profile,
      ),
    )
  }
  let program = linked.program
  let externals = linked.externals
  let export_roots = []
  for export_ in exports {
    let value = export_.entry().value
    if !export_roots.contains(value) {
      export_roots.push(value)
    }
  }
  let program = @effect_specialization.specialize(program, export_roots) catch {
    error => raise effect_specialization_elaboration_error(error)
  }
  observe_executable_stage(observe, EffectSpecialized(program))
  let initializer_roots = collect_reachable_initializer_roots(
    program.program(),
    export_roots,
  )
  let optimization_roots = export_roots + initializer_roots
  let program = match
    @core_opt.optimize({ program, roots: optimization_roots, }) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  observe_executable_stage(observe, CoreOptimized(program))
  let cps_core = lower_effects(program, export_roots, observe)
  let raw_program = cps_core.program().program()
  let initializer_roots = collect_initializer_roots(raw_program)
  let retained_values = collect_retained_values(
    raw_program,
    export_roots + initializer_roots,
  )
  { cps_core, externals, exports, retained_values, }
}

///|
fn collect_retained_values(
  program : @buslane.Program,
  roots : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let occurrence = @occurrence.analyze({ program, roots, })
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
  export_roots : Array[@buslane.ValueId],
  observe : ((ExecutableElaborationStage) -> Unit)?,
) -> @effect_lowering.CpsCoreProgram raise ExecutableElaborationError {
  let lifted = match observe {
    None => unwrap_effect_lowering(@effect_lowering.lower_effects(program))
    Some(emit) =>
      unwrap_effect_lowering(
        @effect_lowering.lower_effects_observed(program, snapshot => {
          emit(EffectLowering(snapshot))
        }),
      )
  }
  observe_executable_stage(observe, MonadicContinuationsLifted(lifted))
  let initializer_roots = collect_reachable_initializer_roots(
    lifted.program().program(),
    export_roots,
  )
  let optimized = match
    @core_opt.optimize_cps_core(lifted, export_roots + initializer_roots) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  observe_executable_stage(observe, CpsCoreOptimized(optimized))
  optimized
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
  export_roots : Array[@buslane.ValueId],
) -> Array[@buslane.ValueId] {
  let occurrence = @occurrence.analyze({ program, roots: export_roots, })
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
    Some(fact) => fact.reachable
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
