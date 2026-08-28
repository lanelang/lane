# Lane Wasm

`Milky2018/lane_wasm` is the wasm1 browser bridge for the Lane IR explorer. It accepts host-collected source files, enumerates public entries, and returns the same curated compiler stages as `lane explore`.

Build it with:

```sh
moon build modules/lane_wasm --target wasm
```

## Requests

Entry enumeration uses this JSON request:

```json
{
  "root": { "sourceId": "main.lane", "text": "module Main\n..." },
  "libraries": [
    { "sourceId": "lib.lane", "text": "module Lib\n..." }
  ]
}
```

Call the exported `entries()` function. The schema-version-1 response contains artifact-defined entries with `module`, `name`, and `type` fields.

Exploration adds the selected entry:

```json
{
  "root": { "sourceId": "main.lane", "text": "module Main\n..." },
  "libraries": [],
  "entry": "main"
}
```

Call the exported `explore()` function. A valid Explore Protocol v11 response contains `schemaVersion`, `compiler`, `root`, optional `selectedEntry`, typed `status`, `diagnostics`, all eighteen ordered `stages`, and a report-level `functions` graph. Each completed stage includes `domain`, `format`, `text`, `diagnostics`, ordered `metrics`, linker-owned module contributions when applicable, stage-local function scale observations where the IR owner assigns function identities, and structured indirect-call provenance where callable-flow analysis applies. Identity-less tree stages publish aggregate metrics only. Generic-ABI bridge metrics are named `genericAbiEraseCount` and `genericAbiUneraseCount`; callable-adapter roles retain the Physical Lowering worker contract and structured source-to-target contract differences, while indirect-call flow boundaries expose adaptations that cross aggregate storage. The graph contains typed nodes and explicit cross-stage edges; clients must not reconstruct lineage or call provenance from numeric offsets, names, or rendered text. A failed report identifies its failed stage in `status.stage`, preserves earlier completed stages and graph facts, and marks every later stage unavailable. The protocol has no fallback failure string.

## Streaming ABI

The Wasm module exports:

- `memory`
- `transfer_ptr() -> i32`
- `transfer_capacity() -> i32`
- `entries() -> i32`
- `explore() -> i32`

The host provides these imports under `lane.explorer`:

- `request_length() -> i32`
- `request_read(offset, ptr, capacity) -> i32`
- `response_begin(length) -> i32`
- `response_write(offset, ptr, length) -> i32`

Requests and responses are UTF-8. The module repeatedly fills a 64 KiB transfer window, so semantic payload size is not limited by a fixed result arena.

The numeric return from `entries()` or `explore()` is the streaming-call outcome: `0` for success, `1` for compiler or lowering failure, `2` for transport failure, and `3` for an invalid request. Inside a valid Explore Protocol response, `status` is instead the compiler-owned object `{ "kind": "succeeded" }` or `{ "kind": "failed", "stage": "<stage-id>" }`; invalid-request responses remain transport-level error objects with numeric status and no Explore Report.
