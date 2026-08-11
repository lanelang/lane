# Lane Workspace

This context owns vocabulary shared by Lane source, compilation artifacts, and
tooling. Compiler-internal and runtime terms are routed through
`CONTEXT-MAP.md`.

## Language

### Source And Modules

**Module**:
A Lane source-language namespace that owns declarations and forms a visibility
boundary.
_Avoid_: source file, MoonBit package, implicit prelude

**Module Path**:
The dotted semantic name of a Module, independent of its filesystem location.
_Avoid_: source filename, directory path, module hierarchy

**Module Binding**:
A source-local qualifier that refers to exactly one imported Module.
_Avoid_: exported declaration, filesystem alias

**Source File**:
A non-interactive Lane source containing exactly one explicitly declared Module.
_Avoid_: compilation unit, project, concatenated source

**Source Identity**:
The stable identity attached to source locations and diagnostics.
_Avoid_: module path, anonymous offset range

**Synthetic Module**:
A driver-supplied module identity for interactive or test source that is not an
ordinary Source File.
_Avoid_: implicit filename module, compatibility fallback

**Compilation Unit**:
One Module compiled against an Imported Environment.
_Avoid_: module graph, linked program

**Library Input**:
An explicitly supplied source or artifact made available to a build workflow.
_Avoid_: implicit prelude, textual include

### Module Artifacts

**Imported Environment**:
The externally supplied Module Interfaces available while compiling one
Compilation Unit.
_Avoid_: source concatenation, linker symbol table

**Direct Import Environment**:
The imported modules whose declarations and offers are directly nameable by one
Compilation Unit.
_Avoid_: transitive interface closure, implementation closure

**Reachable Interface Closure**:
The Module Interfaces transitively referenced by the Direct Import Environment
and required to resolve their public content.
_Avoid_: source import graph, linked implementation set

**Implementation Closure**:
The Compiled Modules transitively required to link a program's referenced
implementations.
_Avoid_: reachable interface closure, exported API surface

**Module Interface**:
The compiler-readable public semantic surface of one Module, including exported
declarations and downstream optimization metadata.
_Avoid_: checked source body, private definitions

**Module Object**:
The linkable semantic implementation artifact of one compiled Module.
_Avoid_: public interface, execution image

**Compiled Module**:
The matching Module Interface and Module Object produced by one compilation.
_Avoid_: interface alone, linked program

**Module Fingerprint**:
The semantic identity of a Compiled Module and the imported interfaces against
which it was compiled.
_Avoid_: filesystem timestamp, module path

**Exported Symbol**:
The stable source-level identity of a declaration exposed by a Module Interface.
_Avoid_: Buslane identity, runtime address

**Imported Reference Placeholder**:
A core-level reference to an Exported Symbol awaiting link-time connection to
its defining Module Object.
_Avoid_: runtime import, source name lookup

**Linked Program**:
A closed set of compiled implementations whose imported references are resolved
and whose executable entry is selected.
_Avoid_: source module graph, runtime entry selection

**Execution Image**:
A target-specific executable representation derived from a Linked Program.
_Avoid_: module interface, canonical semantic core

**Binary Artifact Container**:
The versioned envelope used by Lane interface, object, and linked-program files.
_Avoid_: debug text, domain payload schema

**Binary Artifact Payload**:
The domain-owned structured record inside a Binary Artifact Container.
_Avoid_: container framing, pretty-printed artifact

### Workflows

**Build Workflow**:
A user-owned composition of compilation, linking, optimization, and entry
selection.
_Avoid_: language semantics, compiler-owned project policy

**Entry Selection**:
The workflow decision that chooses one exported executable value before linked
artifact production.
_Avoid_: implicit `main`, runtime symbol selection

**Executable Entry**:
A selected exported zero-argument function returning `Unit` with a runtime-
supported closed residual effect.
_Avoid_: arbitrary public value, parameterized entry

### Language Surface

**Numeric Literal**:
A numeric source spelling whose optional `i32`, `i64`, `f32`, or `f64` suffix
selects its primitive type without expected-type-directed elaboration.
_Avoid_: overloaded numeral, implicit numeric conversion

**UTF-8 String**:
A Lane `String` containing Unicode scalar values encoded as valid UTF-8.
_Avoid_: arbitrary bytes, UTF-16 sequence

**Scalar Index**:
A position between Unicode scalar values in a UTF-8 String.
_Avoid_: UTF-8 byte offset, grapheme index

**Effect Set**:
A canonical set of effect terms with at most one residual row variable.
_Avoid_: ordered operation list, runtime capability vector

**Algebraic Effect**:
A declared family of operations that can be discharged by a deep Lane effect
handler.
_Avoid_: host import, fatal panic

**External Effect**:
A declared non-handleable effect that tracks observable synchronous host
interaction through an extern binding.
_Avoid_: algebraic operation, runtime plugin

**Built-in Effect**:
A compiler-owned non-handleable effect identity, such as `Io` or `Panic`, that
requires no source declaration.
_Avoid_: Basic library declaration, implicit untracked behavior

**Compiler Intrinsic**:
A closed compiler-known operation named by `builtin(...)`, with a compiler-owned
signature and lowering.
_Avoid_: extern binding, host symbol

**Extern Binding**:
A source declaration whose implementation is resolved by the execution host and
whose declared type is an unsafe host-contract assertion.
_Avoid_: compiler intrinsic, algebraic effect operation

**Effect Handler**:
A source construct that supplies operation alternatives and a final branch for
one or more Algebraic Effects.
_Avoid_: exception catcher, host callback table

**Resume Continuation**:
The reusable continuation exposed to an effect-operation alternative under deep
handler semantics.
_Avoid_: captured native stack, one-shot callback
