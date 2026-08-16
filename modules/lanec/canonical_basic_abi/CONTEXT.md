# Canonical Basic ABI Context

## Purpose

This package owns the module-input semantic adapter for compiler-required Basic
declarations. It is the only package that interprets canonical Basic provider
requirements as declaration identities and validates their semantic shapes.

## Glossary

**Canonical Basic ABI**:
The certified module-input catalog for Tuple, List, Void, and structural-
derivation providers. It is constructed once from a Canonical Basic ABI Identity
Catalog, imported Module Interfaces, and the current Module Interface Declaration
Surface; later consumers receive only its resolved identities and semantic
results. This package certifies interface descriptors but never constructs them.
_Avoid_: provider symbol directory, consumer name lookup, repeated shape validation, implicit Basic import

**Canonical Basic ABI Identity Catalog**:
The immutable construction state mapping fixed Basic provider requirements to
resolved declaration and variant identities from the current Module and
Reachable Interface Closure. It carries no independent shape policy and can be
certified only by the Canonical Basic ABI adapter.
_Avoid_: semantic validation result, string-keyed lookup, backend ABI

**Canonical Basic Provider Universe**:
The closed type-provider and variant-provider sets declared by the ABI Contract.
The ABI Contract alone owns enumeration and qualified-identity lookup; this
package consumes that universe when collecting and certifying identities.
_Avoid_: package-local provider arrays, numeric provider indexes, repeated provider switches

**Canonical Basic ABI Diagnostic Policy**:
The complete classification, grouping, diagnostic code, and presentation of a
Canonical Basic ABI failure. Source consumers contribute ordered provider-demand
locations; object consumers contribute the module-object path. This package
selects the representative provenance, preserves runtime certification failures
as typed causes, and produces the final structured diagnostics.
_Avoid_: resolver-owned deduplication, consumer diagnostic codes, string-flattened runtime errors
