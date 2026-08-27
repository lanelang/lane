///|
fn FunctionLowerer::lower_nested_function(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
) -> LocalValue raise PhysicalLoweringError {
  self.lower_nested_function_with_type(
    function,
    self.image.anf_function_type(function),
  )
}

///|
fn FunctionLowerer::lower_nested_function_with_type(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
  function_type : @anf.RuntimeType,
) -> LocalValue raise PhysicalLoweringError {
  let function_type = self.substitutions.apply_type(
    self.image.runtime_types,
    function_type,
  )
  let capture_bindings = free_capture_bindings(function)
  let captured_parameters = self.captured_runtime_parameters(
    [function],
    [function_type],
    capture_bindings,
  )
  let (capture_plans, stored_layouts, capture_slots, members) = self.prepare_captures(
    capture_bindings, captured_parameters,
  )
  let environment_shape = self.image.environment_shape(
    stored_layouts.length(),
    members,
  )
  let function_id = self.image.plans.append(
      LiftedFunction(function=function.id, source=function.source),
      _ => {
        LiftedFunction({
          function,
          type_: function_type,
          substitutions: self.substitutions,
          captured_parameters,
          captures: capture_plans,
          environment_shape,
          recursive_functions: [],
          specialization_ancestry: self.image.active_specialization_ancestry.copy(),
        })
      },
    ).function
  match
    self.make_capture_environment(
      environment_shape, stored_layouts, capture_slots,
    ) {
    environment => RecursiveFunction(function_id, function_type, environment)
  }
}

///|
fn FunctionLowerer::lower_recursive_group(
  self : FunctionLowerer,
  bindings : Array[@anf.AnfRecursiveBinding],
  body : @anf.AnfExpr,
) -> LocalValue raise PhysicalLoweringError {
  let functions : Array[@anf.AnfFunction] = []
  let recursive_values : Array[@buslane.ValueId] = []
  let recursive_types : Array[@anf.RuntimeType] = []
  for binding in bindings {
    let function = match extract_top_atom_function(binding.rhs) {
      Some(function) => function
      None =>
        raise UnsupportedExpression(
          detail="local recursive bindings must contain functions",
        )
    }
    let type_ = match self.image.metadata.value_info(binding.id) {
      Some(info) => info.type_
      None => raise MissingValueMetadata(value=binding.id)
    }
    functions.push(function)
    recursive_values.push(binding.id)
    recursive_types.push(
      self.substitutions.apply_type(self.image.runtime_types, type_),
    )
  }
  let capture_bindings = []
  for function in functions {
    for capture in free_capture_bindings(function) {
      if !recursive_values_contain_capture(recursive_values, capture) &&
        !capture_bindings.contains(capture) {
        capture_bindings.push(capture)
      }
    }
  }
  let captured_parameters = self.captured_runtime_parameters(
    functions, recursive_types, capture_bindings,
  )
  let (capture_plans, stored_layouts, capture_slots, members) = self.prepare_captures(
    capture_bindings, captured_parameters,
  )
  let environment_shape = self.image.environment_shape(
    stored_layouts.length(),
    members,
  )
  let environment = self.make_capture_environment(
    environment_shape, stored_layouts, capture_slots,
  )
  let origins : Array[PhysicalFunctionOrigin] = []
  for function in functions {
    origins.push(
      LiftedRecursiveFunction(function=function.id, source=function.source),
    )
  }
  let recursive_functions : Array[RecursiveFunctionPlan] = []
  ignore(
    self.image.plans.append_group(origins, fn(function_ids) {
      for index, function_id in function_ids {
        recursive_functions.push({
          value: recursive_values[index],
          function: function_id,
          type_: recursive_types[index],
        })
      }
      fn(index) {
        LiftedFunction({
          function: functions[index],
          type_: recursive_types[index],
          substitutions: self.substitutions,
          captured_parameters,
          captures: capture_plans,
          environment_shape,
          recursive_functions,
          specialization_ancestry: self.image.active_specialization_ancestry.copy(),
        })
      }
    }),
  )
  let value_count = self.bindings.length()
  for recursive in recursive_functions {
    self.bindings.push({
      value: recursive.value,
      lowered: RecursiveFunction(
        recursive.function,
        recursive.type_,
        environment,
      ),
    })
  }
  let result = self.lower_expr(body)
  self.restore_bindings(value_count, self.temps.length())
  result
}

///|
fn recursive_values_contain_capture(
  recursive_values : Array[@buslane.ValueId],
  capture : CaptureBinding,
) -> Bool {
  guard capture is Value(value) else { return false }
  recursive_values.contains(value)
}

///|
fn FunctionLowerer::captured_runtime_parameters(
  self : FunctionLowerer,
  functions : Array[@anf.AnfFunction],
  function_types : Array[@anf.RuntimeType],
  bindings : Array[CaptureBinding],
) -> Array[@anf.RuntimeEvidenceParameter] raise PhysicalLoweringError {
  let types = function_types.copy()
  for binding in bindings {
    match self.capture_value(binding) {
      Slot(_, type_)
      | RecursiveFunction(_, type_, _)
      | EvidenceAppliedCallable(_, type_, _)
      | EvidenceAppliedFunction(_, type_, _, _) => types.push(type_)
      AdaptedCallable(adaptation)
      | EvidenceAppliedAdaptedCallable(adaptation, _) =>
        types.push(adaptation.contract.target_type)
      Global(_) | Unit | EvidenceApplied(_, _) => ()
    }
  }
  let parameters = free_runtime_type_parameters_in_types(self.image, types)
  for index, function in functions {
    let (bound, _, _) = function_type_parts(function_types[index])
    collect_free_runtime_evidence_in_expr(
      self.image,
      function.body,
      bound.map(parameter => parameter.id),
      parameters,
    )
  }
  parameters
}

///|
fn collect_free_runtime_evidence_in_expr(
  image : ImageLowerer,
  expression : @anf.AnfExpr,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match expression {
    Atom(atom) =>
      collect_free_runtime_evidence_in_atom(image, atom, bound, parameters)
    Let(binding, body) => {
      if binding is Temp(type_~, ..) {
        collect_free_runtime_type_parameters(image, type_, bound, parameters)
      }
      collect_free_runtime_evidence_in_rhs(
        image,
        binding.rhs(),
        bound,
        parameters,
      )
      collect_free_runtime_evidence_in_expr(image, body, bound, parameters)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_free_runtime_evidence_in_atom(
          image,
          binding.rhs,
          bound,
          parameters,
        )
      }
      collect_free_runtime_evidence_in_expr(image, body, bound, parameters)
    }
  }
}

///|
fn collect_free_runtime_evidence_in_rhs(
  image : ImageLowerer,
  rhs : @anf.AnfRhs,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match rhs {
    Atom(atom) =>
      collect_free_runtime_evidence_in_atom(image, atom, bound, parameters)
    ApplyEvidence(callee~, arguments~) => {
      collect_free_runtime_evidence_in_atom(image, callee, bound, parameters)
      for argument in arguments {
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
    }
    Call(callee~, arguments~) => {
      collect_free_runtime_evidence_in_atom(image, callee, bound, parameters)
      for argument in arguments {
        collect_free_runtime_evidence_in_atom(
          image, argument, bound, parameters,
        )
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments {
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
      for argument in construct.hidden_arguments {
        collect_free_runtime_evidence(
          image,
          argument.evidence,
          bound,
          parameters,
        )
      }
      for payload in construct.payloads {
        collect_free_runtime_evidence_in_atom(image, payload, bound, parameters)
      }
    }
    Match(match_) => {
      collect_free_runtime_evidence_in_atom(
        image,
        match_.scrutinee,
        bound,
        parameters,
      )
      for alternative in match_.alternatives {
        let nested = bound.copy()
        nested.append(
          alternative.evidence_binders.map(parameter => parameter.id),
        )
        collect_free_runtime_evidence_in_expr(
          image,
          alternative.body,
          nested,
          parameters,
        )
      }
    }
  }
}

///|
fn collect_free_runtime_evidence_in_atom(
  image : ImageLowerer,
  atom : @anf.AnfAtom,
  bound : Array[@anf.RuntimeEvidenceId],
  parameters : Array[@anf.RuntimeEvidenceParameter],
) -> Unit {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => ()
    Function(function) =>
      collect_free_runtime_evidence_in_expr(
        image,
        function.body,
        bound,
        parameters,
      )
    EvidenceLambda(parameters=binders, body~) => {
      let nested = bound.copy()
      nested.append(binders.map(parameter => parameter.id))
      collect_free_runtime_evidence_in_expr(image, body, nested, parameters)
    }
  }
}

///|
fn FunctionLowerer::prepare_captures(
  self : FunctionLowerer,
  bindings : Array[CaptureBinding],
  captured_parameters : Array[@anf.RuntimeEvidenceParameter],
) -> (
  Array[CapturePlan],
  Array[@vmcfg.ValueId],
  Array[@vmcfg.ValueId],
  Array[@physical.MemberSchema],
) raise PhysicalLoweringError {
  let capture_plans : Array[CapturePlan] = []
  let stored_layouts = []
  let capture_slots = []
  let members : Array[@physical.MemberSchema] = []
  for parameter in captured_parameters {
    let metadata = runtime_evidence_metadata(parameter)
    members.push({
      representation: metadata.representation,
      cleanup: metadata.cleanup,
      kind: metadata.kind,
      witness_ordinal: None,
    })
    capture_slots.push(self.find_witness(parameter.id))
  }
  for binding in bindings {
    let captured = self.capture_value(binding)
    match captured {
      Global(_) => ()
      Unit => capture_plans.push({ binding, type_: Unit, member_index: None, })
      _ => {
        guard self.materialize_local(captured) is Slot(slot, type_) else {
          abort("captured value was not materialized")
        }
        let (metadata, witness_ordinal) = if self.image.runtime_type(type_)
          is Erased(_) {
          let ordinal = stored_layouts.length()
          guard self.values[slot.value].erased_companion is Some(witness) else {
            raise InvalidTypeApplication(
              detail="erased capture is missing its layout evidence",
            )
          }
          stored_layouts.push(witness)
          (
            @vmcfg.ValueMetadata::{
              representation: I64,
              cleanup: OwnedErased,
              kind: ErasedValue,
              ownership: Owned,
              erased_companion: None,
            },
            Some(ordinal),
          )
        } else {
          (self.image.slot_metadata(type_), None)
        }
        let member_index = members.length()
        members.push({
          representation: metadata.representation,
          cleanup: metadata.cleanup,
          kind: metadata.kind,
          witness_ordinal,
        })
        capture_slots.push(slot)
        capture_plans.push({ binding, type_, member_index: Some(member_index), })
      }
    }
  }
  (capture_plans, stored_layouts, capture_slots, members)
}

///|
fn ImageLowerer::environment_shape(
  self : ImageLowerer,
  stored_witness_count : Int,
  members : Array[@physical.MemberSchema],
) -> @physical.ObjectShapeId? {
  if stored_witness_count == 0 && members.is_empty() {
    None
  } else {
    Some(
      self.intern_object_shape(
        @physical.Environment({ stored_witness_count, members, }),
      ),
    )
  }
}

///|
fn FunctionLowerer::make_capture_environment(
  self : FunctionLowerer,
  environment_shape : @physical.ObjectShapeId?,
  witnesses : Array[@vmcfg.ValueId],
  capture_slots : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId? {
  match environment_shape {
    None => None
    Some(shape) => {
      let layout = self.image.intern_layout(Environment(shape))
      let environment = self.fresh_metadata(environment_metadata(shape))
      self.emit(
        MakeEnv(environment, shape, Immediate(layout), witnesses, capture_slots),
      )
      Some(environment)
    }
  }
}

///|
fn FunctionLowerer::capture_value(
  self : FunctionLowerer,
  binding : CaptureBinding,
) -> LocalValue raise PhysicalLoweringError {
  match binding {
    Value(value) => self.find_value(value)
    Temp(temp) => self.find_temp(temp)
  }
}

///|
fn FunctionLowerer::bind_capture(
  self : FunctionLowerer,
  binding : CaptureBinding,
  value : LocalValue,
) -> Unit {
  match binding {
    Value(id) => self.bindings.push({ value: id, lowered: value, })
    Temp(temp) => self.temps.push({ temp, lowered: value, })
  }
}

///|
fn ImageLowerer::anf_function_type(
  self : ImageLowerer,
  function : @anf.AnfFunction,
) -> @anf.RuntimeType raise PhysicalLoweringError {
  let parameters = function.parameters.map(parameter => {
    match self.metadata.value_info(parameter) {
      Some(info) => info.type_
      None => raise MissingValueMetadata(value=parameter)
    }
  })
  Callable(parameters, function.result_type)
}

///|
