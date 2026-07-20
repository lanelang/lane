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
  if report.failure is Some(message) {
    return LaneCommandOutcome::user_error(ExecutionImageLowering(message~))
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
    #|@media(max-width:760px){main{grid-template-columns:1fr}nav{border-right:0;border-bottom:1px solid var(--line)}}
    #|</style>
    #|</head>
    #|<body>
    #|<main><nav>
  for index, stage in report.stages {
    let selected = if index == 0 { "true" } else { "false" }
    html <+
      "<button type=\"button\" role=\"tab\" aria-selected=\"\{selected}\" data-stage=\"\{escape_html(stage.id)}\">\{escape_html(stage.title)}</button>"
  }
  html <+ "</nav><div class=\"content\">"
  for index, stage in report.stages {
    let class_name = if index == 0 { "stage active" } else { "stage" }
    html <+
      "<section class=\"\{class_name}\" data-stage=\"\{escape_html(stage.id)}\"><pre>\{escape_html(stage.text)}</pre></section>"
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
