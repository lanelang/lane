# Unified bytecode and runtime function table

LoisVM uses one image-global `FunctionId` namespace for bytecode bodies and runtime imports. A tagged function-table entry contains either bytecode metadata and instructions or a stable runtime symbol with an erased ABI descriptor. Ordinary direct, callable-value, and tail-call instructions work for both entry kinds; LoisVM has no separate runtime-call instruction or runtime-function value kind.

The image records one nonzero selected entry before the table. It must reference a no-context bytecode body with no witnesses, no user parameters, and `Unit` result; a runtime import cannot be the selected entry.

## Runtime Import ABI v1

The logical host signature is `(RuntimeContext, VMValue...) -> VMValue`. `RuntimeContext` is implicit borrowed host state. Every explicit argument follows the ordinary callee-owned convention, and every successful call returns exactly one owned value, including logical `Unit` even when no bytecode destination slot is needed.

V1 externs are synchronous, monomorphic, no-context, witness-free, and restricted to `Int`, `Double`, `Bool`, `String`, and `Unit`. A binding cannot re-enter Lane execution, invoke a Lane callback, retain a VM value after return, or cross closures, nominal data, function identifiers, or opaque host handles. Restricted nested calls may target approved non-Lane runtime services only.

Runtime-import descriptors serialize ABI major version, fixed user arity, and a nonempty case-sensitive ASCII symbol. Imports are deduplicated and deterministically ordered. Source extern types drive compiler lowering, while the Runtime Symbol Registry supplies the host implementation; an incorrect extern type or effect remains outside Lane's safety guarantee. Loading resolves every symbol once and rejects missing, version-incompatible, or arity-incompatible bindings before execution.

String values keep the canonical immutable ASCII ARC layout. An argument is transferred as an owned VM value and read through a borrowed byte view valid only during the call. A String result copies validated host bytes into a new owned VM String through the runtime context. Other allowed kinds are immediate values.

Runtime-import failure returns no Lane value and fatally aborts the current execution. The binding first consumes or releases transferred arguments; the VM then releases remaining owned frame values while unwinding. Recoverable host outcomes use normal primitive results. Interpreter, native, and Wasm tiers may use different physical failure mechanisms, but none create a Lane exception, effect, or bytecode exceptional edge.

## Backend mapping

The interpreter caches resolved host bindings in loaded-image state. The Wasm tier emits imports or adapters under the canonical runtime module namespace and uses natural scalar signatures, canonical memory, and approved runtime services for String construction. Stable symbols and erased descriptors are portable; host pointers and backend callables are not serialized.

Compiler intrinsics and portable VM semantics remain bytecode instructions. Runtime imports are reserved for extern-bound host capabilities and are unrelated to effect-operation dispatch or the future Host Effect Handler interface.

Consequences:

- One callable namespace and one call family cover bytecode and extern targets.
- Capture-free callable values use immediate `FunctionId` values rather than empty closures.
- Runtime symbols resolve at load time, never by per-call string lookup.
- The host ABI is primitive-only, synchronous, non-reentrant, and ownership-explicit.
- Runtime imports remain opaque observable calls after source effect erasure.
