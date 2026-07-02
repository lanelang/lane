# Explicit Resume Continuations

Buslane interpreter support for deep handlers uses explicit runtime resume values and captured continuations instead of host exceptions or callback-only control flow. This keeps the interpreter aligned with Buslane semantics: `perform` captures the operation-delimited continuation to the nearest matching handler, and invoking a resume value reinstalls that same handler around the captured continuation.

## Consequences

- The interpreter can represent multi-shot resume values directly because invoking a resume does not consume it.
- The internal evaluator may need a continuation-passing structure even though the public program evaluation API can remain unchanged.
