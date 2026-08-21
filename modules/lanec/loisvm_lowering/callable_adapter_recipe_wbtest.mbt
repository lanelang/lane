///|
fn runtime_adapter_argument(
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
  evidence : @anf.RuntimeEvidence,
) -> @anf.RuntimeArgument {
  { type_expression: runtime_types.intern(Static(type_)), evidence }
}

///|
test "alpha-renamed evidence aliases share one callable adapter recipe" {
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
    image.canonical_callable_abi_under(source, left_substitution),
    image.canonical_callable_abi_under(left_target, left_substitution),
    [0],
    left_substitution,
    [],
    [{ evidence: Existing(left), replacement: StaticLayout(I64) }],
    [],
  )
  let right_recipe = image.callable_adapter_recipe(
    source,
    right_target,
    image.canonical_callable_abi_under(source, right_substitution),
    image.canonical_callable_abi_under(right_target, right_substitution),
    [0],
    right_substitution,
    [],
    [{ evidence: Existing(right), replacement: StaticLayout(I64) }],
    [],
  )
  assert_eq(left_recipe, right_recipe)
  let left_contract : CallableAdapterContract = {
    recipe: left_recipe,
    source_type: source,
    target_type: left_target,
    source_parameter_targets: [0],
    substitutions: left_substitution,
    captures: [],
    nested_adapters: [],
  }
  let right_contract : CallableAdapterContract = {
    recipe: right_recipe,
    source_type: source,
    target_type: right_target,
    source_parameter_targets: [0],
    substitutions: right_substitution,
    captures: [],
    nested_adapters: [],
  }
  let physical = PhysicalRepresentationPlan::new()
  physical.record_adapter_contract(left_contract)
  physical.record_adapter_contract(right_contract)
  debug_inspect(
    (
      physical.adapter_contracts.length(),
      image.callable_adapters.length(),
      image.plans.length(),
    ),
    content="(1, 0, 0)",
  )
  image.materialize_physical_representation_support(physical)
  let left_worker = image.planned_callable_adapter(left_contract)
  let right_worker = image.planned_callable_adapter(right_contract)
  debug_inspect(
    (image.callable_adapters.length(), image.plans.length()),
    content="(1, 1)",
  )
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
    image.canonical_callable_abi_under(
      Callable([Scalar(Bool)], Unit),
      bool_substitution,
    ),
    image.canonical_callable_abi_under(
      Callable([Erased(bool_expression, Parameter(bool_parameter))], Unit),
      bool_substitution,
    ),
    [0],
    bool_substitution,
    [],
    [{ evidence: Existing(bool_parameter), replacement: StaticLayout(Bool) }],
    [],
  )
  let i32_recipe = image.callable_adapter_recipe(
    Callable([Scalar(I32)], Unit),
    Callable([Erased(i32_expression, Parameter(i32_parameter))], Unit),
    image.canonical_callable_abi_under(
      Callable([Scalar(I32)], Unit),
      i32_substitution,
    ),
    image.canonical_callable_abi_under(
      Callable([Erased(i32_expression, Parameter(i32_parameter))], Unit),
      i32_substitution,
    ),
    [0],
    i32_substitution,
    [],
    [{ evidence: Existing(i32_parameter), replacement: StaticLayout(I32) }],
    [],
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
test "callable adapter rejects identity flow across nominal data families" {
  let image = test_image_lowerer(MetadataRegistry())
  let owner : @buslane.TypeId = { index: 0 }
  let type_ : @anf.RuntimeType = Callable([Data(owner, [])], Data(owner, []))
  let data = fn(family : Int) -> CanonicalRuntimeTypeKey {
    Value({
      representation: I32,
      cleanup: OwnedRef,
      kind: DataValue({ value: family }),
    })
  }
  let result : Result[CallableAdapterRecipe, LoisvmLoweringError] = Ok(
    image.callable_adapter_recipe(
      type_,
      type_,
      { witnesses: [], parameters: [data(1)], result: data(1) },
      { witnesses: [], parameters: [data(2)], result: data(2) },
      [0],
      RuntimeSubstitution::new(),
      [],
      [],
      [],
    ),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}
