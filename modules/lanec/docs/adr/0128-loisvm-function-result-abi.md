---
status: accepted
---

# LoisVM function result ABI

Every LoisVM bytecode function result is described by one complete runtime ABI:

- `Unit` occupies no result slot;
- `Value(representation, cleanup, kind)` carries the physical value class, the
  ownership cleanup contract, and the semantic value category.

Representation alone is insufficient. `I32 + Trivial` is an integer-like scalar, while `I32 + OwnedRef` is a reference-counted owner. Treating one as the other can release an integer as a heap reference or leak an owned result.

## Single result contract

The function body is the owner of its result ABI. A non-Unit `Return` source
must have the declared complete value ABI. A direct call destination and a
direct tail-call result must instantiate the target ABI consistently. In
particular, an abstract higher-kinded reference may bind to one concrete
reference category, but equal physical storage never permits unrelated scalar,
ByteSequence, Data, Environment, callable, layout, or opaque values to be
interchanged.

Runtime imports do not duplicate a result ABI beside `RuntimeValueKind`. The result kind is its semantic owner and projects deterministically to the common result ABI: Bool, I64, F32, and F64 are trivial; String and Opaque are `I32 + OwnedRef`; Unit has no result. Import calls then use the same call-result validation as bytecode bodies.

The original callable-value paragraph is superseded by ADR 0129. Callable
calls now name a canonical complete Callable ABI, including this result ABI,
and dynamically selected targets are checked against it.

## Persistence

The current-only bytecode encoding uses result tag `0x01` for Unit. Tag `0x02`
means Value and is followed by representation, cleanup, and semantic-kind tags.
Unknown tags and illegal combinations are rejected.

This incompatible bytecode change raised the enclosing linked-program artifact
schema from 8 to 9. ADR 0129 subsequently raises it from 9 to 10. The semantic
value-kind extension raises it from 10 to 11. Raw bytecode
remains a lockstep internal format under ADR 0116; no legacy decoder or
compatibility branch is added.

## Verification boundaries

The bytecode verifier checks the complete ABI for returns and statically known calls before execution. Binary decoding, interpreter loading, and Wasm compilation all invoke that verifier and publish no partial executable state after failure.

This ADR supersedes the result-descriptor decisions in ADRs 0086, 0087, 0088, and 0103. Their slot, input, terminator, and framing decisions remain in force.
