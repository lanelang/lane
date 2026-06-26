# Module interface and object separation

Lane modules are compilation units, and compiling one module produces two distinct artifacts: a **Module Interface** for downstream compilation and a **Module Object** for linking. Downstream modules consume interfaces for name resolution, type checking, public nominal shapes, transparent aliases, and visible offers; link workflows consume objects to connect imported reference placeholders and produce a linked Buslane program.

This mirrors the mature separate-compilation split between compiler-readable interfaces and link-time objects while keeping Lane independent of filesystem identity. A module path comes from source, build workflows provide module sources and imported interfaces, and object linking remains separate from typechecking.

## Consequences

- `ImportedEnvironment` contains **Module Interfaces**, not **Module Objects**.
- `ModuleInterface` records exported symbols, types, offers, public nominal shapes, and transparent public aliases, but not Buslane identities.
- `ModuleObject` may contain lowered private definitions and Buslane metadata needed for linking and execution.
- `ModuleInterface` has a pure interface fingerprint for downstream compilation; a compiled module has a module fingerprint that combines that interface fingerprint with the imported interface fingerprints used by the compilation.
- Imported Buslane reference placeholders record the imported module fingerprint, so linking can reject stale or mismatched module objects instead of relying on interface shape alone.
- A compiled module may package an interface and object together, but consumers must use the artifact appropriate to their phase.
