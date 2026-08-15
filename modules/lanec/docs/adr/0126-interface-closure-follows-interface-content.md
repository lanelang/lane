# Interface closure follows interface content

Compiling a module requires the interfaces its imports' public surfaces actually reference, not every module those imports were themselves compiled against. A **Module Interface** records references only for the owners of symbols its own content mentions, and `reachable_interface_artifacts` recurses along that set. A module used only inside another module's implementation is therefore absent from a consumer's required inputs.

Linking is unchanged and still requires the full **Implementation Closure**: an object whose code calls another module's code needs that module present regardless of what the interfaces say.

The two closures being different is the point. Before this decision the compile-time requirement followed the source import graph, so a caller of `Y` had to supply `Z` merely because `Y` imported it, even when `Y`'s surface never mentioned `Z`. That leaked `Y`'s implementation detail into every downstream build command and gave interface artifacts no encapsulating power.

The set of modules a surface depends on is computable from the surface itself.
Owned declaration descriptors contribute their stable type and effect owner
references. A selective public import contributes a flattened
`ModuleInterfaceExport` target whose provider is the original declaration owner,
not the intermediate facade. The closure follows both facts and then follows the
provider descriptor's dependencies. It does not follow an implementation-only
source import.

## Considered Options

An interface-artifact search directory on the CLI (`--interface-dir`, GHC's `-i`) was rejected: it makes the burden cheaper to carry rather than removing it, and build policy belongs to user-authored **Build Workflows** under the **NoBuild Model**, not to compiler flags. Deriving artifact locations from module paths, as GHC does with `Data/List.hi`, was rejected because filesystem paths do not define **Module Paths** in Lane. Deferring entirely to a future Lane-authored build system was rejected as the sole answer, since narrowing the requirement makes that system's job smaller and is independent of it.

## Consequences

- Inputs that compile today still compile: supplying more interfaces than required remains accepted, so the change only relaxes obligations.
- Staleness detection is unchanged in strength. Every interface still required is validated against the **Imported Interface Fingerprint** its importer recorded; interfaces no longer required are validated when the **Implementation Closure** is linked, which reports `E4103` and `E4205`.
- `lane compile` can now succeed on an input set that `lane link` rejects as incomplete. That asymmetry is intended and is why the two closures are named separately.
- `optimization_hints` are covered by the content rule even though they carry no symbols yet, so a hint that later embeds a body cannot silently escape the closure.
- Interface reference tables shrank, so interface fingerprints changed and existing artifacts must be regenerated.
- Selective module re-exports preserve this decision: they add the original
  provider to the Reachable Interface Closure without copying its descriptor or
  turning unrelated imports of the facade into interface dependencies.
- Interface artifact schema 14 persists the public export table and rejects
  schema 13 at the decoder boundary.
