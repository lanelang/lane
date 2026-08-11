///|
priv struct DirectEnvironmentPlan {
  target : @bytecode.FunctionId
  shape : @bytecode.ObjectShapeId
  witness_ordinals : Array[Int]
  member_indices : Array[Int]
  body : FunctionBody
}

///|
priv struct EnvironmentPlanCandidate {
  mut shape : @bytecode.ObjectShapeId?
  mut invalid : Bool
}

///|
fn devirtualize_image(image : Image) -> Image {
  let flow = analyze_callable_flow(image)
  apply_devirtualization(
    image,
    flow,
    build_direct_environment_plans(image, flow),
  )
}

///|
fn apply_devirtualization(
  image : Image,
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> Image {
  let functions = image.functions.mapi(fn(index, entry) {
    match entry {
      Body(body) => {
        let selected = match
          direct_environment_plan(plans, { value: index + 1 }) {
          Some(plan) => plan.body
          None => body
        }
        guard flow.body_facts(index) is Some(facts) else {
          return Body(selected)
        }
        Body(
          remove_dead_callable_construction(
            devirtualize_body(selected, facts.values, plans),
          ),
        )
      }
      RuntimeImport(_) => entry
    }
  })
  { ..image, functions, }
}

///|
fn build_direct_environment_plans(
  image : Image,
  flow : CallableFlowAnalysis,
) -> Array[DirectEnvironmentPlan] {
  let candidates : Array[EnvironmentPlanCandidate] = image.functions.map(_ => {
    shape: None,
    invalid: false,
  })
  reject_root_environment_plan(image, candidates, image.entry)
  if image.initializer is Some(initializer) {
    reject_root_environment_plan(image, candidates, initializer)
  }
  for function_index, entry in image.functions {
    guard entry is Body(body) && flow.body_facts(function_index) is Some(facts) else {
      continue
    }
    for block in body.blocks {
      for instruction in block.instructions {
        collect_environment_instruction_candidate(
          image,
          candidates,
          facts.values,
          instruction,
        )
      }
      collect_environment_terminator_candidate(
        image,
        candidates,
        facts.values,
        block.terminator,
      )
    }
  }
  let plans = []
  for index, candidate in candidates {
    guard !candidate.invalid && candidate.shape is Some(shape) else { continue }
    let target : @bytecode.FunctionId = { value: index + 1 }
    if build_direct_environment_plan(image, target, shape) is Some(plan) {
      plans.push(plan)
    }
  }
  plans
}

///|
fn reject_root_environment_plan(
  image : Image,
  candidates : Array[EnvironmentPlanCandidate],
  target : @bytecode.FunctionId,
) -> Unit {
  let index = target.value - 1
  if index >= 0 &&
    index < image.functions.length() &&
    image.functions[index] is Body({ inputs: { environment: Some(_), .. }, .. }) {
    candidates[index].invalid = true
  }
}

///|
fn collect_environment_instruction_candidate(
  image : Image,
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  instruction : Instruction,
) -> Unit {
  match instruction {
    ConstFunction(_, target) =>
      reject_capture_free_reference(image, candidates, target)
    MakeClosure(_, target, environment) =>
      record_environment_candidate(candidates, target, facts[environment.value])
    MakeData(_, _, _, witnesses, fields)
    | MakeEnv(_, _, _, witnesses, fields) =>
      invalidate_callable_values(candidates, facts, witnesses + fields)
    CallDirect(target, environment, witnesses, arguments, _) => {
      match environment {
        Some(environment) =>
          record_environment_candidate(
            candidates,
            target,
            facts[environment.value],
          )
        None => reject_capture_free_reference(image, candidates, target)
      }
      invalidate_callable_values(candidates, facts, witnesses + arguments)
    }
    CallValue(callable, witnesses, arguments, _) => {
      record_callable_candidate(candidates, facts, facts[callable.value])
      invalidate_callable_values(candidates, facts, witnesses + arguments)
    }
    Copy(_, _)
    | Move(_, _)
    | RetainCopy(_, _)
    | BorrowField(_, _, _, _)
    | ConsumeFields(_, _, _)
    | BorrowCapture(_, _, _, _)
    | ConsumeCaptures(_, _, _) => ()
    _ =>
      invalidate_callable_values(
        candidates,
        facts,
        instruction_operand_values(instruction),
      )
  }
}

///|
fn collect_environment_terminator_candidate(
  image : Image,
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  terminator : Terminator,
) -> Unit {
  match terminator {
    TailCallDirect(target, environment, witnesses, arguments) => {
      match environment {
        Some(environment) =>
          record_environment_candidate(
            candidates,
            target,
            facts[environment.value],
          )
        None => reject_capture_free_reference(image, candidates, target)
      }
      invalidate_callable_values(candidates, facts, witnesses + arguments)
    }
    TailCallValue(callable, witnesses, arguments) => {
      record_callable_candidate(candidates, facts, facts[callable.value])
      invalidate_callable_values(candidates, facts, witnesses + arguments)
    }
    Jump(_) | BranchBool(_, _, _) | SwitchTag(_, _, _) | Unreachable => ()
    Return(Some(value)) | Fatal(value) =>
      invalidate_callable_fact(candidates, facts[value.value])
    Return(None) => ()
  }
}

///|
fn invalidate_callable_values(
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  values : Array[ValueId],
) -> Unit {
  for value in values {
    invalidate_callable_fact(candidates, facts[value.value])
  }
}

///|
fn invalidate_callable_fact(
  candidates : Array[EnvironmentPlanCandidate],
  fact : CallableFlowFact,
) -> Unit {
  for alternative in callable_alternatives(fact) {
    invalidate_environment_candidate(candidates, alternative.target)
  }
}

///|
fn record_callable_candidate(
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  fact : CallableFlowFact,
) -> Unit {
  match fact {
    KnownCallables([{ target, environment: LocalEnvironment(environment) }]) =>
      record_environment_candidate(candidates, target, facts[environment.value])
    KnownCallables([{ target, environment: CaptureFree | PackedEnvironment }]) =>
      invalidate_environment_candidate(candidates, target)
    KnownCallables(alternatives) | Unknown(alternatives) =>
      for alternative in alternatives {
        invalidate_environment_candidate(candidates, alternative.target)
      }
    Unreached | KnownAggregate(_, _, _, _, _) => ()
  }
}

///|
fn record_environment_candidate(
  candidates : Array[EnvironmentPlanCandidate],
  target : @bytecode.FunctionId,
  environment : CallableFlowFact,
) -> Unit {
  let index = target.value - 1
  guard index >= 0 && index < candidates.length() else { return }
  guard environment is KnownAggregate(shape, _, _, Some(_), Some(_)) &&
    shape.value >= 0 else {
    candidates[index].invalid = true
    return
  }
  match candidates[index].shape {
    None => candidates[index].shape = Some(shape)
    Some(existing) if existing == shape => ()
    Some(_) => candidates[index].invalid = true
  }
}

///|
fn reject_capture_free_reference(
  image : Image,
  candidates : Array[EnvironmentPlanCandidate],
  target : @bytecode.FunctionId,
) -> Unit {
  let index = target.value - 1
  if index >= 0 &&
    index < image.functions.length() &&
    image.functions[index] is Body({ inputs: { environment: Some(_), .. }, .. }) {
    candidates[index].invalid = true
  }
}

///|
fn invalidate_environment_candidate(
  candidates : Array[EnvironmentPlanCandidate],
  target : @bytecode.FunctionId,
) -> Unit {
  let index = target.value - 1
  if index >= 0 && index < candidates.length() {
    candidates[index].invalid = true
  }
}

///|
fn build_direct_environment_plan(
  image : Image,
  target : @bytecode.FunctionId,
  shape_id : @bytecode.ObjectShapeId,
) -> DirectEnvironmentPlan? {
  let function_index = target.value - 1
  guard function_index >= 0 &&
    function_index < image.functions.length() &&
    image.functions[function_index] is Body(original) &&
    original.inputs.environment is Some(environment) &&
    shape_id.value >= 0 &&
    shape_id.value < image.object_shapes.length() &&
    image.object_shapes[shape_id.value] is Environment(shape) else {
    return None
  }
  let use_def = analyze_use_def(original)
  let values = original.values.copy()
  let extra_witnesses = []
  let witness_ordinals = []
  let extra_arguments = []
  let member_indices = []
  let blocks = []
  for block_index, block in original.blocks {
    let instructions = []
    for instruction_index, instruction in block.instructions {
      if !use_def
        .instruction_uses(block_index, instruction_index)
        .contains(environment) {
        instructions.push(instruction)
        continue
      }
      match instruction {
        LoadObjectWitness(destination, selected_shape, source, ordinal) if source ==
          environment &&
          selected_shape == shape_id &&
          ordinal >= 0 &&
          ordinal < shape.stored_witness_count => {
          extra_witnesses.push(destination)
          witness_ordinals.push(ordinal)
        }
        BorrowCapture(selected_shape, source, member_index, result) if source ==
          environment &&
          selected_shape == shape_id &&
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
        ConsumeCaptures(selected_shape, source, selections) if source ==
          environment &&
          selected_shape == shape_id =>
          for selection in selections {
            let member_index = selection.member_index
            guard member_index >= 0 && member_index < shape.members.length() else {
              return None
            }
            extra_arguments.push(selection.result.value_destination)
            member_indices.push(member_index)
            if selection.result.witness_destination is Some(witness) {
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
    if use_def.terminator_uses(block_index).contains(environment) {
      return None
    }
    blocks.push({ ..block, instructions, })
  }
  Some({
    target,
    shape: shape_id,
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
fn devirtualize_body(
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  plans : Array[DirectEnvironmentPlan],
) -> FunctionBody {
  {
    ..body,
    blocks: body.blocks.map(block => {
      ..block,
      instructions: block.instructions.map(instruction => {
        devirtualize_instruction(instruction, facts, plans)
      }),
      terminator: devirtualize_terminator(block.terminator, facts, plans),
    }),
  }
}

///|
fn devirtualize_instruction(
  instruction : Instruction,
  facts : Array[CallableFlowFact],
  plans : Array[DirectEnvironmentPlan],
) -> Instruction {
  match instruction {
    CallValue(callable, witnesses, arguments, destination) =>
      match facts[callable.value] {
        KnownCallables([{ target, environment: CaptureFree }]) =>
          CallDirect(target, None, witnesses, arguments, destination)
        KnownCallables([{ target, environment: LocalEnvironment(environment) }]) =>
          materialize_direct_call(
            target, environment, witnesses, arguments, destination, facts, plans,
          )
        _ => instruction
      }
    CallDirect(target, Some(environment), witnesses, arguments, destination) =>
      materialize_direct_call(
        target, environment, witnesses, arguments, destination, facts, plans,
      )
    _ => instruction
  }
}

///|
fn materialize_direct_call(
  target : @bytecode.FunctionId,
  environment : ValueId,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  destination : ValueId?,
  facts : Array[CallableFlowFact],
  plans : Array[DirectEnvironmentPlan],
) -> Instruction {
  guard direct_environment_plan(plans, target) is Some(plan) &&
    local_aggregate_values(facts[environment.value], plan.shape)
    is Some(environment_values) else {
    return CallDirect(
      target,
      Some(environment),
      witnesses,
      arguments,
      destination,
    )
  }
  CallDirect(
    target,
    None,
    witnesses + select_values(environment_values.0, plan.witness_ordinals),
    arguments + select_values(environment_values.1, plan.member_indices),
    destination,
  )
}

///|
fn devirtualize_terminator(
  terminator : Terminator,
  facts : Array[CallableFlowFact],
  plans : Array[DirectEnvironmentPlan],
) -> Terminator {
  match terminator {
    TailCallValue(callable, witnesses, arguments) =>
      match facts[callable.value] {
        KnownCallables([{ target, environment: CaptureFree }]) =>
          TailCallDirect(target, None, witnesses, arguments)
        KnownCallables([{ target, environment: LocalEnvironment(environment) }]) =>
          materialize_direct_tail_call(
            target, environment, witnesses, arguments, facts, plans,
          )
        _ => terminator
      }
    TailCallDirect(target, Some(environment), witnesses, arguments) =>
      materialize_direct_tail_call(
        target, environment, witnesses, arguments, facts, plans,
      )
    _ => terminator
  }
}

///|
fn materialize_direct_tail_call(
  target : @bytecode.FunctionId,
  environment : ValueId,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  facts : Array[CallableFlowFact],
  plans : Array[DirectEnvironmentPlan],
) -> Terminator {
  guard direct_environment_plan(plans, target) is Some(plan) &&
    local_aggregate_values(facts[environment.value], plan.shape)
    is Some(environment_values) else {
    return TailCallDirect(target, Some(environment), witnesses, arguments)
  }
  TailCallDirect(
    target,
    None,
    witnesses + select_values(environment_values.0, plan.witness_ordinals),
    arguments + select_values(environment_values.1, plan.member_indices),
  )
}

///|
fn local_aggregate_values(
  fact : CallableFlowFact,
  shape : @bytecode.ObjectShapeId,
) -> (Array[ValueId], Array[ValueId])? {
  match fact {
    KnownAggregate(selected, _, _, Some(witnesses), Some(members)) if selected ==
      shape => Some((witnesses, members))
    _ => None
  }
}

///|
fn direct_environment_plan(
  plans : Array[DirectEnvironmentPlan],
  target : @bytecode.FunctionId,
) -> DirectEnvironmentPlan? {
  for plan in plans {
    if plan.target == target {
      return Some(plan)
    }
  }
  None
}

///|
fn select_values(
  values : Array[ValueId],
  indices : Array[Int],
) -> Array[ValueId] {
  indices.map(index => values[index])
}

///|
fn remove_dead_callable_construction(body : FunctionBody) -> FunctionBody {
  let mut body = body
  let mut changed = true
  while changed {
    changed = false
    let use_def = analyze_use_def(body)
    let blocks = body.blocks.map(block => {
      let instructions = []
      for instruction in block.instructions {
        if dead_callable_construction(instruction, body, use_def) {
          changed = true
        } else {
          instructions.push(instruction)
        }
      }
      { ..block, instructions, }
    })
    body = { ..body, blocks, }
  }
  body
}

///|
fn dead_callable_construction(
  instruction : Instruction,
  body : FunctionBody,
  use_def : UseDefAnalysis,
) -> Bool {
  match instruction {
    ConstFunction(destination, _)
    | MakeClosure(destination, _, _)
    | MakeEnv(destination, _, _, _, _) => use_def.use_count(destination) == 0
    Copy(destination, _) | Move(destination, _) | RetainCopy(destination, _) =>
      body.values[destination.value].kind is CallableValue &&
      use_def.use_count(destination) == 0
    _ => false
  }
}
