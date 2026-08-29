///|
priv struct DirectCallSite {
  caller : Int
  block : Int
  instruction : Int?
}

///|
priv struct DirectFunctionUses {
  calls : Array[DirectCallSite]
  mut first_class : Bool
}

///|
/// Moves a direct function body into its sole call site. Eligibility is exact:
/// the function has no first-class reference, one direct call, one block and a
/// normal return. The rewrite therefore does not clone code and needs no size
/// or call-frequency heuristic.
fn inline_single_use_direct_functions(
  image : Image,
  eligible : Array[@physical.FunctionId],
) -> Image {
  let mut image = image
  for _ in 0..<image.functions.length() {
    guard find_single_use_inline_candidate(image, eligible)
      is Some((target, site)) else {
      break
    }
    guard inline_direct_call_site(image, target, site) is Some(functions) else {
      break
    }
    image = { ..image, functions, }
  }
  image
}

///|
fn find_single_use_inline_candidate(
  image : Image,
  eligible : Array[@physical.FunctionId],
) -> (@physical.FunctionId, DirectCallSite)? {
  let uses : Array[DirectFunctionUses] = image.functions.map(_ => {
    calls: [],
    first_class: false,
  })
  mark_root_function_use(uses, image.entry)
  if image.initializer is Some(initializer) {
    mark_root_function_use(uses, initializer)
  }
  for caller, entry in image.functions {
    guard entry is Body(body) else { continue }
    for block_index, block in body.blocks {
      for instruction_index, instruction in block.instructions {
        match instruction {
          ConstFunction(_, target) | MakeClosure(_, target, _) =>
            mark_first_class_function_use(uses, target)
          CallDirect(target, _, _, _, _) =>
            record_direct_function_use(uses, target, {
              caller,
              block: block_index,
              instruction: Some(instruction_index),
            })
          _ => ()
        }
      }
      if block.terminator is TailCallDirect(target, _, _, _) {
        record_direct_function_use(uses, target, {
          caller,
          block: block_index,
          instruction: None,
        })
      }
    }
  }
  for index, usage in uses {
    let target : @physical.FunctionId = { value: index + 1, }
    guard image.functions[index] is Body(body) &&
      (eligible.contains(target) || body.inputs.environment is Some(_)) else {
      continue
    }
    guard !usage.first_class && usage.calls is [site] && site.caller != index else {
      continue
    }
    guard inlineable_direct_body(body) else { continue }
    return Some((target, site))
  }
  None
}

///|
fn mark_root_function_use(
  uses : Array[DirectFunctionUses],
  function : @physical.FunctionId,
) -> Unit {
  mark_first_class_function_use(uses, function)
}

///|
fn mark_first_class_function_use(
  uses : Array[DirectFunctionUses],
  function : @physical.FunctionId,
) -> Unit {
  let index = function.value - 1
  if index >= 0 && index < uses.length() {
    uses[index].first_class = true
  }
}

///|
fn record_direct_function_use(
  uses : Array[DirectFunctionUses],
  function : @physical.FunctionId,
  site : DirectCallSite,
) -> Unit {
  let index = function.value - 1
  if index >= 0 && index < uses.length() {
    uses[index].calls.push(site)
  }
}

///|
fn inlineable_direct_body(body : FunctionBody) -> Bool {
  body.blocks is [{ parameters: [], terminator: Return(_), .. }]
}

///|
fn inline_direct_call_site(
  image : Image,
  target : @physical.FunctionId,
  site : DirectCallSite,
) -> Array[FunctionEntry]? {
  guard image.functions[target.value - 1] is Body(callee) &&
    callee.blocks is [callee_block] &&
    image.functions[site.caller] is Body(caller) else {
    return None
  }
  let call = match site.instruction {
    Some(instruction) =>
      match caller.blocks[site.block].instructions[instruction] {
        CallDirect(selected, environment, witnesses, arguments, destination) if selected ==
          target => Some((environment, witnesses, arguments, destination))
        _ => None
      }
    None =>
      match caller.blocks[site.block].terminator {
        TailCallDirect(selected, environment, witnesses, arguments) if selected ==
          target => Some((environment, witnesses, arguments, None))
        _ => None
      }
  }
  guard call is Some((environment, witnesses, arguments, destination)) &&
    witnesses.length() == callee.inputs.witnesses.length() &&
    arguments.length() == callee.inputs.user_parameters.length() else {
    return None
  }
  let returned = match callee_block.terminator {
    Return(value) => value
    _ => return None
  }
  match (site.instruction, destination, returned) {
    (Some(_), None, None) | (Some(_), Some(_), Some(_)) | (None, _, _) => ()
    _ => return None
  }
  let values = caller.values.copy()
  let mapping : Array[ValueId?] = Array::make(callee.values.length(), None)
  match (callee.inputs.environment, environment) {
    (None, None) => ()
    (Some(input), Some(environment)) => mapping[input.value] = Some(environment)
    _ => return None
  }
  for index, input in callee.inputs.witnesses {
    mapping[input.value] = Some(witnesses[index])
  }
  for index, input in callee.inputs.user_parameters {
    mapping[input.value] = Some(arguments[index])
  }
  if destination is Some(destination) &&
    returned is Some(returned) &&
    mapping[returned.value] is None {
    mapping[returned.value] = Some(destination)
  }
  for index in 0..<mapping.length() {
    if mapping[index] is None {
      mapping[index] = Some({ value: values.length(), })
      values.push(callee.values[index])
    }
  }
  for index in 0..<callee.values.length() {
    let mapped = mapping[index].unwrap()
    if mapped.value < caller.values.length() {
      continue
    }
    values[mapped.value] = {
      ..callee.values[index],
      erased_companion: callee.values[index].erased_companion.map(companion => {
        mapping[companion.value].unwrap()
      }),
    }
  }
  let transform = fn(value : ValueId) { mapping[value.value].unwrap() }
  let inlined = callee_block.instructions.map(instruction => {
    map_instruction_values(instruction, transform)
  })
  let mapped_return = returned.map(transform)
  if site.instruction is Some(_) &&
    destination is Some(destination) &&
    mapped_return is Some(result) &&
    result != destination {
    inlined.push(Move(destination, result))
  }
  let blocks = caller.blocks.mapi((block_index, block) => {
    guard block_index == site.block else { return block }
    match site.instruction {
      Some(instruction_index) => {
        let instructions = block.instructions[:instruction_index].to_owned()
        instructions.append(inlined)
        instructions.append(block.instructions[instruction_index + 1:])
        { ..block, instructions, }
      }
      None => {
        let instructions = block.instructions.copy()
        instructions.append(inlined)
        { ..block, instructions, terminator: Return(mapped_return), }
      }
    }
  })
  let functions = image.functions.copy()
  functions[site.caller] = Body({ ..caller, values, blocks, })
  Some(functions)
}
