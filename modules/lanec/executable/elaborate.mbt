///|
pub fn elaborate(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
) -> Result[ExecutableProgram, ExecutableElaborationError] {
  Ok(elaborate_or_raise(linked, selected_entry)) catch {
    error => Err(error)
  }
}

///|
fn elaborate_or_raise(
  linked : @module_link.LinkedProgram,
  selected_entry : @buslane_lowering.BuslaneEntry,
) -> ExecutableProgram raise ExecutableElaborationError {
  if !linked.entries.any(entry => entry == selected_entry) {
    raise EntryNotLinked(selected_entry.value)
  }
  let (program, externals, entry, effect_operations) = install_runtime_boundary(
    linked.program,
    linked.externals,
    selected_entry,
    linked.runtime_effect_operations,
  )
  let lowered = lower_effects(program)
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
    runtime_boundary: { effect_operations, },
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
) -> LoweredEffects raise ExecutableElaborationError {
  let elaborated = @effect_lowering.elaborate_handlers(program)
  let bound = unwrap_effect_lowering(
    @effect_lowering.introduce_monadic_binds(elaborated),
  )
  let transformed = unwrap_effect_lowering(
    @effect_lowering_cps.rewrite_selective_cps_abis_with_companions(bound),
  )
  let resolved = unwrap_effect_lowering(
    @effect_lowering.resolve_open_contexts(transformed.program),
  )
  {
    program: unwrap_effect_lowering(
      @effect_lowering.lift_monadic_continuations(resolved),
    ),
    effect_companions: transformed.effect_companions,
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
fn collect_top_level_initializers(
  program : @buslane.Program,
) -> Array[TopLevelInitializer] {
  let initializers = []
  for term in program.terms {
    match term {
      Let(value, expression) =>
        if !is_static_top_level_expression(expression) {
          initializers.push(Value(value, expression))
        }
      LetRec(bindings) =>
        if !bindings.all(binding => is_static_top_level_expression(binding.rhs)) {
          initializers.push(Recursive(bindings))
        }
      External(_) => ()
    }
  }
  initializers
}

///|
fn is_static_top_level_expression(expression : @buslane.Expr) -> Bool {
  match expression {
    Function(_) => true
    TypeLambda(_, body) => is_static_top_level_expression(body)
    _ => false
  }
}
