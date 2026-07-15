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
    runtime_effect_operations: [],
  }
  guard elaborate(linked, second_entry) is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.entry, second_entry)
  assert_eq(executable.initializers, [])
  assert_eq(executable.execution_roots, [Entry(second)])
}

///|
test "whole-program elaboration records ordered initializer roots" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let first = metadata.define_value("first", Local, int_type)
  let second = metadata.define_value("second", Local, int_type)
  let main = metadata.define_value("main", Function, function_type)
  let entry = executable_test_entry("main", main, function_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
        Let(first, Literal(Int(1))),
        Let(second, Ref(first)),
        Let(main, pure_function(unit_type, Literal(Unit))),
      ],
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
    runtime_effect_operations: [],
  }
  guard elaborate(linked, entry) is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.initializers, [
    Value(first, Literal(Int(1))),
    Value(second, Ref(first)),
  ])
  assert_eq(executable.execution_roots, [
    Initializer(0),
    Initializer(1),
    Entry(main),
  ])
}

///|
test "pure entry excludes unused generic runtime operations" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let unused_effect = metadata.define_effect("Unused", [])
  let unused_operation = metadata.define_operation(
    "generic",
    unused_effect,
    [hidden],
    [Parameter(hidden)],
    Parameter(hidden),
  )
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, function_type)
  let entry = executable_test_entry("main", main, function_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main", "Unused"],
    program: {
      metadata,
      terms: [Let(main, pure_function(unit_type, Literal(Unit)))],
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
    runtime_effect_operations: [
      {
        module_path_text: "Unused",
        effect_name: "Unused",
        operation_name: "generic",
        payload: [Primitive(Unit)],
        result: Primitive(Unit),
        operation: unused_operation,
      },
    ],
  }
  guard elaborate(linked, entry) is Ok(executable) else {
    abort("expected executable elaboration to ignore unused runtime operation")
  }
  assert_eq(executable.runtime_boundary.effect_operations, [])
  assert_eq(executable.externals, { builtins: [], runtime_imports: [] })
}
