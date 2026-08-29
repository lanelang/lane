# RFC: Selective module re-exports

Status: Implemented (2026-08-15)

## Summary

Lane shall support explicit selective re-exports with `pub import`:

```lane
module Basic.Prelude

pub import Basic.Data.Option.{ Option }
pub import Basic.Trait.Equal.{ Equal }
pub import Basic.Data.I64.{ i64_impl_equal }
```

Each declaration performs an ordinary selective import in the current Module and
adds the selected access names to the current Module Interface. A downstream
Module may consequently access those declarations through the re-exporting
Module:

```lane
module Example

import Basic.Prelude.{ Equal, Option, i64_impl_equal }
```

A re-export is an additional public access path to a provider-owned declaration.
It does not create or copy a declaration, change its canonical identity, transfer
ownership, or emit a forwarding implementation.

The first version supports only selective re-exports. Qualified Module Bindings,
aliases, and open imports remain local import mechanisms, so these forms are not
valid:

```lane
pub import Basic.Data.Option
pub import Basic.Data.Option as Option
pub import Basic.Data.Option.*
```

## Core invariants

The implementation must preserve these invariants:

1. The provider Module is the sole owner and producer of a declaration's
   semantic descriptor and declaration fingerprint.
2. A facade stores a stable reference to the provider-owned declaration and the
   fingerprint it was compiled against. It never stores another copy of the
   declaration descriptor.
3. Every public access path, including a provider's own public name, is represented
   by the same public export model.
4. Direct import and any number of re-export hops resolve the same declaration
   reference to one locally interned semantic identity.
5. Re-export is erased before runtime lowering. A facade emits no forwarding
   definition or runtime export for a re-exported declaration.
6. Persisted semantic artifacts contain stable declaration references, not
   compilation-local symbol IDs or machine-local source identities.

## Goals

- Let facade Modules present a deliberate public surface assembled from other
  Modules.
- Preserve the local behavior of selective imports.
- Preserve canonical declaration identity through direct and transitive
  re-exports.
- Represent re-exports in Module Interfaces without runtime forwarding
  definitions.
- Keep declaration metadata under one provider-owned semantic authority.
- Preserve offer, dependency, and linking behavior through the additional access
  path.
- Keep the first syntax small and explicit.

## Non-goals

- Exporting a Module Binding or introducing nested Module namespaces.
- Wildcard re-exports.
- Renaming selected bindings during re-export.
- Re-exporting private declarations.
- Automatically adding declarations mentioned by a selected declaration's
  signature to the facade's public surface.
- Changing the semantics of ordinary qualified, open, or selective imports.
- Persisting source URIs or compilation-local source IDs in semantic interface
  artifacts.

## Syntax

The new form is:

```lane
pub import Module.Path.{ item1, item2 }
```

`pub` applies to the complete selective import declaration. The parser records
visibility explicitly on the selective `ImportDeclaration`; visibility is not
inferred from later use.

The formatter prints `pub import` as one keyword chain and otherwise applies the
existing formatting rules for selective imports, including comments and
multiline item lists.

Using `pub` on a qualified, aliased qualified, or open import is a syntax error.
Selective item aliases are outside the first version, so each exposed name is the
authored item name.

## Source semantics

### Local import behavior

For resolution inside the declaring Module, `pub import A.{ x }` behaves exactly
like `import A.{ x }`. The selected binding is available unqualified,
participates in the same namespace, and reports the same ambiguity or collision
diagnostics as an ordinary selective import.

The public import itself is an observable use: it contributes to the Module
Interface. An unused-import diagnostic must therefore not report a successfully
resolved `pub import`, even when no expression in the declaring Module uses the
binding.

### Public export behavior

After resolving an item, the compiler adds every matching public binding to the
current public export table under that item name. As with an ordinary selective
import, one spelling may identify bindings in multiple existing Lane namespaces;
each binding then receives its own export entry.

The public export table is keyed by `(export_namespace, exposed_name)`. That key
is unique across locally owned public declarations and re-exports. Publishing
the same key twice is an error even if both entries target the same canonical
declaration. This is an explicit public-surface invariant; it must not be
inferred from incidental behavior of local name resolution.

An item that resolves to no public binding reports the ordinary unresolved import
item diagnostic. Re-export provides no route to a private declaration. Local
import collisions and public export collisions are diagnosed at the authored
`pub import` item but remain separate checks because the local and public tables
have different responsibilities.

### Canonical identity

The declaration's original provider Module and declaration reference remain
canonical. For example:

```lane
module A

pub struct T {}
```

```lane
module B

pub import A.{ T }
```

```lane
module C

pub import B.{ T }
```

`A.T`, `B.T`, and `C.T` all resolve to the declaration reference for `A.T`.
Transitive re-exports are flattened when an interface is constructed: `C` records
the original declaration in `A`, not an export entry owned by `B`.

IDs such as `TypeSymbolId` are local to a semantic snapshot and are not persisted
as canonical cross-artifact identity. When a consumer loads its Reachable
Interface Closure, the interface catalog interns each declaration reference once.
Direct and facade paths therefore receive the same local symbol and the same
subordinate identities for fields, variants, operations, type parameters,
function parameters, and other declaration-owned metadata.

### Offers

Re-exporting a value resolves the provider-owned descriptor that contains its
offer and parameter metadata. The facade does not copy that metadata and no
wrapper value is synthesized.

Downstream behavior remains unchanged. A selective or open import of a
re-exported offer activates it according to the ordinary offer rules. Qualified
access through a Module Binding does not activate an offer merely because the
value is public.

### Signature dependencies

A re-export exposes only the selected access names. Types, effects, or other
declarations referenced by the target descriptor enter the Reachable Interface
Closure as semantic dependencies, but do not become names in the facade's public
surface unless explicitly re-exported.

The authored import path remains a source and build-graph dependency of the
facade. Flattening the semantic target does not pretend that the facade source
was compiled without reading an intermediate facade.

## Canonical Module Interface model

The Module Interface separates provider-owned declarations from public access
bindings:

```text
ModuleInterface {
  types: Array[ModuleInterfaceType]
  effects: Array[ModuleInterfaceEffect]
  type_aliases: Array[ModuleInterfaceTypeAlias]
  values: Array[ModuleInterfaceValue]
  exports: Array[ModuleInterfaceExport]
}

ModuleInterfaceDeclarationRef {
  provider_module: String
  export_namespace: ModuleInterfaceExportNamespace
  declaration_name: String
}

ModuleInterfaceExport {
  export_namespace: ModuleInterfaceExportNamespace
  exposed_name: String
  target: ModuleInterfaceDeclarationRef
  expected_target_fingerprint: DeclarationFingerprint
}
```

`ModuleInterfaceExportNamespace` uses Lane's semantic namespaces; it does not
create a second namespace system for artifacts. The target kind recorded by the
provider descriptor must be compatible with the export namespace of the export
entry. `declaration_name` is the provider-owned top-level name in that export
namespace. Since only named public declarations can be re-exported, the complete
triple is unique without persisting a compilation-local symbol ID.

The provider-declaration fields contain semantic descriptors owned by that
Module. They are the only place that stores type parameters, struct fields, enum
variants, effect operations, type alias bodies, value types, offer flags,
function parameter metadata, and optimization metadata for those declarations.

`ModuleInterface.exports` stores the Public Exports visible through the current
Module. A locally declared public binding has an export that targets its own
provider declaration. A re-export has the same shape but targets another
provider Module. Public lookup therefore has one path without duplicating the
target descriptor.

The concrete representation may partition declarations by Module Interface
Export Namespace, but it must retain these ownership and lookup rules. In
particular, a re-export entry must not embed a freshened or serialized copy of
the target descriptor.

### Interface catalog seam

A `ModuleInterfaceCatalog` conceptually owns cross-interface resolution for one
semantic snapshot. It consumes the Reachable Interface Closure and provides one
operation that resolves a `ModuleInterfaceDeclarationRef` to its locally
interned descriptor and semantic identity.

Resolution, type checking, elaboration, optimization metadata lookup, lowering,
and tooling consume that operation. They must not independently freshen export
snapshots or reconstruct provider identity from the facade path. This makes the
catalog a deep Module: target validation, local identity interning, descriptor
dependency traversal, and duplicate-path convergence remain behind one
Interface.

### Declaration and interface fingerprints

The provider computes one semantic `DeclarationFingerprint` from the complete
semantic descriptor of an owned declaration, including declaration-owned
subordinate shapes. Source spans, source IDs, documentation, and other
presentation-only data do not participate. The fingerprint encoding uses stable
declaration references for dependencies and is independent of locally allocated
semantic IDs.

A public export records the target fingerprint observed when the facade was
compiled. This value is an integrity and invalidation assertion, not another
producer of declaration semantics. Catalog validation compares it with the
provider-owned fingerprint and rejects a stale or incompatible facade.

The facade's `ModuleInterfaceSemanticFingerprint` includes, for each export:

- the export namespace and exposed name;
- the complete stable `ModuleInterfaceDeclarationRef`;
- the expected target fingerprint.

Consequently, changing the selected declaration changes the facade interface
fingerprint, while changing an unrelated provider declaration does not. The
facade's compilation fingerprint still includes the full interface fingerprint
of every direct import, so rebuilding the facade itself remains conservative
when any part of a directly imported interface changes. A change in an
intermediate facade also changes a downstream facade only when it changes the
resolved target, exposed surface, or selected target fingerprint.

### Source provenance

Semantic artifacts persist the declaration reference and fingerprint, but do not
persist `SourceId`, source URI, provider source identity, or export span. Those
values belong to the live workspace presentation model.

The workspace may index the local `pub import` span by
`(facade module, export namespace, exposed name)` and the provider definition
span by `ModuleInterfaceDeclarationRef`. Diagnostics and navigation combine
those presentation facts with semantic catalog results. Artifact round trips
are required to preserve semantic identity and integrity, not machine-specific
source provenance.

## Reachable Interface Closure and artifact validation

An export target creates a semantic dependency on its provider declaration. The
Reachable Interface Closure includes the provider interface and recursively
includes every declaration dependency reachable from the resolved provider-owned
descriptor. Those dependencies do not become facade export entries.

Binary decoding establishes framing and local structural validity. Validation of
cross-interface facts belongs to the catalog after the required interfaces have
been loaded. It must reject:

- duplicate public export keys;
- a target absent from the provider's declaration table;
- a target that is private or otherwise not exportable;
- export-namespace or declaration-kind mismatch;
- target fingerprint mismatch;
- an export target that designates another export rather than a provider-owned
  declaration; and
- missing descriptor dependencies in the Reachable Interface Closure.

Valid source construction always flattens transitive re-exports. Artifact
validation must not silently repair, search for, or chase an invalid indirect
target.

## Name resolution through a facade

Qualified, open, and selective imports all read the same public export table:

```lane
module Consumer

import Basic.Prelude as Prelude
import Basic.Prelude.{ Option }

let first : Prelude.Option[I64] = Option::none
```

Resolving `Prelude.Option` or `Option` selects the facade access entry and asks the
catalog for its target. The catalog publishes the provider-owned descriptor and
canonical local symbol. Type checking, elaboration, optimization, and linking
therefore observe the original declaration identity.

For a type export, fields, variants, and type members remain subordinate to the
provider-owned type. For an effect export, operations remain subordinate to the
provider-owned effect. They are not independent facade declarations.

## Runtime and linking

Re-export is an interface-only feature. The facade Module Object contains no
forwarding value, function, global, type, constructor, effect, or operation for a
re-exported binding.

Lowering consumes a resolved binding that already carries the original
`ModuleInterfaceDeclarationRef`; it must not use the access-path Module as the
implementation provider. References compiled through a facade therefore import
the original provider symbol. The Implementation Closure includes that provider
when the target requires an implementation, and the linker validates the
reference against the original provider's Module Object.

The linker must distinguish public interface access from Module Object ownership.
It must not require every public export entry to have a same-Module runtime
export. Optimization metadata is read from the provider descriptor through the
same catalog resolution rather than copied into the facade.

Re-export adds no call indirection, allocation, initialization, or runtime
metadata. Existing initialization and dead-code-elimination rules operate on the
original provider definitions.

## Compiler changes

The implementation uses `ModuleInterfaceCatalog` as the cross-interface lookup
owner, `ModuleInterfaceExport` as the single public-access representation, and
interface artifact schema 14. `ResolvedPublicExport` retains authored source
spans only in the live semantic pipeline; those spans are not encoded in `.lmi`
artifacts.

### Syntax and formatting

- Record public visibility on selective `ImportDeclaration` nodes and retain the
  complete declaration and item spans in the live source model.
- Reject public qualified, aliased qualified, and open forms during parsing.
- Extend formatter and syntax round-trip tests for inline, multiline, and
  commented forms.

### Resolution and interface construction

- Resolve each public selective item through the ordinary selective-import
  lookup.
- Publish the selected bindings locally exactly as for an ordinary selective
  import.
- Add public export entries containing only the local access key, flattened
  `ModuleInterfaceDeclarationRef`, and expected provider fingerprint.
- Build one export-namespace-keyed public export table containing both owned
  declarations and re-exports, and diagnose duplicate keys at the authored
  source site.
- Mark successful public selective items as intrinsically used.
- Route all cross-interface target resolution and local identity interning through
  the interface catalog.

### Artifacts and invalidation

- Encode provider-owned declaration tables separately from public export tables.
- Extend interface dependency collection from flattened declaration references
  and provider descriptor dependencies.
- Validate cross-interface references and fingerprints only after the required
  closure is available.
- Change the Module Interface artifact schema version; older readers must reject
  the new representation.
- Change the semantic fingerprint domain/version so old snapshot hashes cannot be
  confused with declaration-reference-aware hashes.
- Bump only artifact formats that actually encode the changed Module Interface
  payload. A Module Object format does not change merely because its paired
  interface gained re-exports.

### Elaboration and linking

- Elaborate imported references from the catalog-resolved provider declaration.
- Carry the original provider through lowering; never recover it from the facade
  access path.
- Do not add re-exported bindings to the facade Module Object or Buslane export
  table.
- Validate implementation references against the original provider Module.
- Read optimization hints from the provider descriptor.

### Tooling

- Completion on a facade includes its re-exported access names.
- Go-to-definition on a re-exported use navigates to the original provider
  declaration. The `pub import` item itself remains a navigable local source site.
- Hover may show both the canonical provider and the facade access path.
- Find-references groups semantic references by catalog-interned declaration
  identity, so direct and facade paths form one result set.
- Rename of a facade-only access name is not introduced until selective import
  aliases exist.
- Diagnostics for an invalid facade surface point at the local `pub import` item;
  diagnostics about a loaded target use the provider presentation index when it
  is available.

## Compatibility with existing architecture decisions

ADR-0126 formerly relied on the statement that a Module could not re-export an
imported type. This implementation supersedes that premise and updates ADR-0126
to follow flattened public export targets instead.

The Reachable Interface Closure decision remains valid after that update. Its
content rule changes from relying only on surface descriptors owned by the current
Module to following flattened export targets into provider-owned descriptors.

This RFC changes the Module Interface artifact and its semantic fingerprint
domain. It does not, by itself, require a Module Object or linked-program schema
change because no runtime payload is added. If either format embeds the changed
Module Interface payload, its owning codec must version that payload as part of
the same implementation change.

## Examples

### Facade Module

```lane
module Basic.Prelude

pub import Basic.Data.Bool.{ Bool }
pub import Basic.Data.Option.{ Option }
pub import Basic.Trait.Equal.{ Equal }
pub import Basic.Data.I64.{ i64_impl_equal }

pub fn identity[T](value : T) -> T {
  value
}
```

The resulting interface has access entries for `Bool`, `Option`, `Equal`,
`i64_impl_equal`, and `identity`. The first four target declarations in their
original providers; `identity` targets an owned declaration in `Basic.Prelude`.
Only `identity` appears as an implementation export of `Basic.Prelude`.

### Transitive facade

```lane
module Application.Prelude

pub import Basic.Prelude.{ Equal, Option, identity }
```

`Application.Prelude.Equal` and `Application.Prelude.Option` target their original
Basic providers. `Application.Prelude.identity` targets the declaration owned by
`Basic.Prelude`. No declaration is re-owned by `Application.Prelude`.

### Dependency without surface leakage

```lane
module Api

pub import Model.{ parse }
```

If `parse` has type `(String) -> Result[Model, ParseError]`, the interfaces that
define `Result`, `Model`, and `ParseError` are semantic dependencies of `Api`.
Those names are not accessible as `Api.Result`, `Api.Model`, or `Api.ParseError`
unless `Api` explicitly re-exports them.

## Acceptance criteria

- `pub import A.{ x }` imports `x` locally and exposes it through the current
  Module Interface.
- Downstream qualified, selective, and open imports can access re-exported types,
  effects, type aliases, values, and offers.
- Direct and transitive paths resolve to the original provider and the same local
  semantic identity, including subordinate field, variant, operation, and
  parameter identities.
- Direct import and facade import of the same declaration in one consumer
  converge to one catalog entry rather than separately freshened descriptors.
- Re-exported offers preserve provider-owned offer and parameter behavior under
  ordinary downstream activation rules.
- Duplicate, unresolved, private, and export-namespace-incompatible items produce
  deterministic diagnostics at the re-export site.
- Signature dependencies enter the Reachable Interface Closure without becoming
  facade access names.
- Separate compilation and interface artifact round trips preserve the flattened
  declaration reference and expected target fingerprint without persisting local
  source identity.
- Catalog validation rejects missing targets, indirect export targets, kind
  mismatches, stale fingerprints, duplicate export keys, and incomplete
  descriptor closures.
- Changing a selected target descriptor changes the facade semantic fingerprint;
  changing an unrelated provider declaration does not.
- The facade Module Object contains exactly its owned implementation exports and
  no forwarding export for a re-exported binding. A consumer reference names the
  original provider.
- Completion, hover, go-to-definition, and find-references preserve the
  distinction between facade access provenance and canonical declaration
  identity.
- The revised Module Interface schema rejects artifacts encoded with the previous
  schema at a deterministic version boundary.
- Generated code contains no re-export forwarding call, allocation,
  initialization, or runtime metadata.
