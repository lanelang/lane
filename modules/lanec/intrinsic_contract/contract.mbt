///|
pub fn type_of(name : String) -> @types.Type? {
  match name {
    "%i64_add" | "%i64_sub" | "%i64_mul" | "%i64_div" | "%i64_rem" =>
      Some(binary(Int, Int))
    "%i64_neg" => Some(unary(Int, Int))
    "%i64_equal" | "%i64_less" => Some(binary(Int, Bool))
    "%f64_add" | "%f64_sub" | "%f64_mul" | "%f64_div" =>
      Some(binary(Double, Double))
    "%f64_neg" => Some(unary(Double, Double))
    "%f64_equal" | "%f64_less" => Some(binary(Double, Bool))
    "%f64_inf" | "%f64_ninf" | "%f64_nan" => Some(Primitive(Double))
    "%string_equal" => Some(binary(String, Bool))
    _ => None
  }
}

///|
fn unary(
  parameter : @types.PrimitiveType,
  result : @types.PrimitiveType,
) -> @types.Type {
  Function([Primitive(parameter)], Primitive(result), Empty)
}

///|
fn binary(
  parameter : @types.PrimitiveType,
  result : @types.PrimitiveType,
) -> @types.Type {
  Function(
    [Primitive(parameter), Primitive(parameter)],
    Primitive(result),
    Empty,
  )
}
