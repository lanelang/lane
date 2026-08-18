///|
fn ImageLowerer::intern_string(
  self : ImageLowerer,
  value : String,
) -> @bytecode.ConstantId {
  let bytes = @utf8.encode(value)
  for index, existing in self.constants {
    if existing == bytes {
      return { value: index }
    }
  }
  let constant : @bytecode.ConstantId = { value: self.constants.length() }
  self.constants.push(bytes)
  constant
}

///|
fn ImageLowerer::intern_layout(
  self : ImageLowerer,
  recipe : @bytecode.LayoutRecipe,
) -> @bytecode.LayoutId {
  for index, existing in self.layouts {
    if existing == recipe {
      return { value: index + 1 }
    }
  }
  let layout : @bytecode.LayoutId = { value: self.layouts.length() + 1 }
  self.layouts.push(recipe)
  layout
}

///|
fn ImageLowerer::intern_object_shape(
  self : ImageLowerer,
  shape : @bytecode.ObjectShape,
) -> @bytecode.ObjectShapeId {
  for index, existing in self.object_shapes {
    if existing == shape {
      return { value: index }
    }
  }
  let id : @bytecode.ObjectShapeId = { value: self.object_shapes.length() }
  self.object_shapes.push(shape)
  ignore(
    self.intern_layout(
      match shape {
        Data(_) => Data(id)
        Environment(_) => Environment(id)
      },
    ),
  )
  id
}

///|
fn ImageLowerer::intern_data_family(
  self : ImageLowerer,
  owner : @buslane.TypeId,
  arguments : Array[@anf.RuntimeArgument],
) -> @bytecode.DataFamilyId {
  let specialized_arguments = if self.callable_instances.specializes_data_owner(
      owner,
    ) {
    let expressions = []
    for argument in arguments {
      guard runtime_type_expression_is_closed(
          self.runtime_types,
          argument.type_expression,
          [],
        ) &&
        runtime_evidence_is_closed(argument.evidence, []) else {
        expressions.clear()
        break
      }
      expressions.push(argument.type_expression)
    }
    if expressions.length() == arguments.length() {
      Some(expressions)
    } else {
      None
    }
  } else {
    None
  }
  let key : DataFamilyKey = { owner, arguments: specialized_arguments }
  for index, existing in self.data_families {
    if existing == key {
      return { value: index }
    }
  }
  let family : @bytecode.DataFamilyId = { value: self.data_families.length() }
  self.data_families.push(key)
  family
}

///|
fn runtime_evidence_is_closed(
  evidence : @anf.RuntimeEvidence,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match evidence {
    Static(_) => true
    Parameter(parameter) => bound.contains(parameter)
    Apply(callee, arguments) =>
      runtime_evidence_is_closed(callee, bound) &&
      arguments.all(argument => runtime_evidence_is_closed(argument, bound))
    Lambda(parameters, body) =>
      runtime_evidence_is_closed(
        body,
        bound + parameters.map(parameter => parameter.id),
      )
  }
}

///|
fn runtime_type_expression_is_closed(
  runtime_types : RuntimeTypeArena,
  expression : @anf.RuntimeTypeExpressionId,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match runtime_types.type_expression(expression) {
    Some(Static(type_)) => runtime_type_is_closed(runtime_types, type_, bound)
    Some(Parameter(parameter)) => bound.contains(parameter)
    Some(Apply(callee, arguments)) =>
      runtime_type_expression_is_closed(runtime_types, callee, bound) &&
      arguments.all(argument => {
        runtime_type_expression_is_closed(runtime_types, argument, bound)
      })
    Some(Lambda(parameters, body)) =>
      runtime_type_expression_is_closed(
        runtime_types,
        body,
        bound + parameters.map(parameter => parameter.id),
      )
    None => false
  }
}

///|
fn runtime_type_is_closed(
  runtime_types : RuntimeTypeArena,
  type_ : @anf.RuntimeType,
  bound : Array[@anf.RuntimeEvidenceId],
) -> Bool {
  match type_ {
    Unit | Scalar(_) | ByteSequence | OpaqueReference(_) => true
    Data(_, arguments) =>
      arguments.all(argument => {
        runtime_type_expression_is_closed(
          runtime_types,
          argument.type_expression,
          bound,
        ) &&
        runtime_evidence_is_closed(argument.evidence, bound)
      })
    Callable(parameters, result) =>
      parameters.all(parameter => {
        runtime_type_is_closed(runtime_types, parameter, bound)
      }) &&
      runtime_type_is_closed(runtime_types, result, bound)
    Erased(expression, evidence) =>
      runtime_type_expression_is_closed(runtime_types, expression, bound) &&
      runtime_evidence_is_closed(evidence, bound)
    Forall(parameters, body) =>
      runtime_type_is_closed(
        runtime_types,
        body,
        bound + parameters.map(parameter => parameter.id),
      )
  }
}

///|
