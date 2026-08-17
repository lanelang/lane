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
  let image = test_image_lowerer(metadata)
  image.plan_intrinsic(
    f32_inf,
    @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
      f32_inf,
      F32Inf,
      f32_type,
    ),
  )
  image.plan_intrinsic(
    f32_ninf,
    @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
      f32_ninf,
      F32NegativeInf,
      f32_type,
    ),
  )
  image.plan_intrinsic(
    f32_nan,
    @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
      f32_nan,
      F32Nan,
      f32_type,
    ),
  )
  image.plan_intrinsic(
    f64_inf,
    @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
      f64_inf,
      F64Inf,
      f64_type,
    ),
  )
  image.plan_intrinsic(
    f64_ninf,
    @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
      f64_ninf,
      F64NegativeInf,
      f64_type,
    ),
  )
  image.plan_intrinsic(
    f64_nan,
    @buslane_lowering.BuslaneBuiltinExternal::from_intrinsic(
      f64_nan,
      F64Nan,
      f64_type,
    ),
  )
  assert_true(
    image.globals
    is [
      { value: { index: 0 }, lowered: FloatConstant(2139095040, Scalar(F32)) },
      { value: { index: 1 }, lowered: FloatConstant(-8388608, Scalar(F32)) },
      { value: { index: 2 }, lowered: FloatConstant(2143289344, Scalar(F32)) },
      {
        value: { index: 3 },
        lowered: DoubleConstant(9218868437227405312L, Scalar(F64)),
      },
      {
        value: { index: 4 },
        lowered: DoubleConstant(-4503599627370496L, Scalar(F64)),
      },
      {
        value: { index: 5 },
        lowered: DoubleConstant(9221120237041090560L, Scalar(F64)),
      },
    ],
  )
}
