# Buslane

Buslane is Lane's typed semantic core language. It is intentionally independent
from the Lane source front end so it can remain a small reusable module.

## Language

**Buslane Core Language**:
The typed expression-tree core produced after checked source elaboration and
before ANF.
_Avoid_: source AST, parser syntax, compiler symbol table

**Buslane Program**:
A metadata registry plus a sequence of top-level value terms.
_Avoid_: source file, package, module

**Buslane Verifier**:
The pure checker that validates Buslane metadata, scope, and expression typing.
_Avoid_: Lane source typechecker, parser validation

**Buslane Interpreter**:
The reference evaluator for Buslane programs.
_Avoid_: source interpreter, bytecode VM

**Buslane Effect Core**:
The Buslane core-language model for effect constructors, effect operations,
effect terms, `perform`, handlers, resume values, and effect-aware verification.
_Avoid_: source effect syntax, source `with` block, external runtime plugin

**Deep Handler**:
A Buslane handler whose resume value reinstalls the same handler around the
captured continuation.
_Avoid_: shallow handler, callback, exception handler

**Handler Table**:
A Buslane handler structure grouped by handled singleton effect and then by
effect operation alternative.
_Avoid_: source `with` block, flat operation map, exception table

**Operation Alternative**:
The Buslane handler arm for one **Effect Operation** inside a **Handler Table**.
_Avoid_: source pattern arm, function clause, callback

**Resume Value**:
A Buslane runtime value representing the captured continuation under a
**Deep Handler**.
_Avoid_: host callback, exception payload, one-shot continuation

**Closed Effect Set**:
A fully known finite effect set with no effect row variable.
_Avoid_: open effect row, effect subtyping

**Open Effect Row**:
An effect set that contains an effect row variable standing for unknown residual
effects.
_Avoid_: closed effect set, effect subtyping, implicit weakening

**Effect Row Variable**:
A type-level effect variable used to preserve unknown residual effects through
effect-polymorphic functions and handlers.
_Avoid_: singleton effect, operation identity, runtime value

**Canonical Effect**:
The normalized representation of an effect set used for equality, removal, and
unification.
_Avoid_: source effect syntax, array order, duplicate-preserving effect list

**Effect Operation**:
A Buslane metadata identity invoked by `perform` within its owning effect
constructor.
_Avoid_: value identity, function value, external value

**Effect Kind**:
The Buslane kind for effect constructors, singleton effect terms, and effect
row variables.
_Avoid_: value type, operation set

**Function Latent Effect**:
The effect set attached to a Buslane function type.
_Avoid_: operation set, inferred capability

## Relationships

- `lanec` lowers checked Lane source into the **Buslane Core Language**.
- `buslane` does not depend on Lane parser, resolver, or source diagnostics.
- **Buslane Effect Core** belongs to the **Buslane Core Language**, not to
  Lane source syntax.
- A **Handler Table** is grouped by singleton effect before **Operation
  Alternatives**.
- An **Operation Alternative** binds evaluated operation payloads positionally;
  source payload patterns are lowered before Buslane.
- A **Resume Value** reinstalls its **Deep Handler** when invoked.
- **Closed Effect Set** is the fully known case of an effect set; **Open Effect
  Row** is the effect-polymorphic case.
- **Canonical Effect** ignores singleton order and duplicate singleton effects.
- **Buslane Effect Core** must be represented by Buslane text parsing and
  pretty printing.
- **Effect Row Variables** have **Effect Kind**.
- **Effect Row Variables** are type-level parameters, not a separate runtime
  identity family.
- An **Effect Operation** is not a Buslane value and does not enter the value
  context.
- An unhandled **Effect Operation** is not resolved by external runtime plugins.
- A **Function Latent Effect** is an effect set of singleton effects plus
  optional residual row information, not a flattened operation set.
- **Buslane Interpreter** must evaluate **Deep Handlers** according to Buslane
  runtime semantics.
- The formal contract for Buslane belongs in the `spec` repository; this
  repository owns the implementation-facing model, verifier, interpreter, and
  pretty printer.
