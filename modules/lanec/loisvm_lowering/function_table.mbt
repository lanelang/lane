///|
fn canonicalize_function_table(image : @vmcfg.Image) -> @vmcfg.Image {
  let mappings : Array[@bytecode.FunctionId?] = Array::make(
    image.functions.length(),
    None,
  )
  let bodies : Array[@vmcfg.FunctionBody] = []
  let imports : Array[CanonicalRuntimeImport] = []
  for index, entry in image.functions {
    let old_id : @bytecode.FunctionId = { value: index + 1 }
    match entry {
      Body(body) => {
        let new_id : @bytecode.FunctionId = { value: bodies.length() + 1 }
        mappings[index] = Some(new_id)
        bodies.push(body)
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
        left.descriptor.user_arity - right.descriptor.user_arity
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
  for body in bodies {
    functions.push(Body(remap_function_body(body, mappings)))
  }
  for import_ in imports {
    functions.push(RuntimeImport(import_.descriptor))
  }
  {
    ..image,
    entry: remap_function_id(image.entry, mappings),
    initializer: image.initializer.map(function => {
      remap_function_id(function, mappings)
    }),
    functions,
  }
}

///|
fn remap_function_body(
  body : @vmcfg.FunctionBody,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.FunctionBody {
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
) -> @vmcfg.Instruction {
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
) -> @vmcfg.Terminator {
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
) -> @bytecode.FunctionId {
  match mappings[function.value - 1] {
    Some(mapped) => mapped
    None => abort("missing canonical FunctionId mapping")
  }
}

///|
