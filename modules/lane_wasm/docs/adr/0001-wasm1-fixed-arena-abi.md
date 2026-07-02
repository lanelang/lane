# Lane Wasm uses a wasm1 fixed-arena ABI

Lane Wasm targets wasm1 for the first IR Explorer surface, so it cannot expose
MoonBit `String` values directly to JavaScript. We use a fixed Explorer Arena
in exported linear memory, bulk-copy UTF-8 Explorer JSON through a JavaScript
wrapper, and keep the ABI single-call-at-a-time; this avoids wasm-gc string
requirements and per-byte accessor overhead while keeping the first browser
integration small.

## Considered Options

- wasm-gc with JS string builtins: rejected because the first Lane Wasm target
  is wasm1.
- Per-byte accessor functions: rejected because crossing the wasm boundary once
  per byte is too expensive for source and IR text.
- General malloc/free or result handles: rejected for the first version because
  the IR Explorer is single-file and single-call-at-a-time.

## Consequences

- Explorer Overflow is a wrapper-handled fallback failure rather than a wasm
  trap.
- The first ABI is not concurrent or reentrant.
- The JavaScript wrapper owns UTF-8 encoding and decoding.
