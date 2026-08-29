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
  smallest_hover_at(self.hovers, Some(source_id), line, column)
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
    hint.position.source_id == source_id &&
    hint.position.in_range(start_line, start_column, end_line, end_column)
  })
}

///|
fn AnalysisResult::reference_at(
  self : AnalysisResult,
  source_id : String,
  line : Int,
  column : Int,
) -> ReferenceEntry? {
  smallest_reference_at(self.references, Some(source_id), line, column)
}

///|
fn AnalysisResult::definition_entry_at(
  self : AnalysisResult,
  source_id : String,
  line : Int,
  column : Int,
) -> DefinitionEntry? {
  smallest_definition_at(self.definitions, Some(source_id), line, column)
}

///|
fn SemanticIndex::reference_at(
  self : SemanticIndex,
  line : Int,
  column : Int,
) -> ReferenceEntry? {
  smallest_reference_at(self.references, None, line, column)
}

///|
fn SemanticIndex::definition_entry_at(
  self : SemanticIndex,
  line : Int,
  column : Int,
) -> DefinitionEntry? {
  smallest_definition_at(self.definitions, None, line, column)
}

///|
fn SemanticIndex::hover_at(
  self : SemanticIndex,
  line : Int,
  column : Int,
) -> HoverEntry? {
  smallest_hover_at(self.hovers, None, line, column)
}

///|
fn SemanticIndex::inlay_hints_in_range(
  self : SemanticIndex,
  start_line : Int,
  start_column : Int,
  end_line : Int,
  end_column : Int,
) -> Array[InlayHintEntry] {
  self.inlay_hints
  .present()
  .filter(fn(hint) {
    hint.position.in_range(start_line, start_column, end_line, end_column)
  })
}

///|
fn AnalysisPosition::in_range(
  self : AnalysisPosition,
  start_line : Int,
  start_column : Int,
  end_line : Int,
  end_column : Int,
) -> Bool {
  let at_or_after_start = self.line > start_line ||
    (self.line == start_line && self.column >= start_column)
  let before_end = self.line < end_line ||
    (self.line == end_line && self.column < end_column)
  at_or_after_start && before_end
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
fn @basic.SourceSpan::size(self : @basic.SourceSpan) -> Int {
  self.end_offset - self.start_offset
}

///|
fn smallest_reference_at(
  references : Array[ReferenceEntry],
  source_id : String?,
  line : Int,
  column : Int,
) -> ReferenceEntry? {
  let mut best = None
  for reference in references {
    if !location_matches(reference.location, source_id, line, column) {
      continue
    }
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
fn smallest_hover_at(
  hovers : Array[HoverEntry],
  source_id : String?,
  line : Int,
  column : Int,
) -> HoverEntry? {
  let mut best = None
  for hover in hovers {
    if !location_matches(hover.location, source_id, line, column) {
      continue
    }
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
fn smallest_definition_at(
  definitions : Array[DefinitionEntry],
  source_id : String?,
  line : Int,
  column : Int,
) -> DefinitionEntry? {
  let mut best = None
  for definition in definitions {
    if !location_matches(definition.location, source_id, line, column) {
      continue
    }
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
fn location_matches(
  location : AnalysisLocation,
  source_id : String?,
  line : Int,
  column : Int,
) -> Bool {
  let source_matches = match source_id {
    Some(source_id) => location.source_id == source_id
    None => true
  }
  source_matches && location.span.contains_position(line, column)
}

///|
fn location(source_id : String, span : @basic.SourceSpan) -> AnalysisLocation {
  { source_id, span, }
}

///|
fn InlayHintFacts::new() -> InlayHintFacts {
  { facts: [], next_semantic_order: 0, }
}

///|
fn InlayHintFacts::add(
  self : InlayHintFacts,
  kind : InlayHintKind,
  position : AnalysisPosition,
  label : String,
) -> Unit {
  self.facts.push({
    hint: { position, kind, label, },
    semantic_order: self.next_semantic_order,
  })
  self.next_semantic_order += 1
}

///|
fn add_type_inlay_hint(
  inlay_hints : InlayHintFacts,
  source_id : String,
  span : @basic.SourceSpan,
  display : @typecheck.TypeDisplayContext,
  type_ : @types.Type,
) -> Unit {
  inlay_hints.add(
    TypeHint,
    position_at_end(source_id, span),
    ": \{display.type_text(type_)}",
  )
}

///|
fn add_parameter_inlay_hint(
  inlay_hints : InlayHintFacts,
  source_id : String,
  span : @basic.SourceSpan,
  name : String,
) -> Unit {
  inlay_hints.add(ParameterHint, position_at_start(source_id, span), "\{name}=")
}

///|
fn add_implicit_argument_inlay_hint(
  inlay_hints : InlayHintFacts,
  source_id : String,
  insertion : @basic.SourceSpan,
  prefix : String,
  arguments : Array[String],
) -> Unit {
  inlay_hints.add(
    ImplicitArgumentHint,
    position_at_end(source_id, insertion),
    "\{prefix}\{arguments.join(", ")}",
  )
}

///|
fn position_at_start(
  source_id : String,
  span : @basic.SourceSpan,
) -> AnalysisPosition {
  { source_id, line: span.start_line, column: span.start_column, }
}

///|
fn position_at_end(
  source_id : String,
  span : @basic.SourceSpan,
) -> AnalysisPosition {
  { source_id, line: span.end_line, column: span.end_column, }
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
  definitions.push({ symbol, location: loc, label, detail, })
  hovers.push({ location: loc, contents: detail, })
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
  references.push({ location: loc, symbol, hover, })
  match hover {
    Some(contents) => hovers.push({ location: loc, contents, })
    None => ()
  }
}

///|
