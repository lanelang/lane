///|
fn callable_boundary_registry(
  observed : Array[Int64],
) -> @loisvm_runtime.RuntimeRegistry {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.test.string_length",
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
      symbol="lane.test.observe_callable_boundary",
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

///|
fn execute_callable_image_in_both_backends(
  image : @loisvm_bytecode.BytecodeImage,
  expected : Int64,
) -> Unit raise {
  let interpreted_observed = []
  let interpreted = match
    @loisvm_interp.load(image, callable_boundary_registry(interpreted_observed)) {
    Ok(value) => value
    Err(error) => fail("interpreter load failed: \{to_repr(error)}")
  }
  assert_eq(interpreted.new_instance().execute(), Ok(()))
  assert_eq(interpreted_observed, [expected])
  let wasm_observed = []
  let wasm = match
    @loisvm_wasm.load(image, callable_boundary_registry(wasm_observed)) {
    Ok(value) => value
    Err(error) => fail("Wasm load failed: \{to_repr(error)}")
  }
  let instance = match wasm.new_instance() {
    Ok(value) => value
    Err(error) => fail("Wasm instantiate failed: \{to_repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
  assert_eq(wasm_observed, [expected])
}

///|
test "existential lowering executes through Wasm with opened ARC witnesses" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let consumed = metadata.define_type_parameter("Consumed", Type)
  let box = metadata.define_type("Box", [])
  let pack = metadata.define_data_constructor("Pack", box, [hidden], [
    Parameter(hidden),
  ])
  let box_type = @buslane.Type::Constructor(box)
  let string_type = @buslane.Type::Primitive(String)
  let unit_type = @buslane.Type::Primitive(Unit)
  let consume_type = @buslane.Type::Forall(
    [consumed],
    Function([Parameter(consumed)], unit_type, Empty),
  )
  let consume_parameter = metadata.define_value(
    "value",
    Parameter,
    Parameter(consumed),
  )
  let consume = metadata.define_value("consume", Function, consume_type)
  let scrutinee = metadata.define_value("scrutinee", Local, box_type)
  let match_binder = metadata.define_value("box", MatchBinder, box_type)
  let payload = metadata.define_value("payload", MatchBinder, Parameter(opened))
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        consume,
        TypeLambda(
          [consumed],
          Function({
            parameters: [consume_parameter],
            result_type: unit_type,
            body: Literal(Unit),
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
              type_arguments: [],
              hidden_witnesses: [TypeArgument(string_type)],
              payloads: [Literal(String("owned"))],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(pack),
                  type_binders: [opened],
                  value_binders: [payload],
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
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      { builtins: [], runtime_imports: [] },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  let loaded = match
    @loisvm_wasm.load(image, @loisvm_runtime.RuntimeRegistry::new()) {
    Ok(value) => value
    Err(error) => fail("Wasm load failed: \{to_repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("Wasm instantiate failed: \{to_repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
}

///|
test "existential callable fields adapt covariant results and contravariant parameters" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let hidden_type = @buslane.Type::Parameter(hidden)
  let opened_type = @buslane.Type::Parameter(opened)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let hidden_producer_type = @buslane.Type::Function([], hidden_type, Empty)
  let hidden_mapper_type = @buslane.Type::Function(
    [hidden_type],
    int_type,
    Empty,
  )
  let opened_producer_type = @buslane.Type::Function([], opened_type, Empty)
  let opened_mapper_type = @buslane.Type::Function(
    [opened_type],
    int_type,
    Empty,
  )
  let string_producer_type = @buslane.Type::Function([], string_type, Empty)
  let string_mapper_type = @buslane.Type::Function(
    [string_type],
    int_type,
    Empty,
  )
  let factory = metadata.define_type("Factory", [])
  let pack = metadata.define_data_constructor("Pack", factory, [hidden], [
    hidden_producer_type, hidden_mapper_type,
  ])
  let factory_type = @buslane.Type::Constructor(factory)
  let producer = metadata.define_value(
    "produce",
    Function,
    string_producer_type,
  )
  let measure = metadata.define_value("measure", External, string_mapper_type)
  let observe_type = @buslane.Type::Function([int_type], unit_type, Empty)
  let observe = metadata.define_value("observe", External, observe_type)
  let scrutinee = metadata.define_value("scrutinee", Local, factory_type)
  let match_binder = metadata.define_value("factory", MatchBinder, factory_type)
  let opened_producer = metadata.define_value(
    "opened_producer",
    MatchBinder,
    opened_producer_type,
  )
  let opened_mapper = metadata.define_value(
    "opened_mapper",
    MatchBinder,
    opened_mapper_type,
  )
  let produced = metadata.define_value("produced", Local, opened_type)
  let measured = metadata.define_value("measured", Local, int_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
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
            scrutinee,
            Construct({
              data_constructor: pack,
              type_arguments: [],
              hidden_witnesses: [TypeArgument(string_type)],
              payloads: [Ref(producer), Ref(measure)],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(pack),
                  type_binders: [opened],
                  value_binders: [opened_producer, opened_mapper],
                  body: Let(
                    produced,
                    Call(Ref(opened_producer), []),
                    Let(
                      measured,
                      Call(Ref(opened_mapper), [Ref(produced)]),
                      Call(Ref(observe), [Ref(measured)]),
                    ),
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
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: measure,
            symbol: "lane.test.string_length",
            type_: string_mapper_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_callable_boundary",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  execute_callable_image_in_both_backends(image, 4L)
}

///|
test "existential callable adapters recurse through callable parameters" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let hidden_type = @buslane.Type::Parameter(hidden)
  let opened_type = @buslane.Type::Parameter(opened)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let hidden_producer_type = @buslane.Type::Function([], hidden_type, Empty)
  let opened_producer_type = @buslane.Type::Function([], opened_type, Empty)
  let string_producer_type = @buslane.Type::Function([], string_type, Empty)
  let hidden_transformer_type = @buslane.Type::Function(
    [hidden_producer_type],
    hidden_type,
    Empty,
  )
  let opened_transformer_type = @buslane.Type::Function(
    [opened_producer_type],
    opened_type,
    Empty,
  )
  let string_transformer_type = @buslane.Type::Function(
    [string_producer_type],
    string_type,
    Empty,
  )
  let hidden_mapper_type = @buslane.Type::Function(
    [hidden_type],
    int_type,
    Empty,
  )
  let opened_mapper_type = @buslane.Type::Function(
    [opened_type],
    int_type,
    Empty,
  )
  let string_mapper_type = @buslane.Type::Function(
    [string_type],
    int_type,
    Empty,
  )
  let factory = metadata.define_type("NestedFactory", [])
  let pack = metadata.define_data_constructor("PackNested", factory, [hidden], [
    hidden_producer_type, hidden_transformer_type, hidden_mapper_type,
  ])
  let factory_type = @buslane.Type::Constructor(factory)
  let producer = metadata.define_value(
    "produce_nested",
    Function,
    string_producer_type,
  )
  let transformer_parameter = metadata.define_value(
    "nested_callable",
    Parameter,
    string_producer_type,
  )
  let transformer = metadata.define_value(
    "transform",
    Function,
    string_transformer_type,
  )
  let measure = metadata.define_value(
    "measure_nested",
    External,
    string_mapper_type,
  )
  let observe_type = @buslane.Type::Function([int_type], unit_type, Empty)
  let observe = metadata.define_value("observe_nested", External, observe_type)
  let scrutinee = metadata.define_value("nested_scrutinee", Local, factory_type)
  let match_binder = metadata.define_value(
    "nested_factory",
    MatchBinder,
    factory_type,
  )
  let opened_producer = metadata.define_value(
    "opened_nested_producer",
    MatchBinder,
    opened_producer_type,
  )
  let opened_transformer = metadata.define_value(
    "opened_transformer",
    MatchBinder,
    opened_transformer_type,
  )
  let opened_mapper = metadata.define_value(
    "opened_nested_mapper",
    MatchBinder,
    opened_mapper_type,
  )
  let produced = metadata.define_value("nested_produced", Local, opened_type)
  let measured = metadata.define_value("nested_measured", Local, int_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("nested_main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
      Let(
        producer,
        Function({
          parameters: [],
          result_type: string_type,
          body: Literal(String("Lane")),
        }),
      ),
      Let(
        transformer,
        Function({
          parameters: [transformer_parameter],
          result_type: string_type,
          body: Call(Ref(transformer_parameter), []),
        }),
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
              type_arguments: [],
              hidden_witnesses: [TypeArgument(string_type)],
              payloads: [Ref(producer), Ref(transformer), Ref(measure)],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(pack),
                  type_binders: [opened],
                  value_binders: [
                    opened_producer, opened_transformer, opened_mapper,
                  ],
                  body: Let(
                    produced,
                    Call(Ref(opened_transformer), [Ref(opened_producer)]),
                    Let(
                      measured,
                      Call(Ref(opened_mapper), [Ref(produced)]),
                      Call(Ref(observe), [Ref(measured)]),
                    ),
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
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: measure,
            symbol: "lane.test.string_length",
            type_: string_mapper_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_callable_boundary",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  execute_callable_image_in_both_backends(image, 4L)
}

///|
test "generic container fields round-trip callable values through erasure" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let callable = metadata.define_type_parameter("Callable", Type)
  let value = metadata.define_type_parameter("Value", Type)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let hidden_type = @buslane.Type::Parameter(hidden)
  let opened_type = @buslane.Type::Parameter(opened)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let hidden_producer_type = @buslane.Type::Function([], hidden_type, Empty)
  let opened_producer_type = @buslane.Type::Function([], opened_type, Empty)
  let string_producer_type = @buslane.Type::Function([], string_type, Empty)
  let hidden_mapper_type = @buslane.Type::Function(
    [hidden_type],
    int_type,
    Empty,
  )
  let opened_mapper_type = @buslane.Type::Function(
    [opened_type],
    int_type,
    Empty,
  )
  let string_mapper_type = @buslane.Type::Function(
    [string_type],
    int_type,
    Empty,
  )
  let wrapper = metadata.define_type("Wrapper", [callable, value])
  let wrap = metadata.define_data_constructor("Wrap", wrapper, [], [
    Parameter(callable),
    Parameter(value),
  ])
  let hidden_wrapper_type = @buslane.Type::Apply(Constructor(wrapper), [
    TypeArgument(hidden_producer_type),
    TypeArgument(hidden_mapper_type),
  ])
  let opened_wrapper_type = @buslane.Type::Apply(Constructor(wrapper), [
    TypeArgument(opened_producer_type),
    TypeArgument(opened_mapper_type),
  ])
  let string_wrapper_type = @buslane.Type::Apply(Constructor(wrapper), [
    TypeArgument(string_producer_type),
    TypeArgument(string_mapper_type),
  ])
  let factory = metadata.define_type("WrappedFactory", [])
  let pack = metadata.define_data_constructor(
    "PackWrapped",
    factory,
    [hidden],
    [hidden_wrapper_type],
  )
  let factory_type = @buslane.Type::Constructor(factory)
  let producer = metadata.define_value(
    "produce_wrapped",
    Function,
    string_producer_type,
  )
  let measure = metadata.define_value(
    "measure_wrapped",
    External,
    string_mapper_type,
  )
  let observe_type = @buslane.Type::Function([int_type], unit_type, Empty)
  let observe = metadata.define_value("observe_wrapped", External, observe_type)
  let wrapped = metadata.define_value("wrapped", Local, string_wrapper_type)
  let scrutinee = metadata.define_value(
    "wrapped_scrutinee",
    Local,
    factory_type,
  )
  let match_binder = metadata.define_value(
    "wrapped_factory",
    MatchBinder,
    factory_type,
  )
  let opened_wrapper = metadata.define_value(
    "opened_wrapper",
    MatchBinder,
    opened_wrapper_type,
  )
  let wrapper_match_binder = metadata.define_value(
    "wrapper_match",
    MatchBinder,
    opened_wrapper_type,
  )
  let opened_producer = metadata.define_value(
    "opened_wrapped_producer",
    MatchBinder,
    opened_producer_type,
  )
  let opened_mapper = metadata.define_value(
    "opened_wrapped_mapper",
    MatchBinder,
    opened_mapper_type,
  )
  let produced = metadata.define_value("wrapped_produced", Local, opened_type)
  let measured = metadata.define_value("wrapped_measured", Local, int_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("wrapped_main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
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
            wrapped,
            Construct({
              data_constructor: wrap,
              type_arguments: [
                TypeArgument(string_producer_type),
                TypeArgument(string_mapper_type),
              ],
              hidden_witnesses: [],
              payloads: [Ref(producer), Ref(measure)],
            }),
            Let(
              scrutinee,
              Construct({
                data_constructor: pack,
                type_arguments: [],
                hidden_witnesses: [TypeArgument(string_type)],
                payloads: [Ref(wrapped)],
              }),
              Match({
                scrutinee: Ref(scrutinee),
                binder: match_binder,
                result_type: unit_type,
                alternatives: [
                  {
                    alt_constructor: DataCon(pack),
                    type_binders: [opened],
                    value_binders: [opened_wrapper],
                    body: Match({
                      scrutinee: Ref(opened_wrapper),
                      binder: wrapper_match_binder,
                      result_type: unit_type,
                      alternatives: [
                        {
                          alt_constructor: DataCon(wrap),
                          type_binders: [],
                          value_binders: [opened_producer, opened_mapper],
                          body: Let(
                            produced,
                            Call(Ref(opened_producer), []),
                            Let(
                              measured,
                              Call(Ref(opened_mapper), [Ref(produced)]),
                              Call(Ref(observe), [Ref(measured)]),
                            ),
                          ),
                        },
                      ],
                    }),
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
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: measure,
            symbol: "lane.test.string_length",
            type_: string_mapper_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_callable_boundary",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  execute_callable_image_in_both_backends(image, 4L)
}

///|
test "existential callable adapters forward explicit forall witnesses" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let argument = metadata.define_type_parameter("Argument", Type)
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let opened = metadata.define_type_parameter("Opened", Type)
  let argument_type = @buslane.Type::Parameter(argument)
  let hidden_type = @buslane.Type::Parameter(hidden)
  let opened_type = @buslane.Type::Parameter(opened)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let hidden_generic_type = @buslane.Type::Forall(
    [argument],
    Function([argument_type], hidden_type, Empty),
  )
  let opened_generic_type = @buslane.Type::Forall(
    [argument],
    Function([argument_type], opened_type, Empty),
  )
  let string_generic_type = @buslane.Type::Forall(
    [argument],
    Function([argument_type], string_type, Empty),
  )
  let hidden_mapper_type = @buslane.Type::Function(
    [hidden_type],
    int_type,
    Empty,
  )
  let opened_mapper_type = @buslane.Type::Function(
    [opened_type],
    int_type,
    Empty,
  )
  let string_mapper_type = @buslane.Type::Function(
    [string_type],
    int_type,
    Empty,
  )
  let factory = metadata.define_type("GenericFactory", [])
  let pack = metadata.define_data_constructor(
    "PackGeneric",
    factory,
    [hidden],
    [hidden_generic_type, hidden_mapper_type],
  )
  let factory_type = @buslane.Type::Constructor(factory)
  let ignored_argument = metadata.define_value(
    "ignored_argument",
    Parameter,
    argument_type,
  )
  let generic_producer = metadata.define_value(
    "generic_producer",
    Function,
    string_generic_type,
  )
  let measure = metadata.define_value(
    "measure_generic",
    External,
    string_mapper_type,
  )
  let observe_type = @buslane.Type::Function([int_type], unit_type, Empty)
  let observe = metadata.define_value("observe_generic", External, observe_type)
  let scrutinee = metadata.define_value(
    "generic_scrutinee",
    Local,
    factory_type,
  )
  let match_binder = metadata.define_value(
    "generic_factory",
    MatchBinder,
    factory_type,
  )
  let opened_generic = metadata.define_value(
    "opened_generic",
    MatchBinder,
    opened_generic_type,
  )
  let opened_mapper = metadata.define_value(
    "opened_generic_mapper",
    MatchBinder,
    opened_mapper_type,
  )
  let produced = metadata.define_value("generic_produced", Local, opened_type)
  let measured = metadata.define_value("generic_measured", Local, int_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("generic_main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
      Let(
        generic_producer,
        TypeLambda(
          [argument],
          Function({
            parameters: [ignored_argument],
            result_type: string_type,
            body: Literal(String("Lane")),
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
              type_arguments: [],
              hidden_witnesses: [TypeArgument(string_type)],
              payloads: [Ref(generic_producer), Ref(measure)],
            }),
            Match({
              scrutinee: Ref(scrutinee),
              binder: match_binder,
              result_type: unit_type,
              alternatives: [
                {
                  alt_constructor: DataCon(pack),
                  type_binders: [opened],
                  value_binders: [opened_generic, opened_mapper],
                  body: Let(
                    produced,
                    Call(
                      TypeApply(Ref(opened_generic), [TypeArgument(int_type)]),
                      [Literal(Int(7L))],
                    ),
                    Let(
                      measured,
                      Call(Ref(opened_mapper), [Ref(produced)]),
                      Call(Ref(observe), [Ref(measured)]),
                    ),
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
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: measure,
            symbol: "lane.test.string_length",
            type_: string_mapper_type,
          },
          {
            value: observe,
            symbol: "lane.test.observe_callable_boundary",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  execute_callable_image_in_both_backends(image, 4L)
}
