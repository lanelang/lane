///|
test "verifier rejects an internally malformed negative unique" {
  let metadata = MetadataRegistry::MetadataRegistry()
  metadata.values.push({
    name: {
      name_space: ValueName,
      occurrence: "invalid",
      unique: { value: -1 },
    },
    kind: Value,
    type_: Primitive(Unit),
  })
  debug_inspect(
    verify_program({ metadata, terms: [] }).diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InvalidMetadataIdentity(InvalidUnique({ value: -1 })),
      #|    provenance: [],
      #|  },
      #|]
    ),
  )
}
