///|
test "open-resolve removes identity and empty abstract markers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let abstract_effect : @buslane.Effect = Parameter(effect_parameter)
  let identity = Program::{
    metadata,
    terms: [
      Let(
        result,
        OpenContext({
          source_effect: abstract_effect,
          target_effect: abstract_effect,
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(
    resolve_open_contexts(identity),
    Ok({ metadata, terms: [Let(result, Literal(Unit))] }),
  )
  let empty = Program::{
    metadata,
    terms: [
      Let(
        result,
        OpenContext({
          source_effect: Empty,
          target_effect: abstract_effect,
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(
    resolve_open_contexts(empty),
    Ok({ metadata, terms: [Let(result, Literal(Unit))] }),
  )
}

///|
test "open-resolve rejects abstract plans with missing source contexts" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let first = metadata.define_effect("First", [])
  let second = metadata.define_effect("Second", [])
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let missing : @buslane.Effect = Singleton(first, [])
  let source : @buslane.Effect = Union([Parameter(effect_parameter), missing])
  let target : @buslane.Effect = Union([
    Parameter(effect_parameter),
    Singleton(second, []),
  ])
  assert_eq(
    resolve_open_contexts({
      metadata,
      terms: [
        Let(
          result,
          OpenContext({
            source_effect: source,
            target_effect: target,
            body: Literal(Unit),
          }),
        ),
      ],
    }),
    Err(MissingEffectContext(missing)),
  )
}
