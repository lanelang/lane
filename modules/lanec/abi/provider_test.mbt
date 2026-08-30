///|
test "Basic ABI provider universes own identity lookup" {
  let types = BasicTypeProvider::all()
  let variants = BasicVariantProvider::all()
  assert_eq(types.map(provider => provider.qualified_name()), [
    "Basic.Data.Tuple.Tuple", "Basic.Data.List.List", "Basic.Data.Void.Void", "Basic.Wasm.Abi.WasmAddress",
    "Basic.Trait.Derive.Deriver", "Basic.Trait.Derive.Product", "Basic.Trait.Derive.Sum",
    "Basic.Trait.Iso.Iso", "Basic.Trait.Derive.TypeInfo", "Basic.Trait.Derive.FieldInfo",
    "Basic.Trait.Derive.VariantInfo",
  ])
  for provider in types {
    assert_eq(
      BasicTypeProvider::find(provider.module_path(), provider.type_name()),
      Some(provider),
    )
  }
  assert_eq(
    variants.map(provider => {
      "\{provider.owner().qualified_name()}::\{provider.variant_name()}"
    }),
    [
      "Basic.Data.Tuple.Tuple::tuple", "Basic.Data.List.List::empty", "Basic.Data.List.List::cons",
    ],
  )
  for provider in variants {
    assert_eq(
      BasicVariantProvider::find(provider.owner(), provider.variant_name()),
      Some(provider),
    )
  }
}
