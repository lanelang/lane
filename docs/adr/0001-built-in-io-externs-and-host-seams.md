---
status: accepted
---

# Built-in Io, extern bindings, and host seams

Lane separates effect semantics, compiler intrinsics, host linkage, and host effect handling. `Io` is an intrinsically identified, non-handleable effect for observable interaction with the execution environment. `builtin("...")` selects a compiler-known intrinsic from a closed signature table, while `extern("...")` names an open host symbol and lowers to a LoisVM runtime import.

An extern requires a complete expected monomorphic function type, primitive host parameters and result, and a latent effect of `Empty` or exactly `Io`. Scalar externs, inferred/default-pure signatures, generic externs, algebraic-effect externs, and fallback between extern and intrinsic lookup are rejected. The extern declaration is an unsafe programmer assertion; an incorrect type or effect invalidates the program's guarantees.

`Basic.Io` exports `println : (String) -> Unit ! Io = extern("println")`. Neither `Basic.Io` nor the `println` runtime symbol receives compiler or command special treatment. The selected executable entry remains `() -> Unit` or `() -> Unit ! Io`; residual algebraic effects are rejected. Runtime-import resolution and invocation failures are fatal execution errors rather than Lane effects.

Extern calls are synchronous and receive no continuation. A future Host Effect Handler may separately receive algebraic-operation payloads and a first-class multi-shot resume continuation, but that interface is not part of runtime imports, does not implement `Io`, and does not change the current entry contract.

`mon-trans` is driven by the general monadic-effect predicate: an open row or any handled operation requires translation, and resume counts are never analyzed. Translation preserves non-monadic residual effects such as `Io`; a later residual-effect-erasure pass removes them only after effect-sensitive optimization while preserving extern calls and evaluation order.

This ADR supersedes Buslane ADR-0010, every context-local ADR-0019 and ADR-0020, and Lane Command ADR-0055. It amends the classification and runtime-boundary portions of Lanec ADR-0067 and the runtime-import terminology of Lanec ADR-0068.
