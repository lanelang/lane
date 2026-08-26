///|
fn runtime_adapter_argument(
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
  evidence : @anf.RuntimeEvidence,
) -> @anf.RuntimeArgument {
  { type_expression: runtime_types.intern(Static(type_)), evidence, }
}

///|
test "alpha-renamed evidence captures share one callable adapter worker" {
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
  guard image.plan_callable_adaptation(source, left_target, left_substitution)
    is Some(left_contract) else {
    fail("expected the left callable boundary to need adaptation")
  }
  guard image.plan_callable_adaptation(source, right_target, right_substitution)
    is Some(right_contract) else {
    fail("expected the right callable boundary to need adaptation")
  }
  let left_worker = image.callable_adapter(left_contract)
  let right_worker = image.callable_adapter(right_contract)
  assert_eq(image.callable_adapters.length(), 1)
  assert_eq(left_worker.function, right_worker.function)
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
  assert_true(
    image.plan_callable_adaptation(
      Callable([], Unit),
      Callable([], Erased(expression, Parameter(parameter))),
      substitutions,
    )
    is Some(_),
  )
}

///|
test "adapter capture discovery ignores evidence erased by beta reduction" {
  let image = test_image_lowerer(MetadataRegistry())
  let free = image.fresh_synthetic_parameter()
  let ignored = image.fresh_synthetic_parameter()
  let expression = image.runtime_types.intern(Parameter(free))
  let source : @anf.RuntimeType = Callable(
    [],
    Data({ index: 0, }, [
      { type_expression: expression, evidence: Parameter(free), },
    ]),
  )
  let target : @anf.RuntimeType = Callable(
    [],
    Erased(
      expression,
      Apply(Lambda([{ id: ignored, arity: 0, }], Static(Reference)), [
        Parameter(free),
      ]),
    ),
  )
  assert_eq(
    free_runtime_type_parameters_under(
      image,
      source,
      target,
      RuntimeSubstitution::new(),
    ),
    [],
  )
}

///|
test "adapter capture discovery retains a phantom source witness" {
  let image = test_image_lowerer(MetadataRegistry())
  let source_parameter = image.fresh_synthetic_parameter()
  let free = image.fresh_synthetic_parameter()
  let free_expression = image.runtime_types.intern(Parameter(free))
  let substitutions = RuntimeSubstitution::new()
  substitutions.insert(source_parameter, {
    type_expression: free_expression,
    evidence: Parameter(free),
  })
  assert_eq(
    free_runtime_type_parameters_under(
      image,
      Forall([{ id: source_parameter, arity: 0, }], Callable([], Unit)),
      Callable([], Unit),
      substitutions,
    ),
    [{ id: free, arity: 0, }],
  )
}
