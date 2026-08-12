# Closed CPS effect-parameter representation

## Context

Selective CPS decomposes a source effect parameter `E` into two independent
facts:

```text
E_context  : [Answer : Type, Residual : Effect] -> Type
E_residual : Effect
```

The first fact determines the runtime representation of the handler context;
the second is the static non-algebraic residual projection. Earlier lowering
expanded callable binders but left effect parameters inside nominal data and
existential binders unchanged. LoisVM then used a parallel
`source -> (context, residual)` table to reconstruct substitutions that the CPS
IR did not contain.

That exception admitted a free source binder after alpha-renaming and gave the
same source parameter multiple lexical companion pairs. A side table cannot
make that representation closed or define an unambiguous inverse mapping.

## Decision

Selective CPS expands every source effect binder into the same ordered pair,
regardless of where it is bound:

- callable `forall` and type-lambda binders;
- nominal type parameters;
- constructor existential parameters; and
- pattern-bound existential parameters.

Every corresponding application supplies both arguments. A symbolic source
argument forwards the in-scope context and residual parameters. A concrete
effect supplies a higher-kinded context type lambda and its recursively
rewritten residual projection. Higher-kinded parameter kinds that accept an
effect argument are expanded by the same rule.

No source effect parameter remains in verified CPS Core. In particular,
runtime lowering does not receive a source/companion association and never
reconstructs an effect substitution from companion identity. Ordinary
capture-avoiding alpha-renaming is sufficient because every fact that remains
semantically relevant is an explicit binder in the IR.

Effect-indexed existential data carries runtime evidence for its explicit
higher-kinded context parameter when that kind requires evidence. The residual
parameter remains static. Phantom-evidence elimination, if introduced, is an
ordinary representation optimization over explicit binders; it is not a
license to restore an implicit source effect.

## Consequences

- CPS Core is closed under its own binders and metadata.
- Callable, nominal, constructor, and pattern applications share one
  effect-parameter elaboration rule.
- Core cloning cannot stale a separate CPS binder-family side table.
- Executable Program and LoisVM lowering no longer expose effect-companion
  metadata as a parallel input.
- The historical nominal-data exception from ISS-183 is superseded.
- Parameterized external effects continue to use recursive residual-position
  rewriting; source effects remain unavailable for runtime layout selection.
