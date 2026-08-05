///|
fn test_function_type(
  parameters : Array[@buslane.Type],
  result : @buslane.Type,
) -> @buslane.Type {
  Function(parameters, result, Empty)
}

///|
fn test_io_function_type(
  parameters : Array[@buslane.Type],
  result : @buslane.Type,
) -> @buslane.Type {
  Function(parameters, result, Io)
}

///|
fn test_generic_callable_type(
  answer : @buslane.TypeParameterId,
  parameters : Array[@buslane.Type],
) -> @buslane.Type {
  Forall([answer], Function(parameters, Parameter(answer), Empty))
}

///|
fn test_companion_application(
  companion : @buslane.TypeParameterId,
  answer : @buslane.TypeParameterId,
  residual : @buslane.Effect,
) -> @buslane.Type {
  Apply(Parameter(companion), [
    TypeArgument(Parameter(answer)),
    EffectArgument(residual),
  ])
}

///|
fn test_host_signature(type_ : @buslane.Type) -> @abi.HostSignature {
  guard type_ is Function(parameters, result, _) else {
    abort("test runtime import must be a function")
  }
  {
    parameters: parameters.map(test_host_value_kind),
    result: test_host_value_kind(result),
  }
}

///|
fn test_host_value_kind(type_ : @buslane.Type) -> @abi.ValueKind {
  match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) => Bool
    Primitive(I64) => I64
    Primitive(F32) => F32
    Primitive(F64) => F64
    Primitive(String) => String
    Constructor(_) => Opaque
    _ => abort("test runtime import must use a direct ABI type")
  }
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
fn lower_test_executable_to_bytecode(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  lower_executable_program_to_bytecode({
    module_path_texts: [],
    program,
    externals,
    entry,
    initializers: [],
    execution_roots: [Entry(entry.value)],
    effect_companions: [],
  })
}

///|
fn test_image_lowerer(
  metadata : @buslane.MetadataRegistry,
  effect_companions : Array[@effect_lowering_cps.EffectCompanionBinding],
) -> ImageLowerer {
  {
    metadata,
    externals: { builtins: [], runtime_imports: [] },
    globals: [],
    instance_globals: [],
    plans: [],
    constants: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    callable_adapters: [],
    effect_companions,
    next_synthetic_parameter: -1,
  }
}

///|
fn test_function_lowerer(image : ImageLowerer) -> FunctionLowerer {
  {
    image,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: TypeSubstitution(),
  }
}

///|
test "pure scalar Buslane lowers through ANF into executable LoisVM bytecode" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([i64_type, i64_type], i64_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let parameter = metadata.define_value("value", Parameter, i64_type)
  let helper_type = test_function_type([i64_type], i64_type)
  let helper = metadata.define_value("add_one", Function, helper_type)
  let result = metadata.define_value("result", Local, i64_type)
  let matched = metadata.define_value("matched", MatchBinder, i64_type)
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
          result_type: i64_type,
          body: Call(Ref(add), [Ref(parameter), Literal(I64(1L))]),
        }),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(Ref(helper), [Literal(I64(41L))]),
            Match({
              scrutinee: Ref(result),
              binder: matched,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: Default,
                  type_binders: [],
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
    lower_test_executable_to_bytecode(
      program,
      {
        builtins: [{ value: add, intrinsic: I64Add, type_: add_type }],
        runtime_imports: [],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(image.entry, { value: 2 })
  guard image.functions is [BytecodeBody(helper_body), BytecodeBody(main_body)] else {
    fail("expected two bytecode bodies")
  }
  assert_true(
    contains_instruction(helper_body, instruction => {
      instruction is I64Add(_, _, _)
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
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "runtime import origin wins over intrinsic-looking symbol" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let import_type = test_io_function_type([i64_type, i64_type], i64_type)
  let import_ = metadata.define_value("host_add", External, import_type)
  let result = metadata.define_value("result", Local, i64_type)
  let main_type = test_io_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(import_),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            result,
            Call(Ref(import_), [Literal(I64(20L)), Literal(I64(22L))]),
            Literal(Unit),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: import_,
            symbol: "%i64_add",
            signature: test_host_signature(import_type),
            type_: import_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions is [BytecodeBody(_), RuntimeImport(import_)] else {
    fail("expected entry body and one runtime import")
  }
  debug_inspect(
    import_,
    content=(
      #|{
      #|  abi_major: 1,
      #|  parameters: [I64, I64],
      #|  result: I64,
      #|  symbol: "%i64_add",
      #|}
    ),
  )
}

///|
test "scalar intrinsics materialize as deduplicated first-class wrappers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([i64_type, i64_type], i64_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let callable = metadata.define_value("callable", Parameter, add_type)
  let other_callable = metadata.define_value(
    "other_callable",
    Parameter,
    add_type,
  )
  let left = metadata.define_value("left", Parameter, i64_type)
  let right = metadata.define_value("right", Parameter, i64_type)
  let apply_type = test_function_type(
    [add_type, add_type, i64_type, i64_type],
    i64_type,
  )
  let apply = metadata.define_value("apply", Function, apply_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let result = metadata.define_value("result", Local, i64_type)
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
          result_type: i64_type,
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
              Literal(I64(20L)),
              Literal(I64(22L)),
            ]),
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
        builtins: [{ value: add, intrinsic: I64Add, type_: add_type }],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_intrinsic_value",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
  assert_true(apply_body.blocks[0].terminator is TailCallValue(_, _, [], _))
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is ConstFunction(_, { value: 3 })
    }),
  )
  assert_true(
    contains_instruction(wrapper_body, instruction => {
      instruction is I64Add(_, _, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_intrinsic_value",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "effect forms fail before bytecode emission" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect = metadata.define_effect("Test", [])
  let operation = metadata.define_operation("run", effect, [], [], unit_type)
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
            payloads: [],
          }),
        }),
      ),
    ],
  }
  debug_inspect(
    lower_linked_program_to_bytecode(
      program,
      { builtins: [], runtime_imports: [] },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ),
    content=(
      #|Err(
      #|  InvalidFunctionType(
      #|    value={ index: 0 },
      #|    type_=Function([], Primitive(Unit), Singleton({ index: 0 }, [])),
      #|  ),
      #|)
    ),
  )
}

///|
test "lexical handlers and resume lower before LoisVM bytecode" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let effect = metadata.define_effect("Choose", [])
  let operation = metadata.define_operation("choose", effect, [], [], i64_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let selected = metadata.define_value("selected", Local, i64_type)
  let handler_result = metadata.define_value("result", Local, unit_type)
  let resume_binder = metadata.define_value(
    "resume",
    Parameter,
    Function([i64_type], unit_type, Empty),
  )
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
          body: Handle({
            body: Let(
              selected,
              Perform({
                operation,
                effect_arguments: [],
                hidden_witnesses: [],
                payloads: [],
              }),
              Call(Ref(observe), [Ref(selected)]),
            ),
            result_binder: handler_result,
            result_type: unit_type,
            final_body: Ref(handler_result),
            handlers: [
              {
                handled_effect: Singleton(effect, []),
                operations: [
                  {
                    operation,
                    type_binders: [],
                    payload_binders: [],
                    resume_binder,
                    body: Call(Resume(resume_binder), [Literal(I64(42L))]),
                  },
                ],
              },
            ],
          }),
        }),
      ),
    ],
  }
  assert_true(@buslane.verify_program(program).is_ok())
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_handled_value",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_handled_value",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "primitive external functions become runtime imports" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([i64_type], unit_type)
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
          body: Call(Ref(observe), [Literal(I64(42L))]),
        }),
      ),
    ],
  }
  let image = match
    lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_true(
    image.functions
    is [
      BytecodeBody(_),
      RuntimeImport(
        {
          abi_major: 1,
          parameters: [I64],
          result: Unit,
          symbol: "lane.test.observe",
        }
      ),
    ],
  )
  assert_eq(image.layouts, [])
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "external host types erase to Opaque runtime import kinds" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let fd = metadata.define_type("Fd", [], flavor=External)
  let fd_type = @buslane.Type::Constructor(fd)
  let unit_type = @buslane.Type::Primitive(Unit)
  let open_type = test_function_type([], fd_type)
  let close_type = test_function_type([fd_type], unit_type)
  let open = metadata.define_value("open", External, open_type)
  let close = metadata.define_value("close", External, close_type)
  let handle = metadata.define_value("handle", Local, fd_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let image = match
    lower_linked_program_to_bytecode(
      {
        metadata,
        terms: [
          External(open),
          External(close),
          Let(
            main,
            Function({
              parameters: [],
              result_type: unit_type,
              body: Let(
                handle,
                Call(Ref(open), []),
                Call(Ref(close), [Ref(handle)]),
              ),
            }),
          ),
        ],
      },
      {
        builtins: [],
        runtime_imports: [
          {
            value: open,
            symbol: "lane.test.open",
            signature: test_host_signature(open_type),
            type_: open_type,
          },
          {
            value: close,
            symbol: "lane.test.close",
            signature: test_host_signature(close_type),
            type_: close_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  debug_inspect(
    (
      image.layouts,
      image.functions.filter_map(fn(entry) {
        match entry {
          RuntimeImport(import_) => Some(import_)
          BytecodeBody(_) => None
        }
      }),
    ),
    content=(
      #|(
      #|  [Reference],
      #|  [
      #|    {
      #|      abi_major: 1,
      #|      parameters: [],
      #|      result: Opaque,
      #|      symbol: "lane.test.open",
      #|    },
      #|    {
      #|      abi_major: 1,
      #|      parameters: [Opaque],
      #|      result: Unit,
      #|      symbol: "lane.test.close",
      #|    },
      #|  ],
      #|)
    ),
  )
}

///|
test "runtime imports are deduplicated and sorted after bytecode bodies" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let import_type = test_io_function_type([], unit_type)
  let z_first = metadata.define_value("z_first", External, import_type)
  let a = metadata.define_value("a", External, import_type)
  let z_second = metadata.define_value("z_second", External, import_type)
  let first = metadata.define_value("first", Local, unit_type)
  let second = metadata.define_value("second", Local, unit_type)
  let main_type = test_io_function_type([], unit_type)
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
        builtins: [],
        runtime_imports: [
          {
            value: z_first,
            symbol: "lane.test.z",
            signature: test_host_signature(import_type),
            type_: import_type,
          },
          {
            value: a,
            symbol: "lane.test.a",
            signature: test_host_signature(import_type),
            type_: import_type,
          },
          {
            value: z_second,
            symbol: "lane.test.z",
            signature: test_host_signature(import_type),
            type_: import_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
test "runtime imports with equal symbols and distinct kinds remain distinct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let i64_import_type = test_io_function_type([Primitive(I64)], unit_type)
  let bool_import_type = test_io_function_type([Primitive(Bool)], unit_type)
  let i64_import = metadata.define_value(
    "observe_int",
    External,
    i64_import_type,
  )
  let bool_import = metadata.define_value(
    "observe_bool",
    External,
    bool_import_type,
  )
  let first = metadata.define_value("first", Local, unit_type)
  let main_type = test_io_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let image = match
    lower_linked_program_to_bytecode(
      {
        metadata,
        terms: [
          External(i64_import),
          External(bool_import),
          Let(
            main,
            Function({
              parameters: [],
              result_type: unit_type,
              body: Let(
                first,
                Call(Ref(i64_import), [Literal(I64(1L))]),
                Call(Ref(bool_import), [Literal(Bool(true))]),
              ),
            }),
          ),
        ],
      },
      {
        builtins: [],
        runtime_imports: [
          {
            value: i64_import,
            symbol: "lane.test.observe",
            signature: test_host_signature(i64_import_type),
            type_: i64_import_type,
          },
          {
            value: bool_import,
            symbol: "lane.test.observe",
            signature: test_host_signature(bool_import_type),
            type_: bool_import_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  debug_inspect(
    image.functions.filter_map(fn(entry) {
      match entry {
        RuntimeImport(import_) => Some(import_)
        BytecodeBody(_) => None
      }
    }),
    content=(
      #|[
      #|  {
      #|    abi_major: 1,
      #|    parameters: [Bool],
      #|    result: Unit,
      #|    symbol: "lane.test.observe",
      #|  },
      #|  {
      #|    abi_major: 1,
      #|    parameters: [I64],
      #|    result: Unit,
      #|    symbol: "lane.test.observe",
      #|  },
      #|]
    ),
  )
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
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_string",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  assert_eq(observed, "Lane")
}

///|
test "Bool matches lower to explicit CFG branches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let bool_type = @buslane.Type::Primitive(Bool)
  let read_type = test_function_type([], bool_type)
  let read = metadata.define_value("read", External, read_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let binder = metadata.define_value("condition", MatchBinder, bool_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(read),
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Match({
            scrutinee: Call(Ref(read), []),
            binder,
            result_type: unit_type,
            alternatives: [
              {
                alt_constructor: Literal(Bool(true)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(I64(1L))]),
              },
              {
                alt_constructor: Literal(Bool(false)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(I64(2L))]),
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
        builtins: [],
        runtime_imports: [
          {
            value: read,
            symbol: "lane.test.read_branch",
            signature: test_host_signature(read_type),
            type_: read_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_branch",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_eq(main_body.blocks.length(), 3)
  assert_true(main_body.blocks[0].terminator is BranchBool(_, _, _))
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.read_branch",
      abi_major=1,
      parameters=[],
      result=Bool,
      invoke=fn(_context, _arguments) { Bool(true) },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_branch",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 1L)
}

///|
test "non-generic data construction and matching lower through object shapes" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let option = metadata.define_type("OptionInt", [])
  let none = metadata.define_data_constructor("None", option, [], [])
  let some = metadata.define_data_constructor("Some", option, [], [i64_type])
  let option_type = @buslane.Type::Constructor(option)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, option_type)
  let binder = metadata.define_value("option", MatchBinder, option_type)
  let payload = metadata.define_value("payload", MatchBinder, i64_type)
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
              payloads: [Literal(I64(7L))],
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
                  body: Call(Ref(observe), [Literal(I64(0L))]),
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
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_data",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 7L)
}

///|
test "capture-free functions lower as callable values for higher-order calls" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([i64_type, i64_type], i64_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let increment_parameter = metadata.define_value("value", Parameter, i64_type)
  let increment_type = test_function_type([i64_type], i64_type)
  let increment = metadata.define_value("increment", Function, increment_type)
  let callable_parameter = metadata.define_value(
    "callable",
    Parameter,
    increment_type,
  )
  let apply_parameter = metadata.define_value("value", Parameter, i64_type)
  let apply_type = test_function_type([increment_type, i64_type], i64_type)
  let apply = metadata.define_value("apply", Function, apply_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let result = metadata.define_value("result", Local, i64_type)
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
          result_type: i64_type,
          body: Call(Ref(add), [Ref(increment_parameter), Literal(I64(1L))]),
        }),
      ),
      Let(
        apply,
        Function({
          parameters: [callable_parameter, apply_parameter],
          result_type: i64_type,
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
            Call(Ref(apply), [Ref(increment), Literal(I64(41L))]),
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
        builtins: [{ value: add, intrinsic: I64Add, type_: add_type }],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_higher_order",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[1] is BytecodeBody(apply_body) else {
    fail("expected apply bytecode body")
  }
  assert_true(apply_body.blocks[0].terminator is TailCallValue(_, _, [], _))
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "nested functions lift with explicit reference-counted environments" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let add_type = test_function_type([i64_type, i64_type], i64_type)
  let add = metadata.define_value("%i64_add", External, add_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let captured = metadata.define_value("captured", Local, i64_type)
  let parameter = metadata.define_value("argument", Parameter, i64_type)
  let closure_type = test_function_type([i64_type], i64_type)
  let closure = metadata.define_value("closure", Local, closure_type)
  let result = metadata.define_value("result", Local, i64_type)
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
            Call(Ref(add), [Literal(I64(40L)), Literal(I64(0L))]),
            Let(
              closure,
              Function({
                parameters: [parameter],
                result_type: i64_type,
                body: Call(Ref(add), [Ref(captured), Ref(parameter)]),
              }),
              Let(
                result,
                Call(Ref(closure), [Literal(I64(2L))]),
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
        builtins: [{ value: add, intrinsic: I64Add, type_: add_type }],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_closure",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "local recursive functions share a cycle-free captured environment" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let bool_type = @buslane.Type::Primitive(Bool)
  let unit_type = @buslane.Type::Primitive(Unit)
  let sub_type = test_function_type([i64_type, i64_type], i64_type)
  let sub = metadata.define_value("%i64_sub", External, sub_type)
  let equal_type = test_function_type([i64_type, i64_type], bool_type)
  let equal = metadata.define_value("%i64_equal", External, equal_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let captured = metadata.define_value("captured", Local, i64_type)
  let parameter = metadata.define_value("remaining", Parameter, i64_type)
  let condition = metadata.define_value("done", MatchBinder, bool_type)
  let recursive_type = test_function_type([i64_type], unit_type)
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
            Call(Ref(sub), [Literal(I64(43L)), Literal(I64(1L))]),
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
                        Literal(I64(0L)),
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
                            Call(Ref(sub), [Ref(parameter), Literal(I64(1L))]),
                          ]),
                        },
                      ],
                    }),
                  }),
                },
              ],
              Call(Ref(recursive_function), [Literal(I64(3L))]),
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
          { value: sub, intrinsic: I64Sub, type_: sub_type },
          { value: equal, intrinsic: I64Equal, type_: equal_type },
        ],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_recursive",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let apply_function = metadata.define_value(
    "function",
    Parameter,
    identity_type,
  )
  let apply_value = metadata.define_value("argument", Parameter, i64_type)
  let apply_type = test_function_type([identity_type, i64_type], i64_type)
  let apply = metadata.define_value("apply", Function, apply_type)
  let result = metadata.define_value("result", Local, i64_type)
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
        apply,
        Function({
          parameters: [apply_function, apply_value],
          result_type: i64_type,
          body: Call(TypeApply(Ref(apply_function), [TypeArgument(i64_type)]), [
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
            Call(Ref(apply), [Ref(identity), Literal(I64(42L))]),
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
            symbol: "lane.test.observe_generic",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(identity_body) else {
    fail("expected identity bytecode body")
  }
  assert_eq(identity_body.inputs.witnesses.length(), 1)
  assert_eq(identity_body.result, Value(I64, OwnedErased))
  guard image.functions[1] is BytecodeBody(apply_body) else {
    fail("expected apply bytecode body")
  }
  assert_true(
    contains_instruction(apply_body, instruction => {
      instruction is ConstLayout(_, _)
    }),
  )
  assert_true(
    contains_instruction(apply_body, instruction => {
      instruction is EraseI64(_, _)
    }),
  )
  assert_true(
    contains_instruction(apply_body, instruction => {
      instruction is UneraseI64(_, _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_generic",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_callable_type = test_function_type([], string_type)
  let producer = metadata.define_value(
    "producer",
    Function,
    string_callable_type,
  )
  let measure_type = test_function_type([string_type], i64_type)
  let measure = metadata.define_value("measure", External, measure_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let adapted = metadata.define_value("adapted", Local, string_callable_type)
  let produced = metadata.define_value("produced", Local, string_type)
  let measured = metadata.define_value("measured", Local, i64_type)
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
        builtins: [],
        runtime_imports: [
          {
            value: measure,
            symbol: "lane.test.generic_string_length",
            signature: test_host_signature(measure_type),
            type_: measure_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_generic_callable",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.generic_string_length",
      abi_major=1,
      parameters=[String],
      result=I64,
      invoke=fn(_context, arguments) {
        guard arguments is [BorrowedString(value)] else { return I64(-1L) }
        I64(value.length().to_int64())
      },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_generic_callable",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_callable_type = test_function_type([], string_type)
  let measure_type = test_function_type([string_type], i64_type)
  let measure = metadata.define_value("measure", External, measure_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let closure = metadata.define_value("closure", Local, string_callable_type)
  let produced = metadata.define_value("produced", Local, string_type)
  let measured = metadata.define_value("measured", Local, i64_type)
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
        builtins: [],
        runtime_imports: [
          {
            value: measure,
            symbol: "lane.test.captured_string_length",
            signature: test_host_signature(measure_type),
            type_: measure_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_generic_capture",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  let observed : Array[Int64] = []
  fn registry(observed : Array[Int64]) -> @loisvm_runtime.RuntimeRegistry {
    let registry = @loisvm_runtime.RuntimeRegistry::new()
    registry.register(
      @loisvm_runtime.RuntimeBinding::new(
        symbol="lane.test.captured_string_length",
        abi_major=1,
        parameters=[String],
        result=I64,
        invoke=fn(_context, arguments) {
          guard arguments is [BorrowedString(value)] else { return I64(-1L) }
          I64(value.length().to_int64())
        },
      ),
    )
    registry.register(
      @loisvm_runtime.RuntimeBinding::new(
        symbol="lane.test.observe_generic_capture",
        abi_major=1,
        parameters=[I64],
        result=Unit,
        invoke=fn(_context, arguments) {
          if arguments is [I64(value)] {
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
    Err(error) => fail("interpreter load failed: \{Repr(error)}")
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
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.single_box",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
    Err(error) => fail("load failed: \{Repr(error)}")
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
  let i64_type = @buslane.Type::Primitive(I64)
  let option_int = @buslane.Type::Apply(Constructor(option), [
    TypeArgument(i64_type),
  ])
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, option_int)
  let binder = metadata.define_value("option", MatchBinder, option_int)
  let payload = metadata.define_value("payload", MatchBinder, i64_type)
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
              type_arguments: [TypeArgument(i64_type)],
              hidden_witnesses: [],
              payloads: [Literal(I64(7L))],
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
                  body: Call(Ref(observe), [Literal(I64(0L))]),
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
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_generic_data",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  let i64_type = @buslane.Type::Primitive(I64)
  let box_type = @buslane.Type::Apply(Constructor(box), [TypeArgument(i64_type)])
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
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, box_type)
  let match_binder = metadata.define_value("box", MatchBinder, box_type)
  let payload = metadata.define_value("payload", MatchBinder, Parameter(opened))
  let owner_payload = metadata.define_value(
    "owner_payload",
    MatchBinder,
    i64_type,
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
            body: Call(Ref(observe), [Literal(I64(42L))]),
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
              type_arguments: [TypeArgument(i64_type)],
              hidden_witnesses: [TypeArgument(i64_type)],
              payloads: [Literal(I64(1L)), Literal(I64(7L))],
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
    lower_test_executable_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_existential_payload",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let probe_type = @buslane.Type::Forall(
    [probed],
    test_function_type([], unit_type),
  )
  let observe_type = test_function_type([i64_type], unit_type)
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
            body: Call(Ref(observe), [Literal(I64(9L))]),
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
              hidden_witnesses: [TypeArgument(i64_type)],
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
    lower_test_executable_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_existential_witness",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
    lower_linked_program_to_bytecode(
      program,
      { builtins: [], runtime_imports: [] },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
}

///|
test "natural Unit parameters and data fields occupy no runtime slots" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let i64_type = @buslane.Type::Primitive(I64)
  let packet = metadata.define_type("Packet", [])
  let packet_constructor = metadata.define_data_constructor(
    "Packet",
    packet,
    [],
    [unit_type, i64_type],
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
  let i64_payload = metadata.define_value("i64_payload", MatchBinder, i64_type)
  let consume_type = test_function_type([unit_type, packet_type], i64_type)
  let consume = metadata.define_value("consume", Function, consume_type)
  let observe_type = test_function_type([i64_type], unit_type)
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
          result_type: i64_type,
          body: Match({
            scrutinee: Ref(packet_parameter),
            binder: match_binder,
            result_type: i64_type,
            alternatives: [
              {
                alt_constructor: DataCon(packet_constructor),
                type_binders: [],
                value_binders: [unit_payload, i64_payload],
                body: Ref(i64_payload),
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
                payloads: [Literal(Unit), Literal(I64(42L))],
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
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_unit_abi",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
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
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "primitive literal matches lower to comparison decision chains" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let read_type = test_function_type([], i64_type)
  let read = metadata.define_value("read", External, read_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let binder = metadata.define_value("matched", MatchBinder, i64_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(read),
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Match({
            scrutinee: Call(Ref(read), []),
            binder,
            result_type: unit_type,
            alternatives: [
              {
                alt_constructor: Literal(I64(1L)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(I64(1L))]),
              },
              {
                alt_constructor: Literal(I64(2L)),
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(I64(2L))]),
              },
              {
                alt_constructor: Default,
                type_binders: [],
                value_binders: [],
                body: Call(Ref(observe), [Literal(I64(0L))]),
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
        builtins: [],
        runtime_imports: [
          {
            value: read,
            symbol: "lane.test.read_literal_match",
            signature: test_host_signature(read_type),
            type_: read_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_literal_match",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => instruction is I64Eq(_, _, _)),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.read_literal_match",
      abi_major=1,
      parameters=[],
      result=I64,
      invoke=fn(_context, _arguments) { I64(2L) },
    ),
  )
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_literal_match",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let result = metadata.define_value("result", Local, i64_type)
  let observe_type = test_function_type([i64_type], unit_type)
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
              Call(TypeApply(Ref(identity), [TypeArgument(i64_type)]), [
                Literal(I64(42L)),
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
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            symbol: "lane.test.observe_nested_generic",
            signature: test_host_signature(observe_type),
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is BytecodeBody(main_body) else {
    fail("expected main bytecode body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is CallValue(_, _, [_], [_], _)
    }),
  )
  let mut observed = 0L
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.observe_nested_generic",
      abi_major=1,
      parameters=[I64],
      result=Unit,
      invoke=fn(_context, arguments) {
        if arguments is [I64(value)] {
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
  assert_eq(observed, 42L)
}

///|
test "function type parts collect every nested forall layer" {
  let outer : @buslane.TypeParameterId = { index: 100 }
  let inner : @buslane.TypeParameterId = { index: 101 }
  assert_eq(
    function_type_parts(
      Forall(
        [outer],
        Forall([inner], Function([Parameter(outer)], Parameter(inner), Empty)),
      ),
    ),
    ([outer, inner], [Parameter(outer)], Parameter(inner)),
  )
}

///|
test "adapter witness does not infer layout from a source effect" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let source = metadata.define_type_parameter("E", Effect)
  let companion = metadata.define_type_parameter(
    "E%context",
    Function([Type, Effect], Type),
  )
  let source_residual = metadata.define_type_parameter(
    "E%residual",
    Effect,
    flavor=External,
  )
  let image = test_image_lowerer(metadata, [
    { source, companion, residual: source_residual },
  ])
  let lowerer = test_function_lowerer(image)
  let substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  substitutions.insert_effect(source, Io)
  try lowerer.adapter_witness(companion, substitutions) catch {
    InvalidTypeApplication(detail~) =>
      assert_eq(
        detail,
        "missing in-scope layout witness for \{Repr(companion)}",
      )
    error => fail("unexpected lowering error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing companion layout witness")
  }
}

///|
test "concrete companion substitution determines its layout witness" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let source = metadata.define_type_parameter("E", Effect)
  let companion = metadata.define_type_parameter(
    "E%context",
    Function([Type, Effect], Type),
  )
  let source_residual = metadata.define_type_parameter(
    "E%residual",
    Effect,
    flavor=External,
  )
  let answer = metadata.define_type_parameter("Answer", Type)
  let residual = metadata.define_type_parameter("Residual", Effect)
  let image = test_image_lowerer(metadata, [
    { source, companion, residual: source_residual },
  ])
  let lowerer = test_function_lowerer(image)
  let substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  substitutions.insert(
    companion,
    TypeLambda([answer, residual], Primitive(Unit)),
  )
  let witness = lowerer.adapter_witness(companion, substitutions)
  debug_inspect(
    (
      witness,
      image.layouts,
      image.callable_adapters,
      lowerer.blocks[0].instructions,
    ),
    content=(
      #|({ value: 0 }, [Unit], [], [ConstLayout({ value: 0 }, { value: 1 })])
    ),
  )
}

///|
test "forwarded companion substitution reuses the outer layout witness" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let formal_source = metadata.define_type_parameter("FormalE", Effect)
  let formal_companion = metadata.define_type_parameter(
    "FormalE%context",
    Function([Type, Effect], Type),
  )
  let actual_source = metadata.define_type_parameter("ActualE", Effect)
  let actual_companion = metadata.define_type_parameter(
    "ActualE%context",
    Function([Type, Effect], Type),
  )
  let formal_residual = metadata.define_type_parameter(
    "FormalE%residual",
    Effect,
    flavor=External,
  )
  let actual_residual = metadata.define_type_parameter(
    "ActualE%residual",
    Effect,
    flavor=External,
  )
  let source_answer = metadata.define_type_parameter("SourceAnswer", Type)
  let target_answer = metadata.define_type_parameter("TargetAnswer", Type)
  let image = test_image_lowerer(metadata, [
    {
      source: formal_source,
      companion: formal_companion,
      residual: formal_residual,
    },
    {
      source: actual_source,
      companion: actual_companion,
      residual: actual_residual,
    },
  ])
  let lowerer = test_function_lowerer(image)
  let outer_witness : @vmcfg.ValueId = { value: 17 }
  lowerer.witnesses.push({ parameter: actual_companion, value: outer_witness })
  let substitutions = lowerer.call_type_substitution(
    [formal_companion, formal_residual],
    [
      TypeArgument(Parameter(actual_companion)),
      EffectArgument(Parameter(actual_residual)),
    ],
  )
  assert_eq(
    substitutions.type_argument(formal_companion),
    Some(Parameter(actual_companion)),
  )
  assert_eq(
    substitutions.effect_argument(formal_source),
    Some(Parameter(actual_source)),
  )
  assert_eq(
    substitutions.effect_argument(formal_residual),
    Some(Parameter(actual_residual)),
  )
  let source_context = test_companion_application(
    actual_companion,
    source_answer,
    Parameter(actual_residual),
  )
  let target_context = test_companion_application(
    formal_companion,
    target_answer,
    Parameter(formal_residual),
  )
  let (targets, _) = image.align_callable_parameters(
    test_generic_callable_type(source_answer, [source_context]),
    test_generic_callable_type(target_answer, [target_context]),
    substitutions,
  )
  assert_eq(targets, [0])
  assert_eq(
    lowerer.adapter_witness(formal_companion, substitutions),
    outer_witness,
  )
  assert_true(lowerer.blocks[0].instructions.is_empty())
}

///|
test "callable adapter owns its final substitution" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let source = metadata.define_type_parameter("E", Effect)
  let companion = metadata.define_type_parameter(
    "E%context",
    Function([Type, Effect], Type),
  )
  let source_residual = metadata.define_type_parameter(
    "E%residual",
    Effect,
    flavor=External,
  )
  let companion_answer = metadata.define_type_parameter("Answer", Type)
  let companion_residual = metadata.define_type_parameter("Residual", Effect)
  let dictionary_type : @buslane.Type = Constructor(
    metadata.define_type("Dictionary", []),
  )
  let image = test_image_lowerer(metadata, [
    { source, companion, residual: source_residual },
  ])
  let lowerer = test_function_lowerer(image)
  let companion_type : @buslane.Type = Apply(Parameter(companion), [
    TypeArgument(Primitive(I64)),
    EffectArgument(Parameter(source_residual)),
  ])
  let source_type : @buslane.Type = Function(
    [companion_type],
    Primitive(Unit),
    Empty,
  )
  let target_type : @buslane.Type = Function(
    [dictionary_type, Primitive(Unit)],
    Primitive(Unit),
    Empty,
  )
  let substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  substitutions.insert(
    companion,
    TypeLambda([companion_answer, companion_residual], dictionary_type),
  )
  let callable = lowerer.fresh_slot(source_type)
  ignore(
    lowerer.make_callable_adapter(
      callable, source_type, target_type, substitutions,
    ),
  )
  guard image.callable_adapters is [plan] else {
    fail("expected one callable adapter plan")
  }
  let body = image.lower_callable_adapter(plan)
  debug_inspect(
    (
      image.layouts,
      image.callable_adapters,
      lowerer.blocks[0].instructions,
      body.blocks,
    ),
    content=(
      #|(
      #|  [Reference, Environment({ value: 0 })],
      #|  [
      #|    {
      #|      function: { value: 1 },
      #|      source_type: Function(
      #|        [
      #|          Apply(
      #|            Parameter({ index: 1 }),
      #|            [
      #|              TypeArgument(Primitive(I64)),
      #|              EffectArgument(Parameter({ index: 2 })),
      #|            ],
      #|          ),
      #|        ],
      #|        Primitive(Unit),
      #|        Empty,
      #|      ),
      #|      target_type: Function(
      #|        [Constructor({ index: 0 }), Primitive(Unit)],
      #|        Primitive(Unit),
      #|        Empty,
      #|      ),
      #|      source_parameter_targets: [0],
      #|      substitutions: {
      #|        entries: [
      #|          {
      #|            parameter: { index: 1 },
      #|            replacement: TypeArgument(TypeLambda([{ index: 3 }, { index: 4 }], Constructor({ index: 0 }))),
      #|          },
      #|        ],
      #|      },
      #|      captured_parameters: [{ index: 1 }],
      #|      environment_shape: { value: 0 },
      #|    },
      #|  ],
      #|  [
      #|    ConstLayout({ value: 1 }, { value: 1 }),
      #|    MakeEnv(
      #|      { value: 2 },
      #|      { value: 0 },
      #|      Immediate({ value: 2 }),
      #|      [{ value: 1 }],
      #|      [{ value: 0 }],
      #|    ),
      #|    MakeClosure({ value: 3 }, { value: 1 }, { value: 2 }),
      #|  ],
      #|  [
      #|    {
      #|      parameters: [],
      #|      instructions: [
      #|        LoadObjectWitness({ value: 1 }, { value: 0 }, { value: 0 }, 0),
      #|        BorrowCapture(
      #|          { value: 0 },
      #|          { value: 0 },
      #|          0,
      #|          { value_destination: { value: 2 }, witness_destination: None },
      #|        ),
      #|        ConstLayout({ value: 4 }, { value: 1 }),
      #|        EraseI32({ value: 5 }, { value: 3 }),
      #|      ],
      #|      terminator: TailCallValue({ value: 2 }, [], [{ value: 5 }]),
      #|    },
      #|  ],
      #|)
    ),
  )
}

///|
test "local value types override substituted formal types during adaptation" {
  let slot : @vmcfg.ValueId = { value: 7 }
  let function : @bytecode.FunctionId = { value: 3 }
  let concrete = @buslane.Type::Apply(Constructor({ index: 4 }), [])
  assert_eq(local_value_type(Slot(slot, concrete)), Some(concrete))
  assert_eq(
    local_value_type(Global(Function(function, concrete))),
    Some(concrete),
  )
  assert_eq(local_value_type(Unit), None)
}

///|
test "value adaptation applies higher-kinded substitutions before classifying representation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let capability = metadata.define_type_parameter("C", Function([Type], Type))
  let element = metadata.define_type_parameter("T", Type)
  let image = test_image_lowerer(metadata, [])
  let lowerer = test_function_lowerer(image)
  let source_type : @buslane.Type = Function(
    [Primitive(Unit)],
    Primitive(String),
    Empty,
  )
  let target_type : @buslane.Type = Apply(Parameter(capability), [
    TypeArgument(Primitive(Unit)),
  ])
  let substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  substitutions.insert(
    capability,
    TypeLambda(
      [element],
      Function([Parameter(element)], Primitive(String), Empty),
    ),
  )
  let slot = lowerer.fresh_slot(source_type)
  let adapted = lowerer.adapt_local_value_with_substitutions(
    Slot(slot, source_type),
    source_type,
    target_type,
    substitutions,
  )
  guard adapted is Slot(adapted_slot, adapted_type) else {
    fail("expected substituted callable adaptation to preserve the slot")
  }
  assert_eq(adapted_slot, slot)
  assert_true(image.types_definitionally_equal(adapted_type, source_type))
  assert_true(image.callable_adapters.is_empty())
  assert_true(lowerer.blocks[0].instructions.is_empty())
}

///|
test "ordinary calls adapt erased slots to concrete parameters" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let image = test_image_lowerer(metadata, [])
  let callable_type : @buslane.Type = Function(
    [Primitive(String)],
    Primitive(Unit),
    Empty,
  )
  let value_lowerer = test_function_lowerer(image)
  let value_witness = value_lowerer.fresh_metadata(layout_witness_metadata())
  let value_erased = value_lowerer.fresh_erased_slot(value_witness, Owned)
  let callable = value_lowerer.fresh_slot(callable_type)
  let value_result = value_lowerer.lower_value_call(callable, callable_type, [
    Slot(value_erased, Primitive(String)),
  ])
  assert_true(value_result is Unit)
  let direct_lowerer = test_function_lowerer(image)
  let direct_witness = direct_lowerer.fresh_metadata(layout_witness_metadata())
  let direct_erased = direct_lowerer.fresh_erased_slot(direct_witness, Owned)
  let direct_result = direct_lowerer.lower_direct_call(
    { value: 7 },
    callable_type,
    [Slot(direct_erased, Primitive(String))],
    None,
  )
  assert_true(direct_result is Unit)
  debug_inspect(
    (
      value_lowerer.blocks[0].instructions,
      direct_lowerer.blocks[0].instructions,
    ),
    content=(
      #|(
      #|  [
      #|    UneraseI32({ value: 3 }, { value: 1 }),
      #|    CallValue({ value: 2 }, [], [{ value: 3 }], None),
      #|  ],
      #|  [
      #|    UneraseI32({ value: 2 }, { value: 1 }),
      #|    CallDirect({ value: 7 }, None, [], [{ value: 2 }], None),
      #|  ],
      #|)
    ),
  )
}

///|
test "callable ABI comparison preserves nested formal erasure" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let image = test_image_lowerer(metadata, [])
  let source_type : @buslane.Type = Function(
    [Function([Primitive(Unit)], Primitive(String), Empty)],
    Primitive(Unit),
    Empty,
  )
  let target_type : @buslane.Type = Function(
    [Function([Parameter(parameter)], Primitive(String), Empty)],
    Primitive(Unit),
    Empty,
  )
  let substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  substitutions.insert(parameter, Primitive(Unit))
  assert_false(
    image.callable_types_share_runtime_abi(
      source_type, target_type, substitutions,
    ),
  )
}

///|
test "callable adapter alignment beta-reduces effect companions" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let source_answer = metadata.define_type_parameter("SourceAnswer", Type)
  let target_answer = metadata.define_type_parameter("TargetAnswer", Type)
  let companion = metadata.define_type_parameter(
    "E%context",
    Function([Type, Effect], Type),
  )
  let companion_answer = metadata.define_type_parameter("Answer", Type)
  let companion_residual = metadata.define_type_parameter("Residual", Effect)
  let external = metadata.define_effect("External", [], flavor=External)
  let algebraic = metadata.define_effect("Algebraic", [])
  let dictionary_type : @buslane.Type = Constructor(
    metadata.define_type("Dictionary", []),
  )
  let other_dictionary_type : @buslane.Type = Constructor(
    metadata.define_type("OtherDictionary", []),
  )
  let image = test_image_lowerer(metadata, [])
  let source_continuation : @buslane.Type = Function(
    [Primitive(I64)],
    Parameter(source_answer),
    Empty,
  )
  let target_continuation : @buslane.Type = Function(
    [Primitive(I64)],
    Parameter(target_answer),
    Empty,
  )
  let source_without_context = test_generic_callable_type(source_answer, [
    Primitive(I64),
    source_continuation,
  ])
  let source_with_context = test_generic_callable_type(source_answer, [
    Primitive(I64),
    dictionary_type,
    source_continuation,
  ])
  let cases : Array[(@buslane.Effect, @buslane.Type, @buslane.Type, Array[Int])] = [
    (Empty, Primitive(Unit), source_without_context, [0, 2]),
    (Io, Primitive(Unit), source_without_context, [0, 2]),
    (Singleton(external, []), Primitive(Unit), source_without_context, [0, 2]),
    (Singleton(algebraic, []), dictionary_type, source_with_context, [0, 1, 2]),
    (
      Union([Io, Singleton(algebraic, [])]),
      dictionary_type,
      source_with_context,
      [0, 1, 2],
    ),
  ]
  for case in cases {
    let (effect, companion_body, source_type, expected_targets) = case
    let substitutions = @buslane.TypeSubstitution::TypeSubstitution()
    substitutions.insert(
      companion,
      TypeLambda([companion_answer, companion_residual], companion_body),
    )
    let target_type = test_generic_callable_type(target_answer, [
      Primitive(I64),
      test_companion_application(companion, target_answer, effect),
      target_continuation,
    ])
    let (targets, _) = image.align_callable_parameters(
      source_type, target_type, substitutions,
    ) catch {
      error => fail("companion did not align: \{Repr(effect)}: \{Repr(error)}")
    }
    assert_eq(targets, expected_targets)
  }
  let mismatched_substitutions = @buslane.TypeSubstitution::TypeSubstitution()
  mismatched_substitutions.insert(
    companion,
    TypeLambda([companion_answer, companion_residual], other_dictionary_type),
  )
  let mismatched_target = test_generic_callable_type(target_answer, [
    Primitive(I64),
    test_companion_application(
      companion,
      target_answer,
      Singleton(algebraic, []),
    ),
    target_continuation,
  ])
  try
    image.align_callable_parameters(
      source_with_context, mismatched_target, mismatched_substitutions,
    )
  catch {
    InvalidTypeApplication(detail~) =>
      assert_eq(
        detail, "callable adapter source parameter 1/3 does not align with target parameter 1/3",
      )
    error => fail("unexpected lowering error: \{Repr(error)}")
  } noraise {
    _ => fail("expected different reference types not to align")
  }
}
