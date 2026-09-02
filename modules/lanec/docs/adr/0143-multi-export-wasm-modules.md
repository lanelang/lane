# ADR-0143: Multi-export WebAssembly modules and instantiation startup

## Status

Accepted.

This decision supersedes the single-entry and entry-wrapper lifecycle portions
of ADR-0083, ADR-0084, ADR-0113, ADR-0135, ADR-0139, and ADR-0140. Their
historical compiler-internal rationale remains applicable where it does not
conflict with this decision.

## Context

Lane persists raw Core WebAssembly as its only executable artifact. Treating a
linked module as one preselected executable entry unnecessarily made library
and command modules different artifact kinds, made `_start` a compiler
semantic, and delayed top-level initialization until an exported function was
called. It also required an entry wrapper to own initialization, invocation,
and root cleanup even though WebAssembly instances already own module startup
and global lifetime.

Source effect admission and the physical WebAssembly function signature are
independent questions. An execution target decides which closed residual
effects it can host. The WebAssembly export ABI separately decides which Lane
parameters and result can cross the module boundary.

## Decision

`lane link` accepts one or more repeated
`--export Module.value:wasm_name` options and emits one raw WebAssembly module.
All requested values form the authoritative whole-program root set. Public Lane
values are not exported implicitly. Duplicate WebAssembly names are rejected;
`memory` is reserved for the canonical exported linear memory.
Exporting the same Lane function under multiple names reuses one generated
boundary wrapper.

The v1 export ABI supports `Unit`, `I32`, `I64`, `F32`, and `F64`. A `Unit`
parameter is erased; scalar parameters and scalar results map directly to the
corresponding Core WebAssembly value type; a `Unit` result produces no result.
Other source types are rejected at export admission. Physical Lowering checks
that the finalized callable ABI is exactly the admitted export ABI. The
verified Physical Program then retains only the exported function identity and
name; the physical callable ABI remains the single owner of its runtime shape.

`_start` is an ordinary requested WebAssembly export name. The compiler assigns
it no special semantics.

Retained top-level initializers are pure Lane expressions. When initialization
is required, the WebAssembly module defines a private `() -> ()` initializer
wrapper and records it in the standard WebAssembly start section. The engine
executes that start function exactly once while instantiating each module and
before exposing the instance. A module without retained dynamic initialization
omits the start section.

Instance globals live for the lifetime of the WebAssembly instance. The
compiler emits no export-return cleanup pass and no initialized-root-count
global. Discarding the instance discards its linear memory and therefore all
Lane-managed instance roots together. Traps and host failures discard the same
instance without a second cleanup protocol.

`lane exec --entry wasm_name program.wasm` instantiates the module and invokes
the named export. Its first command-level invocation ABI is exactly
`() -> ()`; other valid module exports remain available to external WebAssembly
hosts. `lane run FILE:ENTRY` remains a source convenience command and requires
a zero-parameter Lane function returning `Unit`. Both commands use the same raw
WebAssembly artifact and the same Wasmoon instantiation path.

The Wasmoon JIT path builds its compiled state from the already initialized
interpreter store. It must not execute the WebAssembly start section a second
time.

## Consequences

- Linked modules can serve as command modules, libraries, or both without a
  distinct artifact format.
- Whole-program planning, specialization, optimization, Runtime ANF, VM CFG,
  and tree shaking consume the complete export root set.
- Initialization is a module-instantiation invariant rather than an exported
  entry convention.
- Export ABI admission and residual-effect admission remain separate, explicit
  policies.
- External hosts may invoke scalar exports directly; Lane Command currently
  provides only the zero-argument, no-result invocation surface.
- Normal return from an export does not destroy instance globals, so multiple
  calls on one externally managed instance observe one initialized instance.
