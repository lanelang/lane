///|
fn flow_scalar_metadata(
  representation : @bytecode.Representation,
) -> ValueMetadata {
  {
    representation,
    cleanup: Trivial,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
fn flow_edge(target : Int, arguments : Array[ValueId]) -> Edge {
  { target: { value: target }, arguments }
}

///|
fn flow_definition_text(definition : ValueDefinition) -> String {
  match definition {
    FunctionInput(index) => "input:\{index}"
    BlockParameter(block, index) => "parameter:\{block}:\{index}"
    InstructionResult(block, index) => "instruction:\{block}:\{index}"
  }
}

///|
fn flow_use_text(use_site : ValueUseSite) -> String {
  match use_site {
    InstructionUse(block, index) => "instruction:\{block}:\{index}"
    TerminatorUse(block) => "terminator:\{block}"
  }
}

///|
test "VM CFG analyses describe a diamond and ignore unreachable dominance" {
  let body : FunctionBody = {
    values: [
      flow_scalar_metadata(I32),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }],
    },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: BranchBool({ value: 0 }, flow_edge(1, []), flow_edge(2, [])),
      },
      {
        parameters: [],
        instructions: [IntAdd({ value: 2 }, { value: 1 }, { value: 1 })],
        terminator: Jump(flow_edge(3, [{ value: 2 }])),
      },
      {
        parameters: [],
        instructions: [IntSub({ value: 3 }, { value: 1 }, { value: 1 })],
        terminator: Jump(flow_edge(3, [{ value: 3 }])),
      },
      {
        parameters: [{ value: 4 }],
        instructions: [IntAdd({ value: 5 }, { value: 4 }, { value: 1 })],
        terminator: Return(Some({ value: 5 })),
      },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  let control_flow = analyze_control_flow(body.blocks)
  let use_def = analyze_use_def(body)
  let liveness = analyze_liveness(body, control_flow, use_def)
  debug_inspect(
    (
      control_flow.predecessors,
      control_flow.reachable,
      control_flow.dominators,
      control_flow.immediate_dominators,
      use_def.definitions.map(definition => definition.map(flow_definition_text)),
      use_def.uses.map(sites => sites.map(flow_use_text)),
      liveness.live_in,
      liveness.live_out,
      [
        liveness.is_live_after_instruction(body, 1, 0, { value: 1 }),
        liveness.is_live_after_instruction(body, 1, 0, { value: 2 }),
        liveness.is_live_after_instruction(body, 3, 0, { value: 4 }),
        liveness.is_live_after_instruction(body, 3, 0, { value: 5 }),
      ],
    ),
    content=(
      #|(
      #|  [[], [0], [0], [1, 2], []],
      #|  [true, true, true, true, false],
      #|  [
      #|    [true, false, false, false, false],
      #|    [true, true, false, false, false],
      #|    [true, false, true, false, false],
      #|    [true, false, false, true, false],
      #|    [false, false, false, false, false],
      #|  ],
      #|  [None, Some(0), Some(0), Some(0), None],
      #|  [
      #|    Some("input:0"),
      #|    Some("input:1"),
      #|    Some("instruction:1:0"),
      #|    Some("instruction:2:0"),
      #|    Some("parameter:3:0"),
      #|    Some("instruction:3:0"),
      #|  ],
      #|  [
      #|    ["terminator:0"],
      #|    [
      #|      "instruction:1:0",
      #|      "instruction:1:0",
      #|      "instruction:2:0",
      #|      "instruction:2:0",
      #|      "instruction:3:0",
      #|    ],
      #|    ["terminator:1"],
      #|    ["terminator:2"],
      #|    ["instruction:3:0"],
      #|    ["terminator:3"],
      #|  ],
      #|  [
      #|    [false, false, false, false, false, false],
      #|    [false, true, false, false, false, false],
      #|    [false, true, false, false, false, false],
      #|    [false, true, false, false, false, false],
      #|    [false, false, false, false, false, false],
      #|  ],
      #|  [
      #|    [false, true, false, false, false, false],
      #|    [false, true, false, false, false, false],
      #|    [false, true, false, false, false, false],
      #|    [false, false, false, false, false, false],
      #|    [false, false, false, false, false, false],
      #|  ],
      #|  [true, true, false, true],
      #|)
    ),
  )
}

///|
test "VM CFG analyses converge through a loop with block parameters" {
  let body : FunctionBody = {
    values: [
      flow_scalar_metadata(I32),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
      flow_scalar_metadata(I64),
    ],
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: [{ value: 0 }, { value: 1 }, { value: 2 }],
    },
    result: I64,
    blocks: [
      {
        parameters: [],
        instructions: [],
        terminator: Jump(flow_edge(1, [{ value: 1 }])),
      },
      {
        parameters: [{ value: 3 }],
        instructions: [IntAdd({ value: 4 }, { value: 3 }, { value: 2 })],
        terminator: BranchBool(
          { value: 0 },
          flow_edge(1, [{ value: 4 }]),
          flow_edge(2, [{ value: 4 }]),
        ),
      },
      {
        parameters: [{ value: 5 }],
        instructions: [],
        terminator: Return(Some({ value: 5 })),
      },
    ],
  }
  let control_flow = analyze_control_flow(body.blocks)
  let use_def = analyze_use_def(body)
  let liveness = analyze_liveness(body, control_flow, use_def)
  debug_inspect(
    (
      control_flow.predecessors,
      control_flow.dominators,
      control_flow.immediate_dominators,
      liveness.live_in,
      liveness.live_out,
      [
        liveness.is_live_after_instruction(body, 1, 0, { value: 0 }),
        liveness.is_live_after_instruction(body, 1, 0, { value: 2 }),
        liveness.is_live_after_instruction(body, 1, 0, { value: 3 }),
        liveness.is_live_after_instruction(body, 1, 0, { value: 4 }),
      ],
    ),
    content=(
      #|(
      #|  [[], [0, 1], [1]],
      #|  [[true, false, false], [true, true, false], [true, true, true]],
      #|  [None, Some(0), Some(1)],
      #|  [
      #|    [false, false, false, false, false, false],
      #|    [true, false, true, false, false, false],
      #|    [false, false, false, false, false, false],
      #|  ],
      #|  [
      #|    [true, false, true, false, false, false],
      #|    [true, false, true, false, false, false],
      #|    [false, false, false, false, false, false],
      #|  ],
      #|  [true, true, false, true],
      #|)
    ),
  )
}
