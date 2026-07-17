///|
pub(all) struct ExploreStage {
  id : String
  title : String
  text : String
} derive(Debug, Eq)

///|
pub(all) struct ExploreRequest {
  root_source : @module_frontend.SourceInput
  library_sources : Array[@module_frontend.SourceInput]
  entry : String
} derive(Debug, Eq)

///|
pub(all) struct ExploreReport {
  schema_version : Int
  entry : String
  stages : Array[ExploreStage]
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
  failure : String?
} derive(Debug, Eq)

///|
pub(all) struct EntrySummary {
  module_path_text : String
  name : String
  type_text : String
} derive(Debug, Eq)

///|
pub(all) struct EntryReport {
  schema_version : Int
  entries : Array[EntrySummary]
  diagnostics : Array[@compiler_diag.CompilerDiagnostic]
} derive(Debug, Eq)

///|
pub fn list_entries(
  root_source : @module_frontend.SourceInput,
  library_sources : Array[@module_frontend.SourceInput],
) -> EntryReport {
  let compiled = @compile.compile_source_inputs(root_source, library_sources)
  {
    schema_version: 1,
    entries: compiled.entries.map(entry => {
      module_path_text: entry.module_path_text,
      name: entry.name,
      type_text: @prettyprinter.render(entry.type_, width=100),
    }),
    diagnostics: compiled.diagnostics,
  }
}

///|
pub fn explore(request : ExploreRequest) -> ExploreReport {
  let stages : Array[ExploreStage] = []
  let diagnostics : Array[@compiler_diag.CompilerDiagnostic] = []
  let parsed = @module_frontend.parse_module_inputs(
    request.root_source,
    request.library_sources,
  )
  guard parsed.modules.get(0) is Some(root_input) else {
    return failed_report(
      request.entry,
      stages,
      parsed.diagnostics,
      if parsed.diagnostics.is_empty() {
        Some("compiler parser produced no root module")
      } else {
        None
      },
    )
  }
  stages.push(
    stage(
      "syntax",
      "Syntax AST",
      @prettyprinter.render(root_input.source, width=100),
    ),
  )
  if !parsed.diagnostics.is_empty() {
    return failed_report(request.entry, stages, parsed.diagnostics, None)
  }
  let inputs : @module_frontend.ModuleInputSet = {
    root_module_path_text: root_input.header.module_path_text,
    modules: parsed.modules,
  }
  let graph = match @module_frontend.build_module_graph(inputs) {
    Ok(graph) => graph
    Err(errors) => return failed_report(request.entry, stages, errors, None)
  }
  let modules = match
    @module_compile.compile_module_graph_observed(graph, (
      module_path_text,
      observed,
    ) => {
      if module_path_text == root_input.header.module_path_text {
        match observed {
          Resolved(source) =>
            stages.push(
              stage(
                "resolved",
                "Resolved AST",
                @prettyprinter.render(source, width=100),
              ),
            )
        }
      }
    }) {
    Ok(modules) => modules
    Err(errors) => return failed_report(request.entry, stages, errors, None)
  }
  diagnostics.append(modules.diagnostics)
  guard @module_compile.find_compiled_module(
      modules.modules,
      modules.root_module_path_text,
    )
    is Some(root_module) else {
    return failed_report(
      request.entry,
      stages,
      diagnostics,
      Some("compiler produced no root module"),
    )
  }
  stages.push(
    stage(
      "checked",
      "Checked Source AST",
      @prettyprinter.render(root_module.object.checked, width=100),
    ),
  )
  stages.push(
    stage(
      "buslane.module",
      "Buslane (Module Lowering)",
      @prettyprinter.render(
        @buslane.Program::{
          metadata: root_module.object.metadata,
          terms: root_module.object.terms,
        },
        width=100,
      ),
    ),
  )
  let linked = @module_compile.link_compiled_module_set(modules)
  diagnostics.clear()
  diagnostics.append(linked.diagnostics)
  guard linked.program is Some(linked_program) else {
    return failed_report(request.entry, stages, diagnostics, None)
  }
  stages.push(
    buslane_stage("buslane.linked", "Buslane (Linking)", linked_program.program),
  )
  guard select_entry(linked_program.entries, request.entry) is Some(entry) else {
    return failed_report(
      request.entry,
      stages,
      diagnostics,
      Some("entry `\{request.entry}` was not found or is ambiguous"),
    )
  }
  let executable = match
    @executable.elaborate_observed(linked_program, entry, observed => {
      stages.push(executable_stage(observed))
    }) {
    Ok(executable) => executable
    Err(error) =>
      return failed_report(
        request.entry,
        stages,
        diagnostics,
        Some("executable elaboration failed: \{to_repr(error)}"),
      )
  }
  stages.push(
    stage(
      "executable",
      "Executable Program (Whole-Program Elaboration)",
      @prettyprinter.render(executable, width=100),
    ),
  )
  let image = match
    @loisvm_lowering.lower_executable_program_to_bytecode_observed(executable, observed => {
      match observed {
        Anf(program) =>
          stages.push(
            stage("anf", "ANF", @prettyprinter.render(program, width=100)),
          )
        InitialVmcfg(image) =>
          stages.push(
            stage(
              "vmcfg.initial",
              "VM CFG (Initial Lowering)",
              @prettyprinter.render(image, width=100),
            ),
          )
      }
    }) {
    Ok(image) => image
    Err(error) =>
      return failed_report(
        request.entry,
        stages,
        diagnostics,
        Some("LoisVM lowering failed: \{to_repr(error)}"),
      )
  }
  stages.push(
    stage(
      "loisvm.bytecode",
      "LoisVM Bytecode (ARC and Slot Finalization)",
      @prettyprinter.render(image, width=100),
    ),
  )
  let wasm_module = match @wasm_compiler.compile(image) {
    Ok(wasm_module) => wasm_module
    Err(error) =>
      return failed_report(
        request.entry,
        stages,
        diagnostics,
        Some("Wasm lowering failed: \{to_repr(error)}"),
      )
  }
  stages.push(
    stage(
      "wasm",
      "Wasm (LoisVM Backend Lowering)",
      @wasm_compiler.module_to_wat(wasm_module),
    ),
  )
  {
    schema_version: 1,
    entry: request.entry,
    stages,
    diagnostics,
    failure: None,
  }
}

///|
fn executable_stage(
  observed : @executable.ExecutableElaborationStage,
) -> ExploreStage {
  match observed {
    EffectSpecialized(program) =>
      buslane_stage(
        "buslane.effect-specialized", "Buslane (Reachable Effect Specialization)",
        program,
      )
    HandlersElaborated(program) =>
      stage(
        "buslane.handlers-elaborated",
        "Buslane (Handler Elaboration)",
        @prettyprinter.render(program, width=100),
      )
    MonadicTransformed(program) =>
      stage(
        "buslane.monadic",
        "Buslane (Monadic Transformation)",
        @prettyprinter.render(program, width=100),
      )
    SelectiveCpsRewritten(program) =>
      stage(
        "buslane.selective-cps",
        "Buslane (Selective CPS)",
        @prettyprinter.render(program, width=100),
      )
    OpenContextsResolved(program) =>
      stage(
        "buslane.open-context-resolved",
        "Buslane (Open Context Resolution)",
        @prettyprinter.render(program, width=100),
      )
    MonadicContinuationsLifted(program) =>
      buslane_stage("buslane.monadic-lifted", "Buslane (Monadic Lift)", program)
    CoreOptimized(program) =>
      buslane_stage(
        "buslane.core-optimized", "Buslane (Effect-Aware Core Optimization)", program,
      )
    EffectsErased(program) =>
      buslane_stage(
        "buslane.effects-erased", "Buslane (Effect Erasure)", program,
      )
  }
}

///|
fn buslane_stage(
  id : String,
  title : String,
  program : @buslane.Program,
) -> ExploreStage {
  stage(id, title, @prettyprinter.render(program, width=100))
}

///|
fn stage(id : String, title : String, text : String) -> ExploreStage {
  { id, title, text }
}

///|
fn failed_report(
  entry : String,
  stages : Array[ExploreStage],
  diagnostics : Array[@compiler_diag.CompilerDiagnostic],
  failure : String?,
) -> ExploreReport {
  { schema_version: 1, entry, stages, diagnostics, failure }
}

///|
fn select_entry(
  entries : Array[@buslane_lowering.BuslaneEntry],
  name : String,
) -> @buslane_lowering.BuslaneEntry? {
  let matched = entries.filter(entry => entry.name == name)
  if matched.length() == 1 {
    Some(matched[0])
  } else {
    None
  }
}
