///|
priv struct RuntimeEffectBinding {
  operation : @buslane.OperationId
  value : @buslane.ValueId
}

///|
fn install_runtime_boundary(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  operations : Array[@module_link.LinkedRuntimeEffectOperation],
) -> (
  @buslane.Program,
  @buslane_lowering.BuslaneExternalMap,
  @buslane_lowering.BuslaneEntry,
  Array[@module_link.LinkedRuntimeEffectOperation],
) raise ExecutableElaborationError {
  guard entry.type_ is Function(parameters, result, effect) else {
    raise InvalidEntryFunction(value=entry.value, type_=entry.type_)
  }
  let effect = effect.canonicalize()
  let selected_effect_owners : Array[@buslane.EffectId] = []
  for term in root_effect_terms(effect) {
    if term is Singleton(owner, _) {
      selected_effect_owners.push(owner)
    }
  }
  let bindings : Array[RuntimeEffectBinding] = []
  let selected_operations : Array[@module_link.LinkedRuntimeEffectOperation] = []
  let terms = program.terms.copy()
  let builtins = externals.builtins.copy()
  for operation in operations {
    guard program.metadata.operation_info(operation.operation) is Some(info) else {
      continue
    }
    if !selected_effect_owners.any(owner => owner == info.owner) {
      continue
    }
    selected_operations.push(operation)
    if !info.hidden_type_parameters.is_empty() {
      raise UnsupportedRuntimeBoundary(
        detail="generic runtime effect operations are outside the v1 primitive host ABI",
      )
    }
    guard program.metadata.effect_info(info.owner) is Some(effect_info) else {
      raise UnsupportedRuntimeBoundary(
        detail="linked runtime effect metadata is missing",
      )
    }
    if !effect_info.parameters.is_empty() {
      raise UnsupportedRuntimeBoundary(
        detail="generic runtime effects are outside the v1 primitive host ABI",
      )
    }
    let type_ = @buslane.Type::Function(
      info.payload_types,
      info.result_type,
      Empty,
    )
    if !runtime_import_signature_supported(type_) {
      raise UnsupportedRuntimeBoundary(
        detail="runtime effect operations must use only v1 host primitive types",
      )
    }
    let value = program.metadata.define_value(
      "%runtime_effect_\{operation.operation.index}",
      External,
      type_,
    )
    bindings.push({ operation: operation.operation, value })
    terms.push(External(value))
    builtins.push({ value, name: runtime_effect_symbol(operation), type_ })
  }
  if effect == Empty {
    return (
      { metadata: program.metadata, terms },
      { builtins, },
      entry,
      selected_operations,
    )
  }
  let wrapper_parameters = parameters.map(type_ => {
    program.metadata.define_value("%entry_parameter", Parameter, type_)
  })
  let result_binder = program.metadata.define_value(
    "%entry_result",
    Local,
    result,
  )
  let wrapper_type = @buslane.Type::Function(parameters, result, Empty)
  let wrapper = program.metadata.define_value(
    "%runtime_entry",
    Function,
    wrapper_type,
  )
  let handlers = root_runtime_handler_tables(
    program.metadata,
    effect,
    result,
    bindings,
  )
  terms.push(
    Let(
      wrapper,
      Function({
        parameters: wrapper_parameters,
        result_type: result,
        body: Handle({
          body: Call(
            Ref(entry.value),
            wrapper_parameters.map(parameter => Ref(parameter)),
          ),
          result_binder,
          result_type: result,
          final_body: Ref(result_binder),
          handlers,
        }),
      }),
    ),
  )
  (
    { metadata: program.metadata, terms },
    { builtins, },
    { ..entry, value: wrapper, type_: wrapper_type },
    selected_operations,
  )
}

///|
fn root_runtime_handler_tables(
  metadata : @buslane.MetadataRegistry,
  effect : @buslane.Effect,
  handler_result : @buslane.Type,
  bindings : Array[RuntimeEffectBinding],
) -> Array[@buslane.HandlerTable] raise ExecutableElaborationError {
  root_effect_terms(effect).map(term => {
    guard term is Singleton(effect_id, arguments) else {
      raise UnsupportedRuntimeBoundary(
        detail="abstract entry effects cannot cross the v1 runtime boundary",
      )
    }
    if !arguments.is_empty() {
      raise UnsupportedRuntimeBoundary(
        detail="generic runtime effects are outside the v1 primitive host ABI",
      )
    }
    guard metadata.effect_info(effect_id) is Some(info) else {
      raise UnsupportedRuntimeBoundary(
        detail="linked runtime effect metadata is missing",
      )
    }
    {
      handled_effect: term,
      operations: info.operations.map(operation => {
        root_runtime_operation_clause(
          metadata, operation, handler_result, bindings,
        )
      }),
    }
  })
}

///|
fn root_runtime_operation_clause(
  metadata : @buslane.MetadataRegistry,
  operation : @buslane.OperationId,
  handler_result : @buslane.Type,
  bindings : Array[RuntimeEffectBinding],
) -> @buslane.OperationAlternative raise ExecutableElaborationError {
  let info = runtime_operation_info(metadata, operation)
  if !info.hidden_type_parameters.is_empty() {
    raise UnsupportedRuntimeBoundary(
      detail="generic runtime effect operations are outside the v1 primitive host ABI",
    )
  }
  let target = match find_runtime_effect_external(bindings, operation) {
    Some(value) => value
    None =>
      raise UnsupportedRuntimeBoundary(
        detail="non-runtime effects must be erased before VM CFG lowering",
      )
  }
  let payload_binders = info.payload_types.map(type_ => {
    metadata.define_value("%runtime_payload", Parameter, type_)
  })
  let resume_binder = metadata.define_value(
    "%runtime_resume",
    Parameter,
    Function([info.result_type], handler_result, Empty),
  )
  {
    operation,
    type_binders: [],
    payload_binders,
    resume_binder,
    body: Call(Resume(resume_binder), [
      Call(Ref(target), payload_binders.map(payload => Ref(payload))),
    ]),
  }
}

///|
fn runtime_operation_info(
  metadata : @buslane.MetadataRegistry,
  operation : @buslane.OperationId,
) -> @buslane.OperationInfo raise ExecutableElaborationError {
  match metadata.operation_info(operation) {
    Some(info) => info
    None =>
      raise UnsupportedRuntimeBoundary(
        detail="linked runtime effect operation metadata is missing",
      )
  }
}

///|
fn root_effect_terms(effect : @buslane.Effect) -> Array[@buslane.Effect] {
  match effect.canonicalize() {
    Empty => []
    Union(effects) => effects
    effect => [effect]
  }
}

///|
fn runtime_effect_symbol(
  operation : @module_link.LinkedRuntimeEffectOperation,
) -> String {
  "lane.effect.v1/\{operation.module_path_text}/\{operation.effect_name}/\{operation.operation_name}"
}

///|
fn find_runtime_effect_external(
  bindings : Array[RuntimeEffectBinding],
  operation : @buslane.OperationId,
) -> @buslane.ValueId? {
  for binding in bindings {
    if binding.operation == operation {
      return Some(binding.value)
    }
  }
  None
}

///|
fn runtime_import_signature_supported(type_ : @buslane.Type) -> Bool {
  guard type_ is Function(parameters, result, _) else { return false }
  parameters.all(runtime_import_primitive_type) &&
  runtime_import_primitive_type(result)
}

///|
fn runtime_import_primitive_type(type_ : @buslane.Type) -> Bool {
  type_ is Primitive(Unit) ||
  type_ is Primitive(Bool) ||
  type_ is Primitive(Int) ||
  type_ is Primitive(Double) ||
  type_ is Primitive(String)
}
