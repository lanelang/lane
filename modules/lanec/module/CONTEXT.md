# Lane Module Subsystem

This context names the dependency boundaries among the compiler packages that
represent, discover, and compile Lane modules.

## Language

**Module Interface Model**:
The dependency-light package that owns the public semantic representation of a
compiled Lane module interface.
_Avoid_: source discovery, module compilation workflow

**Module Interface Declaration Surface**:
The single projection of a module's checked public nominal types and effects
into Module Interface descriptors. It is formed before expression checking so
module-input semantic adapters can certify it, then reused unchanged when the
complete Module Interface adds values, aliases, references, and exports.
_Avoid_: consumer-specific type projection, reconstructed interface type, ABI-owned declaration descriptor

**Module Interface Catalog**:
The semantic-snapshot owner of available Module Interfaces and canonical
resolution of their provider-owned Declaration References.
_Avoid_: source module graph, copied interface map, linker symbol table

**Module Interface Export Namespace**:
The Type, Effect, or Value namespace in which a Public Export is visible and
its target declaration must belong.
_Avoid_: export space, artifact-only namespace, runtime symbol class

**Declaration Reference**:
The stable cross-interface identity of a provider-owned top-level declaration,
formed from its provider Module, Module Interface Export Namespace, and name.
_Avoid_: facade access path, compilation-local symbol ID, runtime address

**Declaration Fingerprint**:
The provider-owned semantic digest of one declaration descriptor used to detect
stale or incompatible Public Export targets.
_Avoid_: Module Fingerprint, facade-produced declaration identity, source hash

**Public Export**:
A Module Interface access binding that maps an exposed name and Module
Interface Export Namespace to a Declaration Reference and expected Declaration
Fingerprint.
_Avoid_: copied declaration, runtime export, forwarding definition

**Module Frontend**:
The package boundary that owns source inputs, module headers, module input sets,
and dependency-graph construction.
_Avoid_: interface model, linker

**Module Compilation**:
The package boundary that owns module compilation, artifacts, fingerprints,
linking, and executable-program assembly.
_Avoid_: source input discovery, shared interface types

**Linked Core Retention**:
The linker policy that computes whole-program roots only after import identity
remapping and entry selection policy are known, then delegates exact top-term
reachability and retention to occurrence analysis.
_Avoid_: per-module dead-code elimination, downstream root reconstruction
