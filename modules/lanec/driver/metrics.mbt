///|
priv struct AnfScaleAccumulator {
  mut function_count : Int
  mut call_count : Int
  mut generic_binder_count : Int
  mut type_application_count : Int
  functions : Array[ExploreFunctionScale]
  anf_functions : Array[ObservedAnfFunction]
}

///|
fn metric(id : ExploreMetricId, value : Int) -> ExploreMetric {
  { id, value, }
}

///|
fn buslane_scale(program : @buslane.Program) -> ExploreScaleObservation {
  buslane_structural_scale(program.structural_scale())
}

///|
fn buslane_structural_scale(
  scale : @buslane.ProgramScale,
) -> ExploreScaleObservation {
  {
    metrics: [
      metric(TopTermCount, scale.top_terms),
      metric(FunctionCount, scale.functions),
      metric(NodeCount, scale.nodes),
      metric(CallCount, scale.calls),
      metric(GenericBinderCount, scale.generic_binders),
      metric(TypeApplicationCount, scale.type_applications),
      metric(ExternalCount, scale.externals),
    ],
    functions: [],
    modules: [],
  }
}

///|
fn compilation_snapshot_scale(
  scale : @compile.CompilationStageScale,
) -> ExploreScaleObservation {
  match scale {
    Source(scale) =>
      {
        metrics: [
          metric(DeclarationCount, scale.declarations),
          metric(ImportCount, scale.imports),
          metric(FunctionCount, scale.functions),
          metric(NodeCount, scale.nodes),
          metric(CallCount, scale.calls),
          metric(SourceGenericBinderCount, scale.generic_binders),
          metric(SourceTypeApplicationCount, scale.type_applications),
        ],
        functions: [],
        modules: [],
      }
    Buslane(scale) => buslane_structural_scale(scale)
  }
}

///|
fn linked_program_scale(
  scale : @buslane.ProgramScale,
  retention : @module_link.LinkRetentionObservation,
) -> ExploreScaleObservation {
  let observation = buslane_structural_scale(scale)
  {
    ..observation,
    modules: retention.modules.map(module_ => {
      module_path_text: module_.module_path_text,
      input_top_terms: module_.input_top_terms,
      retained_top_terms: module_.retained_top_terms,
      input_value_bindings: module_.input_value_bindings,
      retained_value_bindings: module_.retained_value_bindings,
    }),
  }
}

///|
fn effect_lowering_snapshot_scale(
  scale : @effect_lowering.EffectLoweringScale,
) -> ExploreScaleObservation {
  {
    metrics: [
      metric(TopTermCount, scale.top_terms),
      metric(FunctionCount, scale.functions),
      metric(NodeCount, scale.nodes),
      metric(CallCount, scale.calls),
    ],
    functions: [],
    modules: [],
  }
}

///|
fn anf_observation(program : @anf.AnfProgram) -> AnfStageObservation {
  let accumulator : AnfScaleAccumulator = {
    function_count: 0,
    call_count: 0,
    generic_binder_count: 0,
    type_application_count: 0,
    functions: [],
    anf_functions: [],
  }
  let mut nodes = 0
  for term in program.terms() {
    nodes += 1
    match term {
      Let(_, expression) =>
        nodes += observe_anf_top_expr(expression, accumulator)
      LetRec(bindings) =>
        for binding in bindings {
          nodes += 1 + observe_anf_top_atom(binding.rhs, accumulator)
        }
      External(_) => ()
    }
  }
  accumulator.functions.sort_by(fn(left, right) { left.index - right.index })
  accumulator.anf_functions.sort_by(fn(left, right) {
    left.function.value - right.function.value
  })
  let scale = {
    metrics: [
      metric(TopTermCount, program.terms().length()),
      metric(FunctionCount, accumulator.function_count),
      metric(NodeCount, nodes),
      metric(CallCount, accumulator.call_count),
      metric(GenericBinderCount, accumulator.generic_binder_count),
      metric(TypeApplicationCount, accumulator.type_application_count),
    ],
    functions: accumulator.functions,
    modules: [],
  }
  { scale, functions: accumulator.anf_functions, }
}

///|
fn observe_anf_function(
  function : @anf.AnfFunction,
  accumulator : AnfScaleAccumulator,
  disposition : ExploreFunctionRole,
) -> Int {
  let body_nodes = observe_anf_expr(function.body, accumulator)
  accumulator.functions.push({
    index: function.id.value,
    block_count: 0,
    operation_count: body_nodes,
    value_count: function.parameters.length(),
  })
  accumulator.anf_functions.push({
    function: function.id,
    source: function.source,
    origin: function.origin,
    disposition,
  })
  accumulator.function_count += 1
  body_nodes
}

///|
fn observe_anf_top_expr(
  expression : @anf.AnfExpr,
  accumulator : AnfScaleAccumulator,
) -> Int {
  match expression {
    Atom(atom) => 1 + observe_anf_top_atom(atom, accumulator)
    _ => observe_anf_expr(expression, accumulator)
  }
}

///|
fn observe_anf_top_atom(
  atom : @anf.AnfAtom,
  accumulator : AnfScaleAccumulator,
) -> Int {
  match atom {
    Function(function) =>
      1 + observe_anf_function(function, accumulator, RuntimeAnfTopLevelRoot)
    EvidenceLambda(parameters~, body~) => {
      accumulator.generic_binder_count += parameters.length()
      1 + observe_anf_top_expr(body, accumulator)
    }
    DirectFunction(_) | JoinPoint(_) =>
      abort("Runtime ANF top-level callable has a lexical disposition")
    Literal(_) | Ref(_) | Temp(_) => 1
  }
}

///|
fn observe_anf_expr(
  expression : @anf.AnfExpr,
  accumulator : AnfScaleAccumulator,
) -> Int {
  match expression {
    Atom(atom) => 1 + observe_anf_atom(atom, accumulator)
    Let(binding, body) => {
      let rhs = match binding {
        Value(rhs~, ..) | Temp(rhs~, ..) => rhs
      }
      1 +
      observe_anf_rhs(rhs, accumulator) +
      observe_anf_expr(body, accumulator)
    }
    LetRec(bindings, body) => {
      let mut nodes = 1 + observe_anf_expr(body, accumulator)
      for binding in bindings {
        nodes += 1 + observe_anf_atom(binding.rhs, accumulator)
      }
      nodes
    }
  }
}

///|
fn observe_anf_rhs(rhs : @anf.AnfRhs, accumulator : AnfScaleAccumulator) -> Int {
  match rhs {
    Atom(atom) => 1 + observe_anf_atom(atom, accumulator)
    Call(callee~, arguments~) => {
      accumulator.call_count += 1
      1 +
      observe_anf_atom(callee, accumulator) +
      arguments.fold(init=0, fn(total, argument) {
        total + observe_anf_atom(argument, accumulator)
      })
    }
    ApplyEvidence(callee~, ..) => {
      accumulator.type_application_count += 1
      1 + observe_anf_atom(callee, accumulator)
    }
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(total, payload) {
        total + observe_anf_atom(payload, accumulator)
      })
    Match(match_) => {
      let mut nodes = 1 + observe_anf_atom(match_.scrutinee, accumulator)
      for alternative in match_.alternatives {
        nodes += 1 + observe_anf_expr(alternative.body, accumulator)
      }
      nodes
    }
  }
}

///|
fn observe_anf_atom(
  atom : @anf.AnfAtom,
  accumulator : AnfScaleAccumulator,
) -> Int {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => 1
    Function(function) =>
      1 + observe_anf_function(function, accumulator, RuntimeAnfEscapingClosure)
    DirectFunction(function) =>
      1 + observe_anf_function(function, accumulator, RuntimeAnfDirectFunction)
    JoinPoint(function) =>
      1 + observe_anf_function(function, accumulator, RuntimeAnfJoinPoint)
    EvidenceLambda(parameters~, body~) => {
      accumulator.generic_binder_count += parameters.length()
      1 + observe_anf_expr(body, accumulator)
    }
  }
}

///|
priv struct LoweredScaleAccumulator {
  mut block_count : Int
  mut instruction_count : Int
  mut value_count : Int
  mut direct_calls : Int
  mut indirect_calls : Int
  mut function_references : Int
  mut closures : Int
  mut environments : Int
  mut erasures : Int
  mut unerasures : Int
  mut retains : Int
  mut releases : Int
  functions : Array[ExploreFunctionScale]
}

///|
fn lowered_accumulator() -> LoweredScaleAccumulator {
  {
    block_count: 0,
    instruction_count: 0,
    value_count: 0,
    direct_calls: 0,
    indirect_calls: 0,
    function_references: 0,
    closures: 0,
    environments: 0,
    erasures: 0,
    unerasures: 0,
    retains: 0,
    releases: 0,
    functions: [],
  }
}

///|
fn lowered_metrics(
  accumulator : LoweredScaleAccumulator,
  function_count : Int,
  import_count : Int,
  storage_metric : ExploreMetricId,
  storage_count : Int,
) -> Array[ExploreMetric] {
  [
    metric(FunctionCount, function_count),
    metric(ImportCount, import_count),
    metric(BlockCount, accumulator.block_count),
    metric(InstructionCount, accumulator.instruction_count),
    metric(storage_metric, storage_count),
    metric(DirectCallCount, accumulator.direct_calls),
    metric(IndirectCallCount, accumulator.indirect_calls),
    metric(FunctionReferenceCount, accumulator.function_references),
    metric(ClosureCount, accumulator.closures),
    metric(EnvironmentCount, accumulator.environments),
    metric(EraseCount, accumulator.erasures),
    metric(UneraseCount, accumulator.unerasures),
    metric(RetainCount, accumulator.retains),
    metric(ReleaseCount, accumulator.releases),
  ]
}

///|
fn vmcfg_scale(
  image : @vmcfg.Image,
  functions : Array[@physical_lowering.PhysicalFunctionProvenance],
  runtime_abi_workers : @physical_lowering.RuntimeAbiWorkerEmissionSummary,
) -> ExploreScaleObservation {
  let accumulator = lowered_accumulator()
  let mut body_count = 0
  let mut import_count = 0
  for index, entry in image.functions {
    match entry {
      Body(body) => {
        body_count += 1
        let instruction_count = body.blocks.fold(init=0, fn(total, block) {
          total + block.instructions.length()
        })
        accumulator.block_count += body.blocks.length()
        accumulator.instruction_count += instruction_count
        accumulator.value_count += body.values.length()
        accumulator.functions.push({
          index: functions[index].function.value,
          block_count: body.blocks.length(),
          operation_count: instruction_count,
          value_count: body.values.length(),
        })
        for block in body.blocks {
          for instruction in block.instructions {
            observe_vmcfg_instruction(instruction, accumulator)
          }
          observe_vmcfg_terminator(block.terminator, accumulator)
        }
      }
      RuntimeImport(_) => import_count += 1
    }
  }
  let metrics = lowered_metrics(
      accumulator,
      body_count,
      import_count,
      ValueCount,
      accumulator.value_count,
    ) +
    [
      metric(GlobalCount, image.globals.length()),
      metric(LayoutCount, image.layouts.length()),
      metric(ObjectShapeCount, image.object_shapes.length()),
      metric(ConstantCount, image.constants.length()),
    ]
  if runtime_abi_workers.emission_count > 0 {
    metrics.push(
      metric(
        DuplicateRuntimeAbiWorkerCount,
        runtime_abi_workers.duplicate_count,
      ),
    )
  }
  { metrics, functions: accumulator.functions, modules: [], }
}

///|
fn observe_vmcfg_instruction(
  instruction : @vmcfg.Instruction,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match instruction {
    CallDirect(_, _, _, _, _) | CallPackedDirect(_, _, _, _, _) =>
      accumulator.direct_calls += 1
    CallValue(_, _, _, _) => accumulator.indirect_calls += 1
    ConstFunction(_, _) => accumulator.function_references += 1
    MakeClosure(_, _, _) => {
      accumulator.function_references += 1
      accumulator.closures += 1
    }
    MakeEnv(_, _, _, _, _) => accumulator.environments += 1
    RetainCopy(_, _) => accumulator.retains += 1
    Release(_) => accumulator.releases += 1
    EraseI32(_, _)
    | EraseI64(_, _)
    | EraseF64(_, _)
    | EraseF32(_, _)
    | EraseUnit(_) => accumulator.erasures += 1
    UneraseI32(_, _)
    | UneraseI64(_, _)
    | UneraseF64(_, _)
    | UneraseF32(_, _)
    | UneraseUnit(_) => accumulator.unerasures += 1
    _ => ()
  }
}

///|
fn observe_vmcfg_terminator(
  terminator : @vmcfg.Terminator,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match terminator {
    TailCallDirect(_, _, _, _) | TailCallPackedDirect(_, _, _, _) =>
      accumulator.direct_calls += 1
    TailCallValue(_, _, _) => accumulator.indirect_calls += 1
    _ => ()
  }
}

///|
fn physical_scale(
  image : @physical.PhysicalProgram,
  functions : Array[@physical_lowering.PhysicalFunctionProvenance],
  runtime_abi_workers : @physical_lowering.RuntimeAbiWorkerEmissionSummary,
) -> ExploreScaleObservation {
  let accumulator = lowered_accumulator()
  let mut body_count = 0
  let mut import_count = 0
  let mut slot_count = 0
  for index, entry in image.functions {
    match entry {
      PhysicalBody(body) => {
        body_count += 1
        let instruction_count = body.blocks.fold(init=0, fn(total, block) {
          total + block.instructions.length()
        })
        slot_count += body.slots.length()
        accumulator.block_count += body.blocks.length()
        accumulator.instruction_count += instruction_count
        accumulator.functions.push({
          index: functions[index].function.value,
          block_count: body.blocks.length(),
          operation_count: instruction_count,
          value_count: body.slots.length(),
        })
        for block in body.blocks {
          for instruction in block.instructions {
            observe_physical_instruction(instruction, accumulator)
          }
          observe_physical_terminator(block.terminator, accumulator)
        }
      }
      RuntimeImport(_) => import_count += 1
    }
  }
  let metrics = lowered_metrics(
    accumulator,
    body_count,
    import_count,
    SlotCount,
    slot_count,
  )
  metrics.append([
    metric(CallableAbiCount, image.callable_abis.length()),
    metric(GlobalCount, image.globals.length()),
    metric(LayoutCount, image.layouts.length()),
    metric(ObjectShapeCount, image.object_shapes.length()),
    metric(ConstantCount, image.constants.length()),
  ])
  if runtime_abi_workers.emission_count > 0 {
    metrics.push(
      metric(
        DuplicateRuntimeAbiWorkerCount,
        runtime_abi_workers.duplicate_count,
      ),
    )
  }
  { metrics, functions: accumulator.functions, modules: [], }
}

///|
fn observe_physical_instruction(
  instruction : @physical.Instruction,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match instruction {
    CallDirect(_, _, _, _, _) | CallPackedDirect(_, _, _, _, _) =>
      accumulator.direct_calls += 1
    CallValue(_, _, _, _, _) => accumulator.indirect_calls += 1
    ConstFunction(_, _) => accumulator.function_references += 1
    MakeClosure(_, _, _) => {
      accumulator.function_references += 1
      accumulator.closures += 1
    }
    MakeEnv(_, _, _, _, _) => accumulator.environments += 1
    RetainCopy(_, _) => accumulator.retains += 1
    Release(_) => accumulator.releases += 1
    EraseI32(_, _)
    | EraseI64(_, _)
    | EraseF64(_, _)
    | EraseF32(_, _)
    | EraseUnit(_) => accumulator.erasures += 1
    UneraseI32(_, _)
    | UneraseI64(_, _)
    | UneraseF64(_, _)
    | UneraseF32(_, _)
    | UneraseUnit(_) => accumulator.unerasures += 1
    _ => ()
  }
}

///|
fn observe_physical_terminator(
  terminator : @physical.Terminator,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match terminator {
    TailCallDirect(_, _, _, _) | TailCallPackedDirect(_, _, _, _) =>
      accumulator.direct_calls += 1
    TailCallValue(_, _, _, _) => accumulator.indirect_calls += 1
    _ => ()
  }
}

///|
fn wasm_scale(
  scale : @wasm_compiler.WasmModuleScale,
) -> ExploreScaleObservation {
  let metrics = [
    metric(FunctionCount, scale.defined_function_count),
    metric(ImportCount, scale.imported_function_count),
    metric(InstructionCount, scale.instruction_count),
    metric(LocalCount, scale.local_count),
    metric(TableEntryCount, scale.table_entry_count),
    metric(WasmIfCount, scale.if_count),
    metric(WasmUnreachableCount, scale.unreachable_count),
    metric(
      UnreachableWasmSupportRoleCount,
      scale.unreachable_support_role_count,
    ),
  ]
  for expansion in scale.expansions {
    let category = expansion.category.key()
    if expansion.instruction_count != 0 {
      metrics.push(
        metric(
          WasmExpansionInstructionCount(category),
          expansion.instruction_count,
        ),
      )
    }
    if expansion.local_count != 0 {
      metrics.push(
        metric(WasmExpansionLocalCount(category), expansion.local_count),
      )
    }
  }
  {
    metrics,
    functions: scale.functions.map(function => {
      index: function.index,
      block_count: 0,
      operation_count: function.instruction_count,
      value_count: function.local_count,
    }),
    modules: [],
  }
}
