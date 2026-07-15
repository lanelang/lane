# Effect erasure before bytecode

Lane lowers algebraic effects entirely before ANF and LoisVM bytecode. The pipeline uses compiler-private handler dictionaries and selective answer-type CPS; LoisVM contains no perform, resume, handler, effect-row, or handler-context instruction. Workspace ADR-0001 amends this ADR with built-in `Io`, extern bindings, and residual effect erasure.

## Pipeline contract

1. Reachable-effect specialization runs after linking and entry selection. Executable control flow cannot depend on unresolved concrete effect arguments.
2. Handler elaboration replaces source `Handle` and `Resume` forms with compiler-private install/invoke forms and ordinary reusable resume callables.
3. `mon-trans` applies when an effect row is open or contains any handled operation. Every handled operation is potentially multi-shot; resume counts are not analyzed.
4. `open-resolve` validates that generated context adaptations are actually supplied by the ambient row, then removes the proof markers.
5. `monadic-lift` turns generated local continuations into ordinary nested Buslane functions; the existing ANF lowering remains the sole owner of physical closure conversion and ARC representation.
6. Residual effect erasure removes remaining non-monadic latent effects only after effect-sensitive optimization, producing ordinary effect-free Buslane for ANF.

For monadic residual contexts `M`, non-monadic residual effect `R`, and handled result `H`, the local residual computation has the conceptual shape:

```text
M_(M,R)<H> = [Answer](context_arguments(M, Answer)..., continuation : (H) -> Answer ! R) -> Answer ! R
```

`mon-trans` removes the monadic portion while preserving `R`. Thus an `Io`-only function stays direct, an algebraic-effect function becomes CPS with no residual effect, and a function carrying both retains `Io` on its CPS ABI until residual effect erasure.

## Handler semantics

Handler dictionaries are immutable ordinary products selected statically. Resume callables are first-class and multi-shot; repeated calls rerun the captured continuation and reinstall the same deep handler. Residual effects that cross an answer change use relay dictionaries rather than reusing a dictionary instantiated at an incompatible answer type. Generated dictionaries and closures use ordinary closure, representation-erasure, and ARC rules and do not require VM stack capture.

## Extern boundary

The selected entry is `() -> Unit` or `() -> Unit ! Io`. `Io` requires no dictionary or root handler. Extern calls lower to synchronous primitive runtime imports without `OperationId`, continuation, handler record, or runtime-effect table. Runtime-import failures are fatal execution errors rather than Lane effects.

Consequences:

- Pure and `Io`-only functions retain direct-style source ABIs through `mon-trans`.
- Algebraic effects are represented only by compiler-generated ordinary values and calls before bytecode.
- Effect-sensitive optimization observes non-monadic residual effects until their explicit erasure.
- LoisVM runtime imports are ordinary extern targets, not effect operations or host handlers.
- A future Host Effect Handler requires a separate interface and does not alter this pipeline implicitly.
