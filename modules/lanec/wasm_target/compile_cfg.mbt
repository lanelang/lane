///|
let maximum_linear_control_blocks = 16

///|
fn terminator_transfers_control(terminator : @physical.Terminator) -> Bool {
  match terminator {
    Jump(_) | BranchBool(_, _, _) | SwitchTag(_, _, _) => true
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallPackedDirect(_, _, _, _)
    | TailCallValue(_, _, _, _)
    | Fatal(_)
    | Unreachable => false
  }
}

///|
fn compile_dispatcher(
  context : FunctionCompilationContext,
) -> @wasm_types.Instruction raise WasmCompileError {
  let block_count = context.body.blocks.length()
  let state_local = context.dispatcher_state_local()
  let labels : Array[Int] = []
  for index in 0..<block_count {
    labels.push(index)
  }
  let dispatch : Array[@wasm_types.Instruction] = [
    LocalGet(state_local),
    BrTable(labels, block_count),
  ]
  for block_index in 0..<block_count {
    let block = context.body.blocks[block_index]
    let wrapped : Array[@wasm_types.Instruction] = [
      Block(Empty, dispatch.copy()),
    ]
    for instruction in block.instructions {
      wrapped.append(context.compile_instruction(instruction))
    }
    wrapped.append(
      compile_dispatch_terminator(
        context,
        state_local,
        block_count - block_index,
        block.terminator,
      ),
    )
    dispatch.clear()
    dispatch.append(wrapped)
  }
  Loop(Empty, [Block(Empty, dispatch), Unreachable])
}

///|
fn compile_balanced_dispatcher(
  context : FunctionCompilationContext,
) -> @wasm_types.Instruction raise WasmCompileError {
  let state_local = context.dispatcher_state_local()
  let body = compile_balanced_dispatch_range(
    context,
    state_local,
    start=0,
    end=context.body.blocks.length(),
    loop_depth=0,
  )
  body.push(Unreachable)
  Loop(Empty, body)
}

///|
fn compile_balanced_dispatch_range(
  context : FunctionCompilationContext,
  state_local : Int,
  start~ : Int,
  end~ : Int,
  loop_depth~ : Int,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  if end - start == 1 {
    let block = context.body.blocks[start]
    let instructions : Array[@wasm_types.Instruction] = []
    for instruction in block.instructions {
      instructions.append(context.compile_instruction(instruction))
    }
    instructions.append(
      compile_dispatch_terminator(
        context,
        state_local,
        loop_depth,
        block.terminator,
      ),
    )
    return instructions
  }
  let middle = start + (end - start) / 2
  [
    LocalGet(state_local),
    I32Const(middle),
    I32LtU,
    If(
      Empty,
      compile_balanced_dispatch_range(
        context,
        state_local,
        start~,
        end=middle,
        loop_depth=loop_depth + 1,
      ),
      compile_balanced_dispatch_range(
        context,
        state_local,
        start=middle,
        end~,
        loop_depth=loop_depth + 1,
      ),
    ),
  ]
}

///|
fn compile_dispatch_terminator(
  context : FunctionCompilationContext,
  state_local : Int,
  loop_depth : Int,
  terminator : @physical.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  match terminator {
    Jump(edge) => compile_edge(context, state_local, loop_depth, edge)
    BranchBool(condition, if_true, if_false) =>
      [
        LocalGet(context.slot_local(condition)),
        If(
          Empty,
          compile_edge(context, state_local, loop_depth + 1, if_true),
          compile_edge(context, state_local, loop_depth + 1, if_false),
        ),
      ]
    SwitchTag(discriminator, cases, default) =>
      compile_switch(
        context, state_local, loop_depth, discriminator, cases, default,
      )
    terminal => context.compile_terminator(terminal)
  }
}

///|
fn compile_switch(
  context : FunctionCompilationContext,
  state_local : Int,
  loop_depth : Int,
  discriminator : @physical.SlotId,
  cases : Array[@physical.Edge],
  default : @physical.Edge,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  if cases.is_empty() {
    return compile_edge(context, state_local, loop_depth, default)
  }
  let labels : Array[Int] = []
  for index in 0..<cases.length() {
    labels.push(index)
  }
  let selection : Array[@wasm_types.Instruction] = [
    LocalGet(context.slot_local(discriminator)),
    BrTable(labels, cases.length()),
  ]
  for case_index in 0..<cases.length() {
    let wrapped : Array[@wasm_types.Instruction] = [
      Block(Empty, selection.copy()),
    ]
    wrapped.append(
      compile_edge(
        context,
        state_local,
        loop_depth + cases.length() - case_index,
        cases[case_index],
      ),
    )
    selection.clear()
    selection.append(wrapped)
  }
  let result : Array[@wasm_types.Instruction] = [Block(Empty, selection)]
  result.append(compile_edge(context, state_local, loop_depth, default))
  result
}

///|
fn compile_edge(
  context : FunctionCompilationContext,
  state_local : Int,
  loop_depth : Int,
  edge : @physical.Edge,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  if edge.target.value < 0 || edge.target.value >= context.body.blocks.length() {
    raise InvalidBlockTarget(
      function_id=context.function_id,
      target=edge.target.value,
    )
  }
  let target_parameters = context.body.blocks[edge.target.value].parameters
  if target_parameters.length() != edge.arguments.length() {
    raise InvalidEdgeArity(
      function_id=context.function_id,
      target=edge.target.value,
      expected=target_parameters.length(),
      actual=edge.arguments.length(),
    )
  }
  let instructions : Array[@wasm_types.Instruction] = []
  for index, _ in target_parameters {
    instructions.push(LocalGet(context.slot_local(edge.arguments[index])))
    instructions.push(LocalSet(context.transfer_local(edge.target, index)))
  }
  for index, destination in target_parameters {
    instructions.push(LocalGet(context.transfer_local(edge.target, index)))
    instructions.push(LocalSet(context.slot_local(destination)))
  }
  instructions.push(I32Const(edge.target.value))
  instructions.push(LocalSet(state_local))
  instructions.push(Br(loop_depth))
  instructions
}
