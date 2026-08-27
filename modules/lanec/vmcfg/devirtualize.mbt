///|
priv struct DirectEnvironmentPlan {
  target : @physical.FunctionId
  shape : @physical.ObjectShapeId
  witness_ordinals : Array[Int]
  member_indices : Array[Int]
  body : FunctionBody
}

///|
priv struct EnvironmentPlanCandidate {
  mut shape : @physical.ObjectShapeId?
  mut invalid : Bool
}

///|
priv struct DevirtualizedImage {
  image : Image
  direct_environment_targets : Array[@physical.FunctionId]
}

///|
#warnings("-unused_value")
fn devirtualize_image(image : Image) -> Image raise FinalizeError {
  devirtualize_image_with_direct_environments(image).image
}

///|
fn devirtualize_image_with_direct_environments(
  image : Image,
) -> DevirtualizedImage raise FinalizeError {
  let flow = analyze_callable_flow(image)
  let plans = build_direct_environment_plans(image, flow)
  {
    image: apply_devirtualization(image, flow, plans),
    direct_environment_targets: plans.map(plan => plan.target),
  }
}

///|
fn apply_devirtualization(
  image : Image,
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> Image raise FinalizeError {
  let functions = image.functions.mapi((index, entry) => {
    match entry {
      Body(body) => {
        let selected = match
          direct_environment_plan(plans, { value: index + 1, }) {
          Some(plan) => plan.body
          None => body
        }
        guard flow.body_facts(index) is Some(facts) else {
          return Body(selected)
        }
        Body(
          remove_dead_callable_construction(
            devirtualize_body(image, selected, facts.values, flow, plans),
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
) -> Array[DirectEnvironmentPlan] raise FinalizeError {
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
          flow,
          body,
          instruction,
        )
      }
      collect_environment_terminator_candidate(
        image,
        candidates,
        facts.values,
        flow,
        body,
        block.terminator,
      )
    }
  }
  let plans = []
  for index, candidate in candidates {
    guard !candidate.invalid && candidate.shape is Some(shape) else { continue }
    let target : @physical.FunctionId = { value: index + 1, }
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
  target : @physical.FunctionId,
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
  flow : CallableFlowAnalysis,
  body : FunctionBody,
  instruction : Instruction,
) -> Unit {
  match instruction {
    ConstFunction(_, target) =>
      reject_capture_free_reference(image, candidates, target)
    MakeClosure(_, target, environment) =>
      record_environment_candidate(
        candidates,
        flow,
        target,
        facts[environment.value],
      )
    MakeData(_, _, _, witnesses, fields)
    | MakeEnv(_, _, _, witnesses, fields) =>
      invalidate_callable_values(candidates, facts, flow, witnesses + fields)
    CallDirect(target, environment, witnesses, arguments, _) => {
      match environment {
        Some(environment) =>
          record_environment_candidate(
            candidates,
            flow,
            target,
            facts[environment.value],
          )
        None => reject_capture_free_reference(image, candidates, target)
      }
      invalidate_callable_values(candidates, facts, flow, witnesses + arguments)
    }
    CallValue(callable, witnesses, arguments, destination) => {
      let callable_fact = complete_callable_at_callsite(
        image,
        flow,
        body,
        facts[callable.value],
        witnesses,
        arguments,
        match destination {
          Some(destination) => value_result_abi(body.values[destination.value])
          None => Unit
        },
      )
      record_callable_candidate(candidates, facts, flow, callable_fact)
      invalidate_callable_values(candidates, facts, flow, witnesses + arguments)
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
        flow,
        instruction_operand_values(instruction),
      )
  }
}

///|
fn collect_environment_terminator_candidate(
  image : Image,
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  body : FunctionBody,
  terminator : Terminator,
) -> Unit {
  match terminator {
    TailCallDirect(target, environment, witnesses, arguments) => {
      match environment {
        Some(environment) =>
          record_environment_candidate(
            candidates,
            flow,
            target,
            facts[environment.value],
          )
        None => reject_capture_free_reference(image, candidates, target)
      }
      invalidate_callable_values(candidates, facts, flow, witnesses + arguments)
    }
    TailCallValue(callable, witnesses, arguments) => {
      let callable_fact = complete_callable_at_callsite(
        image,
        flow,
        body,
        facts[callable.value],
        witnesses,
        arguments,
        body.result,
      )
      record_callable_candidate(candidates, facts, flow, callable_fact)
      invalidate_callable_values(candidates, facts, flow, witnesses + arguments)
    }
    Jump(_) | BranchBool(_, _, _) | SwitchTag(_, _, _) | Unreachable => ()
    Return(Some(value)) | Fatal(value) =>
      invalidate_callable_fact(candidates, flow, facts[value.value])
    Return(None) => ()
  }
}

///|
fn invalidate_callable_values(
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  values : Array[ValueId],
) -> Unit {
  for value in values {
    invalidate_callable_fact(candidates, flow, facts[value.value])
  }
}

///|
fn invalidate_callable_fact(
  candidates : Array[EnvironmentPlanCandidate],
  flow : CallableFlowAnalysis,
  fact : CallableFlowFact,
) -> Unit {
  for alternative in callable_alternatives(fact) {
    invalidate_environment_candidate(candidates, alternative.target)
  }
  invalidate_aggregate_callable_facts(candidates, flow, fact, [])
}

///|
fn invalidate_aggregate_callable_facts(
  candidates : Array[EnvironmentPlanCandidate],
  flow : CallableFlowAnalysis,
  fact : CallableFlowFact,
  visited : Array[AggregateSiteId],
) -> Unit {
  guard fact is KnownAggregates(aggregates, _) else { return }
  for aggregate in aggregates {
    guard !visited.contains(aggregate.site) &&
      flow.aggregate_site(aggregate.site) is Some(site) else {
      continue
    }
    visited.push(aggregate.site)
    for reference in site.witnesses + site.members {
      guard flow.body_facts(reference.function_index) is Some(body) else {
        continue
      }
      let nested = body.values[reference.value.value]
      for alternative in callable_alternatives(nested) {
        invalidate_environment_candidate(candidates, alternative.target)
      }
      invalidate_aggregate_callable_facts(candidates, flow, nested, visited)
    }
  }
}

///|
fn record_callable_candidate(
  candidates : Array[EnvironmentPlanCandidate],
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  fact : CallableFlowFact,
) -> Unit {
  match fact {
    KnownCallables([{ target, environment: LocalEnvironment(environment), }], _) =>
      record_environment_candidate(
        candidates,
        flow,
        target,
        facts[environment.value],
      )
    KnownCallables(
      [{ target, environment: CaptureFree | PackedEnvironment, }],
      _
    ) => invalidate_environment_candidate(candidates, target)
    KnownCallables(alternatives, _) | Unknown(alternatives, _) =>
      for alternative in alternatives {
        invalidate_environment_candidate(candidates, alternative.target)
      }
    Unreached | KnownAggregates(_, _) => ()
  }
}

///|
fn record_environment_candidate(
  candidates : Array[EnvironmentPlanCandidate],
  flow : CallableFlowAnalysis,
  target : @physical.FunctionId,
  environment : CallableFlowFact,
) -> Unit {
  let index = target.value - 1
  guard index >= 0 && index < candidates.length() else { return }
  guard local_aggregate_shape(flow, environment) is Some(shape) &&
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
  target : @physical.FunctionId,
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
  target : @physical.FunctionId,
) -> Unit {
  let index = target.value - 1
  if index >= 0 && index < candidates.length() {
    candidates[index].invalid = true
  }
}

///|
fn build_direct_environment_plan(
  image : Image,
  target : @physical.FunctionId,
  shape_id : @physical.ObjectShapeId,
) -> DirectEnvironmentPlan? raise FinalizeError {
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
  image : Image,
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> FunctionBody {
  {
    ..body,
    blocks: body.blocks.map(block => {
      ..block,
      instructions: block.instructions.map(instruction => {
        devirtualize_instruction(image, instruction, body, facts, flow, plans)
      }),
      terminator: devirtualize_terminator(
        block.terminator,
        image,
        body,
        facts,
        flow,
        plans,
      ),
    }),
  }
}

///|
fn devirtualize_instruction(
  image : Image,
  instruction : Instruction,
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> Instruction {
  match instruction {
    CallValue(callable, witnesses, arguments, destination) => {
      let callable_fact = complete_callable_at_callsite(
        image,
        flow,
        body,
        facts[callable.value],
        witnesses,
        arguments,
        match destination {
          Some(value) => value_result_abi(body.values[value.value])
          None => Unit
        },
      )
      match callable_fact {
        KnownCallables([{ target, environment: CaptureFree, }], _) =>
          CallDirect(target, None, witnesses, arguments, destination)
        KnownCallables(
          [{ target, environment: LocalEnvironment(environment), }],
          _
        ) =>
          materialize_direct_call(
            target, environment, witnesses, arguments, destination, facts, flow,
            plans,
          )
        _ => instruction
      }
    }
    CallDirect(target, Some(environment), witnesses, arguments, destination) =>
      materialize_direct_call(
        target, environment, witnesses, arguments, destination, facts, flow, plans,
      )
    _ => instruction
  }
}

///|
fn materialize_direct_call(
  target : @physical.FunctionId,
  environment : ValueId,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  destination : ValueId?,
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> Instruction {
  guard direct_environment_plan(plans, target) is Some(plan) &&
    local_aggregate_values(flow, facts[environment.value], plan.shape)
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
  image : Image,
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> Terminator {
  match terminator {
    TailCallValue(callable, witnesses, arguments) => {
      let callable_fact = complete_callable_at_callsite(
        image,
        flow,
        body,
        facts[callable.value],
        witnesses,
        arguments,
        body.result,
      )
      match callable_fact {
        KnownCallables([{ target, environment: CaptureFree, }], _) =>
          TailCallDirect(target, None, witnesses, arguments)
        KnownCallables(
          [{ target, environment: LocalEnvironment(environment), }],
          _
        ) =>
          materialize_direct_tail_call(
            target, environment, witnesses, arguments, facts, flow, plans,
          )
        _ => terminator
      }
    }
    TailCallDirect(target, Some(environment), witnesses, arguments) =>
      materialize_direct_tail_call(
        target, environment, witnesses, arguments, facts, flow, plans,
      )
    _ => terminator
  }
}

///|
fn materialize_direct_tail_call(
  target : @physical.FunctionId,
  environment : ValueId,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  facts : Array[CallableFlowFact],
  flow : CallableFlowAnalysis,
  plans : Array[DirectEnvironmentPlan],
) -> Terminator {
  guard direct_environment_plan(plans, target) is Some(plan) &&
    local_aggregate_values(flow, facts[environment.value], plan.shape)
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
  flow : CallableFlowAnalysis,
  fact : CallableFlowFact,
  shape : @physical.ObjectShapeId,
) -> (Array[ValueId], Array[ValueId])? {
  guard fact is KnownAggregates([{ site, locally_available: true, }], _) &&
    flow.aggregate_site(site) is Some(aggregate) &&
    aggregate.shape == shape else {
    return None
  }
  Some(
    (
      aggregate.witnesses.map(reference => reference.value),
      aggregate.members.map(reference => reference.value),
    ),
  )
}

///|
fn local_aggregate_shape(
  flow : CallableFlowAnalysis,
  fact : CallableFlowFact,
) -> @physical.ObjectShapeId? {
  guard fact is KnownAggregates([{ site, locally_available: true, }], _) &&
    flow.aggregate_site(site) is Some(aggregate) else {
    return None
  }
  Some(aggregate.shape)
}

///|
fn direct_environment_plan(
  plans : Array[DirectEnvironmentPlan],
  target : @physical.FunctionId,
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
fn remove_dead_callable_construction(
  body : FunctionBody,
) -> FunctionBody raise FinalizeError {
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
