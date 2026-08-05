---
status: accepted
---

# LoisVM function result ABI

Every LoisVM bytecode function result is described by one complete runtime ABI:

- `Unit` occupies no result slot;
- `Value(representation, cleanup)` carries both the physical value class and the ownership cleanup contract.

Representation alone is insufficient. `I32 + Trivial` is an integer-like scalar, while `I32 + OwnedRef` is a reference-counted owner. Treating one as the other can release an integer as a heap reference or leak an owned result.

## Single result contract

The function body is the owner of its result ABI. A non-Unit `Return` source must have exactly the declared representation and cleanup. A direct call destination must exactly match the target body result ABI. A direct tail-call target must have exactly the current function result ABI.

Runtime imports do not duplicate a result ABI beside `RuntimeValueKind`. The result kind is its semantic owner and projects deterministically to the common result ABI: Bool, I64, F32, and F64 are trivial; String and Opaque are `I32 + OwnedRef`; Unit has no result. Import calls then use the same call-result validation as bytecode bodies.

Callable-value calls retain their existing erased physical call shape. Their destination or enclosing tail caller supplies the expected result ABI, while lowering remains responsible for constructing only callables whose source-level signature agrees with that use. This ADR adds no runtime type inspection and no second callable-signature table.

## Persistence

The current-only bytecode encoding uses result tag `0x01` for Unit. Tag `0x02` means Value and is followed by the existing representation tag and cleanup tag. Unknown tags and illegal representation-cleanup pairs are rejected.

This incompatible bytecode change raises the enclosing linked-program artifact schema from 8 to 9. Raw bytecode remains a lockstep internal format under ADR 0116; no legacy decoder or compatibility branch is added.

## Verification boundaries

The bytecode verifier checks the complete ABI for returns and statically known calls before execution. Binary decoding, interpreter loading, and Wasm compilation all invoke that verifier and publish no partial executable state after failure.

This ADR supersedes the result-descriptor decisions in ADRs 0086, 0087, 0088, and 0103. Their slot, input, terminator, and framing decisions remain in force.
