///|
pub fn AnalysisResult::definition_at(
  self : AnalysisResult,
  source_id : String,
  line : Int,
  column : Int,
) -> AnalysisLocation? {
  match self.reference_at(source_id, line, column) {
    Some(reference) => self.definition_for_symbol(reference.symbol)
    None =>
      match self.definition_entry_at(source_id, line, column) {
        Some(definition) => Some(definition.location)
        None => None
      }
  }
}

///|
pub fn AnalysisResult::hover_at(
  self : AnalysisResult,
  source_id : String,
  line : Int,
  column : Int,
) -> HoverEntry? {
  let hovers = self.hovers.filter(fn(hover) {
    hover.location.source_id == source_id &&
    span_contains(hover.location.span, line, column)
  })
  smallest_hover(hovers)
}

///|
fn AnalysisResult::reference_at(
  self : AnalysisResult,
  source_id : String,
  line : Int,
  column : Int,
) -> ReferenceEntry? {
  let references = self.references.filter(fn(reference) {
    reference.location.source_id == source_id &&
    span_contains(reference.location.span, line, column)
  })
  smallest_reference(references)
}

///|
fn AnalysisResult::definition_entry_at(
  self : AnalysisResult,
  source_id : String,
  line : Int,
  column : Int,
) -> DefinitionEntry? {
  let definitions = self.definitions.filter(fn(definition) {
    definition.location.source_id == source_id &&
    span_contains(definition.location.span, line, column)
  })
  smallest_definition(definitions)
}

///|
fn AnalysisResult::definition_for_symbol(
  self : AnalysisResult,
  symbol : AnalysisSymbol,
) -> AnalysisLocation? {
  for definition in self.definitions {
    if definition.symbol == symbol {
      return Some(definition.location)
    }
  }
  None
}

///|
fn definition_label(
  definitions : Array[DefinitionEntry],
  symbol : AnalysisSymbol,
) -> String? {
  for definition in definitions {
    if definition.symbol == symbol {
      return Some(definition.label)
    }
  }
  None
}

///|
fn definition_detail(
  definitions : Array[DefinitionEntry],
  symbol : AnalysisSymbol,
) -> String? {
  for definition in definitions {
    if definition.symbol == symbol {
      return Some(definition.detail)
    }
  }
  None
}

///|
fn definition_reference_span(
  definitions : Array[DefinitionEntry],
  symbol : AnalysisSymbol,
  source_text : String,
  fallback : @basic.SourceSpan,
) -> @basic.SourceSpan {
  match definition_label(definitions, symbol) {
    Some(name) => name_span(source_text, name, fallback)
    None => fallback
  }
}

///|
fn span_contains(span : @basic.SourceSpan, line : Int, column : Int) -> Bool {
  (
    line > span.start_line ||
    (line == span.start_line && column >= span.start_column)
  ) &&
  (line < span.end_line || (line == span.end_line && column < span.end_column))
}

///|
fn span_size(span : @basic.SourceSpan) -> Int {
  span.end_offset - span.start_offset
}

///|
fn smallest_reference(references : Array[ReferenceEntry]) -> ReferenceEntry? {
  let mut best = None
  for reference in references {
    match best {
      None => best = Some(reference)
      Some(current) =>
        if span_size(reference.location.span) < span_size(current.location.span) {
          best = Some(reference)
        }
    }
  }
  best
}

///|
fn smallest_hover(hovers : Array[HoverEntry]) -> HoverEntry? {
  let mut best = None
  for hover in hovers {
    match best {
      None => best = Some(hover)
      Some(current) =>
        if span_size(hover.location.span) < span_size(current.location.span) {
          best = Some(hover)
        }
    }
  }
  best
}

///|
fn smallest_definition(
  definitions : Array[DefinitionEntry],
) -> DefinitionEntry? {
  let mut best = None
  for definition in definitions {
    match best {
      None => best = Some(definition)
      Some(current) =>
        if span_size(definition.location.span) <
          span_size(current.location.span) {
          best = Some(definition)
        }
    }
  }
  best
}

///|
fn location(source_id : String, span : @basic.SourceSpan) -> AnalysisLocation {
  { source_id, span }
}

///|
fn name_span(
  source_text : String,
  name : String,
  fallback : @basic.SourceSpan,
) -> @basic.SourceSpan {
  guard name != "" else { return fallback }
  let lines = source_text.split("\n").collect()
  guard lines.get(fallback.start_line - 1) is Some(line_view) else {
    return fallback
  }
  let line = line_view.to_owned()
  let mut search_start = 0
  let mut best_column = None
  while search_start < line.length() {
    let rest = line.unsafe_substring(start=search_start, end=line.length())
    match rest.find(name) {
      Some(relative) => {
        let column = search_start + relative + 1
        if column <= fallback.start_column {
          best_column = Some(column)
        } else if best_column is None {
          best_column = Some(column)
        }
        search_start = search_start + relative + name.length()
      }
      None => search_start = line.length()
    }
  }
  match best_column {
    Some(column) => {
      let start_offset = line_start_offset(lines, fallback.start_line) +
        column -
        1
      {
        start_offset,
        end_offset: start_offset + name.length(),
        start_line: fallback.start_line,
        start_column: column,
        end_line: fallback.start_line,
        end_column: column + name.length(),
      }
    }
    None => fallback
  }
}

///|
fn line_start_offset(lines : Array[StringView], line : Int) -> Int {
  let mut offset = 0
  for index in 0..<(line - 1) {
    match lines.get(index) {
      Some(text) => offset = offset + text.length() + 1
      None => ()
    }
  }
  offset
}

///|
fn add_definition(
  definitions : Array[DefinitionEntry],
  hovers : Array[HoverEntry],
  source_id : String,
  symbol : AnalysisSymbol,
  span : @basic.SourceSpan,
  label : String,
  detail : String,
) -> Unit {
  let loc = location(source_id, span)
  definitions.push({ symbol, location: loc, label, detail })
  hovers.push({ location: loc, contents: detail })
}

///|
fn add_reference(
  references : Array[ReferenceEntry],
  hovers : Array[HoverEntry],
  source_id : String,
  symbol : AnalysisSymbol,
  span : @basic.SourceSpan,
  hover : String?,
) -> Unit {
  let loc = location(source_id, span)
  references.push({ location: loc, symbol, hover })
  match hover {
    Some(contents) => hovers.push({ location: loc, contents })
    None => ()
  }
}

///|
fn type_text(type_ : @types.Type) -> String {
  @prettyprinter.render(type_.pretty(), width=80)
}

///|
fn kind_text(kind : @types.Kind) -> String {
  @prettyprinter.render(kind.pretty(), width=80)
}
