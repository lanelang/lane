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
  let lowered = lower_effects(specialized, entry, stage => {
    if stage is MonadicContinuationsLifted(lifted) {
      lifted_generic_type = lifted.metadata
        .value_info(generic)
        .map(info => info.type_)
      lifted_verification = Some(@buslane.verify_program(lifted))
    }
  })
  assert_eq(lifted_generic_type, Some(generic_type))
  guard lifted_verification is Some(verified_lifted) else {
    fail("expected to verify the monadic-lift boundary")
  }
  if !verified_lifted.is_ok() {
    fail("monadic-lift program did not verify: \{Repr(verified_lifted)}")
  }
  let verified = @buslane.verify_program(lowered.program)
  if !verified.is_ok() {
    fail("lowered program did not verify: \{Repr(verified)}")
  }
}
