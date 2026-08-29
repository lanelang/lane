///|
test "link identity maps preserve the first binding in every namespace" {
  let identities = LinkIdentityMaps()
  let type_source : @buslane.TypeId = { index: 0, }
  let type_target : @buslane.TypeId = { index: 10, }
  let other_type_target : @buslane.TypeId = { index: 11, }
  let type_parameter_source : @buslane.TypeParameterId = { index: 1, }
  let type_parameter_target : @buslane.TypeParameterId = { index: 12, }
  let other_type_parameter_target : @buslane.TypeParameterId = { index: 13, }
  let value_source : @buslane.ValueId = { index: 2, }
  let value_target : @buslane.ValueId = { index: 14, }
  let other_value_target : @buslane.ValueId = { index: 15, }
  let data_constructor_source : @buslane.DataConId = { index: 3, }
  let data_constructor_target : @buslane.DataConId = { index: 16, }
  let other_data_constructor_target : @buslane.DataConId = { index: 17, }
  let effect_source : @buslane.EffectId = { index: 4, }
  let effect_target : @buslane.EffectId = { index: 18, }
  let other_effect_target : @buslane.EffectId = { index: 19, }
  let operation_source : @buslane.OperationId = { index: 5, }
  let operation_target : @buslane.OperationId = { index: 20, }
  let other_operation_target : @buslane.OperationId = { index: 21, }
  ignore(identities.bind_type("Module", type_source, type_target))
  ignore(
    identities.bind_type_parameter(
      "Module", type_parameter_source, type_parameter_target,
    ),
  )
  ignore(identities.bind_value("Module", value_source, value_target))
  ignore(
    identities.bind_data_constructor(
      "Module", data_constructor_source, data_constructor_target,
    ),
  )
  ignore(identities.bind_effect("Module", effect_source, effect_target))
  ignore(
    identities.bind_operation("Module", operation_source, operation_target),
  )
  debug_inspect(
    (
      (
        identities.bind_type("Module", type_source, other_type_target),
        identities.find_type("Module", type_source),
      ),
      (
        identities.bind_type_parameter(
          "Module", type_parameter_source, other_type_parameter_target,
        ),
        identities.find_type_parameter("Module", type_parameter_source),
      ),
      (
        identities.bind_value("Module", value_source, other_value_target),
        identities.find_value("Module", value_source),
      ),
      (
        identities.bind_data_constructor(
          "Module", data_constructor_source, other_data_constructor_target,
        ),
        identities.find_data_constructor("Module", data_constructor_source),
      ),
      (
        identities.bind_effect("Module", effect_source, other_effect_target),
        identities.find_effect("Module", effect_source),
      ),
      (
        identities.bind_operation(
          "Module", operation_source, other_operation_target,
        ),
        identities.find_operation("Module", operation_source),
      ),
    ),
    content=(
      #|(
      #|  ({ index: 10 }, Some({ index: 10 })),
      #|  ({ index: 12 }, Some({ index: 12 })),
      #|  ({ index: 14 }, Some({ index: 14 })),
      #|  ({ index: 16 }, Some({ index: 16 })),
      #|  ({ index: 18 }, Some({ index: 18 })),
      #|  ({ index: 20 }, Some({ index: 20 })),
      #|)
    ),
  )
}
