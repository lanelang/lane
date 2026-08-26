///|
fn runtime_adapter_argument(
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
  evidence : @anf.RuntimeEvidence,
) -> @anf.RuntimeArgument {
  { type_expression: runtime_types.intern(Static(type_)), evidence, }
}

///|
test "alpha-renamed evidence captures share one callable adapter recipe" {
  let image = test_image_lowerer(MetadataRegistry())
  let left = image.fresh_synthetic_parameter()
  let right = image.fresh_synthetic_parameter()
  let left_expression = image.runtime_types.intern(Parameter(left))
  let right_expression = image.runtime_types.intern(Parameter(right))
  let source : @anf.RuntimeType = Callable([Scalar(I64)], Unit)
  let left_target : @anf.RuntimeType = Callable(
    [Erased(left_expression, Parameter(left))],
    Unit,
  )
  let right_target : @anf.RuntimeType = Callable(
    [Erased(right_expression, Parameter(right))],
    Unit,
  )
  let left_substitution = RuntimeSubstitution::new()
  left_substitution.insert(
    left,
    runtime_adapter_argument(image.runtime_types, Scalar(I64), Static(I64)),
  )
  let right_substitution = RuntimeSubstitution::new()
  right_substitution.insert(
    right,
    runtime_adapter_argument(image.runtime_types, Scalar(I64), Static(I64)),
  )
  let left_recipe = image.callable_adapter_recipe(
    source,
    left_target,
    [0],
    left_substitution,
    [{ id: left, arity: 0, }],
  )
  let right_recipe = image.callable_adapter_recipe(
    source,
    right_target,
    [0],
    right_substitution,
    [{ id: right, arity: 0, }],
  )
  assert_eq(left_recipe, right_recipe)
  let left_worker = image.callable_adapter({
    recipe: left_recipe,
    target_type: left_target,
    substitutions: left_substitution,
    captured_parameters: [{ id: left, arity: 0, }],
  })
  let right_worker = image.callable_adapter({
    recipe: right_recipe,
    target_type: right_target,
    substitutions: right_substitution,
    captured_parameters: [{ id: right, arity: 0, }],
  })
  assert_eq(image.callable_adapters.length(), 1)
  assert_eq(left_worker.function, right_worker.function)
}

///|
test "equal-width scalar layouts keep distinct callable adapter recipes" {
  let image = test_image_lowerer(MetadataRegistry())
  let bool_parameter = image.fresh_synthetic_parameter()
  let i32_parameter = image.fresh_synthetic_parameter()
  let bool_expression = image.runtime_types.intern(Parameter(bool_parameter))
  let i32_expression = image.runtime_types.intern(Parameter(i32_parameter))
  let bool_substitution = RuntimeSubstitution::new()
  bool_substitution.insert(
    bool_parameter,
    runtime_adapter_argument(image.runtime_types, Scalar(Bool), Static(Bool)),
  )
  let i32_substitution = RuntimeSubstitution::new()
  i32_substitution.insert(
    i32_parameter,
    runtime_adapter_argument(image.runtime_types, Scalar(I32), Static(I32)),
  )
  let bool_recipe = image.callable_adapter_recipe(
    Callable([Scalar(Bool)], Unit),
    Callable([Erased(bool_expression, Parameter(bool_parameter))], Unit),
    [0],
    bool_substitution,
    [{ id: bool_parameter, arity: 0, }],
  )
  let i32_recipe = image.callable_adapter_recipe(
    Callable([Scalar(I32)], Unit),
    Callable([Erased(i32_expression, Parameter(i32_parameter))], Unit),
    [0],
    i32_substitution,
    [{ id: i32_parameter, arity: 0, }],
  )
  assert_false(bool_recipe == i32_recipe)
}

///|
test "omitting a Unit callable parameter needs no adapter" {
  let image = test_image_lowerer(MetadataRegistry())
  assert_true(
    image.plan_callable_adaptation(
      Callable([Scalar(I64)], Scalar(I64)),
      Callable([Unit, Scalar(I64)], Scalar(I64)),
      RuntimeSubstitution::new(),
    )
    is None,
  )
}

///|
test "a concrete callable result adapts to the canonical generic ABI" {
  let image = test_image_lowerer(MetadataRegistry())
  let parameter = image.fresh_synthetic_parameter()
  let expression = image.runtime_types.intern(Parameter(parameter))
  let substitutions = RuntimeSubstitution::new()
  substitutions.insert(
    parameter,
    runtime_adapter_argument(image.runtime_types, Unit, Static(Unit)),
  )
  let source : @anf.RuntimeType = Callable([], Unit)
  let target : @anf.RuntimeType = Callable(
    [],
    Erased(expression, Parameter(parameter)),
  )
  guard image.plan_callable_adaptation(source, target, substitutions)
    is Some(contract) else {
    fail("canonical generic callable boundary omitted its result adapter")
  }
  assert_false(contract.recipe.source_abi == contract.recipe.target_abi)
  assert_true(contract.recipe.result is Adapt(_))
}
