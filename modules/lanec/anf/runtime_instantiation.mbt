///|
/// A mutable working catalog for definitionally reducing Runtime ANF type
/// expressions. Runtime ANF metadata owns the source catalog; consumers may
/// derive expressions only through this type so runtime instantiation has one
/// semantic implementation.
pub(all) struct RuntimeTypeCatalog {
  expressions : Array[RuntimeTypeExpression]
}

///|
pub(all) suberror RuntimeTypeInstantiationError {
  MissingTypeExpression(RuntimeTypeExpressionId)
  TypeExpressionArityMismatch(expected~ : Int, actual~ : Int)
} derive(Debug, Eq)

///|
pub fn RuntimeMetadata::runtime_type_catalog(
  self : RuntimeMetadata,
) -> RuntimeTypeCatalog {
  {
    expressions: self.type_expressions.map(expression => expression.snapshot()),
  }
}

///|
pub fn RuntimeTypeCatalog::type_expression(
  self : RuntimeTypeCatalog,
  expression : RuntimeTypeExpressionId,
) -> RuntimeTypeExpression? {
  self.expressions.get(expression.index)
}

///|
pub fn RuntimeTypeCatalog::intern(
  self : RuntimeTypeCatalog,
  expression : RuntimeTypeExpression,
) -> RuntimeTypeExpressionId {
  for index, existing in self.expressions {
    if existing == expression {
      return { index, }
    }
  }
  let id : RuntimeTypeExpressionId = { index: self.expressions.length(), }
  self.expressions.push(expression)
  id
}

///|
pub fn RuntimeTypeCatalog::types_alpha_equivalent(
  self : RuntimeTypeCatalog,
  left : RuntimeType,
  right : RuntimeType,
) -> Bool {
  runtime_types_alpha_equal(
    left,
    right,
    expression => self.type_expression(expression),
    [],
    [],
  )
}

///|
pub fn RuntimeTypeCatalog::argument_is_consistent(
  self : RuntimeTypeCatalog,
  argument : RuntimeArgument,
) -> Bool raise RuntimeTypeInstantiationError {
  runtime_evidence_equal(
    self.expression_evidence(argument.type_expression),
    argument.evidence,
    [],
    [],
  )
}

///|
pub fn RuntimeTypeCatalog::instantiate_type(
  self : RuntimeTypeCatalog,
  type_ : RuntimeType,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
) -> RuntimeType raise RuntimeTypeInstantiationError {
  self.instantiate_type_with(type_, substitutions, [], [])
}

///|
pub fn RuntimeTypeCatalog::instantiate_argument(
  self : RuntimeTypeCatalog,
  argument : RuntimeArgument,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
) -> RuntimeArgument raise RuntimeTypeInstantiationError {
  self.instantiate_argument_with(argument, substitutions, [], [])
}

///|
pub fn instantiate_runtime_evidence(
  evidence : RuntimeEvidence,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
) -> RuntimeEvidence {
  instantiate_runtime_evidence_with(evidence, substitutions, [], [])
}

///|
fn RuntimeTypeCatalog::instantiate_argument_with(
  self : RuntimeTypeCatalog,
  argument : RuntimeArgument,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  bound : Array[RuntimeEvidenceId],
  visited : Array[RuntimeEvidenceId],
) -> RuntimeArgument raise RuntimeTypeInstantiationError {
  {
    type_expression: self.instantiate_type_expression(
      argument.type_expression,
      substitutions,
      bound,
      visited,
    ),
    evidence: instantiate_runtime_evidence_with(
      argument.evidence,
      substitutions,
      bound,
      visited,
    ),
  }
}

///|
fn RuntimeTypeCatalog::instantiate_type_expression(
  self : RuntimeTypeCatalog,
  expression : RuntimeTypeExpressionId,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  bound : Array[RuntimeEvidenceId],
  visited : Array[RuntimeEvidenceId],
) -> RuntimeTypeExpressionId raise RuntimeTypeInstantiationError {
  guard self.type_expression(expression) is Some(node) else {
    raise MissingTypeExpression(expression)
  }
  match node {
    Static(type_) =>
      self.intern(
        Static(self.instantiate_type_with(type_, substitutions, bound, visited)),
      )
    Parameter(parameter) => {
      if bound.contains(parameter) || visited.contains(parameter) {
        return expression
      }
      guard substitution_argument(substitutions, parameter) is Some(argument) else {
        return expression
      }
      let visited = visited.copy()
      visited.push(parameter)
      self.instantiate_type_expression(
        argument.type_expression,
        substitutions,
        bound,
        visited,
      )
    }
    Apply(callee, arguments) => {
      let callee = self.instantiate_type_expression(
        callee, substitutions, bound, visited,
      )
      let arguments = arguments.map(argument => {
        self.instantiate_type_expression(
          argument, substitutions, bound, visited,
        )
      })
      guard self.type_expression(callee) is Some(callee_node) else {
        raise MissingTypeExpression(callee)
      }
      match callee_node {
        Lambda(parameters, body) => {
          if parameters.length() != arguments.length() {
            raise TypeExpressionArityMismatch(
              expected=parameters.length(),
              actual=arguments.length(),
            )
          }
          let beta = []
          for index, parameter in parameters {
            beta.push(
              (
                parameter.id,
                {
                  type_expression: arguments[index],
                  evidence: self.expression_evidence(arguments[index]),
                },
              ),
            )
          }
          self.instantiate_type_expression(
            body,
            overlay_runtime_substitutions(substitutions, beta),
            bound,
            visited,
          )
        }
        _ => self.intern(Apply(callee, arguments))
      }
    }
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      self.intern(
        Lambda(
          parameters,
          self.instantiate_type_expression(body, substitutions, nested, visited),
        ),
      )
    }
  }
}

///|
fn RuntimeTypeCatalog::instantiate_type_with(
  self : RuntimeTypeCatalog,
  type_ : RuntimeType,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  bound : Array[RuntimeEvidenceId],
  visited : Array[RuntimeEvidenceId],
) -> RuntimeType raise RuntimeTypeInstantiationError {
  match type_ {
    Unit | Scalar(_) | ByteSequence => type_
    Data(owner, arguments) =>
      Data(
        owner,
        arguments.map(argument => {
          self.instantiate_argument_with(
            argument, substitutions, bound, visited,
          )
        }),
      )
    Callable(parameters, result) =>
      Callable(
        parameters.map(parameter => {
          self.instantiate_type_with(parameter, substitutions, bound, visited)
        }),
        self.instantiate_type_with(result, substitutions, bound, visited),
      )
    Erased(expression, evidence) => {
      let expression = self.instantiate_type_expression(
        expression, substitutions, bound, visited,
      )
      match self.evaluate_type_expression(expression, [], bound, []) {
        Some(type_) => type_
        None =>
          Erased(
            expression,
            instantiate_runtime_evidence_with(
              evidence, substitutions, bound, visited,
            ),
          )
      }
    }
    Forall(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Forall(
        parameters,
        self.instantiate_type_with(body, substitutions, nested, visited),
      )
    }
  }
}

///|
fn RuntimeTypeCatalog::evaluate_type_expression(
  self : RuntimeTypeCatalog,
  expression : RuntimeTypeExpressionId,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  bound : Array[RuntimeEvidenceId],
  visited : Array[RuntimeEvidenceId],
) -> RuntimeType? raise RuntimeTypeInstantiationError {
  guard self.type_expression(expression) is Some(node) else {
    raise MissingTypeExpression(expression)
  }
  match node {
    Static(type_) => Some(type_)
    Parameter(parameter) => {
      if bound.contains(parameter) || visited.contains(parameter) {
        return None
      }
      guard substitution_argument(substitutions, parameter) is Some(argument) else {
        return None
      }
      let visited = visited.copy()
      visited.push(parameter)
      self.evaluate_type_expression(
        argument.type_expression,
        substitutions,
        bound,
        visited,
      )
    }
    Apply(callee, arguments) => {
      guard self.type_expression(callee) is Some(callee_node) else {
        raise MissingTypeExpression(callee)
      }
      let callee_node = match callee_node {
        Parameter(parameter) => {
          guard substitution_argument(substitutions, parameter)
            is Some(argument) else {
            return None
          }
          guard self.type_expression(argument.type_expression) is Some(node) else {
            raise MissingTypeExpression(argument.type_expression)
          }
          node
        }
        node => node
      }
      guard callee_node is Lambda(parameters, body) else { return None }
      if parameters.length() != arguments.length() {
        raise TypeExpressionArityMismatch(
          expected=parameters.length(),
          actual=arguments.length(),
        )
      }
      let beta = []
      for index, parameter in parameters {
        beta.push(
          (
            parameter.id,
            {
              type_expression: arguments[index],
              evidence: self.expression_evidence(arguments[index]),
            },
          ),
        )
      }
      self.evaluate_type_expression(
        body,
        overlay_runtime_substitutions(substitutions, beta),
        bound,
        visited,
      )
    }
    Lambda(_, _) => None
  }
}

///|
fn RuntimeTypeCatalog::expression_evidence(
  self : RuntimeTypeCatalog,
  expression : RuntimeTypeExpressionId,
) -> RuntimeEvidence raise RuntimeTypeInstantiationError {
  match self.type_expression(expression) {
    Some(Static(type_)) =>
      match type_ {
        Erased(_, evidence) => evidence
        _ => Static(type_.layout().unwrap())
      }
    Some(Parameter(parameter)) => Parameter(parameter)
    Some(Apply(callee, arguments)) =>
      Apply(
        self.expression_evidence(callee),
        arguments.map(argument => self.expression_evidence(argument)),
      )
    Some(Lambda(parameters, body)) =>
      Lambda(parameters, self.expression_evidence(body))
    None => raise MissingTypeExpression(expression)
  }
}

///|
fn instantiate_runtime_evidence_with(
  evidence : RuntimeEvidence,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  bound : Array[RuntimeEvidenceId],
  visited : Array[RuntimeEvidenceId],
) -> RuntimeEvidence {
  match evidence {
    Static(_) => evidence
    Parameter(parameter) => {
      if bound.contains(parameter) || visited.contains(parameter) {
        return evidence
      }
      match substitution_argument(substitutions, parameter) {
        Some(replacement) => {
          let visited = visited.copy()
          visited.push(parameter)
          instantiate_runtime_evidence_with(
            replacement.evidence,
            substitutions,
            bound,
            visited,
          )
        }
        None => evidence
      }
    }
    Apply(callee, arguments) => {
      let callee = instantiate_runtime_evidence_with(
        callee, substitutions, bound, visited,
      )
      let arguments = arguments.map(argument => {
        instantiate_runtime_evidence_with(
          argument, substitutions, bound, visited,
        )
      })
      match callee {
        Lambda(parameters, body) => {
          let replacements = []
          for index in 0..<parameters.length().min(arguments.length()) {
            replacements.push((parameters[index].id, arguments[index]))
          }
          replace_runtime_evidence(body, replacements, [])
        }
        _ => Apply(callee, arguments)
      }
    }
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Lambda(
        parameters,
        instantiate_runtime_evidence_with(body, substitutions, nested, visited),
      )
    }
  }
}

///|
fn replace_runtime_evidence(
  evidence : RuntimeEvidence,
  replacements : Array[(RuntimeEvidenceId, RuntimeEvidence)],
  bound : Array[RuntimeEvidenceId],
) -> RuntimeEvidence {
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
        replace_runtime_evidence(callee, replacements, bound),
        arguments.map(argument => {
          replace_runtime_evidence(argument, replacements, bound)
        }),
      )
    Lambda(parameters, body) => {
      let nested = bound.copy()
      nested.append(parameters.map(parameter => parameter.id))
      Lambda(parameters, replace_runtime_evidence(body, replacements, nested))
    }
  }
}

///|
fn substitution_argument(
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  parameter : RuntimeEvidenceId,
) -> RuntimeArgument? {
  for entry in substitutions {
    let (candidate, replacement) = entry
    if candidate == parameter {
      return Some(replacement)
    }
  }
  None
}

///|
fn overlay_runtime_substitutions(
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  shadowing : Array[(RuntimeEvidenceId, RuntimeArgument)],
) -> Array[(RuntimeEvidenceId, RuntimeArgument)] {
  let entries = shadowing.copy()
  entries.append(substitutions)
  entries
}
