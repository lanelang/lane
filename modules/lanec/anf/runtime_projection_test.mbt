///|
test "runtime ANF projection preserves effect-aware source metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let io_type = @buslane.Type::Function(
    [Primitive(String)],
    Primitive(Unit),
    Builtin(Io),
  )
  let println = metadata.define_value("println", External, io_type)
  let source : @buslane.Program = { metadata, terms: [External(println)] }
  let runtime = @anf.lower_cps_core_to_runtime_anf(source).anf()
  debug_inspect(
    (
      source.metadata.value_info(println).map(info => info.type_),
      runtime.metadata.value_info(println).map(info => info.type_),
    ),
    content=(
      #|(
      #|  Some(Function([Primitive(String)], Primitive(Unit), Builtin(Io))),
      #|  Some(Function([Primitive(String)], Primitive(Unit), Empty)),
      #|)
    ),
  )
}
