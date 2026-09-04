///|
// Compose actual adapter implementations, not identities between endpoint
// contracts. Visit original adapter calls once and copy original bodies, so
// recursive wrapper relationships cannot cause repeated or recursive unfolding.
// Returned closures and their captures remain actual constructed values.
fn compose_callable_adapters(
  image : Image,
  adapters : Array[@physical.FunctionId],
) -> Image raise FinalizeError {
  if adapters.is_empty() {
    return image
  }
  let flow = analyze_callable_flow(image)
  {
    ..image,
    functions: image.functions.mapi((index, entry) => {
      let caller : @physical.FunctionId = { value: index + 1, }
      guard adapters.contains(caller) &&
        entry is Body(body) &&
        flow.body_facts(index) is Some(facts) else {
        return entry
      }
      let mut values = body.values
      let mut changed = false
      let blocks = body.blocks.map(block => {
        let instructions = []
        for instruction in block.instructions {
          let call = match instruction {
            CallDirect(target, environment, witnesses, arguments, destination) =>
              Some(
                (
                  Some(target),
                  environment,
                  None,
                  witnesses,
                  arguments,
                  destination,
                ),
              )
            CallPackedDirect(
              target,
              callable,
              witnesses,
              arguments,
              destination
            ) =>
              Some(
                (
                  Some(target),
                  None,
                  Some(callable),
                  witnesses,
                  arguments,
                  destination,
                ),
              )
            CallValue(callable, witnesses, arguments, destination) =>
              Some(
                (None, None, Some(callable), witnesses, arguments, destination),
              )
            _ => None
          }
          if call
            is Some(
              (target, environment, callable, witnesses, arguments, destination)
            ) &&
            compose_adapter_invocation(
              image,
              adapters,
              caller,
              facts.values,
              values,
              target,
              environment,
              callable,
              witnesses,
              arguments,
              destination,
            )
            is Some((updated, inlined, _)) {
            values = updated
            changed = true
            instructions.append(inlined)
          } else {
            instructions.push(instruction)
          }
        }
        let call = match block.terminator {
          TailCallDirect(target, environment, witnesses, arguments) =>
            Some((Some(target), environment, None, witnesses, arguments))
          TailCallPackedDirect(target, callable, witnesses, arguments) =>
            Some((Some(target), None, Some(callable), witnesses, arguments))
          TailCallValue(callable, witnesses, arguments) =>
            Some((None, None, Some(callable), witnesses, arguments))
          _ => None
        }
        let terminator = if call
          is Some((target, environment, callable, witnesses, arguments)) &&
          compose_adapter_invocation(
            image,
            adapters,
            caller,
            facts.values,
            values,
            target,
            environment,
            callable,
            witnesses,
            arguments,
            None,
          )
          is Some((updated, inlined, returned)) {
          values = updated
          changed = true
          instructions.append(inlined)
          Return(returned)
        } else {
          block.terminator
        }
        { ..block, instructions, terminator, }
      })
      if changed {
        Body(simplify_body({ ..body, values, blocks, }))
      } else {
        entry
      }
    }),
  }
}

///|
fn compose_adapter_invocation(
  image : Image,
  adapters : Array[@physical.FunctionId],
  caller : @physical.FunctionId,
  facts : Array[CallableFlowFact],
  values : Array[ValueMetadata],
  target : @physical.FunctionId?,
  environment : ValueId?,
  callable : ValueId?,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  destination : ValueId?,
) -> (Array[ValueMetadata], Array[Instruction], ValueId?)? {
  let alternative = match callable {
    Some(callable) =>
      match facts[callable.value] {
        KnownCallables([alternative], _) => Some(alternative)
        _ => return None
      }
    None => None
  }
  let selected = match (target, alternative) {
    (Some(target), Some(alternative)) if target != alternative.target =>
      return None
    (Some(target), _) => target
    (None, Some(alternative)) => alternative.target
    _ => return None
  }
  guard selected != caller &&
    adapters.contains(selected) &&
    image.functions[selected.value - 1] is Body(callee) &&
    inlineable_direct_body(callee) else {
    return None
  }
  let prefix = []
  let values = values.copy()
  let environment = if alternative is Some(alternative) &&
    callable is Some(callable) {
    match alternative.environment {
      CaptureFree => None
      LocalEnvironment(reference) => Some(reference.value)
      CapturedEnvironments(_) | PackedEnvironment => {
        guard callee.inputs.environment is Some(input) else { return None }
        let projected : ValueId = { value: values.length(), }
        values.push({ ..callee.values[input.value], ownership: Borrowed, })
        prefix.push(BorrowClosureEnvironment(projected, selected, callable))
        Some(projected)
      }
    }
  } else {
    environment
  }
  guard inline_call_body(
      callee, values, environment, witnesses, arguments, destination,
    )
    is Some((values, instructions, returned)) else {
    return None
  }
  prefix.append(instructions)
  Some((values, prefix, returned))
}
