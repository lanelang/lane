///|
fn global_test_function_type(
  parameters : Array[@buslane.Type],
  result : @buslane.Type,
) -> @buslane.Type {
  Function(parameters, result, Empty)
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
  let first = metadata.define_value("first", Local, string_type)
  let second = metadata.define_value("second", Local, string_type)
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
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: consume, name: "lane.test.consume", type_: consume_type },
          {
            value: unused_import,
            name: "lane.test.unused",
            type_: consume_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_eq(image.entry, { value: 1 })
  assert_eq(image.initializer, Some({ value: 2 }))
  assert_eq(image.globals, [
    { representation: I32, cleanup: OwnedRef, erased_companion: None },
    { representation: I32, cleanup: OwnedRef, erased_companion: None },
  ])
  guard image.functions
    is [
      BytecodeBody(main_body),
      BytecodeBody(initializer),
      RuntimeImport(import_),
    ] else {
    fail("expected reachable entry, initializer, and one runtime import")
  }
  assert_eq(import_.symbol, "lane.test.consume")
  assert_eq(initializer.blocks[0].instructions, [
    ConstString({ value: 0 }, { value: 0 }),
    InitGlobal({ value: 0 }, { value: 0 }),
    BorrowGlobal({ value: 1 }, { value: 0 }),
    RetainCopy({ value: 2 }, { value: 1 }),
    InitGlobal({ value: 1 }, { value: 2 }),
  ])
  assert_eq(main_body.blocks[0].instructions, [
    BorrowGlobal({ value: 0 }, { value: 1 }),
    RetainCopy({ value: 1 }, { value: 0 }),
  ])
  assert_eq(
    main_body.blocks[0].terminator,
    TailCallDirect({ value: 3 }, None, [], [{ value: 1 }]),
  )
}
