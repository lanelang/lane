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
