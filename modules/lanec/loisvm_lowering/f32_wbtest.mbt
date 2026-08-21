///|
test "generic F32 callable flow selects a concrete representation worker" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_value_type = @buslane.Type::Parameter(type_parameter)
  let identity_type = @buslane.Type::Forall(
    [type_parameter],
    test_function_type([generic_value_type], generic_value_type),
  )
  let identity_parameter = metadata.define_value(
    "value",
    Parameter,
    generic_value_type,
  )
  let identity = metadata.define_value("identity", Function, identity_type)
  let f32_type = @buslane.Type::Primitive(F32)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([f32_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let apply_function = metadata.define_value(
    "function",
    Parameter,
    identity_type,
  )
  let apply_value = metadata.define_value("argument", Parameter, f32_type)
  let apply_type = test_function_type([identity_type, f32_type], f32_type)
  let apply = metadata.define_value("apply", Function, apply_type)
  let result = metadata.define_value("result", Local, f32_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let expected = Float::from_double(1.5)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        identity,
        TypeLambda(
          [type_parameter],
          Function({
            parameters: [identity_parameter],
            result_type: generic_value_type,
            body: Ref(identity_parameter),
          }),
        ),
      ),
      Let(
        apply,
        Function({
          parameters: [apply_function, apply_value],
          result_type: f32_type,
          body: Call(TypeApply(Ref(apply_function), [TypeArgument(f32_type)]), [
            Ref(apply_value),
          ]),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(Ref(apply), [Ref(identity), Literal(F32(expected))]),
            Call(Ref(observe), [Ref(result)]),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_test_executable_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_generic_f32",
            signature: test_host_signature(observe_type),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  let bodies = image.functions.filter_map(function => {
    if function is BytecodeBody(body) {
      Some(body)
    } else {
      None
    }
  })
  assert_true(
    bodies.any(body => {
      body.inputs.witnesses.is_empty() &&
      body.inputs.user_parameters.length() == 2 &&
      body.result == Value(F32, Trivial, ScalarValue) &&
      !contains_instruction(body, instruction => {
        instruction is (ConstLayout(_, _) | EraseF32(_, _) | UneraseF32(_, _))
      })
    }),
  )
  let mut observed = Float::from_double(0.0)
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_generic_f32",
      abi_major=1,
      parameters=[F32],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [F32(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, expected)
}
