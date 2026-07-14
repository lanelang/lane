///|
fn runtime_import_signature_supported(type_ : @buslane.Type) -> Bool {
  guard type_ is Function(parameters, result, _) else { return false }
  parameters.all(runtime_import_primitive_type) &&
  runtime_import_primitive_type(result)
}

///|
fn runtime_import_primitive_type(type_ : @buslane.Type) -> Bool {
  type_ is Primitive(Unit) ||
  type_ is Primitive(Bool) ||
  type_ is Primitive(Int) ||
  type_ is Primitive(Double) ||
  type_ is Primitive(String)
}

///|
fn is_scalar_intrinsic(name : String) -> Bool {
  match name {
    "%i64_add"
    | "%i64_sub"
    | "%i64_mul"
    | "%i64_div"
    | "%i64_rem"
    | "%i64_neg"
    | "%i64_equal"
    | "%i64_less"
    | "%f64_add"
    | "%f64_sub"
    | "%f64_mul"
    | "%f64_div"
    | "%f64_neg"
    | "%f64_equal"
    | "%f64_less"
    | "%string_equal" => true
    _ => false
  }
}

///|
fn scalar_double_constant(name : String) -> Int64? {
  match name {
    "%f64_inf" => Some((1.0 / 0.0).reinterpret_as_int64())
    "%f64_ninf" => Some((-1.0 / 0.0).reinterpret_as_int64())
    "%f64_nan" => Some((0.0 / 0.0).reinterpret_as_int64())
    _ => None
  }
}
