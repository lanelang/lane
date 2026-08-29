///|
test "scalar replacement rejects captured whole-value and existential uses" {
  let aggregate : @buslane.ValueId = { index: 0, }
  let callable : @buslane.ValueId = { index: 1, }
  let match_binder : @buslane.ValueId = { index: 2, }
  let field : @buslane.ValueId = { index: 3, }
  let data_constructor : @buslane.DataConId = { index: 0, }
  let construct : @buslane.ConstructExpr = {
    data_constructor,
    type_arguments: [],
    hidden_witnesses: [],
    payloads: [Literal(I64(42L))],
  }
  let captured = @buslane.Expr::Function({
    parameters: [],
    result_type: Primitive(I64),
    body: Ref(aggregate),
  })
  let recursive = @buslane.Expr::LetRec(
    [
      {
        id: callable,
        rhs: Function({
          parameters: [],
          result_type: Primitive(I64),
          body: Ref(aggregate),
        }),
      },
    ],
    Literal(Unit),
  )
  let existential = @buslane.Expr::Match({
    scrutinee: Ref(aggregate),
    binder: match_binder,
    result_type: Primitive(I64),
    alternatives: [
      {
        alt_constructor: DataCon(data_constructor),
        type_binders: [{ index: 0, }],
        value_binders: [field],
        body: Ref(field),
      },
    ],
  })
  let whole_value = @buslane.Expr::Match({
    scrutinee: Ref(aggregate),
    binder: match_binder,
    result_type: Constructor({ index: 0, }),
    alternatives: [
      {
        alt_constructor: DataCon(data_constructor),
        type_binders: [],
        value_binders: [field],
        body: Ref(match_binder),
      },
    ],
  })
  debug_inspect(
    (
      scalar_replace_local_construct(aggregate, construct, captured) is None,
      scalar_replace_local_construct(aggregate, construct, recursive) is None,
      scalar_replace_local_construct(aggregate, construct, existential) is None,
      scalar_replace_local_construct(aggregate, construct, whole_value) is None,
    ),
    content="(true, true, true, true)",
  )
}
