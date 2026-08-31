///|
fn ImageLowerer::lower_runtime_import_adapter(
  self : ImageLowerer,
  plan : RuntimeImportAdapterPlan,
) -> @vmcfg.FunctionBody raise PhysicalLoweringError {
  let (_, parameter_types, result_type) = function_type_parts(plan.source_type)
  if parameter_types.length() != plan.contract.parameters.length() {
    raise RepresentationElaborationInvariant(
      detail="verified runtime import parameter contract has the wrong arity",
    )
  }
  let lowerer : FunctionLowerer = {
    image: self,
    values: [],
    blocks: [{ parameters: [], instructions: [], terminator: None, }],
    current_block: 0,
    bindings: [],
    temps: [],
    environment: None,
    witnesses: [],
    substitutions: RuntimeSubstitution::new(),
  }
  let input_slots = []
  let import_arguments : Array[@vmcfg.RuntimeImportArgument] = []
  for index, parameter_type in parameter_types {
    match plan.contract.parameters[index] {
      ErasedUnit =>
        if parameter_type != Unit {
          raise RepresentationElaborationInvariant(
            detail="verified erased runtime import parameter is not Unit",
          )
        }
      Direct(_) => {
        let parameter = lowerer.fresh_slot(parameter_type)
        input_slots.push(parameter)
        import_arguments.push(Direct(parameter))
      }
      GuestAddress => {
        let parameter = lowerer.fresh_slot(parameter_type)
        input_slots.push(parameter)
        let (storage, offset) = lowerer.project_wasm_address(
          parameter, parameter_type,
        )
        import_arguments.push(GuestAddress(storage, offset))
      }
    }
  }
  let destination = lowerer.fresh_optional_slot(result_type)
  lowerer.emit(
    CallRuntimeImport(plan.import_function, import_arguments, destination.0),
  )
  let terminator : @vmcfg.Terminator = match destination.1 {
    Unit => Return(None)
    Slot(result, _) => Return(Some(result))
    _ =>
      raise RepresentationElaborationInvariant(
        detail="runtime import adapter produced an invalid result",
      )
  }
  lowerer.terminate(terminator)
  {
    values: lowerer.values,
    inputs: { environment: None, witnesses: [], user_parameters: input_slots, },
    result: self.result_abi(result_type),
    blocks: [
      {
        parameters: [],
        instructions: lowerer.blocks[0].instructions,
        terminator,
      },
    ],
  }
}

///|
fn FunctionLowerer::project_wasm_address(
  self : FunctionLowerer,
  address : @vmcfg.ValueId,
  type_ : @anf.RuntimeType,
) -> (@vmcfg.ValueId, @vmcfg.ValueId) raise PhysicalLoweringError {
  guard type_ is Data(owner, _) else {
    raise RepresentationElaborationInvariant(
      detail="verified guest address parameter is not a data object",
    )
  }
  let type_info = self.image.metadata.verified_type_info(owner)
  guard type_info.constructors is [data_constructor] else {
    raise RepresentationElaborationInvariant(
      detail="verified guest address type does not have one constructor",
    )
  }
  let constructor_info = self.image.metadata.verified_data_constructor_info(
    data_constructor,
  )
  guard constructor_info.payload_types == [ByteBuffer, Scalar(I32)] else {
    raise RepresentationElaborationInvariant(
      detail="verified guest address object has the wrong runtime fields",
    )
  }
  let shape = self.image.data_shape(data_constructor, constructor_info)
  let storage = self.fresh_borrowed_slot(ByteBuffer)
  self.emit(
    BorrowField(shape, address, 0, {
      value_destination: storage,
      witness_destination: None,
    }),
  )
  let offset = self.fresh_slot(Scalar(I32))
  self.emit(
    BorrowField(shape, address, 1, {
      value_destination: offset,
      witness_destination: None,
    }),
  )
  (storage, offset)
}
