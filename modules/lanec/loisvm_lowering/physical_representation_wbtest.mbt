///|
fn test_scalar_shape() -> PhysicalValueShape {
  Slot(Value({ representation: I64, cleanup: Trivial, kind: ScalarValue, }))
}

///|
fn test_erased_shape() -> PhysicalValueShape {
  Slot(Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue, }))
}

///|
fn test_contract(shape : PhysicalValueShapeId) -> PhysicalValueContract {
  { shape, callable_interface: None, fields: [], }
}

///|
fn test_flow(
  source : PhysicalValueShapeId,
  target : PhysicalValueShapeId,
  bridge : PhysicalValueBridge?,
) -> PhysicalValueFlowPlan {
  { source: test_contract(source), target: test_contract(target), bridge, }
}

///|
fn test_function_interface(
  parameter_types : Array[@anf.RuntimeType],
  result_type : @anf.RuntimeType,
  invocation : CanonicalCallableAbi,
) -> PhysicalCallableInterface {
  {
    evidence_parameters: [],
    parameter_types,
    result_type,
    invocation,
    parameters: invocation.parameters.map(parameter => Slot(parameter)),
    parameter_callables: parameter_types.map(_ => None),
    result_callable: None,
  }
}

///|
test "Physical ANF value flow rejects unequal shapes without a bridge" {
  let image = test_image_lowerer(@buslane.MetadataRegistry::MetadataRegistry())
  let physical = PhysicalAnfProgram::new()
  let flow = test_flow(
    physical.intern(test_scalar_shape()),
    physical.intern(test_erased_shape()),
    None,
  )
  let result : Result[Unit, LoisvmLoweringError] = Ok(
    image.verify_physical_value_flow(physical, flow),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical ANF value flow accepts an explicit concrete-to-erased bridge" {
  let image = test_image_lowerer(@buslane.MetadataRegistry::MetadataRegistry())
  let physical = PhysicalAnfProgram::new()
  let flow = test_flow(
    physical.intern(test_scalar_shape()),
    physical.intern(test_erased_shape()),
    Some(Erase({ evidence: StaticLayout(I64), callable: None, })),
  )
  image.verify_physical_value_flow(physical, flow)
}

///|
test "Physical ANF verifier rejects an illegal binding flow" {
  let image = test_image_lowerer(@buslane.MetadataRegistry::MetadataRegistry())
  let physical = PhysicalAnfProgram::new()
  let scalar = physical.intern(test_scalar_shape())
  let erased = physical.intern(test_erased_shape())
  let temp : @anf.AnfTempId = { index: 0, }
  let type_ = @anf.RuntimeType::Scalar(@anf.RuntimeScalarType::I64)
  let atom : PhysicalAnfAtom = {
    atom: Literal(I64(1L)),
    contract: test_contract(scalar),
    callable: None,
    allocation: None,
  }
  let interface = test_function_interface([], type_, {
    witnesses: [],
    parameters: [],
    result: test_scalar_shape().canonical_result(),
  })
  physical.add_function({ value: 1, }, {
    interface,
    evidence_parameters: [],
    substitutions: RuntimeSubstitution::new(),
    specialized_parameters: [],
    capture: CallableCaptureContract::empty(),
    parameters: [],
    recursive_functions: [],
    result_type: type_,
    result: test_flow(scalar, scalar, None),
    body: Let(
      {
        binding: Temp(temp~, type_~, rhs=Atom(Literal(I64(1L)))),
        rhs: Atom(atom, {
          binding: Temp(temp),
          target_type: type_,
          flow: test_flow(scalar, erased, None),
        }),
        result: test_contract(erased),
      },
      Atom(atom),
    ),
  })
  let result : Result[Unit, LoisvmLoweringError] = Ok(
    image.verify_physical_anf(physical),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical ANF atom cannot claim a shape different from its producer" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_value("value", Parameter, Primitive(I64))
  let image = test_image_lowerer(metadata)
  let physical = PhysicalAnfProgram::new()
  let scalar = physical.intern(test_scalar_shape())
  let erased = physical.intern(test_erased_shape())
  let type_ = @anf.RuntimeType::Scalar(@anf.RuntimeScalarType::I64)
  let interface = test_function_interface([type_], type_, {
    witnesses: [],
    parameters: [test_scalar_shape().canonical_result()],
    result: test_erased_shape().canonical_result(),
  })
  physical.add_function({ value: 1, }, {
    interface,
    evidence_parameters: [],
    substitutions: RuntimeSubstitution::new(),
    specialized_parameters: [],
    capture: CallableCaptureContract::empty(),
    parameters: [
      { binding: Value(parameter), type_, contract: test_contract(scalar), },
    ],
    recursive_functions: [],
    result_type: type_,
    result: test_flow(erased, erased, None),
    body: Atom({
      atom: Ref(parameter),
      contract: test_contract(erased),
      callable: None,
      allocation: None,
    }),
  })
  let result : Result[Unit, LoisvmLoweringError] = Ok(
    image.verify_physical_anf(physical),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}
