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

///|
test "dynamic layout requirements use the render context" {
  let document = group(
    text("head") +
    dynamic(fn(context) {
      if context.indent == 4 && context.width == 10 {
        hardline + line + text("tail")
      } else {
        text("tail")
      }
    }),
  )
  inspect(
    render(document, width=10),
    content=(
      #|head
      #|
      #|tail
    ),
  )
}

///|
test "dynamic documents do not guess a context during construction" {
  let mut calls = 0
  let document = dynamic(fn(_) {
    calls += 1
    text("value")
  })
  assert_eq(calls, 0)
  inspect(render(document), content="value")
  assert_eq(calls, 1)
}
