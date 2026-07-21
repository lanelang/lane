///|
fn executable_test_entry(
  name : String,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> @buslane_lowering.BuslaneEntry {
  { module_path_text: "Main", name, value, type_ }
}

///|
fn pure_function(
  result_type : @buslane.Type,
  body : @buslane.Expr,
) -> @buslane.Expr {
  Function({ parameters: [], result_type, body })
}

///|
test "whole-program elaboration preserves the selected entry" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let first = metadata.define_value("first", Function, function_type)
  let second = metadata.define_value("second", Function, function_type)
  let first_entry = executable_test_entry("first", first, function_type)
  let second_entry = executable_test_entry("second", second, function_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        Let(first, pure_function(unit_type, Literal(Unit))),
        Let(second, pure_function(unit_type, Literal(Unit))),
      ],
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [first_entry, second_entry],
  }
  guard elaborate(linked, second_entry) is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.entry, second_entry)
  assert_eq(executable.initializers, [])
  assert_eq(executable.execution_roots, [Entry(second)])
}

///|
test "whole-program elaboration records ordered reachable initializer roots" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let producer_type = @buslane.Type::Function([int_type], int_type, Empty)
  let observe_type = @buslane.Type::Function([int_type], unit_type, Io)
  let function_type = @buslane.Type::Function([], unit_type, Io)
  let first = metadata.define_value("first", Local, int_type)
  let second = metadata.define_value("second", Local, int_type)
  let unused = metadata.define_value("unused", Local, int_type)
  let producer_parameter = metadata.define_value(
    "producer_parameter",
    Parameter,
    int_type,
  )
  let produce = metadata.define_value("produce", Function, producer_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let main = metadata.define_value("main", Function, function_type)
  let entry = executable_test_entry("main", main, function_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        Let(first, Literal(Int(1))),
        Let(second, Call(Ref(produce), [Ref(first)])),
        Let(unused, Literal(Int(2))),
        Let(
          produce,
          Function({
            parameters: [producer_parameter],
            result_type: int_type,
            body: Ref(producer_parameter),
          }),
        ),
        External(observe),
        Let(main, pure_function(unit_type, Call(Ref(observe), [Ref(second)]))),
      ],
    },
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: observe,
          symbol: "observe",
          signature: { parameters: [Int], result: Unit },
          type_: observe_type,
        },
      ],
    },
    entries: [entry],
  }
  guard elaborate(linked, entry) is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  debug_inspect(
    (executable.initializers, executable.execution_roots),
    content=(
      #|(
      #|  [
      #|    Value({ index: 0 }, Literal(Int(1))),
      #|    Value({ index: 1 }, Ref({ index: 0 })),
      #|  ],
      #|  [Initializer(0), Initializer(1), Entry({ index: 6 })],
      #|)
    ),
  )
}

///|
test "whole-program elaboration accepts an Io entry without a root handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_type = @buslane.Type::Primitive(String)
  let println_type = @buslane.Type::Function([string_type], unit_type, Io)
  let main_type = @buslane.Type::Function([], unit_type, Io)
  let println = metadata.define_value("println", External, println_type)
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main, main_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        External(println),
        Let(
          main,
          pure_function(
            unit_type,
            Call(Ref(println), [Literal(String("hello"))]),
          ),
        ),
      ],
    },
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: println,
          symbol: "println",
          signature: { parameters: [String], result: Unit },
          type_: println_type,
        },
      ],
    },
    entries: [entry],
  }
  guard elaborate(linked, entry) is Ok(executable) else {
    abort("expected Io entry elaboration to succeed")
  }
  debug_inspect(
    (
      executable.entry,
      executable.externals,
      executable.program.metadata.value_info(println).unwrap().type_,
      executable.program.metadata.value_info(main).unwrap().type_,
    ),
    content=(
      #|(
      #|  {
      #|    module_path_text: "Main",
      #|    name: "main",
      #|    value: { index: 1 },
      #|    type_: Function([], Primitive(Unit), Io),
      #|  },
      #|  {
      #|    builtins: [],
      #|    runtime_imports: [
      #|      {
      #|        value: { index: 0 },
      #|        symbol: "println",
      #|        signature: { parameters: [String], result: Unit },
      #|        type_: Function([Primitive(String)], Primitive(Unit), Io),
      #|      },
      #|    ],
      #|  },
      #|  Function([Primitive(String)], Primitive(Unit), Empty),
      #|  Function([], Primitive(Unit), Empty),
      #|)
    ),
  )
  assert_true(@buslane.verify_program(executable.program).is_ok())
}

///|
test "whole-program elaboration accepts a closed external effect entry" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let host_effect = metadata.define_effect("Host", [], flavor=External)
  let external_effect = @buslane.Effect::Singleton(host_effect, [])
  let main_type = @buslane.Type::Function([], unit_type, external_effect)
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main, main_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [Let(main, pure_function(unit_type, Literal(Unit)))],
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
  }
  guard elaborate(linked, entry) is Ok(executable) else {
    abort("expected external-effect entry elaboration to succeed")
  }
  debug_inspect(
    (
      executable.entry.type_,
      executable.program.metadata
      .effect_info(host_effect)
      .map(info => info.flavor),
      executable.program.metadata.value_info(main).map(info => info.type_),
    ),
    content=(
      #|(
      #|  Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|  Some(External),
      #|  Some(Function([], Primitive(Unit), Empty)),
      #|)
    ),
  )
}

///|
test "whole-program elaboration rejects an algebraic entry effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect = metadata.define_effect("Console", [])
  let operation = metadata.define_operation("write", effect, [], [], unit_type)
  let main_type = @buslane.Type::Function([], unit_type, Singleton(effect, []))
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main, main_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        Let(
          main,
          pure_function(
            unit_type,
            Perform({
              operation,
              effect_arguments: [],
              hidden_witnesses: [],
              payloads: [],
            }),
          ),
        ),
      ],
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
  }
  debug_inspect(
    elaborate(linked, entry),
    content=(
      #|Err(
      #|  InvalidEntryFunction(
      #|    value={ index: 0 },
      #|    type_=Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|  ),
      #|)
    ),
  )
}
