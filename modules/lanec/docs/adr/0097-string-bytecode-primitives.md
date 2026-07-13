# String bytecode primitives

LoisVM v1 provides exactly four dedicated String instructions: `string_length`, `string_concat`, `string_slice`, and `string_eq`. Comparison ordering, search, and byte-access operations are not part of this initial bytecode surface. All String references use `I32`; owned results use `OwnedRef` cleanup.

`string_length(destination, source)` reads one String without consuming ownership and widens its stored `u32` byte length to an `I64 + Trivial` Lane Int result. `string_eq(destination, left, right)` reads both Strings without consuming them and writes canonical `I32 + Trivial` Bool after comparing byte length and exact ASCII bytes. Pointer equality may short-circuit the comparison but is not the semantic definition.

`string_concat(destination, left, right)` consumes two `I32 + OwnedRef` String owners and produces one `I32 + OwnedRef` result. It checks the combined length, allocates one exact-size String, and copies both byte ranges. If either input is empty, execution may move the other input owner directly and release the empty owner instead of allocating. String object identity is not observable.

`string_slice(destination, source, start, length)` consumes one `I32 + OwnedRef` String owner. Start and length are `I64 + Trivial` Lane Int values interpreted as ASCII byte indices, which also equal character indices in v1. A valid range requires nonnegative start and length, non-overflowing addition, and `start + length <= byte_length`. A proper subrange allocates an independent exact-size String and copies bytes. A complete-range slice may move the input owner directly. No slice retains a parent String or creates a view object.

Concatenation length overflow, a negative or out-of-bounds slice, signed or unsigned range overflow, wasm32 addressability overflow, and allocation failure throw the private non-recoverable fatal exception. Fatal failure unwinds owned slots according to the established cleanup contract and the host discards the instance.

The binary encodings contain only slots. Length encodes destination then source. Concatenation and equality encode destination, left, then right. Slice encodes destination, String source, start, then length. No instruction carries encoding, index-unit, bounds, allocation, or ownership mode flags.

Consequences:

- V1 has four dedicated String opcodes and no generic String dispatch.
- String length returns Lane Int even though the object stores `u32` length.
- Length and equality are non-consuming reads.
- Concatenation consumes two owners and returns one owned String.
- Slice consumes one owner and returns an independent owned String.
- Empty concatenation and complete slicing permit zero-allocation owner movement.
- String indices are ASCII byte indices and therefore character indices in v1.
- Invalid ranges, overflow, and allocation failure are fatal.
- Pointer equality is only an equality fast path.
- String instructions expose no raw memory offsets or encoding modes.
