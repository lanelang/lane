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
priv struct InstructionUseDefFacts {
  definitions : Array[ValueId]
  uses : Array[ValueId]
}

///|
priv struct BlockUseDefFacts {
  instructions : Array[InstructionUseDefFacts]
  terminator_uses : Array[ValueId]
  use_counts : Array[Int]
}

///|
priv struct UseDefAnalysis {
  definitions : Array[ValueDefinition?]
  uses : Array[Array[ValueUseSite]]
  blocks : Array[BlockUseDefFacts]
}

///|
fn analyze_use_def(body : FunctionBody) -> UseDefAnalysis {
  let definitions : Array[ValueDefinition?] = Array::make(
    body.values.length(),
    None,
  )
  let uses : Array[Array[ValueUseSite]] = body.values.map(_ => [])
  let blocks = []
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
    let instruction_facts = []
    let use_counts = Array::make(body.values.length(), 0)
    for parameter_index, parameter in block.parameters {
      definitions[parameter.value] = Some(
        BlockParameter(block_index, parameter_index),
      )
    }
    for instruction_index, instruction in block.instructions {
      let instruction_definitions = instruction_destinations(instruction)
      let instruction_uses = instruction_operand_values(instruction)
      instruction_facts.push({
        definitions: instruction_definitions,
        uses: instruction_uses,
      })
      for destination in instruction_definitions {
        definitions[destination.value] = Some(
          InstructionResult(block_index, instruction_index),
        )
      }
      for value in instruction_uses {
        uses[value.value].push(InstructionUse(block_index, instruction_index))
        use_counts[value.value] += 1
      }
    }
    let terminator_uses = terminator_operand_values(block.terminator)
    for value in terminator_uses {
      uses[value.value].push(TerminatorUse(block_index))
      use_counts[value.value] += 1
    }
    blocks.push({ instructions: instruction_facts, terminator_uses, use_counts })
  }
  { definitions, uses, blocks }
}

///|
fn UseDefAnalysis::use_count(self : UseDefAnalysis, value : ValueId) -> Int {
  self.uses[value.value].length()
}

///|
fn UseDefAnalysis::use_count_in_block(
  self : UseDefAnalysis,
  block : Int,
  value : ValueId,
) -> Int {
  self.blocks[block].use_counts[value.value]
}

///|
fn UseDefAnalysis::is_used_only_in_block(
  self : UseDefAnalysis,
  value : ValueId,
  block : Int,
) -> Bool {
  let total = self.use_count(value)
  total > 0 && total == self.use_count_in_block(block, value)
}

///|
fn UseDefAnalysis::copy_block_use_counts(
  self : UseDefAnalysis,
  block : Int,
) -> Array[Int] {
  self.blocks[block].use_counts.copy()
}

///|
fn UseDefAnalysis::instruction_definitions(
  self : UseDefAnalysis,
  block : Int,
  instruction : Int,
) -> ArrayView[ValueId] {
  self.blocks[block].instructions[instruction].definitions[:]
}

///|
fn UseDefAnalysis::instruction_uses(
  self : UseDefAnalysis,
  block : Int,
  instruction : Int,
) -> ArrayView[ValueId] {
  self.blocks[block].instructions[instruction].uses[:]
}

///|
fn UseDefAnalysis::terminator_uses(
  self : UseDefAnalysis,
  block : Int,
) -> ArrayView[ValueId] {
  self.blocks[block].terminator_uses[:]
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
