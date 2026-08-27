///|
fn FunctionLowerer::find_witness(
  self : FunctionLowerer,
  parameter : @anf.RuntimeEvidenceId,
) -> @vmcfg.ValueId raise PhysicalLoweringError {
  for binding in self.witnesses {
    if binding.parameter == parameter {
      return binding.value
    }
  }
  if self.substitutions.argument(parameter) is Some(argument) {
    let parameter = self.image.metadata
      .evidence_parameter(parameter)
      .unwrap_or({ id: parameter, arity: 0, })
    return self.runtime_evidence(parameter, argument)
  }
  let requested = self.substitutions.apply_evidence(Parameter(parameter))
  for binding in self.witnesses {
    if self.substitutions.apply_evidence(Parameter(binding.parameter)) ==
      requested {
      return binding.value
    }
  }
  raise InvalidTypeApplication(
    detail="missing in-scope layout witness for \{Repr(parameter)}",
  )
}

///|
fn FunctionLowerer::layout_witness(
  self : FunctionLowerer,
  evidence : @anf.RuntimeEvidence,
) -> @vmcfg.ValueId raise PhysicalLoweringError {
  let evidence = self.substitutions.apply_evidence(evidence)
  self.materialize_runtime_evidence(self.image.plan_layout_witness(evidence))
}

///|
fn FunctionLowerer::erase_value(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @anf.RuntimeType,
  witness : @vmcfg.ValueId,
) -> @vmcfg.ValueId raise PhysicalLoweringError {
  let destination = self.fresh_erased_slot(witness, Owned)
  let materialized = self.materialize_local(value)
  let type_ = local_value_type(materialized).unwrap_or(source_type)
  match self.image.runtime_type(type_) {
    Erased(_) => {
      guard materialized is Slot(source, _) else {
        raise InvalidTypeApplication(
          detail="generic argument representation does not match its type",
        )
      }
      self.emit(Move(destination, source))
    }
    Concrete(type_) =>
      match (materialized, type_) {
        (Unit, Unit) => self.emit(EraseUnit(destination))
        (
          Slot(source, _),
          Scalar(Bool | I32 | Char | Byte)
          | ByteSequence
          | OpaqueReference(_)
          | Data(_, _),
        ) => self.emit(EraseI32(destination, source))
        (Slot(source, _), Scalar(I64)) =>
          self.emit(EraseI64(destination, source))
        (Slot(source, _), Scalar(F32)) =>
          self.emit(EraseF32(destination, source))
        (Slot(source, _), Callable(_, _) | Forall(_, _)) => {
          let (canonical_type, bindings) = self.image.canonical_callable_type(
            type_,
          )
          guard self.materialize_local(
              self.make_callable_adapter(
                source, type_, canonical_type, bindings,
              ),
            )
            is Slot(adapted, _) else {
            abort("callable adapter was not materialized")
          }
          self.emit(EraseI64(destination, adapted))
        }
        (Slot(source, _), Scalar(F64)) =>
          self.emit(EraseF64(destination, source))
        _ =>
          raise InvalidTypeApplication(
            detail="generic argument representation does not match its type",
          )
      }
  }
  destination
}

///|
fn FunctionLowerer::unerase_value(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  target_type : @anf.RuntimeType,
  substitutions : RuntimeSubstitution,
) -> LocalValue raise PhysicalLoweringError {
  let target_type = substitutions.apply_type(
    self.image.runtime_types,
    target_type,
  )
  match self.image.runtime_type(target_type) {
    Erased(_) => Slot(source, target_type)
    Concrete(runtime_type) =>
      match runtime_type {
        Unit => {
          self.emit(UneraseUnit(source))
          Unit
        }
        Scalar(Bool | I32 | Char | Byte)
        | ByteSequence
        | OpaqueReference(_)
        | Data(_, _) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseI32(destination, source))
          Slot(destination, target_type)
        }
        Scalar(I64) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseI64(destination, source))
          Slot(destination, target_type)
        }
        Scalar(F32) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseF32(destination, source))
          Slot(destination, target_type)
        }
        Callable(_, _) | Forall(_, _) => {
          let (canonical_type, bindings) = self.image.canonical_callable_type(
            runtime_type,
          )
          let canonical = self.fresh_slot(canonical_type)
          self.emit(UneraseI64(canonical, source))
          self.make_callable_adapter(
            canonical, canonical_type, runtime_type, bindings,
          )
        }
        Scalar(F64) => {
          let destination = self.fresh_slot(runtime_type)
          self.emit(UneraseF64(destination, source))
          Slot(destination, target_type)
        }
        Erased(_, _) => raise UnsupportedType(type_=runtime_type)
      }
  }
}
