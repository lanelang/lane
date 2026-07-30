---
status: accepted
---

# UTF-8 String, Char, I32, and the shared byte-sequence runtime

Lane replaces its ASCII-only String model with always-valid UTF-8 text, adds `Char` as the Unicode scalar primitive, and adds `I32` as the ordinary signed 32-bit integer primitive. String and Bytes remain distinct semantic types but share one packed runtime ByteSequence representation. The compiler owns only a closed set of representation-dependent intrinsics; scalar text algorithms and user-facing validation remain ordinary Basic library code.

This document is the complete review contract for the change. Implementation must not infer additional String syntax, Unicode behavior, implicit conversions, reflection, compiler-recognized library declarations, or mutable collection semantics beyond what is specified here.

## Semantic types

`String` is an immutable sequence of Unicode scalar values encoded as valid UTF-8. A Unicode scalar value is any code point in `U+0000..U+10FFFF` except the surrogate range `U+D800..U+DFFF`.

`Char` is a primitive value containing exactly one Unicode scalar value. It is not a one-character String, a Byte, a UTF-8 code unit, or an implicitly convertible integer.

`I32` is a primitive signed two's-complement 32-bit integer with range `-2147483648..2147483647`. It is semantically distinct from `I64`; neither type implicitly converts to the other. Addition, subtraction, multiplication, and negation use 32-bit two's-complement wraparound. Signed division requires a nonzero divisor and a representable quotient, so `-2147483648 / -1` violates the primitive precondition. Signed remainder requires a nonzero divisor and yields zero for `-2147483648 % -1`. Equality and ordering compare signed values.

`Bytes` remains an immutable pure-value sequence of arbitrary Byte values. UTF-8 validity is never an invariant of Bytes.

`String`, `Char`, and `I32` are globally available primitive types. Their ordinary library operations still follow normal module import and name-resolution rules.

## Numeric literals and I32

Lane retains one decimal integer-literal syntax. An integer literal is checked as `I32` when its expected type is `I32`; otherwise it defaults to `I64`. This is expected-type-directed literal elaboration, not an implicit conversion between `I64` and `I32`. Literal and unary-negation checking must admit the complete signed range of the selected type and produce a range diagnostic when the mathematical value is outside it.

I32 literals participate in the existing literal-expression and literal-pattern rules. Syntax retains the authored decimal spelling, while checked and Buslane literals store the validated signed 32-bit value.

The closed I32 intrinsic family is:

| Intrinsic | Type | Contract |
| --- | --- | --- |
| `%i32_add` | `(I32, I32) -> I32` | 32-bit wrapping addition |
| `%i32_sub` | `(I32, I32) -> I32` | 32-bit wrapping subtraction |
| `%i32_mul` | `(I32, I32) -> I32` | 32-bit wrapping multiplication |
| `%i32_div` | `(I32, I32) -> I32` | Signed division requiring a nonzero divisor and representable quotient |
| `%i32_rem` | `(I32, I32) -> I32` | Signed remainder requiring a nonzero divisor |
| `%i32_neg` | `(I32) -> I32` | 32-bit wrapping negation |
| `%i32_equal` | `(I32, I32) -> Bool` | Signed value equality |
| `%i32_less` | `(I32, I32) -> Bool` | Signed ordering |
| `%i32_to_i64` | `(I32) -> I64` | Total sign extension |
| `%i64_to_i32` | `(I64) -> I32` | Total low-32-bit truncation interpreted as signed two's complement |

`Basic.Data.I32` exposes the same ordinary arithmetic, equality, and comparison interfaces as I64, specialized to I32. The compiler does not recognize those declarations.

## String and Char literals

String literals use double quotes and may contain any direct Unicode scalar value except an unescaped delimiter, backslash, or source line terminator. Char literals use single quotes and must decode to exactly one Unicode scalar value.

Both literal forms accept `\n`, `\r`, `\t`, `\0`, `\\`, the active delimiter escape, and `\u{HEX}`. A Unicode escape contains one through six case-insensitive hexadecimal digits and may contain leading zeroes, but its value must not exceed `U+10FFFF` or lie in the surrogate range. `\0` denotes only `U+0000`; Lane has no octal escape syntax. The byte-oriented `\xNN` String escape is removed because arbitrary encoded bytes belong to Byte and Bytes.

The lexer produces precise diagnostics for unterminated literals, unsupported escapes, empty Unicode escapes, more than six hexadecimal digits, non-hexadecimal content, out-of-range values, surrogate values, empty Char literals, and Char literals containing more than one decoded scalar.

The semantic syntax value is the decoded scalar sequence, not the authored escape spelling. The formatter emits ordinary scalars directly as UTF-8, uses short escapes for NUL, line feed, carriage return, and tab, escapes backslash and the active delimiter, and emits remaining C0/C1 controls as uppercase `\u{HEX}` without redundant leading zeroes. Formatting never normalizes Unicode, but it may replace an authored Unicode escape with the direct scalar.

Char literals participate in the same expression and pattern rules as existing scalar literals. Syntax, checked, and Buslane forms preserve the `Char` type. Runtime pattern comparison may use the shared `I32` representation without making Char and I32 definitionally equal.

## Unicode semantics

Lane performs no implicit Unicode normalization. String construction, concatenation, slicing, encoding, decoding, equality, hashing, and storage preserve the exact scalar sequence.

String equality means equal scalar values in equal order. Because valid UTF-8 has one canonical byte encoding per scalar sequence, exact UTF-8 byte equality implements this semantic equality.

String comparison is lexicographic Unicode scalar ordering. It is not locale collation, normalization-aware comparison, grapheme comparison, or case-folded comparison.

Ordinary String positions are zero-based scalar indices. UTF-8 byte offsets belong only to explicit UTF-8 and Bytes interfaces. Grapheme-cluster indexing is outside this design.

`String.slice(value, start, length)` interprets `start` and `length` in Unicode scalar values. A range is valid exactly when `start >= 0`, `length >= 0`, and `start + length <= scalar_count(value)` without arithmetic overflow. An empty slice at `start == scalar_count(value)` is valid. Basic locates the two UTF-8 byte boundaries and invokes `%bytes_slice` with a byte start and byte length.

Invalid scalar lookup or range arguments use the ordinary Basic `OutOfBound` effect. An unsuccessful search is represented by `Option`; it is not an out-of-bounds failure.

## Closed compiler intrinsic boundary

The String, Char, and Bytes increment is exactly:

| Intrinsic | Type | Contract |
| --- | --- | --- |
| `%char_to_i32` | `(Char) -> I32` | Total representation-preserving conversion |
| `%i32_to_char` | `(I32) -> Char` | Requires a valid Unicode scalar value |
| `%string_to_bytes` | `(String) -> Bytes` | Total O(1) representation conversion |
| `%bytes_is_valid_utf8` | `(Bytes) -> Bool` | Total UTF-8 validation |
| `%bytes_to_string` | `(Bytes) -> String` | Requires valid UTF-8 and performs an O(1) representation conversion |
| `%bytes_equal` | `(Bytes, Bytes) -> Bool` | Exact byte equality |
| `%bytes_concat` | `(Bytes, Bytes) -> Bytes` | Exact-size concatenation |
| `%bytes_slice` | `(Bytes, I64, I64) -> Bytes` | Requires a nonnegative in-bounds byte start and byte length |

The existing Byte and Bytes primitives `%byte_to_i64`, `%i64_to_byte`, `%bytes_make`, `%bytes_length`, `%bytes_get`, and `%bytes_set` remain source-level intrinsics with their accepted contracts.

`%string_equal` is removed. The compiler does not add `%string_length`, `%string_concat`, `%string_slice`, `%string_scalar_at`, `%string_scalar_count`, `%char_equal`, `%char_less`, `%char_to_string`, a fold intrinsic, a String cursor intrinsic, or an iterator intrinsic.

Char and I32 both use `I32 + Trivial`. `%char_to_i32` and `%i32_to_char` remain explicit typed calls through checked AST and Buslane, but compiler-intrinsic lowering erases them because their representations are identical. The erasure does not validate `%i32_to_char`; its caller must establish the scalar precondition.

I32 uses `I32 + Trivial`, while I64 uses `I64 + Trivial`. `%i32_to_i64` sign-extends `I32` to `I64`, and `%i64_to_i32` retains the low 32 bits. These conversions require explicit VM operations and are not representation-identical casts.

Basic implements checked `Char.from_i64` by validating the I64 range and surrogate exclusion, then composing `%i64_to_i32` with `%i32_to_char`. `Char.to_i64` composes `%char_to_i32` with `%i32_to_i64`.

## Basic library contract

The initial `Basic.Data.Char` surface contains checked `from_i64`, total `to_i64`, `to_string`, and ordinary Equal and Compare offers. Char comparison is numeric Unicode scalar ordering.

The initial `Basic.Data.String` surface contains `byte_length`, `scalar_count`, `is_empty`, `from_char`, `concat`, scalar-indexed `scalar_at` and `slice`, effect-polymorphic `foldl`, `encode_utf8`, and `decode_utf8`, plus ordinary Equal, Compare, Semigroup, and Monoid offers. The monoid identity is the empty String.

`encode_utf8 : String -> Bytes` is total. `decode_utf8 : Bytes -> Option[String]` first calls `%bytes_is_valid_utf8`; only the successful branch calls `%bytes_to_string`. There is no implicit String/Bytes conversion and no lossy replacement.

`String.foldl` is ordinary effect-polymorphic Lane code. It performs one O(1) String-to-Bytes conversion and advances a private UTF-8 byte cursor with an ordinary decoder. Complete traversal is O(byte length) with O(1) auxiliary space. The cursor and decoder are library implementation details, not public types or compiler protocols.

Search, split, replace, trim, case conversion, normalization, locale collation, grapheme segmentation, capacity-bearing builders, and indexed text structures are later ordinary library work. The initial surface does not add `Add[String]`.

No Basic declaration, module name, offer, algebra, codec, or iterator is compiler-recognized. Only the exact intrinsic names and types in this document are compiler-owned.

## Shared runtime ByteSequence

String and Bytes remain distinct in syntax, resolution, checked types, Buslane types, type equality, generic instantiation, interfaces, and artifacts. They share exactly one runtime `ByteSequence` layout identity.

A ByteSequence is an ARC object containing its byte length and exactly that many packed bytes. It has no capacity, trailing NUL, parent pointer, cached hash, cached scalar count, scalar index, normalization state, String flag, or String-specific payload. Byte length is O(1); scalar count, scalar lookup, and scalar slicing scan UTF-8 and are O(n) in the traversed byte prefix.

String-to-Bytes and prevalidated Bytes-to-String calls remain ordinary typed intrinsic calls through checked AST and Buslane. Compiler-intrinsic lowering erases only these two closed calls into ownership-preserving use of the same ARC reference. It does not add a general cast, layout coercion, or definitional equality between semantic types.

The conversion moves the reference when ownership permits and otherwise retains it. `%bytes_set` may update uniquely owned storage and must copy shared storage. Therefore converting a String to Bytes can never allow a Bytes update to mutate any still-observable String or Bytes alias.

`%bytes_concat` allocates exactly the combined byte length after checked size, addressability, and resource preflight. An empty operand may allow the other owner to be reused.

`%bytes_slice` operates on byte start and byte length. A proper nonempty subrange allocates an independent exact-size object and copies the selected bytes; it never retains the parent. A full-range slice or empty slice may reuse an existing or canonical object. The primitive does not require its result to be valid UTF-8 because its result type is Bytes.

UTF-8 validation rejects malformed leading bytes, invalid continuation bytes, truncated sequences, overlong encodings, surrogate encodings, and values above `U+10FFFF`.

Only allocations that actually execute are subject to resource failure. A pure allocation removed by optimization does not execute and is not required to fail. Actual allocation resource exhaustion is fatal.

## Buslane, VM CFG, bytecode, and backends

Buslane gains semantic `I32` and `Char` primitive types and literal cases. Their definitional equality remains distinct even though both lower to `I32 + Trivial`. VM CFG and bytecode gain `ConstI32` and `ConstChar`; the latter accepts only Unicode scalar values. Existing semantic constant operations such as `ConstBool` remain distinct, so bytecode validation does not lose their value invariants.

I32 arithmetic lowers to `I32Add`, `I32Sub`, `I32Mul`, `I32Div`, `I32Rem`, `I32Neg`, `I32Eq`, and `I32Lt` VM CFG and bytecode operations. `%i32_to_i64` lowers to `I32ToI64`, which sign-extends `I32 -> I64`; `%i64_to_i32` lowers to `I64ToI32`, which wraps `I64 -> I32`. The interpreter and Wasm backend implement the same bit-level contract.

LoisVM names the shared packed representation directly. `BytesMake`, `BytesLength`, `BytesGet`, and `BytesSet` become `ByteSequenceMake`, `ByteSequenceLength`, `ByteSequenceGet`, and `ByteSequenceSet`. The new representation operations are `ByteSequenceEqual`, `ByteSequenceConcat`, `ByteSequenceSlice`, and `ByteSequenceIsValidUtf8`.

`StringLength`, `StringConcat`, `StringSlice`, and `StringEq` are removed. String literal patterns use `ByteSequenceEqual`. `ConstString` remains the semantic load of a valid UTF-8 String constant and produces an owner of the shared ByteSequence layout; there is no Bytes literal or second static byte pool.

Every ByteSequence instruction defensively verifies the runtime layout and argument bounds needed for memory safety. Invalid bytecode or a violated intrinsic precondition must fail safely, but Lane programs cannot depend on a particular trap message or parity of undefined behavior between backends.

The interpreter and Wasm backend must agree for every valid input on I32 arithmetic and conversion, Char conversion, UTF-8 validation, byte equality, concatenation, slicing, ownership transfer, copy-on-write, constant loading, and host String transport.

## Host ABI

A host function receives a Lane String as a borrowed pointer-length view of valid UTF-8 bytes. Embedded NUL is permitted; the view is not NUL-terminated and expires when the synchronous host call returns.

A host function declared to return String must provide valid UTF-8 bytes. The runtime validates and copies those bytes into an owned ByteSequence before returning to Lane. An invalid result violates the host binding contract and causes a fatal runtime failure. The runtime does not replace malformed sequences, return `Option`, or introduce a Lane effect.

This decision does not add Char, I32, Byte, or Bytes to the host-value ABI. Host-value support for additional primitive types is a separate decision.

## Primitive preconditions and user-visible failures

Checked Basic wrappers establish recoverable input validation. Calling `%i32_to_char`, `%bytes_to_string`, `%bytes_slice`, or another preconditioned intrinsic with an invalid argument is undefined Lane behavior.

Interpreter and compiled backends retain defensive checks so invalid bytecode and violated contracts cannot corrupt memory. They may panic, trap, or reject execution, but source code cannot rely on a specific failure detail.

User-facing scalar lookup and slicing report `OutOfBound`; UTF-8 decoding reports `None`; actual executed allocation exhaustion and invalid host String results are fatal. No primitive silently clamps, wraps an index, substitutes U+FFFD, or returns a default value.

## Persistence and compatibility

Buslane codec version 3 becomes version 4. Module interface artifact schema 9 becomes 10, module object artifact schema 12 becomes 13, and linked program artifact schema 6 becomes 7. Each decoder rejects every older version at its version boundary; there is no compatibility decoder or implicit migration.

The artifact binary container remains version 1 because its outer envelope is unchanged.

String constant-pool entries become validated UTF-8 bytes. Reachability filtering, exact-byte deduplication, unsigned-byte deterministic ordering, immortal ownership, and `ConstantId` behavior remain unchanged.

On acceptance, this ADR supersedes the ASCII String and separate String-layout contracts in ADR 0079 and ADR 0097. It replaces the ASCII constraints in ADR 0091 and the String-related portions of ADRs 0053, 0068, 0085, 0110, and associated context documents. It refines ADR 0123 by giving String and Bytes one runtime layout and by renaming Bytes bytecode operations to ByteSequence operations; Byte and Bytes remain the semantic types specified by ADR 0123.

The source change is intentionally breaking: existing `\xNN` String escapes must be rewritten, old compiled artifacts must be rebuilt, and code that assumed ASCII byte indices must move to scalar-indexed String APIs or explicit Bytes APIs.

## Required verification

The implementation is complete only when the following behaviors are covered by structural tests and the native test gate:

- Direct ASCII, multibyte UTF-8, NUL, BMP, and supplementary-plane String and Char literals parse, typecheck, format idempotently, serialize, lower, and execute.
- Valid short and Unicode escapes canonicalize as specified; malformed, empty, oversized, surrogate, out-of-range, multi-scalar Char, and removed `\xNN` forms produce precise diagnostics.
- Integer literals default to I64, elaborate to I32 under an I32 expectation, cover both signed limits, and reject out-of-range values in expressions and patterns.
- I32 arithmetic, comparison, wrapping, division, remainder, literal patterns, `I32 -> I64` sign extension, and `I64 -> I32` truncation agree between interpreter and Wasm.
- Char remains type-distinct from I32 and I64 through checked AST, Buslane, generic substitution, artifacts, hover, completion display, and diagnostics; Char expressions and patterns execute through the I32 representation.
- UTF-8 validation accepts every legal sequence class and rejects invalid continuation, truncation, overlong, surrogate, and above-maximum cases in both backends.
- String equality, scalar count, scalar lookup, scalar slicing, fold order, lexicographic scalar comparison, and embedded NUL behavior are demonstrated with mixed-width text.
- String/Bytes conversions reuse one runtime object, preserve ownership, and force copy-on-write when a converted Bytes value is updated while an alias remains observable.
- ByteSequence concatenation and slicing cover empty, full-range, proper-range, shared-owner, unique-owner, overflow, addressability, and resource-failure paths without publishing partial owners.
- String literal patterns use ByteSequence equality; no removed String operation remains reachable.
- Host input exposes a temporary pointer-length UTF-8 view, valid host output round-trips, and invalid host UTF-8 fails fatally without replacement.
- Buslane v4 and all bumped artifact schemas round-trip new cases and reject their immediately preceding versions at the version boundary.
- Generated interfaces are refreshed, formatting is clean, and all obsolete ASCII-only or separate-layout documentation is removed or explicitly superseded.

## Non-goals

- Unicode normalization, case folding, locale collation, grapheme segmentation, display width, regex, and Unicode property tables
- Implicit String/Bytes, Char/I32, I32/I64, or numeric-tower conversions
- Runtime reflection or compiler-recognized String, Char, I32, codec, iterator, or collection declarations
- Public byte cursors, String cursors, views, capacity, builders, ropes, small-string optimization, or cached scalar indices
- Lossy UTF-8 decoding or automatic replacement characters
- New String operator syntax, interpolation syntax, raw strings, Byte literals, or Bytes literals
- Additional host-value kinds

## Considered options

- Keeping ASCII String was rejected because it freezes the accidental equivalence of byte and character positions into the public text model.
- Making String an alias of Bytes was rejected because arbitrary bytes do not satisfy the UTF-8 validity invariant.
- Maintaining parallel String and Bytes runtime layouts or operations was rejected because both are exact packed byte sequences and the duplication had already diverged.
- Representing Char as I64 was rejected because it wastes width in stored values and erases the semantic type distinction. Char instead shares the I32 representation with I32.
- Treating Char as I32 was rejected because numeric values and Unicode scalar values have different invariants and APIs even when their machine representation is identical.
- Adding only an internal I32 carrier was rejected in favor of the ordinary public I32 primitive; the same representation is useful independently of text.
- Caching scalar count or indices in every ByteSequence was rejected because it penalizes arbitrary Bytes values and complicates the shared zero-copy representation.
- Providing compiler-owned scalar traversal, normalization, search, or iterators was rejected because these operations can be ordinary effect-polymorphic library code over the closed representation primitives.

## Consequences

- The compiler, Buslane, codecs, artifacts, VM CFG, bytecode, interpreter, Wasm backend, semantic tooling, formatter, and documentation gain explicit I32 and Char cases.
- String and Bytes remain statically separate while sharing allocation, ARC, copying, equality, slicing, and COW machinery.
- String byte length is O(1), while scalar operations are linear without an auxiliary index.
- Char/I32 conversion is zero-cost after typed intrinsic lowering; I32/I64 conversion performs an explicit width change.
- Unicode behavior is deterministic and independent of locale or normalization tables.
- Existing ASCII source assumptions, removed escapes, bytecode instruction names, schema versions, and compiled artifacts require coordinated migration.
