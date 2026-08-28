///|
fn certify_physical_program_test(
  image : @physical.PhysicalProgram,
) -> @physical.VerifiedPhysicalProgram {
  match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => abort("invalid Physical Program fixture: \{Repr(error)}")
  }
}
