///|
fn global_test_function_type(
  parameters : Array[@buslane.Type],
  result : @buslane.Type,
) -> @buslane.Type {
  Function(parameters, result, Empty)
}

///|
fn lower_test_linked_program_to_bytecode(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  let executable = match
    @executable.elaborate(
      { module_path_texts: [], program, externals, entries: [entry] },
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[Io, Panic],
        supports_external_effects=true,
      ),
    ) {
    Ok(executable) => executable
    Err(error) => abort("test executable elaboration failed: \{Repr(error)}")
  }
  lower_executable_program_to_bytecode(executable)
}

///|
test "executable lowering emits reachable instance globals in source order" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let string_type = @buslane.Type::Primitive(String)
  let unit_type = @buslane.Type::Primitive(Unit)
  let consume_type = global_test_function_type([string_type], unit_type)
  let consume = metadata.define_value("consume", External, consume_type)
  let unused_import = metadata.define_value(
    "unused_import",
    External,
    consume_type,
  )
  let first = metadata.define_value("first", Value, string_type)
  let second = metadata.define_value("second", Value, string_type)
  let unused_type = global_test_function_type([], unit_type)
  let unused = metadata.define_value("unused", Function, unused_type)
  let main_type = global_test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(consume),
      External(unused_import),
      Let(first, Literal(String("Lane"))),
      Let(second, Ref(first)),
      Let(
        unused,
        Function({ parameters: [], result_type: unit_type, body: Literal(Unit) }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(consume), [Ref(second)]),
        }),
      ),
    ],
  }
  let image = match
    lower_test_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: consume,
            symbol: "lane.test.consume",
            signature: { parameters: [String], result: Unit },
            type_: consume_type,
          },
          {
            value: unused_import,
            symbol: "lane.test.unused",
            signature: { parameters: [String], result: Unit },
            type_: consume_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(image.entry, { value: 3 })
  assert_eq(image.initializer, Some({ value: 4 }))
  assert_eq(image.globals, [
    {
      representation: I32,
      cleanup: OwnedRef,
      kind: ByteSequenceValue,
      erased_companion: None,
    },
    {
      representation: I32,
      cleanup: OwnedRef,
      kind: ByteSequenceValue,
      erased_companion: None,
    },
  ])
  guard image.functions
    is [
      BytecodeBody(first_step),
      BytecodeBody(second_step),
      BytecodeBody(main_body),
      BytecodeBody(initializer),
      RuntimeImport(import_),
    ] else {
    fail(
      "expected two initializer steps, the reachable entry, its orchestrator, and one runtime import",
    )
  }
  assert_eq(import_.symbol, "lane.test.consume")
  assert_eq(first_step.blocks[0], {
    parameters: [],
    instructions: [ConstString({ value: 0 }, { value: 0 })],
    terminator: Return(Some({ value: 0 })),
  })
  assert_eq(second_step.blocks[0], {
    parameters: [],
    instructions: [
      BorrowGlobal({ value: 0 }, { value: 0 }),
      RetainCopy({ value: 1 }, { value: 0 }),
    ],
    terminator: Return(Some({ value: 1 })),
  })
  assert_eq(initializer.slots, [
    {
      representation: I32,
      cleanup: OwnedRef,
      kind: ByteSequenceValue,
      erased_companion: None,
    },
  ])
  assert_eq(initializer.blocks[0].instructions, [
    CallDirect({ value: 1 }, None, [], [], Some({ value: 0 })),
    InitGlobal({ value: 0 }, { value: 0 }),
    CallDirect({ value: 2 }, None, [], [], Some({ value: 0 })),
    InitGlobal({ value: 1 }, { value: 0 }),
  ])
  assert_eq(main_body.blocks[0].instructions, [
    BorrowGlobal({ value: 0 }, { value: 1 }),
    RetainCopy({ value: 1 }, { value: 0 }),
  ])
  assert_eq(
    main_body.blocks[0].terminator,
    TailCallDirect({ value: 5 }, None, [], [{ value: 1 }]),
  )
  assert_eq(@bytecode.verify_bytecode_image(image), Ok(()))
}

///|
test "executable initializer materializes function-valued data fields" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let callable_type = global_test_function_type([], unit_type)
  let holder = metadata.define_type("Holder", [])
  let make_holder = metadata.define_data_constructor("Holder", holder, [], [
    callable_type,
  ])
  let holder_type = @buslane.Type::Constructor(holder)
  let helper = metadata.define_value("helper", Function, callable_type)
  let stored = metadata.define_value("stored", Value, holder_type)
  let consume_parameter = metadata.define_value(
    "consume_parameter",
    Parameter,
    holder_type,
  )
  let matched = metadata.define_value("matched", MatchBinder, holder_type)
  let field = metadata.define_value("field", MatchBinder, callable_type)
  let consume_type = global_test_function_type([holder_type], unit_type)
  let consume = metadata.define_value("consume", Function, consume_type)
  let main = metadata.define_value("main", Function, callable_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        helper,
        Function({ parameters: [], result_type: unit_type, body: Literal(Unit) }),
      ),
      Let(
        consume,
        Function({
          parameters: [consume_parameter],
          result_type: unit_type,
          body: Match({
            scrutinee: Ref(consume_parameter),
            binder: matched,
            result_type: unit_type,
            alternatives: [
              {
                alt_constructor: DataCon(make_holder),
                type_binders: [],
                value_binders: [field],
                body: Call(Ref(field), []),
              },
            ],
          }),
        }),
      ),
      Let(
        stored,
        Construct({
          data_constructor: make_holder,
          type_arguments: [],
          hidden_witnesses: [],
          payloads: [Ref(helper)],
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(consume), [Ref(stored)]),
        }),
      ),
    ],
  }
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
    type_: callable_type,
  }
  let image = match
    lower_executable_program_to_bytecode({
      program,
      externals: { builtins: [], runtime_imports: [] },
      entry,
      retained_values: [helper, consume, stored, main],
    }) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.initializer is Some(_) else {
    fail("expected executable initializer")
  }
  guard image.functions is [_, _, BytecodeBody(step), _, BytecodeBody(body)] else {
    fail("expected initializer bytecode body")
  }
  guard step.blocks[0].instructions
    is [ConstFunction(field, _), MakeData(global, _, _, [], [actual_field])] else {
    fail("expected initializer step to materialize the function field")
  }
  assert_eq(actual_field, field)
  assert_eq(step.blocks[0].terminator, Return(Some(global)))
  guard body.blocks[0].instructions
    is [
      CallDirect(_, None, [], [], Some(result)),
      InitGlobal({ value: 0 }, actual_global),
    ] else {
    fail("expected orchestrator to transfer the step result to its global")
  }
  assert_eq(result, actual_global)
  assert_eq(@bytecode.verify_bytecode_image(image), Ok(()))
}

///|
test "initializer orchestration is bounded by peak live owned results" {
  for count in [4, 16] {
    let metadata = @buslane.MetadataRegistry::MetadataRegistry()
    let string_type = @buslane.Type::Primitive(String)
    let unit_type = @buslane.Type::Primitive(Unit)
    let consume_type = global_test_function_type(
      Array::make(count, string_type),
      unit_type,
    )
    let consume = metadata.define_value("consume", External, consume_type)
    let values : Array[@buslane.ValueId] = []
    let terms : Array[@buslane.TopTerm] = [External(consume)]
    for index in 0..<count {
      let value = metadata.define_value("global_\{index}", Value, string_type)
      values.push(value)
      terms.push(Let(value, Literal(String("Lane"))))
    }
    let main_type = global_test_function_type([], unit_type)
    let main = metadata.define_value("main", Function, main_type)
    terms.push(
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(consume), values.map(value => Ref(value))),
        }),
      ),
    )
    let program : @buslane.Program = { metadata, terms }
    let image = match
      lower_test_linked_program_to_bytecode(
        program,
        {
          builtins: [],
          runtime_imports: [
            {
              value: consume,
              symbol: "lane.test.consume_many",
              signature: {
                parameters: Array::make(count, String),
                result: Unit,
              },
              type_: consume_type,
            },
          ],
        },
        {
          module_path_text: "Main",
          name: "main",
          value: main,
          type_: main_type,
        },
      ) {
      Ok(image) => image
      Err(error) => fail("lowering failed: \{Repr(error)}")
    }
    assert_eq(image.functions.length(), count + 3)
    assert_eq(image.initializer, Some({ value: count + 2 }))
    for index in 0..<count {
      guard image.functions[index] is BytecodeBody(step) else {
        fail("expected initializer step bytecode body")
      }
      assert_eq(step.slots.length(), 1)
    }
    guard image.functions[count + 1] is BytecodeBody(initializer) else {
      fail("expected initializer orchestrator bytecode body")
    }
    assert_eq(initializer.slots, [
      {
        representation: I32,
        cleanup: OwnedRef,
        kind: ByteSequenceValue,
        erased_companion: None,
      },
    ])
    let expected : Array[@bytecode.Instruction] = []
    for index in 0..<count {
      expected.push(
        CallDirect({ value: index + 1 }, None, [], [], Some({ value: 0 })),
      )
      expected.push(InitGlobal({ value: index }, { value: 0 }))
    }
    assert_eq(initializer.blocks, [
      { parameters: [], instructions: expected, terminator: Return(None) },
    ])
    assert_eq(@bytecode.verify_bytecode_image(image), Ok(()))
  }
}
