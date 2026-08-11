///|
priv struct TreeScaleAccumulator {
  mut function_count : Int
  mut call_count : Int
  functions : Array[ExploreFunctionScale]
  anf_functions : Array[ObservedAnfFunction]
}

///|
fn empty_scale() -> ExploreScaleObservation {
  { metrics: [], functions: [] }
}

///|
fn metric(id : ExploreMetricId, value : Int) -> ExploreMetric {
  { id, value }
}

///|
fn buslane_scale(program : @buslane.Program) -> ExploreScaleObservation {
  let accumulator : TreeScaleAccumulator = {
    function_count: 0,
    call_count: 0,
    functions: [],
    anf_functions: [],
  }
  let mut nodes = 0
  for term in program.terms {
    nodes += 1
    match term {
      Let(_, expression) =>
        nodes += observe_buslane_expr(expression, accumulator)
      LetRec(bindings) =>
        for binding in bindings {
          nodes += 1 + observe_buslane_expr(binding.rhs, accumulator)
        }
      External(_) => ()
    }
  }
  {
    metrics: [
      metric(TopTermCount, program.terms.length()),
      metric(FunctionCount, accumulator.function_count),
      metric(NodeCount, nodes),
      metric(CallCount, accumulator.call_count),
    ],
    functions: accumulator.functions,
  }
}

///|
fn observe_buslane_expr(
  expression : @buslane.Expr,
  accumulator : TreeScaleAccumulator,
) -> Int {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => 1
    Function(function) => {
      let body_nodes = observe_buslane_expr(function.body, accumulator)
      accumulator.functions.push({
        index: accumulator.function_count,
        block_count: 0,
        operation_count: body_nodes,
        value_count: function.parameters.length(),
      })
      accumulator.function_count += 1
      1 + body_nodes
    }
    Call(callee, arguments) => {
      accumulator.call_count += 1
      1 +
      observe_buslane_expr(callee, accumulator) +
      arguments.fold(init=0, fn(total, argument) {
        total + observe_buslane_expr(argument, accumulator)
      })
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      1 + observe_buslane_expr(body, accumulator)
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(total, payload) {
        total + observe_buslane_expr(payload, accumulator)
      })
    Let(_, initializer, body) =>
      1 +
      observe_buslane_expr(initializer, accumulator) +
      observe_buslane_expr(body, accumulator)
    LetRec(bindings, body) => {
      let mut nodes = 1 + observe_buslane_expr(body, accumulator)
      for binding in bindings {
        nodes += 1 + observe_buslane_expr(binding.rhs, accumulator)
      }
      nodes
    }
    Match(match_) => {
      let mut nodes = 1 + observe_buslane_expr(match_.scrutinee, accumulator)
      for alternative in match_.alternatives {
        nodes += 1 + observe_buslane_expr(alternative.body, accumulator)
      }
      nodes
    }
    Perform(perform) =>
      1 +
      perform.payloads.fold(init=0, fn(total, payload) {
        total + observe_buslane_expr(payload, accumulator)
      })
    Handle(handle) => {
      let mut nodes = 1 +
        observe_buslane_expr(handle.body, accumulator) +
        observe_buslane_expr(handle.final_body, accumulator)
      for table in handle.handlers {
        nodes += 1
        for operation in table.operations {
          nodes += 1 + observe_buslane_expr(operation.body, accumulator)
        }
      }
      nodes
    }
  }
}

///|
fn effect_lowering_scale(
  program : @effect_lowering_core.Program,
) -> ExploreScaleObservation {
  let accumulator : TreeScaleAccumulator = {
    function_count: 0,
    call_count: 0,
    functions: [],
    anf_functions: [],
  }
  let mut nodes = 0
  for term in program.terms {
    nodes += 1
    match term {
      Let(_, expression) =>
        nodes += observe_effect_lowering_expr(expression, accumulator)
      LetRec(bindings) =>
        for binding in bindings {
          nodes += 1 + observe_effect_lowering_expr(binding.rhs, accumulator)
        }
      External(_) => ()
    }
  }
  {
    metrics: [
      metric(TopTermCount, program.terms.length()),
      metric(FunctionCount, accumulator.function_count),
      metric(NodeCount, nodes),
      metric(CallCount, accumulator.call_count),
    ],
    functions: accumulator.functions,
  }
}

///|
fn observe_effect_function(
  function : @effect_lowering_core.FunctionExpr,
  accumulator : TreeScaleAccumulator,
) -> Int {
  let body_nodes = observe_effect_lowering_expr(function.body, accumulator)
  accumulator.functions.push({
    index: accumulator.function_count,
    block_count: 0,
    operation_count: body_nodes,
    value_count: function.parameters.length(),
  })
  accumulator.function_count += 1
  body_nodes
}

///|
fn observe_effect_lowering_expr(
  expression : @effect_lowering_core.Expr,
  accumulator : TreeScaleAccumulator,
) -> Int {
  match expression {
    Ref(_) | Literal(_) => 1
    Function(function) => 1 + observe_effect_function(function, accumulator)
    Call(callee, arguments) => {
      accumulator.call_count += 1
      1 +
      observe_effect_lowering_expr(callee, accumulator) +
      arguments.fold(init=0, fn(total, argument) {
        total + observe_effect_lowering_expr(argument, accumulator)
      })
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      1 + observe_effect_lowering_expr(body, accumulator)
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(total, payload) {
        total + observe_effect_lowering_expr(payload, accumulator)
      })
    Let(_, initializer, body) =>
      1 +
      observe_effect_lowering_expr(initializer, accumulator) +
      observe_effect_lowering_expr(body, accumulator)
    LetRec(bindings, body) => {
      let mut nodes = 1 + observe_effect_lowering_expr(body, accumulator)
      for binding in bindings {
        nodes += 1 + observe_effect_lowering_expr(binding.rhs, accumulator)
      }
      nodes
    }
    Match(match_) => {
      let mut nodes = 1 +
        observe_effect_lowering_expr(match_.scrutinee, accumulator)
      for alternative in match_.alternatives {
        nodes += 1 + observe_effect_lowering_expr(alternative.body, accumulator)
      }
      nodes
    }
    Invoke(invoke) =>
      1 +
      invoke.payloads.fold(init=0, fn(total, payload) {
        total + observe_effect_lowering_expr(payload, accumulator)
      })
    Install(install) => {
      let mut nodes = 1 +
        observe_effect_lowering_expr(install.body, accumulator) +
        1 +
        observe_effect_function(install.final_clause, accumulator)
      for dictionary in install.dictionaries {
        nodes += 1
        for operation in dictionary.operations {
          let callable_nodes = match operation.callable {
            Monomorphic(function) | Polymorphic(_, function) =>
              observe_effect_function(function, accumulator)
          }
          nodes += 2 + callable_nodes
        }
      }
      nodes
    }
    Bind(bind) =>
      2 +
      observe_effect_lowering_expr(bind.computation, accumulator) +
      observe_effect_function(bind.continuation, accumulator)
    OpenContext(context) =>
      1 + observe_effect_lowering_expr(context.body, accumulator)
  }
}

///|
fn anf_observation(program : @anf.AnfProgram) -> AnfStageObservation {
  let accumulator : TreeScaleAccumulator = {
    function_count: 0,
    call_count: 0,
    functions: [],
    anf_functions: [],
  }
  let mut nodes = 0
  for term in program.terms {
    nodes += 1
    match term {
      Let(_, expression) => nodes += observe_anf_expr(expression, accumulator)
      LetRec(bindings) =>
        for binding in bindings {
          nodes += 1 + observe_anf_atom(binding.rhs, accumulator)
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
      metric(TopTermCount, program.terms.length()),
      metric(FunctionCount, accumulator.function_count),
      metric(NodeCount, nodes),
      metric(CallCount, accumulator.call_count),
    ],
    functions: accumulator.functions,
  }
  { scale, functions: accumulator.anf_functions }
}

///|
fn observe_anf_function(
  function : @anf.AnfFunction,
  accumulator : TreeScaleAccumulator,
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
  })
  accumulator.function_count += 1
  body_nodes
}

///|
fn observe_anf_expr(
  expression : @anf.AnfExpr,
  accumulator : TreeScaleAccumulator,
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
fn observe_anf_rhs(
  rhs : @anf.AnfRhs,
  accumulator : TreeScaleAccumulator,
) -> Int {
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
    TypeApply(callee~, ..) => 1 + observe_anf_atom(callee, accumulator)
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
    Perform(perform) =>
      1 +
      perform.payloads.fold(init=0, fn(total, payload) {
        total + observe_anf_atom(payload, accumulator)
      })
    Handle(handle) => {
      let mut nodes = 1 +
        observe_anf_expr(handle.body, accumulator) +
        observe_anf_expr(handle.final_body, accumulator)
      for table in handle.handlers {
        nodes += 1
        for operation in table.operations {
          nodes += 1 + observe_anf_expr(operation.body, accumulator)
        }
      }
      nodes
    }
  }
}

///|
fn observe_anf_atom(
  atom : @anf.AnfAtom,
  accumulator : TreeScaleAccumulator,
) -> Int {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => 1
    Function(function) => 1 + observe_anf_function(function, accumulator)
    TypeLambda(body~, ..) => 1 + observe_anf_expr(body, accumulator)
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
fn vmcfg_scale(image : @vmcfg.Image) -> ExploreScaleObservation {
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
          index: index + 1,
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
  {
    metrics: lowered_metrics(
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
    ],
    functions: accumulator.functions,
  }
}

///|
fn observe_vmcfg_instruction(
  instruction : @vmcfg.Instruction,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match instruction {
    CallDirect(_, _, _, _, _) => accumulator.direct_calls += 1
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
    TailCallDirect(_, _, _, _) => accumulator.direct_calls += 1
    TailCallValue(_, _, _) => accumulator.indirect_calls += 1
    _ => ()
  }
}

///|
fn bytecode_scale(image : @bytecode.BytecodeImage) -> ExploreScaleObservation {
  let accumulator = lowered_accumulator()
  let mut body_count = 0
  let mut import_count = 0
  let mut slot_count = 0
  for index, entry in image.functions {
    match entry {
      BytecodeBody(body) => {
        body_count += 1
        let instruction_count = body.blocks.fold(init=0, fn(total, block) {
          total + block.instructions.length()
        })
        slot_count += body.slots.length()
        accumulator.block_count += body.blocks.length()
        accumulator.instruction_count += instruction_count
        accumulator.functions.push({
          index: index + 1,
          block_count: body.blocks.length(),
          operation_count: instruction_count,
          value_count: body.slots.length(),
        })
        for block in body.blocks {
          for instruction in block.instructions {
            observe_bytecode_instruction(instruction, accumulator)
          }
          observe_bytecode_terminator(block.terminator, accumulator)
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
  { metrics, functions: accumulator.functions }
}

///|
fn observe_bytecode_instruction(
  instruction : @bytecode.Instruction,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match instruction {
    CallDirect(_, _, _, _, _) => accumulator.direct_calls += 1
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
fn observe_bytecode_terminator(
  terminator : @bytecode.Terminator,
  accumulator : LoweredScaleAccumulator,
) -> Unit {
  match terminator {
    TailCallDirect(_, _, _, _) => accumulator.direct_calls += 1
    TailCallValue(_, _, _, _) => accumulator.indirect_calls += 1
    _ => ()
  }
}

///|
fn wasm_scale(
  scale : @wasm_compiler.WasmModuleScale,
) -> ExploreScaleObservation {
  {
    metrics: [
      metric(FunctionCount, scale.defined_function_count),
      metric(ImportCount, scale.imported_function_count),
      metric(InstructionCount, scale.instruction_count),
      metric(LocalCount, scale.local_count),
      metric(TableEntryCount, scale.table_entry_count),
    ],
    functions: scale.functions.map(function => {
      index: function.index,
      block_count: 0,
      operation_count: function.instruction_count,
      value_count: function.local_count,
    }),
  }
}
