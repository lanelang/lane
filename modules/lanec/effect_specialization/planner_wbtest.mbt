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
test "generic use classification follows substituted canonical effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let forwarded_parameter = metadata.define_type_parameter("Forwarded", Effect)
  let left_effect = metadata.define_effect("Left", [])
  let right_effect = metadata.define_effect("Right", [])
  let generic_type = @buslane.Type::Forall(
    [type_parameter, effect_parameter],
    Function([], Primitive(Unit), Parameter(effect_parameter)),
  )
  let generic = metadata.define_value("generic", Function, generic_type)
  let definition = EffectGenericDefinition::{
    id: generic,
    parameters: [type_parameter, effect_parameter],
    rhs: Literal(Unit),
  }
  let type_argument = @buslane.GenericArgument::TypeArgument(Primitive(I64))
  let incomplete = classify_effect_generic_use(
    metadata,
    definition.parameters,
    [type_argument],
  )
  assert_eq(incomplete, {
    arguments: [type_argument],
    retained_arguments: [],
    mode: Incomplete,
  })
  let forwarded = raw_substitute_specialized_argument(
    EffectArgument(Parameter(effect_parameter)),
    [
      {
        parameter: effect_parameter,
        argument: EffectArgument(Parameter(forwarded_parameter)),
      },
    ],
  )
  let symbolic = classify_effect_generic_use(metadata, definition.parameters, [
    type_argument, forwarded,
  ])
  assert_eq(symbolic, {
    arguments: [type_argument, EffectArgument(Parameter(forwarded_parameter))],
    retained_arguments: [type_argument],
    mode: Symbolic,
  })
  let concrete_effect = @buslane.Effect::Union([
    Singleton(right_effect, []),
    Singleton(left_effect, []),
  ])
  let concrete = classify_effect_generic_use(metadata, definition.parameters, [
    type_argument,
    EffectArgument(concrete_effect),
  ])
  let canonical = metadata.canonicalize_effect(concrete_effect)
  assert_eq(concrete, {
    arguments: [type_argument, EffectArgument(concrete_effect)],
    retained_arguments: [type_argument],
    mode: Concrete([
      { parameter: effect_parameter, argument: EffectArgument(canonical), },
    ]),
  })
  let reversed = classify_effect_generic_use(metadata, definition.parameters, [
    type_argument,
    EffectArgument(
      Union([Singleton(left_effect, []), Singleton(right_effect, [])]),
    ),
  ])
  guard concrete.mode is Concrete(concrete_bindings) &&
    reversed.mode is Concrete(reversed_bindings) else {
    fail("expected two concrete classifications")
  }
  assert_true(
    specialization_bindings_equal(
      metadata, concrete_bindings, reversed_bindings,
    ),
  )
}

///|
test "planner owns retained top terms in source order" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let external_type = @buslane.Type::Function([], unit_type, Empty)
  let reachable_external = metadata.define_value(
    "reachable_external",
    External,
    external_type,
  )
  let unreachable_external = metadata.define_value(
    "unreachable_external",
    External,
    external_type,
  )
  let ordinary = metadata.define_value("ordinary", Value, unit_type)
  let local_value = metadata.define_value("local", Local, unit_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let entry_rhs = @buslane.Expr::Function({
    parameters: [],
    result_type: unit_type,
    body: Let(local_value, Ref(ordinary), Call(Ref(reachable_external), [])),
  })
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(reachable_external),
      External(unreachable_external),
      Let(ordinary, Literal(Unit)),
      LetRec([{ id: entry, rhs: entry_rhs, }]),
    ],
  }
  assert_eq(plan_effect_specializations(program, entry), {
    callable_demands: [],
    data_demands: [],
    retained_top_terms: [
      RetainedExternal(source_index=0, value=reachable_external),
      RetainedLet(source_index=2, value=ordinary),
      RetainedLetRec(source_index=3, values=[entry]),
    ],
    retained_declarations: [],
  })
}

///|
test "phantom generic type arguments contribute nominal data demands" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box_effect = metadata.define_type_parameter("BoxEff", Effect)
  let box = metadata.define_type("Box", [box_effect])
  let make_box = metadata.define_data_constructor("box", box, [], [
    Function([], unit_type, Parameter(box_effect)),
  ])
  let marker_type_parameter = metadata.define_type_parameter("T", Type)
  let marker_type = @buslane.Type::Forall(
    [marker_type_parameter],
    Function([], unit_type, Empty),
  )
  let marker = metadata.define_value("marker", Function, marker_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let box_empty = @buslane.GenericArgument::TypeArgument(
    Apply(Constructor(box), [EffectArgument(Empty)]),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: marker,
          rhs: TypeLambda(
            [marker_type_parameter],
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
            body: Call(TypeApply(Ref(marker), [box_empty]), []),
          }),
        },
      ]),
    ],
  }
  let plan = plan_effect_specializations(program, entry)
  assert_eq(plan, {
    callable_demands: [],
    retained_top_terms: [RetainedLetRec(source_index=0, values=[marker, entry])],
    retained_declarations: [],
    data_demands: [
      {
        source: box,
        bindings: [{ parameter: box_effect, argument: EffectArgument(Empty), }],
        constructors: [make_box],
      },
    ],
  })
  assert_eq(@buslane.verify_program(specialize(program, entry)).diagnostics, [])
}

///|
test "ordinary generic type arguments contribute nominal data demands" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box_effect = metadata.define_type_parameter("BoxEff", Effect)
  let box = metadata.define_type("Box", [box_effect])
  let make_box = metadata.define_data_constructor("box", box, [], [
    Function([], unit_type, Parameter(box_effect)),
  ])
  let marker_type_parameter = metadata.define_type_parameter("T", Type)
  let marker_parameter = metadata.define_value(
    "value",
    Parameter,
    Parameter(marker_type_parameter),
  )
  let marker_type = @buslane.Type::Forall(
    [marker_type_parameter],
    Function([Parameter(marker_type_parameter)], unit_type, Empty),
  )
  let marker = metadata.define_value("marker", Function, marker_type)
  let box_empty_type = @buslane.Type::Apply(Constructor(box), [
    EffectArgument(Empty),
  ])
  let box_value = metadata.define_value("box_value", External, box_empty_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: marker,
          rhs: TypeLambda(
            [marker_type_parameter],
            Function({
              parameters: [marker_parameter],
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
            body: Call(TypeApply(Ref(marker), [TypeArgument(box_empty_type)]), [
              Ref(box_value),
            ]),
          }),
        },
      ]),
    ],
  }
  assert_eq(plan_effect_specializations(program, entry), {
    callable_demands: [],
    retained_top_terms: [RetainedLetRec(source_index=0, values=[marker, entry])],
    retained_declarations: [],
    data_demands: [
      {
        source: box,
        bindings: [{ parameter: box_effect, argument: EffectArgument(Empty), }],
        constructors: [make_box],
      },
    ],
  })
}

///|
test "external generic type arguments contribute nominal data demands" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box_effect = metadata.define_type_parameter("BoxEff", Effect)
  let box = metadata.define_type("Box", [box_effect])
  let make_box = metadata.define_data_constructor("box", box, [], [
    Function([], unit_type, Parameter(box_effect)),
  ])
  let marker_type_parameter = metadata.define_type_parameter("T", Type)
  let marker = metadata.define_value(
    "marker",
    External,
    Forall([marker_type_parameter], Function([], unit_type, Empty)),
  )
  let outer_effect = metadata.define_type_parameter("OuterEff", Effect)
  let outer = metadata.define_value(
    "outer",
    Function,
    Forall([outer_effect], Function([], unit_type, Parameter(outer_effect))),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Empty),
  )
  let empty_effect = @buslane.GenericArgument::EffectArgument(Empty)
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: outer,
          rhs: TypeLambda(
            [outer_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Call(
                TypeApply(Ref(marker), [
                  TypeArgument(
                    Apply(Constructor(box), [
                      EffectArgument(Parameter(outer_effect)),
                    ]),
                  ),
                ]),
                [],
              ),
            }),
          ),
        },
        {
          id: entry,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(TypeApply(Ref(outer), [empty_effect]), []),
          }),
        },
      ]),
    ],
  }
  assert_eq(plan_effect_specializations(program, entry), {
    callable_demands: [
      Specialize(TopLevel(outer), ambient_bindings=[], instance_bindings=[
        { parameter: outer_effect, argument: empty_effect, },
      ]),
    ],
    retained_top_terms: [RetainedLetRec(source_index=0, values=[entry])],
    retained_declarations: [],
    data_demands: [
      {
        source: box,
        bindings: [{ parameter: box_effect, argument: EffectArgument(Empty), }],
        constructors: [make_box],
      },
    ],
  })
}

///|
test "planner records only reachable retained operations" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box_effect = metadata.define_type_parameter("BoxEff", Effect)
  let box = metadata.define_type("Box", [box_effect])
  let make_box = metadata.define_data_constructor("box", box, [], [unit_type])
  let boxed = @buslane.Type::Apply(Constructor(box), [EffectArgument(Empty)])
  let active = metadata.define_effect("Active", [])
  let active_operation = metadata.define_operation(
    "active",
    active,
    [],
    [],
    boxed,
  )
  let dormant = metadata.define_effect("Dormant", [])
  ignore(metadata.define_operation("dormant", dormant, [], [], boxed))
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Singleton(active, [])),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(plan_effect_specializations(program, entry), {
    callable_demands: [],
    retained_top_terms: [RetainedLet(source_index=0, value=entry)],
    retained_declarations: [Operation(active_operation)],
    data_demands: [
      {
        source: box,
        bindings: [{ parameter: box_effect, argument: EffectArgument(Empty), }],
        constructors: [make_box],
      },
    ],
  })
}

///|
test "callable planner keeps generic and concrete demands independently" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let log_effect = metadata.define_effect("Log", [])
  let apply_effect = metadata.define_type_parameter("ApplyEff", Effect)
  let forward_effect = metadata.define_type_parameter("ForwardEff", Effect)
  let apply_type = @buslane.Type::Forall(
    [apply_effect],
    Function([], unit_type, Parameter(apply_effect)),
  )
  let forward_type = @buslane.Type::Forall(
    [forward_effect],
    Function([], unit_type, Parameter(forward_effect)),
  )
  let apply = metadata.define_value("apply", Function, apply_type)
  let forward = metadata.define_value("forward", Function, forward_type)
  let first = metadata.define_value("first", Local, unit_type)
  let second = metadata.define_value("second", Local, unit_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], apply_type, Singleton(log_effect, [])),
  )
  let dead_effect = metadata.define_type_parameter("DeadEff", Effect)
  let dead_type = @buslane.Type::Forall(
    [dead_effect],
    Function([], unit_type, Parameter(dead_effect)),
  )
  let dead = metadata.define_value("dead", Function, dead_type)
  let log_argument = @buslane.GenericArgument::EffectArgument(
    Singleton(log_effect, []),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: apply,
          rhs: TypeLambda(
            [apply_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Literal(Unit),
            }),
          ),
        },
        {
          id: forward,
          rhs: TypeLambda(
            [forward_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Call(
                TypeApply(Ref(apply), [
                  EffectArgument(Parameter(forward_effect)),
                ]),
                [],
              ),
            }),
          ),
        },
        {
          id: entry,
          rhs: Function({
            parameters: [],
            result_type: apply_type,
            body: Let(
              first,
              Call(TypeApply(Ref(apply), [log_argument]), []),
              Let(
                second,
                Call(TypeApply(Ref(forward), [log_argument]), []),
                Ref(apply),
              ),
            ),
          }),
        },
        {
          id: dead,
          rhs: TypeLambda(
            [dead_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Literal(Unit),
            }),
          ),
        },
      ]),
    ],
  }
  let metadata_counts = (
    metadata.values.length(),
    metadata.types.length(),
    metadata.data_constructors.length(),
  )
  let plan = plan_effect_specializations(program, entry)
  assert_eq(
    (
      metadata.values.length(),
      metadata.types.length(),
      metadata.data_constructors.length(),
    ),
    metadata_counts,
  )
  assert_eq(plan, {
    callable_demands: [
      RetainGeneric(TopLevel(apply), []),
      Specialize(TopLevel(apply), ambient_bindings=[], instance_bindings=[
        { parameter: apply_effect, argument: log_argument, },
      ]),
      Specialize(TopLevel(forward), ambient_bindings=[], instance_bindings=[
        { parameter: forward_effect, argument: log_argument, },
      ]),
    ],
    retained_top_terms: [RetainedLetRec(source_index=0, values=[apply, entry])],
    retained_declarations: [],
    data_demands: [],
  })
  assert_eq(plan_effect_specializations(program, entry), plan)
  let specialized = specialize(program, entry)
  assert_eq(@buslane.verify_program(specialized).diagnostics, [])
  guard specialized.terms
    is [
      LetRec(
        [
          { id: concrete_apply, rhs: Function(_), },
          { id: concrete_forward, rhs: Function(_), },
        ]
      ),
      LetRec(
        [
          { id: retained_apply, rhs: TypeLambda(_, _), },
          { id: retained_entry, rhs: Function({ body: entry_body, .. }), },
        ]
      ),
    ] &&
    entry_body
    is Let(
      _,
      Call(Ref(direct_target), []),
      Let(_, Call(Ref(forward_target), []), Ref(returned_generic))
    ) else {
    fail("expected one retained generic and the two planned concrete clones")
  }
  assert_eq(
    (
      retained_apply, retained_entry, direct_target, forward_target, returned_generic,
    ),
    (apply, entry, concrete_apply, concrete_forward, apply),
  )
}

///|
test "callable planner reaches a local recursive group with lexical bindings" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let log_effect = metadata.define_effect("Log", [])
  let outer_effect = metadata.define_type_parameter("OuterEff", Effect)
  let first_effect = metadata.define_type_parameter("FirstEff", Effect)
  let second_effect = metadata.define_type_parameter("SecondEff", Effect)
  let outer_type = @buslane.Type::Forall(
    [outer_effect],
    Function([], unit_type, Parameter(outer_effect)),
  )
  let first_type = @buslane.Type::Forall(
    [first_effect],
    Function([], unit_type, Parameter(first_effect)),
  )
  let second_type = @buslane.Type::Forall(
    [second_effect],
    Function([], unit_type, Parameter(second_effect)),
  )
  let outer = metadata.define_value("outer", Function, outer_type)
  let first = metadata.define_value("first", Local, first_type)
  let second = metadata.define_value("second", Local, second_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], unit_type, Singleton(log_effect, [])),
  )
  let log_argument = @buslane.GenericArgument::EffectArgument(
    Singleton(log_effect, []),
  )
  let empty_argument = @buslane.GenericArgument::EffectArgument(Empty)
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: outer,
          rhs: TypeLambda(
            [outer_effect],
            Function({
              parameters: [],
              result_type: unit_type,
              body: LetRec(
                [
                  {
                    id: first,
                    rhs: TypeLambda(
                      [first_effect],
                      Function({
                        parameters: [],
                        result_type: unit_type,
                        body: Call(
                          TypeApply(Ref(second), [
                            EffectArgument(Parameter(first_effect)),
                          ]),
                          [],
                        ),
                      }),
                    ),
                  },
                  {
                    id: second,
                    rhs: TypeLambda(
                      [second_effect],
                      Function({
                        parameters: [],
                        result_type: unit_type,
                        body: Call(
                          TypeApply(Ref(first), [
                            EffectArgument(Parameter(second_effect)),
                          ]),
                          [],
                        ),
                      }),
                    ),
                  },
                ],
                Call(TypeApply(Ref(first), [empty_argument]), []),
              ),
            }),
          ),
        },
        {
          id: entry,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(TypeApply(Ref(outer), [log_argument]), []),
          }),
        },
      ]),
    ],
  }
  let outer_binding = EffectSpecializationBinding::{
    parameter: outer_effect,
    argument: log_argument,
  }
  let plan = plan_effect_specializations(program, entry)
  assert_eq(plan, {
    callable_demands: [
      Specialize(TopLevel(outer), ambient_bindings=[], instance_bindings=[
        outer_binding,
      ]),
      Specialize(
        Local(owner=outer, value=first),
        ambient_bindings=[outer_binding],
        instance_bindings=[
          { parameter: first_effect, argument: empty_argument, },
        ],
      ),
      Specialize(
        Local(owner=outer, value=second),
        ambient_bindings=[outer_binding],
        instance_bindings=[
          { parameter: second_effect, argument: empty_argument, },
        ],
      ),
    ],
    retained_top_terms: [RetainedLetRec(source_index=0, values=[entry])],
    retained_declarations: [],
    data_demands: [],
  })
}

///|
test "callable planner retains and specializes one local definition" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let log_effect = metadata.define_effect("Log", [])
  let local_effect = metadata.define_type_parameter("LocalEff", Effect)
  let local_type = @buslane.Type::Forall(
    [local_effect],
    Function([], unit_type, Parameter(local_effect)),
  )
  let local_function = metadata.define_value("local", Local, local_type)
  let discarded = metadata.define_value("discarded", Local, unit_type)
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], local_type, Singleton(log_effect, [])),
  )
  let log_argument = @buslane.GenericArgument::EffectArgument(
    Singleton(log_effect, []),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: local_type,
          body: LetRec(
            [
              {
                id: local_function,
                rhs: TypeLambda(
                  [local_effect],
                  Function({
                    parameters: [],
                    result_type: unit_type,
                    body: Literal(Unit),
                  }),
                ),
              },
            ],
            Let(
              discarded,
              Call(TypeApply(Ref(local_function), [log_argument]), []),
              Ref(local_function),
            ),
          ),
        }),
      ),
    ],
  }
  assert_eq(plan_effect_specializations(program, entry), {
    callable_demands: [
      RetainGeneric(Local(owner=entry, value=local_function), []),
      Specialize(
        Local(owner=entry, value=local_function),
        ambient_bindings=[],
        instance_bindings=[{ parameter: local_effect, argument: log_argument, }],
      ),
    ],
    retained_top_terms: [RetainedLet(source_index=0, value=entry)],
    retained_declarations: [],
    data_demands: [],
  })
}

///|
