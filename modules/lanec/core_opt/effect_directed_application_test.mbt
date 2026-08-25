///|
fn optimized_entry_body(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> @buslane.Expr {
  for term in program.terms {
    if term is Let(value, Function(function)) && value == entry {
      return function.body
    }
  }
  abort("expected optimized entry function")
}

///|
test "core optimizer reduces a direct lambda with a complex empty argument" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let producer_type = @buslane.Type::Function([], i64_type, Empty)
  let producer = metadata.define_value("producer", External, producer_type)
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let entry = metadata.define_value("entry", Function, producer_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(producer),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: i64_type,
              body: Ref(parameter),
            }),
            [Call(Ref(producer), [])],
          ),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(optimized_entry_body(optimized, entry), Call(Ref(producer), []))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer preserves a pure callable adaptation boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let pure_action_type = @buslane.Type::Function([], unit_type, Empty)
  let io_action_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let action = metadata.define_value("action", External, pure_action_type)
  let parameter = metadata.define_value("action", Parameter, io_action_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], io_action_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(action),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: io_action_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: io_action_type,
              body: Ref(parameter),
            }),
            [Ref(action)],
          ),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(
    optimized_entry_body(optimized, entry),
    Let(parameter, Ref(action), Ref(parameter)),
  )
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer reduces a known call with a complex empty argument" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let producer_type = @buslane.Type::Function([], i64_type, Empty)
  let identity_type = @buslane.Type::Function([i64_type], i64_type, Empty)
  let producer = metadata.define_value("producer", External, producer_type)
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let identity = metadata.define_value("identity", Function, identity_type)
  let entry = metadata.define_value("entry", Function, producer_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(producer),
      Let(
        identity,
        Function({
          parameters: [parameter],
          result_type: i64_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(identity), [Call(Ref(producer), [])]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(optimized_entry_body(optimized, entry), Call(Ref(producer), []))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer removes an unused complex empty argument" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let producer_type = @buslane.Type::Function([], unit_type, Empty)
  let discard_type = @buslane.Type::Function([unit_type], unit_type, Empty)
  let producer = metadata.define_value("producer", External, producer_type)
  let parameter = metadata.define_value("value", Parameter, unit_type)
  let discard = metadata.define_value("discard", Function, discard_type)
  let entry = metadata.define_value("entry", Function, producer_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(producer),
      Let(
        discard,
        Function({
          parameters: [parameter],
          result_type: unit_type,
          body: Literal(Unit),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(discard), [Call(Ref(producer), [])]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(optimized_entry_body(optimized, entry), Literal(Unit))
  assert_eq(optimized.terms.length(), 1)
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer may duplicate a complex empty argument when profitable" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let producer_type = @buslane.Type::Function([], i64_type, Empty)
  let producer = metadata.define_value("producer", External, producer_type)
  let pair = metadata.define_type("Pair", [])
  let pair_constructor = metadata.define_data_constructor("pair", pair, [], [
    i64_type, i64_type,
  ])
  let pair_type = @buslane.Type::Constructor(pair)
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], pair_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(producer),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: pair_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: pair_type,
              body: Construct({
                data_constructor: pair_constructor,
                type_arguments: [],
                hidden_witnesses: [],
                payloads: [Ref(parameter), Ref(parameter)],
              }),
            }),
            [Call(Ref(producer), [])],
          ),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry) is Construct(construct) else {
    fail("expected the direct application to reduce")
  }
  assert_eq(construct.payloads, [
    Call(Ref(producer), []),
    Call(Ref(producer), []),
  ])
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer evaluates nonempty arguments once in source order" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let discard_type = @buslane.Type::Function(
    [unit_type, unit_type],
    unit_type,
    Empty,
  )
  let entry_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let first = metadata.define_value("first", External, observe_type)
  let second = metadata.define_value("second", External, observe_type)
  let left = metadata.define_value("left", Parameter, unit_type)
  let right = metadata.define_value("right", Parameter, unit_type)
  let discard = metadata.define_value("discard", Function, discard_type)
  let entry = metadata.define_value("entry", Function, entry_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(first),
      External(second),
      Let(
        discard,
        Function({
          parameters: [left, right],
          result_type: unit_type,
          body: Literal(Unit),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(discard), [Call(Ref(first), []), Call(Ref(second), [])]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry)
    is Let(
      _,
      Call(Ref(actual_first), []),
      Let(_, Call(Ref(actual_second), []), Literal(Unit))
    ) else {
    fail("expected ordered one-time argument bindings")
  }
  assert_eq((actual_first, actual_second), (first, second))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer treats an operationless user effect as nonempty" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let diverge = metadata.define_effect("Diverge", [])
  let diverge_effect = @buslane.Effect::Singleton(diverge, [])
  let observe_type = @buslane.Type::Function([], unit_type, diverge_effect)
  let discard_type = @buslane.Type::Function([unit_type], unit_type, Empty)
  let entry_type = @buslane.Type::Function([], unit_type, diverge_effect)
  let observe = metadata.define_value("observe", External, observe_type)
  let parameter = metadata.define_value("value", Parameter, unit_type)
  let discard = metadata.define_value("discard", Function, discard_type)
  let entry = metadata.define_value("entry", Function, entry_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        discard,
        Function({
          parameters: [parameter],
          result_type: unit_type,
          body: Literal(Unit),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(discard), [Call(Ref(observe), [])]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry)
    is Let(_, Call(Ref(actual_observe), []), Literal(Unit)) else {
    fail("expected the user effect argument to execute once")
  }
  assert_eq(actual_observe, observe)
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer binds a multiply used nonempty argument only once" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let observe = metadata.define_value("observe", External, observe_type)
  let pair = metadata.define_type("Pair", [])
  let pair_constructor = metadata.define_data_constructor("pair", pair, [], [
    unit_type, unit_type,
  ])
  let pair_type = @buslane.Type::Constructor(pair)
  let parameter = metadata.define_value("value", Parameter, unit_type)
  let duplicate = metadata.define_value(
    "duplicate",
    Function,
    Function([unit_type], pair_type, Empty),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], pair_type, Builtin(Io)),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        duplicate,
        Function({
          parameters: [parameter],
          result_type: pair_type,
          body: Construct({
            data_constructor: pair_constructor,
            type_arguments: [],
            hidden_witnesses: [],
            payloads: [Ref(parameter), Ref(parameter)],
          }),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: pair_type,
          body: Call(Ref(duplicate), [Call(Ref(observe), [])]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry)
    is Let(binding, Call(Ref(actual_observe), []), Construct(construct)) else {
    fail("expected one binding around the duplicated uses")
  }
  assert_eq(actual_observe, observe)
  assert_eq(construct.payloads, [Ref(binding), Ref(binding)])
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer inlines a callable with a nonempty latent effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let emit_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let output = metadata.define_value("output", External, emit_type)
  let emit = metadata.define_value("emit", Function, emit_type)
  let entry = metadata.define_value("entry", Function, emit_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(output),
      Let(
        emit,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(output), []),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(emit), []),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  assert_eq(optimized_entry_body(optimized, entry), Call(Ref(output), []))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer freshens nested type lambda binders at every inline site" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let parameter_type = @buslane.Type::Parameter(type_parameter)
  let polymorphic_type = @buslane.Type::Forall(
    [type_parameter],
    Function([parameter_type], parameter_type, Empty),
  )
  let nested_parameter = metadata.define_value(
    "value",
    Parameter,
    parameter_type,
  )
  let helper_type = @buslane.Type::Function([], polymorphic_type, Empty)
  let helper = metadata.define_value("helper", Function, helper_type)
  let pair = metadata.define_type("Pair", [])
  let pair_constructor = metadata.define_data_constructor("pair", pair, [], [
    polymorphic_type, polymorphic_type,
  ])
  let pair_type = @buslane.Type::Constructor(pair)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], pair_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({
          parameters: [],
          result_type: polymorphic_type,
          body: TypeLambda(
            [type_parameter],
            Function({
              parameters: [nested_parameter],
              result_type: parameter_type,
              body: Ref(nested_parameter),
            }),
          ),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: pair_type,
          body: Construct({
            data_constructor: pair_constructor,
            type_arguments: [],
            hidden_witnesses: [],
            payloads: [Call(Ref(helper), []), Call(Ref(helper), [])],
          }),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry) is Construct(construct) &&
    construct.payloads
    is [
      TypeLambda([left_type_parameter], Function(left_function)),
      TypeLambda([right_type_parameter], Function(right_function)),
    ] else {
    fail("expected two independently cloned polymorphic values")
  }
  assert_true(left_type_parameter != type_parameter)
  assert_true(right_type_parameter != type_parameter)
  assert_true(left_type_parameter != right_type_parameter)
  assert_eq(left_function.result_type, Parameter(left_type_parameter))
  assert_eq(right_function.result_type, Parameter(right_type_parameter))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer freshens existential match binders while inlining" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let packed = metadata.define_type("Packed", [])
  let pack = metadata.define_data_constructor("pack", packed, [hidden], [
    Parameter(hidden),
  ])
  let packed_type = @buslane.Type::Constructor(packed)
  let parameter = metadata.define_value("packed", Parameter, packed_type)
  let match_binder = metadata.define_value("packed", MatchBinder, packed_type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let payload = metadata.define_value("payload", MatchBinder, Parameter(opened))
  let unpack = metadata.define_value(
    "unpack",
    Function,
    Function([packed_type], i64_type, Empty),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], i64_type, Empty),
  )
  let packed_value = @buslane.Expr::Construct({
    data_constructor: pack,
    type_arguments: [],
    hidden_witnesses: [TypeArgument(i64_type)],
    payloads: [Literal(I64(7L))],
  })
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        unpack,
        Function({
          parameters: [parameter],
          result_type: i64_type,
          body: Match({
            scrutinee: Ref(parameter),
            binder: match_binder,
            result_type: i64_type,
            alternatives: [
              {
                alt_constructor: DataCon(pack),
                type_binders: [opened],
                value_binders: [payload],
                body: Literal(I64(42L)),
              },
            ],
          }),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(unpack), [packed_value]),
        }),
      ),
    ],
  }
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry) is Match(match_) &&
    match_.alternatives is [alternative] &&
    alternative.type_binders is [cloned_opened] &&
    alternative.value_binders is [cloned_payload] else {
    fail("expected one cloned existential alternative")
  }
  assert_true(cloned_opened != opened)
  guard optimized.metadata.value_info(cloned_payload) is Some(payload_info) else {
    fail("expected cloned payload metadata")
  }
  assert_eq(payload_info.type_, Parameter(cloned_opened))
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer freshens handler operation type binders while inlining" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let effect = metadata.define_effect("Choose", [])
  let choose = metadata.define_operation(
    "choose",
    effect,
    [hidden],
    [Parameter(hidden)],
    Parameter(hidden),
  )
  let result_binder = metadata.define_value("result", MatchBinder, i64_type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let payload_binder = metadata.define_value(
    "payload",
    MatchBinder,
    Parameter(opened),
  )
  let resume_binder = metadata.define_value(
    "resume",
    MatchBinder,
    Function([Parameter(opened)], i64_type, Empty),
  )
  let helper_type = @buslane.Type::Function([], i64_type, Empty)
  let helper = metadata.define_value("helper", Function, helper_type)
  let entry = metadata.define_value("entry", Function, helper_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Handle({
            body: Perform({
              operation: choose,
              effect_arguments: [],
              hidden_witnesses: [TypeArgument(i64_type)],
              payloads: [Literal(I64(1L))],
            }),
            result_binder,
            result_type: i64_type,
            final_body: Ref(result_binder),
            handlers: [
              {
                handled_effect: Singleton(effect, []),
                operations: [
                  {
                    operation: choose,
                    type_binders: [opened],
                    payload_binders: [payload_binder],
                    resume_binder,
                    body: Literal(I64(42L)),
                  },
                ],
              },
            ],
          }),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(helper), []),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(program).is_ok())
  guard optimize({ program, entry, roots: [], }) is Ok(optimized) else {
    fail("expected core optimization to succeed")
  }
  guard optimized_entry_body(optimized, entry) is Handle(handle) &&
    handle.handlers is [{ operations: [operation], .. }] &&
    operation.type_binders is [cloned_opened] else {
    fail("expected one cloned polymorphic handler operation")
  }
  assert_true(cloned_opened != opened)
  guard operation.payload_binders is [cloned_payload] &&
    optimized.metadata.value_info(cloned_payload) is Some(payload_info) &&
    optimized.metadata.value_info(operation.resume_binder) is Some(resume_info) else {
    fail("expected cloned handler binder metadata")
  }
  assert_eq(payload_info.type_, Parameter(cloned_opened))
  assert_eq(
    resume_info.type_,
    Function([Parameter(cloned_opened)], i64_type, Empty),
  )
  assert_true(@buslane.verify_program(optimized).is_ok())
}

///|
test "core optimizer reports typed application reduction observations" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let producer_type = @buslane.Type::Function([], i64_type, Empty)
  let identity_type = @buslane.Type::Function([i64_type], i64_type, Empty)
  let producer = metadata.define_value("producer", External, producer_type)
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let identity = metadata.define_value("identity", Function, identity_type)
  let entry = metadata.define_value("entry", Function, producer_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(producer),
      Let(
        identity,
        Function({
          parameters: [parameter],
          result_type: i64_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Call(Ref(identity), [Call(Ref(producer), [])]),
        }),
      ),
    ],
  }
  let observations : Array[CoreOptimizationObservation] = []
  guard optimize_observed({ program, entry, roots: [], }, observation => {
      observations.push(observation)
    })
    is Ok(optimized) else {
    fail("expected observed core optimization to succeed")
  }
  let site = ApplicationReductionSite::KnownCallable(identity)
  assert_eq(observations, [
    ApplicationConsidered(site),
    ApplicationAccepted(site~, empty_arguments=1, materialized_arguments=0),
    ProgramChanged(net_calls_removed=1, net_top_terms_removed=1),
  ])
  assert_eq(optimized_entry_body(optimized, entry), Call(Ref(producer), []))
}

///|
test "core optimizer reports an application arity compiler defect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let parameter = metadata.define_value("value", Parameter, unit_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: unit_type,
              body: Ref(parameter),
            }),
            [],
          ),
        }),
      ),
    ],
  }
  assert_eq(
    optimize({ program, entry, roots: [], }),
    Err(ApplicationArityCompilerDefect(expected=1, actual=0)),
  )
}

///|
test "core optimizer preserves a failed expression-facts query" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let parameter = metadata.define_value("value", Parameter, unit_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let unknown : @buslane.ValueId = { index: 99, }
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(
            Function({
              parameters: [parameter],
              result_type: unit_type,
              body: Ref(parameter),
            }),
            [Ref(unknown)],
          ),
        }),
      ),
    ],
  }
  assert_true(
    optimize({ program, entry, roots: [], })
    is Err(ExpressionFactsCompilerDefect(_)),
  )
}

///|
test "failed known-call reduction does not mutate input metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let helper_type = @buslane.Type::Function([unit_type], unit_type, Empty)
  let parameter = metadata.define_value("value", Parameter, unit_type)
  let helper = metadata.define_value("helper", Function, helper_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let unknown : @buslane.ValueId = { index: 99, }
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({
          parameters: [parameter],
          result_type: unit_type,
          body: Ref(parameter),
        }),
      ),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(helper), [Ref(unknown)]),
        }),
      ),
    ],
  }
  let metadata_before = metadata.snapshot()
  assert_true(
    optimize({ program, entry, roots: [], })
    is Err(ExpressionFactsCompilerDefect(_)),
  )
  assert_eq(metadata, metadata_before)
}
