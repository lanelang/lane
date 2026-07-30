---
status: accepted
---

# Numeric primitive names and F32

Lane names its four numeric primitive types by semantic width: `I64`, `I32`, `F64`, and `F32`. The former source names `Int`, `S32`, and `Double` are removed without aliases. This is a coordinated breaking change across source syntax, diagnostics, Basic APIs, Buslane, artifacts, LoisVM, host bindings, editor highlighting, examples, and documentation.

`I64` is a signed two's-complement 64-bit integer, `I32` is a signed two's-complement 32-bit integer, `F64` is IEEE 754 binary64, and `F32` is IEEE 754 binary32. The four types remain definitionally distinct even when a runtime representation has the same width.

Integer literals default to `I64` and elaborate to `I32` only under an explicit I32 expectation. Floating literals default to `F64` and elaborate to `F32` only under an explicit F32 expectation. F32 elaboration rounds the mathematical literal once to binary32 and rejects a finite nonzero source value that rounds to zero or infinity. These rules are expected-type-directed literal elaboration, not implicit numeric conversion. Lane inserts no implicit conversion among the four numeric types.

The compiler-owned intrinsic families are `%i64_*`, `%i32_*`, `%f64_*`, and `%f32_*`. Explicit conversions are `%i32_to_i64`, `%i64_to_i32`, `%i64_to_f64`, `%f64_to_i64`, `%i64_to_f32`, `%f32_to_i64`, `%f32_to_f64`, and `%f64_to_f32`. Byte conversion uses `%byte_to_i64` and `%i64_to_byte`. Basic exposes ordinary modules `Basic.Data.I64`, `Basic.Data.I32`, `Basic.Data.F64`, and `Basic.Data.F32`; none of those module names or declarations is compiler-recognized.

Buslane represents the numeric primitives and literals independently. LoisVM uses `I64 + Trivial`, `I32 + Trivial`, `F64 + Trivial`, and `F32 + Trivial`, with dedicated arithmetic, comparison, conversion, constant, layout, host-ABI, and representation-erasure cases. F32 values are never widened to F64 merely to cross a compiler or runtime boundary.

The persisted format changes are Buslane codec version 5, module interface schema 11, module object schema 14, and linked program schema 8. Decoders reject their preceding versions at the version boundary; no compatibility aliases or migration decoder preserve the removed numeric identities.

This ADR supersedes the numeric terminology and conversion names in ADRs 0029, 0046, 0053, 0062, 0068, 0071, 0072, 0074, 0075, 0079, 0081, 0083, 0085, 0086, 0091, 0092, 0093, 0097, 0098, 0099, 0101, 0105, 0121, 0123, and 0124. Those documents continue to own their non-numeric decisions.
