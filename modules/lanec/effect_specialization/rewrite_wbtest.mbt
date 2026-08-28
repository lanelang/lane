///|
/// White-box tests for planning, allocation, and mechanical rewriting.
test "effect rewrite child scopes isolate shadowed value bindings" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let source = metadata.define_value("source", Local, unit_type)
  let parent_target = metadata.define_value("parent", Local, unit_type)
  let child_target = metadata.define_value("child", Local, unit_type)
  let parent = EffectRewriteScope::new(source, [])
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
  let entry_type = @buslane.Type::Function(
    [],
    unit_type,
    Singleton(log_effect, []),
  )
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
  let verified = match program.certify() {
    Ok(program) => program
    Err(result) => abort("invalid test input: \{Repr(result)}")
  }
  let specialized = specialize(verified, entry)
  guard specialized.program().terms is [Let(_, Function({ body, .. }))] &&
    body is Let(captured_target, Literal(Unit), nested) &&
    nested
    is LetRec(
      [{ id: target, rhs: Function({ body: Ref(captured_reference), .. }), }],
      Call(Ref(callee), [])
    ) else {
    abort("expected one lexical concrete specialization")
  }
  assert_eq(captured_target, captured_reference)
  assert_true(captured_target != captured)
  assert_eq(target, callee)
  assert_true(target != local_function)
  assert_eq(
    specialized.program().metadata.value_info(target).map(info => info.type_),
    Some(Function([], unit_type, Singleton(log_effect, []))),
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
  let entry_type = @buslane.Type::Function(
    [],
    unit_type,
    Singleton(log_effect, []),
  )
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
  let specialized = specialize(program.certify().unwrap(), entry)
  guard specialized.program().terms
    is [LetRec([instance]), LetRec(entry_bindings)] else {
    abort("expected one specialized callable and one retained entry")
  }
  guard entry_bindings is [{ rhs: Function(entry_function), .. }] &&
    entry_function.body is Call(Ref(target), []) else {
    abort("expected the entry call to target the specialized callable")
  }
  assert_true(target != generic)
  assert_eq(instance.id, target)
  assert_eq(
    specialized.program().metadata.value_info(target).map(info => info.type_),
    Some(Function([], unit_type, Singleton(log_effect, []))),
  )
  assert_true(instance.rhs is Function(_))
}

///|
test "runtime polymorphism propagates through symbolic effect forwarding" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let leaf_effect = metadata.define_type_parameter("LeafEff", Effect)
  let middle_effect = metadata.define_type_parameter("MiddleEff", Effect)
  let outer_effect = metadata.define_type_parameter("OuterEff", Effect)
  let leaf_type = @buslane.Type::Forall(
    [leaf_effect],
    Function([], unit_type, Parameter(leaf_effect)),
  )
  let middle_type = @buslane.Type::Forall(
    [middle_effect],
    Function([], unit_type, Parameter(middle_effect)),
  )
  let outer_type = @buslane.Type::Forall(
    [outer_effect],
    Function([], unit_type, Parameter(outer_effect)),
  )
  let leaf = metadata.define_value("leaf", Function, leaf_type)
  let middle = metadata.define_value("middle", Function, middle_type)
  let outer = metadata.define_value("outer", Function, outer_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], outer_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: leaf,
          rhs: TypeLambda(
            [leaf_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Literal(Unit),
            }),
          ),
        },
        {
          id: middle,
          rhs: TypeLambda(
            [middle_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Call(
                TypeApply(Ref(leaf), [EffectArgument(Parameter(middle_effect))]),
                [],
              ),
            }),
          ),
        },
        {
          id: outer,
          rhs: TypeLambda(
            [outer_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Call(
                TypeApply(Ref(middle), [EffectArgument(Parameter(outer_effect))]),
                [],
              ),
            }),
          ),
        },
        {
          id: entry,
          rhs: Function({
            parameters: [],
            result_type: outer_type,
            body: Ref(outer),
          }),
        },
      ]),
    ],
  }
  let specialized = specialize(program.certify().unwrap(), entry)
  assert_eq(@buslane.verify_program(specialized.program()).diagnostics, [])
  guard specialized.program().terms is [LetRec(bindings)] else {
    abort("expected every symbolic forwarding definition to be retained")
  }
  assert_eq(bindings.map(binding => binding.id), [leaf, middle, outer, entry])
}

///|
test "unreachable bare references do not retain effect-polymorphic definitions" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let log_effect = metadata.define_effect("Log", [])
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let generic_type = @buslane.Type::Forall(
    [effect_parameter],
    Function([], unit_type, Parameter(effect_parameter)),
  )
  let generic = metadata.define_value("generic", Function, generic_type)
  let entry_type = @buslane.Type::Function(
    [],
    unit_type,
    Singleton(log_effect, []),
  )
  let entry = metadata.define_value("entry", Function, entry_type)
  let dead = metadata.define_value("dead", Function, generic_type)
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
      Let(dead, Ref(generic)),
    ],
  }
  let verified = match program.certify() {
    Ok(program) => program
    Err(result) => abort("invalid test input: \{Repr(result)}")
  }
  let specialized = specialize(verified, entry)
  guard specialized.program().terms
    is [LetRec([instance]), LetRec([entry_binding])] else {
    abort("expected dead references to leave one concrete specialization")
  }
  assert_eq(entry_binding.id, entry)
  guard entry_binding.rhs is Function({ body: Call(Ref(target), []), .. }) else {
    abort("expected the entry to call the concrete specialization")
  }
  assert_eq(instance.id, target)
  assert_true(target != generic)
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
  let log_operation = metadata.define_operation(
    "log",
    log_effect,
    [],
    [],
    unit_type,
  )
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
  let entry_type = @buslane.Type::Function(
    [],
    unit_type,
    Singleton(log_effect, []),
  )
  let entry = metadata.define_value("entry", Function, entry_type)
  let action_step = metadata.define_value("action_step", Local, unit_type)
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
                  body: Let(
                    action_step,
                    Perform({
                      operation: yield_operation,
                      effect_arguments: [],
                      hidden_witnesses: [],
                      payloads: [],
                    }),
                    Perform({
                      operation: log_operation,
                      effect_arguments: [],
                      hidden_witnesses: [],
                      payloads: [],
                    }),
                  ),
                }),
              ],
            ),
          }),
        },
      ]),
    ],
  }
  let verified = match program.certify() {
    Ok(program) => program
    Err(result) => abort("invalid test input: \{Repr(result)}")
  }
  let specialized = specialize(verified, entry)
  guard specialized.program().terms is [LetRec([instance]), LetRec(_)] &&
    instance.rhs is Function(function) &&
    function.body is Handle(handle) &&
    handle.handlers is [{ operations: [operation], .. }] else {
    abort("expected a specialized handler instance")
  }
  assert_eq(
    specialized.program().metadata
    .value_info(instance.id)
    .map(info => info.type_),
    Some(Function([concrete_action_type], unit_type, concrete_residual)),
  )
  assert_eq(
    specialized.program().metadata
    .value_info(function.parameters[0])
    .map(info => info.type_),
    Some(concrete_action_type),
  )
  assert_eq(
    specialized.program().metadata
    .value_info(operation.resume_binder)
    .map(info => info.type_),
    Some(Function([unit_type], unit_type, concrete_residual)),
  )
}

///|
/// Specializing an effect-generic data type has to reach the declarations that
/// name it, not only the expressions that build it. A monomorphic definition
/// and a retained data constructor both keep their declared types while their
/// bodies are rewritten around them.
test "effect specialization rewrites retained declarations that name a specialized type" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let log = metadata.define_effect("Log", [])
  let trace = metadata.define_effect("Trace", [])
  let box = metadata.define_type("Box", [effect_parameter])
  let make_box = metadata.define_data_constructor("box", box, [], [
    Primitive(I64),
  ])
  let concrete_effect = @buslane.Effect::Union([
    Singleton(log, []),
    Singleton(trace, []),
  ])
  let reversed_effect = @buslane.Effect::Union([
    Singleton(trace, []),
    Singleton(log, []),
  ])
  let boxed : @buslane.Type = Apply(Constructor(box), [
    EffectArgument(concrete_effect),
  ])
  let reversed_boxed : @buslane.Type = Apply(Constructor(box), [
    EffectArgument(reversed_effect),
  ])
  let holder = metadata.define_type("Holder", [])
  let make_holder = metadata.define_data_constructor("holder", holder, [], [
    boxed, reversed_boxed,
  ])
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Constructor(holder), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Constructor(holder),
          body: Construct({
            data_constructor: make_holder,
            type_arguments: [],
            hidden_witnesses: [],
            payloads: [
              Construct({
                data_constructor: make_box,
                type_arguments: [EffectArgument(concrete_effect)],
                hidden_witnesses: [],
                payloads: [Literal(I64(1L))],
              }),
              Construct({
                data_constructor: make_box,
                type_arguments: [EffectArgument(reversed_effect)],
                hidden_witnesses: [],
                payloads: [Literal(I64(2L))],
              }),
            ],
          }),
        }),
      ),
    ],
  }
  assert_eq(plan_effect_specializations(program, entry), {
    callable_demands: [],
    retained_top_terms: [RetainedLet(source_index=0, value=entry)],
    retained_declarations: [DataConstructor(make_holder)],
    data_demands: [
      {
        source: box,
        bindings: [
          {
            parameter: effect_parameter,
            argument: EffectArgument(
              metadata.canonicalize_effect(concrete_effect),
            ),
          },
        ],
        constructors: [make_box],
      },
    ],
  })
  let source_type_count = metadata.types.length()
  let source_constructor_count = metadata.data_constructors.length()
  let specialized = specialize(program.certify().unwrap(), entry)
  assert_eq(metadata.types.length(), source_type_count)
  assert_eq(metadata.data_constructors.length(), source_constructor_count)
  assert_eq(
    specialized.program().metadata.types.length(),
    source_type_count + 1,
  )
  assert_eq(
    specialized.program().metadata.data_constructors.length(),
    source_constructor_count + 1,
  )
  let result = @buslane.verify_program(specialized.program())
  if !result.is_ok() {
    fail("specialized program did not verify: \{Repr(result)}")
  }
}
