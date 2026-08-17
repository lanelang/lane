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
  guard elaborate(linked, second_entry, test_execution_profile())
    is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.entry, second_entry)
  assert_eq(executable.initializer_roots, [])
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
  let entry = executable_test_entry("main", main, function_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
      metadata,
      terms: [
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
      ],
    },
    externals: {
      builtins: [],
      runtime_imports: [
        {
          value: observe,
          symbol: "observe",
          signature: { parameters: [I64], result: Unit },
          type_: observe_type,
        },
      ],
    },
    entries: [entry],
  }
  guard elaborate(linked, entry, test_execution_profile()) is Ok(executable) else {
    abort("expected executable elaboration to succeed")
  }
  assert_eq(executable.initializer_roots, [first, second])
}

///|
test "whole-program elaboration accepts an Io entry without a root handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_type = @buslane.Type::Primitive(String)
  let println_type = @buslane.Type::Function(
    [string_type],
    unit_type,
    Builtin(Io),
  )
  let main_type = @buslane.Type::Function([], unit_type, Builtin(Io))
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
  guard elaborate(linked, entry, test_execution_profile()) is Ok(executable) else {
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
      #|    type_: Function([], Primitive(Unit), Builtin(Io)),
      #|  },
      #|  {
      #|    builtins: [],
      #|    runtime_imports: [
      #|      {
      #|        value: { index: 0 },
      #|        symbol: "println",
      #|        signature: { parameters: [String], result: Unit },
      #|        type_: Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
      #|      },
      #|    ],
      #|  },
      #|  Function([Primitive(String)], Primitive(Unit), Builtin(Io)),
      #|  Function([], Primitive(Unit), Builtin(Io)),
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
  guard elaborate(linked, entry, test_execution_profile()) is Ok(executable) else {
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
      #|  Some(Function([], Primitive(Unit), Singleton({ index: 0 }, []))),
      #|)
    ),
  )
}

///|
test "whole-program elaboration rejects unverified effect specialization before observation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let char_type = @buslane.Type::Primitive(Char)
  let unit_type = @buslane.Type::Primitive(Unit)
  let consume_type = @buslane.Type::Function([char_type], unit_type, Empty)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let invalid = metadata.define_value("invalid", Value, char_type)
  let parameter = metadata.define_value("parameter", Parameter, char_type)
  let consume = metadata.define_value("consume", Function, consume_type)
  let main = metadata.define_value("main", Function, main_type)
  let entry = executable_test_entry("main", main, main_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
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
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
  }
  let observed = []
  let result = elaborate_observed(linked, entry, test_execution_profile(), stage => {
    observed.push(stage)
  })
  assert_eq(observed.length(), 0)
  debug_inspect(
    result,
    content=(
      #|Err(
      #|  UnverifiedProgram(
      #|    stage="effect specialization",
      #|    result={
      #|      diagnostics: [
      #|        {
      #|          kind: InvalidCharLiteral(-1),
      #|          provenance: [
      #|            TopTerm(
      #|              {
      #|                id: { index: 0 },
      #|                name: Some({ name_space: ValueName, occurrence: "invalid", unique: { value: 0 } }),
      #|              },
      #|            ),
      #|            Expression(Literal),
      #|          ],
      #|        },
      #|      ],
      #|    },
      #|  ),
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
test "whole-program elaboration identifies specialization metadata defects" {
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
  let entry = executable_test_entry("main", main, main_type)
  let linked : @module_link.LinkedProgram = {
    module_path_texts: ["Main"],
    program: {
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
    },
    externals: { builtins: [], runtime_imports: [] },
    entries: [entry],
  }
  guard elaborate(linked, entry, test_execution_profile())
    is Err(EffectSpecializationCompilerDefect(InvalidInputMetadata(context))) else {
    fail("expected an effect-specialization compiler defect")
  }
  assert_eq(context, {
    detail: "an effect parameter requires an effect argument",
    site: Some(TopLevel(main)),
    source: Some(TypeParameter(effect_parameter)),
    specialization_key: [],
  })
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
  let entry = executable_test_entry("main", main, main_type)
  elaborate(
    {
      module_path_texts: ["Main"],
      program: {
        metadata,
        terms: [
          Let(
            main,
            Function({
              parameters: [],
              result_type: unit_type,
              body: Literal(Unit),
            }),
          ),
        ],
      },
      externals: { builtins: [], runtime_imports: [] },
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
