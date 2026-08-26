///|
fn runtime_import_value_kind(
  kind : @abi.ValueKind,
) -> @lane_runtime.RuntimeValueKind {
  match kind {
    Unit => Unit
    Bool => Bool
    I64 => I64
    F32 => F32
    F64 => F64
    String => String
    Opaque => Opaque
  }
}
