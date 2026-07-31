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
  image_ : @bytecode.BytecodeImage,
  label : String,
) -> Unit raise {
  let module_ = match @compiler.compile(image_) {
    Ok(module_) => module_
    Err(error) => fail("\{label}: compile failed: \{Repr(error)}")
  }
  let wat = @compiler.module_to_wat(module_)
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
}

///|
test "printed WAT round-trips for a minimal module" {
  assert_wat_round_trips(image([BytecodeBody(body())]), "minimal")
}

///|
test "printed WAT round-trips for boolean branches" {
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
  assert_wat_round_trips(image([BytecodeBody(branch_body)]), "branch_bool")
}

///|
test "printed WAT round-trips for dense tag switches" {
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
  assert_wat_round_trips(image([BytecodeBody(switch_body)]), "switch_tag")
}

///|
test "printed WAT round-trips for reducible loops" {
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
  assert_wat_round_trips(image([BytecodeBody(loop_body)]), "loop")
}

///|
test "printed WAT round-trips for a direct call" {
  let caller = body(instructions=[CallDirect({ value: 1 }, None, [], [], None)])
  assert_wat_round_trips(
    image([BytecodeBody(caller), BytecodeBody(body())]),
    "call_direct",
  )
}
