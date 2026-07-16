///|
fn id_doc(prefix : String, index : Int) -> Document {
  text("\{prefix}#\{index}")
}

///|
pub impl @prettyprinter.Pretty for TypeSymbolId with fn pretty(
  id : TypeSymbolId,
) {
  id_doc("type", id.index)
}

///|
pub impl @prettyprinter.Pretty for TypeParameterId with fn pretty(
  id : TypeParameterId,
) {
  id_doc("tparam", id.index)
}

///|
pub impl @prettyprinter.Pretty for TypeMemberSymbolId with fn pretty(
  id : TypeMemberSymbolId,
) {
  id_doc("tmember", id.index)
}

///|
pub impl @prettyprinter.Pretty for ValueSymbolId with fn pretty(
  id : ValueSymbolId,
) {
  id_doc("value", id.index)
}

///|
pub impl @prettyprinter.Pretty for FieldSymbolId with fn pretty(
  id : FieldSymbolId,
) {
  id_doc("field", id.index)
}

///|
pub impl @prettyprinter.Pretty for VariantSymbolId with fn pretty(
  id : VariantSymbolId,
) {
  id_doc("variant", id.index)
}

///|
pub impl @prettyprinter.Pretty for EffectSymbolId with fn pretty(
  id : EffectSymbolId,
) {
  id_doc("effect", id.index)
}

///|
pub impl @prettyprinter.Pretty for OperationSymbolId with fn pretty(
  id : OperationSymbolId,
) {
  id_doc("operation", id.index)
}

///|
pub impl @prettyprinter.Pretty for NominalTypeKind with fn pretty(
  kind : NominalTypeKind,
) {
  match kind {
    Struct => text("struct")
    Enum => text("enum")
    External => text("external")
  }
}

///|
pub impl @prettyprinter.Pretty for EffectFlavor with fn pretty(
  flavor : EffectFlavor,
) {
  match flavor {
    Algebraic => text("algebraic")
    External => text("external")
  }
}

///|
pub impl @prettyprinter.Pretty for ValueSymbolKind with fn pretty(
  kind : ValueSymbolKind,
) {
  match kind {
    TopLevelValue => text("top_value")
    TopLevelFunction => text("top_function")
    Parameter => text("parameter")
    LocalBinding => text("local_binding")
    LocalFunction => text("local_function")
    PatternBinder => text("pattern_binder")
  }
}

///|
pub impl @prettyprinter.Pretty for TypeSymbolMetadata with fn pretty(
  metadata : TypeSymbolMetadata,
) {
  metadata.id.pretty() +
  space +
  metadata.kind.pretty() +
  space +
  text("\{metadata.name}/\{metadata.arity}")
}

///|
pub impl @prettyprinter.Pretty for TypeParameterMetadata with fn pretty(
  metadata : TypeParameterMetadata,
) {
  metadata.id.pretty() + space + text(metadata.name)
}

///|
pub impl @prettyprinter.Pretty for TypeMemberSymbolMetadata with fn pretty(
  metadata : TypeMemberSymbolMetadata,
) {
  metadata.id.pretty() +
  space +
  text("owner=") +
  metadata.owner.pretty() +
  space +
  text("parameter=") +
  metadata.type_parameter.pretty() +
  space +
  text(metadata.name) +
  space +
  text("index=\{metadata.index}")
}

///|
pub impl @prettyprinter.Pretty for ValueSymbolMetadata with fn pretty(
  metadata : ValueSymbolMetadata,
) {
  metadata.id.pretty() +
  space +
  metadata.kind.pretty() +
  space +
  text(metadata.name)
}

///|
pub impl @prettyprinter.Pretty for FieldSymbolMetadata with fn pretty(
  metadata : FieldSymbolMetadata,
) {
  metadata.id.pretty() +
  space +
  text("owner=") +
  metadata.owner.pretty() +
  space +
  text(metadata.name) +
  space +
  text("index=\{metadata.index}")
}

///|
pub impl @prettyprinter.Pretty for VariantSymbolMetadata with fn pretty(
  metadata : VariantSymbolMetadata,
) {
  metadata.id.pretty() +
  space +
  text("owner=") +
  metadata.owner.pretty() +
  space +
  text(metadata.name) +
  space +
  text("index=\{metadata.index}") +
  space +
  text("payloads=\{metadata.payload_count}")
}

///|
pub impl @prettyprinter.Pretty for EffectSymbolMetadata with fn pretty(
  metadata : EffectSymbolMetadata,
) {
  metadata.id.pretty() + space + text("\{metadata.name}/\{metadata.arity}")
}

///|
pub impl @prettyprinter.Pretty for OperationSymbolMetadata with fn pretty(
  metadata : OperationSymbolMetadata,
) {
  metadata.id.pretty() +
  space +
  text("owner=") +
  metadata.owner.pretty() +
  space +
  text(metadata.name) +
  space +
  text("index=\{metadata.index}") +
  space +
  text("payloads=\{metadata.payload_count}")
}

///|
pub impl @prettyprinter.Pretty for SymbolRegistry with fn pretty(
  registry : SymbolRegistry,
) {
  let sections = [
    @pretty.section("types", registry.types.map(TypeSymbolMetadata::pretty)),
    @pretty.section(
      "type_parameters",
      registry.type_parameters.map(TypeParameterMetadata::pretty),
    ),
    @pretty.section(
      "type_members",
      registry.type_members.map(TypeMemberSymbolMetadata::pretty),
    ),
    @pretty.section("values", registry.values.map(ValueSymbolMetadata::pretty)),
    @pretty.section("fields", registry.fields.map(FieldSymbolMetadata::pretty)),
    @pretty.section(
      "variants",
      registry.variants.map(VariantSymbolMetadata::pretty),
    ),
  ]
  if !registry.effects.is_empty() {
    sections.push(
      @pretty.section(
        "effects",
        registry.effects.map(EffectSymbolMetadata::pretty),
      ),
    )
  }
  if !registry.operations.is_empty() {
    sections.push(
      @pretty.section(
        "operations",
        registry.operations.map(OperationSymbolMetadata::pretty),
      ),
    )
  }
  text("symbols") + space + @pretty.braced_block(sections)
}
