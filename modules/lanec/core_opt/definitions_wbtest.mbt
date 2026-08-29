///|
test "static value analysis rejects effectful spines and recursive aliases" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box_type = metadata.define_type("Box", [])
  let box_constructor = metadata.define_data_constructor("box", box_type, [], [])
  let box_value_type = @buslane.Type::Constructor(box_type)
  let effect = metadata.define_value(
    "effect",
    External,
    Function([], unit_type, Builtin(Io)),
  )
  let effect_result = metadata.define_value("effect_result", Local, unit_type)
  let effectful = metadata.define_value("effectful", Value, box_value_type)
  let cycle_left = metadata.define_value("cycle_left", Value, box_value_type)
  let cycle_right = metadata.define_value("cycle_right", Value, box_value_type)
  let local_literal = metadata.define_value(
    "local_literal",
    Local,
    Primitive(I64),
  )
  let static_literal = metadata.define_value(
    "static_literal",
    Value,
    Primitive(I64),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(effect),
      Let(cycle_left, Ref(cycle_right)),
      Let(cycle_right, Ref(cycle_left)),
      Let(
        static_literal,
        Let(local_literal, Literal(I64(42L)), Ref(local_literal)),
      ),
      Let(
        effectful,
        Let(
          effect_result,
          Call(Ref(effect), []),
          Construct({
            data_constructor: box_constructor,
            type_arguments: [],
            hidden_witnesses: [],
            payloads: [],
          }),
        ),
      ),
    ],
  }
  let analysis = analyze_core(program)
  debug_inspect(
    (
      analysis.find_static_value(cycle_left) is None,
      analysis.find_static_value(cycle_right) is None,
      analysis.find_static_value(effectful) is None,
      analysis.find_static_value(static_literal)
      is Some(StaticLiteral(I64(42L))),
    ),
    content="(true, true, true, true)",
  )
}
