///|
test "special float intrinsics use deterministic IEEE bit patterns" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let f32_type = @buslane.Type::Primitive(F32)
  let f64_type = @buslane.Type::Primitive(F64)
  let f32_inf = metadata.define_value("f32_inf", External, f32_type)
  let f32_ninf = metadata.define_value("f32_ninf", External, f32_type)
  let f32_nan = metadata.define_value("f32_nan", External, f32_type)
  let f64_inf = metadata.define_value("f64_inf", External, f64_type)
  let f64_ninf = metadata.define_value("f64_ninf", External, f64_type)
  let f64_nan = metadata.define_value("f64_nan", External, f64_type)
  let image = test_image_lowerer(metadata, [])
  image.plan_intrinsic(f32_inf, {
    value: f32_inf,
    intrinsic: F32Inf,
    type_: f32_type,
  })
  image.plan_intrinsic(f32_ninf, {
    value: f32_ninf,
    intrinsic: F32NegativeInf,
    type_: f32_type,
  })
  image.plan_intrinsic(f32_nan, {
    value: f32_nan,
    intrinsic: F32Nan,
    type_: f32_type,
  })
  image.plan_intrinsic(f64_inf, {
    value: f64_inf,
    intrinsic: F64Inf,
    type_: f64_type,
  })
  image.plan_intrinsic(f64_ninf, {
    value: f64_ninf,
    intrinsic: F64NegativeInf,
    type_: f64_type,
  })
  image.plan_intrinsic(f64_nan, {
    value: f64_nan,
    intrinsic: F64Nan,
    type_: f64_type,
  })
  assert_true(
    image.globals
    is [
      {
        value: { index: 0 },
        lowered: FloatConstant(2139095040, Primitive(F32)),
      },
      { value: { index: 1 }, lowered: FloatConstant(-8388608, Primitive(F32)) },
      {
        value: { index: 2 },
        lowered: FloatConstant(2143289344, Primitive(F32)),
      },
      {
        value: { index: 3 },
        lowered: DoubleConstant(9218868437227405312L, Primitive(F64)),
      },
      {
        value: { index: 4 },
        lowered: DoubleConstant(-4503599627370496L, Primitive(F64)),
      },
      {
        value: { index: 5 },
        lowered: DoubleConstant(9221120237041090560L, Primitive(F64)),
      },
    ],
  )
}
