///|
test "expression facts distinguish empty and non-empty call effects" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let unit_type = Type::Primitive(Unit)
  let pure = metadata.define_value(
    "pure",
    External,
    Function([], unit_type, Empty),
  )
  let effectful = metadata.define_value(
    "effectful",
    External,
    Function([], unit_type, Io),
  )
  let program : Program = {
    metadata,
    terms: [External(pure), External(effectful)],
  }
  let facts = ExpressionFactsQuery::new(program)
  debug_inspect(
    (
      facts.synthesize(Call(Ref(pure), [])),
      facts.synthesize(Call(Ref(effectful), [])),
    ),
    content=(
      #|(
      #|  Ok({ type_: Primitive(Unit), effect: Empty }),
      #|  Ok({ type_: Primitive(Unit), effect: Io }),
      #|)
    ),
  )
}

///|
test "expression facts survive direct function effect widening" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let unit_type = Type::Primitive(Unit)
  let invoke = metadata.define_value(
    "invoke",
    External,
    Function([Function([], unit_type, Io)], unit_type, Empty),
  )
  let program : Program = { metadata, terms: [External(invoke)] }
  let expression = Call(Ref(invoke), [
    Function({ parameters: [], result_type: unit_type, body: Literal(Unit) }),
  ])
  debug_inspect(
    ExpressionFactsQuery::new(program).synthesize(expression),
    content="Ok({ type_: Primitive(Unit), effect: Empty })",
  )
}
