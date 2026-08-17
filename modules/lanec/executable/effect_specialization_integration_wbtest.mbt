///|
/// A definition effect specialization replaces keeps its complete metadata.
/// Selective CPS and monadic lift must leave that declaration alone rather than
/// rewrite any nested type or effect while its binders stay as they were.
test "monadic lift preserves a replaced generic declaration's metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let log = metadata.define_effect("Log", [])
  let task_type : @buslane.Type = Function(
    [],
    Primitive(Unit),
    Parameter(effect_parameter),
  )
  let generic_type : @buslane.Type = Forall(
    [effect_parameter],
    Function([task_type], Primitive(Unit), Parameter(effect_parameter)),
  )
  let generic = metadata.define_value("generic", Function, generic_type)
  let task = metadata.define_value("task", Parameter, task_type)
  let logging = metadata.define_value(
    "logging",
    External,
    Function([], Primitive(Unit), Singleton(log, [])),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Singleton(log, [])),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(logging),
      LetRec([
        {
          id: generic,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [task],
              result_type: Primitive(Unit),
              body: Call(Ref(task), []),
            }),
          ),
        },
      ]),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Call(
            TypeApply(Ref(generic), [EffectArgument(Singleton(log, []))]),
            [Ref(logging)],
          ),
        }),
      ),
    ],
  }
  let specialized = @effect_specialization.specialize(program, entry)
  // The generic original is no longer a term but is still in the registry.
  guard metadata.value_info(generic) is Some(_) else {
    fail("expected the replaced definition to keep its metadata")
  }
  let mut lifted_generic_type = None
  let mut lifted_verification = None
  let lowered = lower_effects(
    specialized,
    entry,
    Some(stage => {
      if stage is MonadicContinuationsLifted(lifted) {
        lifted_generic_type = lifted.metadata
          .value_info(generic)
          .map(info => info.type_)
        lifted_verification = Some(@buslane.verify_program(lifted))
      }
    }),
  )
  assert_eq(lifted_generic_type, Some(generic_type))
  guard lifted_verification is Some(verified_lifted) else {
    fail("expected to verify the monadic-lift boundary")
  }
  if !verified_lifted.is_ok() {
    fail("monadic-lift program did not verify: \{Repr(verified_lifted)}")
  }
  let verified = @buslane.verify_program(lowered)
  if !verified.is_ok() {
    fail("lowered program did not verify: \{Repr(verified)}")
  }
}

///|
test "specialization adapter exposes only source limitations as unsupported" {
  let context : @effect_specialization.SpecializationErrorContext = {
    detail: "source limitation",
    site: None,
    source: None,
    specialization_key: [],
  }
  assert_eq(
    effect_specialization_elaboration_error(UnsupportedProgram(context)),
    UnsupportedEffectSpecialization(detail="source limitation"),
  )
  let invariant = @effect_specialization.SpecializationError::PlannerInvariant({
    ..context,
    detail: "planner state diverged",
  })
  assert_eq(
    effect_specialization_elaboration_error(invariant),
    EffectSpecializationCompilerDefect(invariant),
  )
}

///|
test "CPS Core optimization preserves handler-arm residual effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let probe = metadata.define_effect("Probe", [])
  let ping = metadata.define_operation("ping", probe, [], [], Primitive(Unit))
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let handled_result = metadata.define_value(
    "handled_result",
    MatchBinder,
    Primitive(Unit),
  )
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Unit)], Primitive(Unit), Empty),
  )
  let discarded = metadata.define_value("discarded", Local, Primitive(Unit))
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Builtin(Io)),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      External(println),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Let(
            discarded,
            Handle({
              body: Perform({
                operation: ping,
                effect_arguments: [],
                hidden_witnesses: [],
                payloads: [],
              }),
              result_binder: handled_result,
              result_type: Primitive(Unit),
              final_body: Ref(handled_result),
              handlers: [
                {
                  handled_effect: Singleton(probe, []),
                  operations: [
                    {
                      operation: ping,
                      type_binders: [],
                      payload_binders: [],
                      resume_binder: resume_value,
                      body: Call(Ref(println), [Literal(String("handled"))]),
                    },
                  ],
                },
              ],
            }),
            Literal(Unit),
          ),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  assert_cps_stage_entry_effect(source, entry, Builtin(Io))
}

///|
test "CPS Core optimization preserves final-clause residual effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let probe = metadata.define_effect("Probe", [])
  let ping = metadata.define_operation("ping", probe, [], [], Primitive(Unit))
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let handled_result = metadata.define_value(
    "handled_result",
    MatchBinder,
    Primitive(Unit),
  )
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Unit)], Primitive(Unit), Builtin(Io)),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Builtin(Io)),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      External(println),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Handle({
            body: Perform({
              operation: ping,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [],
            }),
            result_binder: handled_result,
            result_type: Primitive(Unit),
            final_body: Call(Ref(println), [Literal(String("finalized"))]),
            handlers: [
              {
                handled_effect: Singleton(probe, []),
                operations: [
                  {
                    operation: ping,
                    type_binders: [],
                    payload_binders: [],
                    resume_binder: resume_value,
                    body: Call(Resume(resume_value), [Literal(Unit)]),
                  },
                ],
              },
            ],
          }),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  assert_cps_stage_entry_effect(source, entry, Builtin(Io))
}

///|
test "CPS Core optimization preserves continuation-suffix residual effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let probe = metadata.define_effect("Probe", [])
  let ping = metadata.define_operation("ping", probe, [], [], Primitive(Unit))
  let println = metadata.define_value(
    "println",
    External,
    Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
  )
  let performed = metadata.define_value("performed", Local, Primitive(Unit))
  let handled_result = metadata.define_value(
    "handled_result",
    MatchBinder,
    Primitive(Unit),
  )
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Unit)], Primitive(Unit), Builtin(Io)),
  )
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Builtin(Io)),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      External(println),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Handle({
            body: Let(
              performed,
              Perform({
                operation: ping,
                effect_arguments: [],
                hidden_witnesses: [],
                payloads: [],
              }),
              Call(Ref(println), [Literal(String("continued"))]),
            ),
            result_binder: handled_result,
            result_type: Primitive(Unit),
            final_body: Ref(handled_result),
            handlers: [
              {
                handled_effect: Singleton(probe, []),
                operations: [
                  {
                    operation: ping,
                    type_binders: [],
                    payload_binders: [],
                    resume_binder: resume_value,
                    body: Call(Resume(resume_value), [Literal(Unit)]),
                  },
                ],
              },
            ],
          }),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(source).is_ok())
  assert_cps_stage_entry_effect(source, entry, Builtin(Io))
}

///|
fn assert_cps_stage_entry_effect(
  source : @buslane.Program,
  entry : @buslane.ValueId,
  expected_effect : @buslane.Effect,
) -> Unit raise {
  let mut lifted_actual = None
  let mut optimized_actual = None
  ignore(
    lower_effects(
      source,
      entry,
      Some(stage => {
        match stage {
          MonadicContinuationsLifted(program) =>
            lifted_actual = synthesized_top_function_type(program, entry)
          CpsCoreOptimized(program) =>
            optimized_actual = synthesized_top_function_type(program, entry)
          _ => ()
        }
      }),
    ),
  )
  let expected = Some(
    @buslane.Type::Function([], Primitive(Unit), expected_effect),
  )
  assert_eq(lifted_actual, expected)
  assert_eq(optimized_actual, expected)
}

///|
fn synthesized_top_function_type(
  program : @buslane.Program,
  value : @buslane.ValueId,
) -> @buslane.Type? {
  for term in program.terms {
    if term is Let(id, expression) && id == value {
      return match
        @buslane.ExpressionFactsQuery::new(program).synthesize(expression) {
        Ok(facts) => Some(facts.type_())
        Err(_) => None
      }
    }
  }
  None
}
