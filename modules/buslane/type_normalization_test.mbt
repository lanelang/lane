///|
test "verify match through a beta-reducible nominal type application" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let item = metadata.define_type_parameter("T", Type)
  let error = metadata.define_type_parameter("E", Type)
  let result = metadata.define_type("Result", [item, error])
  let ok = metadata.define_data_constructor("ok", result, [], [Parameter(item)])
  let err = metadata.define_data_constructor("error", result, [], [
    Parameter(error),
  ])
  let partial_item = metadata.define_type_parameter("A", Type)
  let partial_result = Type::TypeLambda(
    [partial_item],
    Apply(Constructor(result), [
      TypeArgument(Parameter(partial_item)),
      TypeArgument(Primitive(String)),
    ]),
  )
  let applied_result = Type::Apply(partial_result, [
    TypeArgument(Primitive(Bool)),
  ])
  let scrutinee = metadata.define_value("scrutinee", Value, applied_result)
  let match_binder = metadata.define_value(
    "matched",
    MatchBinder,
    applied_result,
  )
  let ok_binder = metadata.define_value("value", MatchBinder, Primitive(Bool))
  let error_binder = metadata.define_value(
    "error",
    MatchBinder,
    Primitive(String),
  )
  let answer = metadata.define_value("answer", Value, Primitive(I64))
  let program : Program = {
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: ok,
          type_arguments: [
            TypeArgument(Primitive(Bool)),
            TypeArgument(Primitive(String)),
          ],
          hidden_witnesses: [],
          payloads: [Literal(Bool(true))],
        }),
      ),
      Let(
        answer,
        Match({
          scrutinee: Ref(scrutinee),
          binder: match_binder,
          result_type: Primitive(I64),
          alternatives: [
            {
              alt_constructor: DataCon(ok),
              type_binders: [],
              value_binders: [ok_binder],
              body: Literal(I64(42L)),
            },
            {
              alt_constructor: DataCon(err),
              type_binders: [],
              value_binders: [error_binder],
              body: Literal(I64(0L)),
            },
          ],
        }),
      ),
    ],
  }
  assert_true(verify_program(program).is_ok())
}
