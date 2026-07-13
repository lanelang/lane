# Optional slot and call operand encoding

LoisVM v1 uses one canonical `OptionalSlot` wire form everywhere an optional `SlotId` appears: `slot_plus_one:u32le`. Zero denotes absence. A nonzero value N denotes `SlotId = N - 1`. This form requires no separate presence tag and is used for function environments, direct-call environments, returning-call destinations, return sources, and projection witness destinations.

A SlotId array is encoded as `count:u32le` followed immediately by exactly that many `SlotId:u32le` values. Empty arrays are permitted. Arrays carry no element tag, byte length, padding, representation list, cleanup list, or implicit trailing terminator.

The complete `call_direct` instruction operands are:

1. `target_function_id:u32le`
2. `environment_slot_plus_one:u32le`
3. `witness_count:u32le` and that many witness SlotIds
4. `user_argument_count:u32le` and that many user-argument SlotIds
5. `destination_slot_plus_one:u32le`

The complete `call_value` instruction operands are:

1. `callable_slot:u32le`
2. `witness_count:u32le` and that many witness SlotIds
3. `user_argument_count:u32le` and that many user-argument SlotIds
4. `destination_slot_plus_one:u32le`

A zero destination denotes a Unit call. A nonzero destination denotes the dead slot that receives one non-Unit owned result. Calls never release an overwritten logical value; compiler lowering releases any previous owner before reusing the destination.

Witness arguments are non-consuming `I32 + Trivial` reads. Trivial user arguments are also non-consuming reads. Owned user arguments transfer ownership into the callee and become logically dead in the caller. `call_direct` additionally consumes a nonzero owned environment. `call_value` consumes the callable and uses consuming callable projection to establish the callee environment.

The `return` terminator contains only `source_slot_plus_one:u32le`. Zero returns Unit. A nonzero value consumes that source owner and returns it to the caller.

The complete `tail_call_direct` operands are target FunctionId, environment OptionalSlot, counted witness SlotId array, then counted user-argument SlotId array. The complete `tail_call_value` operands are callable SlotId, counted witness array, then counted user-argument array. Neither tail terminator contains a destination. Their witness and argument consumption rules match returning calls; direct tail calls consume a nonzero environment, and value tail calls consume their callable.

Call records do not duplicate target arity, argument representations, cleanup categories, function context kind, result representation, or call-shape identity. Decoding rejects a zero direct target FunctionId and malformed counts or framing. Direct-target range, referenced SlotId range, arity, representation, cleanup, context, result, and ownership agreement remain trusted compiler invariants rather than full image verification.

Consequences:

- Every optional SlotId uses the same four-byte encoding.
- Zero remains a compact absence sentinel without conflicting with SlotId zero.
- Counted SlotId arrays have one canonical shape and permit emptiness.
- Direct and value calls have complete fixed operand orders.
- Unit calls and returns carry zero rather than a separate option tag.
- Call destinations must be logically dead before execution.
- Trivial inputs are read; owned inputs and environments transfer ownership.
- Value calls consume callable ownership and project their environment internally.
- Tail calls reuse normal call argument encoding without a destination.
- Call records do not serialize redundant type or arity metadata.
- Loading preserves the trusted-bytecode boundary instead of becoming a semantic verifier.
