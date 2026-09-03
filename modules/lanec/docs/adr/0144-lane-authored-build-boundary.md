# ADR-0144: Lane-authored build dependency boundary

## Status

Accepted.

## Context

A Lane build program must be able to compile a source graph without either
reimplementing Lane import syntax or transferring build policy into the
compiler CLI. `lane compile` already owns single-module compilation and
`lane link` already owns linking an explicit set of object artifacts. A
compiler-owned `compile-graph` command would also have to choose repository
discovery, scheduling, caching, and output policy. An `object-list` file would
only add an incidental transport format for arguments already accepted by
`lane link`.

The source parser is the only valid producer of a source unit's declared module
identity and direct import set. The build program is the correct producer of
the aggregate dependency graph because it owns source discovery and build
policy.

## Decision

`lane inspect FILE.lane` parses exactly one source file through the canonical
module-input frontend and writes one stable JSON object to standard output:

```json
{"schema":1,"module":"App.Main","imports":["App.Model"]}
```

The ordered `imports` array is the frontend's authored direct dependency
projection. Language sugar does not add hidden source dependencies. Inspection
reports ordinary parser diagnostics for invalid source. It performs no
repository discovery, graph construction, compilation, or scheduling.

Build code in Basic owns source discovery, aggregate DAG construction,
topological or parallel scheduling, cache policy, artifact paths, and the final
explicit argument list passed to `lane link`. It invokes `lane compile` once per
selected source module. The compiler does not provide `compile-graph` or
`object-list` commands.

Lane Runtime V1 process execution supplies standard input as bytes and captures
standard output and standard error as bytes. This makes structured command
composition possible without inheriting terminal streams or requiring shell
parsing. The process capability remains a direct executable-plus-argv API; a
build library may decode a command's documented machine-readable output.

## Consequences

- Lane source inspection reports only authored direct imports; library-backed
  syntax creates no hidden dependency edges.
- Build policy stays replaceable ordinary Lane code.
- Source inspection is a small semantic projection rather than an alternate
  compiler pipeline or manifest language.
- Link inputs remain ordinary repeated CLI arguments, with no second list-file
  protocol.
- Process output is explicit data available to build code; host adapters do not
  retain guest-memory addresses across calls.
- Module-object schema 29 records the new `%byte_buffer_to_bytes` intrinsic used
  to copy mutable guest output storage into immutable Lane `Bytes`; schema 28
  objects are rejected.
