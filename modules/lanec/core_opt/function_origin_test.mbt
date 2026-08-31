///|
test "CPS Core optimization preserves certification and function origins" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Empty),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Literal(Unit),
        }),
      ),
    ],
  }
  let cps_core = @effect_lowering.lower_effects(program.certify().unwrap()).unwrap()
  let optimized = @core_opt.optimize_cps_core(cps_core, entry, []).unwrap()
  let (snapshot, origins) = optimized.snapshot()
  assert_true(@buslane.verify_program(snapshot).is_ok())
  guard snapshot.terms is [Let(actual_entry, Function(function))] else {
    fail("expected the optimized entry function")
  }
  assert_eq(actual_entry, entry)
  assert_true(origins.origin(function) is Some(_))
}
