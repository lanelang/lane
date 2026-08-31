# Canonical Basic ABI Context

## Purpose

This package owns the semantic lifecycle of compiler-required Basic
declarations across the source module-input and module-object trust boundaries.
It alone interprets provider requirements, certifies source identities and
shapes, and certifies their persisted runtime projection.

## Glossary

**Canonical Basic ABI**:
The certified module-input catalog for Tuple, List, Void, WasmAddress, and
structural-derivation providers. It is constructed once from a Canonical Basic
ABI Identity Catalog, imported Module Interfaces, and the current Module
Interface Declaration Surface; later consumers receive only its resolved
identities and semantic results. This package certifies interface descriptors
but never constructs them. `WasmAddress` is certified as the exact public
`{ storage : Bytes; offset : I32 }` carrier used at raw Wasm extern boundaries.
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

**Canonical Basic ABI Runtime Contract**:
The persisted, fingerprinted projection of checked Canonical Basic identities
into the runtime identity space. It is untrusted after decoding and cannot
authorize linking decisions until certified at the module-object boundary.
_Avoid_: certified contract, trusted artifact metadata, backend provider lookup

**Certified Canonical Basic ABI Runtime Contract**:
The non-persisted evidence that a Canonical Basic ABI Runtime Contract names
declarations whose bindings and runtime shapes satisfy the Canonical Basic ABI.
Only this evidence may authorize downstream canonical identity comparisons.
_Avoid_: decoded contract, persisted certificate, unchecked runtime identity

**Canonical Basic ABI Runtime Certification Failure**:
A structured distinction between a missing runtime declaration binding and a
declaration with an incompatible runtime shape. The Canonical Basic ABI owns its
classification and diagnostic; object consumers contribute provenance only.
_Avoid_: generic invalid-object string, linker-owned classification, flattened cause
