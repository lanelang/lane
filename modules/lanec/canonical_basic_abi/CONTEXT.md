# Canonical Basic ABI Context

## Purpose

This package owns the module-input semantic adapter for compiler-required Basic
declarations. It is the only package that interprets canonical Basic provider
requirements as declaration identities and validates their semantic shapes.

## Glossary

**Canonical Basic ABI**:
The certified module-input catalog for Tuple, List, Void, and structural-
derivation providers. It is constructed once from a Canonical Basic ABI Identity
Catalog and checked public module-interface declarations; later consumers receive
only its resolved identities and semantic results.
_Avoid_: provider symbol directory, consumer name lookup, repeated shape validation, implicit Basic import

**Canonical Basic ABI Identity Catalog**:
The immutable construction state mapping fixed Basic provider requirements to
resolved declaration and variant identities from the current Module and
Reachable Interface Closure. It carries no independent shape policy and can be
certified only by the Canonical Basic ABI adapter.
_Avoid_: semantic validation result, string-keyed lookup, backend ABI
