///|
fn executable_test_entry(
  name : String,
  value : @buslane.ValueId,
) -> @buslane_lowering.BuslaneEntry {
  { module_path_text: "Main", name, value, }
}

///|
fn pure_function(
  result_type : @buslane.Type,
  body : @buslane.Expr,
) -> @buslane.Expr {
  Function({ parameters: [], result_type, body, })
}

///|
fn executable_test_program(
  metadata : @buslane.MetadataRegistry,
  terms : Array[@buslane.TopTerm],
) -> @buslane.VerifiedProgram {
  let program : @buslane.Program = { metadata, terms, }
  program.certify().unwrap()
}

///|
test "whole-program elaboration preserves the selected entry" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let function_type = @buslane.Type::Function([], unit_type, Empty)
  let first = metadata.define_value("first", Function, function_type)
  let second = metadata.define_value("second", Function, function_type)
  let first_entry = executable_test_entry("first", first)
  let second_entry = executable_test_entry("second", second)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: executable_test_program(metadata, [
      Let(first, pure_function(unit_type, Literal(Unit))),
      Let(second, pure_function(unit_type, Literal(Unit))),
    ]),
    externals: { builtins: [], runtime_imports: [], },
    entries: [first_entry, second_entry],
  }
  guard elaborate(linked, second_entry, test_execution_profile())
    is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.entry, second_entry)
  assert_eq(executable.retained_values, [second])
}

///|
test "whole-program elaboration records ordered reachable initializer roots" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let producer_type = @buslane.Type::Function([i64_type], i64_type, Empty)
  let observe_type = @buslane.Type::Function([i64_type], unit_type, Builtin(Io))
  let function_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let first = metadata.define_value("first", Value, i64_type)
  let second = metadata.define_value("second", Value, i64_type)
  let unused = metadata.define_value("unused", Value, i64_type)
  let producer_parameter = metadata.define_value(
    "producer_parameter",
    Parameter,
    i64_type,
  )
  let produce = metadata.define_value("produce", Function, producer_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let main = metadata.define_value("main", Function, function_type)
  let entry = executable_test_entry("main", main)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: executable_test_program(metadata, [
      Let(
        produce,
        Function({
          parameters: [producer_parameter],
          result_type: i64_type,
          body: Ref(producer_parameter),
        }),
      ),
      Let(first, Literal(I64(1))),
      Let(second, Call(Ref(produce), [Ref(first)])),
      Let(unused, Literal(I64(2))),
      External(observe),
      Let(main, pure_function(unit_type, Call(Ref(observe), [Ref(second)]))),
    ]),
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: observe,
          contract: {
            module_name: "lane.test",
            field_name: "observe",
            parameters: [Direct(I64)],
            result: Unit,
          },
        },
      ],
    },
    entries: [entry],
  }
  guard elaborate(linked, entry, test_execution_profile()) is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.retained_values, [first, second, observe, main])
}

///|
test "whole-program elaboration accepts an Io entry without a root handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let i64_type = @buslane.Type::Primitive(I64)
  let println_type = @buslane.Type::Function([i64_type], unit_type, Builtin(Io))
  let main_type = @buslane.Type::Function([], unit_type, Builtin(Io))
  let println = metadata.define_value("println", External, println_type)
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: executable_test_program(metadata, [
      External(println),
      Let(
        main,
        pure_function(unit_type, Call(Ref(println), [Literal(I64(42L))])),
      ),
    ]),
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: println,
          contract: {
            module_name: "lane.test",
            field_name: "println",
            parameters: [Direct(I64)],
            result: Unit,
          },
        },
      ],
    },
    entries: [entry],
  }
  guard elaborate(linked, entry, test_execution_profile()) is Ok(executable) else {
    abort("expected Io entry elaboration to succeed")
  }
  debug_inspect(
    (
      executable.entry,
      executable.externals,
      executable.cps_core.program().program().metadata
      .value_info(println)
      .unwrap().type_,
      executable.cps_core.program().program().metadata.value_info(main).unwrap().type_,
    ),
    content=(
      #|(
      #|  { module_path_text: "Main", name: "main", value: { index: 1 } },
      #|  {
      #|    builtins: [],
      #|    runtime_imports: [
      #|      {
      #|        value: { index: 0 },
      #|        contract: {
      #|          module_name: "lane.test",
      #|          field_name: "println",
      #|          parameters: [Direct(I64)],
      #|          result: Unit,
      #|        },
      #|      },
      #|    ],
      #|  },
      #|  Function([Primitive(I64)], Primitive(Unit), Builtin(Io)),
      #|  Function([], Primitive(Unit), Builtin(Io)),
      #|)
    ),
  )
  assert_true(
    @buslane.verify_program(executable.cps_core.program().program()).is_ok(),
  )
}

///|
test "whole-program elaboration accepts a closed external effect entry" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let host_effect = metadata.define_effect("Host", [], flavor=External)
  let external_effect = @buslane.Effect::Singleton(host_effect, [])
  let main_type = @buslane.Type::Function([], unit_type, external_effect)
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: executable_test_program(metadata, [
      Let(main, pure_function(unit_type, Literal(Unit))),
    ]),
    externals: { builtins: [], runtime_imports: [], },
    entries: [entry],
  }
  guard elaborate(linked, entry, test_execution_profile()) is Ok(executable) else {
    abort("expected external-effect entry elaboration to succeed")
  }
  debug_inspect(
    (
      @buslane_lowering.source_value_type(
        executable.cps_core.program().program().metadata,
        executable.entry.value,
      ),
      executable.cps_core.program().program().metadata
      .effect_info(host_effect)
      .map(info => info.flavor),
      executable.cps_core.program().program().metadata
      .value_info(main)
      .map(info => info.type_),
    ),
    content=(
      #|(
      #|  Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|  Some(External),
      #|  Some(Function([], Primitive(Unit), Singleton({ index: 0 }, []))),
      #|)
    ),
  )
}

///|
test "invalid Buslane cannot enter executable elaboration" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let char_type = @buslane.Type::Primitive(Char)
  let unit_type = @buslane.Type::Primitive(Unit)
  let consume_type = @buslane.Type::Function([char_type], unit_type, Empty)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let invalid = metadata.define_value("invalid", Value, char_type)
  let parameter = metadata.define_value("parameter", Parameter, char_type)
  let consume = metadata.define_value("consume", Function, consume_type)
  let main = metadata.define_value("main", Function, main_type)
  let source : @buslane.Program = {
    metadata,
    terms: [
      Let(invalid, Literal(Char(-1))),
      Let(
        consume,
        Function({
          parameters: [parameter],
          result_type: unit_type,
          body: Literal(Unit),
        }),
      ),
      Let(main, pure_function(unit_type, Call(Ref(consume), [Ref(invalid)]))),
    ],
  }
  assert_true(source.certify() is Err(_))
}

///|
test "whole-program elaboration rejects an algebraic entry effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect = metadata.define_effect("Console", [])
  let operation = metadata.define_operation("write", effect, [], [], unit_type)
  let main_type = @buslane.Type::Function([], unit_type, Singleton(effect, []))
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: executable_test_program(metadata, [
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
    ]),
    externals: { builtins: [], runtime_imports: [], },
    entries: [entry],
  }
  debug_inspect(
    elaborate(linked, entry, test_execution_profile()),
    content=(
      #|Err(
      #|  EntryAdmissionRejected(
      #|    value={ index: 0 },
      #|    type_=Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|    reason=HasUnsupportedEffects(effects=[Singleton({ index: 0 }, [])]),
      #|  ),
      #|)
    ),
  )
}

///|
test "invalid generic metadata cannot enter executable elaboration" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let generic = metadata.define_value(
    "generic",
    Function,
    Forall(
      [effect_parameter],
      Function([], unit_type, Parameter(effect_parameter)),
    ),
  )
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let source : @buslane.Program = {
    metadata,
    terms: [
      LetRec([
        {
          id: generic,
          rhs: TypeLambda(
            [effect_parameter],
            Function({
              parameters: [],
              result_type: unit_type,
              body: Literal(Unit),
            }),
          ),
        },
        {
          id: main,
          rhs: Function({
            parameters: [],
            result_type: unit_type,
            body: Call(TypeApply(Ref(generic), [TypeArgument(unit_type)]), []),
          }),
        },
      ]),
    ],
  }
  assert_true(source.certify() is Err(_))
}

///|
fn test_execution_profile() -> ExecutionProfile {
  ExecutionProfile::new(
    builtin_effects=[Io, Panic],
    supports_external_effects=true,
  )
}

///|
fn elaborate_entry_with_effect(
  effect : @buslane.Effect,
  profile : ExecutionProfile,
) -> Result[ExecutableProgram, ExecutableElaborationError] raise {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let main_type = @buslane.Type::Function([], unit_type, effect)
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main)
  elaborate(
    {
      module_path_texts: ["Main"],
      program: executable_test_program(metadata, [
        Let(
          main,
          Function({
            parameters: [],
            result_type: unit_type,
            body: Literal(Unit),
          }),
        ),
      ]),
      externals: { builtins: [], runtime_imports: [], },
      entries: [entry],
    },
    entry,
    profile,
  )
}

///|
test "execution profiles explicitly own built-in effect admission" {
  let io_only = ExecutionProfile::new(
    builtin_effects=[Io],
    supports_external_effects=false,
  )
  assert_true(elaborate_entry_with_effect(Builtin(Io), io_only) is Ok(_))
  guard elaborate_entry_with_effect(Builtin(Panic), io_only)
    is Err(EntryAdmissionRejected(reason~, ..)) else {
    fail("expected Panic to be rejected by the Io-only profile")
  }
  assert_eq(reason, HasUnsupportedEffects(effects=[Builtin(Panic)]))
  guard elaborate_entry_with_effect(
      Union([Builtin(Io), Builtin(Panic)]),
      ExecutionProfile::new(builtin_effects=[], supports_external_effects=false),
    )
    is Err(EntryAdmissionRejected(reason~, ..)) else {
    fail("expected an empty profile to reject both built-in effects")
  }
  assert_eq(
    reason,
    HasUnsupportedEffects(effects=[Builtin(Io), Builtin(Panic)]),
  )
  assert_true(
    elaborate_entry_with_effect(
      Union([Builtin(Io), Builtin(Panic)]),
      test_execution_profile(),
    )
    is Ok(_),
  )
}

///|
