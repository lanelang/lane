///|
test "effect rewrite child scopes isolate shadowed value bindings" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let source = metadata.define_value("source", Local, unit_type)
  let parent_target = metadata.define_value("parent", Local, unit_type)
  let child_target = metadata.define_value("child", Local, unit_type)
  let parent = EffectRewriteScope::new([])
  parent.bind_value(source, parent_target)
  let child = parent.enter_scope()
  child.bind_value(source, child_target)
  assert_eq(parent.lookup_value(source), Some(parent_target))
  assert_eq(child.lookup_value(source), Some(child_target))
}

///|
test "reachable local effect-generic functions specialize in lexical scope" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let log_effect = metadata.define_effect("Log", [])
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let local_type = @buslane.Type::Forall(
    [effect_parameter],
    Function([], unit_type, Parameter(effect_parameter)),
  )
  let captured = metadata.define_value("captured", Local, unit_type)
  let local_function = metadata.define_value("local", Local, local_type)
  let entry_type = @buslane.Type::Function([], unit_type, Empty)
  let entry = metadata.define_value("entry", Function, entry_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            captured,
            Literal(Unit),
            LetRec(
              [
                {
                  id: local_function,
                  rhs: TypeLambda(
                    [effect_parameter],
                    Function({
                      parameters: [],
                      result_type: unit_type,
                      body: Ref(captured),
                    }),
                  ),
                },
              ],
              Call(
                TypeApply(Ref(local_function), [
                  EffectArgument(Singleton(log_effect, [])),
                ]),
                [],
              ),
            ),
          ),
        }),
      ),
    ],
  }
  let specialized = specialize_reachable_effects(program, entry)
  guard specialized.terms is [Let(_, Function({ body, .. }))] &&
    body is Let(captured_target, Literal(Unit), nested) &&
    nested
    is LetRec(
      [{ id: target, rhs: Function({ body: Ref(captured_reference), .. }) }],
      Call(Ref(callee), [])
    ) else {
    abort("expected one lexical concrete specialization")
  }
  assert_eq(captured_target, captured_reference)
  assert_true(captured_target != captured)
  assert_eq(target, callee)
  assert_true(target != local_function)
  assert_eq(
    specialized.metadata.value_info(target).map(info => info.type_),
    Some(Function([], unit_type, Singleton(log_effect, []))),
  )
}

///|
test "effect parameter detection traverses singleton arguments" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let outer_effect = metadata.define_effect("Outer", [])
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  assert_true(
    effect_contains_parameter(
      Singleton(outer_effect, [EffectArgument(Parameter(effect_parameter))]),
    ),
  )
}

///|
test "reachable effect applications create concrete callable instances" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let log_effect = metadata.define_effect("Log", [])
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let generic_type = @buslane.Type::Forall(
    [effect_parameter],
    Function([], unit_type, Parameter(effect_parameter)),
  )
  let generic = metadata.define_value("generic", Function, generic_type)
  let entry_type = @buslane.Type::Function([], unit_type, Empty)
  let entry = metadata.define_value("entry", Function, entry_type)
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
            body: Call(
              TypeApply(Ref(generic), [
                EffectArgument(Singleton(log_effect, [])),
              ]),
              [],
            ),
          }),
        },
      ]),
    ],
  }
  let specialized = specialize_reachable_effects(program, entry)
  guard specialized.terms is [LetRec(entry_bindings), LetRec([instance])] else {
    abort("expected one retained entry and one specialized callable")
  }
  guard entry_bindings is [{ rhs: Function(entry_function), .. }] &&
    entry_function.body is Call(Ref(target), []) else {
    abort("expected the entry call to target the specialized callable")
  }
  assert_true(target != generic)
  assert_eq(instance.id, target)
  assert_eq(
    specialized.metadata.value_info(target).map(info => info.type_),
    Some(Function([], unit_type, Singleton(log_effect, []))),
  )
  assert_true(instance.rhs is Function(_))
}

///|
test "handler residual effects specialize before answer-type CPS" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let coroutine = metadata.define_effect("Coroutine", [])
  let yield_operation = metadata.define_operation(
    "yield",
    coroutine,
    [],
    [],
    unit_type,
  )
  let log_effect = metadata.define_effect("Log", [])
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let residual = @buslane.Effect::Parameter(effect_parameter)
  let handled = @buslane.Effect::Singleton(coroutine, [])
  let action_effect = @buslane.Effect::Union([handled, residual])
  let action_type = @buslane.Type::Function([], unit_type, action_effect)
  let run_type = @buslane.Type::Forall(
    [effect_parameter],
    Function([action_type], unit_type, residual),
  )
  let run = metadata.define_value("run", Function, run_type)
  let action = metadata.define_value("action", Parameter, action_type)
  let handled_result = metadata.define_value("result", Local, unit_type)
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([unit_type], unit_type, residual),
  )
  let entry_type = @buslane.Type::Function([], unit_type, Empty)
  let entry = metadata.define_value("entry", Function, entry_type)
  let concrete_residual = @buslane.Effect::Singleton(log_effect, [])
  let concrete_action_type = @buslane.Type::Function(
    [],
    unit_type,
    Union([handled, concrete_residual]),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: run,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [action],
              result_type: unit_type,
              body: Handle({
                body: Call(Ref(action), []),
                result_binder: handled_result,
                result_type: unit_type,
                final_body: Ref(handled_result),
                handlers: [
                  {
                    handled_effect: handled,
                    operations: [
                      {
                        operation: yield_operation,
                        type_binders: [],
                        payload_binders: [],
                        resume_binder: resume_value,
                        body: Call(Ref(resume_value), [Literal(Unit)]),
                      },
                    ],
                  },
                ],
              }),
            }),
          ),
        },
        {
          id: entry,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(
              TypeApply(Ref(run), [EffectArgument(concrete_residual)]),
              [
                Function({
                  parameters: [],
                  result_type: unit_type,
                  body: Literal(Unit),
                }),
              ],
            ),
          }),
        },
      ]),
    ],
  }
  let specialized = specialize_reachable_effects(program, entry)
  guard specialized.terms is [LetRec(_), LetRec([instance])] &&
    instance.rhs is Function(function) &&
    function.body is Handle(handle) &&
    handle.handlers is [{ operations: [operation], .. }] else {
    abort("expected a specialized handler instance")
  }
  assert_eq(
    specialized.metadata.value_info(instance.id).map(info => info.type_),
    Some(Function([concrete_action_type], unit_type, concrete_residual)),
  )
  assert_eq(
    specialized.metadata
    .value_info(function.parameters[0])
    .map(info => info.type_),
    Some(concrete_action_type),
  )
  assert_eq(
    specialized.metadata
    .value_info(operation.resume_binder)
    .map(info => info.type_),
    Some(Function([unit_type], unit_type, concrete_residual)),
  )
}
