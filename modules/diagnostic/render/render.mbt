///|
pub(all) struct RenderConfig {
  color : Bool
  width : Int
} derive(Debug, Eq)

///|
pub fn RenderConfig::plain(width? : Int = 100) -> RenderConfig {
  { color: false, width }
}

///|
pub fn render_for_test(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
) -> String {
  render_diagnostic(diagnostic, sources, config=RenderConfig::plain())
}

///|
pub fn render_diagnostic(
  diagnostic : @core.Diagnostic,
  sources : @source.SourceDatabase,
  config? : RenderConfig = RenderConfig::plain(),
) -> String {
  let lines : Array[String] = []
  lines.push(header(diagnostic, config))
  if diagnostic.labels.get(0) is Some(label) {
    render_label_blocks(lines, label, diagnostic.labels, sources, config)
  }
  for note in diagnostic.notes {
    lines.push("  = note: \{note}")
  }
  for fact in diagnostic.facts {
    render_fact(lines, fact, sources)
  }
  for help in diagnostic.helps {
    lines.push("  = help: \{help}")
  }
  for related in diagnostic.related_locations {
    render_related_location(lines, related, sources)
  }
  for suggestion in diagnostic.suggestions {
    render_suggestion(lines, suggestion, sources)
  }
  lines.join("\n")
}

///|
fn header(diagnostic : @core.Diagnostic, config : RenderConfig) -> String {
  let severity = color_severity(
    diagnostic.severity.as_text(),
    diagnostic.severity,
    config,
  )
  match diagnostic.code {
    Some(code) => "\{severity}[\{code}]: \{diagnostic.message}"
    None => "\{severity}: \{diagnostic.message}"
  }
}

///|
fn render_label_blocks(
  lines : Array[String],
  primary : @core.Label,
  labels : Array[@core.Label],
  sources : @source.SourceDatabase,
  config : RenderConfig,
) -> Unit {
  let rendered_sources : Array[@core.SourceId] = []
  render_label_block(
    lines,
    primary.span.source_id,
    primary,
    labels,
    sources,
    config,
  )
  rendered_sources.push(primary.span.source_id)
  for label in labels {
    if !rendered_sources.contains(label.span.source_id) {
      render_label_block(
        lines,
        label.span.source_id,
        label,
        labels,
        sources,
        config,
      )
      rendered_sources.push(label.span.source_id)
    }
  }
}

///|
fn render_label_block(
  lines : Array[String],
  source_id : @core.SourceId,
  header_label : @core.Label,
  labels : Array[@core.Label],
  sources : @source.SourceDatabase,
  config : RenderConfig,
) -> Unit {
  ignore(config)
  guard sources.file(source_id) is Some(file) else { return }
  let primary_position = file.position(header_label.span.start_offset)
  lines.push(
    "  --> \{file.display_name()}:\{primary_position.line}:\{primary_position.column}",
  )
  lines.push("   |")
  for label in labels {
    if label.span.source_id == source_id {
      render_single_label(lines, label, sources, config)
    }
  }
  lines.push("   |")
}

///|
fn render_single_label(
  lines : Array[String],
  label : @core.Label,
  sources : @source.SourceDatabase,
  config : RenderConfig,
) -> Unit {
  guard sources.file(label.span.source_id) is Some(file) else { return }
  let start = file.position(label.span.start_offset)
  let end = file.position(label.span.end_offset)
  for line in start.line..<=end.line {
    guard file.line_text(line) is Some(text) else { continue }
    let display_text = truncate_line(text, config.width)
    lines.push("\{line_number_text(line)} | \{display_text}")
    lines.push(
      "   | \{underline_for_line(label, line, start, end, display_text.length(), config)}",
    )
  }
}

///|
fn underline_for_line(
  label : @core.Label,
  line : Int,
  start : @source.SourcePosition,
  end : @source.SourcePosition,
  line_length : Int,
  config : RenderConfig,
) -> String {
  let start_column = if line == start.line { start.column } else { 1 }
  let raw_end_column = if line == end.line {
    end.column
  } else {
    line_length + 1
  }
  let end_column = min_int(raw_end_column, line_length + 1)
  let width = max_int(1, end_column - start_column)
  let marker = color_marker(label.style.marker(), label.style, config)
  let underline = marker.repeat(width)
  let message = match label.message {
    Some(message) if line == start.line => " \{message}"
    _ => ""
  }
  "\{" ".repeat(start_column - 1)}\{underline}\{message}"
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn line_number_text(line : Int) -> String {
  let text = line.to_string()
  if text.length() >= 2 {
    text
  } else {
    " ".repeat(2 - text.length()) + text
  }
}

///|
fn truncate_line(text : String, width : Int) -> String {
  if width <= 0 || text.length() <= width {
    text
  } else if width <= 3 {
    ".".repeat(width)
  } else {
    text[:width - 3].to_owned() + "..."
  }
}

///|
fn render_fact(
  lines : Array[String],
  fact : @core.DiagnosticFact,
  sources : @source.SourceDatabase,
) -> Unit {
  match fact.span {
    Some(span) =>
      lines.push(
        "  = \{fact.name}: \{fact.value} at \{span_location(span, sources)}",
      )
    None => lines.push("  = \{fact.name}: \{fact.value}")
  }
}

///|
fn render_related_location(
  lines : Array[String],
  related : @core.RelatedLocation,
  sources : @source.SourceDatabase,
) -> Unit {
  lines.push(
    "  = related: \{span_location(related.span, sources)}: \{related.message}",
  )
}

///|
fn render_suggestion(
  lines : Array[String],
  suggestion : @core.Suggestion,
  sources : @source.SourceDatabase,
) -> Unit {
  lines.push(
    "  = suggestion: \{suggestion.message} (\{suggestion.applicability.as_text()})",
  )
  for edit in suggestion.edits {
    lines.push(
      "    = edit: \{span_range(edit.span, sources)} replace with `\{edit.replacement}`",
    )
  }
}

///|
fn span_location(
  span : @core.SourceSpan,
  sources : @source.SourceDatabase,
) -> String {
  match sources.file(span.source_id) {
    Some(file) => {
      let position = file.position(span.start_offset)
      "\{file.display_name()}:\{position.line}:\{position.column}"
    }
    None => "<source#\{span.source_id.value}>"
  }
}

///|
fn span_range(
  span : @core.SourceSpan,
  sources : @source.SourceDatabase,
) -> String {
  match sources.file(span.source_id) {
    Some(file) => {
      let start = file.position(span.start_offset)
      let end = file.position(span.end_offset)
      "\{file.display_name()}:\{start.line}:\{start.column}-\{end.line}:\{end.column}"
    }
    None => "<source#\{span.source_id.value}>"
  }
}

///|
fn color_severity(
  text : String,
  severity : @core.Severity,
  config : RenderConfig,
) -> String {
  if !config.color {
    return text
  }
  let code = match severity {
    Error => "31"
    Warning => "33"
    Info => "34"
    Hint => "36"
  }
  "\u{1b}[\{code}m\{text}\u{1b}[0m"
}

///|
fn color_marker(
  text : String,
  style : @core.LabelStyle,
  config : RenderConfig,
) -> String {
  if !config.color {
    return text
  }
  let code = match style {
    Primary => "31"
    Secondary => "34"
  }
  "\u{1b}[\{code}m\{text}\u{1b}[0m"
}

///|
pub fn normalize_paths(
  text : String,
  replacement? : String = "<path>",
) -> String {
  let lines = []
  for line in text.split("\n") {
    let owned = line.to_owned()
    if owned.has_prefix("  --> /") {
      match first_colon_index(owned) {
        Some(index) => lines.push("  --> \{replacement}\{owned[index:]}")
        None => lines.push(owned)
      }
    } else {
      lines.push(owned)
    }
  }
  lines.join("\n")
}

///|
fn first_colon_index(text : String) -> Int? {
  for index in 0..<text.length() {
    if text[index] == ':' {
      return Some(index)
    }
  }
  None
}
