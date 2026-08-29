///|
fn PhysicalProgramVerifier::verify_function(
  self : PhysicalProgramVerifier,
  function : FunctionId,
  body : FunctionBody,
) -> Unit raise PhysicalProgramVerificationError {
  let function_site = PhysicalVerificationSite::Function(function)
  if body.blocks.is_empty() {
    self.fail(function_site, "block table must be nonempty")
  }
  if !body.blocks[0].parameters.is_empty() {
    self.fail(function_site, "entry block must have no parameters")
  }
  if body.result is Value(representation, cleanup, kind) &&
    !self.legal_metadata(function_site, representation, cleanup, kind) {
    self.fail(function_site, "illegal function result ABI")
  }
  for slot in body.slots {
    if !self.legal_metadata(
        function_site,
        slot.representation,
        slot.cleanup,
        slot.kind,
      ) {
      self.fail(
        function_site, "illegal slot representation and cleanup combination",
      )
    }
    match (slot.cleanup, slot.erased_companion) {
      (OwnedErased, Some(companion)) => {
        let companion_slot = self.slot_metadata(function_site, body, companion)
        if companion_slot.representation != I32 ||
          companion_slot.cleanup != Trivial ||
          companion_slot.kind != LayoutValue {
          self.fail(
            function_site, "erased companion must name an I32 Trivial slot",
          )
        }
      }
      (OwnedErased, None) =>
        self.fail(function_site, "OwnedErased slot requires a companion")
      (_, Some(_)) =>
        self.fail(function_site, "only OwnedErased slots have companions")
      _ => ()
    }
  }
  let input_slots : Array[SlotId] = []
  if body.inputs.environment is Some(environment) {
    self.expect_slot(function_site, body, environment, I32, OwnedRef)
    if !(self.slot_metadata(function_site, body, environment).kind
      is EnvironmentValue(_)) {
      self.fail(
        function_site, "function environment must have Environment value kind",
      )
    }
    input_slots.push(environment)
  }
  for witness in body.inputs.witnesses {
    ignore(self.slot_metadata(function_site, body, witness))
    input_slots.push(witness)
  }
  for parameter in body.inputs.user_parameters {
    ignore(self.slot_metadata(function_site, body, parameter))
    input_slots.push(parameter)
  }
  self.verify_distinct_slots(function_site, input_slots, "function input")
  for block_index, block in body.blocks {
    let block_id : BlockId = { value: block_index, }
    let block_site = PhysicalVerificationSite::Block(function, block_id)
    for parameter in block.parameters {
      ignore(self.slot_metadata(block_site, body, parameter))
    }
    self.verify_distinct_slots(block_site, block.parameters, "block parameter")
    for instruction_index, instruction in block.instructions {
      self.verify_instruction(
        function, block_id, instruction_index, body, instruction,
      )
    }
    self.verify_terminator(function, block_id, body, block.terminator)
  }
}

///|
fn PhysicalProgramVerifier::verify_distinct_slots(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  slots : Array[SlotId],
  what : String,
) -> Unit raise PhysicalProgramVerificationError {
  for left in 0..<slots.length() {
    for right in (left + 1)..<slots.length() {
      if slots[left] == slots[right] {
        self.fail(site, "duplicate \{what} SlotId \{slots[left].value}")
      }
    }
  }
}

///|
fn PhysicalProgramVerifier::verify_edge(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  edge : Edge,
) -> Unit raise PhysicalProgramVerificationError {
  if edge.target.value < 0 || edge.target.value >= body.blocks.length() {
    self.fail(site, "BlockId \{edge.target.value} is out of range")
  }
  let parameters = body.blocks[edge.target.value].parameters
  if edge.arguments.length() != parameters.length() {
    self.fail(
      site,
      "edge to BlockId \{edge.target.value} has \{edge.arguments.length()} arguments for \{parameters.length()} parameters",
    )
  }
  for index in 0..<edge.arguments.length() {
    self.expect_same_shape(site, body, edge.arguments[index], parameters[index])
  }
}

///|
fn PhysicalProgramVerifier::verify_terminator(
  self : PhysicalProgramVerifier,
  function : FunctionId,
  block : BlockId,
  body : FunctionBody,
  terminator : Terminator,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Terminator(function, block)
  match terminator {
    Jump(edge) => self.verify_edge(site, body, edge)
    BranchBool(condition, true_edge, false_edge) => {
      self.expect_slot(site, body, condition, I32, Trivial)
      self.expect_kind(site, body, condition, ScalarValue)
      self.verify_edge(site, body, true_edge)
      self.verify_edge(site, body, false_edge)
    }
    SwitchTag(tag, cases, default) => {
      self.expect_slot(site, body, tag, I32, Trivial)
      self.expect_kind(site, body, tag, ScalarValue)
      for edge in cases {
        self.verify_edge(site, body, edge)
      }
      self.verify_edge(site, body, default)
    }
    Return(source) =>
      match (result_shape(body.result), source) {
        (None, None) => ()
        (Some((representation, cleanup, kind)), Some(source)) =>
          self.expect_value_shape(
            site, body, source, representation, cleanup, kind,
          )
        (None, Some(_)) => self.fail(site, "Unit function must return no slot")
        (Some(_), None) =>
          self.fail(site, "non-Unit function must return a slot")
      }
    TailCallDirect(target, environment, witnesses, arguments) =>
      self.verify_direct_call(
        site,
        body,
        target,
        environment,
        witnesses,
        arguments,
        None,
        tail_result=Some(body.result),
      )
    TailCallValue(callable, abi_id, witnesses, arguments) => {
      self.expect_slot(site, body, callable, I64, OwnedCallable)
      let abi = self.callable_abi(site, abi_id)
      self.verify_call_abi(
        site,
        body,
        abi,
        witnesses,
        arguments,
        None,
        tail_result=Some(body.result),
      )
    }
    Fatal(message) =>
      self.expect_value_shape(
        site,
        body,
        message,
        I32,
        OwnedRef,
        ByteSequenceValue,
      )
    Unreachable => ()
  }
}
