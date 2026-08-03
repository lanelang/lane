///|
test "type normalization accepts deeply nested inert structure" {
  let mut type_ = @buslane.Type::Primitive(Unit)
  for _ in 0..<1100 {
    type_ = Forall([], type_)
  }
  assert_eq(type_.normalize(), type_)
}

///|
fn non_normalizing_type_application(
  parameter : @buslane.TypeParameterId,
) -> @buslane.Type {
  let self_application = @buslane.Type::TypeLambda(
    [parameter],
    Apply(Parameter(parameter), [TypeArgument(Parameter(parameter))]),
  )
  Apply(self_application, [TypeArgument(self_application)])
}

///|
fn runaway_effect(
  metadata : @buslane.MetadataRegistry,
  type_ : @buslane.Type,
) -> @buslane.Effect {
  let parameter = metadata.define_type_parameter("T", Type)
  let effect = metadata.define_effect("Runaway", [parameter])
  Singleton(effect, [TypeArgument(type_)])
}

///|
fn[T] assert_runaway_beta(
  compute : () -> T raise @buslane.TypeNormalizationError,
) -> Unit raise {
  try compute() catch {
    BetaReductionLimitExceeded(limit~) => assert_eq(limit, 1024)
    error => fail("unexpected normalization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected beta reduction to exhaust its budget")
  }
}

///|
test "type normalization reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let type_ = non_normalizing_type_application(parameter)
  try type_.normalize() catch {
    BetaReductionLimitExceeded(limit~) => assert_eq(limit, 1024)
    error => fail("unexpected normalization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected beta reduction to exhaust its budget")
  }
}

///|
test "type normalization rejects a capturing beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let capturing = @buslane.Type::Apply(
    TypeLambda(
      [x],
      Forall([y], Function([Parameter(x)], Primitive(Unit), Empty)),
    ),
    [TypeArgument(Parameter(y))],
  )
  try capturing.normalize() catch {
    InvalidBetaSubstitution(CapturedTypeParameter(parameter~, binder~)) => {
      assert_eq(parameter, x)
      assert_eq(binder, y)
    }
    error => fail("unexpected normalization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected the capturing reduction to be rejected")
  }
}

///|
test "definitional type equality reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let type_ = non_normalizing_type_application(parameter)
  assert_runaway_beta(() => metadata.types_definitionally_equal(type_, type_))
}

///|
test "type consumability reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let type_ = non_normalizing_type_application(parameter)
  assert_runaway_beta(() => metadata.type_is_consumable_as(type_, type_))
}

///|
test "definitional effect equality reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let effect = runaway_effect(
    metadata,
    non_normalizing_type_application(parameter),
  )
  assert_runaway_beta(() => {
    metadata.effects_definitionally_equal(effect, effect)
  })
}

///|
test "subeffect relation reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let effect = runaway_effect(
    metadata,
    non_normalizing_type_application(parameter),
  )
  assert_runaway_beta(() => metadata.effect_is_subeffect_of(effect, effect))
}

///|
test "effect canonicalization reports runaway beta reduction" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let effect = runaway_effect(
    metadata,
    non_normalizing_type_application(parameter),
  )
  assert_runaway_beta(() => metadata.canonicalize_effect(effect))
}

///|
test "empty-effect query returns a runaway beta diagnostic" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let effect = runaway_effect(
    metadata,
    non_normalizing_type_application(parameter),
  )
  let callable = metadata.define_value(
    "callable",
    Value,
    Function([], Primitive(Unit), effect),
  )
  let query = @buslane.ExpressionFactsQuery::new({ metadata, terms: [] })
  debug_inspect(
    query.has_empty_effect(Call(Ref(callable), [])),
    content=(
      #|Err({ diagnostics: [{ kind: TypeNormalizationFailure(BetaReductionLimitExceeded(limit=1024)) }] })
    ),
  )
}

///|
test "program verifier diagnoses runaway type normalization" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let type_ = non_normalizing_type_application(parameter)
  let value = metadata.define_value("value", Value, type_)
  let result = @buslane.verify_program({
    metadata,
    terms: [Let(value, Literal(Unit))],
  })
  assert_eq(result.diagnostics(), [
    { kind: KindMismatch(expected=Function([], Type), actual=Type) },
    { kind: KindMismatch(expected=Function([], Type), actual=Type) },
    { kind: KindMismatch(expected=Type, actual=Function([Type], Type)) },
    { kind: TypeNormalizationFailure(BetaReductionLimitExceeded(limit=1024)) },
    { kind: TypeMismatch(expected=type_, actual=Primitive(Unit)) },
  ])
}
