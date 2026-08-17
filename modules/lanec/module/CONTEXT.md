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
The package boundary that parses Source Inputs into Parsed Sources and is the
sole producer of Module Graph topology and Module Dependency Failures.
_Avoid_: interface model, linker

**Source Input**:
The Module Frontend-owned identity and text of one in-memory source. Batch
compilation, semantic workspace analysis, Explore, native CLI, and Wasm hosts
all consume this same value without facade-specific copies.
_Avoid_: compile source input, workspace source input, field-copy adapter

**Parsed Source**:
The single result of parsing one Source Input. It owns concrete syntax,
syntactic identifiers, parse diagnostics, and exactly one available-module or
unavailable-with-recovered-header state.
_Avoid_: parallel source syntax arrays, detached recovered header, optional parsed module cache

**Module Graph**:
The Module Frontend-owned dependency result containing dependency-ordered
available modules, explicit unavailable Parsed Sources for tolerant analysis,
and the selected root. The available and unavailable module collections are
the reachable closure; no parallel path list is stored. Strict compilation
receives only a validated Module Graph directly from import-reachable parsing.
_Avoid_: module input set, caller-computed reachability, caller topological sort

**Module Dependency Failure**:
The structured Module Frontend classification and diagnostic policy for
duplicate inputs, missing imports, and import cycles. Provenance distinguishes
Source Input discovery from Interface Artifact closure analysis. A strict
Module Graph always has a root; losing it after this seam is a compiler defect,
not a dependency failure.
_Avoid_: compile-boundary dependency diagnostic, duplicated E400x rendering

**Module Compilation**:
The package boundary that owns module compilation, artifacts, fingerprints,
linking, and executable-program assembly.
_Avoid_: source input discovery, shared interface types

**Compiled Module**:
The compiler-owned product pairing Checked Source, Module Interface, and one
link-only Module Object. The Module Object contains a single Buslane Program
plus link metadata; it never retains source-analysis state or parallel
metadata/term fields.
_Avoid_: checked module object, split Buslane object, copied reachable paths

**Linked Core Retention**:
The linker policy that computes whole-program roots only after import identity
remapping and entry selection policy are known, then delegates exact top-term
reachability and retention to occurrence analysis.
_Avoid_: per-module dead-code elimination, downstream root reconstruction
