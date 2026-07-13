///|
priv struct ImageLowerer {
  metadata : @buslane.MetadataRegistry
  externals : @buslane_lowering.BuslaneExternalMap
  globals : Array[GlobalBinding]
  plans : Array[PlannedEntry]
  constants : Array[Bytes]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  intrinsic_wrappers : Array[IntrinsicWrapperPlan]
  callable_adapters : Array[CallableAdapterPlan]
  mut next_synthetic_parameter : Int
}

///|
priv struct FunctionLowerer {
  image : ImageLowerer
  values : Array[@vmcfg.ValueMetadata]
  blocks : Array[LowerBlock]
  mut current_block : Int
  bindings : Array[ValueBinding]
  temps : Array[TempBinding]
  mut environment : @vmcfg.ValueId?
  witnesses : Array[WitnessBinding]
}

///|
pub fn lower_linked_program_to_bytecode(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  lower_linked_program_to_bytecode_with_runtime_effects(
    program,
    externals,
    entry,
    [],
  )
}

///|
pub fn lower_linked_program_to_bytecode_with_runtime_effects(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  runtime_effect_operations : Array[@artifact_core.LinkedRuntimeEffectOperation],
) -> Result[@bytecode.BytecodeImage, LoisvmLoweringError] {
  Ok(
    lower_linked_program_to_bytecode_or_raise(
      program, externals, entry, runtime_effect_operations,
    ),
  ) catch {
    error => Err(error)
  }
}

///|
fn lower_linked_program_to_bytecode_or_raise(
  program : @buslane.Program,
  externals : @buslane_lowering.BuslaneExternalMap,
  entry : @buslane_lowering.BuslaneEntry,
  runtime_effect_operations : Array[@artifact_core.LinkedRuntimeEffectOperation],
) -> @bytecode.BytecodeImage raise LoisvmLoweringError {
  let (program, externals, entry) = lower_effects_before_anf(
    program, externals, entry, runtime_effect_operations,
  )
  let anf = @anf.lower_buslane_program_to_anf(program)
  let lowerer : ImageLowerer = {
    metadata: program.metadata,
    externals,
    globals: [],
    plans: [],
    constants: [],
    layouts: [],
    object_shapes: [],
    intrinsic_wrappers: [],
    callable_adapters: [],
    next_synthetic_parameter: -1,
  }
  lowerer.plan(anf)
  let entry_function = match lowerer.find_global(entry.value) {
    Some(Function(function, _)) => function
    _ => raise MissingEntry(value=entry.value)
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  let mut plan_index = 0
  while plan_index < lowerer.plans.length() {
    let plan = lowerer.plans[plan_index]
    match plan {
      Function(value, function) =>
        functions.push(Body(lowerer.lower_function(value, function)))
      LiftedFunction(plan) =>
        functions.push(Body(lowerer.lower_lifted_function(plan)))
      IntrinsicWrapper(plan) =>
        functions.push(Body(lowerer.lower_intrinsic_wrapper(plan)))
      CallableAdapter(plan) =>
        functions.push(Body(lowerer.lower_callable_adapter(plan)))
      RuntimeImport(value, external) => {
        let (parameters, _) = lowerer.function_signature(value, external.type_)
        functions.push(
          RuntimeImport({
            abi_major: 1,
            user_arity: parameters.length(),
            symbol: external.name,
          }),
        )
      }
    }
    plan_index += 1
  }
  let virtual_image = canonicalize_function_table({
    entry: entry_function,
    functions,
    layouts: lowerer.layouts,
    object_shapes: lowerer.object_shapes,
    constants: lowerer.constants,
  })
  match @vmcfg.finalize(virtual_image) {
    Ok(image) => image
    Err(error) => raise VmcfgFinalizeError(error)
  }
}

///|
fn canonicalize_function_table(image : @vmcfg.Image) -> @vmcfg.Image {
  let mappings : Array[@bytecode.FunctionId?] = Array::make(
    image.functions.length(),
    None,
  )
  let bodies : Array[@vmcfg.FunctionBody] = []
  let imports : Array[CanonicalRuntimeImport] = []
  for index, entry in image.functions {
    let old_id : @bytecode.FunctionId = { value: index + 1 }
    match entry {
      Body(body) => {
        let new_id : @bytecode.FunctionId = { value: bodies.length() + 1 }
        mappings[index] = Some(new_id)
        bodies.push(body)
      }
      RuntimeImport(descriptor) => {
        let mut found = false
        for import_ in imports {
          if import_.descriptor == descriptor {
            import_.old_ids.push(old_id)
            found = true
          }
        }
        if !found {
          imports.push({ descriptor, old_ids: [old_id] })
        }
      }
    }
  }
  imports.sort_by(fn(left, right) {
    let symbol_order = String::compare(
      left.descriptor.symbol,
      right.descriptor.symbol,
    )
    if symbol_order != 0 {
      symbol_order
    } else {
      let abi_order = left.descriptor.abi_major - right.descriptor.abi_major
      if abi_order != 0 {
        abi_order
      } else {
        left.descriptor.user_arity - right.descriptor.user_arity
      }
    }
  })
  for index, import_ in imports {
    let new_id : @bytecode.FunctionId = { value: bodies.length() + index + 1 }
    for old_id in import_.old_ids {
      mappings[old_id.value - 1] = Some(new_id)
    }
  }
  let functions : Array[@vmcfg.FunctionEntry] = []
  for body in bodies {
    functions.push(Body(remap_function_body(body, mappings)))
  }
  for import_ in imports {
    functions.push(RuntimeImport(import_.descriptor))
  }
  { ..image, entry: remap_function_id(image.entry, mappings), functions }
}

///|
fn remap_function_body(
  body : @vmcfg.FunctionBody,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.FunctionBody {
  {
    ..body,
    blocks: body.blocks.map(block => {
      ..block,
      instructions: block.instructions.map(instruction => {
        remap_instruction_function_ids(instruction, mappings)
      }),
      terminator: remap_terminator_function_ids(block.terminator, mappings),
    }),
  }
}

///|
fn remap_instruction_function_ids(
  instruction : @vmcfg.Instruction,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.Instruction {
  match instruction {
    ConstFunction(destination, function) =>
      ConstFunction(destination, remap_function_id(function, mappings))
    CallDirect(function, environment, witnesses, arguments, destination) =>
      CallDirect(
        remap_function_id(function, mappings),
        environment,
        witnesses,
        arguments,
        destination,
      )
    MakeClosure(destination, function, environment) =>
      MakeClosure(
        destination,
        remap_function_id(function, mappings),
        environment,
      )
    _ => instruction
  }
}

///|
fn remap_terminator_function_ids(
  terminator : @vmcfg.Terminator,
  mappings : Array[@bytecode.FunctionId?],
) -> @vmcfg.Terminator {
  match terminator {
    TailCallDirect(function, environment, witnesses, arguments) =>
      TailCallDirect(
        remap_function_id(function, mappings),
        environment,
        witnesses,
        arguments,
      )
    _ => terminator
  }
}

///|
fn remap_function_id(
  function : @bytecode.FunctionId,
  mappings : Array[@bytecode.FunctionId?],
) -> @bytecode.FunctionId {
  match mappings[function.value - 1] {
    Some(mapped) => mapped
    None => abort("missing canonical FunctionId mapping")
  }
}

///|
fn ImageLowerer::plan(
  self : ImageLowerer,
  program : @anf.AnfProgram,
) -> Unit raise LoisvmLoweringError {
  for term in program.terms {
    match term {
      External(value) => self.plan_external(value)
      Let(value, expression) =>
        match extract_top_function(expression) {
          Some(function) => self.add_plan(value, Function(value, function))
          None => raise UnsupportedTopLevel(value~)
        }
      LetRec(bindings) =>
        for binding in bindings {
          match extract_top_atom_function(binding.rhs) {
            Some(function) =>
              self.add_plan(binding.id, Function(binding.id, function))
            None => raise UnsupportedTopLevel(value=binding.id)
          }
        }
    }
  }
}

///|
fn ImageLowerer::plan_external(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> Unit raise LoisvmLoweringError {
  let external = match self.find_external(value) {
    Some(external) => external
    None => raise MissingExternal(value~)
  }
  if is_scalar_intrinsic(external.name) {
    self.globals.push({
      value,
      lowered: Intrinsic(external.name, external.type_),
    })
  } else if scalar_double_constant(external.name) is Some(bits) {
    self.globals.push({ value, lowered: DoubleConstant(bits, external.type_) })
  } else {
    if !runtime_import_signature_supported(external.type_) {
      raise UnsupportedExpression(
        detail="runtime imports must use only v1 host primitive types",
      )
    }
    self.add_plan(value, RuntimeImport(value, external))
  }
}

///|
fn ImageLowerer::add_plan(
  self : ImageLowerer,
  value : @buslane.ValueId,
  plan : PlannedEntry,
) -> Unit raise LoisvmLoweringError {
  let function : @bytecode.FunctionId = { value: self.plans.length() + 1 }
  let type_ = match self.metadata.value_info(value) {
    Some(info) => info.type_
    None => raise MissingValueMetadata(value~)
  }
  self.plans.push(plan)
  self.globals.push({ value, lowered: Function(function, type_) })
}

///|
fn ImageLowerer::find_external(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> @buslane_lowering.BuslaneBuiltinExternal? {
  for external in self.externals.builtins {
    if external.value == value {
      return Some(external)
    }
  }
  None
}

///|
fn ImageLowerer::find_global(
  self : ImageLowerer,
  value : @buslane.ValueId,
) -> GlobalValue? {
  for binding in self.globals {
    if binding.value == value {
      return Some(binding.lowered)
    }
  }
  None
}

///|
fn extract_top_function(expression : @anf.AnfExpr) -> @anf.AnfFunction? {
  match expression {
    Atom(atom) => extract_top_atom_function(atom)
    _ => None
  }
}

///|
fn extract_top_atom_function(atom : @anf.AnfAtom) -> @anf.AnfFunction? {
  match atom {
    Function(function) => Some(function)
    TypeLambda(body~, ..) => extract_top_function(body)
    _ => None
  }
}

///|
fn ImageLowerer::lower_function(
  self : ImageLowerer,
  value : @buslane.ValueId,
  function : @anf.AnfFunction,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let type_ = match self.metadata.value_info(value) {
    Some(info) => info.type_
    None => raise MissingValueMetadata(value~)
  }
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    type_,
  )
  self.lower_function_body(
    function,
    type_parameters,
    parameter_types,
    result_type,
    [],
    [],
    None,
    [],
  )
}

///|
fn ImageLowerer::lower_lifted_function(
  self : ImageLowerer,
  plan : LiftedFunctionPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    plan.type_,
  )
  self.lower_function_body(
    plan.function,
    type_parameters,
    parameter_types,
    result_type,
    plan.captured_parameters,
    plan.captures,
    plan.environment_shape,
    plan.recursive_functions,
  )
}

///|
fn ImageLowerer::lower_intrinsic_wrapper(
  self : ImageLowerer,
  plan : IntrinsicWrapperPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let (type_parameters, parameter_types, result_type) = function_type_parts(
    plan.type_,
  )
  if !type_parameters.is_empty() {
    raise UnsupportedIntrinsic(name=plan.name)
  }
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
  }
  let parameter_slots = parameter_types.map(type_ => lowerer.fresh_slot(type_))
  let arguments = []
  for index, slot in parameter_slots {
    arguments.push(Slot(slot, parameter_types[index]))
  }
  let result = lowerer.lower_intrinsic(plan.name, plan.type_, arguments)
  guard result is Slot(result_slot, _) else {
    raise UnsupportedIntrinsic(name=plan.name)
  }
  lowerer.terminate(Return(Some(result_slot)))
  {
    values: lowerer.values,
    inputs: {
      environment: None,
      witnesses: [],
      user_parameters: parameter_slots,
    },
    result: result_representation(result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: Return(Some(result_slot)),
      },
    ],
  }
}

///|
fn ImageLowerer::intrinsic_wrapper(
  self : ImageLowerer,
  name : String,
  type_ : @buslane.Type,
) -> @bytecode.FunctionId {
  for wrapper in self.intrinsic_wrappers {
    if wrapper.name == name && wrapper.type_ == type_ {
      return wrapper.function
    }
  }
  let function : @bytecode.FunctionId = { value: self.plans.length() + 1 }
  let wrapper = { function, name, type_ }
  self.intrinsic_wrappers.push(wrapper)
  self.plans.push(IntrinsicWrapper(wrapper))
  function
}

///|
fn ImageLowerer::fresh_synthetic_parameter(
  self : ImageLowerer,
) -> @buslane.TypeParameterId {
  let parameter : @buslane.TypeParameterId = {
    index: self.next_synthetic_parameter,
  }
  self.next_synthetic_parameter -= 1
  parameter
}

///|
fn ImageLowerer::callable_adapter(
  self : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
) -> CallableAdapterPlan {
  for adapter in self.callable_adapters {
    if adapter.source_type == source_type && adapter.target_type == target_type {
      return adapter
    }
  }
  let captured_parameters = free_runtime_type_parameters(
    self, source_type, target_type,
  )
  let environment_shape = self.intern_object_shape(
    Environment({
      stored_witness_count: captured_parameters.length(),
      members: [
        { representation: I64, cleanup: OwnedCallable, witness_ordinal: None },
      ],
    }),
  )
  let adapter : CallableAdapterPlan = {
    function: { value: self.plans.length() + 1 },
    source_type,
    target_type,
    captured_parameters,
    environment_shape,
  }
  self.callable_adapters.push(adapter)
  self.plans.push(CallableAdapter(adapter))
  adapter
}

///|
fn free_runtime_type_parameters(
  image : ImageLowerer,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
) -> Array[@buslane.TypeParameterId] {
  free_runtime_type_parameters_in_types(image, [source_type, target_type])
}

///|
fn free_runtime_type_parameters_in_types(
  image : ImageLowerer,
  types : Array[@buslane.Type],
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  for type_ in types {
    collect_free_runtime_type_parameters(image, type_, [], parameters)
  }
  parameters
}

///|
fn collect_free_runtime_type_parameters(
  image : ImageLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  parameters : Array[@buslane.TypeParameterId],
) -> Unit {
  match type_ {
    Parameter(parameter) =>
      if !bound.contains(parameter) &&
        !parameters.contains(parameter) &&
        (parameter.index < 0 || image.requires_layout_witness(parameter)) {
        parameters.push(parameter)
      }
    Apply(applied_type, arguments) => {
      collect_free_runtime_type_parameters(
        image, applied_type, bound, parameters,
      )
      for argument in arguments {
        if argument is TypeArgument(type_) {
          collect_free_runtime_type_parameters(image, type_, bound, parameters)
        }
      }
    }
    TypeLambda(type_parameters, body) | Forall(type_parameters, body) => {
      let nested_bound = bound.copy()
      nested_bound.append(type_parameters)
      collect_free_runtime_type_parameters(
        image, body, nested_bound, parameters,
      )
    }
    Function(arguments, result, _) => {
      for argument in arguments {
        collect_free_runtime_type_parameters(image, argument, bound, parameters)
      }
      collect_free_runtime_type_parameters(image, result, bound, parameters)
    }
    Primitive(_) | Constructor(_) => ()
  }
}

///|
fn FunctionLowerer::canonical_callable_type(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> (@buslane.Type, Array[TypeArgumentBinding]) raise LoisvmLoweringError {
  let bindings = []
  let canonical = self.canonical_callable_type_with_bound(type_, [], bindings)
  (canonical, bindings)
}

///|
fn FunctionLowerer::canonical_callable_type_with_bound(
  self : FunctionLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  bindings : Array[TypeArgumentBinding],
) -> @buslane.Type raise LoisvmLoweringError {
  match type_ {
    Forall(parameters, body) => {
      let nested_bound = bound.copy()
      nested_bound.append(parameters)
      Forall(
        parameters,
        self.canonical_callable_type_with_bound(body, nested_bound, bindings),
      )
    }
    Function(parameters, result, effect) =>
      Function(
        parameters.map(type_ => {
          self.canonical_callable_value_type(type_, bound, bindings)
        }),
        self.canonical_callable_value_type(result, bound, bindings),
        effect,
      )
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn FunctionLowerer::canonical_callable_value_type(
  self : FunctionLowerer,
  type_ : @buslane.Type,
  bound : Array[@buslane.TypeParameterId],
  bindings : Array[TypeArgumentBinding],
) -> @buslane.Type {
  if type_ == Primitive(Unit) {
    return type_
  }
  if type_ is Parameter(parameter) && bound.contains(parameter) {
    return type_
  }
  let parameter = self.image.fresh_synthetic_parameter()
  bindings.push({ parameter, argument: TypeArgument(type_) })
  Parameter(parameter)
}

///|
fn FunctionLowerer::adapter_witness(
  self : FunctionLowerer,
  parameter : @buslane.TypeParameterId,
  substitutions : Array[TypeArgumentBinding],
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  for substitution in substitutions {
    if substitution.parameter == parameter {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="callable adapter witness requires a type argument",
        )
      }
      return self.layout_witness(type_)
    }
  }
  self.find_witness(parameter)
}

///|
fn FunctionLowerer::make_callable_adapter(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : Array[TypeArgumentBinding],
) -> LocalValue raise LoisvmLoweringError {
  if source_type == target_type {
    return Slot(source, target_type)
  }
  let plan = self.image.callable_adapter(source_type, target_type)
  let witnesses = plan.captured_parameters.map(parameter => {
    self.adapter_witness(parameter, substitutions)
  })
  let environment = self.fresh_metadata(environment_metadata())
  let environment_layout = self.image.intern_layout(
    Environment(plan.environment_shape),
  )
  self.emit(
    MakeEnv(
      environment,
      plan.environment_shape,
      Immediate(environment_layout),
      witnesses,
      [source],
    ),
  )
  let callable = self.fresh_slot(target_type)
  self.emit(MakeClosure(callable, plan.function, environment))
  Slot(callable, target_type)
}

///|
fn FunctionLowerer::adapt_local_value(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
) -> LocalValue raise LoisvmLoweringError {
  self.adapt_local_value_with_substitutions(value, source_type, target_type, [])
}

///|
fn FunctionLowerer::adapt_local_value_with_substitutions(
  self : FunctionLowerer,
  value : LocalValue,
  source_type : @buslane.Type,
  target_type : @buslane.Type,
  substitutions : Array[TypeArgumentBinding],
) -> LocalValue raise LoisvmLoweringError {
  if source_type == target_type {
    return match value {
      Unit => Unit
      Slot(slot, _) => Slot(slot, target_type)
      _ => value
    }
  }
  match (source_type, target_type) {
    (Primitive(Unit), Primitive(Unit)) => Unit
    (Parameter(_), Parameter(_)) =>
      match value {
        Slot(slot, _) => Slot(slot, target_type)
        _ =>
          raise InvalidTypeApplication(
            detail="erased value is not materialized",
          )
      }
    (_, Parameter(parameter)) => {
      let witness = self.adapter_witness(parameter, substitutions)
      Slot(self.erase_value(value, source_type, witness), target_type)
    }
    (Parameter(_), _) => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="erased value is not materialized")
      }
      self.unerase_value(slot, target_type)
    }
    (Function(_, _, _) | Forall(_, _), Function(_, _, _) | Forall(_, _)) => {
      guard self.materialize_local(value) is Slot(source, _) else {
        raise InvalidTypeApplication(
          detail="callable value is not materialized",
        )
      }
      self.make_callable_adapter(
        source, source_type, target_type, substitutions,
      )
    }
    _ => {
      guard value is Slot(slot, _) else {
        raise InvalidTypeApplication(detail="adapted value is not materialized")
      }
      let source_metadata = slot_metadata(source_type)
      let target_metadata = slot_metadata(target_type)
      if source_metadata.representation != target_metadata.representation ||
        source_metadata.cleanup != target_metadata.cleanup {
        raise InvalidTypeApplication(
          detail="callable adapter cannot bridge incompatible value representations",
        )
      }
      Slot(slot, target_type)
    }
  }
}

///|
fn ImageLowerer::lower_callable_adapter(
  self : ImageLowerer,
  plan : CallableAdapterPlan,
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let (source_type_parameters, source_parameter_types, source_result_type) = function_type_parts(
    plan.source_type,
  )
  let (target_type_parameters, target_parameter_types, target_result_type) = function_type_parts(
    plan.target_type,
  )
  if source_type_parameters.length() != target_type_parameters.length() ||
    source_parameter_types.length() != target_parameter_types.length() {
    raise InvalidTypeApplication(
      detail="callable adapter source and target arities differ",
    )
  }
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
  }
  let input_witnesses = []
  for index, parameter in target_type_parameters {
    if self.requires_layout_witness(parameter) {
      let witness = lowerer.fresh_metadata(layout_witness_metadata())
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter, value: witness })
      let source_parameter = source_type_parameters[index]
      if source_parameter != parameter {
        lowerer.witnesses.push({ parameter: source_parameter, value: witness })
      }
    }
  }
  let environment = lowerer.fresh_metadata(environment_metadata())
  lowerer.environment = Some(environment)
  for index, parameter in plan.captured_parameters {
    let witness = lowerer.fresh_metadata(layout_witness_metadata())
    lowerer.emit(
      LoadObjectWitness(witness, plan.environment_shape, environment, index),
    )
    lowerer.witnesses.push({ parameter, value: witness })
  }
  let source_callable = lowerer.fresh_borrowed_slot(plan.source_type)
  lowerer.emit(
    BorrowCapture(plan.environment_shape, environment, 0, {
      value_destination: source_callable,
      witness_destination: None,
    }),
  )
  let target_parameters : Array[LocalValue] = []
  let user_parameter_slots = []
  for type_ in target_parameter_types {
    if type_ == Primitive(Unit) {
      target_parameters.push(Unit)
    } else {
      let slot = lowerer.fresh_slot(type_)
      user_parameter_slots.push(slot)
      target_parameters.push(Slot(slot, type_))
    }
  }
  let source_arguments = []
  for index, source_parameter_type in source_parameter_types {
    let adapted = lowerer.adapt_local_value(
      target_parameters[index],
      target_parameter_types[index],
      source_parameter_type,
    )
    if adapted is Slot(slot, _) {
      source_arguments.push(slot)
    }
  }
  let call_witnesses = []
  for parameter in source_type_parameters {
    if self.requires_layout_witness(parameter) {
      call_witnesses.push(lowerer.find_witness(parameter))
    }
  }
  if source_result_type == target_result_type {
    lowerer.terminate(
      TailCallValue(source_callable, call_witnesses, source_arguments),
    )
  } else {
    let source_result = lowerer.fresh_optional_slot(source_result_type)
    lowerer.emit(
      CallValue(
        source_callable,
        call_witnesses,
        source_arguments,
        source_result.0,
      ),
    )
    let result = lowerer.adapt_local_value(
      source_result.1,
      source_result_type,
      target_result_type,
    )
    lowerer.terminate(
      match result {
        Unit => Return(None)
        Slot(slot, _) => Return(Some(slot))
        _ =>
          raise InvalidTypeApplication(
            detail="callable adapter result is not materialized",
          )
      },
    )
  }
  {
    values: lowerer.values,
    inputs: {
      environment: Some(environment),
      witnesses: input_witnesses,
      user_parameters: user_parameter_slots,
    },
    result: result_representation(target_result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator: lowerer.blocks[0].terminator.unwrap(),
      },
    ],
  }
}

///|
fn ImageLowerer::lower_function_body(
  self : ImageLowerer,
  function : @anf.AnfFunction,
  type_parameters : Array[@buslane.TypeParameterId],
  parameter_types : Array[@buslane.Type],
  result_type : @buslane.Type,
  captured_parameters : Array[@buslane.TypeParameterId],
  captures : Array[CapturePlan],
  environment_shape : @bytecode.ObjectShapeId?,
  recursive_functions : Array[RecursiveFunctionPlan],
) -> @vmcfg.FunctionBody raise LoisvmLoweringError {
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
  }
  let input_witnesses = []
  for parameter in type_parameters {
    if self.requires_layout_witness(parameter) {
      let witness = lowerer.fresh_metadata(layout_witness_metadata())
      input_witnesses.push(witness)
      lowerer.witnesses.push({ parameter, value: witness })
    }
  }
  if environment_shape is Some(shape) {
    let environment = lowerer.fresh_metadata(environment_metadata())
    lowerer.environment = Some(environment)
    for index, parameter in captured_parameters {
      let witness = lowerer.fresh_metadata(layout_witness_metadata())
      lowerer.emit(LoadObjectWitness(witness, shape, environment, index))
      lowerer.witnesses.push({ parameter, value: witness })
    }
    for capture in captures {
      if capture.member_index is Some(member_index) {
        let (destination, witness_destination) = if capture.type_
          is Parameter(_) {
          let witness = lowerer.fresh_metadata(layout_witness_metadata())
          (lowerer.fresh_erased_slot(witness, Borrowed), Some(witness))
        } else {
          (lowerer.fresh_borrowed_slot(capture.type_), None)
        }
        lowerer.emit(
          BorrowCapture(shape, environment, member_index, {
            value_destination: destination,
            witness_destination,
          }),
        )
        lowerer.bind_capture(capture.binding, Slot(destination, capture.type_))
      } else {
        lowerer.bind_capture(capture.binding, Unit)
      }
    }
  } else {
    for capture in captures {
      lowerer.bind_capture(capture.binding, Unit)
    }
  }
  for recursive in recursive_functions {
    lowerer.bindings.push({
      value: recursive.value,
      lowered: RecursiveFunction(
        recursive.function,
        recursive.type_,
        lowerer.environment,
      ),
    })
  }
  let parameter_slots : Array[@vmcfg.ValueId] = []
  for index, parameter in function.parameters {
    let type_ = parameter_types[index]
    if type_ == Primitive(Unit) {
      lowerer.bindings.push({ value: parameter, lowered: Unit })
    } else {
      let slot = lowerer.fresh_slot(type_)
      parameter_slots.push(slot)
      lowerer.bindings.push({ value: parameter, lowered: Slot(slot, type_) })
    }
  }
  let result = lowerer.materialize_local(lowerer.lower_expr(function.body))
  let terminator : @vmcfg.Terminator = match lowerer.take_tail_call(result) {
    Some(terminator) => terminator
    None =>
      match result {
        Unit => Return(None)
        Slot(slot, _) => Return(Some(slot))
        Global(_)
        | RecursiveFunction(_, _, _)
        | TypeApplied(_, _)
        | TypeAppliedCallable(_, _, _) =>
          raise UnsupportedExpression(
            detail="function returns an unapplied callable",
          )
      }
  }
  lowerer.terminate(terminator)
  lowerer.rewrite_tail_call_predecessors()
  let blocks : Array[@vmcfg.Block] = []
  for index, block in lowerer.blocks {
    let terminator = match block.terminator {
      Some(terminator) => terminator
      None => raise UnterminatedBlock(block=index)
    }
    blocks.push({
      parameters: block.parameters,
      instructions: block.instructions,
      terminator,
    })
  }
  {
    values: lowerer.values,
    inputs: {
      environment: lowerer.environment,
      witnesses: input_witnesses,
      user_parameters: parameter_slots,
    },
    result: result_representation(result_type),
    blocks,
  }
}

///|
fn FunctionLowerer::rewrite_tail_call_predecessors(
  self : FunctionLowerer,
) -> Unit {
  for target_index, target in self.blocks {
    if !target.instructions.is_empty() {
      continue
    }
    let returned = match target.terminator {
      Some(Return(None)) if target.parameters.is_empty() => Some(None)
      Some(Return(Some(value))) if target.parameters is [parameter] &&
        parameter == value => Some(Some(value))
      _ => None
    }
    guard returned is Some(returned) else { continue }
    for predecessor in self.blocks {
      guard predecessor.terminator is Some(Jump(edge)) &&
        edge.target.value == target_index else {
        continue
      }
      let expected = match (returned, edge.arguments) {
        (None, []) => Some(None)
        (Some(_), [argument]) => Some(Some(argument))
        _ => None
      }
      guard expected is Some(expected) else { continue }
      predecessor.rewrite_last_call_as_tail(expected)
    }
  }
}

///|
fn LowerBlock::rewrite_last_call_as_tail(
  self : LowerBlock,
  expected : @vmcfg.ValueId?,
) -> Unit {
  guard self.instructions.last() is Some(instruction) else { return }
  match instruction {
    CallDirect(target, environment, witnesses, arguments, destination) =>
      if destination == expected {
        ignore(self.instructions.pop())
        self.terminator = Some(
          TailCallDirect(target, environment, witnesses, arguments),
        )
      }
    CallValue(callable, witnesses, arguments, destination) =>
      if destination == expected {
        ignore(self.instructions.pop())
        self.terminator = Some(TailCallValue(callable, witnesses, arguments))
      }
    _ => ()
  }
}

///|
fn FunctionLowerer::take_tail_call(
  self : FunctionLowerer,
  result : LocalValue,
) -> @vmcfg.Terminator? {
  let instructions = self.blocks[self.current_block].instructions
  guard instructions.last() is Some(instruction) else { return None }
  match instruction {
    CallDirect(target, environment, witnesses, arguments, destination) =>
      if tail_destination_matches(destination, result) {
        ignore(instructions.pop())
        Some(TailCallDirect(target, environment, witnesses, arguments))
      } else {
        None
      }
    CallValue(callable, witnesses, arguments, destination) =>
      if tail_destination_matches(destination, result) {
        ignore(instructions.pop())
        Some(TailCallValue(callable, witnesses, arguments))
      } else {
        None
      }
    _ => None
  }
}

///|
fn tail_destination_matches(
  destination : @vmcfg.ValueId?,
  result : LocalValue,
) -> Bool {
  match (destination, result) {
    (None, Unit) => true
    (Some(destination), Slot(result, _)) => destination == result
    _ => false
  }
}

///|
fn ImageLowerer::function_signature(
  self : ImageLowerer,
  value : @buslane.ValueId,
  type_ : @buslane.Type,
) -> (Array[@buslane.Type], @buslane.Type) raise LoisvmLoweringError {
  ignore(self)
  match strip_forall(type_) {
    Function(parameters, result, _) => (parameters, result)
    _ => raise InvalidFunctionType(value~, type_~)
  }
}

///|
fn ImageLowerer::requires_layout_witness(
  self : ImageLowerer,
  parameter : @buslane.TypeParameterId,
) -> Bool {
  match self.metadata.type_parameter_info(parameter) {
    Some({ kind: Type, .. }) => true
    _ => false
  }
}

///|
fn function_type_parts(
  type_ : @buslane.Type,
) -> (Array[@buslane.TypeParameterId], Array[@buslane.Type], @buslane.Type) raise LoisvmLoweringError {
  match type_ {
    Forall(parameters, body) =>
      match strip_forall(body) {
        Function(arguments, result, _) => (parameters, arguments, result)
        _ => raise UnsupportedType(type_~)
      }
    Function(parameters, result, _) => ([], parameters, result)
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn strip_forall(type_ : @buslane.Type) -> @buslane.Type {
  match type_ {
    Forall(_, body) => strip_forall(body)
    _ => type_
  }
}

///|
fn FunctionLowerer::emit(
  self : FunctionLowerer,
  instruction : @vmcfg.Instruction,
) -> Unit {
  self.blocks[self.current_block].instructions.push(instruction)
}

///|
fn FunctionLowerer::terminate(
  self : FunctionLowerer,
  terminator : @vmcfg.Terminator,
) -> Unit {
  self.blocks[self.current_block].terminator = Some(terminator)
}

///|
fn FunctionLowerer::new_block(
  self : FunctionLowerer,
  parameters : Array[@vmcfg.ValueId],
) -> @bytecode.BlockId {
  let block : @bytecode.BlockId = { value: self.blocks.length() }
  self.blocks.push({ parameters, instructions: [], terminator: None })
  block
}

///|
fn FunctionLowerer::enter_block(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
) -> Unit {
  self.current_block = block.value
}

///|
fn FunctionLowerer::lower_expr(
  self : FunctionLowerer,
  expression : @anf.AnfExpr,
) -> LocalValue raise LoisvmLoweringError {
  match expression {
    Atom(atom) => self.lower_atom(atom)
    Let(binding, body) => {
      let lowered = self.lower_rhs(binding.rhs())
      match binding {
        Value(id~, ..) => self.bindings.push({ value: id, lowered })
        Temp(temp~, ..) => self.temps.push({ temp, lowered })
      }
      self.lower_expr(body)
    }
    LetRec(bindings, body) => self.lower_recursive_group(bindings, body)
    Match(match_) => self.lower_match(match_)
  }
}

///|
fn FunctionLowerer::lower_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
) -> LocalValue raise LoisvmLoweringError {
  let scrutinee = self.materialize_local(self.lower_atom(match_.scrutinee))
  match scrutinee {
    Unit => {
      let alternative = match find_unit_alternative(match_.alternatives) {
        Some(alternative) => alternative
        None =>
          raise UnsupportedExpression(
            detail="Unit match has no matching alternative",
          )
      }
      self.lower_irrefutable_match(match_, scrutinee, alternative)
    }
    Slot(condition, scrutinee_type) =>
      match scrutinee_type {
        Primitive(Bool) => self.lower_bool_match(match_, condition, scrutinee)
        Primitive(Int) | Primitive(Double) | Primitive(String) =>
          self.lower_literal_match(match_, condition, scrutinee_type, scrutinee)
        Function(_, _, _) | Forall(_, _) => {
          let alternative = match
            find_default_alternative(match_.alternatives) {
            Some(alternative) => alternative
            None =>
              raise UnsupportedExpression(
                detail="callable match requires a default alternative",
              )
          }
          self.lower_irrefutable_match(match_, scrutinee, alternative)
        }
        Constructor(owner) =>
          self.lower_data_match(match_, condition, scrutinee_type, owner, [])
        Apply(Constructor(owner), arguments) =>
          self.lower_data_match(
            match_, condition, scrutinee_type, owner, arguments,
          )
        _ =>
          raise UnsupportedExpression(detail="unsupported match scrutinee type")
      }
    Global(_)
    | RecursiveFunction(_, _, _)
    | TypeApplied(_, _)
    | TypeAppliedCallable(_, _, _) =>
      raise UnsupportedExpression(detail="match scrutinee is not materialized")
  }
}

///|
fn FunctionLowerer::lower_literal_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  initial_scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  initial_value : LocalValue,
) -> LocalValue raise LoisvmLoweringError {
  let literal_alternatives = match_.alternatives.filter(alternative => {
    alternative.alt_constructor is Literal(_)
  })
  if literal_alternatives.is_empty() {
    let alternative = match find_default_alternative(match_.alternatives) {
      Some(alternative) => alternative
      None =>
        raise UnsupportedExpression(detail="literal match has no alternatives")
    }
    return self.lower_irrefutable_match(match_, initial_value, alternative)
  }
  let default_alternative = match
    find_default_alternative(match_.alternatives) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(
        detail="literal match requires a default alternative",
      )
  }
  let join_value = self.fresh_optional_slot(match_.result_type)
  let join_parameters = match join_value.0 {
    Some(slot) => [slot]
    None => []
  }
  let join_block = self.new_block(join_parameters)
  let branches : Array[
    (@bytecode.BlockId, @vmcfg.ValueId, @vmcfg.ValueId?, @anf.AnfAlternative),
  ] = []
  let mut scrutinee = initial_scrutinee
  let mut environment = self.environment
  for alternative in literal_alternatives {
    guard alternative.alt_constructor is Literal(literal) else {
      abort("filtered literal alternative")
    }
    let condition = self.emit_literal_equality(
      scrutinee, scrutinee_type, literal,
    )
    let branch_scrutinee = self.fresh_slot(scrutinee_type)
    let branch_environment = self.branch_environment_parameter()
    let branch_parameters = [branch_scrutinee]
    if branch_environment is Some(value) {
      branch_parameters.push(value)
    }
    let branch_block = self.new_block(branch_parameters)
    branches.push(
      (branch_block, branch_scrutinee, branch_environment, alternative),
    )
    let next_scrutinee = self.fresh_slot(scrutinee_type)
    let next_environment = self.branch_environment_parameter()
    let next_parameters = [next_scrutinee]
    if next_environment is Some(value) {
      next_parameters.push(value)
    }
    let next_block = self.new_block(next_parameters)
    let arguments = [scrutinee]
    if environment is Some(value) {
      arguments.push(value)
    }
    self.terminate(
      BranchBool(condition, { target: branch_block, arguments }, {
        target: next_block,
        arguments,
      }),
    )
    self.enter_block(next_block)
    scrutinee = next_scrutinee
    environment = next_environment
  }
  let default_block = self.current_block
  let default_scrutinee = scrutinee
  let default_environment = environment
  for branch in branches {
    let (block, branch_scrutinee, branch_environment, alternative) = branch
    self.lower_bool_alternative(
      block,
      join_block,
      match_.binder,
      Slot(branch_scrutinee, scrutinee_type),
      alternative,
      branch_environment,
    )
  }
  self.lower_bool_alternative(
    { value: default_block },
    join_block,
    match_.binder,
    Slot(default_scrutinee, scrutinee_type),
    default_alternative,
    default_environment,
  )
  self.enter_block(join_block)
  join_value.1
}

///|
fn FunctionLowerer::emit_literal_equality(
  self : FunctionLowerer,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  literal : @buslane.Literal,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let lowered = self.lower_literal(literal)
  guard lowered is Slot(expected, literal_type) &&
    literal_type == scrutinee_type else {
    raise UnsupportedExpression(
      detail="literal pattern type does not match its scrutinee",
    )
  }
  let condition = self.fresh_slot(Primitive(Bool))
  let instruction : @vmcfg.Instruction = match scrutinee_type {
    Primitive(Int) => IntEq(condition, scrutinee, expected)
    Primitive(Double) => DoubleEq(condition, scrutinee, expected)
    Primitive(String) => StringEq(condition, scrutinee, expected)
    _ =>
      raise UnsupportedExpression(
        detail="unsupported literal pattern representation",
      )
  }
  self.emit(instruction)
  condition
}

///|
fn FunctionLowerer::lower_irrefutable_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  scrutinee : LocalValue,
  alternative : @anf.AnfAlternative,
) -> LocalValue raise LoisvmLoweringError {
  if !alternative.type_binders.is_empty() ||
    !alternative.value_binders.is_empty() {
    raise UnsupportedExpression(
      detail="irrefutable alternative cannot bind payloads",
    )
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.bindings.push({ value: match_.binder, lowered: scrutinee })
  let result = self.materialize_local(self.lower_expr(alternative.body))
  self.restore_bindings(value_count, temp_count)
  result
}

///|
fn FunctionLowerer::lower_bool_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  condition : @vmcfg.ValueId,
  scrutinee : LocalValue,
) -> LocalValue raise LoisvmLoweringError {
  let if_true = match find_bool_alternative(match_.alternatives, true) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(detail="Bool match lacks a true alternative")
  }
  let if_false = match find_bool_alternative(match_.alternatives, false) {
    Some(alternative) => alternative
    None =>
      raise UnsupportedExpression(detail="Bool match lacks a false alternative")
  }
  let true_environment = self.branch_environment_parameter()
  let false_environment = self.branch_environment_parameter()
  let true_block = self.new_block(
    true_environment.map(value => [value]).unwrap_or([]),
  )
  let false_block = self.new_block(
    false_environment.map(value => [value]).unwrap_or([]),
  )
  let join_value = self.fresh_optional_slot(match_.result_type)
  let join_parameters = match join_value.0 {
    Some(slot) => [slot]
    None => []
  }
  let join_block = self.new_block(join_parameters)
  self.terminate(
    BranchBool(
      condition,
      {
        target: true_block,
        arguments: self.environment.map(value => [value]).unwrap_or([]),
      },
      {
        target: false_block,
        arguments: self.environment.map(value => [value]).unwrap_or([]),
      },
    ),
  )
  self.lower_bool_alternative(
    true_block,
    join_block,
    match_.binder,
    scrutinee,
    if_true,
    true_environment,
  )
  self.lower_bool_alternative(
    false_block,
    join_block,
    match_.binder,
    scrutinee,
    if_false,
    false_environment,
  )
  self.enter_block(join_block)
  join_value.1
}

///|
fn FunctionLowerer::lower_data_match(
  self : FunctionLowerer,
  match_ : @anf.AnfMatch,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  owner : @buslane.TypeId,
  type_arguments : Array[@buslane.GenericArgument],
) -> LocalValue raise LoisvmLoweringError {
  let owner_info = match self.image.metadata.type_info(owner) {
    Some(info) => info
    None =>
      raise UnsupportedExpression(detail="data match owner metadata is missing")
  }
  let substitutions = data_type_substitutions(
    owner_info.parameters,
    type_arguments,
  )
  if owner_info.constructors is [data_constructor] {
    let alternative = match
      find_data_alternative(match_.alternatives, data_constructor) {
      Some(alternative) => alternative
      None =>
        raise UnsupportedExpression(
          detail="data match lacks a constructor or default alternative",
        )
    }
    return self.lower_irrefutable_data_alternative(
      match_.binder,
      scrutinee,
      scrutinee_type,
      data_constructor,
      alternative,
      substitutions,
    )
  }
  let tag_type = @buslane.Type::Primitive(Bool)
  let tag = self.fresh_slot(tag_type)
  self.emit(LoadTag(tag, scrutinee))
  let join_value = self.fresh_optional_slot(match_.result_type)
  let join_parameters = match join_value.0 {
    Some(slot) => [slot]
    None => []
  }
  let join_block = self.new_block(join_parameters)
  let cases : Array[@vmcfg.Edge] = []
  let alternatives : Array[
    (
      @bytecode.BlockId,
      @vmcfg.ValueId,
      @vmcfg.ValueId?,
      @anf.AnfAlternative,
      @buslane.DataConId,
    ),
  ] = []
  for data_constructor in owner_info.constructors {
    let alternative = match
      find_data_alternative(match_.alternatives, data_constructor) {
      Some(alternative) => alternative
      None =>
        raise UnsupportedExpression(
          detail="data match lacks a constructor or default alternative",
        )
    }
    let branch_scrutinee = self.fresh_slot(scrutinee_type)
    let branch_environment = self.branch_environment_parameter()
    let parameters = [branch_scrutinee]
    if branch_environment is Some(environment) {
      parameters.push(environment)
    }
    let block = self.new_block(parameters)
    let arguments = [scrutinee]
    if self.environment is Some(environment) {
      arguments.push(environment)
    }
    cases.push({ target: block, arguments })
    alternatives.push(
      (
        block, branch_scrutinee, branch_environment, alternative, data_constructor,
      ),
    )
  }
  let default_block = self.new_block([])
  self.terminate(
    SwitchTag(tag, cases, { target: default_block, arguments: [] }),
  )
  for item in alternatives {
    let (
      block,
      branch_scrutinee,
      branch_environment,
      alternative,
      data_constructor,
    ) = item
    self.lower_data_alternative(
      block,
      join_block,
      match_.binder,
      branch_scrutinee,
      scrutinee_type,
      data_constructor,
      alternative,
      branch_environment,
      substitutions,
    )
  }
  self.enter_block(default_block)
  self.terminate(Unreachable)
  self.enter_block(join_block)
  join_value.1
}

///|
fn FunctionLowerer::lower_irrefutable_data_alternative(
  self : FunctionLowerer,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  substitutions : Array[TypeArgumentBinding],
) -> LocalValue raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  self.bind_data_alternative(
    binder, scrutinee, scrutinee_type, data_constructor, alternative, substitutions,
  )
  let result = self.materialize_local(self.lower_expr(alternative.body))
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  result
}

///|
fn FunctionLowerer::lower_data_alternative(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  branch_environment : @vmcfg.ValueId?,
  substitutions : Array[TypeArgumentBinding],
) -> Unit raise LoisvmLoweringError {
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  let witness_count = self.witnesses.length()
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bind_data_alternative(
    binder, scrutinee, scrutinee_type, data_constructor, alternative, substitutions,
  )
  let result = self.materialize_local(self.lower_expr(alternative.body))
  let arguments = match result {
    Unit => []
    Slot(slot, _) => [slot]
    Global(_)
    | RecursiveFunction(_, _, _)
    | TypeApplied(_, _)
    | TypeAppliedCallable(_, _, _) =>
      raise UnsupportedExpression(
        detail="match alternative returns an unapplied callable",
      )
  }
  self.terminate(Jump({ target: join, arguments }))
  self.restore_bindings(value_count, temp_count)
  self.restore_witnesses(witness_count)
  self.environment = original_environment
}

///|
fn FunctionLowerer::bind_data_alternative(
  self : FunctionLowerer,
  binder : @buslane.ValueId,
  scrutinee : @vmcfg.ValueId,
  scrutinee_type : @buslane.Type,
  data_constructor : @buslane.DataConId,
  alternative : @anf.AnfAlternative,
  substitutions : Array[TypeArgumentBinding],
) -> Unit raise LoisvmLoweringError {
  let info = match self.image.metadata.data_constructor_info(data_constructor) {
    Some(info) => info
    None => raise MissingDataConstructorMetadata(data_constructor~)
  }
  let binds_payloads = alternative.alt_constructor is DataCon(_)
  if binds_payloads {
    if alternative.type_binders.length() != info.hidden_type_parameters.length() {
      raise InvalidTypeApplication(
        detail="data alternative expects \{info.hidden_type_parameters.length()} hidden type binders, got \{alternative.type_binders.length()}",
      )
    }
  } else if !alternative.type_binders.is_empty() {
    raise InvalidTypeApplication(
      detail="default data alternative cannot bind hidden types",
    )
  }
  let expected_binders = if binds_payloads {
    info.payload_types.length()
  } else {
    0
  }
  if alternative.value_binders.length() != expected_binders {
    raise InvalidDataPayloadCount(
      data_constructor~,
      expected=expected_binders,
      actual=alternative.value_binders.length(),
    )
  }
  self.bindings.push({ value: binder, lowered: Slot(scrutinee, scrutinee_type) })
  let branch_substitutions = substitutions.copy()
  if binds_payloads {
    let shape = self.image.data_shape(data_constructor, info)
    let owner_info = match self.image.metadata.type_info(info.owner) {
      Some(info) => info
      None => raise MissingDataConstructorMetadata(data_constructor~)
    }
    let mut witness_ordinal = owner_info.parameters
      .filter(parameter => self.image.requires_layout_witness(parameter))
      .length()
    for index, hidden_parameter in info.hidden_type_parameters {
      let binder = alternative.type_binders[index]
      let argument = match
        self.image.metadata.type_parameter_info(hidden_parameter) {
        Some({ kind: Effect, .. }) =>
          @buslane.GenericArgument::EffectArgument(Parameter(binder))
        Some(_) => TypeArgument(Parameter(binder))
        None =>
          raise InvalidTypeApplication(
            detail="hidden data parameter metadata is missing",
          )
      }
      branch_substitutions.push({ parameter: hidden_parameter, argument })
      if self.image.requires_layout_witness(hidden_parameter) {
        let witness = self.fresh_metadata(layout_witness_metadata())
        self.emit(LoadObjectWitness(witness, shape, scrutinee, witness_ordinal))
        self.witnesses.push({ parameter: binder, value: witness })
        witness_ordinal += 1
      }
    }
    for index, value_binder in alternative.value_binders {
      let formal_type = info.payload_types[index]
      let payload_type = substitute_type(formal_type, branch_substitutions)
      let stored = if formal_type is Parameter(_) {
        let witness = self.fresh_metadata(layout_witness_metadata())
        let erased = self.fresh_erased_slot(witness, Borrowed)
        self.emit(
          BorrowField(
            shape,
            scrutinee,
            runtime_member_index(info.payload_types, index),
            { value_destination: erased, witness_destination: Some(witness) },
          ),
        )
        Slot(erased, formal_type)
      } else if formal_type == Primitive(Unit) {
        Unit
      } else {
        let destination = self.fresh_borrowed_slot(formal_type)
        self.emit(
          BorrowField(
            shape,
            scrutinee,
            runtime_member_index(info.payload_types, index),
            { value_destination: destination, witness_destination: None },
          ),
        )
        Slot(destination, formal_type)
      }
      let lowered = self.adapt_local_value_with_substitutions(
        stored, formal_type, payload_type, branch_substitutions,
      )
      self.bindings.push({ value: value_binder, lowered })
    }
  }
}

///|
fn FunctionLowerer::lower_bool_alternative(
  self : FunctionLowerer,
  block : @bytecode.BlockId,
  join : @bytecode.BlockId,
  binder : @buslane.ValueId,
  scrutinee : LocalValue,
  alternative : @anf.AnfAlternative,
  branch_environment : @vmcfg.ValueId?,
) -> Unit raise LoisvmLoweringError {
  if !alternative.type_binders.is_empty() ||
    !alternative.value_binders.is_empty() {
    raise UnsupportedExpression(detail="Bool alternatives cannot bind payloads")
  }
  let value_count = self.bindings.length()
  let temp_count = self.temps.length()
  self.enter_block(block)
  let original_environment = self.environment
  self.enter_branch_environment(original_environment, branch_environment)
  self.bindings.push({ value: binder, lowered: scrutinee })
  let result = self.materialize_local(self.lower_expr(alternative.body))
  let arguments = match result {
    Unit => []
    Slot(slot, _) => [slot]
    Global(_)
    | RecursiveFunction(_, _, _)
    | TypeApplied(_, _)
    | TypeAppliedCallable(_, _, _) =>
      raise UnsupportedExpression(
        detail="match alternative returns an unapplied callable",
      )
  }
  self.terminate(Jump({ target: join, arguments }))
  self.restore_bindings(value_count, temp_count)
  self.environment = original_environment
}

///|
fn FunctionLowerer::branch_environment_parameter(
  self : FunctionLowerer,
) -> @vmcfg.ValueId? {
  self.environment.map(_ => self.fresh_metadata(environment_metadata()))
}

///|
fn FunctionLowerer::enter_branch_environment(
  self : FunctionLowerer,
  original : @vmcfg.ValueId?,
  branch : @vmcfg.ValueId?,
) -> Unit {
  self.environment = branch
  guard original is Some(original) && branch is Some(branch) else { return }
  let shadows : Array[ValueBinding] = []
  for binding in self.bindings {
    if binding.lowered is RecursiveFunction(function, type_, Some(environment)) &&
      environment == original {
      shadows.push({
        value: binding.value,
        lowered: RecursiveFunction(function, type_, Some(branch)),
      })
    }
  }
  self.bindings.append(shadows)
}

///|
fn FunctionLowerer::restore_bindings(
  self : FunctionLowerer,
  value_count : Int,
  temp_count : Int,
) -> Unit {
  while self.bindings.length() > value_count {
    ignore(self.bindings.pop())
  }
  while self.temps.length() > temp_count {
    ignore(self.temps.pop())
  }
}

///|
fn FunctionLowerer::restore_witnesses(
  self : FunctionLowerer,
  witness_count : Int,
) -> Unit {
  while self.witnesses.length() > witness_count {
    ignore(self.witnesses.pop())
  }
}

///|
fn find_bool_alternative(
  alternatives : Array[@anf.AnfAlternative],
  value : Bool,
) -> @anf.AnfAlternative? {
  let mut default = None
  for alternative in alternatives {
    match alternative.alt_constructor {
      Literal(Bool(actual)) if actual == value => return Some(alternative)
      Default => default = Some(alternative)
      _ => ()
    }
  }
  default
}

///|
fn find_unit_alternative(
  alternatives : Array[@anf.AnfAlternative],
) -> @anf.AnfAlternative? {
  for alternative in alternatives {
    if alternative.alt_constructor is Literal(Unit) {
      return Some(alternative)
    }
  }
  find_default_alternative(alternatives)
}

///|
fn find_default_alternative(
  alternatives : Array[@anf.AnfAlternative],
) -> @anf.AnfAlternative? {
  for alternative in alternatives {
    if alternative.alt_constructor is Default {
      return Some(alternative)
    }
  }
  None
}

///|
fn find_data_alternative(
  alternatives : Array[@anf.AnfAlternative],
  data_constructor : @buslane.DataConId,
) -> @anf.AnfAlternative? {
  let mut default = None
  for alternative in alternatives {
    match alternative.alt_constructor {
      DataCon(actual) if actual == data_constructor => return Some(alternative)
      Default => default = Some(alternative)
      _ => ()
    }
  }
  default
}

///|
fn @anf.AnfBinding::rhs(self : @anf.AnfBinding) -> @anf.AnfRhs {
  match self {
    Value(rhs~, ..) | Temp(rhs~, ..) => rhs
  }
}

///|
fn FunctionLowerer::lower_rhs(
  self : FunctionLowerer,
  rhs : @anf.AnfRhs,
) -> LocalValue raise LoisvmLoweringError {
  match rhs {
    Atom(atom) => self.lower_atom(atom)
    TypeApply(callee~, arguments~) => self.lower_type_apply(callee, arguments)
    Call(callee~, arguments~) => self.lower_call(callee, arguments)
    Construct(construct) => self.lower_construct(construct)
    Perform(_) =>
      raise UnsupportedExpression(
        detail="perform must be erased before VM CFG lowering",
      )
    Handle(_) =>
      raise UnsupportedExpression(
        detail="handlers must be erased before VM CFG lowering",
      )
  }
}

///|
fn FunctionLowerer::lower_atom(
  self : FunctionLowerer,
  atom : @anf.AnfAtom,
) -> LocalValue raise LoisvmLoweringError {
  match atom {
    Literal(literal) => self.lower_literal(literal)
    Ref(value) => self.find_value(value)
    Temp(temp) => self.find_temp(temp)
    Function(function) => self.lower_nested_function(function)
    TypeLambda(type_parameters~, body~) => {
      let function = match extract_top_function(body) {
        Some(function) => function
        None =>
          raise UnsupportedExpression(
            detail="generic nested value must contain a function",
          )
      }
      self.lower_nested_function_with_type(
        function,
        Forall(type_parameters, self.image.anf_function_type(function)),
      )
    }
  }
}

///|
fn FunctionLowerer::lower_type_apply(
  self : FunctionLowerer,
  callee : @anf.AnfAtom,
  arguments : Array[@buslane.GenericArgument],
) -> LocalValue raise LoisvmLoweringError {
  match self.lower_atom(callee) {
    Global(global) => TypeApplied(global, arguments)
    Slot(callable, type_) => TypeAppliedCallable(callable, type_, arguments)
    RecursiveFunction(_, _, _) as recursive => {
      guard self.materialize_local(recursive) is Slot(callable, type_) else {
        abort("recursive callable was not materialized")
      }
      TypeAppliedCallable(callable, type_, arguments)
    }
    _ =>
      raise InvalidTypeApplication(
        detail="type application target is not a generic callable",
      )
  }
}

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
fn FunctionLowerer::lower_construct(
  self : FunctionLowerer,
  construct : @anf.AnfConstruct,
) -> LocalValue raise LoisvmLoweringError {
  let info = match
    self.image.metadata.data_constructor_info(construct.data_constructor) {
    Some(info) => info
    None =>
      raise MissingDataConstructorMetadata(
        data_constructor=construct.data_constructor,
      )
  }
  let owner_info = match self.image.metadata.type_info(info.owner) {
    Some(info) => info
    None =>
      raise MissingDataConstructorMetadata(
        data_constructor=construct.data_constructor,
      )
  }
  let substitutions = data_type_substitutions(
    owner_info.parameters,
    construct.type_arguments,
  )
  substitutions.append(
    data_type_substitutions(
      info.hidden_type_parameters,
      construct.hidden_witnesses,
    ),
  )
  if construct.payloads.length() != info.payload_types.length() {
    raise InvalidDataPayloadCount(
      data_constructor=construct.data_constructor,
      expected=info.payload_types.length(),
      actual=construct.payloads.length(),
    )
  }
  let witnesses = []
  for substitution in substitutions {
    if self.image.requires_layout_witness(substitution.parameter) {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="data layout requires a type argument",
        )
      }
      witnesses.push(self.layout_witness(type_))
    }
  }
  let fields = []
  for index, payload in construct.payloads {
    let formal_type = info.payload_types[index]
    let actual_type = substitute_type(formal_type, substitutions)
    let lowered = self.adapt_local_value_with_substitutions(
      self.lower_atom(payload),
      actual_type,
      formal_type,
      substitutions,
    )
    match lowered {
      Unit =>
        if formal_type != Primitive(Unit) {
          raise UnsupportedExpression(
            detail="non-Unit data field has no runtime representation",
          )
        }
      Slot(field, _) => fields.push(field)
      _ =>
        raise UnsupportedExpression(
          detail="data field has no runtime representation",
        )
    }
  }
  let shape = self.image.data_shape(construct.data_constructor, info)
  let layout = self.image.intern_layout(Data(shape))
  let result_type = if owner_info.parameters.is_empty() {
    @buslane.Type::Constructor(info.owner)
  } else {
    Apply(Constructor(info.owner), construct.type_arguments)
  }
  let destination = self.fresh_slot(result_type)
  self.emit(MakeData(destination, shape, Immediate(layout), witnesses, fields))
  Slot(destination, result_type)
}

///|
fn ImageLowerer::data_shape(
  self : ImageLowerer,
  data_constructor : @buslane.DataConId,
  info : @buslane.DataConInfo,
) -> @bytecode.ObjectShapeId raise LoisvmLoweringError {
  let owner_info = match self.metadata.type_info(info.owner) {
    Some(info) => info
    None => raise MissingDataConstructorMetadata(data_constructor~)
  }
  let witness_parameters = owner_info.parameters.filter(parameter => {
    self.requires_layout_witness(parameter)
  })
  witness_parameters.append(
    info.hidden_type_parameters.filter(parameter => {
      self.requires_layout_witness(parameter)
    }),
  )
  let members : Array[@bytecode.MemberSchema] = []
  for payload_type in info.payload_types {
    if payload_type is Parameter(parameter) {
      guard type_parameter_ordinal(witness_parameters, parameter)
        is Some(witness_ordinal) else {
        raise UnsupportedGenericData(data_constructor~)
      }
      members.push({
        representation: I64,
        cleanup: OwnedErased,
        witness_ordinal: Some(witness_ordinal),
      })
    } else if payload_type == Primitive(Unit) {
      ()
    } else {
      let metadata = slot_metadata(payload_type)
      members.push({
        representation: metadata.representation,
        cleanup: metadata.cleanup,
        witness_ordinal: None,
      })
    }
  }
  let constructor_tag = self.constructor_tag(data_constructor, info.owner)
  self.intern_object_shape(
    Data({
      constructor_tag,
      stored_witness_count: witness_parameters.length(),
      members,
    }),
  )
}

///|
fn type_parameter_ordinal(
  parameters : Array[@buslane.TypeParameterId],
  target : @buslane.TypeParameterId,
) -> Int? {
  for index, parameter in parameters {
    if parameter == target {
      return Some(index)
    }
  }
  None
}

///|
fn ImageLowerer::constructor_tag(
  self : ImageLowerer,
  data_constructor : @buslane.DataConId,
  owner : @buslane.TypeId,
) -> Int raise LoisvmLoweringError {
  let owner_info = match self.metadata.type_info(owner) {
    Some(info) => info
    None => raise MissingDataConstructorMetadata(data_constructor~)
  }
  for index, candidate in owner_info.constructors {
    if candidate == data_constructor {
      return index
    }
  }
  raise MissingDataConstructorMetadata(data_constructor~)
}

///|
fn FunctionLowerer::find_value(
  self : FunctionLowerer,
  value : @buslane.ValueId,
) -> LocalValue raise LoisvmLoweringError {
  for binding in self.bindings.rev_iter() {
    if binding.value == value {
      return binding.lowered
    }
  }
  match self.image.find_global(value) {
    Some(global) => Global(global)
    None => raise MissingValueMetadata(value~)
  }
}

///|
fn FunctionLowerer::find_temp(
  self : FunctionLowerer,
  temp : @anf.AnfTempId,
) -> LocalValue raise LoisvmLoweringError {
  for binding in self.temps.rev_iter() {
    if binding.temp == temp {
      return binding.lowered
    }
  }
  raise UnsupportedExpression(detail="unknown ANF temporary")
}

///|
fn FunctionLowerer::lower_literal(
  self : FunctionLowerer,
  literal : @buslane.Literal,
) -> LocalValue raise LoisvmLoweringError {
  match literal {
    Unit => Unit
    Bool(value) => {
      let type_ = @buslane.Type::Primitive(Bool)
      let slot = self.fresh_slot(type_)
      self.emit(ConstBool(slot, value))
      Slot(slot, type_)
    }
    Int(value) => {
      let type_ = @buslane.Type::Primitive(Int)
      let slot = self.fresh_slot(type_)
      self.emit(ConstInt(slot, value))
      Slot(slot, type_)
    }
    Double(value) => {
      let type_ = @buslane.Type::Primitive(Double)
      let slot = self.fresh_slot(type_)
      self.emit(ConstDouble(slot, value.reinterpret_as_int64()))
      Slot(slot, type_)
    }
    String(value) => {
      let type_ = @buslane.Type::Primitive(String)
      let slot = self.fresh_slot(type_)
      let constant = self.image.intern_string(value)
      ignore(self.image.intern_layout(String))
      self.emit(ConstString(slot, constant))
      Slot(slot, type_)
    }
  }
}

///|
fn FunctionLowerer::lower_call(
  self : FunctionLowerer,
  callee : @anf.AnfAtom,
  arguments : Array[@anf.AnfAtom],
) -> LocalValue raise LoisvmLoweringError {
  let callee = self.lower_atom(callee)
  let lowered_arguments = arguments.map(argument => {
    self.materialize_local(self.lower_atom(argument))
  })
  match callee {
    Global(Intrinsic(name, type_)) =>
      self.lower_intrinsic(name, type_, lowered_arguments)
    Global(Function(function, type_)) =>
      self.lower_direct_call(function, type_, lowered_arguments, None)
    RecursiveFunction(function, type_, environment) =>
      self.lower_direct_call(function, type_, lowered_arguments, environment)
    TypeApplied(Function(function, type_), type_arguments) =>
      self.lower_generic_direct_call(
        function, type_, type_arguments, lowered_arguments,
      )
    TypeAppliedCallable(callable, type_, type_arguments) =>
      self.lower_generic_value_call(
        callable, type_, type_arguments, lowered_arguments,
      )
    TypeApplied(_, _) =>
      raise InvalidTypeApplication(
        detail="type application target is not a generic function",
      )
    Slot(callable, type_) =>
      self.lower_value_call(callable, type_, lowered_arguments)
    _ => raise UnsupportedExpression(detail="value is not callable")
  }
}

///|
fn FunctionLowerer::materialize_local(
  self : FunctionLowerer,
  value : LocalValue,
) -> LocalValue raise LoisvmLoweringError {
  match value {
    Global(Function(function, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstFunction(destination, function))
      Slot(destination, type_)
    }
    Global(Intrinsic(name, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(
        ConstFunction(destination, self.image.intrinsic_wrapper(name, type_)),
      )
      Slot(destination, type_)
    }
    Global(DoubleConstant(bits, type_)) => {
      let destination = self.fresh_slot(type_)
      self.emit(ConstDouble(destination, bits))
      Slot(destination, type_)
    }
    RecursiveFunction(function, type_, environment) => {
      let destination = self.fresh_slot(type_)
      match environment {
        Some(environment) =>
          self.emit(MakeClosure(destination, function, environment))
        None => self.emit(ConstFunction(destination, function))
      }
      Slot(destination, type_)
    }
    TypeApplied(_, _) | TypeAppliedCallable(_, _, _) =>
      raise InvalidTypeApplication(
        detail="a type-applied callable must be called before materialization",
      )
    _ => value
  }
}

///|
fn FunctionLowerer::lower_value_call(
  self : FunctionLowerer,
  callable : @vmcfg.ValueId,
  type_ : @buslane.Type,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let result_type = callable_result_type(type_)
  let argument_slots = []
  for argument in arguments {
    match argument {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let destination = self.fresh_optional_slot(result_type)
  self.emit(CallValue(callable, [], argument_slots, destination.0))
  destination.1
}

///|
fn FunctionLowerer::lower_generic_direct_call(
  self : FunctionLowerer,
  function : @bytecode.FunctionId,
  type_ : @buslane.Type,
  arguments : Array[@buslane.GenericArgument],
  values : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, formal_parameters, formal_result) = function_type_parts(
    type_,
  )
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="expected \{parameters.length()} generic arguments, got \{arguments.length()}",
    )
  }
  if formal_parameters.length() != values.length() {
    raise InvalidTypeApplication(
      detail="generic call argument count does not match its function type",
    )
  }
  let substitutions : Array[TypeArgumentBinding] = []
  for index, parameter in parameters {
    substitutions.push({ parameter, argument: arguments[index] })
  }
  let witnesses = []
  for substitution in substitutions {
    if self.image.requires_layout_witness(substitution.parameter) {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="runtime layout witnesses require type arguments",
        )
      }
      witnesses.push(self.layout_witness(type_))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = substitute_type(formal, substitutions)
    let adapted = self.adapt_local_value_with_substitutions(
      values[index],
      actual,
      formal,
      substitutions,
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let actual_result = substitute_type(formal_result, substitutions)
  if formal_result is Parameter(parameter) {
    let witness = self.adapter_witness(parameter, substitutions)
    let erased_result = self.fresh_erased_slot(witness, Owned)
    self.emit(
      CallDirect(function, None, witnesses, argument_slots, Some(erased_result)),
    )
    self.unerase_value(erased_result, actual_result)
  } else {
    let destination = self.fresh_optional_slot(formal_result)
    self.emit(
      CallDirect(function, None, witnesses, argument_slots, destination.0),
    )
    self.adapt_local_value_with_substitutions(
      destination.1,
      formal_result,
      actual_result,
      substitutions,
    )
  }
}

///|
fn FunctionLowerer::lower_generic_value_call(
  self : FunctionLowerer,
  callable : @vmcfg.ValueId,
  type_ : @buslane.Type,
  arguments : Array[@buslane.GenericArgument],
  values : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let (parameters, formal_parameters, formal_result) = function_type_parts(
    type_,
  )
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="expected \{parameters.length()} generic arguments, got \{arguments.length()}",
    )
  }
  if formal_parameters.length() != values.length() {
    raise InvalidTypeApplication(
      detail="generic call argument count does not match its function type",
    )
  }
  let substitutions : Array[TypeArgumentBinding] = []
  for index, parameter in parameters {
    substitutions.push({ parameter, argument: arguments[index] })
  }
  let witnesses = []
  for substitution in substitutions {
    if self.image.requires_layout_witness(substitution.parameter) {
      guard substitution.argument is TypeArgument(type_) else {
        raise InvalidTypeApplication(
          detail="runtime layout witnesses require type arguments",
        )
      }
      witnesses.push(self.layout_witness(type_))
    }
  }
  let argument_slots = []
  for index, formal in formal_parameters {
    let actual = substitute_type(formal, substitutions)
    let adapted = self.adapt_local_value_with_substitutions(
      values[index],
      actual,
      formal,
      substitutions,
    )
    match adapted {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let actual_result = substitute_type(formal_result, substitutions)
  if formal_result is Parameter(parameter) {
    let witness = self.adapter_witness(parameter, substitutions)
    let erased_result = self.fresh_erased_slot(witness, Owned)
    self.emit(
      CallValue(callable, witnesses, argument_slots, Some(erased_result)),
    )
    self.unerase_value(erased_result, actual_result)
  } else {
    let destination = self.fresh_optional_slot(formal_result)
    self.emit(CallValue(callable, witnesses, argument_slots, destination.0))
    self.adapt_local_value_with_substitutions(
      destination.1,
      formal_result,
      actual_result,
      substitutions,
    )
  }
}

///|
fn substitute_type(
  type_ : @buslane.Type,
  substitutions : Array[TypeArgumentBinding],
) -> @buslane.Type raise LoisvmLoweringError {
  match type_ {
    Parameter(parameter) => {
      for substitution in substitutions {
        if substitution.parameter == parameter {
          guard substitution.argument is TypeArgument(type_) else {
            raise InvalidTypeApplication(
              detail="an effect argument cannot substitute a value type",
            )
          }
          return type_
        }
      }
      type_
    }
    Apply(applied_constructor, arguments) =>
      Apply(
        substitute_type(applied_constructor, substitutions),
        arguments.map(argument => {
          match argument {
            TypeArgument(type_) =>
              TypeArgument(substitute_type(type_, substitutions))
            EffectArgument(effect) => EffectArgument(effect)
          }
        }),
      )
    Function(parameters, result, effect) =>
      Function(
        parameters.map(type_ => substitute_type(type_, substitutions)),
        substitute_type(result, substitutions),
        effect,
      )
    TypeLambda(parameters, body) => {
      let nested_substitutions = substitutions.filter(substitution => {
        !parameters.contains(substitution.parameter)
      })
      TypeLambda(parameters, substitute_type(body, nested_substitutions))
    }
    Forall(parameters, body) => {
      let nested_substitutions = substitutions.filter(substitution => {
        !parameters.contains(substitution.parameter)
      })
      Forall(parameters, substitute_type(body, nested_substitutions))
    }
    _ => type_
  }
}

///|
fn data_type_substitutions(
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Array[TypeArgumentBinding] raise LoisvmLoweringError {
  if parameters.length() != arguments.length() {
    raise InvalidTypeApplication(
      detail="data type expects \{parameters.length()} arguments, got \{arguments.length()}",
    )
  }
  let substitutions = []
  for index, parameter in parameters {
    substitutions.push({ parameter, argument: arguments[index] })
  }
  substitutions
}

///|
fn FunctionLowerer::lower_direct_call(
  self : FunctionLowerer,
  function : @bytecode.FunctionId,
  type_ : @buslane.Type,
  arguments : Array[LocalValue],
  environment : @vmcfg.ValueId?,
) -> LocalValue raise LoisvmLoweringError {
  let result_type = callable_result_type(type_)
  let argument_slots = []
  for argument in arguments {
    match argument {
      Unit => ()
      Slot(slot, _) => argument_slots.push(slot)
      _ =>
        raise UnsupportedExpression(detail="call argument is not materialized")
    }
  }
  let destination = self.fresh_optional_slot(result_type)
  self.emit(
    CallDirect(function, environment, [], argument_slots, destination.0),
  )
  destination.1
}

///|
fn FunctionLowerer::lower_intrinsic(
  self : FunctionLowerer,
  name : String,
  type_ : @buslane.Type,
  arguments : Array[LocalValue],
) -> LocalValue raise LoisvmLoweringError {
  let result_type = callable_result_type(type_)
  let slots = arguments.map(fn(argument) {
    match argument {
      Slot(slot, _) => slot
      _ => abort("intrinsic argument is not represented by a slot")
    }
  })
  let destination = self.fresh_slot(result_type)
  let instruction : @vmcfg.Instruction = match (name, slots) {
    ("%i64_add", [left, right]) => IntAdd(destination, left, right)
    ("%i64_sub", [left, right]) => IntSub(destination, left, right)
    ("%i64_mul", [left, right]) => IntMul(destination, left, right)
    ("%i64_div", [left, right]) => IntDiv(destination, left, right)
    ("%i64_rem", [left, right]) => IntRem(destination, left, right)
    ("%i64_neg", [source]) => IntNeg(destination, source)
    ("%i64_equal", [left, right]) => IntEq(destination, left, right)
    ("%i64_less", [left, right]) => IntLt(destination, left, right)
    ("%f64_add", [left, right]) => DoubleAdd(destination, left, right)
    ("%f64_sub", [left, right]) => DoubleSub(destination, left, right)
    ("%f64_mul", [left, right]) => DoubleMul(destination, left, right)
    ("%f64_div", [left, right]) => DoubleDiv(destination, left, right)
    ("%f64_neg", [source]) => DoubleNeg(destination, source)
    ("%f64_equal", [left, right]) => DoubleEq(destination, left, right)
    ("%f64_less", [left, right]) => DoubleLt(destination, left, right)
    ("%string_equal", [left, right]) => StringEq(destination, left, right)
    _ => raise UnsupportedIntrinsic(name~)
  }
  self.emit(instruction)
  Slot(destination, result_type)
}

///|
fn FunctionLowerer::fresh_optional_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> (@vmcfg.ValueId?, LocalValue) raise LoisvmLoweringError {
  if type_ == Primitive(Unit) {
    (None, Unit)
  } else {
    let slot = self.fresh_slot(type_)
    (Some(slot), Slot(slot, type_))
  }
}

///|
fn FunctionLowerer::fresh_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if type_ is Parameter(parameter) {
    return self.fresh_erased_slot(self.find_witness(parameter), Owned)
  }
  let slot : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push(slot_metadata(type_))
  slot
}

///|
fn FunctionLowerer::fresh_metadata(
  self : FunctionLowerer,
  metadata : @vmcfg.ValueMetadata,
) -> @vmcfg.ValueId {
  let value : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push(metadata)
  value
}

///|
fn FunctionLowerer::fresh_borrowed_slot(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if type_ is Parameter(parameter) {
    return self.fresh_erased_slot(self.find_witness(parameter), Borrowed)
  }
  let metadata = slot_metadata(type_)
  let ownership : @vmcfg.Ownership = match metadata.ownership {
    Trivial => Trivial
    Owned | Borrowed => Borrowed
  }
  let slot : @vmcfg.ValueId = { value: self.values.length() }
  self.values.push({ ..metadata, ownership, })
  slot
}

///|
fn FunctionLowerer::fresh_erased_slot(
  self : FunctionLowerer,
  witness : @vmcfg.ValueId,
  ownership : @vmcfg.Ownership,
) -> @vmcfg.ValueId {
  self.fresh_metadata({
    representation: I64,
    cleanup: OwnedErased,
    ownership,
    erased_companion: Some(witness),
  })
}

///|
fn FunctionLowerer::find_witness(
  self : FunctionLowerer,
  parameter : @buslane.TypeParameterId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  for binding in self.witnesses {
    if binding.parameter == parameter {
      return binding.value
    }
  }
  raise InvalidTypeApplication(detail="missing in-scope layout witness")
}

///|
fn FunctionLowerer::layout_witness(
  self : FunctionLowerer,
  type_ : @buslane.Type,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  if type_ is Parameter(parameter) {
    return self.find_witness(parameter)
  }
  let recipe : @bytecode.LayoutRecipe = match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) => Bool
    Primitive(Int) => Int
    Primitive(Double) => Double
    Primitive(String) => String
    Function(_, _, _) | Forall(_, _) => Callable
    Constructor(_) | Apply(_, _) => Reference
    _ => raise UnsupportedType(type_~)
  }
  let layout = self.image.intern_layout(recipe)
  let witness = self.fresh_metadata(layout_witness_metadata())
  self.emit(ConstLayout(witness, layout))
  witness
}

///|
fn FunctionLowerer::erase_value(
  self : FunctionLowerer,
  value : LocalValue,
  type_ : @buslane.Type,
  witness : @vmcfg.ValueId,
) -> @vmcfg.ValueId raise LoisvmLoweringError {
  let destination = self.fresh_erased_slot(witness, Owned)
  let materialized = self.materialize_local(value)
  match (materialized, type_) {
    (Unit, Primitive(Unit)) => self.emit(EraseUnit(destination))
    (
      Slot(source, _),
      Primitive(Bool)
      | Primitive(String)
      | Constructor(_)
      | Apply(_, _),
    ) => self.emit(EraseI32(destination, source))
    (Slot(source, _), Primitive(Int)) =>
      self.emit(EraseI64(destination, source))
    (Slot(source, _), Function(_, _, _) | Forall(_, _)) => {
      let (canonical_type, bindings) = self.canonical_callable_type(type_)
      guard self.make_callable_adapter(source, type_, canonical_type, bindings)
        is Slot(adapted, _) else {
        abort("callable adapter was not materialized")
      }
      self.emit(EraseI64(destination, adapted))
    }
    (Slot(source, _), Primitive(Double)) =>
      self.emit(EraseF64(destination, source))
    (Slot(source, Parameter(_)), Parameter(_)) =>
      self.emit(Move(destination, source))
    _ =>
      raise InvalidTypeApplication(
        detail="generic argument representation does not match its type",
      )
  }
  destination
}

///|
fn FunctionLowerer::unerase_value(
  self : FunctionLowerer,
  source : @vmcfg.ValueId,
  type_ : @buslane.Type,
) -> LocalValue raise LoisvmLoweringError {
  match type_ {
    Primitive(Unit) => {
      self.emit(UneraseUnit(source))
      Unit
    }
    Primitive(Bool) | Primitive(String) | Constructor(_) | Apply(_, _) => {
      let destination = self.fresh_slot(type_)
      self.emit(UneraseI32(destination, source))
      Slot(destination, type_)
    }
    Primitive(Int) => {
      let destination = self.fresh_slot(type_)
      self.emit(UneraseI64(destination, source))
      Slot(destination, type_)
    }
    Function(_, _, _) | Forall(_, _) => {
      let (canonical_type, bindings) = self.canonical_callable_type(type_)
      let canonical = self.fresh_slot(canonical_type)
      self.emit(UneraseI64(canonical, source))
      self.make_callable_adapter(canonical, canonical_type, type_, bindings)
    }
    Primitive(Double) => {
      let destination = self.fresh_slot(type_)
      self.emit(UneraseF64(destination, source))
      Slot(destination, type_)
    }
    Parameter(_) => Slot(source, type_)
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn slot_metadata(
  type_ : @buslane.Type,
) -> @vmcfg.ValueMetadata raise LoisvmLoweringError {
  match type_ {
    Primitive(Unit) => raise UnsupportedType(type_~)
    Primitive(Bool) =>
      {
        representation: I32,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(Int) =>
      {
        representation: I64,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(Double) =>
      {
        representation: F64,
        cleanup: Trivial,
        ownership: Trivial,
        erased_companion: None,
      }
    Primitive(String) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        ownership: Owned,
        erased_companion: None,
      }
    Function(_, _, _) | Forall(_, _) =>
      {
        representation: I64,
        cleanup: OwnedCallable,
        ownership: Owned,
        erased_companion: None,
      }
    Constructor(_) | Apply(_, _) =>
      {
        representation: I32,
        cleanup: OwnedRef,
        ownership: Owned,
        erased_companion: None,
      }
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn environment_metadata() -> @vmcfg.ValueMetadata {
  {
    representation: I32,
    cleanup: OwnedRef,
    ownership: Owned,
    erased_companion: None,
  }
}

///|
fn layout_witness_metadata() -> @vmcfg.ValueMetadata {
  {
    representation: I32,
    cleanup: Trivial,
    ownership: Trivial,
    erased_companion: None,
  }
}

///|
fn result_representation(
  type_ : @buslane.Type,
) -> @bytecode.ResultRepresentation raise LoisvmLoweringError {
  match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) | Primitive(String) | Constructor(_) | Apply(_, _) => I32
    Primitive(Int) | Function(_, _, _) | Forall(_, _) | Parameter(_) => I64
    Primitive(Double) => F64
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn ImageLowerer::intern_string(
  self : ImageLowerer,
  value : String,
) -> @bytecode.ConstantId raise LoisvmLoweringError {
  let bytes = @utf8.encode(value)
  for byte in bytes {
    if byte.to_int() > 0x7F {
      raise NonAsciiString(value~)
    }
  }
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
  id
}

///|
fn callable_result_type(
  type_ : @buslane.Type,
) -> @buslane.Type raise LoisvmLoweringError {
  match strip_forall(type_) {
    Function(_, result, _) => result
    _ => raise UnsupportedType(type_~)
  }
}

///|
fn runtime_member_index(
  payload_types : Array[@buslane.Type],
  source_index : Int,
) -> Int {
  let mut runtime_index = 0
  for index in 0..<source_index {
    if payload_types[index] != Primitive(Unit) {
      runtime_index += 1
    }
  }
  runtime_index
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

///|
fn is_scalar_intrinsic(name : String) -> Bool {
  match name {
    "%i64_add"
    | "%i64_sub"
    | "%i64_mul"
    | "%i64_div"
    | "%i64_rem"
    | "%i64_neg"
    | "%i64_equal"
    | "%i64_less"
    | "%f64_add"
    | "%f64_sub"
    | "%f64_mul"
    | "%f64_div"
    | "%f64_neg"
    | "%f64_equal"
    | "%f64_less"
    | "%string_equal" => true
    _ => false
  }
}

///|
fn scalar_double_constant(name : String) -> Int64? {
  match name {
    "%f64_inf" => Some((1.0 / 0.0).reinterpret_as_int64())
    "%f64_ninf" => Some((-1.0 / 0.0).reinterpret_as_int64())
    "%f64_nan" => Some((0.0 / 0.0).reinterpret_as_int64())
    _ => None
  }
}
