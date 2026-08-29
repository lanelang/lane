// `module_to_wat` renders the same `Module` that `@wasm_encoder` turns into the
// bytes an engine runs, so its output has to be that module. Checking only that
// the text parses lets a printer that drops or reorders instructions pass, and
// the IR explorer then shows a module nobody executes.

///|
/// Prints the module, reads the text back, and validates the result.
///
/// `compile` validates before publication, so the input module is known good.
/// Any validation failure here is the printer's.
fn assert_wat_round_trips(
  image_ : @physical.PhysicalProgram,
  label : String,
) -> Unit raise {
  let module_ = match
    @wasm_target.compile(certify_physical_program_test(image_)) {
    Ok(module_) => module_
    Err(error) => fail("\{label}: compile failed: \{Repr(error)}")
  }
  assert_module_wat_round_trips(module_, label)
}

///|
fn assert_module_wat_round_trips(
  module_ : @wasm_types.Module,
  label : String,
) -> Unit raise {
  round_trip_wat(module_, label) |> ignore
}

///|
fn round_trip_wat(
  module_ : @wasm_types.Module,
  label : String,
) -> @wasm_types.Module raise {
  let wat = @wasm_target.module_to_wat(module_)
  let reparsed = @wat.parse(wat) catch {
    error =>
      fail(
        "\{label}: printed text is not WAT: \{@wat.format_wat_error(error, wat)}",
      )
  }
  @validator.validate_module(reparsed) catch {
    error =>
      fail(
        "\{label}: printed text is not the compiled module: \{@validator.format_validation_error(error)}",
      )
  }
  reparsed
}

///|
test "printed WAT round-trips for a minimal module" {
  assert_wat_round_trips(image([PhysicalBody(body())]), "minimal")
}

///|
test "printed WAT round-trips for boolean branches" {
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
  assert_wat_round_trips(image([PhysicalBody(branch_body)]), "branch_bool")
}

///|
test "printed WAT round-trips for dense tag switches" {
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
  assert_wat_round_trips(image([PhysicalBody(switch_body)]), "switch_tag")
}

///|
test "printed WAT round-trips for reducible loops" {
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
  assert_wat_round_trips(image([PhysicalBody(loop_body)]), "loop")
}

///|
test "printed WAT round-trips for a direct call" {
  let caller = body(instructions=[CallDirect({ value: 1, }, None, [], [], None)])
  assert_wat_round_trips(
    image([PhysicalBody(caller), PhysicalBody(body())]),
    "call_direct",
  )
}

///|
test "printed WAT round-trips for emitted F32 and conversion operations" {
  let module_ = {
    ..@wasm_types.Module::empty(),
    types: [@wasm_types.SubType::from_func({ params: [], results: [], })],
    type_rec_groups: [0],
    funcs: [0],
    memories: [
      {
        limits: { min: 1L, max: Some(1L), },
        is_memory64: false,
        page_size_log2: 16,
      },
    ],
    codes: [
      {
        locals: [F32, F64, I32, I64],
        body: [
          F32Const(Float::reinterpret_from_int(0x7fc00001)),
          LocalSet(0),
          F64Const(0xfff8000000000001UL.reinterpret_as_double()),
          LocalSet(1),
          I32Const(0),
          LocalGet(0),
          F32Store(0, 2, 0L),
          I32Const(0),
          F32Load(0, 2, 0L),
          LocalSet(0),
          LocalGet(0),
          LocalGet(0),
          F32Add,
          LocalSet(0),
          LocalGet(0),
          LocalGet(0),
          F32Sub,
          LocalSet(0),
          LocalGet(0),
          LocalGet(0),
          F32Mul,
          LocalSet(0),
          LocalGet(0),
          LocalGet(0),
          F32Div,
          LocalSet(0),
          LocalGet(0),
          F32Neg,
          LocalSet(0),
          LocalGet(0),
          LocalGet(0),
          F32Eq,
          LocalSet(2),
          LocalGet(0),
          LocalGet(0),
          F32Ne,
          LocalSet(2),
          LocalGet(0),
          LocalGet(0),
          F32Lt,
          LocalSet(2),
          LocalGet(0),
          LocalGet(0),
          F32Le,
          LocalSet(2),
          LocalGet(0),
          LocalGet(0),
          F32Gt,
          LocalSet(2),
          LocalGet(0),
          LocalGet(0),
          F32Ge,
          LocalSet(2),
          LocalGet(3),
          F32ConvertI64S,
          LocalSet(0),
          LocalGet(0),
          I64TruncF32S,
          LocalSet(3),
          LocalGet(1),
          F32DemoteF64,
          LocalSet(0),
          LocalGet(0),
          F64PromoteF32,
          LocalSet(1),
          LocalGet(0),
          I32ReinterpretF32,
          LocalSet(2),
          LocalGet(2),
          F32ReinterpretI32,
          LocalSet(0),
          I32Const(4),
          I32Const(2),
          I32DivS,
          LocalSet(2),
          I32Const(4),
          I32Const(2),
          I32RemS,
          LocalSet(2),
          I32Const(1),
          I32Const(2),
          I32LtS,
          LocalSet(2),
        ],
      },
    ],
  }
  let wat = @wasm_target.module_to_wat(module_)
  assert_false(wat.contains("unsupported.instruction"))
  let reparsed = round_trip_wat(module_, "emitted_f32_operations")
  guard reparsed.codes[0].body[0] is F32Const(f32_nan) else {
    fail("expected the F32 NaN constant to survive WAT parsing")
  }
  assert_eq(f32_nan.reinterpret_as_int(), 0x7fc00001)
  guard reparsed.codes[0].body[2] is F64Const(f64_nan) else {
    fail("expected the F64 NaN constant to survive WAT parsing")
  }
  assert_eq(
    f64_nan.reinterpret_as_int64(),
    0xfff8000000000001UL.reinterpret_as_int64(),
  )
}
