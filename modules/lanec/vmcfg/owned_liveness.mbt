///|
fn thread_owned_block_values(body : FunctionBody) -> FunctionBody {
  let block_count = body.blocks.length()
  let value_count = body.values.length()
  let control_flow = analyze_control_flow(body.blocks)
  let use_def = analyze_use_def(body)
  let liveness = analyze_liveness(body, control_flow, use_def)
  let threaded : Array[Array[ValueId]] = body.blocks.map(_ => [])
  for block_index in 1..<block_count {
    for value_index in 0..<value_count {
      if body.values[value_index].ownership is Owned &&
        liveness.live_in[block_index][value_index] {
        threaded[block_index].push({ value: value_index })
      }
    }
  }
  {
    ..body,
    blocks: body.blocks.mapi(fn(block_index, block) {
      let carried = threaded[block_index]
      {
        ..block,
        parameters: block.parameters + carried,
        terminator: append_threaded_edge_arguments(block.terminator, threaded),
      }
    }),
  }
}

///|
fn block_successors(block : Block) -> Array[Int] {
  match block.terminator {
    Jump(edge) => [edge.target.value]
    BranchBool(_, if_true, if_false) =>
      [if_true.target.value, if_false.target.value]
    SwitchTag(_, cases, default) => {
      let successors = cases.map(edge => edge.target.value)
      successors.push(default.target.value)
      successors
    }
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Unreachable => []
  }
}

///|
fn append_threaded_edge_arguments(
  terminator : Terminator,
  threaded : Array[Array[ValueId]],
) -> Terminator {
  match terminator {
    Jump(edge) => Jump(append_threaded_edge(edge, threaded))
    BranchBool(condition, if_true, if_false) =>
      BranchBool(
        condition,
        append_threaded_edge(if_true, threaded),
        append_threaded_edge(if_false, threaded),
      )
    SwitchTag(tag, cases, default) =>
      SwitchTag(
        tag,
        cases.map(edge => append_threaded_edge(edge, threaded)),
        append_threaded_edge(default, threaded),
      )
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Unreachable => terminator
  }
}

///|
fn append_threaded_edge(edge : Edge, threaded : Array[Array[ValueId]]) -> Edge {
  { ..edge, arguments: edge.arguments + threaded[edge.target.value] }
}
