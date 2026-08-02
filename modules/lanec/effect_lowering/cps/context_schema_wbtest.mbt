///|
test "dictionary schema follows operation order and CPS field types" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let effect = metadata.define_effect("Store", [element])
  let get = metadata.define_operation("get", effect, [], [], Parameter(element))
  let put = metadata.define_operation(
    "put",
    effect,
    [hidden],
    [Parameter(hidden), Parameter(element)],
    Primitive(Unit),
  )
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let dictionary = schema.dictionary(effect)
  let dictionary_info = metadata.type_info(dictionary.type_id).unwrap()
  assert_eq(dictionary_info.constructors.length(), 1)
  assert_eq(dictionary_info.parameters, [
    element,
    dictionary.answer_parameter,
    dictionary.residual_parameter,
  ])
  let answer = @buslane.Type::Parameter(dictionary.answer_parameter)
  let residual = @buslane.Effect::Parameter(dictionary.residual_parameter)
  let data_constructor = dictionary_info.constructors[0]
  let fields = metadata.data_constructor_info(data_constructor).unwrap().payload_types
  assert_eq(
    fields[0],
    Function(
      [Function([Parameter(element)], answer, residual)],
      answer,
      residual,
    ),
  )
  assert_eq(
    fields[1],
    Forall(
      [hidden],
      Function(
        [
          Parameter(hidden),
          Parameter(element),
          Function([Primitive(Unit)], answer, residual),
        ],
        answer,
        residual,
      ),
    ),
  )
  assert_eq(metadata.effect_info(effect).unwrap().operations, [get, put])
  assert_true(@buslane.verify_program({ metadata, terms: [] }).is_ok())
}

///|
test "effect parameters receive one stable higher-kinded companion" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let first = schema.companion_parameter(effect_parameter)
  let second = schema.companion_parameter(effect_parameter)
  let first_residual = schema.residual_parameter(effect_parameter)
  let second_residual = schema.residual_parameter(effect_parameter)
  assert_eq(first, second)
  assert_eq(first_residual, second_residual)
  assert_eq(
    metadata.type_parameter_info(first).unwrap().kind,
    Function([Type, Effect], Type),
  )
  assert_true(first != effect_parameter)
  assert_true(first_residual != effect_parameter)
  assert_eq(metadata.type_parameter_info(first_residual).unwrap().kind, Effect)
  assert_eq(
    metadata.type_parameter_info(first_residual).unwrap().flavor,
    External,
  )
}

///|
test "selective CPS exposes effect companion identities" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let result = rewrite_selective_cps_abis_with_companions({
    metadata,
    terms: [],
  }).unwrap()
  guard result.effect_companions is [{ source, companion, residual }] else {
    abort("expected one effect companion binding")
  }
  assert_eq(source, effect_parameter)
  assert_eq(
    metadata.type_parameter_info(companion).unwrap().kind,
    Function([Type, Effect], Type),
  )
  assert_eq(metadata.type_parameter_info(residual).unwrap().kind, Effect)
  assert_eq(metadata.type_parameter_info(residual).unwrap().flavor, External)
}

///|
test "effect application carries context and residual projections independently" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let handled = metadata.define_effect("Handled", [])
  let external = metadata.define_effect("External", [], flavor=External)
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let companion = schema.companion_parameter(effect_parameter)
  let residual = schema.residual_parameter(effect_parameter)
  let rewrite = effect => {
    schema.rewrite_cps_application_arguments(
      effect_parameter,
      EffectArgument(effect),
    )
  }
  assert_true(
    rewrite(Empty)
    is [
      TypeArgument(TypeLambda([_, _], Primitive(Unit))),
      EffectArgument(Empty),
    ],
  )
  assert_true(
    rewrite(Io)
    is [TypeArgument(TypeLambda([_, _], Primitive(Unit))), EffectArgument(Io)],
  )
  assert_true(
    rewrite(Singleton(external, []))
    is [
      TypeArgument(TypeLambda([_, _], Primitive(Unit))),
      EffectArgument(Singleton(actual_external, [])),
    ] &&
    actual_external == external,
  )
  assert_true(
    rewrite(Singleton(handled, []))
    is [
      TypeArgument(TypeLambda([_, _], Apply(Constructor(_), _))),
      EffectArgument(Empty),
    ],
  )
  assert_true(
    rewrite(Union([Singleton(handled, []), Io]))
    is [
      TypeArgument(TypeLambda([_, _], Apply(Constructor(_), _))),
      EffectArgument(Io),
    ],
  )
  assert_eq(rewrite(Parameter(effect_parameter)), [
    TypeArgument(Parameter(companion)),
    EffectArgument(Parameter(residual)),
  ])
}

///|
test "type planning shares one generated schema" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let pure_type = @buslane.Type::Function(
    [Primitive(I64)],
    Primitive(I64),
    Empty,
  )
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let planned = [
    schema.rewrite_type(pure_type),
    schema.rewrite_type(Function([], Primitive(I64), Singleton(effect, []))),
  ]
  assert_eq(planned[0], pure_type)
  guard planned[1] is Forall([_, residual], Function(_, _, Parameter(latent))) &&
    residual == latent else {
    abort("expected planned CPS type")
  }
  assert_eq(metadata.effect_info(effect).unwrap().operations, [])
}

///|
test "context types cover empty singleton and ordered unions" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let first_effect = metadata.define_effect("First", [])
  let second_effect = metadata.define_effect("Second", [])
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let answer : @buslane.Type = Primitive(I64)
  assert_eq(schema.packed_context_type(Empty, answer, Empty), Primitive(Unit))
  let first_type = schema.context_term_type(
    Singleton(first_effect, []),
    answer,
    Empty,
  )
  assert_eq(
    schema.packed_context_type(Singleton(first_effect, []), answer, Empty),
    first_type,
  )
  let packed = schema.packed_context_type(
    Union([Singleton(first_effect, []), Singleton(second_effect, [])]),
    answer,
    Empty,
  )
  guard packed is Apply(Constructor(pack_type), arguments) else {
    abort("expected context pack")
  }
  assert_eq(arguments.length(), 2)
  let pack = schema.context_pack(2)
  assert_eq(pack.type_id, pack_type)
  assert_eq(schema.context_pack(2).type_id, pack_type)
  let pack_info = metadata.type_info(pack.type_id).unwrap()
  let pack_constructor = pack_info.constructors[0]
  assert_eq(
    metadata.data_constructor_info(pack_constructor).unwrap().payload_types,
    pack_info.parameters.map(parameter => Parameter(parameter)),
  )
}

///|
test "type rewriting preserves residual effects and rewrites monadic effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let handled = metadata.define_effect("Handled", [])
  let external = metadata.define_effect("External", [], flavor=External)
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let companion = schema.companion_parameter(effect_parameter)
  let effect_residual = schema.residual_parameter(effect_parameter)
  assert_eq(
    schema.rewrite_type(Function([Primitive(I64)], Primitive(I64), Empty)),
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  assert_eq(
    schema.rewrite_type(Function([Primitive(String)], Primitive(Unit), Io)),
    Function([Primitive(String)], Primitive(Unit), Io),
  )
  assert_eq(
    schema.rewrite_type(
      Function([Primitive(I64)], Primitive(I64), Singleton(external, [])),
    ),
    Function([Primitive(I64)], Primitive(I64), Singleton(external, [])),
  )
  let mixed = schema.rewrite_type(
    Function(
      [Primitive(String)],
      Primitive(Unit),
      Union([Io, Singleton(handled, [])]),
    ),
  )
  guard mixed
    is Forall(
      [mixed_answer, mixed_residual],
      Function(
        [_, Primitive(String), mixed_continuation],
        mixed_result,
        mixed_latent
      )
    ) else {
    abort("expected mixed effect CPS type")
  }
  // The function performs `Io` itself and propagates whatever its dictionary
  // and continuation perform, so its row is both.
  let mixed_row = @buslane.Effect::Union([Io, Parameter(mixed_residual)])
  assert_eq(mixed_latent, mixed_row)
  assert_eq(mixed_result, Parameter(mixed_answer))
  assert_eq(
    mixed_continuation,
    Function([Primitive(Unit)], Parameter(mixed_answer), mixed_row),
  )
  let rewritten = schema.rewrite_type(
    Forall(
      [effect_parameter],
      Function(
        [Function([], Primitive(I64), Parameter(effect_parameter))],
        Primitive(I64),
        Parameter(effect_parameter),
      ),
    ),
  )
  guard rewritten
    is Forall(
      [outer_companion, outer_effect_residual],
      Forall(
        [answer, residual],
        Function(
          [outer_context, nested_callable, continuation],
          rewritten_answer,
          outer_latent
        )
      )
    ) else {
    abort("expected nested selective CPS type")
  }
  assert_eq(outer_companion, companion)
  assert_eq(outer_effect_residual, effect_residual)
  let outer_row = @buslane.Effect::Union([
    Parameter(effect_residual),
    Parameter(residual),
  ])
  assert_eq(
    outer_context,
    Apply(Parameter(companion), [
      TypeArgument(Parameter(answer)),
      EffectArgument(outer_row),
    ]),
  )
  assert_eq(rewritten_answer, Parameter(answer))
  assert_eq(outer_latent, outer_row)
  assert_eq(
    continuation,
    Function([Primitive(I64)], Parameter(answer), outer_row),
  )
  guard nested_callable
    is Forall(
      [nested_answer, nested_residual],
      Function(
        [nested_context, nested_continuation],
        nested_result,
        nested_latent
      )
    ) else {
    abort("expected nested callable CPS type")
  }
  let nested_row = @buslane.Effect::Union([
    Parameter(effect_residual),
    Parameter(nested_residual),
  ])
  assert_eq(
    nested_context,
    Apply(Parameter(companion), [
      TypeArgument(Parameter(nested_answer)),
      EffectArgument(nested_row),
    ]),
  )
  assert_true(outer_context != nested_context)
  assert_eq(nested_result, Parameter(nested_answer))
  assert_eq(nested_latent, nested_row)
  assert_eq(
    nested_continuation,
    Function([Primitive(I64)], Parameter(nested_answer), nested_row),
  )
}
