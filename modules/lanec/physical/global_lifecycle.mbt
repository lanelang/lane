///|
pub(all) struct GlobalLifecycleRoot {
  global : GlobalId
  companion : GlobalId?
  cleanup : Cleanup
  owned_ordinal : Int?
} derive(Debug, Eq)

///|
pub(all) struct GlobalLifecyclePlan {
  roots : Array[GlobalLifecycleRoot]
  root_ordinals : Array[Int]
  owned_roots : Array[GlobalLifecycleRoot]
} derive(Debug, Eq)

///|
fn PhysicalProgram::global_lifecycle_plan(
  self : PhysicalProgram,
) -> GlobalLifecyclePlan {
  let roots : Array[GlobalLifecycleRoot] = []
  let root_ordinals = Array::make(self.globals.length(), -1)
  let owned_roots : Array[GlobalLifecycleRoot] = []
  for index, metadata in self.globals {
    let global : GlobalId = { value: index, }
    let is_companion = index + 1 < self.globals.length() &&
      self.globals[index + 1].erased_companion == Some(global)
    if !is_companion {
      let owned_ordinal = if metadata.cleanup is Trivial {
        None
      } else {
        Some(owned_roots.length())
      }
      let root = {
        global,
        companion: metadata.erased_companion,
        cleanup: metadata.cleanup,
        owned_ordinal,
      }
      let root_ordinal = roots.length()
      root_ordinals[index] = root_ordinal
      if metadata.erased_companion is Some(companion) {
        root_ordinals[companion.value] = root_ordinal
      }
      roots.push(root)
      if owned_ordinal is Some(_) {
        owned_roots.push(root)
      }
    }
  }
  { roots, root_ordinals, owned_roots, }
}

///|
pub struct VerifiedPhysicalProgram {
  priv image : PhysicalProgram
  priv global_lifecycle : GlobalLifecyclePlan
} derive(Debug, Eq)

///|
pub fn VerifiedPhysicalProgram::image(
  self : VerifiedPhysicalProgram,
) -> PhysicalProgram {
  self.image
}

///|
pub fn VerifiedPhysicalProgram::global_lifecycle(
  self : VerifiedPhysicalProgram,
) -> GlobalLifecyclePlan {
  self.global_lifecycle
}
