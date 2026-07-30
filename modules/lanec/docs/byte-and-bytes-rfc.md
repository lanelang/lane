# RFC: Pure Byte and Bytes primitives

Status: Accepted

Decision summary: [ADR 0123](adr/0123-byte-and-bytes-primitives.md)

The semantic Byte and Bytes design in this RFC remains active, while its separate runtime Bytes layout and `Bytes*` instruction names are superseded by ADR 0124's shared ByteSequence representation.

## Summary

Lane will add two globally available primitive types:

- `Byte`, an unsigned scalar value in `0..255`;
- `Bytes`, a pure-value contiguous sequence of packed Byte Values.

The feature adds no mutable source construct. A Bytes update returns a new
value and cannot change any previously observable value or alias. The runtime
may implement that contract with copy-on-write: consume the input owner, reuse
the allocation when it is unique, and copy it when it is shared.

The first version is intentionally small. It adds two explicit Byte conversion
builtins and four Bytes builtins. It does not add literals, indexing syntax,
mutation syntax, `BoxedArray`, slices, append, concatenation, capacity, or
compiler knowledge of a standard-library codec.

## Motivation

Lane is pure and does not permit shared mutable values. Its nominal
`Basic.Data.List.List[T]` remains a good persistent recursive structure, but it
is not an efficient representation for dense byte-oriented data:

- every element participates in a linked structure;
- indexing is linear;
- the representation cannot provide contiguous host or runtime storage;
- binary encoding and decoding require unnecessary allocation and indirection.

The goal is not to add a conventional mutable array. The goal is to provide a
compact primitive value on which ordinary pure libraries can build binary
data, codecs, checked indexing, and eventually higher-level array APIs.

## Goals

- Preserve pure value semantics and referential transparency.
- Store every element of a Bytes Value in one byte.
- Make passing a Bytes Value constant-size through an owned ARC reference.
- Permit efficient repeated updates when ownership proves the prior value dead.
- Keep the compiler builtin contract closed and exactly typed.
- Keep recoverable library types such as `Option` outside the compiler.
- Use the same semantics in the LoisVM interpreter and Wasm compiled tier.
- Preserve Byte and Bytes through generic erasure, artifacts, analysis, and
  tooling like every other primitive type.

## Non-goals

The first version does not provide:

- shared mutation, references, mutable bindings, or assignment;
- a source-level `Array` or `MutArray` abstraction;
- `BoxedArray`;
- `UnboxedArray` as a generic or nominal type;
- Byte or Bytes literal syntax;
- implicit conversion between `Byte` and `I64`;
- Byte arithmetic, comparison, or bitwise operators;
- Bytes indexing or update syntax;
- slice or parent-backed view values;
- append, concatenation, builders, or spare capacity;
- a host ABI for Byte or Bytes;
- compiler-recognized `BytesCodec`, `Iso`, or `Option` declarations;
- runtime reflection or observable Bytes object identity.

These omissions are scope boundaries, not claims that the features can never
be added.

## Language model

### Byte

`Byte` is a primitive type of kind `Type`. It is not a nominal alias for `I64`.
Its values are unsigned integers in the inclusive range `0..255`.

`Byte` is globally available in the same way as `I64`, `F64`, `Bool`,
`String`, and `Unit`. Type resolution recognizes the primitive before type
parameters, nominal declarations, aliases, or imports. No import enables or
changes Byte semantics.

Lane adds no Byte literal. An integer literal such as `42` continues to have
type `I64`, including when a surrounding expression expects `Byte`. There is
no implicit conversion in either direction.

### Bytes

`Bytes` is a primitive type of kind `Type`. A Bytes Value is a finite ordered
sequence of Byte Values with a nonnegative logical length.

`Bytes` is globally available and independent of imports. It is not a String:

- it may contain arbitrary bytes rather than ASCII text;
- it has no text decoding or character semantics;
- it does not inherit String operations;
- it has no literal syntax in the first version.

Bytes obeys Pure Array Value Semantics. For any source value `xs`, evaluating
an update that produces `ys` cannot change the length or elements subsequently
observed through `xs` or any alias of `xs`.

## Closed builtin contract

A builtin remains an ordinary `builtin("%name")` expression checked against an
expected type. This RFC adds no alternate builtin declaration or invocation
syntax.

### Byte conversions

| Builtin expression | Required expected type |
| --- | --- |
| `builtin("%byte_to_i64")` | `(Byte) -> I64` |
| `builtin("%i64_to_byte")` | `(I64) -> Byte` |

`%byte_to_i64` zero-extends a Byte Value into `I64`.

`%i64_to_byte` is total. It retains the low eight bits of the input, equivalently
returning the canonical result modulo 256:

| Input | Result |
| ---: | ---: |
| `0` | `0` |
| `255` | `255` |
| `256` | `0` |
| `257` | `1` |
| `-1` | `255` |
| `-256` | `0` |

### Bytes operations

| Builtin expression | Required expected type |
| --- | --- |
| `builtin("%bytes_make")` | `(I64, Byte) -> Bytes` |
| `builtin("%bytes_length")` | `(Bytes) -> I64` |
| `builtin("%bytes_get")` | `(Bytes, I64) -> Byte` |
| `builtin("%bytes_set")` | `(Bytes, I64, Byte) -> Bytes` |

The operations have these semantics:

- `%bytes_make(length, fill)` creates a Bytes Value of exactly `length`
  elements, each equal to `fill`.
- `%bytes_length(bytes)` returns the logical element count.
- `%bytes_get(bytes, index)` returns the element at `index`.
- `%bytes_set(bytes, index, value)` returns a Bytes Value with the same length,
  equal to `bytes` at every position except `index`, where it contains `value`.

The six builtin names are closed compiler intrinsics. A wrong expected type is
a normal builtin signature diagnostic; it does not create an overloaded or
partially applicable intrinsic.

All six functions have an empty Lane effect row. Their value-domain preconditions are established by ordinary library wrappers; allocation and runtime failure do not introduce a user-handleable algebraic effect.

## Preconditions and runtime failure

The primitive layer is intentionally partial. Calls must satisfy these value-domain preconditions:

| Operation | Precondition |
| --- | --- |
| `%bytes_make(length, _)` | `length >= 0` |
| `%bytes_get(bytes, index)` | `0 <= index < length(bytes)` |
| `%bytes_set(bytes, index, _)` | `0 <= index < length(bytes)` |

Violating a precondition is undefined Lane behavior. Interpreter and compiled backends retain defensive validation and may panic or trap, but source programs cannot rely on that behavior being evaluated or reported consistently. No operation clamps an index, wraps an index, or returns a default byte. `%i64_to_byte` is total because truncation is its specified behavior.

Safe APIs are ordinary library code. A library checks the preconditions before invoking the primitive and may return `Option`, a nominal error type, or an effectful result without changing the compiler contract. Allocation or resource exhaustion for an otherwise valid request is a fatal runtime failure only when that allocation is actually executed. Effect-aware optimization may remove an unused empty-effect allocation, in which case no allocation or resource failure occurs.

## Runtime representation

### Scalar Byte carrier

`Byte` remains a distinct semantic primitive throughout checked types and
Buslane. Its scalar execution representation uses the existing `I32 + Trivial`
slot class, while preserving the invariant that its value lies in `0..255`.

This does not make `Byte` definitionally equal to `I64`; Lane `I64` uses its
existing signed 64-bit semantics and `I64 + Trivial` representation. The two
types interact only through the explicit conversion builtins.

Using `I32` as the scalar carrier does not change Bytes element density. Values
inside a Runtime Bytes Object occupy one byte each.

### Runtime Bytes Object

A Bytes Value uses `I32 + OwnedRef`: one ARC-owned reference to a Runtime Bytes
Object. The object contains:

1. the existing common ARC object header;
2. one logical byte length;
3. exactly that many packed bytes;
4. only the alignment padding required by the allocator.

The first version stores no capacity and no parent reference. It does not
represent a slice or view. Its physical organization may follow the existing
Runtime String Object layout, but Bytes has its own primitive type, runtime
payload classification, and layout recipe.

Passing, returning, capturing, or storing a Bytes Value transfers or retains
the reference according to the existing compiler-directed ARC rules. It does
not copy the byte payload merely because the value crosses a function or data
boundary.

## Pure update and ownership

`%bytes_set` consumes one owned reference and produces one owned reference.
Conceptually:

```text
bytes_set(old, index, value):
  check index
  if old is uniquely owned:
    write value into old[index]
    return old
  else:
    new = exact_copy(old)
    release the consumed old owner
    write value into new[index]
    return new
```

The uniqueness test is a runtime implementation detail based on the existing
ARC ownership state. Shared and immortal references are not uniquely owned.

If source code still needs the old value, ownership lowering establishes
another owner before the call. The runtime therefore observes a shared object
and copies it. If the argument is dead after the update, its consumed owner may
be the only reference and the allocation may be reused.

For example:

```lane
let original = make(2, zero)
let changed = set(original, 0, one)
get(original, 0) // zero
get(changed, 0)  // one
```

The two observations are required regardless of whether the implementation
copied or reused storage internally. Lane exposes neither reference equality
nor a way to observe the uniqueness test.

This contract is compatible with future Perceus-style reuse analysis. Such an
analysis may prove more arguments dead and reduce retains or copies without
changing source typing, builtin signatures, bytecode semantics, or observable
results.

## Compiler architecture

### Front end and semantic types

`Byte` and `Bytes` become explicit cases of the compiler's `PrimitiveType`.
They participate in:

- resolution and kind checking;
- type equality, normalization, substitution, and display;
- checked expressions and declaration signatures;
- interfaces, semantic fingerprints, and artifacts;
- hover, completion details, semantic tokens, and definition-independent type
  presentation.

No lexer, parser, CST, or formatter grammar changes are required because the
names use ordinary type-name syntax and the RFC adds no literals or operators.

### Intrinsic signature ownership

The current intrinsic signature model reuses an ABI value-kind enum also used
for external host bindings. This RFC does not add Byte or Bytes to the host
runtime-import ABI.

The compiler intrinsic contract must therefore represent Byte and Bytes without
silently widening the external ABI. If the existing shared enum cannot express
that boundary, it must be split so intrinsic value kinds and runtime-import
value kinds have separate ownership. Adding Byte or Bytes to the external
`ValueKind` merely to type these six intrinsics is not an acceptable shortcut.

### Buslane

Buslane gains `Byte` and `Bytes` primitive cases. They remain distinct under
definitional equality and serialization.

The physical mappings are:

| Buslane primitive | Slot representation | Cleanup |
| --- | --- | --- |
| `Byte` | `I32` | `Trivial` |
| `Bytes` | `I32` | `OwnedRef` |

Generic erasure and unerasure must handle both types through ordinary layout
witnesses. Byte uses a primitive trivial layout; Bytes uses an owned-reference
layout whose destructor releases the Runtime Bytes Object. No generic-code
special case may treat either type as `I64`, `String`, or a nominal value.

### Intrinsic lowering

The typed intrinsic identities lower to dedicated VMCFG operations rather than
remaining stringly named calls:

| Operation | Destination | Inputs | Ownership |
| --- | --- | --- | --- |
| `ByteToI64` | `I64 + Trivial` | Byte `I32 + Trivial` | read |
| `I64ToByte` | `I32 + Trivial` | I64 `I64 + Trivial` | read |
| `BytesMake` | `I32 + OwnedRef` | length `I64`, fill `I32` | creates owner |
| `BytesLength` | `I64 + Trivial` | Bytes `I32 + OwnedRef` | reads/borrows |
| `BytesGet` | `I32 + Trivial` | Bytes `I32 + OwnedRef`, index `I64` | reads/borrows |
| `BytesSet` | `I32 + OwnedRef` | Bytes `I32 + OwnedRef`, index `I64`, Byte `I32` | consumes Bytes owner |

VMCFG occurrence, ownership, liveness, simplification, cloning, pretty
printing, finalization, and verification must each model the new operations
through their ordinary instruction contracts. `%bytes_set` consumption must
not be reconstructed later from its builtin name.

## LoisVM bytecode and execution

LoisVM gains corresponding dedicated bytecode instructions. Their verifier
contracts use the representation and cleanup combinations above. Byte does not
add a new bytecode slot representation: it uses `I32 + Trivial`. Bytes does not
add a new cleanup category: it uses `I32 + OwnedRef`.

The bytecode image gains a Bytes layout recipe so generic layout witnesses,
destruction, interpreter objects, and Wasm heap objects agree on the owned
reference. The String constant pool remains String-only because this RFC adds
no Bytes literal or constant instruction.

Both execution tiers implement identical valid-input behavior:

- the interpreter adds a Bytes heap payload and executes all six operations;
- the Wasm compiler emits scalar conversion code and Runtime Bytes Object
  allocation, access, bounds checks, uniqueness checks, copying, and release;
- both defensively reject invalid length and index operands without publishing a
  partial owner, without requiring identical failure classification or trap
  details;
- resource exhaustion and allocation failure use the existing fatal runtime
  failure boundary only for allocations that remain after optimization and are
  actually executed.

The linked program carries only the current bytecode format. Adding primitive,
layout, and instruction tags advances the affected Buslane/artifact/linked
program schema versions. Decoders reject older versions instead of adding
legacy branches. New tags append to their closed namespaces and do not renumber
existing tags.

## Standard-library boundary

The compiler provides representation and primitive operations, not policy.
Library code owns:

- checked indexing and update APIs;
- equality, comparison, hashing, and formatting;
- byte arithmetic and bit operations, if desired;
- builders, concatenation, and slicing abstractions;
- textual and binary encodings;
- the proposed ordinary value:

```lane
struct BytesCodec[T] {
  encode : (T) -> Bytes
  decode : (Bytes) -> Option[T]
}
```

`BytesCodec[T]` is illustrative library design, not a canonical compiler ABI.
The compiler does not resolve it by module path or name, does not derive it,
and assumes no codec laws. A useful library law is
`decode(encode(value)) == some(value)`; arbitrary Bytes Values need not decode,
and successful decoding need not preserve the original byte spelling.

## Rejected alternatives

### Shared mutable Array

Rejected because aliases could observe in-place updates, violating Lane's pure
value model and interacting poorly with first-class multi-shot continuations.

### Effect-based physical mutation

Rejected as the foundation for Array values. Lane effects describe ordinary
program behavior; they do not make shared mutable identity safe or give a
captured multi-shot continuation a unique buffer.

### Nominal Bytes with compiler-known representation

Rejected for this feature. It would require a new representation attachment
between arbitrary nominal declarations and closed compiler intrinsics, along
with module/provider identity rules. `Byte` and `Bytes` are fundamental enough
to be explicit primitives instead.

### Primitive Byte but nominal Bytes

Rejected because it leaves the central question—how a nominal type binds to
packed storage and intrinsic operations—unsolved.

### One scalar word per Bytes element

Rejected. `I32` is acceptable as the transient scalar Byte carrier, but Runtime
Bytes Objects must store packed one-byte elements.

### Option-returning primitive operations

Rejected because it would make the compiler intrinsic contract depend on a
specific nominal `Option` declaration. Fatal primitive operations plus ordinary
safe library wrappers keep the boundary orthogonal.

### Uninitialized allocation

Rejected because it exposes an invalid intermediate value or requires a hidden
linearity rule. `%bytes_make` initializes every element with an explicit Byte
Value.

### Capacity and append in the first version

Rejected because the agreed operations never change length. An exact allocation
has a smaller object contract and avoids speculative builder semantics.

### Dedicated Byte and Bytes syntax

Rejected for the first version. It would expand parsing, formatting, literal
typing, and expected-type behavior without being required to establish the
primitive and runtime model.

## Implementation sequence

Implementation should proceed in vertical, testable steps:

1. Add the semantic primitive cases and exact intrinsic signature validation.
2. Extend checked/Buslane conversion, display, equality, codecs, interfaces,
   artifacts, semantic fingerprints, and analysis.
3. Add VMCFG and bytecode instruction models, codecs, disassembly, occurrence
   semantics, and ownership behavior.
4. Add Runtime Bytes Object support and interpreter execution.
5. Add Wasm compiled-tier execution with the same panic and copy-on-write
   behavior.
6. Update schema versions, generated interfaces, bytecode documentation, and
   complete examples.

Each step must remove exhaustiveness fallbacks exposed by the new primitive.
The implementation must not route Byte through `I64` semantic cases or Bytes
through `String` semantic cases merely because their physical representations
overlap.

## Validation plan

### Type and builtin contract

- `Byte` and `Bytes` resolve without imports in every type position.
- They remain distinct from `I64`, `String`, nominal types, and each other.
- Every builtin accepts exactly its specified expected type.
- Unknown builtin names and mismatched signatures retain ordinary diagnostics.
- The external host ABI does not acquire Byte or Bytes accidentally.

### Byte behavior

- Conversion tests cover `0`, `1`, `255`, `256`, `257`, `-1`, `-255`, and
  `I64` extrema.
- Round trips satisfy
  `byte_to_i64(i64_to_byte(value)) == canonical_modulo_256(value)`.
- Byte survives function arguments/results, local bindings, fields, enum
  payloads, closures, globals, and generic erasure.

### Bytes behavior

- Zero-length and nonzero `%bytes_make` values have the expected length and
  contents.
- `%bytes_get` reads the first, middle, and final valid positions.
- `%bytes_set` updates the first, middle, and final valid positions.
- An update preserves every unmodified element and preserves the logical
  length.
- Retaining an alias before `%bytes_set` proves the old alias remains unchanged.
- A white-box runtime test may verify unique-owner allocation reuse, but reuse
  is an optimization and is not observable Lane behavior.
- Bytes survives function arguments/results, local bindings, fields, enum
  payloads, closures, globals, and generic erasure.

### Preconditions and failure behavior

- Valid calls satisfy nonnegative length and in-bounds index preconditions.
- Runtime implementations defensively reject invalid operands, but source behavior after a precondition violation is undefined.
- An oversized allocation or allocation failure uses fatal runtime failure only
  when the allocation is actually executed; an unused empty-effect allocation
  removed by optimization has no runtime failure obligation.
- No failing operation returns a default or partially published Bytes Value.

### Serialization and execution

- Buslane and artifact binary round trips preserve both primitive identities.
- Artifact inspection and Buslane text use `Byte` and `Bytes`.
- Bytecode encode/decode/disassemble round trips cover every new instruction
  and the Bytes layout recipe.
- Compiler-generated bytecode assigns the documented representation and cleanup
  operands to every new instruction.
- Interpreter and Wasm/JIT execution produce identical successful results for valid inputs.
- Bytecode with invalid primitive operands is rejected safely by every backend,
  but failure classification, trap details, and evaluation after undefined
  behavior need not agree.
- Current-format version mismatches are rejected before execution.

### Tooling

- Hover and inlay presentation render the new type names.
- Completion classifies both names as primitive type candidates in type space.
- Semantic indexing and workspace snapshots preserve their signatures.
- Formatter behavior is unchanged because no new surface syntax exists.

The repository acceptance gate is:

```sh
MOONBIT_NEW_NATIVE=0 moon test --target native
moon info
moon fmt
```

No other target is part of the test-result gate unless explicitly requested.

## Acceptance criteria

The feature is complete when:

1. all six builtin expressions have the exact specified types and semantics;
2. Byte and Bytes are distinct primitives across the complete compiler and
   artifact pipeline;
3. Bytes uses packed one-byte storage behind an owned ARC reference;
4. `%bytes_set` preserves pure alias semantics and supports unique-owner reuse;
5. interpreter and Wasm/JIT results agree for valid inputs, while invalid
   primitive operands are rejected safely without requiring identical trap
   details;
6. generic erasure, serialization, analysis, and tooling retain both types;
7. no `Option`, `BytesCodec`, Basic module, nominal provider, or external ABI
   special case enters the compiler;
8. the native test gate, `moon info`, and `moon fmt` pass.

## Deferred work

Future RFCs may independently design:

- `BoxedArray` and the representation of generic elements;
- efficient append, concatenation, and capacity-bearing builders;
- copied slices or shared immutable views;
- Byte arithmetic and bitwise library APIs;
- Byte or Bytes literals;
- host ABI borrowing or copying of Bytes data;
- Perceus ownership analysis.

None of these may weaken Pure Array Value Semantics or make the first-version
builtin contract depend on a standard-library nominal identity.
