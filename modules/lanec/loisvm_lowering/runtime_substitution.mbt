///|
fn RuntimeSubstitution::new() -> RuntimeSubstitution {
  { entries: [] }
}

///|
fn RuntimeSubstitution::from_arguments(
  parameters : Array[@anf.RuntimeEvidenceParameter],
  arguments : Array[@anf.RuntimeArgument],
) -> RuntimeSubstitution raise LoisvmLoweringError {
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
) -> @anf.RuntimeEvidence raise LoisvmLoweringError {
  self.apply_evidence_with(evidence, [], [])
}

///|
fn RuntimeSubstitution::apply_argument(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  argument : @anf.RuntimeArgument,
) -> @anf.RuntimeArgument raise LoisvmLoweringError {
  self.apply_argument_with(metadata, argument, [], [])
}

///|
fn RuntimeSubstitution::apply_argument_with(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  argument : @anf.RuntimeArgument,
  bound : Array[@anf.RuntimeEvidenceId],
  visited : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeArgument raise LoisvmLoweringError {
  {
    type_expression: self.apply_type_expression(
      metadata,
      argument.type_expression,
      bound,
      visited,
    ),
    evidence: self.apply_evidence_with(argument.evidence, bound, visited),
  }
}

///|
fn RuntimeSubstitution::apply_type_expression(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  expression : @anf.RuntimeTypeExpressionId,
  bound : Array[@anf.RuntimeEvidenceId],
  visited : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeTypeExpressionId raise LoisvmLoweringError {
  guard metadata.type_expression(expression) is Some(node) else {
    raise InvalidTypeApplication(
      detail="runtime type expression \{expression.index} is missing",
    )
  }
  match node {
    Static(type_) =>
      metadata.intern_type_expression(
        Static(self.apply_type_with(metadata, type_, bound, visited)),
      )
    Parameter(parameter) => {
      if bound.contains(parameter) || visited.contains(parameter) {
        return expression
      }
      guard self.argument(parameter) is Some(argument) else {
        return expression
      }
      let visited = visited.copy()
      visited.push(parameter)
      self.apply_type_expression(
        metadata,
        argument.type_expression,
        bound,
        visited,
      )
    }
    Apply(callee, arguments) => {
      let callee = self.apply_type_expression(metadata, callee, bound, visited)
      let arguments = arguments.map(argument => {
        self.apply_type_expression(metadata, argument, bound, visited)
      })
      guard metadata.type_expression(callee) is Some(callee_node) else {
        raise InvalidTypeApplication(detail="runtime type callee is missing")
      }
      match callee_node {
        Lambda(parameters, body) => {
          if parameters.length() != arguments.length() {
            raise InvalidTypeApplication(
              detail="runtime type constructor expects \{parameters.length()} arguments, got \{arguments.length()}",
            )
          }
          let beta = RuntimeSubstitution::new()
          for index, parameter in parameters {
            beta.insert(parameter.id, {
              type_expression: arguments[index],
              evidence: runtime_expression_evidence(metadata, arguments[index]),
            })
          }
          self
          .overlay(beta)
          .apply_type_expression(metadata, body, bound, visited)
        }
        _ => metadata.intern_type_expression(Apply(callee, arguments))
      }
    }
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      metadata.intern_type_expression(
        Lambda(
          parameters,
          self.apply_type_expression(metadata, body, nested, visited),
        ),
      )
    }
  }
}

///|
fn RuntimeSubstitution::argument_type(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  argument : @anf.RuntimeArgument,
) -> @anf.RuntimeType? raise LoisvmLoweringError {
  self.evaluate_type_expression(metadata, argument.type_expression, [], [])
}

///|
fn RuntimeSubstitution::apply_evidence_with(
  self : RuntimeSubstitution,
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
  visited : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeEvidence raise LoisvmLoweringError {
  match evidence {
    Static(_) => evidence
    Parameter(parameter) => {
      if bound.contains(parameter) || visited.contains(parameter) {
        return evidence
      }
      match self.argument(parameter) {
        Some(replacement) => {
          let visited = visited.copy()
          visited.push(parameter)
          self.apply_evidence_with(replacement.evidence, bound, visited)
        }
        None => evidence
      }
    }
    Apply(callee, arguments) => {
      let callee = self.apply_evidence_with(callee, bound, visited)
      let arguments = arguments.map(argument => {
        self.apply_evidence_with(argument, bound, visited)
      })
      match callee {
        Lambda(parameters, body) => {
          let replacements = []
          for index in 0..<parameters.length().min(arguments.length()) {
            replacements.push((parameters[index].id, arguments[index]))
          }
          apply_evidence_replacements(body, replacements, [])
        }
        _ => Apply(callee, arguments)
      }
    }
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Lambda(parameters, self.apply_evidence_with(body, nested, visited))
    }
  }
}

///|
fn apply_evidence_replacements(
  evidence : @anf.RuntimeEvidence,
  replacements : Array[(@anf.RuntimeEvidenceId, @anf.RuntimeEvidence)],
  bound : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeEvidence {
  match evidence {
    Static(_) => evidence
    Parameter(parameter) => {
      if bound.contains(parameter) {
        return evidence
      }
      for entry in replacements {
        let (candidate, replacement) = entry
        if candidate == parameter {
          return replacement
        }
      }
      evidence
    }
    Apply(callee, arguments) =>
      Apply(
        apply_evidence_replacements(callee, replacements, bound),
        arguments.map(argument => {
          apply_evidence_replacements(argument, replacements, bound)
        }),
      )
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Lambda(
        parameters,
        apply_evidence_replacements(body, replacements, nested),
      )
    }
  }
}

///|
fn RuntimeSubstitution::apply_type(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  type_ : @anf.RuntimeType,
) -> @anf.RuntimeType raise LoisvmLoweringError {
  self.apply_type_with(metadata, type_, [], [])
}

///|
fn RuntimeSubstitution::apply_type_with(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
  visited : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeType raise LoisvmLoweringError {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => type_
    Data(owner, arguments) =>
      Data(
        owner,
        arguments.map(argument => {
          self.apply_argument_with(metadata, argument, bound, visited)
        }),
      )
    Callable(parameters, result) =>
      Callable(
        parameters.map(parameter => {
          self.apply_type_with(metadata, parameter, bound, visited)
        }),
        self.apply_type_with(metadata, result, bound, visited),
      )
    Erased(expression, evidence) => {
      let expression = self.apply_type_expression(
        metadata, expression, bound, visited,
      )
      match
        RuntimeSubstitution::new().evaluate_type_expression(
          metadata,
          expression,
          bound,
          [],
        ) {
        Some(type_) => type_
        None =>
          Erased(expression, self.apply_evidence_with(evidence, bound, visited))
      }
    }
    Forall(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Forall(parameters, self.apply_type_with(metadata, body, nested, visited))
    }
  }
}

///|
fn RuntimeSubstitution::evaluate_type_expression(
  self : RuntimeSubstitution,
  metadata : @anf.RuntimeMetadata,
  expression : @anf.RuntimeTypeExpressionId,
  bound : Array[@anf.RuntimeEvidenceId],
  visited : Array[@anf.RuntimeEvidenceId],
) -> @anf.RuntimeType? raise LoisvmLoweringError {
  guard metadata.type_expression(expression) is Some(node) else {
    raise InvalidTypeApplication(
      detail="runtime type expression \{expression.index} is missing",
    )
  }
  match node {
    Static(type_) => Some(type_)
    Parameter(parameter) => {
      if bound.contains(parameter) || visited.contains(parameter) {
        return None
      }
      guard self.argument(parameter) is Some(argument) else { return None }
      let visited = visited.copy()
      visited.push(parameter)
      self.evaluate_type_expression(
        metadata,
        argument.type_expression,
        bound,
        visited,
      )
    }
    Apply(callee, arguments) => {
      guard metadata.type_expression(callee) is Some(callee_node) else {
        raise InvalidTypeApplication(detail="runtime type callee is missing")
      }
      let callee_node = match callee_node {
        Parameter(parameter) => {
          guard self.argument(parameter) is Some(argument) else { return None }
          guard metadata.type_expression(argument.type_expression) is Some(node) else {
            raise InvalidTypeApplication(
              detail="runtime type constructor argument is missing",
            )
          }
          node
        }
        node => node
      }
      guard callee_node is Lambda(parameters, body) else { return None }
      if parameters.length() != arguments.length() {
        raise InvalidTypeApplication(
          detail="runtime type constructor expects \{parameters.length()} arguments, got \{arguments.length()}",
        )
      }
      let beta = RuntimeSubstitution::new()
      for index, parameter in parameters {
        beta.insert(parameter.id, {
          type_expression: arguments[index],
          evidence: runtime_expression_evidence(metadata, arguments[index]),
        })
      }
      self
      .overlay(beta)
      .evaluate_type_expression(metadata, body, bound, visited)
    }
    Lambda(_, _) => None
  }
}

///|
fn runtime_expression_evidence(
  metadata : @anf.RuntimeMetadata,
  expression : @anf.RuntimeTypeExpressionId,
) -> @anf.RuntimeEvidence raise LoisvmLoweringError {
  match metadata.type_expression(expression) {
    Some(Static(type_)) =>
      match type_ {
        Erased(_, evidence) => evidence
        _ => Static(type_.layout().unwrap())
      }
    Some(Parameter(parameter)) => Parameter(parameter)
    Some(Apply(callee, arguments)) =>
      Apply(
        runtime_expression_evidence(metadata, callee),
        arguments.map(argument => {
          runtime_expression_evidence(metadata, argument)
        }),
      )
    Some(Lambda(parameters, body)) =>
      Lambda(parameters, runtime_expression_evidence(metadata, body))
    None =>
      raise InvalidTypeApplication(detail="runtime type expression is missing")
  }
}
