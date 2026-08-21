///|
fn FunctionLowerer::find_witness(
  self : FunctionLowerer,
  parameter : @anf.RuntimeEvidenceId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  for binding in self.witnesses {
    if binding.parameter == parameter {
      return binding.value
    }
  }
  raise InvalidTypeApplication(
    detail="missing in-scope layout witness for \{Repr(parameter)}; available=\{Repr(self.witnesses.map(binding => binding.parameter))}; substitutions=\{Repr(self.substitutions)}",
  )
}

///|
fn FunctionLowerer::equivalent_witness(
  self : FunctionLowerer,
  evidence : @anf.RuntimeEvidence,
) -> @vmcfg.ValueId? raise LoisvmLoweringError {
  for binding in self.witnesses {
    if self.substitutions.apply_evidence(Parameter(binding.parameter)) ==
      evidence {
      return Some(binding.value)
    }
  }
  None
}

///|
fn FunctionLowerer::layout_witness(
  self : FunctionLowerer,
  evidence : @anf.RuntimeEvidence,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let evidence = self.substitutions.apply_evidence(evidence)
  self.materialize_runtime_evidence(self.image.plan_layout_witness(evidence))
}

///|
fn FunctionLowerer::erase_planned_value(
  self : FunctionLowerer,
  value : LocalValue,
  witness : @vmcfg.ValueId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let destination = self.fresh_erased_slot(witness, Owned)
  match self.materialize_local(value) {
    Unit => self.emit(EraseUnit(destination))
    Slot(source, _, Value({ representation: I32, .. })) =>
      self.emit(EraseI32(destination, source))
    Slot(source, _, Value({ representation: I64, .. }))
    | Slot(source, _, Callable(_)) => self.emit(EraseI64(destination, source))
    Slot(source, _, Value({ representation: F32, .. })) =>
      self.emit(EraseF32(destination, source))
    Slot(source, _, Value({ representation: F64, .. })) =>
      self.emit(EraseF64(destination, source))
    _ =>
      raise RepresentationSpecializationInvariant(
        detail="planned erasure source is not a physical value",
      )
  }
  destination
}
