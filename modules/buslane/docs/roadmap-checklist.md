# Buslane Roadmap Checklist

This checklist tracks implementation work owned by the Buslane module. It is
intentionally concrete enough to drive development, while larger project
coordination and independent work items can still live in the issue tracker.

## 0. Existing Core Baseline

- [x] Own Buslane identities, metadata, types, expressions, diagnostics, and
  verification outside the Lane source front end.
- [x] Represent Buslane programs as metadata plus top-level value terms.
- [x] Lower checked source into Buslane expression-tree core.
- [x] Verify Buslane metadata, scope, typing, constructor arity, match
  exhaustiveness, and let-rec RHS shape.
- [x] Provide Buslane pretty printing and stable snapshot tests.
- [x] Provide Buslane text import/export support for the current core language.
- [x] Provide a reference interpreter for the current pure core language.

## 1. Effect Core Data Model And Text

- [x] Add Buslane identities for effects and operations: `EffectId` and
  `OperationId`.
- [x] Add metadata records for effect constructors and operation signatures.
- [x] Extend kinds with `Effect`.
- [x] Represent effect terms with empty effects, singleton effects, effect row
  variables, and unions.
- [x] Reuse `TypeParameterId` with `Kind::Effect` for effect row variables.
- [x] Attach a latent effect to function types; pure functions use the empty
  effect.
- [x] Update type equality, substitution, and metadata lookup helpers for
  effect-aware function types.
- [x] Add Buslane expressions for `perform`, handler tables, operation
  alternatives, and resume values.
- [x] Keep handler tables grouped by singleton effect before operation
  alternatives.
- [x] Make operation alternatives bind evaluated payload values positionally.
- [x] Update Buslane pretty output for effect metadata, function latent effects,
  `perform`, handlers, and resume values.
- [x] Update Buslane text parsing and import/export for the effect core.
- [x] Add text roundtrip tests for pure function types, open effect rows,
  `perform`, and deep handlers.

## 2. Verifier Effect Judgment

- [x] Add canonical effect normalization for union flattening, deduplication,
  order-insensitive singleton comparison, and row-variable preservation.
- [x] Add effect well-formedness checking against Buslane metadata and kind
  information.
- [x] Change expression synthesis to produce both a value type and an effect.
- [x] Verify calls by combining callee latent effects with argument effects.
- [x] Verify `perform` by checking the operation payloads and producing the
  operation result type plus its singleton effect.
- [x] Verify handlers by checking return clauses, operation alternatives, and
  resume usage under the handled effect.
- [x] Implement effect removal or unification for handled singleton effects in
  the presence of optional residual effect rows.
- [x] Reject operations used outside their owning effect metadata.
- [x] Reject operation alternatives whose payload or resume arity does not match
  the operation signature.
- [x] Report unhandled verifier cases as Buslane diagnostics, not source
  diagnostics.
- [x] Add verifier tests for closed effect sets, open effect rows, duplicate
  effects, missing handlers, wrong operation payloads, and invalid resume types.

## 3. Interpreter Deep Handlers

- [ ] Move the interpreter internals to an explicit evaluation-continuation
  model while keeping the public interpreter API stable where possible.
- [ ] Represent runtime resume values as captured continuations under a deep
  handler.
- [ ] Dispatch `perform` to the nearest matching handler table entry.
- [ ] Reinstall the same deep handler when a resume value is invoked.
- [ ] Support multi-shot resume according to the Buslane runtime semantics.
- [ ] Preserve strict left-to-right evaluation of callee, arguments, operation
  payloads, and handler clauses.
- [ ] Treat unhandled `perform` as a Buslane runtime error.
- [ ] Add interpreter tests for direct handling, nested handlers, resumed
  continuations, multi-shot resume, and unhandled operations.

## 4. Lanec Lowering Integration

- [ ] Extend checked-source or lowering input data with effect declarations and
  operation signatures once the source layer is ready.
- [ ] Lower effect metadata into Buslane `EffectId` and `OperationId` entries.
- [ ] Lower source-level operation calls into Buslane `perform`.
- [ ] Lower source-level handlers into Buslane handler tables grouped by effect.
- [ ] Lower source payload patterns before Buslane so operation alternatives
  only bind positional payload values.
- [ ] Preserve source presentation and spans for diagnostics outside Buslane;
  do not add source spans to Buslane nodes.
- [ ] Add integration snapshots from Lane source through checked source into
  Buslane effect core.

## 5. V1 Completion Gates

- [ ] `moon test modules/buslane`
- [ ] `moon test modules/buslane/text`
- [ ] `moon test modules/buslane/interpreter`
- [ ] `moon test modules/lanec`
- [ ] `moon info && moon fmt`
- [ ] Buslane text can roundtrip every effect-core form used by lowering.
- [ ] The verifier accepts and rejects effect programs according to the
  canonical effect model.
- [ ] The interpreter demonstrates deep handler resume behavior, including
  multi-shot resume.
- [ ] Lanec lowering can emit Buslane effect metadata, `perform`, and handler
  terms without leaking source syntax into Buslane.
