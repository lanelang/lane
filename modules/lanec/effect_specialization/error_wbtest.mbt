///|
fn error_test_specializer(
  program : @buslane.Program,
  plan : SpecializationPlan,
) -> EffectSpecializer {
  {
    program,
    definitions: collect_effect_generic_definitions(program),
    planned_definitions: collect_plannable_definitions(program),
    instances: [],
    data_instances: [],
    plan,
  }
}

///|
fn error_test_generic_program(
  metadata : @buslane.MetadataRegistry,
  effect_parameter : @buslane.TypeParameterId,
) -> (@buslane.Program, @buslane.ValueId, @buslane.ValueId) raise @buslane.MetadataAllocationError {
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
  (
    {
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
              body: Literal(Unit),
            }),
          },
        ]),
      ],
    },
    generic,
    entry,
  )
}

///|
test "planner rejects conflicting constructor families for one key" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let box = metadata.define_type("Box", [effect_parameter])
  let first = metadata.define_data_constructor("first", box, [], [])
  let second = metadata.define_data_constructor("second", box, [], [])
  let bindings = [
    { parameter: effect_parameter, argument: EffectArgument(Empty) },
  ]
  let planner = SpecializationPlanner::{
    program: { metadata, terms: [] },
    definitions: [],
    visits: [],
    plan: {
      callable_demands: [],
      data_demands: [{ source: box, bindings, constructors: [first] }],
      retained_top_terms: [],
      retained_declarations: [],
    },
  }
  try
    planner.add_data_demand({ source: box, bindings, constructors: [second] })
  catch {
    PlannerInvariant(context) =>
      assert_eq(context, {
        detail: "one data specialization key resolved to different constructor families",
        site: None,
        source: Some(Type(box)),
        specialization_key: bindings,
      })
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a planner invariant error")
  }
}

///|
test "allocator missing-plan errors retain the requested specialization key" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let box = metadata.define_type("Box", [effect_parameter])
  let (program, generic, _entry) = error_test_generic_program(
    metadata, effect_parameter,
  )
  let specializer = error_test_specializer(program, {
    callable_demands: [],
    data_demands: [],
    retained_top_terms: [],
    retained_declarations: [],
  })
  let arguments = [@buslane.GenericArgument::EffectArgument(Empty)]
  try specializer.require_data_instance(box, arguments) catch {
    AllocatorInvariant(context) =>
      assert_eq(context, {
        detail: "a reachable data specialization is missing from the immutable plan",
        site: None,
        source: Some(Type(box)),
        specialization_key: [
          { parameter: effect_parameter, argument: EffectArgument(Empty) },
        ],
      })
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an allocator invariant error")
  }
  let bindings = [
    { parameter: effect_parameter, argument: EffectArgument(Empty) },
  ]
  try specializer.planned_instance(TopLevel(generic), [], bindings) catch {
    AllocatorInvariant(context) =>
      assert_eq(context, {
        detail: "a reachable callable specialization is missing from the immutable plan",
        site: Some(TopLevel(generic)),
        source: Some(Value(generic)),
        specialization_key: bindings,
      })
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a callable allocator invariant error")
  }
}

///|
test "metadata allocation exhaustion retains context and typed cause" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let (program, generic, _entry) = error_test_generic_program(
    metadata, effect_parameter,
  )
  let bindings = [
    { parameter: effect_parameter, argument: EffectArgument(Empty) },
  ]
  let specializer = error_test_specializer(program, {
    callable_demands: [
      Specialize(
        TopLevel(generic),
        ambient_bindings=[],
        instance_bindings=bindings,
      ),
    ],
    data_demands: [],
    retained_top_terms: [],
    retained_declarations: [],
  })
  metadata.name_allocator = Exhausted
  try specializer.allocate_callable_instances() catch {
    MetadataAllocationCompilerDefect(context, cause) => {
      assert_eq(context, {
        detail: "Buslane metadata allocation failed",
        site: Some(TopLevel(generic)),
        source: Some(Value(generic)),
        specialization_key: bindings,
      })
      assert_true(cause is MetadataNameExhausted)
    }
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a metadata allocation compiler defect")
  }
}

///|
test "rewriter missing-plan errors identify the callable site" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let (program, generic, entry) = error_test_generic_program(
    metadata, effect_parameter,
  )
  let specializer = error_test_specializer(program, {
    callable_demands: [],
    data_demands: [],
    retained_top_terms: [],
    retained_declarations: [],
  })
  try
    specializer.rewrite_expr(
      TypeApply(Ref(generic), [EffectArgument(Parameter(effect_parameter))]),
      EffectRewriteScope::new(entry, []),
    )
  catch {
    RewriterInvariant(context) =>
      assert_eq(context, {
        detail: "a symbolic effect application is missing its planned generic definition",
        site: Some(TopLevel(generic)),
        source: Some(Value(generic)),
        specialization_key: [],
      })
    error => fail("unexpected specialization error: \{Repr(error)}")
  } noraise {
    _ => fail("expected a rewriter invariant error")
  }
}
