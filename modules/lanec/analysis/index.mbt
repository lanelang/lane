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
    hover.location.span.contains_position(line, column)
  })
  smallest_hover(hovers)
}

///|
pub fn AnalysisResult::inlay_hints_in_range(
  self : AnalysisResult,
  source_id : String,
  start_line : Int,
  start_column : Int,
  end_line : Int,
  end_column : Int,
) -> Array[InlayHintEntry] {
  self.inlay_hints.filter(fn(hint) {
    hint.location.source_id == source_id &&
    hint.location.span.overlaps_range(
      start_line, start_column, end_line, end_column,
    )
  })
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
    reference.location.span.contains_position(line, column)
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
    definition.location.span.contains_position(line, column)
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
fn @basic.SourceSpan::contains_position(
  self : @basic.SourceSpan,
  line : Int,
  column : Int,
) -> Bool {
  (
    line > self.start_line ||
    (line == self.start_line && column >= self.start_column)
  ) &&
  (line < self.end_line || (line == self.end_line && column < self.end_column))
}

///|
fn @basic.SourceSpan::overlaps_range(
  self : @basic.SourceSpan,
  start_line : Int,
  start_column : Int,
  end_line : Int,
  end_column : Int,
) -> Bool {
  let starts_before_range_end = self.start_line < end_line ||
    (self.start_line == end_line && self.start_column < end_column)
  let ends_after_range_start = self.end_line > start_line ||
    (self.end_line == start_line && self.end_column > start_column)
  starts_before_range_end && ends_after_range_start
}

///|
fn @basic.SourceSpan::size(self : @basic.SourceSpan) -> Int {
  self.end_offset - self.start_offset
}

///|
fn smallest_reference(references : Array[ReferenceEntry]) -> ReferenceEntry? {
  let mut best = None
  for reference in references {
    match best {
      None => best = Some(reference)
      Some(current) =>
        if reference.location.span.size() < current.location.span.size() {
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
        if hover.location.span.size() < current.location.span.size() {
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
        if definition.location.span.size() < current.location.span.size() {
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
fn add_inlay_hint(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  kind : InlayHintKind,
  span : @basic.SourceSpan,
  label : String,
) -> Unit {
  inlay_hints.push({ location: location(source_id, span), kind, label })
}

///|
fn add_type_inlay_hint(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  span : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
  type_ : @types.Type,
) -> Unit {
  add_inlay_hint(
    inlay_hints,
    source_id,
    TypeHint,
    span,
    ": \{display.type_text(type_)}",
  )
}

///|
fn add_parameter_inlay_hint(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  span : @basic.SourceSpan,
  name : String,
) -> Unit {
  add_inlay_hint(inlay_hints, source_id, ParameterHint, span, "\{name}=")
}

///|
fn add_implicit_argument_inlay_hint(
  inlay_hints : Array[InlayHintEntry],
  source_id : String,
  span : @basic.SourceSpan,
  arguments : Array[String],
) -> Unit {
  add_inlay_hint(
    inlay_hints,
    source_id,
    ImplicitArgumentHint,
    span,
    ", \{arguments.join(", ")}",
  )
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
