///|
test "generic Array intrinsic wrapper carries its layout witness" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let image = test_image_lowerer(metadata)
  let evidence = image.fresh_synthetic_parameter()
  let parameter : @anf.RuntimeEvidenceParameter = { id: evidence, arity: 0, }
  let expression = image.runtime_types.intern(Parameter(evidence))
  let argument : @anf.RuntimeArgument = {
    type_expression: expression,
    evidence: Parameter(evidence),
  }
  let erased = @anf.RuntimeType::Erased(expression, Parameter(evidence))
  let contract : RuntimeIntrinsicFunctionContract = {
    intrinsic: @abi.Intrinsic::ArrayMake,
    evidence_parameters: [parameter],
    parameters: [Scalar(I64), erased],
    result: @anf.RuntimeType::Array(argument),
    implementation: Direct,
  }
  ignore(image.intrinsic_wrapper(contract))
  let body = image.lower_intrinsic_wrapper(image.intrinsic_wrappers[0])
  assert_eq(body.inputs.witnesses.length(), 1)
  assert_eq(body.inputs.user_parameters.length(), 2)
  let fill = body.values[body.inputs.user_parameters[1].value]
  assert_true(
    fill
    is {
      representation: I64,
      cleanup: OwnedErased,
      kind: ErasedValue,
      ownership: Owned,
      erased_companion: Some(_),
    },
  )
  assert_true(
    body.blocks[0].instructions.any(instruction => {
      instruction is @vmcfg.Instruction::ArrayMake(_, _, _)
    }),
  )
}
