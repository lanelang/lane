///|
fn trivial_slot(
  representation : @physical.Representation,
  kind? : @physical.SemanticValueKind = ScalarValue,
) -> @physical.SlotMetadata {
  { representation, cleanup: Trivial, kind, erased_companion: None, }
}

///|
fn owned_slot(
  representation : @physical.Representation,
  cleanup : @physical.Cleanup,
  kind? : @physical.SemanticValueKind = match cleanup {
    OwnedCallable => CallableValue
    OwnedRef => ByteSequenceValue
    OwnedErased => ErasedValue
    Trivial => ScalarValue
  },
) -> @physical.SlotMetadata {
  { representation, cleanup, kind, erased_companion: None, }
}

///|
fn contains_return_call(
  instructions : Array[@wasm_types.Instruction],
  target : Int,
) -> Bool {
  for instruction in instructions {
    match instruction {
      ReturnCall(actual) if actual == target => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if contains_return_call(body, target) {
          return true
        }
      If(_, consequent, alternate) =>
        if contains_return_call(consequent, target) ||
          contains_return_call(alternate, target) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn contains_return_call_indirect(
  instructions : Array[@wasm_types.Instruction],
) -> Bool {
  for instruction in instructions {
    match instruction {
      ReturnCallIndirect(_, 0) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if contains_return_call_indirect(body) {
          return true
        }
      If(_, consequent, alternate) =>
        if contains_return_call_indirect(consequent) ||
          contains_return_call_indirect(alternate) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn contains_call_indirect(
  instructions : Array[@wasm_types.Instruction],
) -> Bool {
  for instruction in instructions {
    match instruction {
      CallIndirect(_, _) | ReturnCallIndirect(_, _) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if contains_call_indirect(body) {
          return true
        }
      If(_, consequent, alternate) =>
        if contains_call_indirect(consequent) ||
          contains_call_indirect(alternate) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn contains_br_table(instructions : Array[@wasm_types.Instruction]) -> Bool {
  for instruction in instructions {
    match instruction {
      BrTable(_, _) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if contains_br_table(body) {
          return true
        }
      If(_, consequent, alternate) =>
        if contains_br_table(consequent) || contains_br_table(alternate) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn contains_loop(instructions : Array[@wasm_types.Instruction]) -> Bool {
  for instruction in instructions {
    match instruction {
      Loop(_, _) => return true
      Block(_, body) | TryTable(_, _, body) =>
        if contains_loop(body) {
          return true
        }
      If(_, consequent, alternate) =>
        if contains_loop(consequent) || contains_loop(alternate) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn contains_try_table(instructions : Array[@wasm_types.Instruction]) -> Bool {
  for instruction in instructions {
    match instruction {
      TryTable(_, _, _) => return true
      Block(_, body) | Loop(_, body) =>
        if contains_try_table(body) {
          return true
        }
      If(_, consequent, alternate) =>
        if contains_try_table(consequent) || contains_try_table(alternate) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
test "control depth follows the structured instruction tree" {
  let module_ = @wasm_types.Module::simple(
    [],
    [],
    [Block(Empty, [If(Empty, [Loop(Empty, [Nop])], [])])],
    "entry",
  )
  assert_eq(maximum_function_control_depth(module_), 3)
}

///|
fn body(
  slots? : Array[@physical.SlotMetadata] = [],
  parameters? : Array[@physical.SlotId] = [],
  result? : @physical.ResultAbi = Unit,
  instructions? : Array[@physical.Instruction] = [],
  terminator? : @physical.Terminator = Return(None),
) -> @physical.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: parameters, },
    result,
    blocks: [{ parameters: [], instructions, terminator, }],
  }
}

///|
fn image(
  functions : Array[@physical.FunctionEntry],
) -> @physical.PhysicalProgram {
  let callable_abis : Array[@physical.CallableAbi] = []
  for entry in functions {
    if entry.callable_abi() is Some(abi) && !callable_abis.contains(abi) {
      callable_abis.push(abi)
    }
  }
  {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis,
    globals: [],
    functions,
    layouts: [],
    object_shapes: [],
    constants: [],
  }
}

///|
fn compile_test_image(
  image : @physical.PhysicalProgram,
) -> Result[@wasm_types.Module, WasmCompileError] {
  @wasm_target.compile(certify_physical_program_test(image))
}

///|
fn compile_test_image_observed(
  image : @physical.PhysicalProgram,
) -> Result[WasmCompileObservation, WasmCompileError] {
  @wasm_target.compile_observed(certify_physical_program_test(image))
}

///|
test "Fatal emits a platform-independent Wasm trap" {
  let entry = body(terminator=Fatal)
  let observed = compile_test_image_observed({ ..image([PhysicalBody(entry)]), }).unwrap()
  assert_eq(observed.module_.imports, [])
  assert_eq(observed.module_.codes[0].body, [Unreachable])
}

///|
fn edge(
  target : Int,
  arguments? : Array[@physical.SlotId] = [],
) -> @physical.Edge {
  { target: { value: target, }, arguments, }
}

///|
fn straight_line_cfg(block_count : Int) -> @physical.FunctionBody {
  let blocks : Array[@physical.Block] = []
  for index in 0..<block_count {
    blocks.push({
      parameters: [],
      instructions: [],
      terminator: if index + 1 == block_count {
        Return(None)
      } else {
        Jump(edge(index + 1))
      },
    })
  }
  {
    slots: [],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks,
  }
}

///|
fn ceiling_log2(value : Int) -> Int {
  let mut power = 1
  let mut exponent = 0
  while power < value {
    power *= 2
    exponent += 1
  }
  exponent
}

///|
fn run_entry(body : @physical.FunctionBody) -> Unit raise {
  let wasm_module = match compile_test_image(image([PhysicalBody(body)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "compiled scalar Physical Program executes with Wasmoon" {
  let entry = body(slots=[trivial_slot(I64)], instructions=[
    CallDirect({ value: 2, }, None, [], [], Some({ value: 0, })),
  ])
  let target = body(
    slots=[trivial_slot(I64), trivial_slot(I64), trivial_slot(I64)],
    result=Value(I64, Trivial, ScalarValue),
    instructions=[
      ConstI64({ value: 0, }, 40L),
      ConstI64({ value: 1, }, 2L),
      I64Add({ value: 2, }, { value: 0, }, { value: 1, }),
    ],
    terminator=Return(Some({ value: 2, })),
  )
  let wasm_module = match
    compile_test_image(image([PhysicalBody(entry), PhysicalBody(target)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "compiled tail calls use Wasmoon tail-call support" {
  assert_true(@wasmoon_runtime.supports_tail_call())
  let entry = body(terminator=TailCallDirect({ value: 2, }, None, [], []))
  let target = body()
  let wasm_module = match
    compile_test_image(image([PhysicalBody(entry), PhysicalBody(target)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_return_call(wasm_module.codes[0].body, 1))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "invalid Physical Program is rejected at certification" {
  let invalid_entry = body(instructions=[
    CallDirect({ value: 2, }, None, [], [], None),
  ])
  let target = body(slots=[trivial_slot(I64)], parameters=[{ value: 0, }])
  assert_true(
    @physical.verify_physical_program(
      image([PhysicalBody(invalid_entry), PhysicalBody(target)]),
    )
    is Err(_),
  )
}

///|
test "Physical certification rejects packed direct target without environment" {
  let entry = body(slots=[owned_slot(I64, OwnedCallable)], instructions=[
    ConstFunction({ value: 0, }, { value: 2, }),
    CallPackedDirect({ value: 2, }, { value: 0, }, [], [], None),
  ])
  let error = match
    @physical.verify_physical_program(
      image([PhysicalBody(entry), PhysicalBody(body())]),
    ) {
    Ok(_) => None
    Err(error) => Some(error)
  }
  assert_eq(
    error,
    Some(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 1),
        detail="packed direct-call target requires an environment",
      ),
    ),
  )
}

///|
test "Physical certification rejects call result ownership mismatch" {
  let caller = body(slots=[owned_slot(I32, OwnedRef)], instructions=[
    CallDirect({ value: 2, }, None, [], [], Some({ value: 0, })),
    Release({ value: 0, }),
  ])
  let target = body(
    slots=[trivial_slot(I32)],
    result=Value(I32, Trivial, ScalarValue),
    instructions=[ConstI32({ value: 0, }, 42)],
    terminator=Return(Some({ value: 0, })),
  )
  let error = match
    @physical.verify_physical_program(
      image([PhysicalBody(caller), PhysicalBody(target)]),
    ) {
    Ok(_) => None
    Err(error) => Some(error)
  }
  assert_eq(
    error,
    Some(
      InvalidPhysicalProgram(
        site=Instruction({ value: 1, }, { value: 0, }, 0),
        detail="call result ABI does not match destination slot",
      ),
    ),
  )
}

///|
test "structured CFG executes boolean branches and dense tag switches" {
  let branch_body : @physical.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: BranchBool({ value: 0, }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  let branch_module = match
    compile_test_image(image([PhysicalBody(branch_body)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_false(contains_br_table(branch_module.codes[0].body))
  let (branch_store, branch_instance) = @executor.instantiate_module_with_init(
    branch_module,
  )
  assert_eq(
    @executor.call_exported_func(branch_store, branch_instance, "_start", []),
    [],
  )
  let switch_body : @physical.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: SwitchTag({ value: 0, }, [edge(2), edge(1)], edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  run_entry(switch_body)
}

///|
test "reducible loops use Wasm loop control" {
  let loop_body : @physical.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      { parameters: [], instructions: [], terminator: Jump(edge(1)), },
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, false)],
        terminator: BranchBool({ value: 0, }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
    ],
  }
  let wasm_module = match compile_test_image(image([PhysicalBody(loop_body)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_loop(wasm_module.codes[0].body))
  assert_false(contains_br_table(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "nested reducible loops preserve structured branch depths" {
  let nested : @physical.FunctionBody = {
    slots: [trivial_slot(I32), trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: Jump(edge(1)),
      },
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 0, }, edge(2), edge(6)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 1, }, true)],
        terminator: Jump(edge(3)),
      },
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 1, }, edge(4), edge(5)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 1, }, false)],
        terminator: Jump(edge(3)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, false)],
        terminator: Jump(edge(1)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
    ],
  }
  let wasm_module = match compile_test_image(image([PhysicalBody(nested)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_loop(wasm_module.codes[0].body))
  assert_false(contains_br_table(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "irreducible CFG uses the dispatcher fallback" {
  let irreducible : @physical.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, true)],
        terminator: BranchBool({ value: 0, }, edge(1), edge(2)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 0, }, false)],
        terminator: Jump(edge(2)),
      },
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 0, }, edge(1), edge(3)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
    ],
  }
  let wasm_module = match
    compile_test_image(image([PhysicalBody(irreducible)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_br_table(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "straight-line CFG selects the balanced dispatcher above the cutoff" {
  let small_module = match
    compile_test_image(image([PhysicalBody(straight_line_cfg(16))])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_false(contains_loop(small_module.codes[0].body))
  assert_false(contains_br_table(small_module.codes[0].body))
  let large_module = match
    compile_test_image(image([PhysicalBody(straight_line_cfg(17))])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_loop(large_module.codes[0].body))
  assert_false(contains_br_table(large_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(large_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "balanced dispatcher control depth grows logarithmically" {
  for block_count in [17, 64, 257] {
    let wasm_module = match
      compile_test_image(image([PhysicalBody(straight_line_cfg(block_count))])) {
      Ok(value) => value
      Err(error) => fail("compile failed: \{Repr(error)}")
    }
    assert_true(contains_loop(wasm_module.codes[0].body))
    assert_false(contains_br_table(wasm_module.codes[0].body))
    // The outer failure block, try table, and dispatcher loop each add one.
    let fixed_wrapper_depth = 3
    assert_true(
      maximum_function_control_depth(wasm_module) <=
      fixed_wrapper_depth + ceiling_log2(block_count),
    )
  }
}

///|
test "structured CFG transfers block arguments in parallel" {
  let slots = [
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I32),
  ]
  let cfg_body : @physical.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstI64({ value: 0, }, 1L), ConstI64({ value: 1, }, 2L)],
        terminator: Jump(edge(1, arguments=[{ value: 1, }, { value: 0, }])),
      },
      {
        parameters: [{ value: 0, }, { value: 1, }],
        instructions: [
          ConstI64({ value: 2, }, 2L),
          I64Eq({ value: 3, }, { value: 0, }, { value: 2, }),
        ],
        terminator: BranchBool({ value: 3, }, edge(2), edge(4)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 2, }, 1L),
          I64Eq({ value: 3, }, { value: 1, }, { value: 2, }),
        ],
        terminator: BranchBool({ value: 3, }, edge(3), edge(4)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  run_entry(cfg_body)
}

///|
test "packed callables execute through the canonical function table" {
  let entry = body(
    slots=[owned_slot(I64, OwnedCallable), trivial_slot(I64), trivial_slot(I64)],
    instructions=[
      ConstFunction({ value: 0, }, { value: 2, }),
      ConstI64({ value: 1, }, 42L),
      CallValue(
        { value: 0, },
        { value: 1, },
        [],
        [{ value: 1, }],
        Some({ value: 2, }),
      ),
    ],
  )
  let identity = body(
    slots=[trivial_slot(I64)],
    parameters=[{ value: 0, }],
    result=Value(I64, Trivial, ScalarValue),
    terminator=Return(Some({ value: 0, })),
  )
  let observed = match
    compile_test_image_observed(
      image([PhysicalBody(entry), PhysicalBody(identity)]),
    ) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let wasm_module = observed.module_
  let abi_guards = observed.functions.filter(function => {
    function.origin is HelperFunction(CallableAbiGuard)
  })
  guard abi_guards is [abi_guard] else {
    fail("expected exactly one callable ABI guard helper")
  }
  let guard_scale = observed.scale.functions.filter(function => {
    function.index == abi_guard.index
  })
  guard guard_scale is [guard_scale] else {
    fail("expected one observed callable ABI guard")
  }
  debug_inspect(
    guard_scale.expansions,
    content="[{ category: RuntimeGuard, instruction_count: 23, local_count: 0 }]",
  )
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "callable target metadata stores one canonical ABI identity per table slot" {
  let entry = body(
    slots=[owned_slot(I64, OwnedCallable), owned_slot(I64, OwnedCallable)],
    instructions=[
      ConstFunction({ value: 0, }, { value: 2, }),
      ConstFunction({ value: 1, }, { value: 3, }),
      Release({ value: 0, }),
      Release({ value: 1, }),
    ],
  )
  let scalar = body(slots=[trivial_slot(I32)], parameters=[{ value: 0, }])
  let wasm_module = compile_test_image(
    image([PhysicalBody(entry), PhysicalBody(body()), PhysicalBody(scalar)]),
  ).unwrap()
  guard wasm_module.datas is [static_image] else {
    fail("expected one static image")
  }
  assert_eq(static_image.init.length(), 56)
}

///|
test "fatal propagation installs no per-frame ownership cleanup" {
  let reference = owned_slot(I32, OwnedRef)
  let owning_body = body(slots=[reference], instructions=[
    ConstString({ value: 0, }, { value: 0, }),
    Release({ value: 0, }),
  ])
  let observed = compile_test_image_observed({
    ..image([PhysicalBody(owning_body)]),
    layouts: [ByteSequence],
    constants: [b"owned"],
  }).unwrap()
  assert_false(
    observed.module_.codes.any(code => contains_try_table(code.body)),
  )
}

///|
test "ordinary functions emit no execution-policy runtime guard" {
  let observed = compile_test_image_observed(image([PhysicalBody(body())])).unwrap()
  guard observed.functions.filter(function => {
      function.origin is PhysicalFunction(function={ value: 1, })
    })
    is [entry_provenance] else {
    fail("expected one emitted Physical function")
  }
  guard observed.scale.functions.filter(function => {
      function.index == entry_provenance.index
    })
    is [entry] else {
    fail("expected scale facts for the emitted Physical function")
  }
  assert_eq(
    entry.expansions.filter(expansion => expansion.category is RuntimeGuard),
    [],
  )
}

///|
test "packed callable ownership ABI mismatch traps in both Wasm modes" {
  let entry = body(slots=[owned_slot(I64, OwnedCallable), trivial_slot(I32)], instructions=[
    ConstFunction({ value: 0, }, { value: 2, }),
    ConstBool({ value: 1, }, true),
    CallValue({ value: 0, }, { value: 1, }, [], [{ value: 1, }], None),
  ])
  let target = body(
    slots=[owned_slot(I32, OwnedRef)],
    parameters=[{ value: 0, }],
    instructions=[Release({ value: 0, })],
  )
  let physical_program = {
    ..image([PhysicalBody(entry), PhysicalBody(target)]),
    callable_abis: [
      { witnesses: [], parameters: [], result: Unit, },
      {
        witnesses: [],
        parameters: [
          { representation: I32, cleanup: Trivial, kind: ScalarValue, },
        ],
        result: Unit,
      },
      {
        witnesses: [],
        parameters: [
          { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue, },
        ],
        result: Unit,
      },
    ],
  }
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    let loaded = match load(physical_program, mode~) {
      Ok(value) => value
      Err(error) => fail("load failed: \{Repr(error)}")
    }
    let instance = match loaded.new_instance() {
      Ok(value) => value
      Err(error) => fail("instantiation failed: \{Repr(error)}")
    }
    assert_true(instance.execute() is Err(EngineTrap(detail=_)))
  }
}

///|
test "packed closure environment and indirect tail call execute" {
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, })),
      owned_slot(I64, OwnedCallable),
    ],
    instructions=[
      MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
    ],
    terminator=TailCallValue({ value: 1, }, { value: 0, }, [], []),
  )
  let target : @physical.FunctionBody = {
    slots: [owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, }))],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
    ],
  }
  let physical_program = {
    ..image([PhysicalBody(entry), PhysicalBody(target)]),
    layouts: [Environment({ value: 0, })],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_return_call_indirect(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "packed direct call transfers its environment without an ABI guard" {
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, })),
      owned_slot(I64, OwnedCallable),
    ],
    instructions=[
      MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
      CallPackedDirect({ value: 2, }, { value: 1, }, [], [], None),
    ],
  )
  let target : @physical.FunctionBody = {
    slots: [owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, }))],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
    ],
  }
  let observed = compile_test_image_observed({
    ..image([PhysicalBody(entry), PhysicalBody(target)]),
    layouts: [Environment({ value: 0, })],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
  }).unwrap()
  assert_false(contains_call_indirect(observed.module_.codes[0].body))
  assert_false(
    observed.functions.any(function => {
      function.origin is HelperFunction(CallableAbiGuard)
    }),
  )
  assert_eq(
    observed.functions
    .filter(function => {
      function.origin is HelperFunction(PackedCallableTargetGuard)
    })
    .length(),
    1,
  )
  let (store, instance) = @executor.instantiate_module_with_init(
    observed.module_,
  )
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "packed direct tail call uses the authenticated direct target" {
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, })),
      owned_slot(I64, OwnedCallable),
    ],
    instructions=[
      MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
    ],
    terminator=TailCallPackedDirect({ value: 2, }, { value: 1, }, [], []),
  )
  let target : @physical.FunctionBody = {
    slots: [owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, }))],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0, })],
        terminator: Return(None),
      },
    ],
  }
  let observed = compile_test_image_observed({
    ..image([PhysicalBody(entry), PhysicalBody(target)]),
    layouts: [Environment({ value: 0, })],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
  }).unwrap()
  guard observed.functions.filter(function => {
      function.origin is PhysicalFunction(function={ value: 2, })
    })
    is [target_function] else {
    fail("expected direct target function")
  }
  assert_true(
    contains_return_call(observed.module_.codes[0].body, target_function.index),
  )
  assert_false(contains_call_indirect(observed.module_.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(
    observed.module_,
  )
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "packed direct call traps when the carrier belongs to another target" {
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, })),
      owned_slot(I64, OwnedCallable),
    ],
    instructions=[
      MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
      CallPackedDirect({ value: 3, }, { value: 1, }, [], [], None),
    ],
  )
  let make_target = fn() -> @physical.FunctionBody {
    {
      slots: [owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, }))],
      inputs: {
        environment: Some({ value: 0, }),
        witnesses: [],
        user_parameters: [],
      },
      result: Unit,
      blocks: [
        {
          parameters: [],
          instructions: [Release({ value: 0, })],
          terminator: Return(None),
        },
      ],
    }
  }
  let physical_program = {
    ..image([
      PhysicalBody(entry),
      PhysicalBody(make_target()),
      PhysicalBody(make_target()),
    ]),
    layouts: [Environment({ value: 0, })],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
  }
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    let loaded = load(physical_program, mode~).unwrap()
    let instance = loaded.new_instance().unwrap()
    assert_true(instance.execute() is Err(EngineTrap(detail=_)))
  }
}

///|
test "packed direct call transfers environment ownership into fatal control" {
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, })),
      owned_slot(I64, OwnedCallable),
    ],
    instructions=[
      MakeEnv({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
      MakeClosure({ value: 1, }, { value: 2, }, { value: 0, }),
      CallPackedDirect({ value: 2, }, { value: 1, }, [], [], None),
    ],
  )
  let target : @physical.FunctionBody = {
    slots: [
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0, })),
      owned_slot(I32, OwnedRef),
    ],
    inputs: {
      environment: Some({ value: 0, }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          Release({ value: 0, }),
          ConstString({ value: 1, }, { value: 0, }),
        ],
        terminator: Fatal,
      },
    ],
  }
  let physical_program = {
    ..image([PhysicalBody(entry), PhysicalBody(target)]),
    layouts: [Environment({ value: 0, }), ByteSequence],
    object_shapes: [Environment({ stored_witness_count: 0, members: [], })],
    constants: [b"packed fatal"],
  }
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    let loaded = load(physical_program, mode~).unwrap()
    let instance = loaded.new_instance().unwrap()
    assert_true(instance.execute() is Err(EngineTrap(_)))
  }
}

///|
test "static image materializes layout descriptors and immortal strings" {
  let entry : @physical.FunctionBody = {
    slots: [
      owned_slot(I32, OwnedRef),
      trivial_slot(I64),
      trivial_slot(I64),
      trivial_slot(I32),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          ByteSequenceLength({ value: 1, }, { value: 0, }),
          Release({ value: 0, }),
          ConstI64({ value: 2, }, 3L),
          I64Eq({ value: 3, }, { value: 1, }, { value: 2, }),
        ],
        terminator: BranchBool({ value: 3, }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"abc"],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_eq(wasm_module.memories[0].limits.min, 1L)
  assert_eq(wasm_module.datas[0].init.length(), 88)
  assert_eq(wasm_module.globals[0].init, [I32Const(8)])
  assert_eq(wasm_module.globals[1].init, [I32Const(88)])
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  let memory = store.get_mem(instance.mem_addrs[0])
  assert_eq(memory.load_i32(72), -1)
  assert_eq(memory.load_i32(76), 1)
  assert_eq(memory.load_i32(80), 3)
  assert_eq(memory.read_bytes(84, 3), b"abc")
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "ByteSequence instructions require the shared layout" {
  let entry = body(slots=[owned_slot(I32, OwnedRef), trivial_slot(I64)], instructions=[
    ConstString({ value: 0, }, { value: 0, }),
    ByteSequenceLength({ value: 1, }, { value: 0, }),
    Release({ value: 0, }),
  ])
  let error = match
    compile_test_image({
      entry: { value: 1, },
      initializer: None,
      data_family_count: 0,
      callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
      globals: [],
      functions: [PhysicalBody(entry)],
      layouts: [],
      object_shapes: [],
      constants: [b"a"],
    }) {
    Err(error) => error
    Ok(_) => fail("expected missing ByteSequence layout")
  }
  assert_eq(error, MissingByteSequenceLayout)
}

///|
test "fieldless data construction reuses an immortal static singleton" {
  let owned_ref = owned_slot(I32, OwnedRef, kind=DataValue({ value: 0, }))
  let entry = body(slots=[owned_ref], instructions=[
    MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
    Release({ value: 0, }),
    MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
    Release({ value: 0, }),
  ])
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 7,
        stored_witness_count: 0,
        members: [],
      }),
    ],
    constants: [],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  let heap_base = store.get_global(instance.global_addrs[1]).get()
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
  assert_eq(store.get_global(instance.global_addrs[2]).get(), heap_base)
  guard heap_base is I32(heap_base) else { fail("expected wasm32 heap base") }
  let memory = store.get_mem(instance.mem_addrs[0])
  assert_eq(memory.load_i32(heap_base - 16), -1)
  assert_eq(memory.load_i32(heap_base - 8), 7)
}

///|
test "dynamic String primitives allocate, copy, compare, and release" {
  let ref_slot = owned_slot(I32, OwnedRef)
  let slots = [
    ref_slot,
    ref_slot,
    ref_slot,
    ref_slot,
    ref_slot,
    ref_slot,
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I32),
  ]
  let entry : @physical.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0, }, { value: 0, }),
          ConstString({ value: 1, }, { value: 1, }),
          ByteSequenceConcat({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstString({ value: 3, }, { value: 2, }),
          ByteSequenceEqual({ value: 8, }, { value: 2, }, { value: 3, }),
          Release({ value: 3, }),
        ],
        terminator: BranchBool({ value: 8, }, edge(1), edge(3)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 6, }, 1L),
          ConstI64({ value: 7, }, 2L),
          ByteSequenceSlice({ value: 4, }, { value: 2, }, { value: 6, }, {
            value: 7,
          }),
          ConstString({ value: 5, }, { value: 3, }),
          ByteSequenceEqual({ value: 8, }, { value: 4, }, { value: 5, }),
          Release({ value: 5, }),
        ],
        terminator: BranchBool({ value: 8, }, edge(2), edge(3)),
      },
      {
        parameters: [],
        instructions: [Release({ value: 4, })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"ab", b"cd", b"abcd", b"bc"],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
  debug_inspect(runtime_service_exports(wasm_module), content="[]")
}

///|
test "canonical Data and Environment layouts construct and project" {
  let data_slot = owned_slot(I32, OwnedRef, kind=DataValue({ value: 0, }))
  let environment_slot = owned_slot(
    I32,
    OwnedRef,
    kind=EnvironmentValue({ value: 1, }),
  )
  let slots = [
    data_slot,
    trivial_slot(I64),
    trivial_slot(I32),
    trivial_slot(I32),
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I32),
    environment_slot,
    trivial_slot(I64),
    trivial_slot(I64),
  ]
  let entry : @physical.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 1, }, 42L),
          MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], [
            { value: 1, },
          ]),
          LoadTag({ value: 2, }, { value: 0, }),
          ConstBool({ value: 3, }, true),
          BoolEq({ value: 6, }, { value: 2, }, { value: 3, }),
        ],
        terminator: BranchBool({ value: 6, }, edge(1), edge(4)),
      },
      {
        parameters: [],
        instructions: [
          BorrowField({ value: 0, }, { value: 0, }, 0, {
            value_destination: { value: 4, },
            witness_destination: None,
          }),
          ConstI64({ value: 5, }, 42L),
          I64Eq({ value: 6, }, { value: 4, }, { value: 5, }),
          Release({ value: 0, }),
        ],
        terminator: BranchBool({ value: 6, }, edge(2), edge(4)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 8, }, 99L),
          MakeEnv({ value: 7, }, { value: 1, }, Immediate({ value: 2, }), [], [
            { value: 8, },
          ]),
          BorrowCapture({ value: 1, }, { value: 7, }, 0, {
            value_destination: { value: 9, },
            witness_destination: None,
          }),
          ConstI64({ value: 5, }, 99L),
          I64Eq({ value: 6, }, { value: 9, }, { value: 5, }),
          Release({ value: 7, }),
        ],
        terminator: BranchBool({ value: 6, }, edge(3), edge(4)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  let shapes : Array[@physical.ObjectShape] = [
    Data({
      family: { value: 0, },
      constructor_tag: 1,
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
  ]
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [Data({ value: 0, }), Environment({ value: 1, })],
    object_shapes: shapes,
    constants: [],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  let memory = store.get_mem(instance.mem_addrs[0])
  assert_eq(memory.load_i32(48), 24)
  assert_eq(memory.load_i32(80), 16)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "descriptor destructors preserve owners across consuming projection" {
  let inner_slot = owned_slot(I32, OwnedRef, kind=DataValue({ value: 0, }))
  let outer_slot = owned_slot(I32, OwnedRef, kind=DataValue({ value: 1, }))
  let entry = body(slots=[inner_slot, outer_slot, outer_slot, inner_slot], instructions=[
    MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], []),
    MakeData({ value: 1, }, { value: 1, }, Immediate({ value: 2, }), [], [
      { value: 0, },
    ]),
    RetainCopy({ value: 2, }, { value: 1, }),
    ConsumeFields({ value: 1, }, { value: 1, }, [
      {
        member_index: 0,
        result: { value_destination: { value: 3, }, witness_destination: None, },
      },
    ]),
    Release({ value: 2, }),
    Release({ value: 3, }),
  ])
  let shapes : Array[@physical.ObjectShape] = [
    Data({
      family: { value: 0, },
      constructor_tag: 0,
      stored_witness_count: 0,
      members: [],
    }),
    Data({
      family: { value: 1, },
      constructor_tag: 0,
      stored_witness_count: 0,
      members: [
        {
          representation: I32,
          cleanup: OwnedRef,
          kind: DataValue({ value: 0, }),
          witness_ordinal: None,
        },
      ],
    }),
  ]
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 2,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [Data({ value: 0, }), Data({ value: 1, })],
    object_shapes: shapes,
    constants: [],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
  assert_true(
    store.get_global(instance.global_addrs[3]).get() is I32(head) && head != 0,
  )
}

///|
test "Wasm loads an object witness independently from members" {
  let entry : @physical.FunctionBody = {
    slots: [
      trivial_slot(I32, kind=LayoutValue),
      owned_slot(I32, OwnedRef, kind=DataValue({ value: 0, })),
      trivial_slot(I32, kind=LayoutValue),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [], },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0, }, { value: 1, }),
          MakeData(
            { value: 1, },
            { value: 0, },
            Immediate({ value: 2, }),
            [{ value: 0, }],
            [],
          ),
          LoadObjectWitness({ value: 2, }, { value: 0, }, { value: 1, }, 0),
          Release({ value: 1, }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [Bool, Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
        stored_witness_count: 1,
        members: [],
      }),
    ],
    constants: [],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
}

///|
test "OwnedErased ARC dispatches through its layout witness" {
  let erased_slot : @physical.SlotMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    erased_companion: Some({ value: 1, }),
  }
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=DataValue({ value: 0, })),
      trivial_slot(I32, kind=LayoutValue),
      erased_slot,
      erased_slot,
      trivial_slot(I64),
    ],
    instructions=[
      ConstI64({ value: 4, }, 42L),
      MakeData({ value: 0, }, { value: 0, }, Immediate({ value: 1, }), [], [
        { value: 4, },
      ]),
      ConstLayout({ value: 1, }, { value: 1, }),
      EraseI32({ value: 2, }, { value: 0, }),
      RetainCopy({ value: 3, }, { value: 2, }),
      Release({ value: 2, }),
      Release({ value: 3, }),
    ],
  )
  let physical_program : @physical.PhysicalProgram = {
    entry: { value: 1, },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witnesses: [], parameters: [], result: Unit, }],
    globals: [],
    functions: [PhysicalBody(entry)],
    layouts: [Data({ value: 0, })],
    object_shapes: [
      Data({
        family: { value: 0, },
        constructor_tag: 0,
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
    constants: [],
  }
  let wasm_module = match compile_test_image(physical_program) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "_start", []), [])
  assert_true(
    store.get_global(instance.global_addrs[3]).get() is I32(head) && head != 0,
  )
}

///|
test "Wasmoon execution can be interrupted at a Wasm safepoint" {
  let entry = body(terminator=TailCallDirect({ value: 1, }, None, [], []))
  let loaded = match load(image([PhysicalBody(entry)])) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  let polls = [0]
  assert_eq(
    instance.execute(
      cancel=Some(fn() {
        polls[0] += 1
        polls[0] >= 4
      }),
    ),
    Err(Interrupted),
  )
  assert_eq(instance.execute(), Err(InstanceNotReady))
}

///|
