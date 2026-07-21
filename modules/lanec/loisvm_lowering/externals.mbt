///|
fn runtime_import_value_kind(
  kind : @abi.ValueKind,
) -> @bytecode.RuntimeValueKind {
  match kind {
    Unit => Unit
    Bool => Bool
    Int => Int
    Double => Double
    String => String
    Opaque => Opaque
  }
}
