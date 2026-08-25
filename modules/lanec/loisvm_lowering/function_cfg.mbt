///|
fn ImageLowerer::lower_function_body(
  self : ImageLowerer,
  lowered_function : @bytecode.FunctionId,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  guard self.physical_function(lowered_function) is Some(physical) else {
    raise RepresentationSpecializationInvariant(
      detail="VM CFG function emission lacks a physical function variant",
    )
  }
  let capture = physical.capture
  let lowerer : FunctionLowerer = {
    image: self,
    function: Some(lowered_function),
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: physical.substitutions,
    specialized_parameters: physical.specialized_parameters,
    physical: Some(physical),
  }
  let input_witnesses = []
  for parameter in physical.evidence_parameters {
    if self.requires_runtime_evidence(parameter) {
      let witness = lowerer.fresh_metadata(runtime_evidence_metadata(parameter))
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter: parameter.id, value: witness, })
    }
  }
  if capture.environment_shape is Some(shape) {
    let environment = lowerer.fresh_metadata(environment_metadata(shape))
    lowerer.environment = Some(environment)
    for index, evidence_plan in capture.captured_evidence {
      let parameter = evidence_plan.target
      let metadata = runtime_evidence_metadata(parameter)
      let evidence = lowerer.fresh_metadata(
        borrowed_evidence_metadata(metadata),
      )
      lowerer.emit(
        BorrowCapture(shape, environment, index, {
          value_destination: evidence,
          witness_destination: None,
        }),
      )
      lowerer.witnesses.push({ parameter: parameter.id, value: evidence, })
      if evidence_plan.source != parameter.id {
        lowerer.witnesses.push({
          parameter: evidence_plan.source,
          value: evidence,
        })
      }
    }
    for captured in capture.captures {
      match (captured.member_index, captured.shape) {
        (Some(member_index), Some(capture_shape)) => {
          let (destination, witness_destination) = if capture_shape
            is Value({ cleanup: OwnedErased, .. }) {
            let witness = lowerer.fresh_metadata(layout_witness_metadata())
            (
              lowerer.fresh_metadata(
                capture_shape.borrowed_value_metadata(Some(witness)),
              ),
              Some(witness),
            )
          } else {
            (
              lowerer.fresh_metadata(
                capture_shape.borrowed_value_metadata(None),
              ),
              None,
            )
          }
          lowerer.emit(
            BorrowCapture(shape, environment, member_index, {
              value_destination: destination,
              witness_destination,
            }),
          )
          lowerer.bind_capture(
            captured.binding,
            LocalValue::Slot(destination, captured.type_, capture_shape),
          )
        }
        (None, None) => lowerer.bind_capture(captured.binding, Unit)
        _ =>
          raise RepresentationSpecializationInvariant(
            detail="callable capture shape and environment member disagree",
          )
      }
    }
  } else {
    for captured in capture.captures {
      if captured.shape is Some(_) || captured.member_index is Some(_) {
        raise RepresentationSpecializationInvariant(
          detail="non-Unit callable capture has no environment",
        )
      }
      lowerer.bind_capture(captured.binding, Unit)
    }
  }
  for recursive in physical.recursive_functions {
    lowerer.bindings.push({
      value: recursive.recursive.value,
      lowered: RecursiveFunction(
        recursive.recursive.function,
        recursive.recursive.type_,
        lowerer.environment,
      ),
    })
  }
  let parameter_slots : Array[@vmcfg.ValueId] = []
  for index, parameter in physical.parameters {
    guard parameter.binding is Value(parameter_id) else {
      raise RepresentationSpecializationInvariant(
        detail="physical function parameter is not a source value binding",
      )
    }
    let type_ = parameter.type_
    let shape = lowerer.physical_parameter_shape(index)
    match shape {
      Product(contract, payload_shapes) => {
        if payload_shapes.length() != contract.payload_types.length() {
          raise RepresentationSpecializationInvariant(
            detail="planned aggregate parameter payload shapes disagree with its contract",
          )
        }
        let payloads = []
        for payload_index, payload_type in contract.payload_types {
          let (slot, payload) = lowerer.fresh_planned_optional_slot(
            payload_type,
            lowerer.physical_shape(payload_shapes[payload_index]),
          )
          if slot is Some(slot) {
            parameter_slots.push(slot)
          }
          payloads.push(payload)
        }
        lowerer.bindings.push({
          value: parameter_id,
          lowered: ClosedAggregate(contract, payloads),
        })
      }
      shape => {
        let (slot, lowered) = lowerer.fresh_planned_optional_slot(type_, shape)
        if slot is Some(slot) {
          parameter_slots.push(slot)
        }
        lowerer.bindings.push({ value: parameter_id, lowered, })
      }
    }
  }
  let result = lowerer.materialize_physical_function_result(
    lowerer.materialize_physical_local(lowerer.lower_expr(physical.body)),
  )
  let terminator : @vmcfg.Terminator = match
    lowerer.take_tail_call(result.value) {
    Some(terminator) => terminator
    None =>
      match result.value {
        Unit => Return(None)
        Slot(slot, _, _) => Return(Some(slot))
        ClosedAggregate(_, _)
        | Global(_)
        | NestedCallable(_)
        | RecursiveFunction(_, _, _)
        | EvidenceApplied(_, _)
        | EvidenceAppliedCallable(_, _, _, _)
        | EvidenceAppliedNestedCallable(_, _) =>
          raise UnsupportedExpression(
            detail="function returns an unapplied callable",
          )
      }
  }
  lowerer.terminate(terminator)
  lowerer.rewrite_tail_call_predecessors()
  let blocks : Array[@vmcfg.Block] = []
  for index, block in lowerer.blocks {
    let terminator = match block.terminator {
      Some(terminator) => terminator
      None => raise UnterminatedBlock(block=index)
    }
    blocks.push({
      parameters: block.parameters,
      instructions: block.instructions,
      terminator,
    })
  }
  {
    values: lowerer.values,
    inputs: {
      environment: lowerer.environment,
      witnesses: input_witnesses,
      user_parameters: parameter_slots,
    },
    result: physical.interface.invocation.result.physical_shape().result_abi(),
    blocks,
  }
}

///|
fn FunctionLowerer::rewrite_tail_call_predecessors(
  self : FunctionLowerer,
) -> Unit {
  for target_index, target in self.blocks {
    if !target.instructions.is_empty() {
      continue
    }
    let returned = match target.terminator {
      Some(Return(None)) if target.parameters.is_empty() => Some(None)
      Some(Return(Some(value))) if target.parameters is [parameter] &&
        parameter == value => Some(Some(value))
      _ => None
    }
    guard returned is Some(returned) else { continue }
    for predecessor in self.blocks {
      guard predecessor.terminator is Some(Jump(edge)) &&
        edge.target.value == target_index else {
        continue
      }
      let expected = match (returned, edge.arguments) {
        (None, []) => Some(None)
        (Some(_), [argument]) => Some(Some(argument))
        _ => None
      }
      guard expected is Some(expected) else { continue }
      predecessor.rewrite_last_call_as_tail(expected)
    }
  }
}

///|
fn LowerBlock::rewrite_last_call_as_tail(
  self : LowerBlock,
  expected : @vmcfg.ValueId?,
) -> Unit {
  guard self.instructions.last() is Some(instruction) else { return }
  match instruction {
    CallDirect(target, environment, witnesses, arguments, destination) =>
      if destination == expected {
        ignore(self.instructions.pop())
        self.terminator = Some(
          TailCallDirect(target, environment, witnesses, arguments),
        )
      }
    CallValue(callable, witnesses, arguments, destination) =>
      if destination == expected {
        ignore(self.instructions.pop())
        self.terminator = Some(TailCallValue(callable, witnesses, arguments))
      }
    _ => ()
  }
}

///|
fn FunctionLowerer::take_tail_call(
  self : FunctionLowerer,
  result : LocalValue,
) -> @vmcfg.Terminator? {
  let instructions = self.blocks[self.current_block].instructions
  guard instructions.last() is Some(instruction) else { return None }
  match instruction {
    CallDirect(target, environment, witnesses, arguments, destination) =>
      if tail_destination_matches(destination, result) {
        ignore(instructions.pop())
        Some(TailCallDirect(target, environment, witnesses, arguments))
      } else {
        None
      }
    CallValue(callable, witnesses, arguments, destination) =>
      if tail_destination_matches(destination, result) {
        ignore(instructions.pop())
        Some(TailCallValue(callable, witnesses, arguments))
      } else {
        None
      }
    _ => None
  }
}

///|
fn tail_destination_matches(
  destination : @vmcfg.ValueId?,
  result : LocalValue,
) -> Bool {
  match (destination, result) {
    (None, Unit) => true
    (Some(destination), Slot(result, _, _)) => destination == result
    _ => false
  }
}

///|
fn ImageLowerer::requires_runtime_evidence(
  _self : ImageLowerer,
  _parameter : @anf.RuntimeEvidenceParameter,
) -> Bool {
  true
}

///|
fn function_type_parts(
  type_ : @anf.RuntimeType,
) -> (
  Array[@anf.RuntimeEvidenceParameter],
  Array[@anf.RuntimeType],
  @anf.RuntimeType,
) raise LoisvmLoweringError {
  match type_ {
    Forall(parameters, body) => {
      let (nested_parameters, arguments, result) = function_type_parts(body)
      (parameters + nested_parameters, arguments, result)
    }
    Callable(parameters, result) => ([], parameters, result)
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn FunctionLowerer::emit(
  self : FunctionLowerer,
  instruction : @vmcfg.Instruction,
) -> Unit {
  self.blocks[self.current_block].instructions.push(instruction)
}

///|
fn FunctionLowerer::terminate(
  self : FunctionLowerer,
  terminator : @vmcfg.Terminator,
) -> Unit {
  self.blocks[self.current_block].terminator = Some(terminator)
}

///|
fn FunctionLowerer::new_block(
  self : FunctionLowerer,
  parameters : Array[@vmcfg.ValueId],
) -> @bytecode.BlockId {
  let block : @bytecode.BlockId = { value: self.blocks.length(), }
  self.blocks.push({ parameters, instructions: [], terminator: None, })
  block
}

///|
/// Creates the complete VM CFG parameter list for one physical value port.
/// An erased payload and its layout witness form one control-flow value and
/// must cross every edge together.
fn FunctionLowerer::fresh_block_value_parameter(
  self : FunctionLowerer,
  type_ : @anf.RuntimeType,
  shape : PhysicalValueShape,
) -> (Array[@vmcfg.ValueId], LocalValue) raise LoisvmLoweringError {
  let type_ = self.instantiate_runtime_type(type_)
  match shape {
    Unit => ([], Unit)
    Product(_, _) =>
      raise RepresentationSpecializationInvariant(
        detail="a VM CFG block parameter cannot encode a product shape",
      )
    Slot(key) => {
      let parameters = []
      let companion = match key {
        Value({ cleanup: OwnedErased, .. }) => {
          let companion = self.fresh_metadata(layout_witness_metadata())
          parameters.push(companion)
          Some(companion)
        }
        _ => None
      }
      let value = self.fresh_metadata(key.value_metadata(companion))
      parameters.push(value)
      (parameters, LocalValue::Slot(value, type_, key))
    }
  }
}

///|
fn FunctionLowerer::block_value_arguments(
  self : FunctionLowerer,
  value : LocalValue,
) -> Array[@vmcfg.ValueId] raise LoisvmLoweringError {
  match value {
    Unit => []
    Slot(slot, _, _) => {
      let arguments = []
      if self.values[slot.value].cleanup is OwnedErased {
        guard self.values[slot.value].erased_companion is Some(companion) else {
          raise RepresentationSpecializationInvariant(
            detail="an erased control-flow value has no layout companion",
          )
        }
        arguments.push(companion)
      }
      arguments.push(slot)
      arguments
    }
    ClosedAggregate(_, _)
    | Global(_)
    | NestedCallable(_)
    | RecursiveFunction(_, _, _)
    | EvidenceApplied(_, _)
    | EvidenceAppliedCallable(_, _, _, _)
    | EvidenceAppliedNestedCallable(_, _) =>
      raise UnsupportedExpression(
        detail="control-flow edge carries an unapplied callable",
      )
  }
}

///|
fn FunctionLowerer::enter_block(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
) -> Unit {
  self.current_block = block.value
}

///|
