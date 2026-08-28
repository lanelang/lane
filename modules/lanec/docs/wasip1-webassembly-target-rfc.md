# WASI Preview 1 WebAssembly Target RFC

## Status

Implemented and release-qualified on 2026-08-28 against Basic revision
`807f78b4bd31` and the Wasmoon dependency family at `0.12.6`. Native compiler
tests, the complete example corpus, Basic under both Wasmoon interpreter and
JIT modes, the complete Lane WebAssembly Profile probes, and the raw WASI
command-module contract pass at this baseline.

## Summary

Lane will produce a standard WebAssembly core module as its sole executable
artifact. Wasmoon is the sole supported execution engine. Its interpreter and
JIT must execute the same module with the same Lane-observable behavior.

The operating-system host seam is WASI Preview 1. Lane will not persist a
semantic runtime-import manifest, define a `lane.abi` custom section, or retain
the current `lane.runtime.v1` registry as a second host ABI. The imports and
exports of the WebAssembly module are the executable contract.

This decision does not make Wasmoon-private instructions or semantics part of
Lane. A Lane artifact remains a standards-valid WebAssembly module using only
the feature profile defined below.

## Motivation

The previous executable artifact contained WebAssembly bytes plus a Lane-specific
runtime-import manifest. Loading then reconstructs a semantic host ABI through
the Runtime Registry, Runtime Value Kinds, Runtime Context, runtime services,
and an Opaque Host Object Table. That design was useful while Lane supported an
independent bytecode interpreter and rich host values crossed a generic runtime
boundary. It is unnecessary once WebAssembly is the only execution target and
the platform ABI is fixed.

Keeping both the WebAssembly import section and a semantic manifest gives the
same linkage fact two producers. It also makes ordinary tooling unable to
execute a Lane artifact without understanding the outer Lane container. The
target architecture instead makes the WebAssembly module itself authoritative:

```text
Lane source
  -> target-independent semantic IR
  -> Wasm Physical Program
  -> standard WASI Preview 1 core module
  -> Wasmoon interpreter or Wasmoon JIT
```

## Lane WebAssembly Profile v1

The v1 profile uses the WebAssembly 1.0 core model with one non-shared `wasm32`
linear memory and the following standardized extensions:

- Bulk Memory Operations;
- Reference Types;
- Typed Function References;
- Tail Call;
- Exception Handling;
- Multi-value;
- Fixed-width SIMD; and
- Extended Constant Expressions.

The compiler may rely on every listed feature. Wasmoon support is therefore a
release requirement for both interpreter and JIT modes, not an optional fast
path. Both modes validate and execute exactly the same bytes.

The v1 profile excludes Threads and Atomics, Multiple Memories, Memory64,
WebAssembly GC, Stack Switching, Relaxed SIMD, the Component Model, WASI
Preview 2, and Wasmoon-specific opcodes, types, or validation rules. Adding or
removing a required feature changes the named Lane WebAssembly profile and
requires an explicit compatibility decision.

Wasmtime is not a supported runtime and is not part of Lane's compatibility
gate. A Lane module may happen to run on another conforming engine with a
compatible WASI Preview 1 host, but releases make no such promise and carry no
engine-specific adapter for it.

## Executable module contract

A linked executable is a raw WebAssembly module rather than a Lane container
around WebAssembly bytes.

The module follows the WASI Preview 1 command convention:

- it exports `_start : () -> ()` as its sole program entry;
- it exports canonical linear memory as `memory` when required by WASI host
  calls;
- it imports standardized system operations from `wasi_snapshot_preview1`;
  and
- it contains no `lane.entry`, `lane.memory`, or `lane.runtime.v1` public ABI.

Compiler-private helpers, tables, globals, exception tags, and runtime
functions are implementation details. They are emitted only when reachable
and are not an embedding interface merely because WebAssembly assigns them an
index or a name.

`_start` initializes the Lane instance, invokes the linked entry selected by
the Lane command, releases normal execution roots, and returns normally. A
source panic or an unrecoverable runtime failure follows the compiler-owned
fatal-control path and terminates execution rather than becoming a recoverable
WASI result.

## Host ABI

### WASI imports

WASI Preview 1 owns the module name, field name, and physical core-Wasm type of
every system import. The compiler maintains one checked WASI catalog derived
from that standard. Planning, emission, and validation consume the catalog;
they do not independently restate individual signatures.

Basic facilities such as console output are ordinary Lane functions built on
the narrow WASI primitives they need. For example, `println` is implemented
above `wasi_snapshot_preview1.fd_write`; it is not a host import taking a Lane
`String` and is not registered in a Lane runtime registry.

WASI Preview 1 operates on guest memory. The compiler and Basic therefore need
one deliberately narrow guest-memory interface that can expose a borrowed
byte range and temporary WASI records such as `ciovec` and `nwritten`. This
interface owns the mapping between Lane's memory representation and WASI's
pointer-length ABI. It must not expose general unchecked pointer arithmetic as
ordinary source-language functionality.

### Source `extern`

The future source form is:

```lane
extern("module", "value")
```

The pair names a core WebAssembly import directly. It does not name a semantic
registry entry. Its declared Lane type must lower mechanically to the import's
core-Wasm function type.

The initial raw-extern value universe is intentionally small: `Unit`, `I32`,
`I64`, `F32`, `F64`, and, when required by the accepted profile, `V128`.
Strings, Bytes, nominal data, generic values, closures, layout witnesses, and
host-language objects do not cross this seam implicitly. A library must expose
an explicit scalar or guest-memory protocol for richer values.

WASI declarations use the same syntax but are certified against the canonical
WASI catalog rather than trusted as arbitrary user declarations. A mismatched
module, field, or function type is a compile-time error.

### Host resources

The current Opaque Runtime Value Kind and generic Host Object Table do not
survive this migration. Preview 1 resources are represented by their explicit
integer descriptors or handles, with explicit operations and explicit close
semantics. Lane does not smuggle host-language references through private
generational handles.

If a future platform needs typed resources, it requires a separate design. The
likely standards seam is a future Component Model resource contract, not a
revival of the generic Preview 1-era Opaque registry.

## Memory and ownership

The generated module continues to own one non-shared `wasm32` linear memory,
its allocator, Lane object layouts, and compiler-directed ARC. WASI may borrow
validated regions during synchronous calls but does not own Lane allocation or
object lifetime.

Lane references never cross the host seam as raw long-lived pointers. A WASI
call may observe only the exact borrowed byte or record ranges prepared for
that call. Memory growth, object movement policy, ARC, and destruction remain
compiler/runtime implementation facts behind the Wasm Physical Program seam.

## Panic and process termination

Source `panic` remains distinct from recoverable exceptions and from ordinary
I/O. It is compiler-owned terminal control. The Wasm backend may use private
Exception Handling constructs to run ARC cleanup before termination, but those
tags are not a public effect handler interface.

Diagnostic output for a panic may use `wasi_snapshot_preview1.fd_write` when a
WASI environment is available. The terminal outcome does not depend on that
write succeeding. Process termination may use the appropriate Preview 1
facility or a standards-defined trap after cleanup; the execution adapter owns
the mapping to the Lane command's process status.

## Artifact and build consequences

The final executable artifact is the raw `.wasm` file. The existing linked
container schema is removed from executable persistence rather than revised to
carry a second copy of import facts. Module interfaces and relocatable compiler
objects remain target-independent and are unaffected unless they currently
persist execution-only runtime-import metadata.

WebAssembly validation is mandatory before execution. Wasmoon interpreter and
JIT conformance tests are mandatory for every required profile feature and for
the complete generated-module contract. There is no bytecode fallback, host
registry fallback, alternate runtime adapter, or silent feature downgrade.

## Ownership of facts

The target architecture has the following single owners:

- the Lane WebAssembly Profile owns the permitted and required Wasm features;
- the WASI catalog owns standardized import identities and function types;
- raw `extern` type lowering owns the mechanically representable core-Wasm
  import shape;
- the Wasm Physical Program owns target-specific calling, memory, ownership,
  and control-flow facts before emission;
- the WebAssembly emitter owns module indices and emits each reachable helper
  exactly once;
- the WebAssembly validator owns structural module validity; and
- the Lane Command owns execution policy and maps Wasmoon outcomes to process
  status.

Wasmoon is an adapter at the execution-engine seam, with two implementations:
interpreter and JIT. No additional engine seam is introduced until a second
runtime is actually supported.

## Migration plan

The migration is intentionally ordered so each step replaces an owner instead
of layering another adapter over the current runtime.

1. **Freeze the target contract.** Add the feature-profile and WASI catalog
   owners, plus black-box feature probes executed through both Wasmoon modes.
2. **Make the Physical Program Wasm-specific.** Replace remaining generic VM
   terminology and runtime-import shapes with explicit Wasm call, memory, and
   import contracts. Preserve its verifier as the last compiler trust seam.
3. **Introduce the WASI module entry.** Emit `_start`, `memory`, and canonical
   Preview 1 imports. Move Basic output onto the narrow guest-memory/WASI seam.
4. **Introduce direct core-Wasm externs.** Change source and interface syntax
   to `extern("module", "value")`, restrict its value universe, and certify
   WASI imports through the canonical catalog.
5. **Delete the semantic host runtime.** Remove the runtime manifest, Runtime
   Registry, Runtime Value Kinds, runtime services, Opaque Host Object Table,
   and `lane.runtime.v1`. Keep the standard `_start` and `memory` exports.
6. **Delete the linked executable container.** Make link output and `exec`
   consume raw WebAssembly bytes, then advance or retire any artifact schemas
   whose only purpose was wrapping executable Wasm.
7. **Update Basic and documentation.** Publish the matching Basic revision,
   update current ADRs and owning glossaries, and remove historical claims from
   active documentation. Historical ADR text remains historical and receives
   explicit supersession notes.

Each step must leave one executable path. Transitional dual ownership is not an
accepted steady state and must not be retained as fallback code.

## Acceptance criteria

- A linked Lane executable is a standards-valid raw WebAssembly core module.
- The same bytes execute successfully under Wasmoon interpreter and JIT modes.
- Required feature probes cover every Lane WebAssembly Profile v1 extension in
  both modes.
- The module uses `_start`, `memory`, and only required
  `wasi_snapshot_preview1` imports for its system interface.
- Basic console output works through WASI Preview 1 rather than a semantic Lane
  host import.
- Raw extern signatures are restricted to the declared core-Wasm value
  universe and are validated before emission.
- Rich Lane values never cross the host seam through inferred layouts or a
  private Opaque handle convention.
- No executable artifact manifest, Runtime Registry, Runtime Value Kind,
  runtime service, or Host Object Table remains.
- No code path emits or accepts `lane.entry`, `lane.memory`, or
  `lane.runtime.v1` as the public module ABI.
- Only helpers reachable from `_start`, retained imports, and required runtime
  support are emitted.
- Wasmtime is absent from required tests and compatibility claims.

## Documents superseded on completion

When the migration is complete, this RFC supersedes the executable-artifact and
host-ABI portions of ADR-0069, ADR-0075, ADR-0079, ADR-0082, ADR-0083,
ADR-0112, ADR-0139, and the root built-in/extern host-seam ADR. Their
target-independent language and representation decisions remain in force where
they do not depend on the deleted semantic runtime.
