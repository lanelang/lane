///|
fn runtime_import_value_kind(
  metadata : @buslane.MetadataRegistry,
  type_ : @buslane.Type,
) -> @bytecode.RuntimeValueKind? {
  match type_ {
    Primitive(Unit) => Some(@bytecode.RuntimeValueKind::Unit)
    Primitive(Bool) => Some(@bytecode.RuntimeValueKind::Bool)
    Primitive(Int) => Some(@bytecode.RuntimeValueKind::Int)
    Primitive(Double) => Some(@bytecode.RuntimeValueKind::Double)
    Primitive(String) => Some(@bytecode.RuntimeValueKind::String)
    Constructor(type_id) =>
      match metadata.type_info(type_id) {
        Some(info) if info.flavor is @buslane.TypeFlavor::External =>
          Some(@bytecode.RuntimeValueKind::Opaque)
        _ => None
      }
    _ => None
  }
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
