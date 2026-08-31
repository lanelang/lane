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
  Function(parameters, result, Builtin(Io))
}

///|
fn test_import_contract(
  field_name : String,
  type_ : @buslane.Type,
) -> @wasm_abi.ImportContract {
  guard type_ is Function(parameters, result, _) else {
    abort("test runtime import must be a function")
  }
  {
    module_name: "lane.test",
    field_name,
    parameters: parameters.map(test_import_parameter),
    result: test_import_result(result),
  }
}

///|
fn test_import_parameter(type_ : @buslane.Type) -> @wasm_abi.ImportParameter {
  match type_ {
    Primitive(Unit) => ErasedUnit
    Primitive(I32) => Direct(I32)
    Primitive(I64) => Direct(I64)
    Primitive(F32) => Direct(F32)
    Primitive(F64) => Direct(F64)
    _ => abort("test runtime import must use a direct ABI type")
  }
}

///|
fn test_import_result(type_ : @buslane.Type) -> @wasm_abi.ImportResult {
  match type_ {
    Primitive(Unit) => Unit
    Primitive(I32) => Direct(I32)
    Primitive(I64) => Direct(I64)
    Primitive(F32) => Direct(F32)
    Primitive(F64) => Direct(F64)
    _ => abort("test runtime import must use a direct ABI type")
  }
}

///|
fn contains_instruction(
  body : @physical.FunctionBody,
  predicate : (@physical.Instruction) -> Bool,
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
fn lower_test_executable_to_physical(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@physical.PhysicalProgram, PhysicalLoweringError] {
  lower_test_executable_to_physical_observed(program, externals, entry, _ => ())
}

///|
fn lower_test_executable_to_physical_observed(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  observe : (PhysicalLoweringStage) -> Unit,
) -> Result[@physical.PhysicalProgram, PhysicalLoweringError] {
  let cps_core = @effect_lowering.lower_effects(program.certify().unwrap()).unwrap()
  lower_executable_program_to_physical_observed(
    {
      cps_core,
      externals,
      entry,
      retained_values: test_retained_values(program),
    },
    observe,
  ).map(verified => verified.image())
}

///|
fn lower_test_executable_to_physical_without_representation_specialization(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@physical.PhysicalProgram, PhysicalLoweringError] {
  let cps_core = @effect_lowering.lower_effects(program.certify().unwrap()).unwrap()
  lower_executable_program_to_physical_observed_with_specialization(
    {
      cps_core,
      externals,
      entry,
      retained_values: test_retained_values(program),
    },
    _ => (),
    false,
  ).map(verified => verified.image())
}

///|
fn test_retained_values(program : @buslane.Program) -> Array[@buslane.ValueId] {
  let values = []
  for term in program.terms {
    match term {
      Let(value, _) | External(value) => values.push(value)
      LetRec(bindings) =>
        for binding in bindings {
          values.push(binding.id)
        }
    }
  }
  values
}

///|
fn lower_test_linked_program_to_physical(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@physical.PhysicalProgram, PhysicalLoweringError] {
  let executable = match
    @executable.elaborate(
      {
        module_path_texts: [],
        program: program.certify().unwrap(),
        externals,
        entries: [entry],
      },
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[Io, Panic],
        supports_external_effects=true,
      ),
    ) {
    Ok(executable) => executable
    Err(error) => abort("test executable elaboration failed: \{Repr(error)}")
  }
  lower_executable_program_to_physical(executable).map(verified => {
    verified.image()
  })
}

///|
fn test_image_lowerer(metadata : @buslane.MetadataRegistry) -> ImageLowerer {
  let program : @buslane.Program = { metadata, terms: [], }
  let cps_core = @effect_lowering.lower_effects(program.certify().unwrap()).unwrap()
  let runtime_metadata = @anf.lower_cps_core_to_runtime_anf({
      cps_core,
      retained_values: [],
    })
    .unwrap()
    .metadata()
  {
    metadata: runtime_metadata,
    runtime_types: RuntimeTypeArena::from_metadata(runtime_metadata),
    externals: { builtins: [], runtime_imports: [], },
    globals: [],
    instance_globals: [],
    plans: FunctionPlanTable::new(),
    constants: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    representation_workers: [],
    representation_worker_contracts: { entries: [], },
    representation_worker_candidates: [],
    callable_adapters: [],
    callable_adapter_worker_contracts: { entries: [], },
    physical_callable_contracts: { requests: [], entries: [], },
    data_families: [],
    synthetic_parameters: [],
    active_specialization_ancestry: [],
    representation_specialization_enabled: false,
  }
}

///|
test "function plans allocate source and synthetic origins atomically" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let initialized = metadata.define_value("initialized", Value, Primitive(I64))
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(I64), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(initialized, Literal(I64(42L))),
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(I64),
          body: Ref(initialized),
        }),
      ),
    ],
  }
  let lowerer = test_image_lowerer(metadata)
  let cps_core = @effect_lowering.lower_effects(program.certify().unwrap()).unwrap()
  let anf = @anf.lower_cps_core_to_runtime_anf({
    cps_core,
    retained_values: test_retained_values(program),
  }).unwrap()
  ignore(lowerer.plan(anf))
  debug_inspect(
    lowerer.plans.observations(),
    content=(
      #|[
      #|  ({ value: 1 }, Initializer(source={ index: 0 })),
      #|  (
      #|    { value: 2 },
      #|    TopLevelFunction(
      #|      function={ value: 0 },
      #|      source=Some({ index: 1 }),
      #|      origin=SourceWritten,
      #|    ),
      #|  ),
      #|  ({ value: 3 }, InitializerOrchestrator),
      #|]
    ),
  )
}

///|
test "pure scalar Buslane lowers through ANF into executable Physical Program" {
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(add, I64Add),
        ],
        runtime_imports: [],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(image.entry, { value: 2, })
  guard image.functions is [PhysicalBody(helper_body), PhysicalBody(main_body)] else {
    fail("expected two physical bodies")
  }
  assert_true(
    contains_instruction(helper_body, instruction => {
      instruction is I64Add(_, _, _)
    }),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is CallDirect({ value: 1, }, None, [], _, _)
    }),
  )
  let loaded = match load_physical_interpreted(image) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: import_,
            contract: test_import_contract("%i64_add", import_type),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions is [PhysicalBody(_), RuntimeImport(import_)] else {
    fail("expected entry body and one runtime import")
  }
  debug_inspect(
    import_,
    content=(
      #|{
      #|  module_name: "lane.test",
      #|  field_name: "%i64_add",
      #|  parameters: [Direct(I64), Direct(I64)],
      #|  result: Direct(I64),
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(add, I64Add),
        ],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_intrinsic_value", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions
    is [
      PhysicalBody(apply_body),
      PhysicalBody(main_body),
      PhysicalBody(wrapper_body),
      RuntimeImport(_),
    ] else {
    fail("expected apply, main, intrinsic wrapper, and runtime import")
  }
  assert_true(apply_body.blocks[0].terminator is TailCallDirect(_, None, [], _))
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is ConstFunction(_, { value: 3, })
    }),
  )
  assert_true(
    contains_instruction(wrapper_body, instruction => {
      instruction is I64Add(_, _, _)
    }),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_intrinsic_value", value => {
    observed = value
  })
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "entry admission rejects residual algebraic effects before lowering" {
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
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
  }
  debug_inspect(
    @executable.elaborate(
      {
        module_path_texts: [],
        program: program.certify().unwrap(),
        externals: { builtins: [], runtime_imports: [], },
        entries: [entry],
      },
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[Io, Panic],
        supports_external_effects=true,
      ),
    ),
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
test "lexical handlers and resume lower before the Physical Program" {
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_handled_value", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_handled_value", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract("lane.test.observe", observe_type),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_true(
    image.functions
    is [
      PhysicalBody(_),
      RuntimeImport(
        {
          module_name: "lane.test",
          field_name: "lane.test.observe",
          parameters: [Direct(I64)],
          result: Unit,
        }
      ),
    ],
  )
  assert_eq(image.layouts, [])
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|

///|
test "runtime imports are deduplicated and sorted after physical bodies" {
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
  let mut initial_provenance : Array[PhysicalFunctionProvenance] = []
  let mut final_provenance : Array[PhysicalFunctionProvenance] = []
  let image = match
    lower_test_executable_to_physical_observed(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: z_first,
            contract: test_import_contract("lane.test.z", import_type),
          },
          {
            value: a,
            contract: test_import_contract("lane.test.a", import_type),
          },
          {
            value: z_second,
            contract: test_import_contract("lane.test.z", import_type),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
      fn(observed) {
        match observed {
          InitialVmcfg(_, provenance, _) =>
            initial_provenance = provenance.functions
          FinalPhysicalProgram(_, provenance, _) =>
            final_provenance = provenance.functions
          Anf(_) => ()
        }
      },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_true(
    image.functions
    is [
      PhysicalBody(_),
      RuntimeImport({ field_name: "lane.test.a", .. }),
      RuntimeImport({ field_name: "lane.test.z", .. }),
    ],
  )
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
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
  assert_eq(direct_targets, [{ value: 3, }, { value: 2, }, { value: 3, }])
  assert_eq(initial_provenance, final_provenance)
  debug_inspect(
    final_provenance,
    content=(
      #|[
      #|  {
      #|    function: { value: 1 },
      #|    origins: [
      #|      TopLevelFunction(
      #|        function={ value: 0 },
      #|        source=Some({ index: 5 }),
      #|        origin=SourceWritten,
      #|      ),
      #|    ],
      #|  },
      #|  {
      #|    function: { value: 2 },
      #|    origins: [
      #|      RuntimeImport(
      #|        source={ index: 1 },
      #|        module_name="lane.test",
      #|        field_name="lane.test.a",
      #|      ),
      #|    ],
      #|  },
      #|  {
      #|    function: { value: 3 },
      #|    origins: [
      #|      RuntimeImport(
      #|        source={ index: 0 },
      #|        module_name="lane.test",
      #|        field_name="lane.test.z",
      #|      ),
      #|      RuntimeImport(
      #|        source={ index: 2 },
      #|        module_name="lane.test",
      #|        field_name="lane.test.z",
      #|      ),
      #|    ],
      #|  },
      #|]
    ),
  )
}

///|
test "runtime imports with equal symbols and distinct core types remain distinct" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let unit_type = @buslane.Type::Primitive(Unit)
  let i64_import_type = test_io_function_type([Primitive(I64)], unit_type)
  let i32_import_type = test_io_function_type([Primitive(I32)], unit_type)
  let i64_import = metadata.define_value(
    "observe_int",
    External,
    i64_import_type,
  )
  let i32_import = metadata.define_value(
    "observe_i32",
    External,
    i32_import_type,
  )
  let first = metadata.define_value("first", Local, unit_type)
  let main_type = test_io_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let image = match
    lower_test_linked_program_to_physical(
      {
        metadata,
        terms: [
          External(i64_import),
          External(i32_import),
          Let(
            main,
            Function({
              parameters: [],
              result_type: unit_type,
              body: Let(
                first,
                Call(Ref(i64_import), [Literal(I64(1L))]),
                Call(Ref(i32_import), [Literal(I32(1))]),
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
            contract: test_import_contract("lane.test.observe", i64_import_type),
          },
          {
            value: i32_import,
            contract: test_import_contract("lane.test.observe", i32_import_type),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(image) => image
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  debug_inspect(
    image.functions.filter_map(fn(entry) {
      match entry {
        RuntimeImport(import_) => Some(import_)
        PhysicalBody(_) => None
      }
    }),
    content=(
      #|[
      #|  {
      #|    module_name: "lane.test",
      #|    field_name: "lane.test.observe",
      #|    parameters: [Direct(I32)],
      #|    result: Unit,
      #|  },
      #|  {
      #|    module_name: "lane.test",
      #|    field_name: "lane.test.observe",
      #|    parameters: [Direct(I64)],
      #|    result: Unit,
      #|  },
      #|]
    ),
  )
}

///|
test "Bool matches lower to explicit CFG branches" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let bool_type = @buslane.Type::Primitive(Bool)
  let read_type = test_function_type([], i64_type)
  let read = metadata.define_value("read", External, read_type)
  let equal_type = test_function_type([i64_type, i64_type], bool_type)
  let equal = metadata.define_value("equal", External, equal_type)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let binder = metadata.define_value("condition", MatchBinder, bool_type)
  let main_type = test_function_type([], unit_type)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(read),
      External(equal),
      External(observe),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Match({
            scrutinee: Call(Ref(equal), [Call(Ref(read), []), Literal(I64(0L))]),
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
            equal,
            I64Equal,
          ),
        ],
        runtime_imports: [
          {
            value: read,
            contract: test_import_contract("lane.test.read_branch", read_type),
          },
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_branch", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions
    is [PhysicalBody(main_body), RuntimeImport(_), RuntimeImport(_)] else {
    fail("expected main, read, and observe functions")
  }
  assert_eq(main_body.blocks.length(), 3)
  assert_true(main_body.blocks[0].terminator is BranchBool(_, _, _))
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.provide_i64("lane.test.read_branch", 0L)
  host.observe_i64("lane.test.observe_branch", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
  let rebound = metadata.define_value("rebound", MatchBinder, option_type)
  let reprojected = metadata.define_value("reprojected", MatchBinder, i64_type)
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
                  body: Match({
                    scrutinee: Ref(binder),
                    binder: rebound,
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
                        value_binders: [reprojected],
                        body: Call(Ref(observe), [Ref(reprojected)]),
                      },
                    ],
                  }),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_data", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(image.object_shapes.length(), 2)
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is MakeData(_, _, _, [], _)
    }),
  )
  assert_true(main_body.blocks[0].terminator is SwitchTag(_, _, _))
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_data", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(add, I64Add),
        ],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_higher_order", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[1] is PhysicalBody(apply_body) else {
    fail("expected apply physical body")
  }
  assert_true(apply_body.blocks[0].terminator is TailCallDirect(_, None, [], _))
  guard image.functions[2] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is ConstFunction(_, { value: 1, })
    }),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_higher_order", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "single-use nonescaping nested functions beta-reduce before closure conversion" {
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(add, I64Add),
        ],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_closure", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(image.object_shapes.length(), 0)
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_eq(image.functions.length(), 2)
  debug_inspect(
    main_body.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [ConstI64({ value: 0 }, 42)],
      #|    terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
      #|  },
      #|]
    ),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_closure", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "tail-recursive local functions become local join points" {
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(sub, I64Sub),
          @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
            equal,
            I64Equal,
          ),
        ],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_recursive", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(image.object_shapes.length(), 0)
  let bodies = image.functions.filter_map(function => {
    if function is PhysicalBody(body) {
      Some(body)
    } else {
      None
    }
  })
  assert_eq(bodies.length(), 1)
  assert_true(bodies[0].blocks.length() > 1)
  assert_true(bodies[0].blocks.any(block => block.terminator is Jump(_)))
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_recursive", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_generic", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is PhysicalBody(identity_body) else {
    fail("expected identity physical body")
  }
  assert_eq(identity_body.inputs.witnesses.length(), 1)
  assert_eq(identity_body.result, Value(I64, OwnedErased, ErasedValue))
  guard image.functions[1] is PhysicalBody(apply_body) else {
    fail("expected apply physical body")
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
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_generic", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "closed generic calls specialize without changing the canonical fallback" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_type = @buslane.Type::Parameter(type_parameter)
  let identity_type = @buslane.Type::Forall(
    [type_parameter],
    test_function_type([generic_type], generic_type),
  )
  let parameter = metadata.define_value("value", Parameter, generic_type)
  let identity = metadata.define_value("identity", Function, identity_type)
  let bool_type = @buslane.Type::Primitive(Bool)
  let i64_type = @buslane.Type::Primitive(I64)
  let unit_type = @buslane.Type::Primitive(Unit)
  let observe_type = test_function_type([i64_type], unit_type)
  let observe = metadata.define_value("observe", External, observe_type)
  let bool_result = metadata.define_value("bool_result", Local, bool_type)
  let result = metadata.define_value("result", Local, i64_type)
  let second_result = metadata.define_value("second_result", Local, i64_type)
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
            parameters: [parameter],
            result_type: generic_type,
            body: Ref(parameter),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            bool_result,
            Call(TypeApply(Ref(identity), [TypeArgument(bool_type)]), [
              Literal(Bool(true)),
            ]),
            Let(
              result,
              Call(TypeApply(Ref(identity), [TypeArgument(i64_type)]), [
                Literal(I64(42L)),
              ]),
              Let(
                second_result,
                Call(TypeApply(Ref(identity), [TypeArgument(i64_type)]), [
                  Ref(result),
                ]),
                Call(Ref(observe), [Ref(second_result)]),
              ),
            ),
          ),
        }),
      ),
    ],
  }
  let mut representation_worker_count = 0
  let specialized_image = match
    lower_test_executable_to_physical_observed(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_canonical_generic", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
      stage => {
        if stage is InitialVmcfg(_, provenance, _) {
          representation_worker_count = provenance.functions
            .filter(item => {
              item.origins.any(origin => origin is RepresentationWorker(..))
            })
            .length()
        }
      },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_eq(representation_worker_count, 2)
  let generic_image = match
    lower_test_executable_to_physical_without_representation_specialization(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_canonical_generic", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("generic lowering failed: \{Repr(error)}")
  }
  let generic_bodies = generic_image.functions.filter_map(function => {
    if function is PhysicalBody(body) {
      Some(body)
    } else {
      None
    }
  })
  assert_eq(generic_bodies.length(), 2)
  assert_true(
    generic_bodies.any(body => {
      body.inputs.witnesses.length() == 1 &&
      body.inputs.user_parameters.length() == 1 &&
      body.result == Value(I64, OwnedErased, ErasedValue) &&
      body.blocks.all(block => block.instructions.is_empty())
    }),
  )
  assert_true(
    generic_bodies.any(body => {
      contains_instruction(body, instruction => instruction is ConstLayout(_, _)) &&
      contains_instruction(body, instruction => instruction is EraseI32(_, _)) &&
      contains_instruction(body, instruction => instruction is EraseI64(_, _)) &&
      contains_instruction(body, instruction => instruction is UneraseI64(_, _))
    }),
  )
  let specialized_bodies = specialized_image.functions.filter_map(function => {
    if function is PhysicalBody(body) {
      Some(body)
    } else {
      None
    }
  })
  assert_eq(specialized_bodies.length(), 3)
  assert_true(
    specialized_bodies.any(body => {
      body.inputs.witnesses.is_empty() &&
      body.inputs.user_parameters.length() == 1 &&
      body.result == Value(I64, Trivial, ScalarValue) &&
      body.blocks.all(block => block.instructions.is_empty())
    }),
  )
  assert_true(
    specialized_bodies.any(body => {
      body.inputs.witnesses.is_empty() &&
      body.inputs.user_parameters.length() == 1 &&
      body.result == Value(I32, Trivial, ScalarValue) &&
      body.blocks.all(block => block.instructions.is_empty())
    }),
  )
  assert_false(
    specialized_bodies.any(body => {
      contains_instruction(body, instruction => {
        instruction is EraseI32(_, _) ||
        instruction is UneraseI32(_, _) ||
        instruction is EraseI64(_, _) ||
        instruction is UneraseI64(_, _)
      })
    }),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_canonical_generic", value => {
    observed = value
  })
  let loaded = match load_physical_interpreted(specialized_image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
  observed = 0L
  let generic_loaded = match load_physical_interpreted(generic_image, host~) {
    Ok(value) => value
    Err(error) => fail("generic load failed: \{Repr(error)}")
  }
  assert_eq(generic_loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "closed worker preserves a generic nominal callable field contract" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_type = @buslane.Type::Parameter(type_parameter)
  let generic_producer_type = test_function_type([], generic_type)
  let box = metadata.define_type("ProducerBox", [type_parameter])
  let boxed = metadata.define_data_constructor("ProducerBox", box, [], [
    generic_producer_type,
  ])
  let generic_box_type = @buslane.Type::Apply(Constructor(box), [
    TypeArgument(generic_type),
  ])
  let invoke_type = @buslane.Type::Forall(
    [type_parameter],
    test_function_type([generic_box_type], generic_type),
  )
  let box_parameter = metadata.define_value("box", Parameter, generic_box_type)
  let match_binder = metadata.define_value(
    "matched_box",
    MatchBinder,
    generic_box_type,
  )
  let producer_binder = metadata.define_value(
    "producer",
    MatchBinder,
    generic_producer_type,
  )
  let invoke = metadata.define_value("invoke", Function, invoke_type)
  let i64_type = @buslane.Type::Primitive(I64)
  let i64_producer_type = test_function_type([], i64_type)
  let producer = metadata.define_value(
    "produce_i64",
    Function,
    i64_producer_type,
  )
  let i64_box_type = @buslane.Type::Apply(Constructor(box), [
    TypeArgument(i64_type),
  ])
  let boxed_value = metadata.define_value("boxed", Local, i64_box_type)
  let result = metadata.define_value("result", Local, i64_type)
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
        producer,
        Function({
          parameters: [],
          result_type: i64_type,
          body: Literal(I64(42L)),
        }),
      ),
      LetRec([
        {
          id: invoke,
          rhs: TypeLambda(
            [type_parameter],
            Function({
              parameters: [box_parameter],
              result_type: generic_type,
              body: Match({
                scrutinee: Ref(box_parameter),
                binder: match_binder,
                result_type: generic_type,
                alternatives: [
                  {
                    alt_constructor: DataCon(boxed),
                    type_binders: [],
                    value_binders: [producer_binder],
                    body: Call(Ref(producer_binder), []),
                  },
                ],
              }),
            }),
          ),
        },
      ]),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            boxed_value,
            Construct({
              data_constructor: boxed,
              type_arguments: [TypeArgument(i64_type)],
              hidden_witnesses: [],
              payloads: [Ref(producer)],
            }),
            Let(
              result,
              Call(TypeApply(Ref(invoke), [TypeArgument(i64_type)]), [
                Ref(boxed_value),
              ]),
              Call(Ref(observe), [Ref(result)]),
            ),
          ),
        }),
      ),
    ],
  }
  let externals : @buslane_lowering.BuslaneExternalMap = {
    builtins: [],
    runtime_imports: [
      {
        value: observe,
        contract: test_import_contract(
          "lane.test.observe_nominal_callable", observe_type,
        ),
      },
    ],
  }
  let entry : @buslane_lowering.BuslaneEntry = {
    module_path_text: "Main",
    name: "main",
    value: main,
  }
  let mut worker_count = 0
  let specialized = match
    lower_test_executable_to_physical_observed(program, externals, entry, stage => {
      if stage is InitialVmcfg(_, provenance, _) {
        worker_count = provenance.functions
          .filter(item => {
            item.origins.any(origin => origin is RepresentationWorker(..))
          })
          .length()
      }
    }) {
    Ok(image) => image
    Err(error) => fail("specialized lowering failed: \{Repr(error)}")
  }
  assert_eq(worker_count, 1)
  let generic = match
    lower_test_executable_to_physical_without_representation_specialization(
      program, externals, entry,
    ) {
    Ok(image) => image
    Err(error) => fail("generic lowering failed: \{Repr(error)}")
  }
  let observations = []
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_nominal_callable", value => {
    observations.push(value)
  })
  let specialized_loaded = match load_physical_interpreted(specialized, host~) {
    Ok(loaded) => loaded
    Err(error) => fail("specialized load failed: \{Repr(error)}")
  }
  assert_eq(specialized_loaded.execute(), Ok(()))
  let generic_loaded = match load_physical_interpreted(generic, host~) {
    Ok(loaded) => loaded
    Err(error) => fail("generic load failed: \{Repr(error)}")
  }
  assert_eq(generic_loaded.execute(), Ok(()))
  assert_eq(observations, [42L, 42L])
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract("lane.test.single_box", observe_type),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_false(
    main_body.blocks.any(block => block.terminator is SwitchTag(_, _, _)),
  )
  let mut observed = false
  let host = TestHostBindings::new()
  host.signal("lane.test.single_box", () => observed = true)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
  let rebound = metadata.define_value("rebound", MatchBinder, option_int)
  let reprojected = metadata.define_value("reprojected", MatchBinder, i64_type)
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
                  body: Match({
                    scrutinee: Ref(binder),
                    binder: rebound,
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
                        value_binders: [reprojected],
                        body: Call(Ref(observe), [Ref(reprojected)]),
                      },
                    ],
                  }),
                },
              ],
            }),
          ),
        }),
      ),
    ],
  }
  let image = match
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_generic_data", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
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
          ..
        }
      )
    }),
  )
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
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
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_generic_data", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_existential_payload", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
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
            { cleanup: Trivial, kind: LayoutValue, .. },
            { cleanup: OwnedErased, witness_ordinal: Some(0), .. },
            { cleanup: OwnedErased, witness_ordinal: Some(1), .. },
          ],
          ..
        }
      )
    }),
  )
  guard image.functions[1] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is BorrowField(_, _, 0, { witness_destination: None, .. })
    }),
  )
  assert_true(
    contains_instruction(main_body, instruction => {
      instruction is BorrowField(_, _, _, { witness_destination: Some(_), .. })
    }),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_existential_payload", value => {
    observed = value
  })
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}

///|
test "payload-free existential evidence disappears when no runtime use remains" {
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_existential_witness", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_true(
    image.object_shapes.any(shape => {
      shape is Data({ stored_witness_count: 0, members: [], .. })
    }),
  )
  guard image.functions[1] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_false(
    contains_instruction(main_body, instruction => {
      instruction is BorrowField(_, _, 0, { witness_destination: None, .. })
    }),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_existential_witness", value => {
    observed = value
  })
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 9L)
}

///|
test "unused effect-kind existential evidence disappears from runtime ANF" {
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
    lower_test_linked_program_to_physical(
      program,
      { builtins: [], runtime_imports: [], },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  assert_true(
    image.object_shapes.any(shape => {
      shape is Data({ stored_witness_count: 0, members: [], .. })
    }),
  )
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_false(
    contains_instruction(main_body, instruction => {
      instruction is LoadObjectWitness(_, _, _, _)
    }),
  )
  let loaded = match load_physical_interpreted(image) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_executable_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_unit_abi", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is PhysicalBody(consume_body) else {
    fail("expected consume physical body")
  }
  assert_eq(consume_body.inputs.user_parameters.length(), 1)
  assert_true(
    image.object_shapes.any(shape => {
      shape is Data({ members: [{ representation: I64, .. }], .. })
    }),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_unit_abi", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: read,
            contract: test_import_contract(
              "lane.test.read_literal_match", read_type,
            ),
          },
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_literal_match", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  assert_true(
    contains_instruction(main_body, instruction => instruction is I64Eq(_, _, _)),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.provide_i64("lane.test.read_literal_match", 2L)
  host.observe_i64("lane.test.observe_literal_match", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 2L)
}

///|
test "single-use generic nested functions beta-reduce before representation lowering" {
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
    lower_test_linked_program_to_physical(
      program,
      {
        builtins: [],
        runtime_imports: [
          {
            value: observe,
            contract: test_import_contract(
              "lane.test.observe_nested_generic", observe_type,
            ),
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{Repr(error)}")
  }
  guard image.functions[0] is PhysicalBody(main_body) else {
    fail("expected main physical body")
  }
  debug_inspect(
    main_body.blocks,
    content=(
      #|[
      #|  {
      #|    parameters: [],
      #|    instructions: [ConstI64({ value: 0 }, 42)],
      #|    terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
      #|  },
      #|]
    ),
  )
  let mut observed = 0L
  let host = TestHostBindings::new()
  host.observe_i64("lane.test.observe_nested_generic", value => observed = value)
  let loaded = match load_physical_interpreted(image, host~) {
    Ok(value) => value
    Err(error) => fail("load failed: \{Repr(error)}")
  }
  assert_eq(loaded.execute(), Ok(()))
  assert_eq(observed, 42L)
}
