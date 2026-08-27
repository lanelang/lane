///|
fn ImageLowerer::lower_function_body(
  self : ImageLowerer,
  function : @anf.AnfFunction,
  type_parameters : Array[@anf.RuntimeEvidenceParameter],
  parameter_types : Array[@anf.RuntimeType],
  result_type : @anf.RuntimeType,
  captured_parameters : Array[@anf.RuntimeEvidenceParameter],
  captures : Array[CapturePlan],
  environment_shape : @physical.ObjectShapeId?,
  recursive_functions : Array[RecursiveFunctionPlan],
  substitutions : RuntimeSubstitution,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions,
  }
  let input_witnesses = []
  for parameter in type_parameters {
    if self.requires_runtime_evidence(parameter) {
      let witness = lowerer.fresh_metadata(runtime_evidence_metadata(parameter))
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter: parameter.id, value: witness, })
    }
  }
  if environment_shape is Some(shape) {
    let environment = lowerer.fresh_metadata(environment_metadata(shape))
    lowerer.environment = Some(environment)
    for index, parameter in captured_parameters {
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
    }
    for capture in captures {
      if capture.member_index is Some(member_index) {
        let (destination, witness_destination) = if self.runtime_type(
            capture.type_,
          )
          is Erased(_) {
          let witness = lowerer.fresh_metadata(layout_witness_metadata())
          (lowerer.fresh_erased_slot(witness, Borrowed), Some(witness))
        } else {
          (lowerer.fresh_borrowed_slot(capture.type_), None)
        }
        lowerer.emit(
          BorrowCapture(shape, environment, member_index, {
            value_destination: destination,
            witness_destination,
          }),
        )
        lowerer.bind_capture(capture.binding, Slot(destination, capture.type_))
      } else {
        lowerer.bind_capture(capture.binding, Unit)
      }
    }
  } else {
    for capture in captures {
      lowerer.bind_capture(capture.binding, Unit)
    }
  }
  for recursive in recursive_functions {
    lowerer.bindings.push({
      value: recursive.value,
      lowered: RecursiveFunction(
        recursive.function,
        recursive.type_,
        lowerer.environment,
      ),
    })
  }
  let parameter_slots : Array[@vmcfg.ValueId] = []
  for index, parameter in function.parameters {
    let type_ = parameter_types[index]
    if self.runtime_type(type_) is Concrete(Unit) {
      lowerer.bindings.push({ value: parameter, lowered: Unit, })
    } else {
      let slot = lowerer.fresh_slot(type_)
      parameter_slots.push(slot)
      lowerer.bindings.push({ value: parameter, lowered: Slot(slot, type_), })
    }
  }
  let lowered_result = lowerer.lower_expr(function.body)
  let source_type = local_value_type(lowered_result).unwrap_or(result_type)
  let result = lowerer.materialize_local(
    lowerer.adapt_local_value_with_substitutions(
      lowered_result, source_type, result_type, substitutions,
    ),
  )
  let terminator : @vmcfg.Terminator = match lowerer.take_tail_call(result) {
    Some(terminator) => terminator
    None =>
      match result {
        Unit => Return(None)
        Slot(slot, _) => Return(Some(slot))
        Global(_)
        | RecursiveFunction(_, _, _)
        | EvidenceApplied(_, _)
        | EvidenceAppliedCallable(_, _, _)
        | EvidenceAppliedFunction(_, _, _, _)
        | AdaptedCallable(_)
        | EvidenceAppliedAdaptedCallable(_, _) =>
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
    result: self.result_abi(result_type),
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
    (Some(destination), Slot(result, _)) => destination == result
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
) raise PhysicalLoweringError {
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
) -> @physical.BlockId {
  let block : @physical.BlockId = { value: self.blocks.length(), }
  self.blocks.push({ parameters, instructions: [], terminator: None, })
  block
}

///|
fn FunctionLowerer::enter_block(
  self : FunctionLowerer,
  block : @physical.BlockId,
) -> Unit {
  self.current_block = block.value
}

///|
