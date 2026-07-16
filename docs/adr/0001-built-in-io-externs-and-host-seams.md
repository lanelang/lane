---
status: accepted
---

# Built-in Io, extern bindings, and host seams

Lane separates effect semantics, compiler intrinsics, host linkage, and host effect handling. `Io` is an import-free compiler-provided name for an ordinary External Effect identity, and users may declare additional nominal External Effects with `extern type E : Effect`. After name resolution, `Io` and user-declared External Effects use the same semantic IR representation rather than a dedicated `Io` effect constructor. External Effects have no operations, are non-handleable, do not trigger monadic translation, and remain as static observability markers until residual effect erasure. `builtin("...")` selects a compiler-known intrinsic from a closed signature table, while `extern("...")` names an open host symbol and lowers to a LoisVM runtime import.

Every effect identity has an origin and a flavor. Origin is compiler-provided or declaration-owned and controls stable identity, linking, remapping, and serialization. Flavor is External or Algebraic and alone controls handleability and lowering. `Io` uses a stable compiler-builtin identity with External flavor; user External Effects use declaration-owned identities with the same flavor. A compiler-builtin identity is encoded explicitly rather than forged as a registry-local ordinary `EffectSymbolId`.

An External Effect declaration may have parameters of any supported kind. Its applications retain External flavor, participate normally in effect equality and row canonicalization, and carry no runtime effect arguments. An extern function remains monomorphic and may mention only fully applied, closed External Effect instances.

Effect aliases remain transparent rows and have no origin or flavor of their own. They may combine External Effects, Algebraic Effects, and effect parameters; handleability, monadic translation, extern eligibility, and residual erasure are determined after expansion for each concrete row member.

Optimization treats every nonempty External Effect row as observable. Calls carrying External Effects cannot be deleted, duplicated, merged, or reordered across other observable operations. An extern with an empty effect row is an unsafe assertion of purity and may be optimized as a pure function. External Effect names do not yet express read/write sets, resource identities, idempotence, or commutativity.

The extern source binding owns a Lane function type and an opaque runtime lookup key; equal key strings do not establish source-level identity or require equal External Effect rows. Execution-image loading performs runtime linking against the host registry before initialization or entry execution. The Runtime Import descriptor carries the complete supported host ABI signature, and loading rejects any host binding whose ABI major, parameter kinds, or result kind differ. External Effect rows remain compile-time semantic assertions and are erased rather than validated by the host registry.

Extern-bound and Lane-defined functions use the same latent-effect contract and the same rules at every call site, in higher-order types, aliases, branches, and effect propagation. A Lane-defined function checks that contract against its visible body; an extern-bound function has no visible body, so its declared contract is the unsafe assertion supplied at the host boundary. The compiler does not introduce extern-specific effect widening, symbol-derived effects, or a second effect-subtyping relation.

An External Effect declaration is a type-system identity, not a runtime dependency declaration. It may appear in public and higher-order APIs without any local extern binding. Only reachable `extern("...")` bindings produce Runtime Import entries; unused or forwarding-only External Effect identities require no host registration and leave no effect metadata in final bytecode.

External Effect declarations reuse ordinary type-declaration rules for nominal identity, visibility, imports, exports, qualification, generic application, duplicate detection, interfaces, and linking. The `extern` modifier changes the definition source and assigns External flavor; it does not introduce a parallel naming or module system. `Io` remains the compiler-provided identity exception.

An `extern type T : Type` declaration introduces a zero-parameter opaque nominal External Type. It has no Lane constructors, fields, representation declaration, primitive equivalence, or user-visible layout. Values of the type are created and interpreted only by host bindings and otherwise behave as ordinary opaque Lane values. Generic External Types are not supported by the initial design.

External Type flavor remains explicit through source type checking, Buslane, and whole-program linking. It is not inferred from the absence of visible constructors and is distinct from an ordinary abstract nominal type. Extern signature validation accepts only types carrying this flavor as `Opaque` host values. LoisVM lowering erases the flavor and nominal identity to the `Opaque` ABI kind; final bytecode preserves neither source identity nor External Type metadata.

Each External Type value is represented by one Lane-owned ARC wrapper referring to an opaque host object. Lane copies retain and release the wrapper without invoking host retain operations. Extern parameters borrow the resolved host object only for the duration of the synchronous call and may not retain it. Releasing the final Lane reference invokes that Host Object instance's finalizer exactly once; longer-lived host retention or ownership transfer requires a future explicit API.

The finalizer belongs to each returned Host Object instance rather than to a global External Type registry. A host result packages opaque payload state with its own finalizer, and the Host Object Table entry stores both while the Lane ARC wrapper stores only its internal handle. External Type declarations therefore require no runtime type key or module-name-derived registry entry, and different providers may safely create values of the same External Type with provider-specific destruction logic.

An `Opaque` result transfers one independently owned Host Object lifetime into a new Lane wrapper. It is never a borrowed view of an argument. A host implementation may return an object backed by the same underlying resource as an input only after acquiring an independent ownership share, such as by cloning, retaining, or using host-side shared ownership, so that the returned wrapper's finalizer remains independently valid.

All External Types erase to the single `Opaque` host ABI kind. Their nominal Lane identities remain enforced by source typing but are not serialized into Runtime Import descriptors, stored in wrappers, or compared during runtime linking. The host registry and its implementations are part of the trusted runtime boundary: loading can distinguish primitive kinds from `Opaque`, but cannot detect that a host binding uses one External Type where its Lane declaration promises another.

The host ABI accepts External Types only as direct parameters and direct results. An External Type cannot cross the boundary nested inside an array, tuple, option, result, user data type, closure, or other Lane-managed aggregate. Lane wrapper functions must construct and deconstruct such values on the Lane side around direct extern calls.

Extern ABI classification expands transparent type aliases before deciding whether a parameter or result is a supported direct value. An alias resolving directly to an External Type therefore maps to `Opaque`, while a struct, enum, or other nominal wrapper remains a Lane aggregate and is rejected at the host boundary.

The initial host ABI has no recoverable failure channel. If a host implementation cannot produce its declared result, it terminates the current execution with a fatal runtime panic. Such failure is not represented as a Lane effect or return value. Recoverable host errors and structured failure values are deferred to a future host ABI design.

An `Opaque` result is always a valid non-null Host Object with a finalizer. External Types have no hidden null inhabitant, sentinel payload, or optional-object convention. A host implementation that cannot return a valid object must panic; optional External Type values require a future explicit structured ABI.

External Type values are execution-local and thread-affine. They may be used and finalized only by the execution instance and thread on which their wrapper was created. The initial host ABI does not require Host Object payloads or finalizers to be thread-safe and provides no `Send`- or `Sync`-like capability. Cross-thread transfer is deferred until the runtime has an explicit concurrency model.

External Types have no compiler-provided equality, ordering, hashing, identity test, formatting, serialization, or pointer-observation operation. ARC wrapper identity and Host Object payload identity are not Lane semantics. Libraries that need such behavior must expose explicit extern functions with the appropriate External Effects.

External Type values have shared reference semantics. Copying a Lane value retains the same ARC wrapper rather than cloning its Host Object, so aliases observe mutations to the same underlying object. Multiple arguments of one runtime import may resolve to the same payload. The compiler and runtime provide no uniqueness, exclusive borrow, copy-on-write, or automatic host clone guarantee; observable mutation must be reflected by the callable's declared External Effects.

External Type values may be fields and constructor payloads of ordinary Lane-managed data. Those enclosing values remain internal Lane representations and cannot cross the host ABI as aggregates. For example:

```lane
struct OpenFile {
  fd : Fd
  path : String
}

enum MaybeFd {
  none()
  some(Fd)
}
```

A Host Object finalizer is synchronous, has no result, cannot produce a Lane effect, and must not fail. If it panics, execution terminates with a fatal runtime error. The wrapper is considered finalized before the callback is invoked, so the runtime never retries it or invokes it a second time. Finalizer failure does not trigger recovery or continued cleanup.

A finalizer receives only its host payload and no Runtime Context. It cannot allocate Lane values, invoke runtime imports, resolve or mutate Host Object Table entries, or re-enter Lane execution. Any host-side service needed for cleanup must be captured by the finalizer when the Host Object is created.

Finalization is guaranteed when normal ARC execution releases the last wrapper reference and when normal execution shutdown releases roots owned by the execution instance. Fatal runtime panic does not guarantee a sweep of all remaining wrappers or invocation of every outstanding finalizer. Strong cleanup guarantees for abnormal termination are deferred; host resources must tolerate execution-instance destruction or process termination as the fallback.

Finalizer timing and ordering are not observable Lane semantics. ARC insertion and optimization may move the last release without preserving a source-level destruction point, and finalization does not itself create an External Effect barrier. APIs requiring deterministic observable cleanup must expose an explicit effectful extern operation such as `close`; the finalizer remains a non-observable safety fallback for resources not explicitly closed.

Explicit cleanup does not consume or invalidate the Lane wrapper at the type-system level. A `close`-like runtime import mutates the shared Host Object into a closed state, so all aliases observe that state. Later invalid operations are detected by the host binding and cause a fatal runtime panic. The finalizer must accept an already closed payload and avoid releasing the underlying resource twice; the compiler performs no use-after-close analysis.

Each execution instance owns one Host Object Table shared by its initializer, selected entry, and all runtime imports. A host-created object occupies one table entry and is represented inside Lane-managed memory by an execution-local integer handle stored in its ARC wrapper. Runtime imports resolve borrowed `Opaque` handles through the current Runtime Context. Releasing the final wrapper reference removes the table entry and invokes its per-instance finalizer. Handles cannot be serialized, persisted, or transferred between execution instances.

An internal handle contains both a table slot index and that slot's generation. Reusing a released slot increments its generation, and every resolution validates both components. Stale, forged, out-of-range, or cross-instance handles cause a fatal runtime panic rather than resolving to a different Host Object. The generation protects table integrity but carries no External Type identity.

The physical encoding and bit allocation of a Host Object handle are backend-private implementation details. `Opaque` is an abstract Runtime Import ABI kind rather than an alias for Wasm `i32`, Wasm `i64`, or a LoisVM scalar representation. The interpreter may use a structured handle and the Wasm backend may choose one or more machine fields, provided compiler and runtime agree within that backend.

The interpreter and Wasm backends use the same Host Object Table semantics. The interpreter does not embed host-language object references directly in VM values, and Wasm linear memory never stores host object references. Backend-specific transport may differ, but `Opaque` always denotes an execution-local table handle.

`ExecutionConfig` includes a `max_host_objects` resource limit shared by both backends. Allocating an `Opaque` result consumes one live Host Object Table slot, final release returns that capacity, and exceeding the configured limit raises a fatal runtime panic. The runtime chooses the default limit; the language and artifact formats do not embed one.

The Runtime Symbol Registry may be reused across execution instances and contains only host function implementations plus their ABI descriptors. Runtime Context, Host Object Table entries, payloads, and finalizers belong to one execution instance. A registered host function cannot persist a call's Runtime Context or borrowed payload in registry-global state. Cross-execution services must be injected explicitly by the embedding and obey their own synchronization contract; they are not shared by transferring `Opaque` values.

Host Object Table handles are private runtime transport and are never exposed through the host binding API. Before invocation, the Runtime Context resolves each borrowed `Opaque` argument to a borrowed host payload. A host binding returns an owned Host Object payload and finalizer rather than a handle; the Runtime Context allocates the table entry and Lane wrapper. Host code cannot forge, persist, compare, resolve, or release handles.

The runtime-import core invokes bindings through one erased direct-value model covering `Unit`, `Bool`, `Int`, `Double`, `String`, and borrowed or owned `Opaque` payloads. The public host SDK layers typed registration adapters over that core. An adapter validates and unpacks erased arguments, presents ordinary host-language parameter types to the implementation, wraps its result, and converts host failure into fatal runtime panic. Host authors do not manually index dynamic argument arrays or switch over ABI kinds, and the adapters do not change the serialized Runtime Import ABI.

Host Object payloads carry no runtime type tag or host-private brand. A typed registration adapter uses its binding-specific trusted projection from erased `Opaque` payload to the expected host-language type. An incorrect projection is an embedding bug inside the trusted host boundary and may panic or, where the host language requires unsafe casting, violate host memory safety. Implementations should prefer memory-safe host-language erasure containers when available, but Lane, bytecode, runtime linking, and the Host Object Table add no dynamic payload typing.

String parameters are immutable byte sequences borrowed only for the synchronous call and cannot be retained by the host binding. A String result supplies host bytes that the runtime validates and copies into a newly owned Lane String; it carries no host finalizer. A binding that needs parameter bytes after return must copy them into host-owned storage. The interpreter and Wasm backends follow the same borrow-and-copy contract.

A host binding cannot return a borrowed `Opaque` argument directly. To return the same underlying resource, it must explicitly acquire a new host ownership share and return that independently releasable payload-finalizer pair. The runtime does not compare returned payloads with arguments, infer sharing, or automatically retain host resources. Objects that cannot acquire another ownership share cannot be returned by reference.

Ownership transfer of an `Opaque` result is atomic. Until the runtime has successfully allocated both its Host Object Table entry and Lane ARC wrapper, the returned payload remains pending host ownership. If slot allocation, wrapper allocation, or initialization fails, the runtime invokes the supplied finalizer for that payload and then raises a fatal runtime panic. Only a fully initialized wrapper transfers ownership to Lane; no table entry may remain live without its owning wrapper.

An extern requires a complete expected monomorphic function type, supported host parameters and result, and a closed latent effect row containing only External Effects. Pure externs and externs carrying any closed set of External Effects share the same direct runtime-import ABI. Scalar externs, inferred signatures, generic or open-row externs, algebraic-effect externs, and fallback between extern and intrinsic lookup are rejected. The extern declaration is an unsafe programmer assertion; an incorrect type or effect invalidates the program's guarantees.

`Basic.Io` exports `println : (String) -> Unit ! Io = extern("println")`. Neither `Basic.Io` nor the `println` runtime symbol receives compiler or command special treatment. A selected executable entry has zero parameters, returns `Unit`, and has a closed residual effect row containing only External Effects; it requires no root handler. Residual algebraic or open effects are rejected. Runtime-import resolution and invocation failures are fatal execution errors rather than Lane effects.

Extern calls are synchronous and receive no continuation. A future Host Effect Handler may separately receive algebraic-operation payloads and a first-class multi-shot resume continuation, but that interface is not part of runtime imports, does not implement `Io`, and does not change the current entry contract.

`mon-trans` is driven by the general monadic-effect predicate: an open row or any handled operation requires translation, and resume counts are never analyzed. Translation preserves non-monadic residual effects such as `Io`; a later residual-effect-erasure pass removes them only after effect-sensitive optimization while preserving extern calls and evaluation order.

This ADR supersedes Buslane ADR-0010, every context-local ADR-0019 and ADR-0020, and Lane Command ADR-0055. It amends the classification and runtime-boundary portions of Lanec ADR-0067 and the runtime-import terminology of Lanec ADR-0068.
