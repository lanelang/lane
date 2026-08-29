///|
fn certify_physical_program_wbtest(
  image : @physical.PhysicalProgram,
) -> @physical.VerifiedPhysicalProgram {
  match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => abort("invalid Physical Program fixture: \{Repr(error)}")
  }
}
