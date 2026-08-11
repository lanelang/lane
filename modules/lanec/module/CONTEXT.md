# Lane Module Subsystem

This context names the dependency boundaries among the compiler packages that
represent, discover, and compile Lane modules.

## Language

**Module Interface Model**:
The dependency-light package that owns the public semantic representation of a
compiled Lane module interface.
_Avoid_: source discovery, module compilation workflow

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
