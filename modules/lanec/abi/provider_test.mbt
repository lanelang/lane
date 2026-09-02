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
  let values = BasicValueProvider::all()
  assert_eq(values.map(provider => provider.qualified_name()), [
    "Basic.Ops.op_add", "Basic.Ops.op_sub", "Basic.Ops.op_mul", "Basic.Ops.op_div",
    "Basic.Ops.op_rem", "Basic.Ops.op_neg", "Basic.Ops.op_equal", "Basic.Ops.op_not_equal",
    "Basic.Ops.op_less", "Basic.Ops.op_less_eq", "Basic.Ops.op_greater", "Basic.Ops.op_greater_eq",
    "Basic.Ops.op_and", "Basic.Ops.op_or", "Basic.Ops.op_not",
  ])
  for provider in values {
    assert_eq(
      BasicValueProvider::find(provider.module_path(), provider.value_name()),
      Some(provider),
    )
  }
}
