---
status: accepted
---

# Byte and Bytes are pure built-in primitives

The complete reviewed design is recorded in
[the Byte and Bytes RFC](../byte-and-bytes-rfc.md).

Lane adds `Byte` and `Bytes` as globally available primitive types. `Byte` is
an unsigned scalar value in `0..255`; `Bytes` is a pure-value contiguous
sequence of Byte Values. Neither type depends on an import or a standard-library
declaration.

The first version adds no Byte or Bytes literal, operator, indexing, or update
syntax. Integer literals remain `Int`, and conversion is always explicit
through the closed builtin contract:

| Builtin expression | Required expected type |
| --- | --- |
| `builtin("%byte_to_int")` | `(Byte) -> Int` |
| `builtin("%int_to_byte")` | `(Int) -> Byte` |

`%byte_to_int` zero-extends its input. `%int_to_byte` is total and retains the
low eight bits of its input. `Byte` remains semantically distinct from `Int`,
although execution targets may use a normalized integer scalar carrier for
Byte parameters, locals, and results.

`Bytes` exposes only four primitive operations in the first version:

| Builtin expression | Required expected type |
| --- | --- |
| `builtin("%bytes_make")` | `(Int, Byte) -> Bytes` |
| `builtin("%bytes_length")` | `(Bytes) -> Int` |
| `builtin("%bytes_get")` | `(Bytes, Int) -> Byte` |
| `builtin("%bytes_set")` | `(Bytes, Int, Byte) -> Bytes` |

`%bytes_make` initializes every element with the supplied Byte Value. Its caller must provide a nonnegative length, and `%bytes_get` and `%bytes_set` require `0 <= index < length`. Violating these builtin preconditions is undefined Lane behavior; execution backends retain defensive checks so invalid bytecode cannot corrupt runtime memory. The builtin contract does not depend on a nominal `Option` type; ordinary library wrappers establish the preconditions and expose recoverable bounds checking.

A runtime Bytes Value is one owned ARC reference to an object containing its
logical length and exactly that many packed one-byte elements. The first
version reserves no spare capacity. `%bytes_set` consumes its owned Bytes
argument and returns a Bytes Value with one element replaced. It may reuse
uniquely owned storage and must copy shared storage, so no update can change any
previously observable value or alias. More precise future ownership analysis,
including Perceus-style reuse, may improve this decision without changing the
language or builtin contract.

`BytesCodec[T]`, checked conversion, equality, comparison, encoding, and other
convenience APIs are ordinary library abstractions. The compiler does not
recognize their declarations. `BoxedArray`, slices, append, concatenation,
capacity-bearing builders, shared mutable buffers, and external buffer
borrowing are outside this decision.

## Consequences

- Checked types, Buslane, artifacts, LoisVM bytecode, runtime layouts, and every
  execution backend gain explicit Byte and Bytes primitive cases.
- Bytes elements are packed bytes even when a backend widens scalar Byte Values
  in registers or operand slots.
- Adding the new primitive and bytecode tags follows the current-format
  versioning policy: affected schemas advance and old formats are rejected
  rather than decoded through compatibility branches.
- Allocation or resource exhaustion for an otherwise valid request remains a fatal runtime failure. Invalid length and index arguments violate the primitive preconditions and have undefined Lane behavior.
