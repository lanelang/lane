///|
async fn lane_explore(
  file : String,
  entry : String,
  libs : Array[String],
  lib_dirs : Array[String],
  output : String,
  no_basic? : Bool = false,
) -> LaneCommandOutcome {
  let source = read_source_file(file) catch {
    error =>
      return LaneCommandOutcome::user_error(
        CliError::file_io(Read, file, "\{error}"),
      )
  }
  let root : LaneSourceInput = {
    source_id: file,
    path: Some(file),
    text: source,
  }
  let libraries = match
    read_source_command_library_inputs(file, libs, lib_dirs, no_basic~) {
    Ok(libraries) => libraries
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  let diagnostic_sources = LaneSourceInput::diagnostic_sources(root, libraries)
  let report = @driver.explore({
    root_source: root.to_compile_input(),
    library_sources: LaneSourceInput::array_to_compile_inputs(libraries),
    entry,
    execution_profile: lane_command_execution_profile(),
  })
  let html = render_explore_html(report)
  match write_explore_report_atomic(output, html) {
    Ok(_) => ()
    Err(error) => return LaneCommandOutcome::user_error(error)
  }
  if !denied_diagnostics(report.diagnostics, false).is_empty() {
    return LaneCommandOutcome::compile_diagnostics(
      report.diagnostics,
      diagnostic_sources,
      false,
    )
  }
  if !report.diagnostics.is_empty() {
    LaneCommandOutcome::compile_diagnostics(
      report.diagnostics,
      diagnostic_sources,
      true,
    )
  } else {
    Succeeded
  }
}

///|
async fn write_explore_report_atomic(
  output : String,
  html : String,
) -> Result[Unit, CliError] {
  let temporary = "\{output}.tmp"
  @fs.write_file(temporary, html, create_mode=CreateOrTruncate) catch {
    error => return Err(CliError::file_io(Write, output, "\{error}"))
  }
  @fs.rename(temporary, output, replace=true) catch {
    error => {
      @fs.remove(temporary) catch {
        _ => ()
      }
      return Err(CliError::file_io(Write, output, "\{error}"))
    }
  }
  Ok(())
}

///|
fn render_explore_html(report : @driver.ExploreReport) -> String {
  let html = StringBuilder::new()
  let stages = report.stages.ordered()
  html <+
    #|<!doctype html>
    #|<html lang="en">
    #|<head>
    #|<meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width, initial-scale=1">
    #|<title>Lane IR Explorer</title>
    #|<style>
    #|:root{color-scheme:dark;--bg:#0b1020;--panel:#111831;--line:#263152;--text:#e7ecff;--accent:#8aa4ff}
    #|*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 ui-sans-serif,system-ui,sans-serif}
    #|main{display:grid;grid-template-columns:minmax(220px,300px) 1fr;min-height:100vh}nav{padding:16px;border-right:1px solid var(--line);overflow:auto}
    #|button{display:block;width:100%;margin:0 0 8px;padding:10px 12px;border:1px solid var(--line);border-radius:8px;background:var(--panel);color:var(--text);text-align:left;cursor:pointer}
    #|button[aria-selected="true"]{border-color:var(--accent);color:#fff}.content{min-width:0;padding:20px 24px}.stage{display:none}.stage.active{display:block}
    #|pre{margin:0;padding:18px;border:1px solid var(--line);border-radius:10px;background:#080d1a;color:#dce5ff;overflow:auto;white-space:pre;tab-size:2}
    #|.observations{display:grid;gap:14px;margin:0 0 16px}.metrics{display:flex;flex-wrap:wrap;gap:8px}.metric{padding:7px 10px;border:1px solid var(--line);border-radius:8px;background:var(--panel)}
    #|table{width:100%;border-collapse:collapse;background:var(--panel)}th,td{padding:8px 10px;border:1px solid var(--line);text-align:left;vertical-align:top}th{color:var(--accent)}
    #|@media(max-width:760px){main{grid-template-columns:1fr}nav{border-right:0;border-bottom:1px solid var(--line)}}
    #|</style>
    #|</head>
    #|<body>
    #|<main><nav>
  for index, stage in stages {
    let selected = if index == 0 { "true" } else { "false" }
    let status = explore_stage_status(stage.state)
    html <+
      "<button type=\"button\" role=\"tab\" aria-selected=\"\{selected}\" data-stage=\"\{escape_html(stage.id)}\" data-status=\"\{status}\">\{escape_html(stage.title)}</button>"
  }
  html <+ "</nav><div class=\"content\">"
  for index, stage in stages {
    let class_name = if index == 0 { "stage active" } else { "stage" }
    html <+
      "<section class=\"\{class_name}\" data-stage=\"\{escape_html(stage.id)}\">"
    render_stage_observations(html, stage, report.functions)
    html <+
      "<pre>\{escape_html(explore_stage_text(stage.state))}</pre></section>"
  }
  html <+
    #|</div></main>
    #|<script>
    #|const buttons=[...document.querySelectorAll('button[data-stage]')];
    #|const stages=[...document.querySelectorAll('.stage[data-stage]')];
    #|for(const button of buttons){button.addEventListener('click',()=>{const id=button.dataset.stage;for(const item of buttons)item.setAttribute('aria-selected',String(item===button));for(const stage of stages)stage.classList.toggle('active',stage.dataset.stage===id);});}
    #|</script>
    #|</body>
    #|</html>
  html.to_string()
}

///|
fn render_stage_observations(
  html : StringBuilder,
  stage : @driver.ExploreStage,
  functions : @driver.ExploreFunctionGraph,
) -> Unit {
  guard stage.state is Completed(snapshot) else { return }
  let nodes = functions.nodes.filter(node => {
    node.function.stage.key() == stage.id
  })
  if snapshot.scale.metrics.is_empty() &&
    snapshot.scale.functions.is_empty() &&
    snapshot.scale.modules.is_empty() &&
    nodes.is_empty() {
    return
  }
  html <+ "<div class=\"observations\">"
  if !snapshot.scale.metrics.is_empty() {
    html <+ "<div class=\"metrics\">"
    for metric in snapshot.scale.metrics {
      html <+
        "<span class=\"metric\">\{escape_html(metric.id.key())}: \{metric.value}</span>"
    }
    html <+ "</div>"
  }
  if !snapshot.scale.functions.is_empty() {
    html <+
      "<table><thead><tr><th>Function</th><th>Blocks</th><th>Operations</th><th>Values/locals</th></tr></thead><tbody>"
    for function in snapshot.scale.functions {
      html <+
        "<tr><td>\{function.index}</td><td>\{function.block_count}</td><td>\{function.operation_count}</td><td>\{function.value_count}</td></tr>"
    }
    html <+ "</tbody></table>"
  }
  if !snapshot.scale.modules.is_empty() {
    html <+
      "<table><thead><tr><th>Module</th><th>Input top terms</th><th>Retained top terms</th><th>Input values</th><th>Retained values</th></tr></thead><tbody>"
    for module_ in snapshot.scale.modules {
      html <+
        "<tr><td>\{escape_html(module_.module_path_text)}</td><td>\{module_.input_top_terms}</td><td>\{module_.retained_top_terms}</td><td>\{module_.input_value_bindings}</td><td>\{module_.retained_value_bindings}</td></tr>"
    }
    html <+ "</tbody></table>"
  }
  if !nodes.is_empty() {
    html <+
      "<table><thead><tr><th>Function lineage</th><th>Role</th><th>From</th></tr></thead><tbody>"
    for node in nodes {
      let sources = functions.edges.filter_map(edge => {
        if edge.target == node.function {
          Some(function_ref_label(edge.source))
        } else {
          None
        }
      })
      let source_text = if sources.is_empty() {
        "root"
      } else {
        sources.join(", ")
      }
      html <+
        "<tr><td>\{escape_html(function_ref_label(node.function))}</td><td>\{escape_html(node.roles.map(function_role_label).join(", "))}</td><td>\{escape_html(source_text)}</td></tr>"
    }
    html <+ "</tbody></table>"
  }
  html <+ "</div>"
}

///|
fn function_ref_label(function : @driver.ExploreFunctionRef) -> String {
  "\{function.stage.key()}#\{function.index}"
}

///|
fn function_role_label(role : @driver.ExploreFunctionRole) -> String {
  match role {
    SourceFunction(value~, name~) =>
      match name {
        Some(name) => "source \{name} (value#\{value})"
        None => "source value#\{value}"
      }
    AnonymousFunction => "anonymous function"
    Initializer(value~, name~) =>
      match name {
        Some(name) => "initializer for \{name} (value#\{value})"
        None => "initializer for value#\{value}"
      }
    InitializerOrchestrator => "initializer orchestrator"
    IntrinsicWrapper(name~) => "intrinsic wrapper \{name}"
    CallableAdapter => "callable adapter"
    RepresentationWorker(value~, name~) =>
      match (value, name) {
        (Some(value), Some(name)) =>
          "representation worker for \{name} (value#\{value})"
        (Some(value), None) => "representation worker for value#\{value}"
        (None, _) => "representation worker for anonymous function"
      }
    LayoutConstructor => "layout constructor"
    RuntimeImport(value~, name~, symbol~) => {
      let source = match name {
        Some(name) => "\{name} (value#\{value})"
        None => "value#\{value}"
      }
      "runtime import \{symbol} for \{source}"
    }
    InternalRuntimeImport(name~) => "internal runtime import \{name}"
    PhysicalRuntimeImport(symbol~) => "physical runtime import \{symbol}"
    WasmBytecodeFunction => "Wasm body for bytecode function"
    RuntimeImportAdapter(symbol~) => "runtime import adapter \{symbol}"
    WasmRuntimeFunction(name~) => "Wasm runtime function \{name}"
    WasmHelperFunction(name~, ordinal~) =>
      match ordinal {
        Some(ordinal) => "Wasm helper \{name} #\{ordinal}"
        None => "Wasm helper \{name}"
      }
    EntryWrapper => "entry wrapper"
  }
}

///|
fn explore_stage_status(state : @driver.ExploreStageState) -> String {
  match state {
    Completed(_) => "completed"
    Failed(_) => "failed"
    Unavailable => "unavailable"
  }
}

///|
fn explore_stage_text(state : @driver.ExploreStageState) -> String {
  match state {
    Completed(snapshot) => snapshot.text
    Failed(_) => "Stage failed. See compiler diagnostics."
    Unavailable => "Unavailable because an earlier stage failed."
  }
}

///|
fn escape_html(text : String) -> String {
  let escaped = StringBuilder::new()
  for character in text {
    match character {
      '&' => escaped <+ "&amp;"
      '<' => escaped <+ "&lt;"
      '>' => escaped <+ "&gt;"
      '\"' => escaped <+ "&quot;"
      '\'' => escaped <+ "&#39;"
      _ => escaped.write_char(character)
    }
  }
  escaped.to_string()
}
