///|
fn test_program(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> Program {
  let result = metadata.define_value("result", Value, Primitive(Int))
  { metadata, terms: [Let(result, expression)] }
}

///|
test "mon-trans keeps pure calls direct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let callee = metadata.define_value(
    "callee",
    Value,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let input = test_program(metadata, Call(Ref(callee), [Literal(Int(1L))]))
  assert_eq(introduce_monadic_binds(input), Ok(input))
}

///|
test "mon-trans keeps Io calls direct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let println = metadata.define_value(
    "println",
    Value,
    Function([Primitive(String)], Primitive(Unit), Io),
  )
  let local_value = metadata.define_value("local", Local, Primitive(Unit))
  let input = test_program(
    metadata,
    Let(
      local_value,
      Call(Ref(println), [Literal(String("hello"))]),
      Literal(Int(1L)),
    ),
  )
  assert_eq(introduce_monadic_binds(input), Ok(input))
}

///|
test "mon effect classification separates Io from handled effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let handled = metadata.define_effect("Handled", [])
  let external = metadata.define_effect("External", [], flavor=External)
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  assert_false(is_mon_effect(metadata, Empty))
  assert_false(is_mon_effect(metadata, Io))
  assert_false(is_mon_effect(metadata, Singleton(external, [])))
  assert_true(is_mon_effect(metadata, Singleton(handled, [])))
  assert_true(is_mon_effect(metadata, Parameter(effect_parameter)))
  assert_true(
    is_mon_effect(
      metadata,
      Union([Io, Singleton(external, []), Singleton(handled, [])]),
    ),
  )
  assert_eq(
    mon_effect_part(
      metadata,
      Union([Io, Singleton(external, []), Singleton(handled, [])]),
    ),
    Singleton(handled, []),
  )
  assert_eq(
    residual_effect_part(
      metadata,
      Union([Io, Singleton(external, []), Singleton(handled, [])]),
    ),
    Union([Io, Singleton(external, [])]),
  )
  debug_inspect(
    (
      metadata.effect_info(handled).map(info => info.flavor),
      metadata.effect_info(external).map(info => info.flavor),
    ),
    content="(Some(Algebraic), Some(External))",
  )
}

///|
test "mon-trans keeps pure sequencing direct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let local_value = metadata.define_value("local", Local, Primitive(Int))
  let input = test_program(
    metadata,
    Let(local_value, Literal(Int(1L)), Ref(local_value)),
  )
  assert_eq(introduce_monadic_binds(input), Ok(input))
}

///|
test "mon-trans binds effectful calls before their continuation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let effectful = metadata.define_value(
    "effectful",
    Value,
    Function([], Primitive(Int), Singleton(effect, [])),
  )
  let pure = metadata.define_value(
    "pure",
    Value,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let local_value = metadata.define_value("local", Local, Primitive(Int))
  let input = test_program(
    metadata,
    Let(
      local_value,
      Call(Ref(effectful), []),
      Call(Ref(pure), [Ref(local_value)]),
    ),
  )
  let output = introduce_monadic_binds(input).unwrap()
  guard output.terms[0] is Let(_, Bind(bind)) else {
    abort("expected monadic bind")
  }
  assert_eq(bind.computation, Call(Ref(effectful), []))
  assert_eq(
    bind.continuation.body,
    Let(local_value, Ref(bind.binder), Call(Ref(pure), [Ref(local_value)])),
  )
}

///|
test "mon-trans preserves effectful argument order" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let first = metadata.define_value(
    "first",
    Value,
    Function([], Primitive(Int), Singleton(effect, [])),
  )
  let second = metadata.define_value(
    "second",
    Value,
    Function([], Primitive(Int), Singleton(effect, [])),
  )
  let combine = metadata.define_value(
    "combine",
    Value,
    Function([Primitive(Int), Primitive(Int)], Primitive(Int), Empty),
  )
  let output = introduce_monadic_binds(
    test_program(
      metadata,
      Call(Ref(combine), [Call(Ref(first), []), Call(Ref(second), [])]),
    ),
  ).unwrap()
  guard output.terms[0] is Let(_, Bind(first_bind)) else {
    abort("expected first argument bind")
  }
  guard first_bind.continuation.body is Bind(second_bind) else {
    abort("expected second argument bind")
  }
  assert_eq(first_bind.computation, Call(Ref(first), []))
  assert_eq(second_bind.computation, Call(Ref(second), []))
  assert_eq(
    second_bind.continuation.body,
    Call(Ref(combine), [Ref(first_bind.binder), Ref(second_bind.binder)]),
  )
}

///|
test "mon-trans evaluates an effectful callee before its argument" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let get_callee = metadata.define_value(
    "get_callee",
    Value,
    Function(
      [],
      Function([Primitive(Int)], Primitive(Int), Empty),
      Singleton(effect, []),
    ),
  )
  let argument = metadata.define_value(
    "argument",
    Value,
    Function([], Primitive(Int), Singleton(effect, [])),
  )
  let output = introduce_monadic_binds(
    test_program(
      metadata,
      Call(Call(Ref(get_callee), []), [Call(Ref(argument), [])]),
    ),
  ).unwrap()
  guard output.terms[0] is Let(_, Bind(callee_bind)) else {
    abort("expected callee bind")
  }
  guard callee_bind.continuation.body is Bind(argument_bind) else {
    abort("expected argument bind")
  }
  assert_eq(callee_bind.computation, Call(Ref(get_callee), []))
  assert_eq(argument_bind.computation, Call(Ref(argument), []))
  assert_eq(
    argument_bind.continuation.body,
    Call(Ref(callee_bind.binder), [Ref(argument_bind.binder)]),
  )
}

///|
test "mon-trans shares one continuation after effectful match branches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let effectful = metadata.define_value(
    "effectful",
    Value,
    Function([], Primitive(Int), Singleton(effect, [])),
  )
  let pure = metadata.define_value(
    "pure",
    Value,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let match_binder = metadata.define_value(
    "match",
    MatchBinder,
    Primitive(Bool),
  )
  let local_value = metadata.define_value("local", Local, Primitive(Int))
  let input = test_program(
    metadata,
    Let(
      local_value,
      Match({
        scrutinee: Literal(Bool(true)),
        binder: match_binder,
        result_type: Primitive(Int),
        alternatives: [
          {
            alt_constructor: Literal(Bool(true)),
            type_binders: [],
            value_binders: [],
            body: Call(Ref(effectful), []),
          },
          {
            alt_constructor: Default,
            type_binders: [],
            value_binders: [],
            body: Literal(Int(0L)),
          },
        ],
      }),
      Call(Ref(pure), [Ref(local_value)]),
    ),
  )
  let output = introduce_monadic_binds(input).unwrap()
  guard output.terms[0] is Let(_, Bind(bind)) else {
    abort("expected shared match bind")
  }
  guard bind.computation is Match(match_) else {
    abort("expected match computation")
  }
  assert_eq(match_.alternatives[0].body, Call(Ref(effectful), []))
  assert_eq(
    bind.continuation.body,
    Let(local_value, Ref(bind.binder), Call(Ref(pure), [Ref(local_value)])),
  )
}

///|
test "mon-trans records open context adaptation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let first_effect = metadata.define_effect("First", [])
  let second_effect = metadata.define_effect("Second", [])
  let callee = metadata.define_value(
    "callee",
    Value,
    Function([], Primitive(Int), Singleton(first_effect, [])),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Function(
      [],
      Primitive(Int),
      Union([Singleton(first_effect, []), Singleton(second_effect, [])]),
    ),
  )
  let function = Function({
    parameters: [],
    result_type: Primitive(Int),
    body: Let(
      metadata.define_value("local", Local, Primitive(Int)),
      Call(Ref(callee), []),
      Invoke({
        operation: metadata.define_operation(
          "second",
          second_effect,
          [],
          [],
          Primitive(Int),
        ),
        effect_arguments: [],
        hidden_witnesses: [],
        payloads: [],
      }),
    ),
  })
  let output = introduce_monadic_binds({
    metadata,
    terms: [LetRec([{ id: outer, rhs: function }])],
  }).unwrap()
  guard output.terms[0] is LetRec([{ rhs: Function(transformed), .. }]) else {
    abort("expected transformed function")
  }
  guard transformed.body is Bind(bind) else { abort("expected open call bind") }
  assert_eq(
    bind.computation,
    OpenContext({
      source_effect: Singleton(first_effect, []),
      target_effect: Union([
        Singleton(first_effect, []),
        Singleton(second_effect, []),
      ]),
      body: Call(Ref(callee), []),
    }),
  )
}

///|
test "mon-trans binds calls with an abstract effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let callee = metadata.define_value(
    "callee",
    Value,
    Function([], Primitive(Int), Parameter(effect_parameter)),
  )
  let outer = metadata.define_value(
    "outer",
    Function,
    Forall(
      [effect_parameter],
      Function([], Primitive(Int), Parameter(effect_parameter)),
    ),
  )
  let local_value = metadata.define_value("local", Local, Primitive(Int))
  let output = introduce_monadic_binds({
    metadata,
    terms: [
      LetRec([
        {
          id: outer,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [],
              result_type: Primitive(Int),
              body: Let(local_value, Call(Ref(callee), []), Ref(local_value)),
            }),
          ),
        },
      ]),
    ],
  }).unwrap()
  guard output.terms[0]
    is LetRec([{ rhs: TypeLambda(_, Function(transformed)), .. }]) else {
    abort("expected transformed effect-polymorphic function")
  }
  guard transformed.body is Bind(bind) else {
    abort("expected abstract-effect bind")
  }
  assert_eq(bind.computation, Call(Ref(callee), []))
  assert_eq(
    bind.continuation.body,
    Let(local_value, Ref(bind.binder), Ref(local_value)),
  )
}
