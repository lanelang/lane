///|
fn test_function_type(
  parameters : Array[@buslane.Type],
  result : @buslane.Type,
) -> @buslane.Type {
  Function(parameters, result, Empty)
}

///|
fn contains_instruction(
  body : @bytecode.FunctionBody,
  predicate : (@bytecode.Instruction) -> Bool,
) -> Bool {
  for block in body.blocks {
    for instruction in block.instructions {
      if predicate(instruction) {
        return true
      }
    }
  }
  false
}

///|
test "pure scalar Buslane lowers through ANF into executable LoisVM bytecode" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([int_type, int_type], int_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let parameter = metadata.define_value("value", Parameter, int_type)
  let helper_type = test_function_type([int_type], int_type)
  let helper = metadata.define_value("add_one", Function, helper_type)
  let result = metadata.define_value("result", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(add),
      Let(
        helper,
        Function({
          parameters: [parameter],
          result_type: int_type,
          body: Call(Ref(add), [Ref(parameter), Literal(Int(1L))]),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(Ref(helper), [Literal(Int(41L))]),
            Literal(Unit),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      { builtins: [{ value: add, name: "%i64_add", type_: add_type }] },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_eq(image.entry, { value: 2 })
  guard image.functions is [BytecodeBody(helper_body), BytecodeBody(main_body)] else {
    fail("expected two bytecode bodies")
  }
  assert_true(
    contains_instruction(helper_body, instruction => {
      instruction is IntAdd(_, _, _)
    }),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is CallDirect({ value: 1 }, None, [], _, _)
    }),
  )
  let loaded = match
    @interp.load(image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "scalar intrinsics materialize as deduplicated first-class wrappers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([int_type, int_type], int_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let callable = metadata.define_value("callable", Parameter, add_type)
  let other_callable = metadata.define_value(
    "other_callable",
    Parameter,
    add_type,
  )
  let left = metadata.define_value("left", Parameter, int_type)
  let right = metadata.define_value("right", Parameter, int_type)
  let apply_type = test_function_type(
    [add_type, add_type, int_type, int_type],
    int_type,
  )
  let apply = metadata.define_value("apply", Function, apply_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let result = metadata.define_value("result", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(add),
      External(observe),
      Let(
        apply,
        Function({
          parameters: [callable, other_callable, left, right],
          result_type: int_type,
          body: Call(Ref(callable), [Ref(left), Ref(right)]),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(Ref(apply), [
              Ref(add),
              Ref(add),
              Literal(Int(20L)),
              Literal(Int(22L)),
            ]),
            Call(Ref(observe), [Ref(result)]),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: add, name: "%i64_add", type_: add_type },
          {
            value: observe,
            name: "lane.test.observe_intrinsic_value",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions
    is [
      BytecodeBody(apply_body),
      BytecodeBody(main_body),
      BytecodeBody(wrapper_body),
      RuntimeImport(_),
    ] else {
    fail("expected apply, main, intrinsic wrapper, and runtime import")
  }
  assert_true(apply_body.blocks[0].terminator is TailCallValue(_, [], _))
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is ConstFunction(_, { value: 3 })
    }),
  )
  assert_true(
    contains_instruction(wrapper_body, instruction => {
      instruction is IntAdd(_, _, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_intrinsic_value",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "effect forms fail before bytecode emission" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect = metadata.define_effect("Test", [])
  let operation = metadata.define_operation("run", effect, [], [], unit_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Perform({
            operation,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [],
          }),
        }),
      ),
    ],
  }
  assert_true(
    lower_linked_program_to_bytecode(program, { builtins: [] }, {
      module_path_text: "Main",
      name: "main",
      value: main,
      type_: main_type,
    })
    is Err(
      UnsupportedExpression(
        detail="non-runtime effects must be erased before VM CFG lowering"
      )
    ),
  )
}

///|
test "linked runtime effects become ordinary stable-symbol imports" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let string_type = @buslane.Type::Primitive(String)
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect = metadata.define_effect("Io", [])
  let operation = metadata.define_operation(
    "print",
    effect,
    [],
    [string_type],
    unit_type,
  )
  let main_type = @buslane.Type::Function([], unit_type, Singleton(effect, []))
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Perform({
            operation,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(String("Lane"))],
          }),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode_with_runtime_effects(
      program,
      { builtins: [] },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
      [
        {
          module_path_text: "Main",
          effect_name: "Io",
          operation_name: "print",
          payload: [Primitive(String)],
          result: Primitive(Unit),
          operation,
        },
      ],
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.functions[1]
    is RuntimeImport(
      { abi_major: 1, user_arity: 1, symbol: "lane.effect.v1/Main/Io/print" }
    ),
  )
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    main_body.blocks[0].terminator
    is TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
  )
  let mut observed = ""
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.effect.v1/Main/Io/print",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [BorrowedString(value)] {
          observed = value.to_string()
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, "Lane")
}

///|
test "primitive external functions become runtime imports" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(observe), [Literal(Int(42L))]),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: observe, name: "lane.test.observe", type_: observe_type },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.functions
    is [
      BytecodeBody(_),
      RuntimeImport(
        { abi_major: 1, user_arity: 1, symbol: "lane.test.observe" }
      ),
    ],
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "runtime imports are deduplicated and sorted after bytecode bodies" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let import_type = test_function_type([], unit_type)
  let z_first = metadata.define_value("z_first", External, import_type)
  let a = metadata.define_value("a", External, import_type)
  let z_second = metadata.define_value("z_second", External, import_type)
  let first = metadata.define_value("first", Local, unit_type)
  let second = metadata.define_value("second", Local, unit_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(z_first),
      External(a),
      External(z_second),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            first,
            Call(Ref(z_first), []),
            Let(second, Call(Ref(a), []), Call(Ref(z_second), [])),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: z_first, name: "lane.test.z", type_: import_type },
          { value: a, name: "lane.test.a", type_: import_type },
          { value: z_second, name: "lane.test.z", type_: import_type },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.functions
    is [
      BytecodeBody(_),
      RuntimeImport({ symbol: "lane.test.a", .. }),
      RuntimeImport({ symbol: "lane.test.z", .. }),
    ],
  )
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  let direct_targets = []
  for block in main_body.blocks {
    for instruction in block.instructions {
      if instruction is CallDirect(target, _, _, _, _) {
        direct_targets.push(target)
      }
    }
    if block.terminator is TailCallDirect(target, _, _, _) {
      direct_targets.push(target)
    }
  }
  assert_eq(direct_targets, [{ value: 3 }, { value: 2 }, { value: 3 }])
}

///|
test "owned String arguments are transferred through VM CFG ARC insertion" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let string_type = @buslane.Type::Primitive(String)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([string_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(observe), [Literal(String("Lane"))]),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_string",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    main_body.blocks[0].terminator
    is TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
  )
  let mut observed = ""
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_string",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [BorrowedString(value)] {
          observed = value.to_string()
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, "Lane")
}

///|
test "Bool matches lower to explicit CFG branches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let bool_type = @buslane.Type::Primitive(Bool)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let binder = metadata.define_value("condition", MatchBinder, bool_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Match({
            scrutinee: Literal(Bool(true)),
            binder,
            result_type: unit_type,
            alternatives: [
              {
                alt_constructor: Literal(Bool(true)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(Int(1L))]),
              },
              {
                alt_constructor: Literal(Bool(false)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(Int(2L))]),
              },
            ],
          }),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_branch",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_eq(main_body.blocks.length(), 4)
  assert_true(main_body.blocks[0].terminator is BranchBool(_, _, _))
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_branch",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 1L)
}

///|
test "non-generic data construction and matching lower through object shapes" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let option = metadata.define_type("OptionInt", [])
  let none = metadata.define_data_constructor("None", option, [], [])
  let some = metadata.define_data_constructor("Some", option, [], [int_type])
  let option_type = @buslane.Type::Constructor(option)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, option_type)
  let binder = metadata.define_value("option", MatchBinder, option_type)
  let payload = metadata.define_value("payload", MatchBinder, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            scrutinee,
            Construct({
              data_constructor: some,
              type_arguments: [],
              hidden_witnesses: [],
              payloads: [Literal(Int(7L))],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(none),
                  type_binders: [],
                  value_binders: [],
                  body: Call(Ref(observe), [Literal(Int(0L))]),
                },
                {
                  alt_constructor: DataCon(some),
                  type_binders: [],
                  value_binders: [payload],
                  body: Call(Ref(observe), [Ref(payload)]),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_data",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_eq(image.object_shapes.length(), 2)
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is MakeData(_, _, _, [], _)
    }),
  )
  assert_true(main_body.blocks[0].terminator is SwitchTag(_, _, _))
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_data",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 7L)
}

///|
test "capture-free functions lower as callable values for higher-order calls" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([int_type, int_type], int_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let increment_parameter = metadata.define_value("value", Parameter, int_type)
  let increment_type = test_function_type([int_type], int_type)
  let increment = metadata.define_value("increment", Function, increment_type)
  let callable_parameter = metadata.define_value(
    "callable",
    Parameter,
    increment_type,
  )
  let apply_parameter = metadata.define_value("value", Parameter, int_type)
  let apply_type = test_function_type([increment_type, int_type], int_type)
  let apply = metadata.define_value("apply", Function, apply_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let result = metadata.define_value("result", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(add),
      External(observe),
      Let(
        increment,
        Function({
          parameters: [increment_parameter],
          result_type: int_type,
          body: Call(Ref(add), [Ref(increment_parameter), Literal(Int(1L))]),
        }),
      ),
      Let(
        apply,
        Function({
          parameters: [callable_parameter, apply_parameter],
          result_type: int_type,
          body: Call(Ref(callable_parameter), [Ref(apply_parameter)]),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(Ref(apply), [Ref(increment), Literal(Int(41L))]),
            Call(Ref(observe), [Ref(result)]),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: add, name: "%i64_add", type_: add_type },
          {
            value: observe,
            name: "lane.test.observe_higher_order",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[1] is BytecodeBody(apply_body) else {
    fail("expected apply bytecode body")
  }
  assert_true(apply_body.blocks[0].terminator is TailCallValue(_, [], _))
  guard image.functions[2] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is ConstFunction(_, { value: 1 })
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_higher_order",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "nested functions lift with explicit reference-counted environments" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([int_type, int_type], int_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let captured = metadata.define_value("captured", Local, int_type)
  let parameter = metadata.define_value("argument", Parameter, int_type)
  let closure_type = test_function_type([int_type], int_type)
  let closure = metadata.define_value("closure", Local, closure_type)
  let result = metadata.define_value("result", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(add),
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            captured,
            Literal(Int(40L)),
            Let(
              closure,
              Function({
                parameters: [parameter],
                result_type: int_type,
                body: Call(Ref(add), [Ref(captured), Ref(parameter)]),
              }),
              Let(
                result,
                Call(Ref(closure), [Literal(Int(2L))]),
                Call(Ref(observe), [Ref(result)]),
              ),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: add, name: "%i64_add", type_: add_type },
          {
            value: observe,
            name: "lane.test.observe_closure",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_eq(image.object_shapes.length(), 1)
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is MakeEnv(_, _, _, [], _)
    }),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is MakeClosure(_, { value: 2 }, _)
    }),
  )
  guard image.functions[1] is BytecodeBody(lifted_body) else {
    fail("expected lifted bytecode body")
  }
  assert_true(lifted_body.inputs.environment is Some(_))
  assert_true(
    contains_instruction(lifted_body, instruction => {
      instruction is BorrowCapture(_, _, 0, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_closure",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "local recursive functions share a cycle-free captured environment" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let bool_type = @buslane.Type::Primitive(Bool)
  let unit_type = @buslane.Type::Primitive(Unit)
  let sub_type = test_function_type([int_type, int_type], int_type)
  let sub = metadata.define_value("%i64_sub", External, sub_type)
  let equal_type = test_function_type([int_type, int_type], bool_type)
  let equal = metadata.define_value("%i64_equal", External, equal_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let captured = metadata.define_value("captured", Local, int_type)
  let parameter = metadata.define_value("remaining", Parameter, int_type)
  let condition = metadata.define_value("done", MatchBinder, bool_type)
  let recursive_type = test_function_type([int_type], unit_type)
  let recursive_function = metadata.define_value("loop", Local, recursive_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(sub),
      External(equal),
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            captured,
            Literal(Int(42L)),
            LetRec(
              [
                {
                  id: recursive_function,
                  rhs: Function({
                    parameters: [parameter],
                    result_type: unit_type,
                    body: Match({
                      scrutinee: Call(Ref(equal), [
                        Ref(parameter),
                        Literal(Int(0L)),
                      ]),
                      binder: condition,
                      result_type: unit_type,
                      alternatives: [
                        {
                          alt_constructor: Literal(Bool(true)),
                          type_binders: [],
                          value_binders: [],
                          body: Call(Ref(observe), [Ref(captured)]),
                        },
                        {
                          alt_constructor: Literal(Bool(false)),
                          type_binders: [],
                          value_binders: [],
                          body: Call(Ref(recursive_function), [
                            Call(Ref(sub), [Ref(parameter), Literal(Int(1L))]),
                          ]),
                        },
                      ],
                    }),
                  }),
                },
              ],
              Call(Ref(recursive_function), [Literal(Int(3L))]),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: sub, name: "%i64_sub", type_: sub_type },
          { value: equal, name: "%i64_equal", type_: equal_type },
          {
            value: observe,
            name: "lane.test.observe_recursive",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_eq(image.object_shapes.length(), 1)
  guard image.functions[1] is BytecodeBody(loop_body) else {
    fail("expected lifted recursive bytecode body")
  }
  assert_true(loop_body.inputs.environment is Some(_))
  let has_recursive_tail_call = loop_body.blocks.any(block => {
    block.terminator is TailCallDirect({ value: 2 }, Some(_), [], _)
  })
  assert_true(has_recursive_tail_call)
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_recursive",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "generic identity calls cross explicit representation erasure bridges" {
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
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let result = metadata.define_value("result", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
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
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(TypeApply(Ref(identity), [TypeArgument(int_type)]), [
              Literal(Int(42L)),
            ]),
            Call(Ref(observe), [Ref(result)]),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_generic",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(identity_body) else {
    fail("expected identity bytecode body")
  }
  assert_eq(identity_body.inputs.witnesses.length(), 1)
  assert_eq(identity_body.result, I64)
  guard image.functions[1] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is ConstLayout(_, _)
    }),
  )
  assert_true(
    contains_instruction(main_body, instruction => instruction is EraseI64(_, _)),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is UneraseI64(_, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_generic",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "generic calls adapt callable arguments and callable results" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_type = @buslane.Type::Parameter(type_parameter)
  let generic_callable_type = test_function_type([], generic_type)
  let passthrough_type = @buslane.Type::Forall(
    [type_parameter],
    test_function_type([generic_callable_type], generic_callable_type),
  )
  let callable_parameter = metadata.define_value(
    "callable",
    Parameter,
    generic_callable_type,
  )
  let passthrough = metadata.define_value(
    "passthrough",
    Function,
    passthrough_type,
  )
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_callable_type = test_function_type([], string_type)
  let producer = metadata.define_value(
    "producer",
    Function,
    string_callable_type,
  )
  let measure_type = test_function_type([string_type], int_type)
  let measure = metadata.define_value("measure", External, measure_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let adapted = metadata.define_value("adapted", Local, string_callable_type)
  let produced = metadata.define_value("produced", Local, string_type)
  let measured = metadata.define_value("measured", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
      Let(
        passthrough,
        TypeLambda(
          [type_parameter],
          Function({
            parameters: [callable_parameter],
            result_type: generic_callable_type,
            body: Ref(callable_parameter),
          }),
        ),
      ),
      Let(
        producer,
        Function({
          parameters: [],
          result_type: string_type,
          body: Literal(String("Lane")),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            adapted,
            Call(TypeApply(Ref(passthrough), [TypeArgument(string_type)]), [
              Ref(producer),
            ]),
            Let(
              produced,
              Call(Ref(adapted), []),
              Let(
                measured,
                Call(Ref(measure), [Ref(produced)]),
                Call(Ref(observe), [Ref(measured)]),
              ),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: measure,
            name: "lane.test.generic_string_length",
            type_: measure_type,
          },
          {
            value: observe,
            name: "lane.test.observe_generic_callable",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.generic_string_length",
      abi_major=1,
      parameters=[String],
      result=Int,
      invoke=fn(_context, arguments) {
        guard arguments is [BorrowedString(value)] else { return Int(-1L) }
        Int(value.length().to_int64())
      },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_generic_callable",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 4L)
}

///|
test "generic nested closures capture erased values and layout witnesses" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_type = @buslane.Type::Parameter(type_parameter)
  let generic_callable_type = test_function_type([], generic_type)
  let make_type = @buslane.Type::Forall(
    [type_parameter],
    test_function_type([generic_type], generic_callable_type),
  )
  let captured = metadata.define_value("captured", Parameter, generic_type)
  let make = metadata.define_value("make", Function, make_type)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_callable_type = test_function_type([], string_type)
  let measure_type = test_function_type([string_type], int_type)
  let measure = metadata.define_value("measure", External, measure_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let closure = metadata.define_value("closure", Local, string_callable_type)
  let produced = metadata.define_value("produced", Local, string_type)
  let measured = metadata.define_value("measured", Local, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
      Let(
        make,
        TypeLambda(
          [type_parameter],
          Function({
            parameters: [captured],
            result_type: generic_callable_type,
            body: Function({
              parameters: [],
              result_type: generic_type,
              body: Ref(captured),
            }),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            closure,
            Call(TypeApply(Ref(make), [TypeArgument(string_type)]), [
              Literal(String("Lane")),
            ]),
            Let(
              produced,
              Call(Ref(closure), []),
              Let(
                measured,
                Call(Ref(measure), [Ref(produced)]),
                Call(Ref(observe), [Ref(measured)]),
              ),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: measure,
            name: "lane.test.captured_string_length",
            type_: measure_type,
          },
          {
            value: observe,
            name: "lane.test.observe_generic_capture",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  let observed : Array[Int64] = []
  fn registry(observed : Array[Int64]) -> @loisvm_runtime.RuntimeRegistry {
    let registry = @loisvm_runtime.RuntimeRegistry::new()
    registry.register(
      @loisvm_runtime.RuntimeBinding::new(
        symbol="lane.test.captured_string_length",
        abi_major=1,
        parameters=[String],
        result=Int,
        invoke=fn(_context, arguments) {
          guard arguments is [BorrowedString(value)] else { return Int(-1L) }
          Int(value.length().to_int64())
        },
      ),
    )
    registry.register(
      @loisvm_runtime.RuntimeBinding::new(
        symbol="lane.test.observe_generic_capture",
        abi_major=1,
        parameters=[Int],
        result=Unit,
        invoke=fn(_context, arguments) {
          if arguments is [Int(value)] {
            observed.push(value)
          }
          Unit
        },
      ),
    )
    registry
  }
  let interpreted = match @interp.load(image, registry(observed)) {
    Ok(value) => value
    Err(error) => fail("interpreter load failed: \{to_repr(error)}")
  }
  assert_eq(interpreted.new_instance().execute(), Ok(()))
  assert_eq(observed, [4L])
}

///|
test "single-constructor matches keep owned captures in the current block" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let box = metadata.define_type("Box", [])
  let boxed = metadata.define_data_constructor("Box", box, [], [])
  let box_type = @buslane.Type::Constructor(box)
  let observe_type = test_function_type([], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let continuation = metadata.define_value("continuation", Local, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, box_type)
  let match_binder = metadata.define_value("box", MatchBinder, box_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            continuation,
            Function({
              parameters: [],
              result_type: unit_type,
              body: Call(Ref(observe), []),
            }),
            Let(
              scrutinee,
              Construct({
                data_constructor: boxed,
                type_arguments: [],
                hidden_witnesses: [],
                payloads: [],
              }),
              Match({
                scrutinee: Ref(scrutinee),
                binder: match_binder,
                result_type: unit_type,
                alternatives: [
                  {
                    alt_constructor: DataCon(boxed),
                    type_binders: [],
                    value_binders: [],
                    body: Call(Ref(continuation), []),
                  },
                ],
              }),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          { value: observe, name: "lane.test.single_box", type_: observe_type },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_false(
    main_body.blocks.any(block => block.terminator is SwitchTag(_, _, _)),
  )
  let mut observed = false
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.single_box",
      abi_major=1,
      parameters=[],
      result=Unit,
      invoke=fn(_context, _arguments) {
        observed = true
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_true(observed)
}

///|
test "generic data stores layout witnesses beside erased payloads" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let option = metadata.define_type("Option", [type_parameter])
  let none = metadata.define_data_constructor("None", option, [], [])
  let some = metadata.define_data_constructor("Some", option, [], [
    Parameter(type_parameter),
  ])
  let int_type = @buslane.Type::Primitive(Int)
  let option_int = @buslane.Type::Apply(Constructor(option), [
    TypeArgument(int_type),
  ])
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, option_int)
  let binder = metadata.define_value("option", MatchBinder, option_int)
  let payload = metadata.define_value("payload", MatchBinder, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            scrutinee,
            Construct({
              data_constructor: some,
              type_arguments: [TypeArgument(int_type)],
              hidden_witnesses: [],
              payloads: [Literal(Int(7L))],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(none),
                  type_binders: [],
                  value_binders: [],
                  body: Call(Ref(observe), [Literal(Int(0L))]),
                },
                {
                  alt_constructor: DataCon(some),
                  type_binders: [],
                  value_binders: [payload],
                  body: Call(Ref(observe), [Ref(payload)]),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_generic_data",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.object_shapes.any(shape => {
      shape
      is Data(
        {
          stored_witness_count: 1,
          members: [{ cleanup: OwnedErased, witness_ordinal: Some(0), .. }],
          ..,
        }
      )
    }),
  )
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => instruction is EraseI64(_, _)),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is UneraseI64(_, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_generic_data",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 7L)
}

///|
test "existential data opens hidden witnesses beside erased payloads" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let consumed = metadata.define_type_parameter("Consumed", Type)
  let owner_parameter = metadata.define_type_parameter("Owner", Type)
  let box = metadata.define_type("Box", [owner_parameter])
  let pack = metadata.define_data_constructor("Pack", box, [hidden], [
    Parameter(owner_parameter),
    Parameter(hidden),
  ])
  let int_type = @buslane.Type::Primitive(Int)
  let box_type = @buslane.Type::Apply(Constructor(box), [TypeArgument(int_type)])
  let unit_type = @buslane.Type::Primitive(Unit)
  let consume_type = @buslane.Type::Forall(
    [consumed],
    test_function_type([Parameter(consumed)], unit_type),
  )
  let consume_parameter = metadata.define_value(
    "value",
    Parameter,
    Parameter(consumed),
  )
  let consume = metadata.define_value("consume", Function, consume_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, box_type)
  let match_binder = metadata.define_value("box", MatchBinder, box_type)
  let payload = metadata.define_value("payload", MatchBinder, Parameter(opened))
  let owner_payload = metadata.define_value(
    "owner_payload",
    MatchBinder,
    int_type,
  )
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        consume,
        TypeLambda(
          [consumed],
          Function({
            parameters: [consume_parameter],
            result_type: unit_type,
            body: Call(Ref(observe), [Literal(Int(42L))]),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            scrutinee,
            Construct({
              data_constructor: pack,
              type_arguments: [TypeArgument(int_type)],
              hidden_witnesses: [TypeArgument(int_type)],
              payloads: [Literal(Int(1L)), Literal(Int(7L))],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(pack),
                  type_binders: [opened],
                  value_binders: [owner_payload, payload],
                  body: Call(
                    TypeApply(Ref(consume), [TypeArgument(Parameter(opened))]),
                    [Ref(payload)],
                  ),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_existential_payload",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.object_shapes.any(shape => {
      shape
      is Data(
        {
          stored_witness_count: 2,
          members: [
            { cleanup: OwnedErased, witness_ordinal: Some(0), .. },
            { cleanup: OwnedErased, witness_ordinal: Some(1), .. },
          ],
          ..,
        }
      )
    }),
  )
  guard image.functions[1] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is LoadObjectWitness(_, _, _, 1)
    }),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is BorrowField(_, _, _, { witness_destination: Some(_), .. })
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_existential_payload",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "payload-free existential data still opens its hidden witness" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let probed = metadata.define_type_parameter("Probed", Type)
  let token = metadata.define_type("Token", [])
  let make_token = metadata.define_data_constructor("Token", token, [hidden], [])
  let token_type = @buslane.Type::Constructor(token)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let probe_type = @buslane.Type::Forall(
    [probed],
    test_function_type([], unit_type),
  )
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let probe = metadata.define_value("probe", Function, probe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, token_type)
  let match_binder = metadata.define_value("token", MatchBinder, token_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        probe,
        TypeLambda(
          [probed],
          Function({
            parameters: [],
            result_type: unit_type,
            body: Call(Ref(observe), [Literal(Int(9L))]),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            scrutinee,
            Construct({
              data_constructor: make_token,
              type_arguments: [],
              hidden_witnesses: [TypeArgument(int_type)],
              payloads: [],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(make_token),
                  type_binders: [opened],
                  value_binders: [],
                  body: Call(
                    TypeApply(Ref(probe), [TypeArgument(Parameter(opened))]),
                    [],
                  ),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_existential_witness",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.object_shapes.any(shape => {
      shape is Data({ stored_witness_count: 1, members: [], .. })
    }),
  )
  guard image.functions[1] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is LoadObjectWitness(_, _, _, 0)
    }),
  )
  assert_false(
    contains_instruction(main_body, instruction => {
      instruction is BorrowField(_, _, _, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_existential_witness",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 9L)
}

///|
test "effect-kind existential binders remain fully erased" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("HiddenEffect", Effect)
  let opened = metadata.define_type_parameter("OpenedEffect", Effect)
  let token = metadata.define_type("EffectToken", [])
  let make_token = metadata.define_data_constructor(
    "EffectToken",
    token,
    [hidden],
    [],
  )
  let token_type = @buslane.Type::Constructor(token)
  let unit_type = @buslane.Type::Primitive(Unit)
  let scrutinee = metadata.define_value("scrutinee", Local, token_type)
  let match_binder = metadata.define_value("token", MatchBinder, token_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            scrutinee,
            Construct({
              data_constructor: make_token,
              type_arguments: [],
              hidden_witnesses: [EffectArgument(Empty)],
              payloads: [],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(make_token),
                  type_binders: [opened],
                  value_binders: [],
                  body: Literal(Unit),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(program, { builtins: [] }, {
      module_path_text: "Main",
      name: "main",
      value: main,
      type_: main_type,
    }) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(
    image.object_shapes.any(shape => {
      shape is Data({ stored_witness_count: 0, members: [], .. })
    }),
  )
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_false(
    contains_instruction(main_body, instruction => {
      instruction is LoadObjectWitness(_, _, _, _)
    }),
  )
  let loaded = match
    @interp.load(image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "natural Unit parameters and data fields occupy no runtime slots" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let int_type = @buslane.Type::Primitive(Int)
  let packet = metadata.define_type("Packet", [])
  let packet_constructor = metadata.define_data_constructor(
    "Packet",
    packet,
    [],
    [unit_type, int_type],
  )
  let packet_type = @buslane.Type::Constructor(packet)
  let unit_parameter = metadata.define_value("unit", Parameter, unit_type)
  let packet_parameter = metadata.define_value("packet", Parameter, packet_type)
  let match_binder = metadata.define_value("matched", MatchBinder, packet_type)
  let unit_payload = metadata.define_value(
    "unit_payload",
    MatchBinder,
    unit_type,
  )
  let int_payload = metadata.define_value("int_payload", MatchBinder, int_type)
  let consume_type = test_function_type([unit_type, packet_type], int_type)
  let consume = metadata.define_value("consume", Function, consume_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        consume,
        Function({
          parameters: [unit_parameter, packet_parameter],
          result_type: int_type,
          body: Match({
            scrutinee: Ref(packet_parameter),
            binder: match_binder,
            result_type: int_type,
            alternatives: [
              {
                alt_constructor: DataCon(packet_constructor),
                type_binders: [],
                value_binders: [unit_payload, int_payload],
                body: Ref(int_payload),
              },
            ],
          }),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Call(Ref(observe), [
            Call(Ref(consume), [
              Literal(Unit),
              Construct({
                data_constructor: packet_constructor,
                type_arguments: [],
                hidden_witnesses: [],
                payloads: [Literal(Unit), Literal(Int(42L))],
              }),
            ]),
          ]),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_unit_abi",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(consume_body) else {
    fail("expected consume bytecode body")
  }
  assert_eq(consume_body.inputs.user_parameters.length(), 1)
  assert_true(
    image.object_shapes.any(shape => {
      shape is Data({ members: [{ representation: I64, .. }], .. })
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_unit_abi",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "primitive literal matches lower to comparison decision chains" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let binder = metadata.define_value("matched", MatchBinder, int_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Match({
            scrutinee: Literal(Int(2L)),
            binder,
            result_type: unit_type,
            alternatives: [
              {
                alt_constructor: Literal(Int(1L)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(Int(1L))]),
              },
              {
                alt_constructor: Literal(Int(2L)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(Int(2L))]),
              },
              {
                alt_constructor: Default,
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(Int(0L))]),
              },
            ],
          }),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_literal_match",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => instruction is IntEq(_, _, _)),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_literal_match",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 2L)
}

///|
test "generic nested functions lower as type-applied callable values" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_type = @buslane.Type::Parameter(type_parameter)
  let identity_type = @buslane.Type::Forall(
    [type_parameter],
    test_function_type([generic_type], generic_type),
  )
  let identity_parameter = metadata.define_value(
    "value",
    Parameter,
    generic_type,
  )
  let identity = metadata.define_value("identity", Local, identity_type)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let result = metadata.define_value("result", Local, int_type)
  let observe_type = test_function_type([int_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            identity,
            TypeLambda(
              [type_parameter],
              Function({
                parameters: [identity_parameter],
                result_type: generic_type,
                body: Ref(identity_parameter),
              }),
            ),
            Let(
              result,
              Call(TypeApply(Ref(identity), [TypeArgument(int_type)]), [
                Literal(Int(42L)),
              ]),
              Call(Ref(observe), [Ref(result)]),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: observe,
            name: "lane.test.observe_nested_generic",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is CallValue(_, [_], [_], _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_nested_generic",
      abi_major=1,
      parameters=[Int],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [Int(value)] {
          observed = value
        }
        Unit
      },
    ),
  )
  let loaded = match @interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("load failed: \{to_repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, 42L)
}
