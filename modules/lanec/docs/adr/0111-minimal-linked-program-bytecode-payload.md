# Minimal linked-program bytecode payload

Lane v1 `.lbp` artifacts use the existing Lane binary artifact container with
artifact kind Program. The linked-program payload is one fixed-order record:

1. `linked_program_schema_version:u32le = 4`;
2. the complete LoisVM bytecode section occupying every remaining payload byte.

V1 has no linked-program section directory, section tags, optional sections, or
nested bytecode-length field. The outer artifact container's `payload_length`
frames the linked-program payload. After consuming the four-byte linked-program
schema version, the remaining payload is the exact slice supplied to the
LoisVM bytecode decoder, which must consume that slice completely. Adding
another linked-program payload component requires a linked-program schema
version change rather than unknown-section skipping.

The linked-program payload contains no duplicate selected entry, runtime-import
descriptor table, module-path list, linked Buslane/core, external map, effect
metadata, source type, source map, compiler version, lowering options, target
profile, or backend identifier. The selected `FunctionId` and runtime imports
already belong to the LoisVM bytecode section. Backend requirements follow from
the supported bytecode schema and execution implementation rather than
serialized Wasm metadata.

The incompatible replacement of the current schema-3 Buslane-bearing
linked-program payload sets `linked_program_schema_version` to 4. Lane artifacts
are compiler contracts, so the loader rejects the old schema and asks users to
relink instead of retaining a compatibility decoder.

The in-memory `LinkedProgramArtifact` contains a decoded
`loisvm/bytecode.BytecodeImage`, not an opaque byte array. The Lane artifact
codec owns the outer container and linked-program schema, slices the remaining
payload, and delegates bytecode encoding and decoding to `loisvm/bytecode`.
This preserves package ownership and prevents malformed bytecode bytes from
being represented as a successfully decoded linked artifact.

`lane inspect` renders a linked artifact as explicitly lowered code. It reports
the linked-program and bytecode schema versions, selected entry, table
summaries, and canonical bytecode disassembly. It does not reconstruct omitted
module, source-type, or Buslane information and does not use a raw-byte dump as
the normal projection. LoisVM malformed-encoding offsets remain relative to the
bytecode section; the artifact command may additionally report the derived
absolute file offset.

## Consequences

- A v1 linked-program payload is schema version 4 followed by one bytecode
  section.
- The bytecode section consumes the remainder of the artifact payload.
- V1 has no section directory or redundant bytecode length.
- Entry and runtime-import information exist only in LoisVM bytecode.
- Ordinary `.lbp` files contain no module provenance or semantic core.
- `LinkedProgramArtifact` carries a decoded bytecode image.
- The artifact codec delegates the nested bytecode codec to `loisvm/bytecode`.
- Old Buslane-bearing linked-program artifacts are rejected and regenerated.
- Linked-artifact inspection uses canonical disassembly rather than source
  reconstruction or raw-byte output.
- Bytecode diagnostics retain section-relative offsets and may gain an
  additional absolute-file-offset presentation.
