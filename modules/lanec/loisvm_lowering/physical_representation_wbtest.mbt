///|
fn test_scalar_shape() -> PhysicalValueShape {
  Slot(Value({ representation: I64, cleanup: Trivial, kind: ScalarValue }))
}

///|
fn test_erased_shape() -> PhysicalValueShape {
  Slot(Value({ representation: I64, cleanup: OwnedErased, kind: ErasedValue }))
}

///|
test "represented value flow rejects unequal shapes without a bridge" {
  let image = test_image_lowerer(@buslane.MetadataRegistry::MetadataRegistry())
  let physical = PhysicalRepresentationPlan::new()
  let flow : PhysicalValueFlowPlan = {
    source: physical.intern(test_scalar_shape()),
    target: physical.intern(test_erased_shape()),
    bridge: None,
  }
  let result : Result[Unit, LoisvmLoweringError] = Ok(
    image.verify_physical_value_flow(physical, flow),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(RepresentationSpecializationInvariant(detail=_)))
}

///|
test "represented value flow accepts an explicit concrete-to-erased bridge" {
  let image = test_image_lowerer(@buslane.MetadataRegistry::MetadataRegistry())
  let physical = PhysicalRepresentationPlan::new()
  let flow : PhysicalValueFlowPlan = {
    source: physical.intern(test_scalar_shape()),
    target: physical.intern(test_erased_shape()),
    bridge: Some(Erase({ evidence: StaticLayout(I64), callable: None })),
  }
  image.verify_physical_value_flow(physical, flow)
}
