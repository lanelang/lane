///|
test "trivial functions omit frame liveness locals" {
  let trivial_slot : @physical.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let body : @physical.FunctionBody = {
    slots: [trivial_slot, trivial_slot, trivial_slot],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, 40L),
          ConstI64({ value: 1, }, 2L),
          I64Add({ value: 2, }, { value: 0, }, { value: 1, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    functions: [PhysicalBody(body)],
    globals: [],
    layouts: [],
    object_shapes: [],
    constants: [],
  }
  let wasm_module = match compile(certify_physical_program_wbtest(image)) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  debug_inspect(wasm_module.codes[0].locals, content="[I64, I64, I64]")
}

///|
test "CFG functions share packed liveness state across owned slots" {
  let trivial_i64 : @physical.SlotMetadata = {
    representation: I64,
    cleanup: Trivial,
    kind: ScalarValue,
    erased_companion: None,
  }
  let owned_string : @physical.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let body : @physical.FunctionBody = {
    slots: [trivial_i64, owned_string, trivial_i64, owned_string],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 0, }, 42L),
          ConstString({ value: 1, }, { value: 0, }),
        ],
        terminator: Jump({
          target: { value: 1, },
          arguments: [{ value: 0, }, { value: 1, }],
        }),
      },
      {
        parameters: [{ value: 2, }, { value: 3, }],
        instructions: [Release({ value: 3, })],
        terminator: Return(None),
      },
    ],
  }
  let image : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    functions: [PhysicalBody(body)],
    globals: [],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"Lane"],
  }
  let wasm_module = match compile(certify_physical_program_wbtest(image)) {
    Ok(module_) => module_
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  debug_inspect(
    wasm_module.codes[0].locals,
    content="[I64, I32, I64, I32, I64, I32]",
  )
}

///|
test "reference ownership uses the physical slot as its liveness state" {
  let owned_string : @physical.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let slots = Array::make(65, owned_string)
  let body : @physical.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Unreachable, }],
  }
  let plan = plan_function_locals(body, 1, false, false)
  assert_eq(plan.slot_local_count, 65)
  assert_eq(plan.arc_local_count, 0)
  assert_eq(plan.locals.length(), 65)
  debug_inspect(
    plan.mark_slot_dead({ value: 64, }),
    content="[I32Const(0), LocalSet(65)]",
  )
}

///|
test "erased ownership retains an explicit liveness local" {
  let erased_value : @physical.SlotMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    erased_companion: Some({ value: 0, }),
  }
  let body : @physical.FunctionBody = {
    slots: [erased_value],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Unreachable, }],
  }
  let plan = plan_function_locals(body, 1, false, false)
  assert_eq(plan.slot_local_count, 1)
  assert_eq(plan.arc_local_count, 1)
  debug_inspect(plan.locals, content="[I64, I32]")
  debug_inspect(
    plan.mark_slot_live({ value: 0, }),
    content="[I32Const(1), LocalSet(2)]",
  )
  debug_inspect(
    plan.mark_slot_dead({ value: 0, }),
    content="[I32Const(0), LocalSet(2)]",
  )
}
