///|
fn empty_module_interface(
  module_path : String,
  source_id : String?,
  hints? : Array[OptimizationHint] = [],
) -> ModuleInterface {
  {
    module_path,
    source_id,
    type_references: [],
    effect_references: [],
    types: [],
    effects: [],
    type_aliases: [],
    values: [],
    optimization_hints: hints,
  }
}

///|
test "semantic fingerprint ignores source identity" {
  guard empty_module_interface("A", Some("old-A.lane")).semantic_fingerprint()
    is Ok(old_fingerprint) else {
    abort("expected old fingerprint")
  }
  guard empty_module_interface("A", Some("new-A.lane")).semantic_fingerprint()
    is Ok(new_fingerprint) else {
    abort("expected new fingerprint")
  }
  assert_eq(old_fingerprint, new_fingerprint)
}

///|
test "semantic fingerprint tracks exported semantics" {
  guard empty_module_interface("A", None).semantic_fingerprint() is Ok(initial) else {
    abort("expected initial fingerprint")
  }
  guard empty_module_interface("A", None, hints=[{ name: "specialize" }]).semantic_fingerprint()
    is Ok(changed_hint) else {
    abort("expected hint fingerprint")
  }
  guard empty_module_interface("B", None).semantic_fingerprint()
    is Ok(changed_module) else {
    abort("expected module fingerprint")
  }
  assert_false(initial == changed_hint)
  assert_false(initial == changed_module)
}
