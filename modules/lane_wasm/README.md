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

Call the exported `entries()` function. The response contains artifact-defined entries with `module`, `name`, and `type` fields.

Exploration adds the selected entry:

```json
{
  "root": { "sourceId": "main.lane", "text": "module Main\n..." },
  "libraries": [],
  "entry": "main"
}
```

Call the exported `explore()` function. The response contains `schemaVersion`, `status`, `entry`, `diagnostics`, `stages`, and an optional `failure`. Each stage has a stable `id`, a display `title`, and human-readable `text`.

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

Status values are `0` for success, `1` for compiler or lowering failure, `2` for transport failure, and `3` for an invalid request.
