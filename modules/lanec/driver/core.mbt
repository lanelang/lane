///|
priv struct ExploreStageBuilder {
  states : Array[ExploreStageState]
}

///|
/// Compiles and links the source closure and lists entries in deterministic link
/// order. Compilation failure returns an empty entry list plus full diagnostics.
pub fn list_entries(
  root_source : @compile.SourceInput,
  library_sources : Array[@compile.SourceInput],
) -> EntryReport {
  let compiled = @compile.compile({
    root: root_source,
    libraries: library_sources,
  })
  match compiled {
    Succeeded(program, warnings) =>
      {
        schema_version: 1,
        entries: program.entries().map(entry_summary),
        diagnostics: warnings.diagnostics(),
      }
    Failed(failure) =>
      { schema_version: 1, entries: [], diagnostics: failure.diagnostics() }
  }
}

///|
/// Runs the fixed Explore Protocol pipeline from syntax through Wasm and records
/// every completed stage in canonical order. The first failed stage terminates
/// processing; later stages remain unavailable and no partial stage is marked
/// completed.
pub fn explore(request : ExploreRequest) -> ExploreReport {
  let stages = ExploreStageBuilder::new()
  let functions = ExploreFunctionGraphBuilder::new()
  let mut root_module_path_text : String? = None
  let compiled = @compile.compile_modules_observed(
    { root: request.root_source, libraries: request.library_sources },
    observed => {
      match observed {
        Syntax(snapshot) => {
          root_module_path_text = Some(snapshot.module_path_text)
          stages.complete(Syntax, snapshot.text, [], empty_scale())
        }
        Resolved(snapshot) =>
          if root_module_path_text == Some(snapshot.module_path_text) {
            stages.complete(Resolved, snapshot.text, [], empty_scale())
          }
        Checked(snapshot) =>
          if root_module_path_text == Some(snapshot.module_path_text) {
            stages.complete(Checked, snapshot.text, [], empty_scale())
          }
        BuslaneModule(snapshot) =>
          if root_module_path_text == Some(snapshot.module_path_text) {
            stages.complete(BuslaneModule, snapshot.text, [], empty_scale())
          }
      }
    },
  )
  let diagnostics = compiled.diagnostics()
  let modules = match compiled {
    Succeeded(modules, _) => modules
    Failed(_) =>
      return failed_report(
        request,
        root_module_path_text,
        None,
        stages,
        functions,
        diagnostics,
      )
  }
  stages.attach_diagnostics(Checked, diagnostics)
  let linked = @compile.link_modules(modules)
  diagnostics.append(linked.diagnostics())
  let linked_program = match linked {
    Succeeded(program, _) => program
    Failed(_) =>
      return failed_report(
        request,
        root_module_path_text,
        None,
        stages,
        functions,
        diagnostics,
      )
  }
  guard select_entry(linked_program.entries(), request.entry) is Some(entry) else {
    diagnostics.push(
      exploration_error(
        "entry `\{request.entry}` was not found or is ambiguous",
        "exploration requires one artifact-defined entry with the requested name",
      ),
    )
    return failed_report(
      request,
      root_module_path_text,
      None,
      stages,
      functions,
      diagnostics,
    )
  }
  stages.complete(
    BuslaneLinked,
    linked_program.buslane_text(),
    linked.diagnostics(),
    empty_scale(),
  )
  let selected_entry = Some(entry_summary(entry))
  let executable = match
    linked_program.elaborate_entry_observed(entry, observed => {
      let observed = executable_stage(observed)
      stages.complete(observed.0, observed.1, [], observed.2)
    }) {
    Ok(executable) => executable
    Err(error) => {
      diagnostics.push(
        exploration_error("executable elaboration failed", "\{Repr(error)}"),
      )
      return failed_report(
        request, root_module_path_text, selected_entry, stages, functions, diagnostics,
      )
    }
  }
  stages.complete(
    Executable,
    render_buslane_code(executable.program),
    [],
    buslane_scale(executable.program),
  )
  let image = match
    @loisvm_lowering.lower_executable_program_to_bytecode_observed(executable, observed => {
      match observed {
        Anf(program) => {
          let observed = anf_observation(program)
          functions.observe_anf(program.metadata, observed.functions)
          stages.complete(Anf, render_anf_code(program), [], observed.scale)
        }
        InitialVmcfg(image, provenance) => {
          functions.observe_vmcfg(provenance)
          stages.complete(
            VmcfgInitial,
            @vmcfg.image_to_code(image),
            [],
            vmcfg_scale(image, provenance),
          )
        }
        FinalBytecode(image, provenance) => {
          functions.observe_bytecode(provenance)
          stages.complete(
            LoisvmBytecode,
            @bytecode.bytecode_image_to_code(image),
            [],
            bytecode_scale(image, provenance),
          )
        }
      }
    }) {
    Ok(image) => image
    Err(error) => {
      diagnostics.push(
        exploration_error("LoisVM lowering failed", "\{Repr(error)}"),
      )
      return failed_report(
        request, root_module_path_text, selected_entry, stages, functions, diagnostics,
      )
    }
  }
  let wasm = match @wasm_compiler.compile_observed(image) {
    Ok(wasm) => wasm
    Err(error) => {
      diagnostics.push(
        exploration_error("Wasm lowering failed", "\{Repr(error)}"),
      )
      return failed_report(
        request, root_module_path_text, selected_entry, stages, functions, diagnostics,
      )
    }
  }
  functions.observe_wasm(wasm.functions)
  stages.complete(
    Wasm,
    @wasm_compiler.module_to_wat(wasm.module_),
    [],
    wasm_scale(wasm.scale),
  )
  {
    schema_version: explore_report_schema_version,
    compiler: explore_compiler_identity(),
    root: {
      source_id: request.root_source.source_id,
      module_path_text: root_module_path_text,
    },
    selected_entry,
    status: Succeeded,
    diagnostics,
    stages: stages.finish(),
    functions: functions.finish(),
  }
}

///|
fn ExploreStageBuilder::new() -> ExploreStageBuilder {
  let states = []
  for _ in 0..<18 {
    states.push(Unavailable)
  }
  { states, }
}

///|
fn ExploreStageBuilder::complete(
  self : ExploreStageBuilder,
  id : ExploreStageId,
  text : String,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  scale : ExploreScaleObservation,
) -> Unit {
  self.states[id.index()] = Completed({
    domain: id.domain(),
    text_format: id.text_format(),
    text,
    diagnostics,
    scale,
  })
}

///|
fn ExploreStageBuilder::attach_diagnostics(
  self : ExploreStageBuilder,
  id : ExploreStageId,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
) -> Unit {
  if self.states[id.index()] is Completed(snapshot) {
    self.states[id.index()] = Completed({ ..snapshot, diagnostics, })
  }
}

///|
fn ExploreStageBuilder::fail_next(
  self : ExploreStageBuilder,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
) -> ExploreStageId {
  for id in explore_stage_ids() {
    if self.states[id.index()] is Unavailable {
      self.states[id.index()] = Failed(diagnostics)
      return id
    }
  }
  abort("completed exploration cannot fail at another stage")
}

///|
fn ExploreStageBuilder::finish(self : ExploreStageBuilder) -> ExploreStages {
  {
    syntax: self.states[0],
    resolved: self.states[1],
    checked: self.states[2],
    buslane_module: self.states[3],
    buslane_linked: self.states[4],
    buslane_effect_specialized: self.states[5],
    buslane_core_optimized: self.states[6],
    buslane_handlers_elaborated: self.states[7],
    buslane_monadic: self.states[8],
    buslane_selective_cps: self.states[9],
    buslane_open_context_resolved: self.states[10],
    buslane_monadic_lifted: self.states[11],
    buslane_effects_erased: self.states[12],
    executable: self.states[13],
    anf: self.states[14],
    vmcfg_initial: self.states[15],
    loisvm_bytecode: self.states[16],
    wasm: self.states[17],
  }
}

///|
fn explore_stage_ids() -> Array[ExploreStageId] {
  [
    Syntax,
    Resolved,
    Checked,
    BuslaneModule,
    BuslaneLinked,
    BuslaneEffectSpecialized,
    BuslaneCoreOptimized,
    BuslaneHandlersElaborated,
    BuslaneMonadic,
    BuslaneSelectiveCps,
    BuslaneOpenContextResolved,
    BuslaneMonadicLifted,
    BuslaneEffectsErased,
    Executable,
    Anf,
    VmcfgInitial,
    LoisvmBytecode,
    Wasm,
  ]
}

///|
fn failed_report(
  request : ExploreRequest,
  root_module_path_text : String?,
  selected_entry : EntrySummary?,
  stages : ExploreStageBuilder,
  functions : ExploreFunctionGraphBuilder,
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
) -> ExploreReport {
  let failed_stage = stages.fail_next(diagnostics)
  {
    schema_version: explore_report_schema_version,
    compiler: explore_compiler_identity(),
    root: {
      source_id: request.root_source.source_id,
      module_path_text: root_module_path_text,
    },
    selected_entry,
    status: Failed(failed_stage),
    diagnostics,
    stages: stages.finish(),
    functions: functions.finish(),
  }
}

///|
fn explore_compiler_identity() -> ExploreCompilerIdentity {
  { name: "Milky2018/lanec", version: "0.1.0" }
}

///|
fn exploration_error(
  message : String,
  reason : String,
) -> @compiler_diag.CompilerDiagnostic {
  @compiler_diag.compiler_error(
    message,
    span=None,
    code=Some("E6016"),
    labels=[],
    notes=[reason],
    helps=[],
  )
}

///|
fn executable_stage(
  observed : @executable.ExecutableElaborationStage,
) -> (ExploreStageId, String, ExploreScaleObservation) {
  match observed {
    EffectSpecialized(program) =>
      (
        BuslaneEffectSpecialized,
        render_buslane_code(program),
        buslane_scale(program),
      )
    HandlersElaborated(program) =>
      (
        BuslaneHandlersElaborated,
        render_effect_lowering_code(program),
        effect_lowering_scale(program),
      )
    MonadicTransformed(program) =>
      (
        BuslaneMonadic,
        render_effect_lowering_code(program),
        effect_lowering_scale(program),
      )
    SelectiveCpsRewritten(program) =>
      (
        BuslaneSelectiveCps,
        render_effect_lowering_code(program),
        effect_lowering_scale(program),
      )
    OpenContextsResolved(program) =>
      (
        BuslaneOpenContextResolved,
        render_effect_lowering_code(program),
        effect_lowering_scale(program),
      )
    MonadicContinuationsLifted(program) =>
      (
        BuslaneMonadicLifted,
        render_buslane_code(program),
        buslane_scale(program),
      )
    CoreOptimized(program) =>
      (
        BuslaneCoreOptimized,
        render_buslane_code(program),
        buslane_scale(program),
      )
    EffectsErased(program) =>
      (
        BuslaneEffectsErased,
        render_buslane_code(program),
        buslane_scale(program),
      )
  }
}

///|
fn entry_summary(entry : @compile.CompiledEntry) -> EntrySummary {
  {
    module_path_text: entry.module_path_text(),
    name: entry.name(),
    type_text: entry.type_text(),
  }
}

///|
fn select_entry(
  entries : Array[@compile.CompiledEntry],
  name : String,
) -> @compile.CompiledEntry? {
  let matched = entries.filter(entry => entry.name() == name)
  if matched.length() == 1 {
    Some(matched[0])
  } else {
    None
  }
}
