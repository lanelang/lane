///|
fn derive_hover_notes() -> String {
  (
    #|// `C` must have kind `[Type] -> Type`.
    #|// `T` must normalize to a struct or enum application.
    #|// A bare generic type parameter cannot be used as `T` because its structure is unknown.
    #|// Omitting `deriver` selects one visible `Deriver[C]` offer.
  )
}

///|
fn unresolved_derive_hover() -> String {
  "derive[C, T](deriver=...) -> C[T]\n\{derive_hover_notes()}"
}

///|
fn SemanticIndex::enrich_checked_derive(
  self : SemanticIndex,
  plan : @checked.CheckedDerivePlan,
  type_ : @types.Type,
  source : @basic.DeriveSourceSite,
  display : @typecheck.TypeDisplayContext,
) -> Unit {
  let explicit = plan.deriver is Explicit(_)
  let invocation = if explicit {
    "derive[\{display.type_text(plan.capability)}, \{display.type_text(plan.target)}](deriver=...)"
  } else {
    "derive[\{display.type_text(plan.capability)}, \{display.type_text(plan.target)}]()"
  }
  let lines = ["\{invocation} : \{display.type_text(type_)}"]
  match plan.deriver {
    Explicit(value) => {
      lines.push("deriver: explicit : \{display.type_text(value.type_())}")
      self.enrich_checked_expr(value, display)
    }
    Contextual(selection) => {
      lines.push(
        "deriver: \{selection.name} : \{display.type_text(selection.type_)}",
      )
      self.add_reference(Value(selection.symbol), source.keyword_loc, None)
      add_implicit_argument_inlay_hint(
        self.inlay_hints,
        self.source_id,
        source.close_paren_loc.ascii_prefix(0),
        "",
        ["deriver=\{selection.name}"],
      )
      self.collect_checked_expr_types(selection.value)
    }
  }
  let evidence_lines = []
  plan.shape.for_each_evidence(fn(evidence) {
    let selection = evidence.selection
    evidence_lines.push(
      "  \{evidence.path}: \{selection.name} : \{display.type_text(evidence.required_type)}",
    )
    self.collect_checked_expr_types(selection.value)
  })
  if !evidence_lines.is_empty() {
    lines.push("evidence:")
    lines.append(evidence_lines)
  }
  lines.push(derive_hover_notes())
  self.upsert_hover(source.keyword_loc, lines.join("\n"))
}
