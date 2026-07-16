///|
fn terminator_transfers_control(terminator : @bytecode.Terminator) -> Bool {
  match terminator {
    Jump(_) | BranchBool(_, _, _) | SwitchTag(_, _, _) => true
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Unreachable => false
  }
}

///|
fn transfer_local(
  parameter_count : Int,
  slot_count : Int,
  slot : @bytecode.SlotId,
) -> Int {
  parameter_count + slot_count + slot.value
}

///|
fn dispatcher_state_local(parameter_count : Int, slot_count : Int) -> Int {
  parameter_count + slot_count * 2
}

///|
fn compile_dispatcher(
  context : FunctionCompilationContext,
) -> @wasm_types.Instruction raise WasmCompileError {
  let block_count = context.body.blocks.length()
  let state_local = dispatcher_state_local(
    context.parameter_count,
    context.body.slots.length(),
  )
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
fn compile_dispatch_terminator(
  context : FunctionCompilationContext,
  state_local : Int,
  loop_depth : Int,
  terminator : @bytecode.Terminator,
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
  discriminator : @bytecode.SlotId,
  cases : Array[@bytecode.Edge],
  default : @bytecode.Edge,
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
  edge : @bytecode.Edge,
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
  for index, destination in target_parameters {
    instructions.push(LocalGet(context.slot_local(edge.arguments[index])))
    instructions.push(LocalSet(context.transfer_local(destination)))
  }
  for source in edge.arguments {
    instructions.append(context.mark_slot_dead(source))
  }
  for destination in target_parameters {
    instructions.push(LocalGet(context.transfer_local(destination)))
    instructions.push(LocalSet(context.slot_local(destination)))
    instructions.append(context.mark_slot_live(destination))
  }
  instructions.push(I32Const(edge.target.value))
  instructions.push(LocalSet(state_local))
  instructions.push(Br(loop_depth))
  instructions
}
