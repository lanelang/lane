///|
fn FunctionLowerer::lower_call(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.AnfAtom],
) -> LocalValue raise LoisvmLoweringError {
  let physical_call = self.planned_call(site)
  let representation_target = physical_call.target
  let lowered_callee = match representation_target {
    Some({ invocation: Direct, .. }) => None
    Some({ invocation: Captured(_), .. }) | None =>
      Some(self.lower_atom(callee))
  }
  let lowered_arguments = []
  for index, argument in arguments {
    let planned_argument = physical_call.callable_arguments[index]
    let lowered = match planned_argument {
      Some(instance) =>
        self.materialize_planned_callable_atom(argument, instance)
      None => self.lower_atom(argument)
    }
    lowered_arguments.push(self.materialize_local(lowered))
  }
  if representation_target is Some(physical_target) {
    let plan = physical_target.worker
    let contract = self.image.physical_invocation(plan.worker)
    let (callable, environment) = match physical_target.invocation {
      Direct => (None, None)
      Captured(function) => {
        let deferred = match lowered_callee {
          Some(
            NestedCallable(callable)
            | EvidenceAppliedNestedCallable(callable, _)
          ) => Some(callable)
          _ => None
        }
        guard deferred is Some(callable) && callable.function.id == function else {
          raise RepresentationSpecializationInvariant(
            detail="represented call no longer matches its planned captured invocation",
          )
        }
        guard self.materialize_representation_worker(plan, callable.environment)
          is Slot(worker, _, _) else {
          abort("representation worker was not materialized")
        }
        (Some(worker), None)
      }
    }
    return self.lower_representation_specialized_call(
      plan,
      contract,
      lowered_arguments,
      physical_call,
      environment~,
      callable~,
    )
  }
  guard lowered_callee is Some(callee) else {
    raise RepresentationSpecializationInvariant(
      detail="ordinary call has no materialized callable",
    )
  }
  match callee {
    Global(Intrinsic(contract)) =>
      self.lower_intrinsic(contract, lowered_arguments)
    Global(Function(function, _)) =>
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=Some((function, None)),
        callable=None,
      )
    RecursiveFunction(function, _, environment) =>
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=Some((function, environment)),
        callable=None,
      )
    EvidenceApplied(Function(function, _), _) =>
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=Some((function, None)),
        callable=None,
      )
    EvidenceAppliedCallable(callable, _, _, _) =>
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=None,
        callable=Some(callable),
      )
    NestedCallable(callable) => {
      guard self.materialize_nested_callable(callable) is Slot(slot, type_, _) else {
        abort("nested callable was not materialized")
      }
      ignore(type_)
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=None,
        callable=Some(slot),
      )
    }
    EvidenceAppliedNestedCallable(callable, type_arguments) => {
      guard self.materialize_nested_callable(callable) is Slot(slot, _, _) else {
        abort("nested callable was not materialized")
      }
      ignore(type_arguments)
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=None,
        callable=Some(slot),
      )
    }
    EvidenceApplied(_, _) =>
      raise InvalidTypeApplication(
        detail="type application target is not a generic function",
      )
    Slot(callable, _, _) =>
      self.lower_physical_call(
        lowered_arguments,
        physical_call,
        direct=None,
        callable=Some(callable),
      )
    _ => raise UnsupportedExpression(detail="value is not callable")
  }
}

///|
fn FunctionLowerer::materialize_local(
  self : FunctionLowerer,
  value : LocalValue,
) -> LocalValue raise LoisvmLoweringError {
  match value {
    Global(Function(function, type_)) =>
      self.materialize_callable_value(function, type_, None)
    Global(Intrinsic(contract)) => {
      let type_ = contract.type_()
      self.materialize_callable_value_with_abi(
        self.image.intrinsic_wrapper(contract),
        type_,
        None,
        self.image.canonical_callable_abi_under(
          type_,
          RuntimeSubstitution::new(),
        ),
      )
    }
    Global(DoubleConstant(bits, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstF64(destination, bits))
      self.slot_value(destination, type_)
    }
    Global(FloatConstant(bits, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstF32(destination, bits))
      self.slot_value(destination, type_)
    }
    RecursiveFunction(function, type_, environment) =>
      self.materialize_callable_value(function, type_, environment)
    NestedCallable(callable) => self.materialize_nested_callable(callable)
    EvidenceApplied(_, _)
    | EvidenceAppliedCallable(_, _, _, _)
    | EvidenceAppliedNestedCallable(_, _) =>
      raise InvalidTypeApplication(
        detail="a type-applied callable must be called before materialization",
      )
    _ => value
  }
}

///|
fn FunctionLowerer::lower_physical_call(
  self : FunctionLowerer,
  arguments : Array[LocalValue],
  call : PhysicalCallPlan,
  direct~ : (@bytecode.FunctionId, @vmcfg.ValueId?)?,
  callable~ : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  if call.parameter_types.length() != arguments.length() ||
    call.arguments.length() != arguments.length() {
    raise RepresentationSpecializationInvariant(
      detail="call arguments disagree with its physical invocation contract",
    )
  }
  let witnesses = self.materialize_physical_call_witnesses(call)
  let argument_slots = []
  for index, argument in arguments {
    let flow = call.arguments[index]
    let source_shape = self.physical_shape(flow.source)
    let target_shape = self.physical_shape(flow.target)
    if self.local_physical_shape(argument) != source_shape {
      raise RepresentationSpecializationInvariant(
        detail="call argument \{index} at \{Repr(call.site)} (callable instance \{Repr(call.callable_arguments[index])}) produced \{Repr(self.local_physical_shape(argument))}, but its source port owns \{Repr(source_shape)} before flow to \{Repr(target_shape)} for \{Repr(call.parameter_types[index])}",
      )
    }
    let adapted = self.materialize_planned_value_flow(
      "call argument \{index} at \{Repr(call.site)}",
      argument,
      call.parameter_types[index],
      target_shape,
      flow.bridge,
    )
    match adapted {
      Unit => ()
      Slot(slot, _, shape) => {
        guard target_shape is PhysicalValueShape::Slot(expected) &&
          shape == expected else {
          raise RepresentationSpecializationInvariant(
            detail="value call argument disagrees with its physical invocation contract",
          )
        }
        argument_slots.push(slot)
      }
      _ =>
        raise RepresentationSpecializationInvariant(
          detail="value call argument is not a materialized physical value",
        )
    }
  }
  if argument_slots.length() != call.invocation.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="value call arguments do not consume its physical invocation contract",
    )
  }
  let destination = self.fresh_physical_call_result(call)
  match (direct, callable) {
    (Some((function, environment)), None) =>
      self.emit(
        CallDirect(
          function,
          environment,
          witnesses,
          argument_slots,
          destination.0,
        ),
      )
    (None, Some(callable)) =>
      self.emit(CallValue(callable, witnesses, argument_slots, destination.0))
    _ =>
      raise RepresentationSpecializationInvariant(
        detail="physical call must select exactly one callable target",
      )
  }
  self.materialize_planned_value_flow(
    "call result at \{Repr(call.site)}",
    destination.1,
    call.result_type,
    self.physical_shape(call.result.target),
    call.result.bridge,
  )
}

///|
fn FunctionLowerer::materialize_physical_call_witnesses(
  self : FunctionLowerer,
  call : PhysicalCallPlan,
) -> Array[@vmcfg.ValueId] raise LoisvmLoweringError {
  let witnesses = []
  for plan in call.witnesses {
    let witness = self.materialize_runtime_evidence(plan) catch {
      error =>
        raise RepresentationSpecializationInvariant(
          detail="call at \{Repr(call.site)} cannot materialize planned witness \{Repr(plan)}: \{Repr(error)}",
        )
    }
    witnesses.push(witness)
  }
  if witnesses.length() != call.invocation.witnesses.length() {
    raise RepresentationSpecializationInvariant(
      detail="call at \{Repr(call.site)} planned \{witnesses.length()} runtime witnesses for an invocation requiring \{call.invocation.witnesses.length()}: plans=\{Repr(call.witnesses)}, invocation=\{Repr(call.invocation)}",
    )
  }
  witnesses
}

///|
fn FunctionLowerer::fresh_physical_call_result(
  self : FunctionLowerer,
  call : PhysicalCallPlan,
) -> (@vmcfg.ValueId?, LocalValue) raise LoisvmLoweringError {
  let shape = call.invocation.result.physical_shape()
  match (shape, call.abi_result_evidence) {
    (
      PhysicalValueShape::Slot(Value({ cleanup: OwnedErased, .. }) as key),
      Some(evidence),
    ) => {
      let companion = self.materialize_runtime_evidence(evidence) catch {
        error =>
          raise RepresentationSpecializationInvariant(
            detail="call at \{Repr(call.site)} cannot materialize planned result evidence \{Repr(evidence)}: \{Repr(error)}",
          )
      }
      let slot = self.fresh_metadata(key.value_metadata(Some(companion)))
      (Some(slot), LocalValue::Slot(slot, call.abi_result_type, key))
    }
    (PhysicalValueShape::Slot(Value({ cleanup: OwnedErased, .. })), None) =>
      raise RepresentationSpecializationInvariant(
        detail="call at \{Repr(call.site)} has an erased result without planned runtime evidence",
      )
    (_, Some(_)) =>
      raise RepresentationSpecializationInvariant(
        detail="call at \{Repr(call.site)} planned runtime evidence for a non-erased result",
      )
    (_, None) => self.fresh_planned_optional_slot(call.abi_result_type, shape)
  }
}

///|
fn FunctionLowerer::materialize_planned_call_argument(
  self : FunctionLowerer,
  site : @anf.AnfBindingId,
  argument : LocalValue,
  target_type : @anf.RuntimeType,
  target_shape : PhysicalValueShape,
  bridge : PhysicalValueBridge?,
) -> LocalValue raise LoisvmLoweringError {
  self.materialize_planned_value_flow(
    "Runtime ANF flow at \{Repr(site)}",
    argument,
    target_type,
    target_shape,
    bridge,
  )
}

///|
fn FunctionLowerer::materialize_planned_value_flow(
  self : FunctionLowerer,
  provenance : String,
  argument : LocalValue,
  target_type : @anf.RuntimeType,
  target_shape : PhysicalValueShape,
  bridge : PhysicalValueBridge?,
) -> LocalValue raise LoisvmLoweringError {
  let adapted = match bridge {
    Some(Callable(contract)) =>
      self.materialize_planned_callable_bridge(provenance, argument, contract)
    Some(Erase(erasure)) => {
      guard target_shape is Slot(target) else {
        raise RepresentationSpecializationInvariant(
          detail="planned erasure has no physical result slot",
        )
      }
      let argument = match erasure.callable {
        Some(contract) =>
          self.materialize_planned_callable_bridge(
            provenance, argument, contract,
          )
        None => argument
      }
      let witness = self.materialize_runtime_evidence(erasure.evidence) catch {
        error =>
          raise RepresentationSpecializationInvariant(
            detail="\{provenance} cannot materialize planned erasure evidence \{Repr(erasure.evidence)}: \{Repr(error)}",
          )
      }
      let erased = self.erase_planned_value(argument, witness)
      LocalValue::Slot(erased, target_type, target)
    }
    Some(Unerase(callable)) => {
      guard argument is Slot(source, _, source_shape) &&
        source_shape
        is CanonicalRuntimeTypeKey::Value({ cleanup: OwnedErased, .. }) else {
        raise RepresentationSpecializationInvariant(
          detail="planned unerasure has no erased source slot",
        )
      }
      let unerased_shape = match callable {
        Some(contract) =>
          PhysicalValueShape::Slot(
            CanonicalRuntimeTypeKey::Callable(contract.recipe.source_abi),
          )
        None => target_shape
      }
      let unerased = self.unerase_planned_call_argument(
        source, target_type, unerased_shape,
      )
      match callable {
        Some(contract) =>
          self.materialize_planned_callable_bridge(
            provenance, unerased, contract,
          )
        None => unerased
      }
    }
    None => argument
  }
  if self.local_physical_shape(adapted) != target_shape {
    let bridge_kind = match bridge {
      None => "none"
      Some(Callable(_)) => "callable"
      Some(Erase(_)) => "erase"
      Some(Unerase(None)) => "unerase"
      Some(Unerase(Some(_))) => "unerase+callable"
    }
    raise RepresentationSpecializationInvariant(
      detail="\{provenance} planned \{bridge_kind} bridge but produced \{Repr(self.local_physical_shape(adapted))}, expected \{Repr(target_shape)} for \{Repr(target_type)}",
    )
  }
  match (target_shape, adapted) {
    (Unit, Unit) => Unit
    (Slot(expected), Slot(slot, _, actual)) if expected == actual =>
      LocalValue::Slot(slot, target_type, expected)
    (Product(_), _) =>
      raise RepresentationSpecializationInvariant(
        detail="a call argument cannot expose an unlowered product shape",
      )
    _ =>
      raise RepresentationSpecializationInvariant(
        detail="planned call argument has no matching physical value",
      )
  }
}

///|
fn FunctionLowerer::unerase_planned_call_argument(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  target_type : @anf.RuntimeType,
  target_shape : PhysicalValueShape,
) -> LocalValue raise LoisvmLoweringError {
  match target_shape {
    Unit => {
      self.emit(UneraseUnit(source))
      Unit
    }
    Product(_) =>
      raise RepresentationSpecializationInvariant(
        detail="planned unerasure cannot produce an unlowered product shape",
      )
    Slot(key) => {
      let destination = self.fresh_metadata(key.value_metadata(None))
      let representation = match key {
        Unit =>
          raise RepresentationSpecializationInvariant(
            detail="Unit cannot be stored in a physical call slot",
          )
        Value(abi) => abi.representation
        Callable(_) => @bytecode.Representation::I64
      }
      match representation {
        I32 => self.emit(UneraseI32(destination, source))
        I64 => self.emit(UneraseI64(destination, source))
        F32 => self.emit(UneraseF32(destination, source))
        F64 => self.emit(UneraseF64(destination, source))
      }
      LocalValue::Slot(destination, target_type, key)
    }
  }
}

///|
fn FunctionLowerer::lower_representation_specialized_call(
  self : FunctionLowerer,
  plan : RepresentationSpecializationPlan,
  contract : CanonicalCallableAbi,
  values : Array[LocalValue],
  call : PhysicalCallPlan,
  environment~ : @vmcfg.ValueId?,
  callable~ : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  if values.length() != plan.parameter_types.length() ||
    call.parameter_types != plan.parameter_types {
    raise RepresentationSpecializationInvariant(
      detail="representation-specialized call arguments do not match its worker",
    )
  }
  if call.invocation != contract {
    raise RepresentationSpecializationInvariant(
      detail="representation-specialized call planned \{Repr(call.invocation)}, but worker owns \{Repr(contract)}",
    )
  }
  if call.arguments.length() != values.length() {
    raise RepresentationSpecializationInvariant(
      detail="representation-specialized call argument arity disagrees with its physical call plan",
    )
  }
  let witnesses = self.materialize_physical_call_witnesses(call)
  let arguments = []
  let mut physical_index = 0
  for index, formal in plan.parameter_types {
    let flow = call.arguments[index]
    let source_shape = self.physical_shape(flow.source)
    if self.local_physical_shape(values[index]) != source_shape {
      raise RepresentationSpecializationInvariant(
        detail="representation call argument \{index} at \{Repr(call.site)} produced \{Repr(self.local_physical_shape(values[index]))}, but its source port owns \{Repr(source_shape)}",
      )
    }
    let target_shape = self.physical_shape(flow.target)
    match target_shape {
      Product(payload_shapes) => {
        guard flow.bridge is None &&
          values[index] is ClosedAggregate(aggregate_contract, payloads) &&
          payloads.length() == payload_shapes.length() &&
          plan.scalar_parameters.any(parameter => {
            parameter.parameter_index == index &&
            parameter.contract == aggregate_contract
          }) else {
          raise RepresentationSpecializationInvariant(
            detail="closed aggregate argument does not match its physical call plan",
          )
        }
        for payload_index, payload in payloads {
          let expected = self.physical_shape(payload_shapes[payload_index])
          if self.local_physical_shape(payload) != expected {
            raise RepresentationSpecializationInvariant(
              detail="closed aggregate payload disagrees with its physical call plan",
            )
          }
          physical_index = self.append_planned_call_argument(
            arguments,
            self.materialize_local(payload),
            contract.parameters,
            physical_index,
          )
        }
      }
      target_shape => {
        let adapted = self.materialize_planned_value_flow(
          "representation call argument \{index} at \{Repr(call.site)}",
          values[index],
          formal,
          target_shape,
          flow.bridge,
        )
        physical_index = self.append_planned_call_argument(
          arguments,
          adapted,
          contract.parameters,
          physical_index,
        )
      }
    }
  }
  if physical_index != contract.parameters.length() {
    raise RepresentationSpecializationInvariant(
      detail="representation-specialized arguments do not consume the planned worker contract",
    )
  }
  let abi_result_shape = contract.result.physical_shape()
  if call.invocation.result.physical_shape() != abi_result_shape {
    raise RepresentationSpecializationInvariant(
      detail="representation-specialized result disagrees with its physical call plan",
    )
  }
  let worker_result = self.fresh_physical_call_result(call)
  match callable {
    Some(callable) =>
      self.emit(CallValue(callable, witnesses, arguments, worker_result.0))
    None =>
      self.emit(
        CallDirect(
          plan.worker,
          environment,
          witnesses,
          arguments,
          worker_result.0,
        ),
      )
  }
  self.materialize_planned_value_flow(
    "representation call result at \{Repr(call.site)}",
    worker_result.1,
    call.result_type,
    self.physical_shape(call.result.target),
    call.result.bridge,
  )
}

///|
fn FunctionLowerer::append_planned_call_argument(
  self : FunctionLowerer,
  arguments : Array[@vmcfg.ValueId],
  value : LocalValue,
  parameters : Array[CanonicalRuntimeTypeKey],
  index : Int,
) -> Int raise LoisvmLoweringError {
  ignore(self)
  match value {
    Unit => index
    Slot(slot, _, shape) => {
      guard parameters.get(index) is Some(expected) && shape == expected else {
        raise RepresentationSpecializationInvariant(
          detail="representation-specialized argument disagrees with the planned worker contract",
        )
      }
      arguments.push(slot)
      index + 1
    }
    _ =>
      raise RepresentationSpecializationInvariant(
        detail="representation-specialized argument is not materialized",
      )
  }
}

///|
fn required_runtime_argument(
  substitution : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
  parameter : @anf.RuntimeEvidenceId,
) -> @anf.RuntimeArgument raise LoisvmLoweringError {
  match substitution.argument(parameter) {
    Some(argument) => substitution.apply_argument(runtime_types, argument)
    None =>
      raise InvalidTypeApplication(
        detail="type substitution does not bind \{Repr(parameter)}",
      )
  }
}

///|
fn FunctionLowerer::lower_intrinsic(
  self : FunctionLowerer,
  contract : RuntimeIntrinsicFunctionContract,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let intrinsic = contract.intrinsic
  let result_type = contract.result
  match (intrinsic, arguments) {
    (
      CharToI32
      | I32ToChar
      | StringToBytes
      | BytesToString,
      [Slot(source, _, shape)],
    ) => return Slot(source, result_type, shape)
    _ => ()
  }
  match intrinsic {
    BytesMake
    | BytesLength
    | BytesGet
    | BytesSet
    | BytesEqual
    | BytesConcat
    | BytesSlice
    | BytesIsValidUtf8
    | F32ToString
    | F64ToString => ignore(self.image.intern_layout(ByteSequence))
    _ => ()
  }
  let slots = arguments.map(fn(argument) {
    match argument {
      Slot(slot, _, _) => slot
      _ => abort("intrinsic argument is not represented by a slot")
    }
  })
  let destination = self.fresh_slot(result_type)
  let instruction : @vmcfg.Instruction = match (intrinsic, slots) {
    (I64Add, [left, right]) => I64Add(destination, left, right)
    (I64Sub, [left, right]) => I64Sub(destination, left, right)
    (I64Mul, [left, right]) => I64Mul(destination, left, right)
    (I64Div, [left, right]) => I64Div(destination, left, right)
    (I64Rem, [left, right]) => I64Rem(destination, left, right)
    (I64Neg, [source]) => I64Neg(destination, source)
    (I64Equal, [left, right]) => I64Eq(destination, left, right)
    (I64Less, [left, right]) => I64Lt(destination, left, right)
    (I32Add, [left, right]) => I32Add(destination, left, right)
    (I32Sub, [left, right]) => I32Sub(destination, left, right)
    (I32Mul, [left, right]) => I32Mul(destination, left, right)
    (I32Div, [left, right]) => I32Div(destination, left, right)
    (I32Rem, [left, right]) => I32Rem(destination, left, right)
    (I32Neg, [source]) => I32Neg(destination, source)
    (I32Equal, [left, right]) => I32Eq(destination, left, right)
    (I32Less, [left, right]) => I32Lt(destination, left, right)
    (I32ToI64, [source]) => I32ToI64(destination, source)
    (I64ToI32, [source]) => I64ToI32(destination, source)
    (F32Add, [left, right]) => F32Add(destination, left, right)
    (F32Sub, [left, right]) => F32Sub(destination, left, right)
    (F32Mul, [left, right]) => F32Mul(destination, left, right)
    (F32Div, [left, right]) => F32Div(destination, left, right)
    (F32Neg, [source]) => F32Neg(destination, source)
    (F32Equal, [left, right]) => F32Eq(destination, left, right)
    (F32Less, [left, right]) => F32Lt(destination, left, right)
    (I64ToF32, [source]) => I64ToF32(destination, source)
    (F32ToI64, [source]) => F32ToI64(destination, source)
    (F32ToF64, [source]) => F32ToF64(destination, source)
    (F64ToF32, [source]) => F64ToF32(destination, source)
    (F32ToString, [source]) => F32ToString(destination, source)
    (F64ToString, [source]) => F64ToString(destination, source)
    (I64ToF64, [source]) => I64ToF64(destination, source)
    (F64ToI64, [source]) => F64ToI64(destination, source)
    (F64Add, [left, right]) => F64Add(destination, left, right)
    (F64Sub, [left, right]) => F64Sub(destination, left, right)
    (F64Mul, [left, right]) => F64Mul(destination, left, right)
    (F64Div, [left, right]) => F64Div(destination, left, right)
    (F64Neg, [source]) => F64Neg(destination, source)
    (F64Equal, [left, right]) => F64Eq(destination, left, right)
    (F64Less, [left, right]) => F64Lt(destination, left, right)
    (ByteToI64, [source]) => ByteToI64(destination, source)
    (I64ToByte, [source]) => I64ToByte(destination, source)
    (BytesMake, [length, fill]) => ByteSequenceMake(destination, length, fill)
    (BytesLength, [source]) => ByteSequenceLength(destination, source)
    (BytesGet, [source, index]) => ByteSequenceGet(destination, source, index)
    (BytesSet, [source, index, value]) =>
      ByteSequenceSet(destination, source, index, value)
    (BytesEqual, [left, right]) => ByteSequenceEqual(destination, left, right)
    (BytesConcat, [left, right]) => ByteSequenceConcat(destination, left, right)
    (BytesSlice, [source, start, length]) =>
      ByteSequenceSlice(destination, source, start, length)
    (BytesIsValidUtf8, [source]) => ByteSequenceIsValidUtf8(destination, source)
    _ => raise UnsupportedIntrinsic(name=intrinsic.name())
  }
  self.emit(instruction)
  self.slot_value(destination, result_type)
}

///|
