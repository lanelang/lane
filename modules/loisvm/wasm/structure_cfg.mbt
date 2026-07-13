///|
priv struct StructuredSequence {
  parts : Array[StructuredPart]
}

///|
priv enum StructuredPart {
  Plain(Int)
  Loop(Int, StructuredSequence)
}

///|
priv struct StructuredLabel {
  target : Int
  depth : Int
}

///|
fn structure_cfg(body : @bytecode.FunctionBody) -> StructuredSequence? {
  let nodes = []
  for index in 0..<body.blocks.length() {
    nodes.push(index)
  }
  structure_region(body, nodes, 0, None)
}

///|
fn structure_region(
  body : @bytecode.FunctionBody,
  nodes : Array[Int],
  entry : Int,
  ignored_target : Int?,
) -> StructuredSequence? {
  if nodes.is_empty() || !contains_node(nodes, entry) {
    return None
  }
  let components = strong_components(body, nodes, ignored_target)
  let order = match
    topological_component_order(body, nodes, components, entry, ignored_target) {
    Some(order) => order
    None => return None
  }
  let parts = []
  for component_index in order {
    let component = components[component_index]
    if component_is_cyclic(body, component, ignored_target) {
      let header = match
        component_header(body, nodes, component, entry, ignored_target) {
        Some(header) => header
        None => return None
      }
      let nested = match
        structure_region(body, component, header, Some(header)) {
        Some(nested) => nested
        None => return None
      }
      parts.push(Loop(header, nested))
    } else {
      if component.length() != 1 {
        return None
      }
      parts.push(Plain(component[0]))
    }
  }
  Some({ parts, })
}

///|
fn strong_components(
  body : @bytecode.FunctionBody,
  nodes : Array[Int],
  ignored_target : Int?,
) -> Array[Array[Int]] {
  let assigned = Array::make(body.blocks.length(), false)
  let components = []
  for node in nodes {
    if assigned[node] {
      continue
    }
    let component = []
    for candidate in nodes {
      if !assigned[candidate] &&
        graph_reaches(body, nodes, ignored_target, node, candidate) &&
        graph_reaches(body, nodes, ignored_target, candidate, node) {
        component.push(candidate)
      }
    }
    for node in component {
      assigned[node] = true
    }
    components.push(component)
  }
  components
}

///|
fn graph_reaches(
  body : @bytecode.FunctionBody,
  nodes : Array[Int],
  ignored_target : Int?,
  start : Int,
  target : Int,
) -> Bool {
  if start == target {
    return true
  }
  let visited = Array::make(body.blocks.length(), false)
  let pending = [start]
  visited[start] = true
  while pending.pop() is Some(node) {
    for successor in analysis_successors(body, nodes, ignored_target, node) {
      if successor == target {
        return true
      }
      if !visited[successor] {
        visited[successor] = true
        pending.push(successor)
      }
    }
  }
  false
}

///|
fn analysis_successors(
  body : @bytecode.FunctionBody,
  nodes : Array[Int],
  ignored_target : Int?,
  node : Int,
) -> Array[Int] {
  let result = []
  for target in terminator_targets(body.blocks[node].terminator) {
    if target >= 0 &&
      target < body.blocks.length() &&
      contains_node(nodes, target) &&
      ignored_target != Some(target) &&
      !contains_node(result, target) {
      result.push(target)
    }
  }
  result
}

///|
fn terminator_targets(terminator : @bytecode.Terminator) -> Array[Int] {
  match terminator {
    Jump(edge) => [edge.target.value]
    BranchBool(_, if_true, if_false) =>
      [if_true.target.value, if_false.target.value]
    SwitchTag(_, cases, default) => {
      let targets = cases.map(edge => edge.target.value)
      targets.push(default.target.value)
      targets
    }
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Unreachable => []
  }
}

///|
fn component_is_cyclic(
  body : @bytecode.FunctionBody,
  component : Array[Int],
  ignored_target : Int?,
) -> Bool {
  if component.length() > 1 {
    return true
  }
  let node = component[0]
  for target in terminator_targets(body.blocks[node].terminator) {
    if target == node && ignored_target != Some(target) {
      return true
    }
  }
  false
}

///|
fn component_header(
  body : @bytecode.FunctionBody,
  nodes : Array[Int],
  component : Array[Int],
  region_entry : Int,
  ignored_target : Int?,
) -> Int? {
  let mut header = if contains_node(component, region_entry) {
    Some(region_entry)
  } else {
    None
  }
  for source in nodes {
    if contains_node(component, source) {
      continue
    }
    for target in analysis_successors(body, nodes, ignored_target, source) {
      if contains_node(component, target) {
        match header {
          None => header = Some(target)
          Some(existing) if existing != target => return None
          Some(_) => ()
        }
      }
    }
  }
  match header {
    Some(header) => Some(header)
    None => component.get(0)
  }
}

///|
fn topological_component_order(
  body : @bytecode.FunctionBody,
  nodes : Array[Int],
  components : Array[Array[Int]],
  entry : Int,
  ignored_target : Int?,
) -> Array[Int]? {
  let count = components.length()
  let edges : Array[Array[Bool]] = []
  for _ in 0..<count {
    edges.push(Array::make(count, false))
  }
  let indegree = Array::make(count, 0)
  for source in nodes {
    let source_component = find_component(components, source)
    for target in analysis_successors(body, nodes, ignored_target, source) {
      let target_component = find_component(components, target)
      if source_component != target_component &&
        !edges[source_component][target_component] {
        edges[source_component][target_component] = true
        indegree[target_component] += 1
      }
    }
  }
  let entry_component = find_component(components, entry)
  if indegree[entry_component] != 0 {
    return None
  }
  let selected = Array::make(count, false)
  let order = []
  while order.length() < count {
    let mut next = None
    if order.is_empty() {
      next = Some(entry_component)
    } else {
      for candidate in 0..<count {
        if !selected[candidate] && indegree[candidate] == 0 {
          next = Some(candidate)
          break
        }
      }
    }
    guard next is Some(component) else { return None }
    if selected[component] || indegree[component] != 0 {
      return None
    }
    selected[component] = true
    order.push(component)
    for target in 0..<count {
      if edges[component][target] {
        indegree[target] -= 1
      }
    }
  }
  Some(order)
}

///|
fn find_component(components : Array[Array[Int]], node : Int) -> Int {
  for index, component in components {
    if contains_node(component, node) {
      return index
    }
  }
  abort("CFG node is missing from its component partition")
}

///|
fn contains_node(nodes : Array[Int], target : Int) -> Bool {
  for node in nodes {
    if node == target {
      return true
    }
  }
  false
}

///|
fn StructuredPart::entry(self : StructuredPart) -> Int {
  match self {
    Plain(block) | Loop(block, _) => block
  }
}

///|
fn compile_structured_cfg(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  sequence : StructuredSequence,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  compile_structured_sequence(
    function_id,
    parameter_count,
    live_base,
    body,
    wasm_module,
    static_image,
    runtime_functions,
    sequence,
    [],
  )
}

///|
fn compile_structured_sequence(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  sequence : StructuredSequence,
  external_labels : Array[StructuredLabel],
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  let compiled = []
  for index, part in sequence.parts {
    let remaining = sequence.parts.length() - index - 1
    let labels = external_labels.map(label => {
      ..label,
      depth: label.depth + remaining,
    })
    for future in (index + 1)..<sequence.parts.length() {
      labels.push({
        target: sequence.parts[future].entry(),
        depth: future - index - 1,
      })
    }
    compiled.push(
      compile_structured_part(
        function_id, parameter_count, live_base, body, wasm_module, static_image,
        runtime_functions, part, labels,
      ),
    )
  }
  let result = compiled[0]
  for index in 1..<compiled.length() {
    let nested : Array[@wasm_types.Instruction] = [Block(Empty, result.copy())]
    nested.append(compiled[index])
    result.clear()
    result.append(nested)
  }
  result
}

///|
fn compile_structured_part(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  part : StructuredPart,
  labels : Array[StructuredLabel],
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  match part {
    Plain(block) =>
      compile_structured_block(
        function_id, parameter_count, live_base, body, wasm_module, static_image,
        runtime_functions, block, labels,
      )
    Loop(header, nested) => {
      let loop_labels = labels.map(label => { ..label, depth: label.depth + 1 })
      loop_labels.insert(0, { target: header, depth: 0 })
      [
        Loop(
          Empty,
          compile_structured_sequence(
            function_id, parameter_count, live_base, body, wasm_module, static_image,
            runtime_functions, nested, loop_labels,
          ),
        ),
      ]
    }
  }
}

///|
fn compile_structured_block(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  block_index : Int,
  labels : Array[StructuredLabel],
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  let block = body.blocks[block_index]
  let instructions : Array[@wasm_types.Instruction] = []
  for instruction in block.instructions {
    instructions.append(
      compile_instruction(
        parameter_count,
        live_base,
        body.slots,
        wasm_module,
        static_image,
        runtime_functions,
        instruction,
      ),
    )
  }
  instructions.append(
    compile_structured_terminator(
      function_id,
      parameter_count,
      live_base,
      body,
      wasm_module,
      static_image,
      labels,
      block.terminator,
    ),
  )
  instructions
}

///|
fn compile_structured_terminator(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  labels : Array[StructuredLabel],
  terminator : @bytecode.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  match terminator {
    Jump(edge) =>
      compile_structured_edge(
        function_id, parameter_count, live_base, body, labels, edge, 0,
      )
    BranchBool(condition, if_true, if_false) =>
      [
        LocalGet(slot_local(parameter_count, condition)),
        If(
          Empty,
          compile_structured_edge(
            function_id, parameter_count, live_base, body, labels, if_true, 1,
          ),
          compile_structured_edge(
            function_id, parameter_count, live_base, body, labels, if_false, 1,
          ),
        ),
      ]
    SwitchTag(discriminator, cases, default) =>
      compile_structured_switch(
        function_id, parameter_count, live_base, body, labels, discriminator, cases,
        default,
      )
    terminal =>
      compile_terminator(
        function_id,
        parameter_count,
        live_base,
        body.slots,
        body.result,
        wasm_module,
        static_image,
        terminal,
      )
  }
}

///|
fn compile_structured_switch(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  labels : Array[StructuredLabel],
  discriminator : @bytecode.SlotId,
  cases : Array[@bytecode.Edge],
  default : @bytecode.Edge,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  if cases.is_empty() {
    return compile_structured_edge(
      function_id, parameter_count, live_base, body, labels, default, 0,
    )
  }
  let branch_labels = []
  for index in 0..<cases.length() {
    branch_labels.push(index)
  }
  let selection : Array[@wasm_types.Instruction] = [
    LocalGet(slot_local(parameter_count, discriminator)),
    BrTable(branch_labels, cases.length()),
  ]
  for case_index in 0..<cases.length() {
    let wrapped : Array[@wasm_types.Instruction] = [
      Block(Empty, selection.copy()),
    ]
    wrapped.append(
      compile_structured_edge(
        function_id,
        parameter_count,
        live_base,
        body,
        labels,
        cases[case_index],
        cases.length() - case_index,
      ),
    )
    selection.clear()
    selection.append(wrapped)
  }
  let result : Array[@wasm_types.Instruction] = [Block(Empty, selection)]
  result.append(
    compile_structured_edge(
      function_id, parameter_count, live_base, body, labels, default, 0,
    ),
  )
  result
}

///|
fn compile_structured_edge(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  body : @bytecode.FunctionBody,
  labels : Array[StructuredLabel],
  edge : @bytecode.Edge,
  extra_depth : Int,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  if edge.target.value < 0 || edge.target.value >= body.blocks.length() {
    raise InvalidBlockTarget(function_id~, target=edge.target.value)
  }
  let target_parameters = body.blocks[edge.target.value].parameters
  if target_parameters.length() != edge.arguments.length() {
    raise InvalidEdgeArity(
      function_id~,
      target=edge.target.value,
      expected=target_parameters.length(),
      actual=edge.arguments.length(),
    )
  }
  let instructions : Array[@wasm_types.Instruction] = []
  for index, destination in target_parameters {
    instructions.push(
      LocalGet(slot_local(parameter_count, edge.arguments[index])),
    )
    instructions.push(
      LocalSet(
        transfer_local(parameter_count, body.slots.length(), destination),
      ),
    )
  }
  for source in edge.arguments {
    instructions.append(mark_slot_dead(live_base, body.slots, source))
  }
  for destination in target_parameters {
    instructions.push(
      LocalGet(
        transfer_local(parameter_count, body.slots.length(), destination),
      ),
    )
    instructions.push(LocalSet(slot_local(parameter_count, destination)))
    instructions.append(mark_slot_live(live_base, body.slots, destination))
  }
  let depth = match structured_label_depth(labels, edge.target.value) {
    Some(depth) => depth
    None => abort("structured CFG edge has no enclosing Wasm label")
  }
  instructions.push(Br(depth + extra_depth))
  instructions
}

///|
fn structured_label_depth(
  labels : Array[StructuredLabel],
  target : Int,
) -> Int? {
  for label in labels {
    if label.target == target {
      return Some(label.depth)
    }
  }
  None
}
