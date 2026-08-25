///|
fn runtime_adapter_argument(
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
  evidence : @anf.RuntimeEvidence,
) -> @anf.RuntimeArgument {
  { type_expression: runtime_types.intern(Static(type_)), evidence, }
}

///|
fn erased_adapter_key() -> CanonicalRuntimeTypeKey {
  Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, })
}

///|
fn bool_adapter_key() -> CanonicalRuntimeTypeKey {
  Value({ representation: I32, cleanup: Trivial, kind: ScalarValue, })
}

///|
fn callable_adapter_recipe_for_test(
  image : ImageLowerer,
  source_type : @anf.RuntimeType,
  target_type : @anf.RuntimeType,
  source_abi : CanonicalCallableAbi,
  target_abi : CanonicalCallableAbi,
  source_parameters : Array[PhysicalCallableParameterProjection],
  target_parameters : Array[PhysicalCallableParameterProjection],
  source_parameter_targets : Array[Int],
  substitutions : RuntimeSubstitution,
  captures : Array[CallableAdapterEvidenceCapture],
  aliases : Array[CallableAdapterEvidenceAlias],
  nested_adapters : Array[CallableAdapterContract],
) -> CallableAdapterRecipe raise LoisvmLoweringError {
  fn interface(
    type_ : @anf.RuntimeType,
    abi : CanonicalCallableAbi,
    projections : Array[PhysicalCallableParameterProjection],
  ) -> PhysicalCallableInterface raise LoisvmLoweringError {
    let (evidence_parameters, logical_parameters, logical_result) = function_type_parts(
      type_,
    )
    {
      evidence_parameters,
      parameter_types: logical_parameters,
      result_type: logical_result,
      invocation: abi,
      parameters: projections,
      parameter_callables: logical_parameters.mapi((index, parameter) => {
        match projections[index] {
          Slot(Callable(nested)) =>
            image.callable_interface_for_type_with_invocation(
              parameter, substitutions, nested,
            )
          _ => None
        }
      }),
      result_callable: match abi.result {
        Callable(nested) =>
          image.callable_interface_for_type_with_invocation(
            logical_result, substitutions, nested,
          )
        _ => None
      },
    }
  }
  image.callable_adapter_recipe_with_interfaces(
    source_type,
    target_type,
    interface(source_type, source_abi, source_parameters),
    interface(target_type, target_abi, target_parameters),
    source_parameter_targets,
    substitutions,
    captures,
    aliases,
    nested_adapters,
  )
}

///|
test "callable adapter preserves the alias for substituted free evidence" {
  let image = test_image_lowerer(MetadataRegistry())
  let source_parameter = image.fresh_synthetic_parameter()
  let target_parameter = image.fresh_synthetic_parameter()
  let source_expression = image.runtime_types.intern(
    Parameter(source_parameter),
  )
  let target_expression = image.runtime_types.intern(
    Parameter(target_parameter),
  )
  let source_type : @anf.RuntimeType = Callable(
    [Callable([Erased(source_expression, Parameter(source_parameter))], Unit)],
    Unit,
  )
  let target_type : @anf.RuntimeType = Callable(
    [Callable([Erased(target_expression, Parameter(target_parameter))], Unit)],
    Unit,
  )
  let substitutions = RuntimeSubstitution::new()
  substitutions.insert(source_parameter, {
    type_expression: target_expression,
    evidence: Parameter(target_parameter),
  })
  let (captures, aliases) = image.callable_adapter_evidence_captures(
    source_type, target_type, substitutions,
  )
  assert_eq(captures.map(capture => capture.source), [
    { id: target_parameter, arity: 0, },
  ])
  assert_eq(aliases.length(), 1)
  assert_true(aliases[0].evidence is Existing(id) && id == source_parameter)
  assert_true(aliases[0].replacement is Existing(id) && id == target_parameter)
}

///|
test "generic erased Unit parameters adapt to a zero-slot worker" {
  let image = test_image_lowerer(MetadataRegistry())
  let type_ : @anf.RuntimeType = Callable([Unit, Unit], Scalar(Bool))
  let erased = erased_adapter_key()
  let result = bool_adapter_key()
  let recipe = callable_adapter_recipe_for_test(
    image,
    type_,
    type_,
    { witnesses: [], parameters: [erased, erased], result, },
    { witnesses: [], parameters: [], result, },
    [Slot(erased), Slot(erased)],
    [Unit, Unit],
    [0, 1],
    RuntimeSubstitution::new(),
    [],
    [],
    [],
  )
  debug_inspect(
    recipe,
    content=(
      #|{
      #|  source_abi: {
      #|    witnesses: [],
      #|    parameters: [
      #|      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue }),
      #|      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue }),
      #|    ],
      #|    result: Value({ representation: I32, cleanup: Trivial, kind: ScalarValue }),
      #|  },
      #|  target_abi: {
      #|    witnesses: [],
      #|    parameters: [],
      #|    result: Value({ representation: I32, cleanup: Trivial, kind: ScalarValue }),
      #|  },
      #|  captured_evidence: [],
      #|  source_witnesses: [],
      #|  target_parameters: [],
      #|  source_arguments: [
      #|    {
      #|      input: Unit,
      #|      flow: {
      #|        value: Unit,
      #|        source_shape: Unit,
      #|        target: Erased(Static(Unit)),
      #|        target_shape: Erased(Static(Unit)),
      #|        definitionally_equal: true,
      #|        nested_adapter: None,
      #|      },
      #|    },
      #|    {
      #|      input: Unit,
      #|      flow: {
      #|        value: Unit,
      #|        source_shape: Unit,
      #|        target: Erased(Static(Unit)),
      #|        target_shape: Erased(Static(Unit)),
      #|        definitionally_equal: true,
      #|        nested_adapter: None,
      #|      },
      #|    },
      #|  ],
      #|  target_discards: [],
      #|  result: TailCall,
      #|}
    ),
  )
}

///|
test "zero-slot worker consumes erased Unit parameters at a generic boundary" {
  let image = test_image_lowerer(MetadataRegistry())
  let type_ : @anf.RuntimeType = Callable([Unit, Unit], Scalar(Bool))
  let erased = erased_adapter_key()
  let result = bool_adapter_key()
  let recipe = callable_adapter_recipe_for_test(
    image,
    type_,
    type_,
    { witnesses: [], parameters: [], result, },
    { witnesses: [], parameters: [erased, erased], result, },
    [Unit, Unit],
    [Slot(erased), Slot(erased)],
    [0, 1],
    RuntimeSubstitution::new(),
    [],
    [],
    [],
  )
  debug_inspect(
    recipe,
    content=(
      #|{
      #|  source_abi: {
      #|    witnesses: [],
      #|    parameters: [],
      #|    result: Value({ representation: I32, cleanup: Trivial, kind: ScalarValue }),
      #|  },
      #|  target_abi: {
      #|    witnesses: [],
      #|    parameters: [
      #|      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue }),
      #|      Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue }),
      #|    ],
      #|    result: Value({ representation: I32, cleanup: Trivial, kind: ScalarValue }),
      #|  },
      #|  captured_evidence: [],
      #|  source_witnesses: [],
      #|  target_parameters: [Erased(Static(Unit)), Erased(Static(Unit))],
      #|  source_arguments: [],
      #|  target_discards: [
      #|    {
      #|      input: 0,
      #|      flow: {
      #|        value: Erased(Static(Unit)),
      #|        source_shape: Erased(Static(Unit)),
      #|        target: Unit,
      #|        target_shape: Unit,
      #|        definitionally_equal: true,
      #|        nested_adapter: None,
      #|      },
      #|    },
      #|    {
      #|      input: 1,
      #|      flow: {
      #|        value: Erased(Static(Unit)),
      #|        source_shape: Erased(Static(Unit)),
      #|        target: Unit,
      #|        target_shape: Unit,
      #|        definitionally_equal: true,
      #|        nested_adapter: None,
      #|      },
      #|    },
      #|  ],
      #|  result: TailCall,
      #|}
    ),
  )
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
  let left_recipe = callable_adapter_recipe_for_test(
    image,
    source,
    left_target,
    image.canonical_callable_abi_under(source, left_substitution),
    image.canonical_callable_abi_under(left_target, left_substitution),
    [Slot(Value({ representation: I64, cleanup: Trivial, kind: ScalarValue, }))],
    [
      Slot(
        Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, }),
      ),
    ],
    [0],
    left_substitution,
    [],
    [
      {
        evidence: Existing(left),
        replacement: StaticLayout({ recipe: I64, layout: { value: 1, }, }),
      },
    ],
    [],
  )
  let right_recipe = callable_adapter_recipe_for_test(
    image,
    source,
    right_target,
    image.canonical_callable_abi_under(source, right_substitution),
    image.canonical_callable_abi_under(right_target, right_substitution),
    [Slot(Value({ representation: I64, cleanup: Trivial, kind: ScalarValue, }))],
    [
      Slot(
        Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, }),
      ),
    ],
    [0],
    right_substitution,
    [],
    [
      {
        evidence: Existing(right),
        replacement: StaticLayout({ recipe: I64, layout: { value: 1, }, }),
      },
    ],
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
  image.preplan_callable_adapter_recipe(left_contract.recipe)
  image.preplan_callable_adapter_recipe(right_contract.recipe)
  let left_worker = image.planned_callable_adapter_recipe(left_contract.recipe)
  let right_worker = image.planned_callable_adapter_recipe(
    right_contract.recipe,
  )
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
  let bool_recipe = callable_adapter_recipe_for_test(
    image,
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
    [Slot(Value({ representation: I32, cleanup: Trivial, kind: ScalarValue, }))],
    [
      Slot(
        Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, }),
      ),
    ],
    [0],
    bool_substitution,
    [],
    [
      {
        evidence: Existing(bool_parameter),
        replacement: StaticLayout({ recipe: Bool, layout: { value: 1, }, }),
      },
    ],
    [],
  )
  let i32_recipe = callable_adapter_recipe_for_test(
    image,
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
    [Slot(Value({ representation: I32, cleanup: Trivial, kind: ScalarValue, }))],
    [
      Slot(
        Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, }),
      ),
    ],
    [0],
    i32_substitution,
    [],
    [
      {
        evidence: Existing(i32_parameter),
        replacement: StaticLayout({ recipe: I32, layout: { value: 1, }, }),
      },
    ],
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
test "nested callable adaptation observes the substituted erased head" {
  let image = test_image_lowerer(MetadataRegistry())
  let outer = image.fresh_synthetic_parameter()
  let inner = image.fresh_synthetic_parameter()
  let outer_expression = image.runtime_types.intern(Parameter(outer))
  let inner_expression = image.runtime_types.intern(Parameter(inner))
  let erased_inner : @anf.RuntimeType = Erased(
    inner_expression,
    Parameter(inner),
  )
  let source_callable : @anf.RuntimeType = Callable(
    [erased_inner],
    erased_inner,
  )
  let target_callable : @anf.RuntimeType = Callable([erased_inner], Scalar(I64))
  let substitutions = RuntimeSubstitution::new()
  substitutions.insert(outer, {
    type_expression: image.runtime_types.intern(Static(source_callable)),
    evidence: Static(Callable),
  })
  let source_abi = image.canonical_callable_abi_under(
    source_callable,
    RuntimeSubstitution::new(),
  )
  let target_abi = image.canonical_callable_abi_under(
    target_callable,
    RuntimeSubstitution::new(),
  )
  let contract = image.callable_adapter_nested_contract(
    Erased(outer_expression, Parameter(outer)),
    target_callable,
    substitutions,
    Some(erased_adapter_key()),
    Some(Callable(target_abi)),
    None,
    None,
  )
  assert_true(
    contract
    is Some(
      {
        recipe: { source_abi: actual_source, target_abi: actual_target, .. },
        ..
      }
    ) &&
    actual_source == source_abi &&
    actual_target == target_abi,
  )
}

///|
test "callable erasure follows the physical key after substitution reveals a callable" {
  let image = test_image_lowerer(MetadataRegistry())
  let outer = image.fresh_synthetic_parameter()
  let inner = image.fresh_synthetic_parameter()
  let outer_expression = image.runtime_types.intern(Parameter(outer))
  let inner_expression = image.runtime_types.intern(Parameter(inner))
  let erased_inner : @anf.RuntimeType = Erased(
    inner_expression,
    Parameter(inner),
  )
  let callable : @anf.RuntimeType = Callable([erased_inner], erased_inner)
  let substitutions = RuntimeSubstitution::new()
  substitutions.insert(outer, {
    type_expression: image.runtime_types.intern(Static(callable)),
    evidence: Static(Callable),
  })
  let exact_abi : CanonicalCallableAbi = {
    witnesses: [],
    parameters: [bool_adapter_key()],
    result: bool_adapter_key(),
  }
  let exact_interface = image.callable_interface_under_with_invocation(
    callable,
    RuntimeSubstitution::new(),
    exact_abi,
  )
  let canonical_abi = image.canonical_callable_abi_under(
    callable,
    RuntimeSubstitution::new(),
  )
  let contract = image.callable_adapter_nested_contract(
    callable,
    Erased(outer_expression, Parameter(outer)),
    substitutions,
    Some(Callable(exact_abi)),
    Some(erased_adapter_key()),
    Some(exact_interface),
    None,
  )
  assert_true(
    contract
    is Some(
      {
        recipe: { source_abi: actual_source, target_abi: actual_target, .. },
        ..
      }
    ) &&
    actual_source == exact_abi &&
    actual_target == canonical_abi,
  )
}

///|
test "callable adapter rejects identity flow across nominal data families" {
  let image = test_image_lowerer(MetadataRegistry())
  let owner : @buslane.TypeId = { index: 0, }
  let type_ : @anf.RuntimeType = Callable([Data(owner, [])], Data(owner, []))
  let data = fn(family : Int) -> CanonicalRuntimeTypeKey {
    Value({
      representation: I32,
      cleanup: OwnedRef,
      kind: DataValue({ value: family, }),
    })
  }
  let result : Result[CallableAdapterRecipe, LoisvmLoweringError] = Ok(
    callable_adapter_recipe_for_test(
      image,
      type_,
      type_,
      { witnesses: [], parameters: [data(1)], result: data(1), },
      { witnesses: [], parameters: [data(2)], result: data(2), },
      [Slot(data(1))],
      [Slot(data(2))],
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
