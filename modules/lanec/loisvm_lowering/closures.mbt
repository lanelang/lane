///|
fn FunctionLowerer::lower_nested_function(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
) -> LocalValue raise LoisvmLoweringError {
  self.lower_nested_function_with_type(
    function,
    self.image.anf_function_type(function),
  )
}

///|
fn FunctionLowerer::lower_nested_function_with_type(
  self : FunctionLowerer,
  function : @anf.AnfFunction,
  function_type : @buslane.Type,
) -> LocalValue raise LoisvmLoweringError {
  let capture_bindings = free_capture_bindings(function)
  let captured_parameters = self.captured_runtime_parameters(
    [function_type],
    capture_bindings,
  )
  let (capture_plans, capture_slots, members) = self.prepare_captures(
    capture_bindings, captured_parameters,
  )
  let environment_shape = self.image.environment_shape(
    captured_parameters.length(),
    members,
  )
  let function_id : @bytecode.FunctionId = {
    value: self.image.plans.length() + 1,
  }
  self.image.plans.push(
    LiftedFunction({
      function,
      type_: function_type,
      captured_parameters,
      captures: capture_plans,
      environment_shape,
      recursive_functions: [],
    }),
  )
  let captured_witnesses = captured_parameters.map(parameter => {
    self.find_witness(parameter)
  })
  match
    self.make_capture_environment(
      environment_shape, captured_witnesses, capture_slots,
    ) {
    None => {
      let destination = self.fresh_slot(function_type)
      self.emit(ConstFunction(destination, function_id))
      Slot(destination, function_type)
    }
    Some(environment) => {
      let destination = self.fresh_slot(function_type)
      self.emit(MakeClosure(destination, function_id, environment))
      Slot(destination, function_type)
    }
  }
}

///|
fn FunctionLowerer::lower_recursive_group(
  self : FunctionLowerer,
  bindings : Array[@anf.AnfRecursiveBinding],
  body : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  let functions : Array[@anf.AnfFunction] = []
  let recursive_functions : Array[RecursiveFunctionPlan] = []
  let first_function_id = self.image.plans.length() + 1
  for index, binding in bindings {
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
    recursive_functions.push({
      value: binding.id,
      function: { value: first_function_id + index },
      type_,
    })
  }
  let capture_bindings = []
  for function in functions {
    for capture in free_capture_bindings(function) {
      if !recursive_functions_contain_capture(recursive_functions, capture) &&
        !capture_bindings.contains(capture) {
        capture_bindings.push(capture)
      }
    }
  }
  let captured_parameters = self.captured_runtime_parameters(
    recursive_functions.map(recursive => recursive.type_),
    capture_bindings,
  )
  let (capture_plans, capture_slots, members) = self.prepare_captures(
    capture_bindings, captured_parameters,
  )
  let environment_shape = self.image.environment_shape(
    captured_parameters.length(),
    members,
  )
  let captured_witnesses = captured_parameters.map(parameter => {
    self.find_witness(parameter)
  })
  let environment = self.make_capture_environment(
    environment_shape, captured_witnesses, capture_slots,
  )
  for index, function in functions {
    self.image.plans.push(
      LiftedFunction({
        function,
        type_: recursive_functions[index].type_,
        captured_parameters,
        captures: capture_plans,
        environment_shape,
        recursive_functions,
      }),
    )
  }
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
fn recursive_functions_contain_capture(
  recursive_functions : Array[RecursiveFunctionPlan],
  capture : CaptureBinding,
) -> Bool {
  guard capture is Value(value) else { return false }
  recursive_functions.any(recursive => recursive.value == value)
}

///|
fn FunctionLowerer::captured_runtime_parameters(
  self : FunctionLowerer,
  function_types : Array[@buslane.Type],
  bindings : Array[CaptureBinding],
) -> Array[@buslane.TypeParameterId] raise LoisvmLoweringError {
  let types = function_types.copy()
  for binding in bindings {
    match self.capture_value(binding) {
      Slot(_, type_)
      | RecursiveFunction(_, type_, _)
      | TypeAppliedCallable(_, type_, _) => types.push(type_)
      Global(_) | Unit | TypeApplied(_, _) => ()
    }
  }
  free_runtime_type_parameters_in_types(self.image, types)
}

///|
fn FunctionLowerer::prepare_captures(
  self : FunctionLowerer,
  bindings : Array[CaptureBinding],
  captured_parameters : Array[@buslane.TypeParameterId],
) -> (Array[CapturePlan], Array[@vmcfg.ValueId], Array[@bytecode.MemberSchema]) raise LoisvmLoweringError {
  let capture_plans : Array[CapturePlan] = []
  let capture_slots = []
  let members : Array[@bytecode.MemberSchema] = []
  for binding in bindings {
    let captured = self.capture_value(binding)
    match captured {
      Global(_) => ()
      Unit =>
        capture_plans.push({
          binding,
          type_: Primitive(Unit),
          member_index: None,
        })
      _ => {
        guard self.materialize_local(captured) is Slot(slot, type_) else {
          abort("captured value was not materialized")
        }
        let (metadata, witness_ordinal) = if type_ is Parameter(parameter) {
          let ordinal = type_parameter_ordinal(captured_parameters, parameter)
          guard ordinal is Some(_) else {
            raise InvalidTypeApplication(
              detail="generic capture is missing its layout witness",
            )
          }
          (
            @vmcfg.ValueMetadata::{
              representation: I64,
              cleanup: OwnedErased,
              ownership: Owned,
              erased_companion: None,
            },
            ordinal,
          )
        } else {
          (slot_metadata(type_), None)
        }
        let member_index = members.length()
        members.push({
          representation: metadata.representation,
          cleanup: metadata.cleanup,
          witness_ordinal,
        })
        capture_slots.push(slot)
        capture_plans.push({ binding, type_, member_index: Some(member_index) })
      }
    }
  }
  (capture_plans, capture_slots, members)
}

///|
fn ImageLowerer::environment_shape(
  self : ImageLowerer,
  stored_witness_count : Int,
  members : Array[@bytecode.MemberSchema],
) -> @bytecode.ObjectShapeId? {
  if stored_witness_count == 0 && members.is_empty() {
    None
  } else {
    Some(
      self.intern_object_shape(Environment({ stored_witness_count, members })),
    )
  }
}

///|
fn FunctionLowerer::make_capture_environment(
  self : FunctionLowerer,
  environment_shape : @bytecode.ObjectShapeId?,
  witnesses : Array[@vmcfg.ValueId],
  capture_slots : Array[@vmcfg.ValueId],
) -> @vmcfg.ValueId? {
  match environment_shape {
    None => None
    Some(shape) => {
      let layout = self.image.intern_layout(Environment(shape))
      let environment = self.fresh_metadata(environment_metadata())
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
) -> LocalValue raise LoisvmLoweringError {
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
    Value(id) => self.bindings.push({ value: id, lowered: value })
    Temp(temp) => self.temps.push({ temp, lowered: value })
  }
}

///|
fn ImageLowerer::anf_function_type(
  self : ImageLowerer,
  function : @anf.AnfFunction,
) -> @buslane.Type raise LoisvmLoweringError {
  let parameters = function.parameters.map(parameter => {
    match self.metadata.value_info(parameter) {
      Some(info) => info.type_
      None => raise MissingValueMetadata(value=parameter)
    }
  })
  Function(parameters, function.result_type, Empty)
}

///|
