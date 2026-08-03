///|
test "unsupported source programs have a distinct specialization error" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let unit_type = @buslane.Type::Primitive(Unit)
  let entry = metadata.define_value(
    "entry",
    Function,
    Forall(
      [effect_parameter],
      Function([], unit_type, Parameter(effect_parameter)),
    ),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        TypeLambda(
          [effect_parameter],
          Function({
            parameters: [],
            result_type: unit_type,
            body: Literal(Unit),
          }),
        ),
      ),
    ],
  }
  try specialize(program, entry) catch {
    UnsupportedProgram(context) =>
      assert_eq(context, {
        detail: "an executable entry cannot retain effect parameters",
        site: Some(TopLevel(entry)),
        source: Some(Value(entry)),
        specialization_key: [],
      })
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an unsupported-program error")
  }
}

///|
test "invalid specialization input retains structured source context" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let unit_type = @buslane.Type::Primitive(Unit)
  let generic = metadata.define_value(
    "generic",
    Function,
    Forall(
      [effect_parameter],
      Function([], unit_type, Parameter(effect_parameter)),
    ),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: generic,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Literal(Unit),
            }),
          ),
        },
        {
          id: entry,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(TypeApply(Ref(generic), [TypeArgument(unit_type)]), []),
          }),
        },
      ]),
    ],
  }
  try specialize(program, entry) catch {
    InvalidInputMetadata(context) =>
      assert_eq(context, {
        detail: "an effect parameter requires an effect argument",
        site: Some(TopLevel(entry)),
        source: Some(TypeParameter(effect_parameter)),
        specialization_key: [],
      })
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an invalid-input-metadata error")
  }
}
