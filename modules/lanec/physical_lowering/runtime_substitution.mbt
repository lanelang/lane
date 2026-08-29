///|
fn RuntimeSubstitution::new() -> RuntimeSubstitution {
  { entries: [], }
}

///|
fn RuntimeSubstitution::from_arguments(
  parameters : Array[@anf.RuntimeEvidenceParameter],
  arguments : Array[@anf.RuntimeArgument],
) -> RuntimeSubstitution raise PhysicalLoweringError {
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="runtime application expects \{parameters.length()} arguments, got \{arguments.length()}",
    )
  }
  let substitution = RuntimeSubstitution::new()
  for index, parameter in parameters {
    substitution.insert(parameter.id, arguments[index])
  }
  substitution
}

///|
fn RuntimeSubstitution::insert(
  self : RuntimeSubstitution,
  parameter : @anf.RuntimeEvidenceId,
  replacement : @anf.RuntimeArgument,
) -> Unit {
  self.entries.push((parameter, replacement))
}

///|
fn RuntimeSubstitution::overlay(
  self : RuntimeSubstitution,
  shadowing : RuntimeSubstitution,
) -> RuntimeSubstitution {
  let entries = shadowing.entries.copy()
  entries.append(self.entries)
  { entries, }
}

///|
fn RuntimeSubstitution::argument(
  self : RuntimeSubstitution,
  parameter : @anf.RuntimeEvidenceId,
) -> @anf.RuntimeArgument? {
  for entry in self.entries {
    let (candidate, replacement) = entry
    if candidate == parameter {
      return Some(replacement)
    }
  }
  None
}

///|
fn RuntimeSubstitution::apply_evidence(
  self : RuntimeSubstitution,
  evidence : @anf.RuntimeEvidence,
) -> @anf.RuntimeEvidence {
  @anf.instantiate_runtime_evidence(evidence, self.entries)
}

///|
fn RuntimeSubstitution::apply_argument(
  self : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
  argument : @anf.RuntimeArgument,
) -> @anf.RuntimeArgument raise PhysicalLoweringError {
  runtime_types.catalog.instantiate_argument(argument, self.entries) catch {
    error => raise runtime_instantiation_error(error)
  }
}

///|
fn RuntimeSubstitution::apply_type(
  self : RuntimeSubstitution,
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
) -> @anf.RuntimeType raise PhysicalLoweringError {
  runtime_types.catalog.instantiate_type(type_, self.entries) catch {
    error => raise runtime_instantiation_error(error)
  }
}

///|
fn runtime_instantiation_error(
  error : @anf.RuntimeTypeInstantiationError,
) -> PhysicalLoweringError {
  InvalidTypeApplication(
    detail="runtime type instantiation failed: \{Repr(error)}",
  )
}
