///|
fn present_inlay_hints(facts : Array[InlayHintFact]) -> Array[InlayHintEntry] {
  let ordered = facts.copy()
  ordered.sort_by(compare_inlay_hint_facts)
  let hints : Array[InlayHintEntry] = []
  for fact in ordered {
    let hint = fact.hint
    let last_index = hints.length() - 1
    if hint.kind is ImplicitArgumentHint &&
      last_index >= 0 &&
      hints[last_index].kind is ImplicitArgumentHint &&
      hints[last_index].position == hint.position {
      let previous = hints[last_index]
      hints[last_index] = { ..previous, label: previous.label + hint.label }
    } else {
      hints.push(hint)
    }
  }
  hints
}

///|
fn compare_inlay_hint_facts(left : InlayHintFact, right : InlayHintFact) -> Int {
  let source_order = left.hint.position.source_id.compare(
    right.hint.position.source_id,
  )
  if source_order != 0 {
    return source_order
  }
  let line_order = left.hint.position.line.compare(right.hint.position.line)
  if line_order != 0 {
    return line_order
  }
  let position_order = left.hint.position.column.compare(
    right.hint.position.column,
  )
  if position_order != 0 {
    return position_order
  }
  let kind_order = inlay_hint_kind_rank(left.hint.kind).compare(
    inlay_hint_kind_rank(right.hint.kind),
  )
  if kind_order != 0 {
    return kind_order
  }
  let size_order = inlay_hint_origin_size(left).compare(
    inlay_hint_origin_size(right),
  )
  if size_order != 0 {
    return size_order
  }
  let start_order = right.origin.start_offset.compare(left.origin.start_offset)
  if start_order != 0 {
    return start_order
  }
  let end_order = left.origin.end_offset.compare(right.origin.end_offset)
  if end_order != 0 {
    return end_order
  }
  left.hint.label.compare(right.hint.label)
}

///|
fn inlay_hint_kind_rank(kind : InlayHintKind) -> Int {
  match kind {
    TypeHint => 0
    ParameterHint => 1
    ImplicitArgumentHint => 2
  }
}

///|
fn inlay_hint_origin_size(fact : InlayHintFact) -> Int {
  fact.origin.end_offset - fact.origin.start_offset
}
