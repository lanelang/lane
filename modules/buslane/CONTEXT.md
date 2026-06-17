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

## Relationships

- `lanec` lowers checked Lane source into the **Buslane Core Language**.
- `buslane` does not depend on Lane parser, resolver, or source diagnostics.
- The formal contract for Buslane belongs in the `spec` repository; this
  repository owns the implementation-facing model, verifier, interpreter, and
  pretty printer.
