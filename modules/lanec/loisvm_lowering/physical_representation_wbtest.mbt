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
  transition_site? : PhysicalRepresentationTransitionSite? = None,
) -> PhysicalValueFlowPlan {
  {
    source: test_contract(source),
    target: test_contract(target),
    bridge,
    transition_site,
  }
}

///|
fn test_function_interface(
  physical : PhysicalAnfProgram,
  parameter_types : Array[@anf.RuntimeType],
  result_type : @anf.RuntimeType,
  invocation : PhysicalCallableContract,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  let parameters = invocation.parameters.map(parameter => {
    PhysicalCallableParameterProjection::Slot(parameter)
  })
  let invocation = physical.callable_contracts.intern(invocation)
  {
    evidence_parameters: [],
    evidence_arguments: [],
    parameter_types,
    result_type,
    invocation,
    callable_target: None,
    parameters,
    parameter_callable_targets: parameter_types.map(_ => None),
    result_callable_target: None,
  }
}

///|
test "Physical ANF value flow rejects unequal shapes without a bridge" {
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let flow = test_flow(
    physical.intern(test_scalar_shape()),
    physical.intern(test_erased_shape()),
    None,
  )
  let result : Result[Unit, LoisvmLoweringError] = Ok(
    physical.verify_value_flow(flow),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical ANF value flow accepts an explicit concrete-to-erased bridge" {
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let source = physical.intern(test_scalar_shape())
  let target = physical.intern(test_erased_shape())
  let transition = physical.representation_transitions.intern({
    source: test_scalar_shape().canonical_result(),
    target: test_erased_shape().canonical_result(),
    kind: Erase,
  })
  let flow = test_flow(
    source,
    target,
    Some(
      Erase({
        evidence: StaticLayout({ recipe: I64, layout: { value: 1, }, }),
        callable: None,
      }),
    ),
    transition_site=Some({
      transition,
      boundary: AtomBinding,
      binding: None,
      ordinal: None,
    }),
  )
  physical.verify_value_flow(flow)
}

///|
test "Physical ANF verifier rejects an illegal binding flow" {
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let scalar = physical.intern(test_scalar_shape())
  let erased = physical.intern(test_erased_shape())
  let temp : @anf.AnfTempId = { index: 0, }
  let type_ = @anf.RuntimeType::Scalar(@anf.RuntimeScalarType::I64)
  let atom : PhysicalAnfAtom = {
    producer: PhysicalAnfAtomProducer::Literal(I64(1L)),
    contract: test_contract(scalar),
  }
  let interface = test_function_interface(physical, [], type_, {
    witnesses: [],
    parameters: [],
    result: test_scalar_shape().canonical_result(),
  })
  ignore(physical.callable_contracts.canonicalize())
  physical.add_function({ value: 1, }, {
    interface,
    evidence_parameters: [],
    capture: CallableCaptureContract::empty(),
    parameters: [],
    recursive_functions: [],
    result: test_flow(scalar, scalar, None),
    body: Let(
      {
        binding: Temp(temp~, type_~, rhs=Atom(Literal(I64(1L)))),
        rhs: Atom(atom, {
          binding: Temp(temp),
          flow: test_flow(scalar, erased, None),
        }),
        result: test_contract(erased),
      },
      Atom(atom),
    ),
  })
  let result : Result[VerifiedPhysicalAnfProgram, LoisvmLoweringError] = Ok(
    physical.verify(),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical ANF atom cannot claim a shape different from its producer" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_value("value", Parameter, Primitive(I64))
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let scalar = physical.intern(test_scalar_shape())
  let erased = physical.intern(test_erased_shape())
  let type_ = @anf.RuntimeType::Scalar(@anf.RuntimeScalarType::I64)
  let interface = test_function_interface(physical, [type_], type_, {
    witnesses: [],
    parameters: [test_scalar_shape().canonical_result()],
    result: test_erased_shape().canonical_result(),
  })
  ignore(physical.callable_contracts.canonicalize())
  physical.add_function({ value: 1, }, {
    interface,
    evidence_parameters: [],
    capture: CallableCaptureContract::empty(),
    parameters: [
      {
        binding: Value(parameter),
        contract: test_contract(scalar),
        erased_evidence: None,
        field_erased_evidence: [],
      },
    ],
    recursive_functions: [],
    result: test_flow(erased, erased, None),
    body: Atom({
      producer: Binding(Value(parameter)),
      contract: test_contract(erased),
    }),
  })
  let result : Result[VerifiedPhysicalAnfProgram, LoisvmLoweringError] = Ok(
    physical.verify(),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical ANF global cannot claim a shape different from its producer" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(F32))
  let physical = PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new())
  let scalar = physical.intern(test_scalar_shape())
  physical.add_global(value, {
    producer: PhysicalFloatConstant(0),
    contract: test_contract(scalar),
  })
  let result : Result[VerifiedPhysicalAnfProgram, LoisvmLoweringError] = Ok(
    physical.verify(),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical ANF owns canonical function emission order" {
  let physical = {
    ..PhysicalAnfProgram::new(PhysicalCallableContractCatalog::new()),
    emissions: [
      {
        function: { value: 2, },
        body: PhysicalFunctionBodyPlan::Function,
        origin: CallableAdapter(transition={ index: 0, }),
      },
    ],
  }
  let result : Result[VerifiedPhysicalAnfProgram, LoisvmLoweringError] = Ok(
    physical.verify(),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "Physical match representation owns its alternative universe" {
  assert_true(PhysicalMatchRepresentation::Bool.accepts(Literal(Bool(true))))
  assert_false(PhysicalMatchRepresentation::Bool.accepts(Literal(I32(1))))
  assert_true(
    PhysicalMatchRepresentation::Literal(I32).accepts(Literal(Char(65))),
  )
  assert_false(
    PhysicalMatchRepresentation::Literal(I32).accepts(Literal(I64(1L))),
  )
  assert_true(PhysicalMatchRepresentation::Callable.accepts(Default))
  assert_false(PhysicalMatchRepresentation::Callable.accepts(Literal(Unit)))
}
