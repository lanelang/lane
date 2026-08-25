///|
priv struct CanonicalRuntimeImport {
  descriptor : @bytecode.RuntimeImport
  old_ids : Array[@bytecode.FunctionId]
}

///|
priv struct CanonicalFunctionTable {
  image : Image
  source_functions : Array[Array[@bytecode.FunctionId]]
}

///|
fn canonicalize_function_table_to_fixed_point(
  image : Image,
) -> CanonicalFunctionTable raise FunctionTableCanonicalizationError {
  for canonical = canonicalize_function_table(image) {
    let next = canonicalize_function_table(canonical.image)
    let source_functions = next.source_functions.map(sources => {
      let original : Array[@bytecode.FunctionId] = []
      for source in sources {
        if source.value <= 0 ||
          source.value > canonical.source_functions.length() {
          raise InvalidFunctionReference(source)
        }
        original.append(canonical.source_functions[source.value - 1])
      }
      original
    })
    let composed : CanonicalFunctionTable = {
      image: next.image,
      source_functions,
    }
    if composed.image.functions.length() == canonical.image.functions.length() {
      break composed
    }
    continue composed
  }
}

///|
fn canonicalize_function_table(
  image : Image,
) -> CanonicalFunctionTable raise FunctionTableCanonicalizationError {
  let reachable = reachable_functions(image)
  let equivalence_classes = structural_function_classes(image, reachable)
  let mappings : Array[@bytecode.FunctionId?] = Array::make(
    image.functions.length(),
    None,
  )
  let bodies : Array[FunctionBody] = []
  let body_classes : Array[Int] = []
  let body_old_ids : Array[Array[@bytecode.FunctionId]] = []
  let imports : Array[CanonicalRuntimeImport] = []
  for index, entry in image.functions {
    guard reachable[index] else { continue }
    let old_id : @bytecode.FunctionId = { value: index + 1, }
    match entry {
      Body(body) => {
        let class = equivalence_classes[index]
        let mut existing : Int? = None
        for body_index, canonical in body_classes {
          if canonical == class {
            existing = Some(body_index)
            break
          }
        }
        match existing {
          Some(body_index) => {
            mappings[index] = Some({ value: body_index + 1, })
            body_old_ids[body_index].push(old_id)
          }
          None => {
            let new_id : @bytecode.FunctionId = { value: bodies.length() + 1, }
            mappings[index] = Some(new_id)
            bodies.push(body)
            body_classes.push(class)
            body_old_ids.push([old_id])
          }
        }
      }
      RuntimeImport(descriptor) => {
        let mut existing : CanonicalRuntimeImport? = None
        for import_ in imports {
          if import_.descriptor == descriptor {
            existing = Some(import_)
            break
          }
        }
        match existing {
          Some(import_) => import_.old_ids.push(old_id)
          None => imports.push({ descriptor, old_ids: [old_id], })
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
    let new_id : @bytecode.FunctionId = { value: bodies.length() + index + 1, }
    for old_id in import_.old_ids {
      mappings[old_id.value - 1] = Some(new_id)
    }
  }
  let functions : Array[FunctionEntry] = []
  let source_functions = body_old_ids.copy()
  for body in bodies {
    functions.push(Body(remap_function_body(body, mappings)))
  }
  for import_ in imports {
    functions.push(RuntimeImport(import_.descriptor))
    source_functions.push(import_.old_ids)
  }
  {
    image: {
      ..image,
      entry: remap_function_id(image.entry, mappings),
      initializer: image.initializer.map(function => {
        remap_function_id(function, mappings)
      }),
      functions,
    },
    source_functions,
  }
}

///|
fn structural_function_classes(
  image : Image,
  reachable : Array[Bool],
) -> Array[Int] raise FunctionTableCanonicalizationError {
  let initial = reachable.mapi((index, retained) => {
    if !retained {
      -1
    } else {
      match image.functions[index] {
        Body(_) => 0
        RuntimeImport(import_) => {
          let mut class = 1
          for candidate in image.functions[:index] {
            if candidate is RuntimeImport(existing) {
              if existing == import_ {
                break
              }
              class += 1
            }
          }
          class
        }
      }
    }
  })
  for classes = initial {
    let mappings : Array[@bytecode.FunctionId?] = classes.map(class => {
      if class >= 0 {
        Some(({ value: class + 1, } : @bytecode.FunctionId))
      } else {
        None
      }
    })
    let normalized : Array[FunctionEntry?] = image.functions.mapi((index, entry) => {
      guard reachable[index] else { return None }
      Some(
        match entry {
          Body(body) => Body(remap_function_body(body, mappings))
          RuntimeImport(_) => entry
        },
      )
    })
    let next = classes.copy()
    let representatives : Array[Int] = []
    for index, entry in normalized {
      guard entry is Some(entry) else { continue }
      let mut class : Int? = None
      for candidate_class, representative in representatives {
        if classes[representative] == classes[index] &&
          normalized[representative] == Some(entry) {
          class = Some(candidate_class)
          break
        }
      }
      match class {
        Some(class) => next[index] = class
        None => {
          next[index] = representatives.length()
          representatives.push(index)
        }
      }
    }
    if next == classes {
      break classes
    }
    continue next
  }
}

///|
fn reachable_functions(
  image : Image,
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
  functions : Array[FunctionEntry],
  reachable : Array[Bool],
  worklist : Array[@bytecode.FunctionId],
  function : @bytecode.FunctionId,
) -> Unit raise FunctionTableCanonicalizationError {
  if function.value <= 0 || function.value > functions.length() {
    raise InvalidFunctionReference(function)
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
  body : FunctionBody,
  mappings : Array[@bytecode.FunctionId?],
) -> FunctionBody raise FunctionTableCanonicalizationError {
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
  instruction : Instruction,
  mappings : Array[@bytecode.FunctionId?],
) -> Instruction raise FunctionTableCanonicalizationError {
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
  terminator : Terminator,
  mappings : Array[@bytecode.FunctionId?],
) -> Terminator raise FunctionTableCanonicalizationError {
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
    raise InvalidFunctionReference(function)
  }
  match mappings[function.value - 1] {
    Some(mapped) => mapped
    None => raise MissingFunctionMapping(function)
  }
}
