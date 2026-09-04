///|
test "closure environment projection reads the current instance and checks its target" {
  let environment = owned_slot(
    I32,
    OwnedRef,
    kind=EnvironmentValue({ value: 0, }),
  )
  let target : @physical.FunctionBody = {
    ..body(slots=[environment], instructions=[Release({ value: 0, })]),
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
  }
  for projected_target in [2, 3] {
    let entry = body(
      slots=[
        trivial_slot(I64),
        environment,
        owned_slot(I64, OwnedCallable),
        trivial_slot(I32, kind=EnvironmentValue({ value: 0, })),
        trivial_slot(I64),
      ],
      result=Value(I64, Trivial, ScalarValue),
      instructions=[
        ConstI64({ value: 0, }, 42L),
        MakeEnv({ value: 1, }, { value: 0, }, Immediate({ value: 1, }), [], [
          { value: 0, },
        ]),
        MakeClosure({ value: 2, }, { value: 2, }, { value: 1, }),
        BorrowClosureEnvironment({ value: 3, }, { value: projected_target, }, {
          value: 2,
        }),
        BorrowCapture({ value: 0, }, { value: 3, }, 0, {
          value_destination: { value: 4, },
          witness_destination: None,
        }),
        Release({ value: 2, }),
      ],
      terminator=Return(Some({ value: 4, })),
    )
    let program = {
      ..image([PhysicalBody(entry), PhysicalBody(target), PhysicalBody(target)]),
      layouts: [Environment({ value: 0, })],
      object_shapes: [
        Environment({
          stored_witness_count: 0,
          members: [
            {
              representation: I64,
              cleanup: Trivial,
              kind: ScalarValue,
              witness_ordinal: None,
            },
          ],
        }),
      ],
    }
    let module_ = compile_test_image(program).unwrap()
    let (store, instance) = @executor.instantiate_module_with_init(module_)
    if projected_target == 2 {
      assert_eq(@executor.call_exported_func(store, instance, "_start", []), [
        I64(42L),
      ])
    } else {
      try @executor.call_exported_func(store, instance, "_start", []) catch {
        _ => ()
      } noraise {
        _ => fail("a different target must not expose its environment")
      }
    }
  }
}
