///|
/// Checks one in-memory Lane source module.
pub fn check_source(source : String) -> CompilationOutcome[Unit] {
  check({ root: { source_id: "<root>", text: source }, libraries: [] })
}

///|
/// Checks a source set without linking it.
pub fn check(request : CompilationRequest) -> CompilationOutcome[Unit] {
  discard_checked_source(check_request(request))
}

///|
fn check_request(
  request : CompilationRequest,
) -> CompilationOutcome[@checked.CheckedSourceFile] {
  match compile_module_set(request, _ => ()) {
    Ok(modules) =>
      match
        @module_compile.find_compiled_module(
          modules.modules,
          modules.root_module_path_text,
        ) {
        Some(root) =>
          compilation_succeeded(root.object.checked, modules.diagnostics)
        None =>
          compilation_failed([
            @module_compile.no_root_source_module_diagnostic(),
          ])
      }
    Err(diagnostics) => compilation_failed(diagnostics)
  }
}

///|
/// Checks one source module against persisted module interfaces.
pub fn check_with_interfaces(
  request : InterfaceCompilationRequest,
) -> CompilationOutcome[Unit] {
  discard_checked_source(check_interface_request(request))
}

///|
fn check_interface_request(
  request : InterfaceCompilationRequest,
) -> CompilationOutcome[@checked.CheckedSourceFile] {
  match
    @module_compile.compile_module_from_interface_artifacts(
      request.root.to_frontend(),
      request.interfaces,
    ) {
    Ok(modules) =>
      match
        @module_compile.find_compiled_module(
          modules.modules,
          modules.root_module_path_text,
        ) {
        Some(root) =>
          compilation_succeeded(root.object.checked, modules.diagnostics)
        None =>
          compilation_failed([
            @module_compile.no_root_source_module_diagnostic(),
          ])
      }
    Err(diagnostics) => compilation_failed(diagnostics)
  }
}

///|
fn discard_checked_source(
  outcome : CompilationOutcome[@checked.CheckedSourceFile],
) -> CompilationOutcome[Unit] {
  match outcome {
    Succeeded(_, warnings) => Succeeded((), warnings)
    Failed(failure) => Failed(failure)
  }
}

///|
/// Compiles one in-memory Lane source module through linking.
pub fn compile_source(source : String) -> CompilationOutcome[CompiledProgram] {
  compile({ root: { source_id: "<root>", text: source }, libraries: [] })
}

///|
/// Compiles and links a source set.
pub fn compile(
  request : CompilationRequest,
) -> CompilationOutcome[CompiledProgram] {
  match compile_module_set(request, _ => ()) {
    Ok(modules) =>
      linked_outcome(@module_compile.link_compiled_module_set(modules))
    Err(diagnostics) => compilation_failed(diagnostics)
  }
}

///|
/// Compiles a source set into separate modules without linking it.
pub fn compile_modules(
  request : CompilationRequest,
) -> CompilationOutcome[CompiledModules] {
  compile_modules_observed(request, _ => ())
}

///|
/// Compiles modules while reporting stable, rendered stage snapshots.
pub fn compile_modules_observed(
  request : CompilationRequest,
  observe : (SourceCompilationStage) -> Unit,
) -> CompilationOutcome[CompiledModules] {
  match compile_module_set(request, observe) {
    Ok(modules) => compilation_succeeded({ modules, }, modules.diagnostics)
    Err(diagnostics) => compilation_failed(diagnostics)
  }
}

///|
/// Compiles one source module against persisted module interfaces.
pub fn compile_module_with_interfaces(
  request : InterfaceCompilationRequest,
) -> CompilationOutcome[CompiledModules] {
  match
    @module_compile.compile_module_from_interface_artifacts(
      request.root.to_frontend(),
      request.interfaces,
    ) {
    Ok(modules) => compilation_succeeded({ modules, }, modules.diagnostics)
    Err(diagnostics) => compilation_failed(diagnostics)
  }
}

///|
/// Links modules produced by this facade.
pub fn link_modules(
  modules : CompiledModules,
) -> CompilationOutcome[CompiledProgram] {
  linked_outcome(@module_compile.link_compiled_module_set(modules.modules))
}

///|
/// Validates and links persisted module object artifacts.
pub fn link_module_objects(
  objects : Array[@artifact.ModuleObjectArtifact],
) -> CompilationOutcome[CompiledProgram] {
  linked_outcome(@artifact.link_module_object_artifacts(objects))
}

///|
fn linked_outcome(
  linked : @module_link.LinkResult,
) -> CompilationOutcome[CompiledProgram] {
  match linked.program {
    Some(program) =>
      compilation_succeeded({ linked: program }, linked.diagnostics)
    None => compilation_failed(linked.diagnostics)
  }
}

///|
fn compile_module_set(
  request : CompilationRequest,
  observe : (SourceCompilationStage) -> Unit,
) -> Result[@module_compile.CompiledModuleSet, Array[CompilerDiagnostic]] {
  match
    @module_frontend.parse_import_reachable_module_input_set_from_inputs_observed(
      request.root.to_frontend(),
      request.libraries.map(SourceInput::to_frontend),
      root => {
        observe(
          Syntax({
            module_path_text: root.header.module_path_text,
            text: @prettyprinter.render(root.source, width=100),
          }),
        )
      },
    ) {
    Err(diagnostics) => Err(diagnostics)
    Ok(inputs) =>
      match @module_frontend.build_module_graph(inputs) {
        Err(diagnostics) => Err(diagnostics)
        Ok(graph) =>
          @module_compile.compile_module_graph_observed(graph, (
            module_path_text,
            stage,
          ) => {
            let snapshot = match stage {
              Resolved(source) =>
                SourceCompilationStage::Resolved({
                  module_path_text,
                  text: render_resolved_source(source, 100),
                })
              Checked(source) =>
                Checked({
                  module_path_text,
                  text: render_checked_source(source, 100),
                })
              BuslaneModule(program) =>
                BuslaneModule({
                  module_path_text,
                  text: render_buslane_program(program, 100),
                })
            }
            observe(snapshot)
          })
      }
  }
}

///|
fn SourceInput::to_frontend(self : SourceInput) -> @module_frontend.SourceInput {
  { source_id: self.source_id, text: self.text }
}
