///|
test "data allocation consumes the planned constructor family" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box_effect = metadata.define_type_parameter("BoxEff", Effect)
  let box = metadata.define_type("Box", [box_effect])
  let make_box = metadata.define_data_constructor("box", box, [], [
    Function([], unit_type, Parameter(box_effect)),
  ])
  let marker_parameter = metadata.define_type_parameter("T", Type)
  let marker = metadata.define_value(
    "marker",
    Function,
    Forall([marker_parameter], Function([], unit_type, Empty)),
  )
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
            [marker_parameter],
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
              TypeApply(Ref(marker), [
                TypeArgument(Apply(Constructor(box), [EffectArgument(Empty)])),
              ]),
              [],
            ),
          }),
        },
      ]),
    ],
  }
  let definitions = collect_effect_generic_definitions(program)
  let planned_definitions = collect_plannable_definitions(program)
  let plan = plan_effect_specializations_with_definitions(
    program, entry, planned_definitions,
  )
  guard plan.data_demands is [demand] && demand.constructors == [make_box] else {
    abort("expected one planned data constructor")
  }
  let late_box = metadata.define_data_constructor("late_box", box, [], [])
  assert_eq(
    (
      demand.constructors,
      metadata.type_info(box).map(info => info.constructors),
    ),
    ([make_box], Some([make_box, late_box])),
  )
  let specializer = EffectSpecializer::{
    program,
    definitions,
    planned_definitions,
    instances: [],
    data_instances: [],
    occurrence: @occurrence.analyze({ program, entry, roots: [] }),
    plan,
  }
  specializer.allocate_data_instances()
  guard specializer.data_instances is [{ target, constructors: [binding], .. }] &&
    metadata.type_info(target) is Some(target_info) else {
    abort("expected exactly one allocated data constructor")
  }
  assert_eq(binding.source, make_box)
  assert_eq(target_info.constructors, [binding.target])
}
