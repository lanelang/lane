///|
fn ImageLowerer::lower_function_body(
  self : ImageLowerer,
  function : @anf.AnfFunction,
  type_parameters : Array[@buslane.TypeParameterId],
  parameter_types : Array[@buslane.Type],
  result_type : @buslane.Type,
  captured_parameters : Array[@buslane.TypeParameterId],
  captures : Array[CapturePlan],
  environment_shape : @bytecode.ObjectShapeId?,
  recursive_functions : Array[RecursiveFunctionPlan],
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
  }
  let input_witnesses = []
  for parameter in type_parameters {
    if self.requires_layout_witness(parameter) {
      let witness = lowerer.fresh_metadata(layout_witness_metadata())
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter, value: witness })
    }
  }
  if environment_shape is Some(shape) {
    let environment = lowerer.fresh_metadata(environment_metadata())
    lowerer.environment = Some(environment)
    for index, parameter in captured_parameters {
      let witness = lowerer.fresh_metadata(layout_witness_metadata())
      lowerer.emit(LoadObjectWitness(witness, shape, environment, index))
      lowerer.witnesses.push({ parameter, value: witness })
    }
    for capture in captures {
      if capture.member_index is Some(member_index) {
        let (destination, witness_destination) = if capture.type_
          is Parameter(_) {
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
    if type_ == Primitive(Unit) {
      lowerer.bindings.push({ value: parameter, lowered: Unit })
    } else {
      let slot = lowerer.fresh_slot(type_)
      parameter_slots.push(slot)
      lowerer.bindings.push({ value: parameter, lowered: Slot(slot, type_) })
    }
  }
  let result = lowerer.materialize_local(lowerer.lower_expr(function.body))
  let terminator : @vmcfg.Terminator = match lowerer.take_tail_call(result) {
    Some(terminator) => terminator
    None =>
      match result {
        Unit => Return(None)
        Slot(slot, _) => Return(Some(slot))
        Global(_)
        | RecursiveFunction(_, _, _)
        | TypeApplied(_, _)
        | TypeAppliedCallable(_, _, _) =>
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
    result: result_representation(result_type),
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
fn ImageLowerer::requires_layout_witness(
  self : ImageLowerer,
  parameter : @buslane.TypeParameterId,
) -> Bool {
  match self.metadata.type_parameter_info(parameter) {
    Some({ kind: Type, .. }) => true
    _ => false
  }
}

///|
fn function_type_parts(
  type_ : @buslane.Type,
) -> (Array[@buslane.TypeParameterId], Array[@buslane.Type], @buslane.Type) raise LoisvmLoweringError {
  match type_ {
    Forall(parameters, body) =>
      match strip_forall(body) {
        Function(arguments, result, _) => (parameters, arguments, result)
        _ => raise UnsupportedType(type_~)
      }
    Function(parameters, result, _) => ([], parameters, result)
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn strip_forall(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Forall(_, body) => strip_forall(body)
    _ => type_
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
  let block : @bytecode.BlockId = { value: self.blocks.length() }
  self.blocks.push({ parameters, instructions: [], terminator: None })
  block
}

///|
fn FunctionLowerer::enter_block(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
) -> Unit {
  self.current_block = block.value
}

///|
