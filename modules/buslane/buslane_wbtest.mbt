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
      #|    kind: InvalidMetadataIdentity(NegativeUnique({ value: -1 })),
      #|    provenance: [],
      #|  },
      #|]
    ),
  )
}

///|
test "verifier distinguishes an internally malformed negative next unique" {
  let metadata = MetadataRegistry::MetadataRegistry()
  metadata.name_allocator = Fresh({ value: -1 })
  debug_inspect(
    verify_program({ metadata, terms: [] }).diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InvalidMetadataIdentity(NegativeNextUnique({ value: -1 })),
      #|    provenance: [],
      #|  },
      #|]
    ),
  )
}
