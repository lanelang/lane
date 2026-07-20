///|
test "line comment forces following nested text onto a new line" {
  inspect(
    render(
      text("value") + line_comment("// note") + nest(space + text("|> next")),
    ),
    content=(
      #|value // note
      #|  |> next
    ),
  )
}

///|
test "explicit line after line comment does not duplicate the break" {
  inspect(
    render(text("value") + line_comment("// note") + hardline + text("next")),
    content=(
      #|value // note
      #|next
    ),
  )
}

///|
test "generic document adapter preserves width-sensitive layout" {
  let document = group(text("left") + line + text("right"))
  let source_render = render(document, width=5)
  let generic_render = @generic_prettyprinter.render(
    document.to_generic(),
    width=5,
  )
  inspect(
    source_render,
    content=(
      #|left
      #|right
    ),
  )
  assert_eq(generic_render, source_render)
}
