---
status: accepted
---

# Canonical instance-global lifecycle

LoisVM verification owns one canonical Instance Global lifecycle. Every
non-companion global is a lifecycle root in table order. An `OwnedErased`
global and its immediately preceding layout companion form one atomic root.
The Instance Initializer must initialize those roots in canonical order, and
control-flow predecessors may merge only at the same initialized prefix.
Every global borrow and transitive direct-call dependency must belong to that
prefix. Every normal initializer return requires the complete prefix.

Successful verification produces a `GlobalLifecyclePlan` beside the verified
image. The plan records root ordinals, owned-root ordinals, companion identity,
and cleanup categories. Execution backends consume this plan. They do not
recheck initializer identity, duplicate initialization, initialized borrows, or
normal-return completeness at runtime. Runtime-dependent failures such as
allocation exhaustion, bounds failure, indirect-call ABI mismatch, and host
failure remain dynamic.

An execution instance tracks only the count of successfully installed owned
roots. Advancing that count after an owned root is fully stored makes the
initialized owned roots a cleanup prefix even when initialization fails.
Cleanup walks the plan in reverse prefix order. Trivial roots require neither
runtime progress state nor cleanup work.

The Wasm tier stores global payloads in eight-byte Instance Root Table cells;
it does not store per-root initialized flags. One packed four-byte descriptor
per owned root records its GlobalId and selects reference, callable, or erased
cleanup. A single shared loop
performs normal and exceptional cleanup, so entry-lifecycle code size is
independent of the number of globals.

This decision narrows the accepted LoisVM bytecode language: images whose
initializer reaches the same initialized set through different orders were
previously accepted. Bytecode has no independent format version, so the
enclosing linked-program schema advances from 14 to 15. Schema 14 artifacts are
rejected rather than interpreted with the new lifecycle contract.
