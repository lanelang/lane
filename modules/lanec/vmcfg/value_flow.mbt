///|
priv enum ValueDefinition {
  FunctionInput(Int)
  BlockParameter(Int, Int)
  InstructionResult(Int, Int)
}

///|
priv enum ValueUseSite {
  InstructionUse(Int, Int)
  TerminatorUse(Int)
}

///|
priv struct UseDefAnalysis {
  definitions : Array[ValueDefinition?]
  uses : Array[Array[ValueUseSite]]
}

///|
fn analyze_use_def(body : FunctionBody) -> UseDefAnalysis {
  let definitions : Array[ValueDefinition?] = Array::make(
    body.values.length(),
    None,
  )
  let uses : Array[Array[ValueUseSite]] = body.values.map(_ => [])
  let mut input_index = 0
  if body.inputs.environment is Some(environment) {
    definitions[environment.value] = Some(FunctionInput(input_index))
    input_index += 1
  }
  for value in body.inputs.witnesses {
    definitions[value.value] = Some(FunctionInput(input_index))
    input_index += 1
  }
  for value in body.inputs.user_parameters {
    definitions[value.value] = Some(FunctionInput(input_index))
    input_index += 1
  }
  for block_index, block in body.blocks {
    for parameter_index, parameter in block.parameters {
      definitions[parameter.value] = Some(
        BlockParameter(block_index, parameter_index),
      )
    }
    for instruction_index, instruction in block.instructions {
      for destination in instruction_destinations(instruction) {
        definitions[destination.value] = Some(
          InstructionResult(block_index, instruction_index),
        )
      }
      for value in instruction_uses(instruction) {
        uses[value.value].push(InstructionUse(block_index, instruction_index))
      }
    }
    for value in terminator_uses(block.terminator) {
      uses[value.value].push(TerminatorUse(block_index))
    }
  }
  { definitions, uses }
}

///|
fn UseDefAnalysis::use_count(self : UseDefAnalysis, value : ValueId) -> Int {
  self.uses[value.value].length()
}

///|
fn body_value_use_counts(body : FunctionBody) -> Array[Int] {
  let use_def = analyze_use_def(body)
  body.values.mapi(fn(index, _) { use_def.use_count({ value: index }) })
}

///|
fn ValueDefinition::block(self : ValueDefinition) -> Int {
  match self {
    FunctionInput(_) => 0
    BlockParameter(block, _) | InstructionResult(block, _) => block
  }
}

///|
fn ValueDefinition::position(self : ValueDefinition) -> Int {
  match self {
    FunctionInput(index) | BlockParameter(_, index) => -index - 1
    InstructionResult(_, instruction) => instruction
  }
}

///|
fn ValueUseSite::block(self : ValueUseSite) -> Int {
  match self {
    InstructionUse(block, _) | TerminatorUse(block) => block
  }
}

///|
fn ValueUseSite::position(self : ValueUseSite, body : FunctionBody) -> Int {
  match self {
    InstructionUse(_, instruction) => instruction
    TerminatorUse(block) => body.blocks[block].instructions.length()
  }
}
