# Binary artifact payloads

Lane artifact files should be real binary artifacts, not text artifacts wrapped
in a binary header. `.lmi`, `.lmo`, and `.lbp` keep a Lane artifact container
with magic bytes, format version, artifact kind, and payload length, but the
payload itself is a structured binary schema rather than UTF-8
`lane-artifact-text-v1` data.

The formal load path for compiler and command-line workflows reads only binary
artifact payloads:

- `lane compile` writes binary interface and object artifacts.
- `lane compile -i` reads binary interface artifacts.
- `lane link` reads binary object artifacts and writes a binary linked program
  artifact.
- `lane exec` reads binary linked program artifacts.
- `lane inspect` reads binary artifacts and renders a human-readable projection.

Artifact text parsing is not a compatibility layer for official artifact IO.
If any text form remains, it is a debugging or test-only projection and must
not define the serialized contract. `inspect` is the supported human-readable
view of artifacts.

Binary payloads use a fixed-order schema codec, not a self-describing tagged
field format. The container identifies the artifact kind, then the payload is
decoded according to that artifact kind and its schema version. Primitive
codecs cover integers, booleans, strings, byte arrays, arrays, options, enums,
records, and Buslane/core structures. Payload fields do not repeat source field
names.

Buslane/core structures are encoded by Buslane's own codec package. The
compiler artifact codec composes artifact fields and delegates Buslane
`Program`, `TopTerm`, metadata, types, expressions, and related core structures
to `modules/buslane/codec`. It must not embed Buslane text or duplicate the
Buslane AST schema inside `lanec`.

Decoding uses typed `suberror` exceptions inside codec packages rather than
`Result` plumbing or accumulated error arrays. Binary decoding is a sequential
reader: the first malformed byte sequence prevents a meaningful artifact from
being produced. Codec errors should carry enough structure for callers to build
good diagnostics, such as byte offset, expected domain, invalid tag, invalid
UTF-8, or invalid value messages.

Primitive encodings are fixed-width little-endian encodings, not varints:

- `u8` for small closed domains such as container kind, version bytes, boolean
  values, and enum tags.
- `u32le` for byte lengths, array lengths, counts, and non-negative indexes.
- signed integer codecs only for fields whose domain is truly signed.
- strings as `u32le` byte length followed by UTF-8 bytes.
- byte arrays as `u32le` byte length followed by raw bytes.

The artifact format optimizes for simple strict decoding and clear byte offsets
before compactness. If artifact size later matters, compression can be added at
the container level without changing every primitive codec.

Primitive byte-level reading and writing belongs in a reusable `bytecodec`
module. `bytecodec` owns strict byte readers, byte writers, little-endian
primitive codecs, length-prefixed UTF-8 strings, raw byte arrays, offset
tracking, and low-level decode errors. It does not know about Lane artifacts,
Buslane AST nodes, schema versions, command diagnostics, or inspect output.
`bytecodec` may use MoonBit bitstring patterns internally for compact primitive
decoding and fixed header parsing, but artifact and Buslane schema codecs should
use the reader/writer API. Higher-level schemas need composable nested decoding,
offset tracking, and structured error context more than direct byte-pattern
syntax.

Versioning is split by layer:

- the artifact container version describes the outer framing: magic bytes,
  artifact kind, payload length, and future framing features such as checksums
  or compression;
- the artifact schema version describes the fixed-order payload fields for one
  artifact kind such as interface, module object, or linked program;
- the Buslane codec version describes the binary schema for Buslane/core
  structures embedded inside artifacts.

These versions are bumped independently. Changing `.lmo` fields should not
change the container version; changing Buslane expression tags should not
change every artifact schema version; adding a checksum to the container should
not imply a Buslane schema change.

Every top-level decoder and nested binary section decoder must consume its
entire input. The container decoder slices the payload by declared payload
length; the artifact payload decoder must end exactly at the end of that slice;
Buslane/core sections must do the same for their section bytes. Trailing bytes
are invalid rather than ignored. Format evolution happens through explicit
schema version bumps, not unknown-field skipping or tail-compatible append
rules.

`inspect` is the human-readable projection of binary artifacts. It decodes the
binary artifact into structured in-memory data, then renders semantic artifact
summaries and Buslane/core pretty output. It does not print raw binary, default
to derived debug dumps, or recreate artifact text. If linked artifacts later
store lowered execution images, `inspect` may show them in a clearly labeled
lowered-code section after semantic metadata and Buslane/core information.

Tests should follow the new artifact contract. Artifact text parser fixtures and
roundtrips should be removed with the production text load path. Buslane
text/pretty/parser tests remain valuable because Buslane is still an independent
language with a readable text form. Artifact coverage should move to binary
roundtrip tests, malformed binary tests, CLI compile/link/exec smoke tests, and
`inspect` golden output tests.

Encoding is expected to be infallible for valid in-memory artifacts. If an
encoder encounters an impossible internal invariant violation, that should be
handled as an internal compiler/runtime bug rather than a recoverable artifact
load diagnostic.

Lane artifacts are compiler contracts, not a long-term stable interchange
format. Incompatible schema versions should be rejected clearly and regenerated
with the current compiler rather than migrated field by field.

## Consequences

- Binary decoding, schema validation, and semantic artifact validation are
  separate steps.
- Artifact parser packages for text artifacts should not sit on the production
  artifact load path.
- Human readability belongs to `inspect`, not to the persisted payload.
- The binary schema must carry enough version and kind information to reject
  incompatible artifacts before semantic validation.
- The binary codec is compact and strict: no field names, no best-effort
  unknown-field skipping, and no text-artifact fallback.
- Buslane text and pretty printing remain debugging, inspection, and test
  projections; they do not participate in artifact loading.
- Command and tool boundaries catch codec `suberror`s and convert them into
  artifact load diagnostics; codec packages do not depend on CLI diagnostics.
- `modules/bytecodec` provides the shared primitive byte codec used by both
  `modules/buslane/codec` and compiler artifact codecs.
- Container, artifact payload, and Buslane/core schema versions are separate
  compatibility boundaries.
- MoonBit bitstring patterns are an implementation technique for `bytecodec`,
  not the public style for artifact or Buslane schema decoders.
- Decoders must reject trailing bytes at every top-level or section boundary.
- `inspect` renders semantic artifact structure and Buslane/core pretty output
  from decoded binary artifacts; it is not an artifact text serializer.
- Artifact text parser tests should be removed; Buslane text tests and binary
  artifact tests become the relevant coverage.
