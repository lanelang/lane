# Lane Wasm

`Milky2018/lane_wasm` is the wasm1 browser-facing Lane IR explorer module.

Build it with:

```sh
moon build modules/lane_wasm --target wasm
```

The semantic request is JSON:

```json
{ "source": "module Test\npub let sample_value : Int = 42" }
```

The response is JSON:

```json
{
  "status": 0,
  "diagnostics": [],
  "panes": [
    { "name": "checked", "text": "..." },
    { "name": "buslane", "text": "..." },
    { "name": "anf", "text": "..." }
  ]
}
```

The wasm1 physical ABI uses exported linear memory and one fixed arena:

- `memory`
- `arena_reset() -> Unit`
- `arena_alloc(len : Int) -> Int`
- `arena_capacity() -> Int`
- `explore(input_ptr : Int, input_len : Int) -> Int`
- `last_result_ptr() -> Int`
- `last_result_len() -> Int`

Status values:

- `0`: success
- `1`: compile diagnostics were returned
- `2`: arena overflow; the host should create its own fallback response
- `3`: invalid request or invalid input buffer

The host should call `arena_reset`, allocate and bulk-write UTF-8 request bytes
into `memory`, call `explore`, then bulk-read `last_result_len` bytes from
`last_result_ptr`.
