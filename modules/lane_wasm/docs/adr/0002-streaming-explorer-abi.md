# Lane Wasm uses a streaming explorer ABI

Lane Wasm supports the same multi-file, selected-entry Explore Report as the native Lane Command. A complete report contains seventeen compiler and backend snapshots and may exceed the former fixed 15 MiB Explorer Arena. Silently truncating a report is invalid, while treating one fixed whole-message capacity as the browser feature limit does not scale with multi-file exploration.

The Explorer Byte Buffer ABI is therefore replaced by a streaming wasm1 transaction. The JavaScript wrapper provides bulk request-read and response-write callbacks. One Artifact Entry Enumeration or Executable IR Exploration invocation pulls UTF-8 request bytes in chunks and pushes UTF-8 JSON response bytes in chunks. Chunk boundaries are byte boundaries and may split UTF-8 code points; JavaScript decodes only the assembled response stream.

The ABI does not require a persistent compilation session. It may retain bounded request, response, chunk, or reusable cache state when useful, but the semantic result of a request depends only on that request. A later implementation may expose explicit request handles if required without changing the compiler-owned Explore Report Protocol.

Response framing preserves ordered stage snapshots and places final status and terminal diagnostics after the streamed stage sequence, allowing a compilation failure to finish a valid Partial Explore Report. A failed host callback or transport operation aborts the transaction and never reports a truncated stream as successful.

Lane Wasm remains a compiler bridge. It invokes `lanec/driver`, serializes the versioned Explore Report Protocol, and uses `loisvm/wasm/compiler` to generate the final Wasm snapshot. It does not load, instantiate, JIT-compile, or execute that generated module.

## Consequences

- The fixed whole-request and whole-response arena is no longer the Explorer transport contract.
- Multi-file reports are transferred incrementally rather than rejected solely for exceeding 15 MiB.
- JavaScript owns request production, response accumulation, and final UTF-8 decoding.
- Lane Wasm may use bounded transient state or internal caches without exposing a mutable compiler session.
- Transport failure is distinct from compiler diagnostics and Partial Explore Reports.
- The native and browser hosts share report semantics while retaining platform-specific presentation and transport.
