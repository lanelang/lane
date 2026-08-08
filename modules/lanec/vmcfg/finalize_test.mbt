///|
test "finalize rejects an invalid complete bytecode image" {
  let body : FunctionBody = {
    values: [],
    inputs: { environment: None, witnesses: [], user_parameters: [] },
    result: Unit,
    blocks: [{ parameters: [], instructions: [], terminator: Return(None) }],
  }
  assert_eq(
    finalize({
      entry: { value: 2 },
      initializer: None,
      functions: [Body(body)],
      data_family_count: 0,
      globals: [],
      layouts: [],
      object_shapes: [],
      constants: [],
    }),
    Err(
      BytecodeVerificationCompilerDefect(
        @bytecode.BytecodeVerificationError::InvalidBytecode(
          site=Image,
          detail="FunctionId 2 is out of range",
        ),
      ),
    ),
  )
}
