---
status: accepted
---

# Numeric primitive names and F32

The expected-type-directed numeric literal rules in this ADR are superseded by
ADR 0127. This ADR continues to own primitive naming, numeric operations,
representation, persistence, and host ABI decisions.

## Decision

Lane names its four numeric primitive types by semantic width: `I64`, `I32`, `F64`, and `F32`. The former source names `Int`, `S32`, and `Double` are removed without aliases. This is a coordinated breaking change across source syntax, diagnostics, Basic APIs, Buslane, artifacts, LoisVM, host bindings, editor highlighting, examples, and documentation.

`I64` is a signed two's-complement 64-bit integer, `I32` is a signed two's-complement 32-bit integer, `F64` is IEEE 754 binary64, and `F32` is IEEE 754 binary32. The four types remain definitionally distinct even when a runtime representation has the same width. Lane inserts no implicit conversion among them.

Basic exposes ordinary modules `Basic.Data.I64`, `Basic.Data.I32`, `Basic.Data.F64`, and `Basic.Data.F32`. These module names, declarations, traits, and offers are not compiler-recognized.

## Literal elaboration

The following three paragraphs record the historical rule replaced by ADR 0127.

Integer literals default to `I64` and elaborate to `I32` only under an explicit I32 expectation. The complete signed range of each type is accepted, including a minimum value written through unary negation; an out-of-range mathematical integer produces a typechecking diagnostic.

Floating literals default to `F64` and elaborate to `F32` only under an explicit F32 expectation. F32 elaboration parses the authored decimal value as binary64, rounds it once to binary32 using round-to-nearest, ties-to-even, and rejects a finite nonzero source value that rounds to signed zero or infinity. Positive and negative zero remain distinct bit patterns. Infinity and NaN are not special literal spellings; they are obtained through the closed intrinsics below.

Expected-type-directed literal elaboration does not create a general numeric coercion. A value expression of one numeric type never satisfies an expectation for another numeric type without an explicit conversion call.

## Closed intrinsic surface

The complete compiler-owned numeric intrinsic surface is:

| Family | Intrinsics | Type and contract |
| --- | --- | --- |
| I64 arithmetic | `%i64_add`, `%i64_sub`, `%i64_mul`, `%i64_div`, `%i64_rem` | `(I64, I64) -> I64`; overflow in add/sub/mul is undefined behavior, and division and remainder require their ordinary signed preconditions |
| I64 unary and comparison | `%i64_neg`, `%i64_equal`, `%i64_less` | `(I64) -> I64` or `(I64, I64) -> Bool`; negating the minimum I64 is undefined behavior, and ordering is signed |
| I32 arithmetic | `%i32_add`, `%i32_sub`, `%i32_mul`, `%i32_div`, `%i32_rem` | `(I32, I32) -> I32`; add/sub/mul wrap at 32 bits, and division and remainder require their ordinary signed preconditions |
| I32 unary and comparison | `%i32_neg`, `%i32_equal`, `%i32_less` | `(I32) -> I32` or `(I32, I32) -> Bool`; negation wraps and ordering is signed |
| F64 arithmetic | `%f64_add`, `%f64_sub`, `%f64_mul`, `%f64_div`, `%f64_neg` | IEEE 754 binary64 operations |
| F64 comparison | `%f64_equal`, `%f64_less` | `(F64, F64) -> Bool` with IEEE equality and ordering |
| F64 constants | `%f64_inf`, `%f64_ninf`, `%f64_nan` | Values of type F64 |
| F32 arithmetic | `%f32_add`, `%f32_sub`, `%f32_mul`, `%f32_div`, `%f32_neg` | IEEE 754 binary32 operations, rounded at binary32 width |
| F32 comparison | `%f32_equal`, `%f32_less` | `(F32, F32) -> Bool` with IEEE equality and ordering |
| F32 constants | `%f32_inf`, `%f32_ninf`, `%f32_nan` | Values of type F32 |
| Integer width | `%i32_to_i64`, `%i64_to_i32` | Sign extension and low-32-bit two's-complement truncation |
| I64/F64 | `%i64_to_f64`, `%f64_to_i64` | IEEE conversion to F64; truncation toward zero to I64 with a finite, representable-result precondition |
| I64/F32 | `%i64_to_f32`, `%f32_to_i64` | Round-to-nearest, ties-to-even to F32; truncation toward zero to I64 with a finite, representable-result precondition |
| Float width | `%f32_to_f64`, `%f64_to_f32` | Exact promotion to F64; round-to-nearest, ties-to-even demotion to F32 |
| Byte/I64 | `%byte_to_i64`, `%i64_to_byte` | Zero extension and low-eight-bit truncation |

There are no direct I32/float conversions. Library code composes the explicit width conversions when it needs them.

The precondition of float-to-I64 conversion excludes NaN, both infinities, and values whose truncation-toward-zero result is outside the I64 range. Violating an intrinsic precondition is undefined Lane behavior; defensive runtimes trap rather than corrupt state.

## IEEE behavior

Arithmetic uses the target IEEE width rather than widening F32 operations through F64. `+0.0` and `-0.0` compare equal, neither is less than the other, and negation changes the sign bit. Every ordered comparison with NaN is false, including equality and less-than. The `%f32_nan` and `%f64_nan` intrinsics produce NaN values, but Lane does not promise a particular NaN payload or preservation of a payload through arithmetic. Persistence and representation erasure preserve the stored bits of an existing F32 or F64 value.

`%f32_to_f64` is exact. `%f64_to_f32`, `%i64_to_f32`, and F32 arithmetic may produce signed zero or infinity according to IEEE rounding; only source-literal elaboration applies the additional finite-nonzero underflow and overflow diagnostics.

Buslane canonical text writes F64 and F32 literals as fixed-width lowercase hexadecimal IEEE bit patterns: `f64(0x0000000000000000)` and `f32(0x00000000)`. This representation round-trips signed zero, infinities, subnormals, and every NaN payload exactly. Human-oriented Buslane Pretty output remains decimal and is not a persistence format.

## Semantic and runtime representation

Buslane represents I64, I32, F64, and F32 primitive types and literals independently. LoisVM uses `I64 + Trivial`, `I32 + Trivial`, `F64 + Trivial`, and `F32 + Trivial`, with dedicated arithmetic, comparison, conversion, constant, layout, host-ABI, and representation-erasure cases. F32 values are never widened to F64 merely to cross a compiler, artifact, runtime, or host boundary.

Generic representation erasure stores the raw 32 bits of F32 in the low half of the erased I64 carrier and reconstructs those exact bits. This representation choice does not make F32 definitionally equal to I32.

## Persistence

The current persisted formats are Buslane codec version 5, module interface schema 11, module object schema 16, and linked program schema 8. Module object schema 15 added the I64/F64 conversion intrinsic tags to the numeric model introduced by schema 14; schema 16 replaced module-reference kinds plus optional identities with one closed tagged reference. Their decoders reject versions 4, 10, 15, and 7 respectively; there is no compatibility alias or migration decoder for removed representations.

The stable new tags within those current formats are:

| Domain | Numeric migration encoding |
| --- | --- |
| Buslane primitive type | tag `9` |
| Buslane literal | tag `7` followed by the binary32 payload |
| Lane artifact primitive type | tag `9` |
| Lane artifact intrinsic | tags `43` through `56` for the ordered F32 operation, constant, and conversion cases |
| Lane artifact I64/F64 conversion intrinsics | tags `57` and `58` for `%i64_to_f64` and `%f64_to_i64` |
| Lane artifact host value kind | tag `6` |
| LoisVM runtime import value kind | tag `0x06` |
| LoisVM slot representation | tag `0x04` |
| LoisVM result representation | tag `0x05` |
| LoisVM layout recipe | tag `0x0E` |
| LoisVM instructions | opcodes `0x5C` through `0x6D` for `ConstF32`, arithmetic, six comparisons, four conversions, and erase/unerase |

F32 constants and literals are persisted as their raw 32-bit IEEE payload. Decoders do not canonicalize negative zero or NaN bits.

## Host ABI

The language-independent LoisVM host ABI represents an F32 parameter or result as `RuntimeValueKind::F32` and `RuntimeValue::F32(Float)`. The interpreter passes a MoonBit `Float`; the Wasm backend uses a physical WebAssembly `f32`. Artifact and bytecode host signatures use the F32 value-kind tag `6`. No host boundary widens F32 to F64, and a binding whose declared value kind differs is rejected by normal runtime signature validation.

## Compatibility

This ADR supersedes the numeric terminology, conversion names, canonical floating-text representation, and superseded persistence-version statements in ADRs 0029, 0046, 0053, 0062, 0068, 0071, 0072, 0074, 0075, 0079, 0081, 0083, 0085, 0086, 0091, 0092, 0093, 0097, 0098, 0099, 0101, 0105, 0121, 0123, and 0124. Those documents continue to own their other decisions.
