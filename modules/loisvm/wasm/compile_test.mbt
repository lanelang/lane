///|
fn trivial_slot(
  representation : @bytecode.Representation,
  kind? : @bytecode.SemanticValueKind = ScalarValue,
) -> @bytecode.SlotMetadata {
  { representation, cleanup: Trivial, kind, erased_companion: None }
}

///|
fn owned_slot(
  representation : @bytecode.Representation,
  cleanup : @bytecode.Cleanup,
  kind? : @bytecode.SemanticValueKind = match cleanup {
    OwnedCallable => CallableValue
    OwnedRef => ByteSequenceValue
    OwnedErased => ErasedValue
    Trivial => ScalarValue
  },
) -> @bytecode.SlotMetadata {
  { representation, cleanup, kind, erased_companion: None }
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
fn body(
  slots? : Array[@bytecode.SlotMetadata] = [],
  parameters? : Array[@bytecode.SlotId] = [],
  result? : @bytecode.ResultAbi = Unit,
  instructions? : Array[@bytecode.Instruction] = [],
  terminator? : @bytecode.Terminator = Return(None),
) -> @bytecode.FunctionBody {
  {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: parameters },
    result,
    blocks: [{ parameters: [], instructions, terminator }],
  }
}

///|
fn image(functions : Array[@bytecode.FunctionEntry]) -> @bytecode.BytecodeImage {
  let callable_abis : Array[@bytecode.CallableAbi] = []
  for entry in functions {
    if entry.callable_abi() is Some(abi) && !callable_abis.contains(abi) {
      callable_abis.push(abi)
    }
  }
  {
    entry: { value: 1 },
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
fn edge(
  target : Int,
  arguments? : Array[@bytecode.SlotId] = [],
) -> @bytecode.Edge {
  { target: { value: target }, arguments }
}

///|
fn run_entry(body : @bytecode.FunctionBody) -> Unit raise {
  let wasm_module = match compile(image([BytecodeBody(body)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "compiled scalar bytecode executes with Wasmoon" {
  let entry = body(slots=[trivial_slot(I64)], instructions=[
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
  ])
  let target = body(
    slots=[trivial_slot(I64), trivial_slot(I64), trivial_slot(I64)],
    result=Value(I64, Trivial, ScalarValue),
    instructions=[
      ConstI64({ value: 0 }, 40L),
      ConstI64({ value: 1 }, 2L),
      I64Add({ value: 2 }, { value: 0 }, { value: 1 }),
    ],
    terminator=Return(Some({ value: 2 })),
  )
  let wasm_module = match
    compile(image([BytecodeBody(entry), BytecodeBody(target)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "compiled tail calls use Wasmoon tail-call support" {
  assert_true(@wasmoon_runtime.supports_tail_call())
  let entry = body(terminator=TailCallDirect({ value: 2 }, None, [], []))
  let target = body()
  let wasm_module = match
    compile(image([BytecodeBody(entry), BytecodeBody(target)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_return_call(wasm_module.codes[0].body, 1))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "runtime imports compile from bytecode descriptors" {
  let import_ : @bytecode.RuntimeImport = {
    abi_major: 1,
    parameters: [Opaque],
    result: Opaque,
    symbol: "lane.test",
  }
  let bytecode = {
    ..image([BytecodeBody(body()), RuntimeImport(import_)]),
    layouts: [Reference],
  }
  assert_eq(@compiler.physical_runtime_parameters_for_import(import_), [I64])
  assert_eq(@compiler.runtime_results_for_import(import_), [I32])
  assert_true(
    compile(image([BytecodeBody(body()), RuntimeImport(import_)]))
    is Err(
      ValidationFailure(
        detail="Opaque runtime imports require a Reference layout"
      )
    ),
  )
  assert_true(compile(bytecode) is Ok(_))
}

///|
test "invalid Bytecode is rejected before Wasm publication" {
  let invalid_entry = body(instructions=[
    CallDirect({ value: 2 }, None, [], [], None),
  ])
  let target = body(slots=[trivial_slot(I64)], parameters=[{ value: 0 }])
  assert_true(
    compile(image([BytecodeBody(invalid_entry), BytecodeBody(target)]))
    is Err(InvalidBytecode(_)),
  )
}

///|
test "Wasm compiler rejects call result ownership mismatch" {
  let caller = body(slots=[owned_slot(I32, OwnedRef)], instructions=[
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    Release({ value: 0 }),
  ])
  let target = body(
    slots=[trivial_slot(I32)],
    result=Value(I32, Trivial, ScalarValue),
    instructions=[ConstI32({ value: 0 }, 42)],
    terminator=Return(Some({ value: 0 })),
  )
  let error = match
    compile(image([BytecodeBody(caller), BytecodeBody(target)])) {
    Ok(_) => None
    Err(error) => Some(error)
  }
  assert_eq(
    error,
    Some(
      InvalidBytecode(
        InvalidBytecode(
          site=Instruction({ value: 1 }, { value: 0 }, 0),
          detail="call result ABI does not match destination slot",
        ),
      ),
    ),
  )
}

///|
test "structured CFG executes boolean branches and dense tag switches" {
  let branch_body : @bytecode.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, true)],
        terminator: BranchBool({ value: 0 }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  let branch_module = match compile(image([BytecodeBody(branch_body)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_false(contains_br_table(branch_module.codes[0].body))
  let (branch_store, branch_instance) = @executor.instantiate_module_with_init(
    branch_module,
  )
  assert_eq(
    @executor.call_exported_func(branch_store, branch_instance, "lane.entry", []),
    [],
  )
  let switch_body : @bytecode.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, true)],
        terminator: SwitchTag({ value: 0 }, [edge(2), edge(1)], edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  run_entry(switch_body)
}

///|
test "reducible loops use Wasm loop control" {
  let loop_body : @bytecode.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      { parameters: [], instructions: [], terminator: Jump(edge(1)) },
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, false)],
        terminator: BranchBool({ value: 0 }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
    ],
  }
  let wasm_module = match compile(image([BytecodeBody(loop_body)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_loop(wasm_module.codes[0].body))
  assert_false(contains_br_table(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "nested reducible loops preserve structured branch depths" {
  let nested : @bytecode.FunctionBody = {
    slots: [trivial_slot(I32), trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, true)],
        terminator: Jump(edge(1)),
      },
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 0 }, edge(2), edge(6)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 1 }, true)],
        terminator: Jump(edge(3)),
      },
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 1 }, edge(4), edge(5)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 1 }, false)],
        terminator: Jump(edge(3)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, false)],
        terminator: Jump(edge(1)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
    ],
  }
  let wasm_module = match compile(image([BytecodeBody(nested)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_loop(wasm_module.codes[0].body))
  assert_false(contains_br_table(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "irreducible CFG uses the dispatcher fallback" {
  let irreducible : @bytecode.FunctionBody = {
    slots: [trivial_slot(I32)],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, true)],
        terminator: BranchBool({ value: 0 }, edge(1), edge(2)),
      },
      {
        parameters: [],
        instructions: [ConstBool({ value: 0 }, false)],
        terminator: Jump(edge(2)),
      },
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 0 }, edge(1), edge(3)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
    ],
  }
  let wasm_module = match compile(image([BytecodeBody(irreducible)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_br_table(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "structured CFG transfers block arguments in parallel" {
  let slots = [
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I32),
  ]
  let cfg_body : @bytecode.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [ConstI64({ value: 0 }, 1L), ConstI64({ value: 1 }, 2L)],
        terminator: Jump(edge(1, arguments=[{ value: 1 }, { value: 0 }])),
      },
      {
        parameters: [{ value: 0 }, { value: 1 }],
        instructions: [
          ConstI64({ value: 2 }, 2L),
          I64Eq({ value: 3 }, { value: 0 }, { value: 2 }),
        ],
        terminator: BranchBool({ value: 3 }, edge(2), edge(4)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 2 }, 1L),
          I64Eq({ value: 3 }, { value: 1 }, { value: 2 }),
        ],
        terminator: BranchBool({ value: 3 }, edge(3), edge(4)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  run_entry(cfg_body)
}

///|
test "packed callables execute through the canonical function table" {
  let entry = body(
    slots=[owned_slot(I64, OwnedCallable), trivial_slot(I64), trivial_slot(I64)],
    instructions=[
      ConstFunction({ value: 0 }, { value: 2 }),
      ConstI64({ value: 1 }, 42L),
      CallValue(
        { value: 0 },
        { value: 1 },
        [],
        [{ value: 1 }],
        Some({ value: 2 }),
      ),
    ],
  )
  let identity = body(
    slots=[trivial_slot(I64)],
    parameters=[{ value: 0 }],
    result=Value(I64, Trivial, ScalarValue),
    terminator=Return(Some({ value: 0 })),
  )
  let wasm_module = match
    compile(image([BytecodeBody(entry), BytecodeBody(identity)])) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "packed callable ownership ABI mismatch traps in both Wasm modes" {
  let entry = body(slots=[owned_slot(I64, OwnedCallable), trivial_slot(I32)], instructions=[
    ConstFunction({ value: 0 }, { value: 2 }),
    ConstBool({ value: 1 }, true),
    CallValue({ value: 0 }, { value: 1 }, [], [{ value: 1 }], None),
  ])
  let target = body(
    slots=[owned_slot(I32, OwnedRef)],
    parameters=[{ value: 0 }],
    instructions=[Release({ value: 0 })],
  )
  let bytecode_image = {
    ..image([BytecodeBody(entry), BytecodeBody(target)]),
    callable_abis: [
      { witness_count: 0, parameters: [], result: Unit },
      {
        witness_count: 0,
        parameters: [
          { representation: I32, cleanup: Trivial, kind: ScalarValue },
        ],
        result: Unit,
      },
      {
        witness_count: 0,
        parameters: [
          { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
        ],
        result: Unit,
      },
    ],
  }
  for mode in [ExecutionMode::Interpreter, Jit] {
    let loaded = match
      load(bytecode_image, @loisvm_runtime.RuntimeRegistry::new(), mode~) {
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
      owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0 })),
      owned_slot(I64, OwnedCallable),
    ],
    instructions=[
      MakeEnv({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
      MakeClosure({ value: 1 }, { value: 2 }, { value: 0 }),
    ],
    terminator=TailCallValue({ value: 1 }, { value: 0 }, [], []),
  )
  let target : @bytecode.FunctionBody = {
    slots: [owned_slot(I32, OwnedRef, kind=EnvironmentValue({ value: 0 }))],
    inputs: {
      environment: Some({ value: 0 }),
      witnesses: [],
      user_parameters: [],
    },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [Release({ value: 0 })],
        terminator: Return(None),
      },
    ],
  }
  let bytecode_image = {
    ..image([BytecodeBody(entry), BytecodeBody(target)]),
    layouts: [Environment({ value: 0 })],
    object_shapes: [Environment({ stored_witness_count: 0, members: [] })],
  }
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  assert_true(contains_return_call_indirect(wasm_module.codes[0].body))
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "static image materializes layout descriptors and immortal strings" {
  let entry : @bytecode.FunctionBody = {
    slots: [
      owned_slot(I32, OwnedRef),
      trivial_slot(I64),
      trivial_slot(I64),
      trivial_slot(I32),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0 }, { value: 0 }),
          ByteSequenceLength({ value: 1 }, { value: 0 }),
          Release({ value: 0 }),
          ConstI64({ value: 2 }, 3L),
          I64Eq({ value: 3 }, { value: 1 }, { value: 2 }),
        ],
        terminator: BranchBool({ value: 3 }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"abc"],
  }
  let wasm_module = match compile(bytecode_image) {
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
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "ByteSequence instructions require the shared layout" {
  let entry = body(slots=[owned_slot(I32, OwnedRef), trivial_slot(I64)], instructions=[
    ConstString({ value: 0 }, { value: 0 }),
    ByteSequenceLength({ value: 1 }, { value: 0 }),
    Release({ value: 0 }),
  ])
  let error = match
    compile({
      entry: { value: 1 },
      initializer: None,
      data_family_count: 0,
      callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
      globals: [],
      functions: [BytecodeBody(entry)],
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
  let owned_ref = owned_slot(I32, OwnedRef, kind=DataValue({ value: 0 }))
  let entry = body(slots=[owned_ref], instructions=[
    MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
    Release({ value: 0 }),
    MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
    Release({ value: 0 }),
  ])
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({
        family: { value: 0 },
        constructor_tag: 7,
        stored_witness_count: 0,
        members: [],
      }),
    ],
    constants: [],
  }
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  let heap_base = store.get_global(instance.global_addrs[1]).get()
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
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
  let entry : @bytecode.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstString({ value: 0 }, { value: 0 }),
          ConstString({ value: 1 }, { value: 1 }),
          ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
          ConstString({ value: 3 }, { value: 2 }),
          ByteSequenceEqual({ value: 8 }, { value: 2 }, { value: 3 }),
          Release({ value: 3 }),
        ],
        terminator: BranchBool({ value: 8 }, edge(1), edge(3)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 6 }, 1L),
          ConstI64({ value: 7 }, 2L),
          ByteSequenceSlice({ value: 4 }, { value: 2 }, { value: 6 }, {
            value: 7,
          }),
          ConstString({ value: 5 }, { value: 3 }),
          ByteSequenceEqual({ value: 8 }, { value: 4 }, { value: 5 }),
          Release({ value: 5 }),
        ],
        terminator: BranchBool({ value: 8 }, edge(2), edge(3)),
      },
      {
        parameters: [],
        instructions: [Release({ value: 4 })],
        terminator: Return(None),
      },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"ab", b"cd", b"abcd", b"bc"],
  }
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
  let allocated = @executor.call_exported_func(
    store,
    instance,
    "lane.runtime.string.new",
    [I32(3)],
  )
  guard allocated is [I32(reference)] else { fail("expected String reference") }
  let memory = store.get_mem(instance.mem_addrs[0])
  assert_eq(memory.load_i32(reference), 1)
  assert_eq(memory.load_i32(reference + 4), 1)
  assert_eq(memory.load_i32(reference + 8), 3)
}

///|
test "canonical Data and Environment layouts construct and project" {
  let data_slot = owned_slot(I32, OwnedRef, kind=DataValue({ value: 0 }))
  let environment_slot = owned_slot(
    I32,
    OwnedRef,
    kind=EnvironmentValue({ value: 1 }),
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
  let entry : @bytecode.FunctionBody = {
    slots,
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 1 }, 42L),
          MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], [
            { value: 1 },
          ]),
          LoadTag({ value: 2 }, { value: 0 }),
          ConstBool({ value: 3 }, true),
          BoolEq({ value: 6 }, { value: 2 }, { value: 3 }),
        ],
        terminator: BranchBool({ value: 6 }, edge(1), edge(4)),
      },
      {
        parameters: [],
        instructions: [
          BorrowField({ value: 0 }, { value: 0 }, 0, {
            value_destination: { value: 4 },
            witness_destination: None,
          }),
          ConstI64({ value: 5 }, 42L),
          I64Eq({ value: 6 }, { value: 4 }, { value: 5 }),
          Release({ value: 0 }),
        ],
        terminator: BranchBool({ value: 6 }, edge(2), edge(4)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 8 }, 99L),
          MakeEnv({ value: 7 }, { value: 1 }, Immediate({ value: 2 }), [], [
            { value: 8 },
          ]),
          BorrowCapture({ value: 1 }, { value: 7 }, 0, {
            value_destination: { value: 9 },
            witness_destination: None,
          }),
          ConstI64({ value: 5 }, 99L),
          I64Eq({ value: 6 }, { value: 9 }, { value: 5 }),
          Release({ value: 7 }),
        ],
        terminator: BranchBool({ value: 6 }, edge(3), edge(4)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  let shapes : Array[@bytecode.ObjectShape] = [
    Data({
      family: { value: 0 },
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
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 }), Environment({ value: 1 })],
    object_shapes: shapes,
    constants: [],
  }
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  let memory = store.get_mem(instance.mem_addrs[0])
  assert_eq(memory.load_i32(48), 24)
  assert_eq(memory.load_i32(80), 16)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "descriptor destructors preserve owners across consuming projection" {
  let inner_slot = owned_slot(I32, OwnedRef, kind=DataValue({ value: 0 }))
  let outer_slot = owned_slot(I32, OwnedRef, kind=DataValue({ value: 1 }))
  let entry = body(slots=[inner_slot, outer_slot, outer_slot, inner_slot], instructions=[
    MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], []),
    MakeData({ value: 1 }, { value: 1 }, Immediate({ value: 2 }), [], [
      { value: 0 },
    ]),
    RetainCopy({ value: 2 }, { value: 1 }),
    ConsumeFields({ value: 1 }, { value: 1 }, [
      {
        member_index: 0,
        result: { value_destination: { value: 3 }, witness_destination: None },
      },
    ]),
    Release({ value: 2 }),
    Release({ value: 3 }),
  ])
  let shapes : Array[@bytecode.ObjectShape] = [
    Data({
      family: { value: 0 },
      constructor_tag: 0,
      stored_witness_count: 0,
      members: [],
    }),
    Data({
      family: { value: 1 },
      constructor_tag: 0,
      stored_witness_count: 0,
      members: [
        {
          representation: I32,
          cleanup: OwnedRef,
          kind: DataValue({ value: 0 }),
          witness_ordinal: None,
        },
      ],
    }),
  ]
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 2,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 }), Data({ value: 1 })],
    object_shapes: shapes,
    constants: [],
  }
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
  assert_true(
    store.get_global(instance.global_addrs[3]).get() is I32(head) && head != 0,
  )
}

///|
test "Wasm loads an object witness independently from members" {
  let entry : @bytecode.FunctionBody = {
    slots: [
      trivial_slot(I32, kind=LayoutValue),
      owned_slot(I32, OwnedRef, kind=DataValue({ value: 0 })),
      trivial_slot(I32, kind=LayoutValue),
    ],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstLayout({ value: 0 }, { value: 1 }),
          MakeData(
            { value: 1 },
            { value: 0 },
            Immediate({ value: 2 }),
            [{ value: 0 }],
            [],
          ),
          LoadObjectWitness({ value: 2 }, { value: 0 }, { value: 1 }, 0),
          Release({ value: 1 }),
        ],
        terminator: Return(None),
      },
    ],
  }
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Bool, Data({ value: 0 })],
    object_shapes: [
      Data({
        family: { value: 0 },
        constructor_tag: 0,
        stored_witness_count: 1,
        members: [],
      }),
    ],
    constants: [],
  }
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
}

///|
test "OwnedErased ARC dispatches through its layout witness" {
  let erased_slot : @bytecode.SlotMetadata = {
    representation: I64,
    cleanup: OwnedErased,
    kind: ErasedValue,
    erased_companion: Some({ value: 1 }),
  }
  let entry = body(
    slots=[
      owned_slot(I32, OwnedRef, kind=DataValue({ value: 0 })),
      trivial_slot(I32, kind=LayoutValue),
      erased_slot,
      erased_slot,
      trivial_slot(I64),
    ],
    instructions=[
      ConstI64({ value: 4 }, 42L),
      MakeData({ value: 0 }, { value: 0 }, Immediate({ value: 1 }), [], [
        { value: 4 },
      ]),
      ConstLayout({ value: 1 }, { value: 1 }),
      EraseI32({ value: 2 }, { value: 0 }),
      RetainCopy({ value: 3 }, { value: 2 }),
      Release({ value: 2 }),
      Release({ value: 3 }),
    ],
  )
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 1,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [Data({ value: 0 })],
    object_shapes: [
      Data({
        family: { value: 0 },
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
  let wasm_module = match compile(bytecode_image) {
    Ok(value) => value
    Err(error) => fail("compile failed: \{Repr(error)}")
  }
  let (store, instance) = @executor.instantiate_module_with_init(wasm_module)
  assert_eq(@executor.call_exported_func(store, instance, "lane.entry", []), [])
  assert_true(
    store.get_global(instance.global_addrs[3]).get() is I32(head) && head != 0,
  )
}

///|
test "Wasm returning calls enforce logical depth while tail calls preserve it" {
  let returning_entry = body(instructions=[
    CallDirect({ value: 2 }, None, [], [], None),
  ])
  let target = body()
  let returning_loaded = match
    load(
      image([BytecodeBody(returning_entry), BytecodeBody(target)]),
      @loisvm_runtime.RuntimeRegistry::new(),
    ) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let returning_instance = match
    returning_loaded.new_instance(config={
      max_call_depth: Some(1),
      max_live_heap_bytes: None,
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  assert_eq(
    returning_instance.execute(),
    Err(ExecutionResourceLimit(kind=CallDepth)),
  )
  let tail_entry = body(terminator=TailCallDirect({ value: 2 }, None, [], []))
  let tail_loaded = match
    load(
      image([BytecodeBody(tail_entry), BytecodeBody(target)]),
      @loisvm_runtime.RuntimeRegistry::new(),
    ) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let tail_instance = match
    tail_loaded.new_instance(config={
      max_call_depth: Some(1),
      max_live_heap_bytes: None,
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  assert_eq(tail_instance.execute(), Ok(()))
}

///|
test "Wasmoon execution can be interrupted at a Wasm safepoint" {
  let entry = body(terminator=TailCallDirect({ value: 1 }, None, [], []))
  let loaded = match
    load(image([BytecodeBody(entry)]), @loisvm_runtime.RuntimeRegistry::new()) {
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
test "call depth exhaustion releases arguments transferred into the callee" {
  let ref_slot = owned_slot(I32, OwnedRef)
  let entry = body(slots=[ref_slot, ref_slot, ref_slot], instructions=[
    ConstString({ value: 0 }, { value: 0 }),
    ConstString({ value: 1 }, { value: 1 }),
    ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
    CallDirect({ value: 2 }, None, [], [{ value: 2 }], None),
  ])
  let target = body(slots=[ref_slot], parameters=[{ value: 0 }], instructions=[
    Release({ value: 0 }),
  ])
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [
      { witness_count: 0, parameters: [], result: Unit },
      {
        witness_count: 0,
        parameters: [
          { representation: I32, cleanup: OwnedRef, kind: ByteSequenceValue },
        ],
        result: Unit,
      },
    ],
    globals: [],
    functions: [BytecodeBody(entry), BytecodeBody(target)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"a", b"b"],
  }
  let loaded = match
    load(bytecode_image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = match
    loaded.new_instance(config={
      max_call_depth: Some(1),
      max_live_heap_bytes: None,
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=CallDepth)))
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "Wasm allocator enforces canonical live heap bytes" {
  let ref_slot = owned_slot(I32, OwnedRef)
  let entry = body(slots=[ref_slot, ref_slot, ref_slot], instructions=[
    ConstString({ value: 0 }, { value: 0 }),
    ConstString({ value: 1 }, { value: 1 }),
    ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
    Release({ value: 2 }),
  ])
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"a", b"b"],
  }
  let loaded = match
    load(bytecode_image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let limited = match
    loaded.new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: Some(8),
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  assert_eq(limited.execute(), Err(ExecutionResourceLimit(kind=LiveHeapBytes)))
  let exact = match
    loaded.new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: Some(16),
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  assert_eq(exact.execute(), Ok(()))
}

///|
test "live heap exhaustion unwinds owners from the current frame" {
  let ref_slot = owned_slot(I32, OwnedRef)
  let entry = body(slots=[ref_slot, ref_slot, ref_slot, ref_slot], instructions=[
    ConstString({ value: 0 }, { value: 0 }),
    ConstString({ value: 1 }, { value: 1 }),
    ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
    ConstString({ value: 0 }, { value: 0 }),
    ConstString({ value: 1 }, { value: 1 }),
    ByteSequenceConcat({ value: 3 }, { value: 0 }, { value: 1 }),
    Release({ value: 2 }),
    Release({ value: 3 }),
  ])
  let bytecode_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"a", b"b"],
  }
  let loaded = match
    load(bytecode_image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  let instance = match
    loaded.new_instance(config={
      max_call_depth: None,
      max_live_heap_bytes: Some(16),
      max_host_objects: None,
    }) {
    Ok(value) => value
    Err(error) => fail("instantiate failed: \{Repr(error)}")
  }
  assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=LiveHeapBytes)))
  assert_eq(
    instance.store.get_global(instance.instance.global_addrs[4]).get(),
    I32(0),
  )
}

///|
test "non-positive execution limits provide zero budget" {
  let empty_loaded = match
    load(image([BytecodeBody(body())]), @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  for limit in [0, -1] {
    let instance = match
      empty_loaded.new_instance(config={
        max_call_depth: Some(limit),
        max_live_heap_bytes: None,
        max_host_objects: None,
      }) {
      Ok(value) => value
      Err(error) => fail("instantiate failed: \{Repr(error)}")
    }
    assert_eq(instance.execute(), Err(ExecutionResourceLimit(kind=CallDepth)))
  }
  let ref_slot = owned_slot(I32, OwnedRef)
  let allocating_entry = body(slots=[ref_slot, ref_slot, ref_slot], instructions=[
    ConstString({ value: 0 }, { value: 0 }),
    ConstString({ value: 1 }, { value: 1 }),
    ByteSequenceConcat({ value: 2 }, { value: 0 }, { value: 1 }),
    Release({ value: 2 }),
  ])
  let allocating_image : @bytecode.BytecodeImage = {
    entry: { value: 1 },
    initializer: None,
    data_family_count: 0,
    callable_abis: [{ witness_count: 0, parameters: [], result: Unit }],
    globals: [],
    functions: [BytecodeBody(allocating_entry)],
    layouts: [ByteSequence],
    object_shapes: [],
    constants: [b"a", b"b"],
  }
  let allocating_loaded = match
    load(allocating_image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  for limit in [0, -1] {
    let instance = match
      allocating_loaded.new_instance(config={
        max_call_depth: None,
        max_live_heap_bytes: Some(limit),
        max_host_objects: None,
      }) {
      Ok(value) => value
      Err(error) => fail("instantiate failed: \{Repr(error)}")
    }
    assert_eq(
      instance.execute(),
      Err(ExecutionResourceLimit(kind=LiveHeapBytes)),
    )
  }
}
