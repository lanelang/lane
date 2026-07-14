///|
test "monadic-lift rejects unresolved context markers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let effect : @buslane.Effect = Parameter(effect_parameter)
  assert_eq(
    lift_monadic_continuations({
      metadata,
      terms: [
        Let(
          result,
          OpenContext({
            source_effect: effect,
            target_effect: effect,
            body: Literal(Unit),
          }),
        ),
      ],
    }),
    Err(ResidualOpenContext(source=effect, target=effect)),
  )
}
