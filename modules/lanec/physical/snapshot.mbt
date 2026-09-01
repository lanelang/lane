///|
fn PhysicalProgram::snapshot(self : PhysicalProgram) -> PhysicalProgram {
  {
    entry: self.entry,
    initializer: self.initializer,
    callable_abis: self.callable_abis.map(abi => abi.snapshot()),
    data_family_count: self.data_family_count,
    functions: self.functions.map(function => function.snapshot()),
    globals: self.globals.copy(),
    layouts: self.layouts.copy(),
    object_shapes: self.object_shapes.map(shape => shape.snapshot()),
    constants: self.constants.copy(),
  }
}

///|
fn CallableAbi::snapshot(self : CallableAbi) -> CallableAbi {
  {
    witnesses: self.witnesses.copy(),
    parameters: self.parameters.copy(),
    result: self.result,
  }
}

///|
fn ObjectShape::snapshot(self : ObjectShape) -> ObjectShape {
  match self {
    Data(shape) => Data({ ..shape, members: shape.members.copy(), })
    Environment(shape) =>
      Environment({ ..shape, members: shape.members.copy(), })
  }
}

///|
fn FunctionEntry::snapshot(self : FunctionEntry) -> FunctionEntry {
  match self {
    PhysicalBody(body) => PhysicalBody(body.snapshot())
    RuntimeImport(contract) => RuntimeImport(contract.snapshot())
  }
}

///|
fn FunctionBody::snapshot(self : FunctionBody) -> FunctionBody {
  {
    slots: self.slots.copy(),
    inputs: self.inputs.snapshot(),
    result: self.result,
    blocks: self.blocks.map(block => block.snapshot()),
  }
}

///|
fn FunctionInputs::snapshot(self : FunctionInputs) -> FunctionInputs {
  {
    environment: self.environment,
    witnesses: self.witnesses.copy(),
    user_parameters: self.user_parameters.copy(),
  }
}

///|
fn Block::snapshot(self : Block) -> Block {
  {
    parameters: self.parameters.copy(),
    instructions: self.instructions.map(instruction => instruction.snapshot()),
    terminator: self.terminator.snapshot(),
  }
}

///|
fn Instruction::snapshot(self : Instruction) -> Instruction {
  match self {
    CallDirect(function, destination, witnesses, arguments, environment) =>
      CallDirect(
        function,
        destination,
        witnesses.copy(),
        arguments.copy(),
        environment,
      )
    CallRuntimeImport(function, arguments, destination) =>
      CallRuntimeImport(function, arguments.copy(), destination)
    CallPackedDirect(function, callable, witnesses, arguments, destination) =>
      CallPackedDirect(
        function,
        callable,
        witnesses.copy(),
        arguments.copy(),
        destination,
      )
    CallValue(callable, abi, witnesses, arguments, destination) =>
      CallValue(callable, abi, witnesses.copy(), arguments.copy(), destination)
    MakeData(destination, shape, layout, witnesses, fields) =>
      MakeData(destination, shape, layout, witnesses.copy(), fields.copy())
    ConsumeFields(shape, source, selections) =>
      ConsumeFields(shape, source, selections.copy())
    MakeEnv(destination, shape, layout, witnesses, captures) =>
      MakeEnv(destination, shape, layout, witnesses.copy(), captures.copy())
    ConsumeCaptures(shape, source, selections) =>
      ConsumeCaptures(shape, source, selections.copy())
    _ => self
  }
}

///|
fn Terminator::snapshot(self : Terminator) -> Terminator {
  match self {
    Jump(edge) => Jump(edge.snapshot())
    BranchBool(condition, consequent, alternative) =>
      BranchBool(condition, consequent.snapshot(), alternative.snapshot())
    SwitchTag(scrutinee, alternatives, default) =>
      SwitchTag(
        scrutinee,
        alternatives.map(edge => edge.snapshot()),
        default.snapshot(),
      )
    TailCallDirect(function, environment, witnesses, arguments) =>
      TailCallDirect(function, environment, witnesses.copy(), arguments.copy())
    TailCallPackedDirect(function, callable, witnesses, arguments) =>
      TailCallPackedDirect(
        function,
        callable,
        witnesses.copy(),
        arguments.copy(),
      )
    TailCallValue(callable, abi, witnesses, arguments) =>
      TailCallValue(callable, abi, witnesses.copy(), arguments.copy())
    Return(_) | Fatal | Unreachable => self
  }
}

///|
fn Edge::snapshot(self : Edge) -> Edge {
  { target: self.target, arguments: self.arguments.copy(), }
}

///|
fn GlobalLifecyclePlan::snapshot(
  self : GlobalLifecyclePlan,
) -> GlobalLifecyclePlan {
  {
    roots: self.roots.copy(),
    root_ordinals: self.root_ordinals.copy(),
    owned_roots: self.owned_roots.copy(),
  }
}
