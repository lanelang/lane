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
      to_repr(executable).to_string(),
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
              to_repr(image).to_string(),
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
      @bytecode.bytecode_image_to_disassembly(image),
    ),
  )
  let signatures = match
    runtime_import_signatures(image, executable.externals) {
    Ok(signatures) => signatures
    Err(message) =>
      return failed_report(request.entry, stages, diagnostics, Some(message))
  }
  let wasm_module = match
    @wasm_compiler.compile_with_runtime_imports(image, signatures) {
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
      to_repr(wasm_module).to_string(),
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
        to_repr(program).to_string(),
      )
    MonadicTransformed(program) =>
      stage(
        "buslane.monadic",
        "Buslane (Monadic Transformation)",
        to_repr(program).to_string(),
      )
    SelectiveCpsRewritten(program) =>
      stage(
        "buslane.selective-cps",
        "Buslane (Selective CPS)",
        to_repr(program).to_string(),
      )
    OpenContextsResolved(program) =>
      stage(
        "buslane.open-context-resolved",
        "Buslane (Open Context Resolution)",
        to_repr(program).to_string(),
      )
    MonadicContinuationsLifted(program) =>
      buslane_stage("buslane.monadic-lifted", "Buslane (Monadic Lift)", program)
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

///|
fn runtime_import_signatures(
  image : @bytecode.BytecodeImage,
  externals : @buslane_lowering.BuslaneExternalMap,
) -> Result[Array[@wasm_compiler.RuntimeImportSignature], String] {
  let signatures = []
  for function in image.functions {
    guard function is RuntimeImport(import_) else { continue }
    guard find_runtime_import(externals.runtime_imports, import_.symbol)
      is Some(external) else {
      return Err(
        "missing checked signature for runtime import `\{import_.symbol}`",
      )
    }
    guard external.type_ is Function(parameters, result, _) else {
      return Err("runtime import `\{import_.symbol}` is not a function")
    }
    let primitive_parameters = []
    for parameter in parameters {
      match primitive_kind(parameter) {
        Some(kind) => primitive_parameters.push(kind)
        None =>
          return Err(
            "runtime import `\{import_.symbol}` has a non-primitive parameter",
          )
      }
    }
    guard primitive_kind(result) is Some(primitive_result) else {
      return Err(
        "runtime import `\{import_.symbol}` has a non-primitive result",
      )
    }
    signatures.push(
      @wasm_compiler.RuntimeImportSignature::new(
        symbol=import_.symbol,
        parameters=primitive_parameters,
        result=primitive_result,
      ),
    )
  }
  Ok(signatures)
}

///|
fn primitive_kind(type_ : @buslane.Type) -> @loisvm_runtime.PrimitiveKind? {
  match type_ {
    Primitive(Unit) => Some(Unit)
    Primitive(Bool) => Some(Bool)
    Primitive(Int) => Some(Int)
    Primitive(Double) => Some(Double)
    Primitive(String) => Some(String)
    _ => None
  }
}

///|
fn find_runtime_import(
  imports : Array[@buslane_lowering.BuslaneRuntimeImport],
  symbol : String,
) -> @buslane_lowering.BuslaneRuntimeImport? {
  for import_ in imports {
    if import_.symbol == symbol {
      return Some(import_)
    }
  }
  None
}
