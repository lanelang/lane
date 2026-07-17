# Unified bytecode and runtime function table

LoisVM uses one image-global `FunctionId` namespace for bytecode bodies and runtime imports. A tagged function-table entry contains either bytecode metadata and instructions or a stable runtime symbol with an erased ABI descriptor. Ordinary direct, callable-value, and tail-call instructions work for both entry kinds; LoisVM has no separate runtime-call instruction or runtime-function value kind.

The image records one nonzero selected entry before the table. It must reference a no-context bytecode body with no witnesses, no user parameters, and `Unit` result; a runtime import cannot be the selected entry.

## Runtime Import ABI v1

The logical host signature is `(RuntimeContext, VMValue...) -> VMValue`. `RuntimeContext` is implicit borrowed host state. Every explicit argument follows the ordinary callee-owned convention, and every successful call returns exactly one owned value, including logical `Unit` even when no bytecode destination slot is needed.

V1 externs are synchronous, monomorphic, no-context, and witness-free. Their host ABI supports `Int`, `Double`, `Bool`, `String`, `Unit`, and one `Opaque` kind used by every External Type. A binding cannot re-enter Lane execution, invoke a Lane callback, retain a borrowed VM value after return, or cross closures, ordinary nominal data, or function identifiers. Restricted nested calls may target approved non-Lane runtime services only.

Each source External Type is a zero-parameter nominal type. Generic External Types and runtime type witnesses are outside the initial ABI.

The compiler retains External Type flavor through checking, Buslane, and whole-program linking so extern signature validation can distinguish it from ordinary abstract nominal types. LoisVM lowering erases that flavor and source identity to `Opaque`; bytecode carries only the erased Runtime Import signature.

Every ABI kind is top-level. `Opaque` and primitive values cannot be nested inside Lane arrays, tuples, options, results, user data types, closures, or other Lane-managed aggregates at the host boundary. Source libraries may expose those richer types by wrapping one or more direct extern calls.

Compiler ABI classification first expands transparent type aliases. An alias whose normalized target is a supported primitive or External Type remains a direct ABI value; nominal struct and enum wrappers do not.

Runtime imports have no recoverable error result in the initial ABI. A host binding either returns the declared direct result or raises a fatal runtime panic that terminates the current execution. Structured recoverable host failure remains deferred.

`Opaque` is non-null. Every returned `Opaque` value must contain a valid Host Object payload and finalizer; null pointers, missing payloads, and sentinel objects are invalid ABI results and cause a runtime panic.

`Opaque` values are local to one execution instance and thread. Runtime imports receive them only on that thread, and their finalizers run there. The initial ABI defines no cross-thread transfer or thread-safety requirement.

`Opaque` parameters are borrowed only for the synchronous call. An `Opaque` result transfers an independently owned Host Object lifetime to Lane and creates a new ARC wrapper. Returning a borrowed input object is invalid unless the host first acquires a separate ownership share that the result finalizer can safely release.

The runtime exposes no equality, ordering, hashing, formatting, serialization, wrapper-address, or Host Object identity operation for `Opaque`. Any such behavior must be an explicit runtime import.

`Opaque` has shared reference semantics inside Lane. Copying it retains one ARC wrapper and does not clone the Host Object. Distinct arguments may therefore resolve to the same payload, and the runtime supplies no uniqueness, exclusive-borrow, or copy-on-write guarantee.

An `Opaque` finalizer is synchronous, effect-free at the Lane level, returns no value, and must not fail. A finalizer panic is fatal. The wrapper is marked finalized before invocation, and the runtime neither retries that finalizer nor continues recovery-oriented cleanup.

A finalizer receives its payload but no Runtime Context. It cannot allocate Lane values, invoke runtime imports, access the Host Object Table, or re-enter Lane. Required host-side services must be captured in the finalizer itself.

Normal ARC release and normal execution shutdown finalize reachable runtime-owned wrappers. Fatal runtime panic provides no guarantee that every still-live `Opaque` wrapper is finalized before termination.

Finalizer timing and ordering are outside Lane's observable semantics and introduce no effect barrier for ARC insertion or optimization. Deterministic cleanup must be an explicit runtime import carrying the appropriate External Effect; finalization is only a fallback.

An explicit cleanup import mutates the shared Host Object into a closed state but does not consume its Lane wrapper. All aliases remain valid Lane values that refer to the closed payload. Host bindings detect invalid post-close operations and panic, while the finalizer treats an already closed object as safe to release without repeating cleanup. No compiler use-after-close analysis is provided.

Each execution instance owns one Host Object Table shared across initialization and entry execution. An `Opaque` Lane wrapper stores an execution-local integer handle, and runtime imports resolve that handle through the current Runtime Context. The table entry contains a private key into an embedding-owned typed `HostObjectStore[T]` plus a release closure. Final wrapper release removes the table entry, removes the typed-store value, and invokes its finalizer. Handles are neither serializable nor valid across execution instances.

Each handle combines a slot index with a generation. Slot reuse increments the generation, and resolution rejects stale, forged, out-of-range, or cross-instance handles with a fatal runtime panic. No External Type fingerprint is encoded.

`Opaque` does not standardize a machine representation or divide handle bits between index and generation. Its concrete encoding is private to each backend implementation and is not serialized as part of the bytecode Runtime Import signature.

`ExecutionConfig.max_host_objects` limits the number of simultaneously live table entries. Creating an `Opaque` result consumes one slot, final release returns it, and exhaustion is a fatal runtime panic with identical interpreter and Wasm semantics.

The Runtime Symbol Registry has a fixed capability set and is reusable across execution instances. Bindings for one host type capture the same typed `HostObjectStore[T]`; that store may contain values owned by several active executions, but every value is reachable from exactly one execution-local Host Object Table entry. Registered functions cannot retain a call's context or borrowed Lane value; embeddings inject any intentionally shared external service separately.

The interpreter and Wasm backends implement this same table-handle model. Neither VM values nor Wasm linear memory directly contain host-language object references.

Handles are private to the runtime ABI implementation. Host bindings receive typed values resolved through their captured `HostObjectStore[T]` for `Opaque` arguments and return owned typed values plus finalizers for `Opaque` results. They never receive or produce handles and cannot manipulate Host Object Table entries directly.

The runtime-import core uses one erased direct-value representation for all supported ABI kinds. The public host SDK provides typed registration adapters that unpack arguments, expose host-language parameter types, wrap results, and translate host failure into runtime panic. These adapters are an embedding convenience and safety layer rather than a second serialized ABI.

`Opaque` payloads use no dynamic `Any` value and require no unchecked cast. A typed adapter must name its `HostObjectStore[T]`; lookup through a different store is rejected by private store identity before any value is returned. Runtime-import descriptors still preserve only the coarse `Opaque` ABI kind and contain no source External Type fingerprint.

String parameters are immutable call-scoped borrows and cannot be retained by a host binding. String results provide bytes that the runtime validates and copies into a new owned Lane String, without a host finalizer. A binding must make its own copy to retain input bytes after return.

Returning an argument's underlying Host Object requires the binding to acquire an explicit independent host ownership share. The runtime neither detects payload aliasing nor automatically retains host resources. A borrowed argument cannot itself become an `Opaque` result.

Adopting an `Opaque` result is transactional. The typed value remains pending host ownership until it is inserted into its `HostObjectStore[T]`, linked from an execution-local table entry, and wrapped by Lane. Any failure during adoption invokes the supplied finalizer and then raises a fatal runtime panic; a typed-store value without an owning wrapper is forbidden.

Runtime-import descriptors serialize ABI major version, the complete supported parameter and result kind signature, and a nonempty case-sensitive ASCII lookup key. All External Type identities erase to `Opaque`; descriptors contain no source type fingerprint. Source extern types drive compiler lowering, while the Runtime Symbol Registry supplies the trusted host implementation. Loading resolves every import before execution and rejects missing bindings or any mismatch in ABI major, parameter kinds, or result kind, but cannot detect confusion between distinct External Types. The lookup key is opaque: equal strings do not establish source-level identity or require equal External Effect annotations. External Effect rows are compile-time semantic assertions and are not part of the runtime ABI contract.

String values keep the canonical immutable ASCII ARC layout. An argument is transferred as an owned VM value and read through a borrowed byte view valid only during the call. A String result copies validated host bytes into a new owned VM String through the runtime context. `Opaque` values use Lane ARC wrappers over execution-local Host Object Table handles; Bool, Int, Double, and Unit are immediate.

Runtime-import failure returns no Lane value and fatally aborts the current execution. The binding first consumes or releases transferred arguments; the VM then releases remaining owned frame values while unwinding. Recoverable host outcomes use normal primitive results. Interpreter, native, and Wasm tiers may use different physical failure mechanisms, but none create a Lane exception, effect, or bytecode exceptional edge.

## Backend mapping

The interpreter caches resolved host bindings in loaded-image state. The Wasm tier emits imports or adapters under the canonical runtime module namespace and uses natural scalar signatures, canonical memory, and approved runtime services for String construction. Stable symbols and erased descriptors are portable; host pointers and backend callables are not serialized.

Compiler intrinsics and portable VM semantics remain bytecode instructions. Runtime imports are reserved for extern-bound host capabilities and are unrelated to effect-operation dispatch or the future Host Effect Handler interface.

Consequences:

- One callable namespace and one call family cover bytecode and extern targets.
- Capture-free callable values use immediate `FunctionId` values rather than empty closures.
- Runtime symbols resolve at load time, never by per-call string lookup.
- The host ABI is direct-value-only, synchronous, non-reentrant, and ownership-explicit; it supports primitives plus `Opaque`.
- Runtime imports remain opaque observable calls after source effect erasure.
