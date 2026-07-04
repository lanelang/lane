# Lane Runtime And Execution

This context names execution targets, interpreter runtime concepts, builtin
runtime plugins, and runtime error boundaries.

## Language

**Execution Target**:
A way to execute a checked Lane program, such as an interpreter or a bytecode virtual machine.
_Avoid_: host target, MoonBit target, backend platform

**Reference Interpreter**:
The first execution target, currently evaluating ANF IR, that defines observable Lane/Core behavior.
_Avoid_: source interpreter, bytecode VM

**Interpreter Entry Selection**:
The rule that a caller chooses which checked value or function to evaluate rather than the interpreter hard-coding `main`.
_Avoid_: built-in main, source entrypoint

**Run Entry Convention**:
The Lane Command convention that `lane run` and `lane runobj` select and execute an **Executable Entry Type**.
_Avoid_: language-level main semantics, project entrypoint, arbitrary value inspection

**Run Effect Convention**:
The Lane Command convention that an executable selected entry may leave a specific outer effect set for the command to handle.
_Avoid_: language-level main effect, standard library effect, compiler-builtin effect

**Executable Entry Type**:
The function type shape accepted by `lane run` and `lane runobj` for automatic command execution.
_Avoid_: language main type, pure value entry, unchecked effectful entry

**Runtime Effect Handler**:
An execution-target handler for an operation that escapes all source-level lexical handlers to the outer runtime boundary.
_Avoid_: source effect handler, handler override, unsafe builtin plugin

**Runtime Effect Convention**:
A command/runtime rule that maps a source-level exported effect operation identity and signature to a host-provided **Runtime Effect Handler**.
_Avoid_: Buslane debug-name binding, operation-number API, official standard-library pinning

**Interpreter Value**:
A uniform runtime value used by the reference interpreter.
_Avoid_: unboxed primitive special case, source AST node

**Global Environment**:
The interpreter environment containing initialized linked top-level values.
_Avoid_: module namespace, source scope

**Call Frame**:
The interpreter environment for a single function call or local evaluation scope.
_Avoid_: global scope, closure object

**Closure Environment**:
The captured interpreter environment stored with a first-class function value.
_Avoid_: call frame, lambda-lifted parameter list

**Tail-Call Optimization**:
An execution optimization that reuses a call frame for a tail-position call.
_Avoid_: required recursion semantics, function correctness

**Builtin Runtime Plugin**:
An execution-time extension that supplies behavior for unsafe builtin intrinsic names according to the compiler core contract.
_Avoid_: compiler intrinsic table, hard-coded primitive

**Builtin Dispatch Key**:
The intrinsic name and typed expected type used to select or call a builtin runtime plugin entry.
_Avoid_: name-only builtin lookup, type-checked intrinsic

**Runtime Error Report**:
An execution-target diagnostic result that reports interpreter or plugin failure without becoming a Lane language-level exception.
_Avoid_: catchable exception, panic

**Integer Undefined Behavior**:
Undefined behavior caused by invalid `Int` arithmetic such as signed overflow or division by zero.
_Avoid_: integer trap, arbitrary precision integer

## Relationships

- The first **Execution Target** currently evaluates ANF IR.
- The **Reference Interpreter** uses **Interpreter Entry Selection** over a whole checked compiler program.
- **Run Entry Convention** is a caller policy layered on top of **Interpreter Entry Selection** and selects from the final linked top-level environment.
- `lane run` and `lane runobj` execute only an **Executable Entry Type**; arbitrary public value inspection belongs to inspect tooling rather than run tooling.
- `lane run` and `lane runobj` do not print the `Unit` result of an executed entry; user-visible output comes from runtime effect handlers.
- **Run Effect Convention** belongs to `lane run` and `lane runobj`; it is not a Lane language prelude or standard library rule.
- The v1 **Executable Entry Type** is exactly a zero-argument function returning `Unit`; validation uses only the fully expanded closed concrete effect set, which may be empty or covered by registered runtime effect conventions such as `Stdlib.Write`.
- A **Runtime Effect Handler** only handles operations that are not captured by source lexical handlers.
- A **Runtime Effect Convention** is validated against source-level exported module, effect, operation, and signature metadata before execution maps it to a Buslane operation identity.
- The initial built-in **Runtime Effect Convention** handles only `Stdlib.Write.println(String) -> Unit`.
- Runtime convention validation belongs at the execution boundary, not at compile or link time.
- Runtime failures inside the initial `Stdlib.Write.println` handler are execution failures rather than Lane language-level effects or exceptions.
- The **Reference Interpreter** separates the **Global Environment**, **Call Frame**, and **Closure Environment**.
- The **Reference Interpreter** evaluates to **Interpreter Values**.
- Lane v1 does not require **Tail-Call Optimization**.
- An **Execution Target** consumes checked compiler output rather than raw source syntax.
- Runtime type arguments are erased before execution.
- **Builtin Runtime Plugins** are selected by a **Builtin Dispatch Key**.
- A **Runtime Error Report** is not a Lane language-level exception.
- Invalid `Int` arithmetic is **Integer Undefined Behavior** in v1.

## Example dialogue

> **Dev:** "Does the interpreter decide which `main` to run?"
> **Domain expert:** "No. **Interpreter Entry Selection** belongs to the caller or later linker, not to the reference interpreter."

> **Dev:** "Can single-file `lane run` execute `main` by default?"
> **Domain expert:** "No. The **Run Entry Convention** requires `FILE:ENTRY` and debug-prints the selected value."

> **Dev:** "Can `lane run` inspect a selected public value such as `answer : Int`?"
> **Domain expert:** "No. **Run Entry Convention** executes an **Executable Entry Type**; arbitrary value inspection belongs to inspect tooling."

> **Dev:** "Can a runtime effect handler intercept operations already handled by source code?"
> **Domain expert:** "No. A **Runtime Effect Handler** only handles the outer residual operations that escape source lexical handlers."
