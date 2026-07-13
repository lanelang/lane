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
  assert_eq(dictionary_info.parameters, [element, dictionary.answer_parameter])
  let answer = @buslane.Type::Parameter(dictionary.answer_parameter)
  let data_constructor = dictionary_info.constructors[0]
  let fields = metadata.data_constructor_info(data_constructor).unwrap().payload_types
  assert_eq(
    fields[0],
    Function([Function([Parameter(element)], answer, Empty)], answer, Empty),
  )
  assert_eq(
    fields[1],
    Forall(
      [hidden],
      Function(
        [
          Parameter(hidden),
          Parameter(element),
          Function([Primitive(Unit)], answer, Empty),
        ],
        answer,
        Empty,
      ),
    ),
  )
  assert_eq(metadata.effect_info(effect).unwrap().operations, [get, put])
  assert_true(@buslane.verify_program({ metadata, terms: [] }).is_ok())
}

///|
test "effect parameters receive one stable ordinary companion" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let first = schema.companion_parameter(effect_parameter)
  let second = schema.companion_parameter(effect_parameter)
  assert_eq(first, second)
  assert_eq(metadata.type_parameter_info(first).unwrap().kind, Type)
  assert_true(first != effect_parameter)
}

///|
test "public type planning shares one generated schema" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let pure_type = @buslane.Type::Function(
    [Primitive(Int)],
    Primitive(Int),
    Empty,
  )
  let planned = plan_dictionary_cps_types(metadata, [
    pure_type,
    Function([], Primitive(Int), Singleton(effect, [])),
  ]).unwrap()
  assert_eq(planned[0], pure_type)
  guard planned[1] is Forall([_], Function(_, _, Empty)) else {
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
  let answer : @buslane.Type = Primitive(Int)
  assert_eq(schema.packed_context_type(Empty, answer), Primitive(Unit))
  let first_type = schema.context_term_type(Singleton(first_effect, []), answer)
  assert_eq(
    schema.packed_context_type(Singleton(first_effect, []), answer),
    first_type,
  )
  let packed = schema.packed_context_type(
    Union([Singleton(first_effect, []), Singleton(second_effect, [])]),
    answer,
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
test "type rewriting erases nested and abstract latent effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let schema = build_dictionary_cps_schema_or_raise(metadata)
  let companion = schema.companion_parameter(effect_parameter)
  assert_eq(
    schema.rewrite_type(Function([Primitive(Int)], Primitive(Int), Empty)),
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let rewritten = schema.rewrite_type(
    Forall(
      [effect_parameter],
      Function(
        [Function([], Primitive(Int), Parameter(effect_parameter))],
        Primitive(Int),
        Parameter(effect_parameter),
      ),
    ),
  )
  guard rewritten
    is Forall(
      [outer_companion],
      Forall(
        [answer],
        Function(
          [outer_context, nested_callable, continuation],
          rewritten_answer,
          Empty
        )
      )
    ) else {
    abort("expected nested selective CPS type")
  }
  assert_eq(outer_companion, companion)
  assert_eq(outer_context, Parameter(companion))
  assert_eq(rewritten_answer, Parameter(answer))
  assert_eq(continuation, Function([Primitive(Int)], Parameter(answer), Empty))
  guard nested_callable
    is Forall(
      [nested_answer],
      Function([nested_context, nested_continuation], nested_result, Empty)
    ) else {
    abort("expected nested callable CPS type")
  }
  assert_eq(nested_context, Parameter(companion))
  assert_eq(nested_result, Parameter(nested_answer))
  assert_eq(
    nested_continuation,
    Function([Primitive(Int)], Parameter(nested_answer), Empty),
  )
}
