///|
pub fn elaborate(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  elaborate_observed(linked, selected_entry, _ => ())
}

///|
pub(all) enum ExecutableElaborationStage {
  EffectSpecialized(@buslane.Program)
  HandlersElaborated(@effect_lowering_core.Program)
  MonadicTransformed(@effect_lowering_core.Program)
  SelectiveCpsRewritten(@effect_lowering_core.Program)
  OpenContextsResolved(@effect_lowering_core.Program)
  MonadicContinuationsLifted(@buslane.Program)
  CoreOptimized(@buslane.Program)
  EffectsErased(@buslane.Program)
}

///|
pub fn elaborate_observed(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  observe : (ExecutableElaborationStage) -> Unit,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  Ok(elaborate_or_raise(linked, selected_entry, observe)) catch {
    error => Err(error)
  }
}

///|
fn elaborate_or_raise(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
  observe : (ExecutableElaborationStage) -> Unit,
) -> ExecutableProgram raise ExecutableElaborationError {
  if !linked.entries.any(entry => entry == selected_entry) {
    raise EntryNotLinked(selected_entry.value)
  }
  validate_executable_entry(linked.program.metadata, selected_entry)
  let program = linked.program
  let externals = linked.externals
  let entry = selected_entry
  let program = specialize_reachable_effects(program, entry.value)
  observe(EffectSpecialized(program))
  let lowered = lower_effects(program, entry.value, observe)
  let program = lowered.program
  let initializers = collect_top_level_initializers(program)
  let execution_roots = initializers.mapi((index, _) => Initializer(index))
  execution_roots.push(Entry(entry.value))
  {
    module_path_texts: linked.module_path_texts,
    program,
    externals,
    entry,
    initializers,
    execution_roots,
    effect_companions: lowered.effect_companions,
  }
}

///|
priv struct LoweredEffects {
  program : @buslane.Program
  effect_companions : Array[@effect_lowering_cps.EffectCompanionBinding]
}

///|
fn lower_effects(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  observe : (ExecutableElaborationStage) -> Unit,
) -> LoweredEffects raise ExecutableElaborationError {
  let elaborated = @effect_lowering_core.elaborate_handlers(program)
  observe(HandlersElaborated(elaborated))
  let bound = unwrap_effect_lowering(
    @effect_lowering_core.introduce_monadic_binds(elaborated),
  )
  observe(MonadicTransformed(bound))
  let transformed = unwrap_effect_lowering(
    @effect_lowering_cps.rewrite_selective_cps_abis_with_companions(bound),
  )
  observe(SelectiveCpsRewritten(transformed.program))
  let resolved = unwrap_effect_lowering(
    @effect_lowering_core.resolve_open_contexts(transformed.program),
  )
  observe(OpenContextsResolved(resolved))
  let lifted = unwrap_effect_lowering(
    @effect_lowering_core.lift_monadic_continuations(resolved),
  )
  observe(MonadicContinuationsLifted(lifted))
  let initializer_roots = collect_reachable_initializer_roots(lifted, entry)
  let optimized = match
    @core_opt.optimize({ program: lifted, entry, roots: initializer_roots }) {
    Ok(program) => program
    Err(error) => raise CoreOptimizationError(error)
  }
  observe(CoreOptimized(optimized))
  let erased = @effect_lowering_core.erase_residual_effects(optimized)
  observe(EffectsErased(erased))
  { program: erased, effect_companions: transformed.effect_companions }
}

///|
fn[T] unwrap_effect_lowering(
  result : Result[T, @effect_lowering_core.SynthesisError],
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
fn collect_top_level_initializers(
  program : @buslane.Program,
) -> Array[TopLevelInitializer] {
  let initializers = []
  for term in program.terms {
    match term {
      Let(value, expression) =>
        if !is_static_top_level_expression(program, expression) {
          initializers.push(Value(value, expression))
        }
      LetRec(bindings) =>
        if !bindings.all(binding => {
            is_static_top_level_expression(program, binding.rhs)
          }) {
          initializers.push(Recursive(bindings))
        }
      External(_) => ()
    }
  }
  initializers
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
