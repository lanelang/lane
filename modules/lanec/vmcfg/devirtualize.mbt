///|
priv struct DirectEnvironmentCandidate {
  target : @bytecode.FunctionId
  shape : @bytecode.ObjectShapeId
}

///|
priv struct DirectEnvironmentPlan {
  target : @bytecode.FunctionId
  shape : @bytecode.ObjectShapeId
  function : @bytecode.FunctionId
  witness_ordinals : Array[Int]
  member_indices : Array[Int]
  body : FunctionBody
}

///|
fn devirtualize_image(image : Image) -> Image {
  let candidates = collect_direct_environment_candidates(image.functions)
  let reference_counts = function_reference_counts(image)
  let plans : Array[DirectEnvironmentPlan] = []
  for candidate in candidates {
    guard reference_counts[candidate.target.value - 1] == 1 else { continue }
    if build_direct_environment_plan(image, candidate, candidate.target)
      is Some(plan) {
      plans.push(plan)
    }
  }
  let functions = image.functions.mapi(fn(index, entry) {
    match entry {
      Body(body) => {
        let function : @bytecode.FunctionId = { value: index + 1 }
        let selected = match
          replacement_direct_environment_body(plans, function) {
          Some(replacement) => replacement
          None => body
        }
        Body(devirtualize_body_with_plans(selected, plans))
      }
      RuntimeImport(_) => entry
    }
  })
  { ..image, functions, }
}

///|
fn function_reference_counts(image : Image) -> Array[Int] {
  let counts = Array::make(image.functions.length(), 0)
  record_function_reference(counts, image.entry)
  if image.initializer is Some(initializer) {
    record_function_reference(counts, initializer)
  }
  for entry in image.functions {
    guard entry is Body(body) else { continue }
    for block in body.blocks {
      for instruction in block.instructions {
        match instruction {
          ConstFunction(_, function)
          | CallDirect(function, _, _, _, _)
          | MakeClosure(_, function, _) =>
            record_function_reference(counts, function)
          _ => ()
        }
      }
      if block.terminator is TailCallDirect(function, _, _, _) {
        record_function_reference(counts, function)
      }
    }
  }
  counts
}

///|
fn record_function_reference(
  counts : Array[Int],
  function : @bytecode.FunctionId,
) -> Unit {
  let index = function.value - 1
  if index >= 0 && index < counts.length() {
    counts[index] += 1
  }
}

///|
fn replacement_direct_environment_body(
  plans : Array[DirectEnvironmentPlan],
  function : @bytecode.FunctionId,
) -> FunctionBody? {
  for plan in plans {
    if plan.target == function && plan.function == function {
      return Some(plan.body)
    }
  }
  None
}

///|
fn collect_direct_environment_candidates(
  functions : Array[FunctionEntry],
) -> Array[DirectEnvironmentCandidate] {
  let candidates = []
  for entry in functions {
    guard entry is Body(body) else { continue }
    let uses = body_value_use_counts(body)
    for block in body.blocks {
      let mut index = 0
      while index + 2 < block.instructions.length() {
        match
          (
            block.instructions[index],
            block.instructions[index + 1],
            block.instructions[index + 2],
          ) {
          (
            MakeEnv(environment, shape, _, _, _),
            MakeClosure(callable, target, closure_environment),
            CallValue(invoked, _, _, _),
          ) if environment == closure_environment &&
            callable == invoked &&
            uses[environment.value] == 1 &&
            uses[callable.value] == 1 =>
            push_direct_environment_candidate(candidates, target, shape)
          _ => ()
        }
        index += 1
      }
      guard block.instructions.length() >= 2 &&
        block.terminator is TailCallValue(invoked, _, _) else {
        continue
      }
      let environment_instruction = block.instructions[block.instructions.length() -
        2]
      let closure_instruction = block.instructions[block.instructions.length() -
        1]
      match (environment_instruction, closure_instruction) {
        (
          MakeEnv(environment, shape, _, _, _),
          MakeClosure(callable, target, closure_environment),
        ) if environment == closure_environment &&
          callable == invoked &&
          uses[environment.value] == 1 &&
          uses[callable.value] == 1 =>
          push_direct_environment_candidate(candidates, target, shape)
        _ => ()
      }
    }
  }
  candidates
}

///|
fn push_direct_environment_candidate(
  candidates : Array[DirectEnvironmentCandidate],
  target : @bytecode.FunctionId,
  shape : @bytecode.ObjectShapeId,
) -> Unit {
  if !candidates.any(fn(candidate) {
      candidate.target == target && candidate.shape == shape
    }) {
    candidates.push({ target, shape })
  }
}

///|
fn build_direct_environment_plan(
  image : Image,
  candidate : DirectEnvironmentCandidate,
  function : @bytecode.FunctionId,
) -> DirectEnvironmentPlan? {
  let function_index = candidate.target.value - 1
  guard function_index >= 0 &&
    function_index < image.functions.length() &&
    image.functions[function_index] is Body(original) &&
    original.inputs.environment is Some(environment) &&
    image.object_shapes[candidate.shape.value] is Environment(shape) else {
    return None
  }
  guard direct_environment_body_is_leaf(original) else { return None }
  let values = original.values.copy()
  let extra_witnesses = []
  let witness_ordinals = []
  let extra_arguments = []
  let member_indices = []
  let blocks = []
  for block in original.blocks {
    let instructions = []
    for instruction in block.instructions {
      if !instruction_uses(instruction).contains(environment) {
        instructions.push(instruction)
        continue
      }
      match instruction {
        LoadObjectWitness(destination, selected_shape, source, ordinal) if source ==
          environment &&
          selected_shape == candidate.shape &&
          ordinal >= 0 &&
          ordinal < shape.stored_witness_count => {
          extra_witnesses.push(destination)
          witness_ordinals.push(ordinal)
        }
        BorrowCapture(selected_shape, source, member_index, result) if source ==
          environment &&
          selected_shape == candidate.shape &&
          member_index >= 0 &&
          member_index < shape.members.length() => {
          let destination = result.value_destination
          values[destination.value] = {
            ..values[destination.value],
            ownership: match values[destination.value].ownership {
              Trivial => Trivial
              Owned | Borrowed => Owned
            },
          }
          extra_arguments.push(destination)
          member_indices.push(member_index)
          if result.witness_destination is Some(witness) {
            guard shape.members[member_index].witness_ordinal is Some(ordinal) else {
              return None
            }
            extra_witnesses.push(witness)
            witness_ordinals.push(ordinal)
          }
        }
        _ => return None
      }
    }
    if terminator_uses(block.terminator).contains(environment) {
      return None
    }
    blocks.push({ ..block, instructions, })
  }
  Some({
    target: candidate.target,
    shape: candidate.shape,
    function,
    witness_ordinals,
    member_indices,
    body: {
      values,
      inputs: {
        environment: None,
        witnesses: original.inputs.witnesses + extra_witnesses,
        user_parameters: original.inputs.user_parameters + extra_arguments,
      },
      result: original.result,
      blocks,
    },
  })
}

///|
fn direct_environment_body_is_leaf(body : FunctionBody) -> Bool {
  for block in body.blocks {
    for instruction in block.instructions {
      match instruction {
        CallDirect(_, _, _, _, _)
        | CallValue(_, _, _, _)
        | MakeEnv(_, _, _, _, _)
        | MakeClosure(_, _, _) => return false
        _ => ()
      }
    }
    match block.terminator {
      TailCallDirect(_, _, _, _) | TailCallValue(_, _, _) => return false
      _ => ()
    }
  }
  true
}

///|
fn devirtualize_body_with_plans(
  body : FunctionBody,
  plans : Array[DirectEnvironmentPlan],
) -> FunctionBody {
  let uses = body_value_use_counts(body)
  {
    ..body,
    blocks: body.blocks.map(fn(block) { devirtualize_block(block, uses, plans) }),
  }
}

///|
fn body_value_use_counts(body : FunctionBody) -> Array[Int] {
  let counts = Array::make(body.values.length(), 0)
  for block in body.blocks {
    for instruction in block.instructions {
      for value in instruction_uses(instruction) {
        counts[value.value] += 1
      }
    }
    for value in terminator_uses(block.terminator) {
      counts[value.value] += 1
    }
  }
  counts
}

///|
fn devirtualize_block(
  block : Block,
  uses : Array[Int],
  plans : Array[DirectEnvironmentPlan],
) -> Block {
  let instructions = []
  let mut index = 0
  while index < block.instructions.length() {
    if index + 2 < block.instructions.length() {
      match
        (
          block.instructions[index],
          block.instructions[index + 1],
          block.instructions[index + 2],
        ) {
        (
          MakeEnv(environment, shape, _, environment_witnesses, captures),
          MakeClosure(callable, target, closure_environment),
          CallValue(invoked, call_witnesses, arguments, destination),
        ) if environment == closure_environment &&
          callable == invoked &&
          uses[environment.value] == 1 &&
          uses[callable.value] == 1 =>
          match find_direct_environment_plan(plans, target, shape) {
            Some(plan) => {
              instructions.push(
                direct_environment_call(
                  plan, environment_witnesses, captures, call_witnesses, arguments,
                  destination,
                ),
              )
              index += 3
              continue
            }
            None => ()
          }
        _ => ()
      }
    }
    if index + 1 < block.instructions.length() {
      let producer = block.instructions[index]
      let invocation = block.instructions[index + 1]
      match (producer, invocation) {
        (
          ConstFunction(callable, target),
          CallValue(invoked, witnesses, arguments, destination),
        ) if callable == invoked && uses[callable.value] == 1 => {
          instructions.push(
            CallDirect(target, None, witnesses, arguments, destination),
          )
          index += 2
          continue
        }
        (
          MakeClosure(callable, target, environment),
          CallValue(invoked, witnesses, arguments, destination),
        ) if callable == invoked && uses[callable.value] == 1 => {
          instructions.push(
            CallDirect(
              target,
              Some(environment),
              witnesses,
              arguments,
              destination,
            ),
          )
          index += 2
          continue
        }
        _ => ()
      }
    }
    instructions.push(block.instructions[index])
    index += 1
  }
  let terminator = match block.terminator {
    TailCallValue(callable, witnesses, arguments) if uses[callable.value] == 1 =>
      direct_tail_terminator(
        block.terminator,
        callable,
        witnesses,
        arguments,
        instructions,
        uses,
        plans,
      )
    _ => block.terminator
  }
  { ..block, instructions, terminator }
}

///|
fn direct_tail_terminator(
  original : Terminator,
  callable : ValueId,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  instructions : Array[Instruction],
  uses : Array[Int],
  plans : Array[DirectEnvironmentPlan],
) -> Terminator {
  if instructions.length() >= 2 &&
    instructions[instructions.length() - 2]
    is MakeEnv(environment, shape, _, environment_witnesses, captures) &&
    instructions[instructions.length() - 1]
    is MakeClosure(produced, target, closure_environment) &&
    produced == callable &&
    closure_environment == environment &&
    uses[environment.value] == 1 &&
    find_direct_environment_plan(plans, target, shape) is Some(plan) {
    ignore(instructions.pop())
    ignore(instructions.pop())
    return direct_environment_tail_call(
      plan, environment_witnesses, captures, witnesses, arguments,
    )
  }
  match instructions.last() {
    Some(ConstFunction(produced, target)) if produced == callable => {
      ignore(instructions.pop())
      TailCallDirect(target, None, witnesses, arguments)
    }
    Some(MakeClosure(produced, target, environment)) if produced == callable => {
      ignore(instructions.pop())
      TailCallDirect(target, Some(environment), witnesses, arguments)
    }
    _ => original
  }
}

///|
fn find_direct_environment_plan(
  plans : Array[DirectEnvironmentPlan],
  target : @bytecode.FunctionId,
  shape : @bytecode.ObjectShapeId,
) -> DirectEnvironmentPlan? {
  for plan in plans {
    if plan.target == target && plan.shape == shape {
      return Some(plan)
    }
  }
  None
}

///|
fn direct_environment_call(
  plan : DirectEnvironmentPlan,
  environment_witnesses : Array[ValueId],
  captures : Array[ValueId],
  call_witnesses : Array[ValueId],
  arguments : Array[ValueId],
  destination : ValueId?,
) -> Instruction {
  CallDirect(
    plan.function,
    None,
    call_witnesses + select_values(environment_witnesses, plan.witness_ordinals),
    arguments + select_values(captures, plan.member_indices),
    destination,
  )
}

///|
fn direct_environment_tail_call(
  plan : DirectEnvironmentPlan,
  environment_witnesses : Array[ValueId],
  captures : Array[ValueId],
  call_witnesses : Array[ValueId],
  arguments : Array[ValueId],
) -> Terminator {
  TailCallDirect(
    plan.function,
    None,
    call_witnesses + select_values(environment_witnesses, plan.witness_ordinals),
    arguments + select_values(captures, plan.member_indices),
  )
}

///|
fn select_values(
  values : Array[ValueId],
  indices : Array[Int],
) -> Array[ValueId] {
  indices.map(fn(index) { values[index] })
}
