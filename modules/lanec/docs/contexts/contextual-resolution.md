# Lane Contextual Resolution

This context names contextual offers, contextual parameters, operator aliases,
standard-library operation values, and builtin boundaries.

## Language

**Contextual Resolution**:
The type-directed process that supplies omitted contextual arguments from visible offers.
_Avoid_: open overload resolution, trait instance search, name resolution

**Contextual Offer**:
A named value identifier made available to Contextual Resolution.
_Avoid_: offered expression, offered field path, open binding

**Contextual Parameter**:
A function parameter marked for omission at eligible call sites and supplied by Contextual Resolution.
_Avoid_: typeclass constraint, trait bound, hidden type parameter

**Offered Parameter**:
A function parameter that is automatically offered in the function body.
_Avoid_: automatically propagated auto parameter, implicit local open

**Contextual Forwarding Field**:
A struct field that becomes an additional contextual offer when the containing struct value is offered.
_Avoid_: open field, inherited field, ordinary unqualified field exposure

**Explicit Contextual Argument**:
A named call argument that explicitly supplies a Contextual Parameter instead of using Contextual Resolution.
_Avoid_: general labelled argument, positional contextual argument

**Direct Named Function Call**:
A call whose callee is a direct value reference to a function definition symbol.
_Avoid_: function value call, field function call, parenthesized callee expression

**Call Origin Metadata**:
Source information retained across desugaring so diagnostics can refer to the user-written call or operator form.
_Avoid_: erased source name, generated-only span

**Contextual Resolution Diagnostic**:
A diagnostic produced when contextual arguments cannot be supplied or checked.
_Avoid_: generic inference failure, unresolved open candidate

**Ambiguous Contextual Offer Diagnostic**:
A diagnostic that reports multiple visible contextual offers matching one contextual parameter type.
_Avoid_: open candidate ambiguity, silent default choice

**Operation Value**:
A value whose fields provide named operations through ordinary field access.
_Avoid_: trait instance, interface implementation

**Operator Alias**:
A symbolic operator form that resolves through its corresponding ordinary operation name.
_Avoid_: primitive operator, compiler-only operator

**Recognized Operation**:
A conventional operation name, such as `op_add` or `op_equal`, that may be referenced by an operator alias.
_Avoid_: compiler-only operator method, ad-hoc operator field

**Operation Name**:
A normal value name with an `op_` prefix that may be targeted by a fixed operator alias mapping.
_Avoid_: reserved identifier, user-defined operator token

**Operation Field**:
A field inside a standard-library operation struct that stores the implementation function.
_Avoid_: operator alias target, op-prefixed field

**Standard Operation**:
A standard-library nominal operation struct whose fields use conventional operation names.
_Avoid_: compiler-only operator magic, user-defined operator trait

**Short-Circuit Boolean Operation**:
A boolean operation whose right-hand expression is delayed as a zero-argument function and evaluated only by the operation implementation.
_Avoid_: generic logical operation, ordinary strict binary function

**Thunked Operator Call**:
A Buslane call to a resolved operation where a delayed operand is represented as a zero-argument function value.
_Avoid_: direct if lowering, strict binary call

**Resolved Operator Call**:
A Buslane call produced from an operator alias after resolving the operation value.
_Avoid_: special operator node, primitive operator

**Unsafe Builtin**:
An intrinsic expression whose meaning is supplied outside Lane, whose type is taken from direct context, and whose incorrect use can produce undefined behavior.
_Avoid_: typed intrinsic, safe primitive

**Checked Builtin Request**:
A checked-source builtin expression whose intrinsic name is uninterpreted but whose expected type is explicit.
_Avoid_: intrinsic lookup during type checking, safe builtin, Buslane builtin expression

**External Builtin Value**:
A Buslane external value produced from Lane builtin syntax and supplied by a runtime plugin or linker.
_Avoid_: Buslane builtin expression, checked intrinsic call

**Required Intrinsic**:
An intrinsic name that every conforming Lane/Core v1 implementation must provide for portable programs.
_Avoid_: placeholder builtin, implementation-only primitive

## Relationships

- **Contextual Resolution** supplies omitted contextual arguments from visible **Contextual Offers**.
- A **Contextual Offer** offers a named value, not an expression or field path.
- An **Offered Value Definition** has the shape `offer name : Type = expression`.
- An **Offered Value Definition** must be named and must have an explicit type annotation.
- A local **Offered Value Definition** is visible from its declaration point to the end of the current block.
- A top-level **Offered Value Definition** contributes to the top-level contextual offer environment.
- **Contextual Offers** use lexical scope and affect only **Contextual Resolution**.
- A **Contextual Forwarding Field** is exposed only when the containing value is offered.
- **Operator Aliases** are fixed mappings to **Operation Names**.
- `&&` and `||` are **Short-Circuit Boolean Operations** and elaborate to **Thunked Operator Calls**.
- Ordinary calls to `op_and` and `op_or` are strict.
- Lane builtin syntax lowers to an **External Builtin Value** before entering Buslane.
- Builtin intrinsic strings belong to compiler, linker, or runtime side tables rather than Buslane metadata.

## Example dialogue

> **Dev:** "Can contextual resolution pick between two matching offers?"
> **Domain expert:** "No. It must report an **Ambiguous Contextual Offer Diagnostic** instead of choosing a default."
