///|
priv struct CallableCatalogBuilder {
  metadata : RuntimeMetadata
  globals : Array[@buslane.ValueId]
  temp_types : Array[(AnfTempId, RuntimeType)]
  definitions : Array[AnfCallableDefinition]
}

///|
fn build_callable_catalog(program : AnfProgram) -> AnfCallableCatalog {
  let globals = []
  for term in program.terms {
    match term {
      Let(value, _) | External(value) => globals.push(value)
      LetRec(bindings) => globals.append(bindings.map(binding => binding.id))
    }
  }
  let temp_types = []
  for term in program.terms {
    match term {
      Let(_, expression) => collect_temp_types_expr(expression, temp_types)
      LetRec(bindings) =>
        for binding in bindings {
          collect_temp_types_atom(binding.rhs, temp_types)
        }
      External(_) => ()
    }
  }
  let builder : CallableCatalogBuilder = {
    metadata: program.metadata,
    globals,
    temp_types,
    definitions: [],
  }
  for term in program.terms {
    match term {
      Let(_, expression) =>
        builder.visit_expr(expression, None, [], [], None, [])
      LetRec(bindings) => builder.visit_recursive_group(bindings, None, [])
      External(_) => ()
    }
  }
  builder.complete_lexical_parameters()
  { definitions: builder.definitions, temp_types }
}

///|
fn CallableCatalogBuilder::complete_lexical_parameters(
  self : CallableCatalogBuilder,
) -> Unit {
  for definition in self.definitions {
    let free = []
    let bound = definition.parameters.map(parameter => parameter.id)
    collect_free_evidence_type(definition.type_, bound, free)
    for capture in definition.captures {
      match capture {
        Value(value) =>
          if self.metadata.value_info(value) is Some(info) {
            collect_free_evidence_type(info.type_, bound, free)
          }
        Temp(temp) =>
          for entry in self.temp_types {
            if entry.0 == temp {
              collect_free_evidence_type(entry.1, bound, free)
              break
            }
          }
      }
    }
    collect_free_evidence_expr(definition.function.body, bound, free)
    for id in free {
      guard !definition.lexical_parameters.any(parameter => parameter.id == id) else {
        continue
      }
      if self.metadata.evidence_parameter(id) is Some(parameter) {
        definition.lexical_parameters.push(parameter)
      }
    }
  }
  while true {
    let mut changed = false
    for child in self.definitions {
      guard child.owner is Some(owner_id) else { continue }
      guard find_callable_definition(self.definitions, owner_id) is Some(owner) else {
        continue
      }
      for parameter in child.lexical_parameters {
        if !owner.parameters.any(bound => bound.id == parameter.id) &&
          !owner.lexical_parameters.any(existing => existing.id == parameter.id) {
          owner.lexical_parameters.push(parameter)
          changed = true
        }
      }
    }
    if !changed {
      break
    }
  }
}

///|
fn find_callable_definition(
  definitions : Array[AnfCallableDefinition],
  function : AnfFunctionId,
) -> AnfCallableDefinition? {
  for definition in definitions {
    if definition.function.id == function {
      return Some(definition)
    }
  }
  None
}

///|
fn collect_free_evidence_type(
  type_ : RuntimeType,
  bound : Array[RuntimeEvidenceId],
  free : Array[RuntimeEvidenceId],
) -> Unit {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => ()
    Erased(_, evidence) => collect_free_evidence(evidence, bound, free)
    Data(_, arguments) =>
      for argument in arguments {
        collect_free_evidence(argument.evidence, bound, free)
      }
    Forall(parameters, body) =>
      collect_free_evidence_type(
        body,
        bound + parameters.map(parameter => parameter.id),
        free,
      )
    Callable(parameters, result) => {
      for parameter in parameters {
        collect_free_evidence_type(parameter, bound, free)
      }
      collect_free_evidence_type(result, bound, free)
    }
  }
}

///|
fn collect_free_evidence(
  evidence : RuntimeEvidence,
  bound : Array[RuntimeEvidenceId],
  free : Array[RuntimeEvidenceId],
) -> Unit {
  match evidence {
    Static(_) => ()
    Parameter(parameter) =>
      if !bound.contains(parameter) && !free.contains(parameter) {
        free.push(parameter)
      }
    Apply(callee, arguments) => {
      collect_free_evidence(callee, bound, free)
      for argument in arguments {
        collect_free_evidence(argument, bound, free)
      }
    }
    Lambda(parameters, body) =>
      collect_free_evidence(
        body,
        bound + parameters.map(parameter => parameter.id),
        free,
      )
  }
}

///|
fn collect_free_evidence_expr(
  expression : AnfExpr,
  bound : Array[RuntimeEvidenceId],
  free : Array[RuntimeEvidenceId],
) -> Unit {
  match expression {
    Atom(atom) => collect_free_evidence_atom(atom, bound, free)
    Let(binding, body) => {
      collect_free_evidence_rhs(binding.rhs(), bound, free)
      collect_free_evidence_expr(body, bound, free)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_free_evidence_atom(binding.rhs, bound, free)
      }
      collect_free_evidence_expr(body, bound, free)
    }
  }
}

///|
fn collect_free_evidence_rhs(
  rhs : AnfRhs,
  bound : Array[RuntimeEvidenceId],
  free : Array[RuntimeEvidenceId],
) -> Unit {
  match rhs {
    Atom(atom) => collect_free_evidence_atom(atom, bound, free)
    ApplyEvidence(callee~, arguments~) => {
      collect_free_evidence_atom(callee, bound, free)
      for argument in arguments {
        collect_free_evidence(argument.evidence, bound, free)
      }
    }
    Call(callee~, arguments~) => {
      collect_free_evidence_atom(callee, bound, free)
      for argument in arguments {
        collect_free_evidence_atom(argument, bound, free)
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments + construct.hidden_arguments {
        collect_free_evidence(argument.evidence, bound, free)
      }
      for payload in construct.payloads {
        collect_free_evidence_atom(payload, bound, free)
      }
    }
    Match(match_) => {
      collect_free_evidence_atom(match_.scrutinee, bound, free)
      collect_free_evidence_type(match_.result_type, bound, free)
      for alternative in match_.alternatives {
        collect_free_evidence_expr(
          alternative.body,
          bound + alternative.evidence_binders.map(parameter => parameter.id),
          free,
        )
      }
    }
  }
}

///|
fn collect_free_evidence_atom(
  atom : AnfAtom,
  bound : Array[RuntimeEvidenceId],
  free : Array[RuntimeEvidenceId],
) -> Unit {
  match atom {
    Function(function) => {
      collect_free_evidence_type(function.result_type, bound, free)
      collect_free_evidence_expr(function.body, bound, free)
    }
    EvidenceLambda(parameters~, body~) =>
      collect_free_evidence_expr(
        body,
        bound + parameters.map(parameter => parameter.id),
        free,
      )
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn collect_temp_types_expr(
  expression : AnfExpr,
  types : Array[(AnfTempId, RuntimeType)],
) -> Unit {
  match expression {
    Atom(atom) => collect_temp_types_atom(atom, types)
    Let(binding, body) => {
      match binding {
        Temp(temp~, type_~, ..) => types.push((temp, type_))
        Value(..) => ()
      }
      collect_temp_types_rhs(binding.rhs(), types)
      collect_temp_types_expr(body, types)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_temp_types_atom(binding.rhs, types)
      }
      collect_temp_types_expr(body, types)
    }
  }
}

///|
fn collect_temp_types_rhs(
  rhs : AnfRhs,
  types : Array[(AnfTempId, RuntimeType)],
) -> Unit {
  match rhs {
    Atom(atom) | ApplyEvidence(callee=atom, ..) =>
      collect_temp_types_atom(atom, types)
    Call(callee~, arguments~) => {
      collect_temp_types_atom(callee, types)
      for argument in arguments {
        collect_temp_types_atom(argument, types)
      }
    }
    Construct(construct) =>
      for payload in construct.payloads {
        collect_temp_types_atom(payload, types)
      }
    Match(match_) =>
      for alternative in match_.alternatives {
        collect_temp_types_expr(alternative.body, types)
      }
  }
}

///|
fn collect_temp_types_atom(
  atom : AnfAtom,
  types : Array[(AnfTempId, RuntimeType)],
) -> Unit {
  match atom {
    Function(function) => collect_temp_types_expr(function.body, types)
    EvidenceLambda(body~, ..) => collect_temp_types_expr(body, types)
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn CallableCatalogBuilder::visit_recursive_group(
  self : CallableCatalogBuilder,
  bindings : Array[AnfRecursiveBinding],
  owner : AnfFunctionId?,
  lexical_parameters : Array[RuntimeEvidenceParameter],
) -> Unit {
  let recursive_values = bindings.map(binding => binding.id)
  let mut recursive_group : AnfRecursiveGroupId? = None
  for binding in bindings {
    if first_function_id(binding.rhs) is Some(function) {
      recursive_group = Some({ value: function.value })
      break
    }
  }
  for binding in bindings {
    self.visit_atom(
      binding.rhs,
      owner,
      lexical_parameters,
      [],
      recursive_group,
      recursive_values,
    )
  }
}

///|
fn first_function_id(atom : AnfAtom) -> AnfFunctionId? {
  match atom {
    Function(function) => Some(function.id)
    EvidenceLambda(body~, ..) => first_function_id_in_expr(body)
    Literal(_) | Ref(_) | Temp(_) => None
  }
}

///|
fn first_function_id_in_expr(expression : AnfExpr) -> AnfFunctionId? {
  match expression {
    Atom(atom) => first_function_id(atom)
    Let(_, body) | LetRec(_, body) => first_function_id_in_expr(body)
  }
}

///|
fn CallableCatalogBuilder::visit_expr(
  self : CallableCatalogBuilder,
  expression : AnfExpr,
  owner : AnfFunctionId?,
  lexical_parameters : Array[RuntimeEvidenceParameter],
  pending_parameters : Array[RuntimeEvidenceParameter],
  recursive_group : AnfRecursiveGroupId?,
  recursive_values : Array[@buslane.ValueId],
) -> Unit {
  match expression {
    Atom(atom) =>
      self.visit_atom(
        atom, owner, lexical_parameters, pending_parameters, recursive_group, recursive_values,
      )
    Let(binding, body) => {
      self.visit_rhs(binding.rhs(), owner, lexical_parameters)
      self.visit_expr(
        body, owner, lexical_parameters, pending_parameters, recursive_group, recursive_values,
      )
    }
    LetRec(bindings, body) => {
      self.visit_recursive_group(bindings, owner, lexical_parameters)
      self.visit_expr(
        body, owner, lexical_parameters, pending_parameters, recursive_group, recursive_values,
      )
    }
  }
}

///|
fn CallableCatalogBuilder::visit_rhs(
  self : CallableCatalogBuilder,
  rhs : AnfRhs,
  owner : AnfFunctionId?,
  lexical_parameters : Array[RuntimeEvidenceParameter],
) -> Unit {
  match rhs {
    Atom(atom) | ApplyEvidence(callee=atom, ..) =>
      self.visit_atom(atom, owner, lexical_parameters, [], None, [])
    Call(callee~, arguments~) => {
      self.visit_atom(callee, owner, lexical_parameters, [], None, [])
      for argument in arguments {
        self.visit_atom(argument, owner, lexical_parameters, [], None, [])
      }
    }
    Construct(construct) =>
      for payload in construct.payloads {
        self.visit_atom(payload, owner, lexical_parameters, [], None, [])
      }
    Match(match_) => {
      self.visit_atom(match_.scrutinee, owner, lexical_parameters, [], None, [])
      for alternative in match_.alternatives {
        self.visit_expr(
          alternative.body,
          owner,
          lexical_parameters + alternative.evidence_binders,
          [],
          None,
          [],
        )
      }
    }
  }
}

///|
fn CallableCatalogBuilder::visit_atom(
  self : CallableCatalogBuilder,
  atom : AnfAtom,
  owner : AnfFunctionId?,
  lexical_parameters : Array[RuntimeEvidenceParameter],
  pending_parameters : Array[RuntimeEvidenceParameter],
  recursive_group : AnfRecursiveGroupId?,
  recursive_values : Array[@buslane.ValueId],
) -> Unit {
  match atom {
    Function(function) => {
      let parameter_types = function.parameters.map(parameter => {
        match self.metadata.value_info(parameter) {
          Some(info) => info.type_
          None => abort("Runtime ANF function parameter lacks metadata")
        }
      })
      let callable_type = RuntimeType::Callable(
        parameter_types,
        function.result_type,
      )
      let type_ = if pending_parameters.is_empty() {
        callable_type
      } else {
        Forall(pending_parameters, callable_type)
      }
      self.definitions.push({
        function,
        type_,
        parameters: pending_parameters,
        lexical_parameters,
        captures: function_captures(function, recursive_values + self.globals),
        owner,
        recursive_group,
      })
      self.visit_expr(
        function.body,
        Some(function.id),
        lexical_parameters + pending_parameters,
        [],
        None,
        [],
      )
    }
    EvidenceLambda(parameters~, body~) =>
      self.visit_expr(
        body,
        owner,
        lexical_parameters,
        pending_parameters + parameters,
        recursive_group,
        recursive_values,
      )
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn function_captures(
  function : AnfFunction,
  recursive_values : Array[@buslane.ValueId],
) -> Array[AnfCapture] {
  let captures = []
  collect_function_capture_expr(
    function.body,
    function.parameters + recursive_values,
    [],
    captures,
  )
  captures
}

///|
fn collect_function_capture_expr(
  expression : AnfExpr,
  bound_values : Array[@buslane.ValueId],
  bound_temps : Array[AnfTempId],
  captures : Array[AnfCapture],
) -> Unit {
  match expression {
    Atom(atom) =>
      collect_function_capture_atom(atom, bound_values, bound_temps, captures)
    Let(binding, body) => {
      collect_function_capture_rhs(
        binding.rhs(),
        bound_values,
        bound_temps,
        captures,
      )
      let next_values = bound_values.copy()
      let next_temps = bound_temps.copy()
      match binding {
        Value(id~, ..) => next_values.push(id)
        Temp(temp~, ..) => next_temps.push(temp)
      }
      collect_function_capture_expr(body, next_values, next_temps, captures)
    }
    LetRec(bindings, body) => {
      let next_values = bound_values + bindings.map(binding => binding.id)
      for binding in bindings {
        collect_function_capture_atom(
          binding.rhs,
          next_values,
          bound_temps,
          captures,
        )
      }
      collect_function_capture_expr(body, next_values, bound_temps, captures)
    }
  }
}

///|
fn collect_function_capture_rhs(
  rhs : AnfRhs,
  bound_values : Array[@buslane.ValueId],
  bound_temps : Array[AnfTempId],
  captures : Array[AnfCapture],
) -> Unit {
  match rhs {
    Atom(atom) | ApplyEvidence(callee=atom, ..) =>
      collect_function_capture_atom(atom, bound_values, bound_temps, captures)
    Call(callee~, arguments~) => {
      collect_function_capture_atom(callee, bound_values, bound_temps, captures)
      for argument in arguments {
        collect_function_capture_atom(
          argument, bound_values, bound_temps, captures,
        )
      }
    }
    Construct(construct) =>
      for payload in construct.payloads {
        collect_function_capture_atom(
          payload, bound_values, bound_temps, captures,
        )
      }
    Match(match_) => {
      collect_function_capture_atom(
        match_.scrutinee,
        bound_values,
        bound_temps,
        captures,
      )
      for alternative in match_.alternatives {
        collect_function_capture_expr(
          alternative.body,
          bound_values + [match_.binder] + alternative.value_binders,
          bound_temps,
          captures,
        )
      }
    }
  }
}

///|
fn collect_function_capture_atom(
  atom : AnfAtom,
  bound_values : Array[@buslane.ValueId],
  bound_temps : Array[AnfTempId],
  captures : Array[AnfCapture],
) -> Unit {
  match atom {
    Literal(_) => ()
    Ref(value) => {
      let capture = AnfCapture::Value(value)
      if !bound_values.contains(value) && !captures.contains(capture) {
        captures.push(capture)
      }
    }
    Temp(temp) => {
      let capture = AnfCapture::Temp(temp)
      if !bound_temps.contains(temp) && !captures.contains(capture) {
        captures.push(capture)
      }
    }
    Function(function) =>
      collect_function_capture_expr(
        function.body,
        bound_values + function.parameters,
        bound_temps,
        captures,
      )
    EvidenceLambda(body~, ..) =>
      collect_function_capture_expr(body, bound_values, bound_temps, captures)
  }
}
