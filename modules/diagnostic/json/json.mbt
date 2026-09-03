///|
pub fn diagnostic_to_json(diagnostic : @core.Diagnostic) -> Json {
  @json_object.object([
    @json_object.required("severity", diagnostic.severity.as_text().to_json()),
    @json_object.required("message", diagnostic.message.to_json()),
    @json_object.optional("code", diagnostic.code.map(code => code.to_json())),
    @json_object.required(
      "labels",
      diagnostic.labels.map(label_to_json).to_json(),
    ),
    @json_object.required("notes", diagnostic.notes.to_json()),
    @json_object.required("helps", diagnostic.helps.to_json()),
    @json_object.required("facts", diagnostic.facts.map(fact_to_json).to_json()),
    @json_object.required(
      "suggestions",
      diagnostic.suggestions.map(suggestion_to_json).to_json(),
    ),
    @json_object.required(
      "relatedLocations",
      diagnostic.related_locations.map(related_location_to_json).to_json(),
    ),
    @json_object.required(
      "related",
      diagnostic.related.map(diagnostic_to_json).to_json(),
    ),
  ])
}

///|
pub fn label_to_json(label : @core.Label) -> Json {
  {
    "style": label_style_text(label.style),
    "span": span_to_json(label.span),
    "message": match label.message {
      Some(message) => message.to_json()
      None => Json::null()
    },
  }
}

///|
pub fn span_to_json(span : @core.SourceSpan) -> Json {
  {
    "sourceId": span.source_id.value,
    "startOffset": span.start_offset,
    "endOffset": span.end_offset,
  }
}

///|
pub fn suggestion_to_json(suggestion : @core.Suggestion) -> Json {
  {
    "message": suggestion.message,
    "applicability": suggestion.applicability.as_text(),
    "edits": suggestion.edits.map(text_edit_to_json),
  }
}

///|
pub fn fact_to_json(fact : @core.DiagnosticFact) -> Json {
  {
    "name": fact.name,
    "value": fact.value,
    "span": match fact.span {
      Some(span) => span_to_json(span)
      None => Json::null()
    },
  }
}

///|
pub fn related_location_to_json(related : @core.RelatedLocation) -> Json {
  { "span": span_to_json(related.span), "message": related.message }
}

///|
pub fn text_edit_to_json(edit : @core.TextEdit) -> Json {
  { "span": span_to_json(edit.span), "replacement": edit.replacement }
}

///|
fn label_style_text(style : @core.LabelStyle) -> String {
  match style {
    Primary => "primary"
    Secondary => "secondary"
  }
}
