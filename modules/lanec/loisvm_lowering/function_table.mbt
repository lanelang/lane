///|
fn canonicalize_function_table(
  image : @vmcfg.Image,
  origins : Array[LoisvmFunctionOrigin],
) -> CanonicalizedFunctionTable raise FunctionTableCanonicalizationError {
  if image.functions.length() != origins.length() {
    raise OriginCountMismatch(
      functions=image.functions.length(),
      origins=origins.length(),
    )
  }
  let reachable = reachable_functions(image)
  let mappings : Array[@bytecode.FunctionId?] = Array::make(
    image.functions.length(),
    None,
  )
  let bodies : Array[@vmcfg.FunctionBody] = []
  let body_provenance : Array[LoisvmFunctionProvenance] = []
  let imports : Array[CanonicalRuntimeImport] = []
  for index, entry in image.functions {
    guard reachable[index] else { continue }
    let old_id : @bytecode.FunctionId = { value: index + 1 }
    match entry {
      Body(body) => {
        let new_id : @bytecode.FunctionId = { value: bodies.length() + 1 }
        mappings[index] = Some(new_id)
        bodies.push(body)
        body_provenance.push({ function: new_id, origins: [origins[index]] })
      }
      RuntimeImport(descriptor) => {
        let mut found = false
        for import_ in imports {
          if import_.descriptor == descriptor {
            import_.old_ids.push(old_id)
            found = true
          }
        }
        if !found {
          imports.push({ descriptor, old_ids: [old_id] })
        }
      }
    }
  }
  imports.sort_by(fn(left, right) {
    let symbol_order = String::compare(
      left.descriptor.symbol,
      right.descriptor.symbol,
    )
    if symbol_order != 0 {
      symbol_order
    } else {
      let abi_order = left.descriptor.abi_major - right.descriptor.abi_major
      if abi_order != 0 {
        abi_order
      } else {
        let parameter_order = compare_runtime_value_kinds(
          left.descriptor.parameters,
          right.descriptor.parameters,
        )
        if parameter_order != 0 {
          parameter_order
        } else {
          runtime_value_kind_rank(left.descriptor.result) -
          runtime_value_kind_rank(right.descriptor.result)
        }
      }
    }
  })
  for index, import_ in imports {
    let new_id : @bytecode.FunctionId = { value: bodies.length() + index + 1 }
    for old_id in import_.old_ids {
      mappings[old_id.value - 1] = Some(new_id)
    }
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  let provenance = body_provenance
  for body in bodies {
    functions.push(Body(remap_function_body(body, mappings)))
  }
  for import_ in imports {
    functions.push(RuntimeImport(import_.descriptor))
    let function : @bytecode.FunctionId = { value: provenance.length() + 1 }
    let merged_origins = import_.old_ids.map(old_id => origins[old_id.value - 1])
    provenance.push({ function, origins: merged_origins })
  }
  let canonical_image = {
    ..image,
    entry: remap_function_id(image.entry, mappings),
    initializer: match image.initializer {
      Some(function) => Some(remap_function_id(function, mappings))
      None => None
    },
    functions,
  }
  { image: canonical_image, provenance }
}

///|
fn reachable_functions(
  image : @vmcfg.Image,
) -> Array[Bool] raise FunctionTableCanonicalizationError {
  let reachable = Array::make(image.functions.length(), false)
  let worklist : Array[@bytecode.FunctionId] = []
  mark_reachable_function(image.functions, reachable, worklist, image.entry)
  if image.initializer is Some(initializer) {
    mark_reachable_function(image.functions, reachable, worklist, initializer)
  }
  while worklist.pop() is Some(function) {
    guard image.functions[function.value - 1] is Body(body) else { continue }
    for block in body.blocks {
      for instruction in block.instructions {
        match instruction {
          ConstFunction(_, target)
          | CallDirect(target, _, _, _, _)
          | MakeClosure(_, target, _) =>
            mark_reachable_function(
              image.functions,
              reachable,
              worklist,
              target,
            )
          _ => ()
        }
      }
      if block.terminator is TailCallDirect(target, _, _, _) {
        mark_reachable_function(image.functions, reachable, worklist, target)
      }
    }
  }
  reachable
}

///|
fn mark_reachable_function(
  functions : Array[@vmcfg.FunctionEntry],
  reachable : Array[Bool],
  worklist : Array[@bytecode.FunctionId],
  function : @bytecode.FunctionId,
) -> Unit raise FunctionTableCanonicalizationError {
  if function.value <= 0 || function.value > functions.length() {
    raise InvalidFunctionReference(function~)
  }
  let index = function.value - 1
  if !reachable[index] {
    reachable[index] = true
    worklist.push(function)
  }
}

///|
fn compare_runtime_value_kinds(
  left : Array[@bytecode.RuntimeValueKind],
  right : Array[@bytecode.RuntimeValueKind],
) -> Int {
  let common = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for index in 0..<common {
    let order = runtime_value_kind_rank(left[index]) -
      runtime_value_kind_rank(right[index])
    if order != 0 {
      return order
    }
  }
  left.length() - right.length()
}

///|
fn runtime_value_kind_rank(kind : @bytecode.RuntimeValueKind) -> Int {
  match kind {
    Unit => 0
    Bool => 1
    I64 => 2
    F64 => 3
    String => 4
    Opaque => 5
    F32 => 6
  }
}

///|
fn remap_function_body(
  body : @vmcfg.FunctionBody,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.FunctionBody raise FunctionTableCanonicalizationError {
  {
    ..body,
    blocks: body.blocks.map(block => {
      ..block,
      instructions: block.instructions.map(instruction => {
        remap_instruction_function_ids(instruction, mappings)
      }),
      terminator: remap_terminator_function_ids(block.terminator, mappings),
    }),
  }
}

///|
fn remap_instruction_function_ids(
  instruction : @vmcfg.Instruction,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.Instruction raise FunctionTableCanonicalizationError {
  match instruction {
    ConstFunction(destination, function) =>
      ConstFunction(destination, remap_function_id(function, mappings))
    CallDirect(function, environment, witnesses, arguments, destination) =>
      CallDirect(
        remap_function_id(function, mappings),
        environment,
        witnesses,
        arguments,
        destination,
      )
    MakeClosure(destination, function, environment) =>
      MakeClosure(
        destination,
        remap_function_id(function, mappings),
        environment,
      )
    _ => instruction
  }
}

///|
fn remap_terminator_function_ids(
  terminator : @vmcfg.Terminator,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.Terminator raise FunctionTableCanonicalizationError {
  match terminator {
    TailCallDirect(function, environment, witnesses, arguments) =>
      TailCallDirect(
        remap_function_id(function, mappings),
        environment,
        witnesses,
        arguments,
      )
    _ => terminator
  }
}

///|
fn remap_function_id(
  function : @bytecode.FunctionId,
  mappings : Array[@bytecode.FunctionId?],
) -> @bytecode.FunctionId raise FunctionTableCanonicalizationError {
  if function.value <= 0 || function.value > mappings.length() {
    raise InvalidFunctionReference(function~)
  }
  match mappings[function.value - 1] {
    Some(mapped) => mapped
    None => raise MissingFunctionMapping(function~)
  }
}

///|
