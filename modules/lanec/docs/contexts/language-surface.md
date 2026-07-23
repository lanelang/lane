# Lane Language Surface

This context names the source-level syntax and declaration concepts visible to
Lane programmers before semantic lowering.

## Language

**Top-Level Definition**:
A named definition that may introduce a type, function, or immutable value at the outermost program scope.
_Avoid_: statement, entrypoint, main function

**Immutable Value Definition**:
A binding that gives a name to a value without permitting reassignment.
_Avoid_: variable, mutable binding

**Offered Value Definition**:
A value definition that defines a named value and immediately adds it to the contextual offer environment.
_Avoid_: anonymous offer, open binding, standalone offer form, implicit library entry

**Offered Function Definition**:
A top-level or local named function definition that makes the function value itself available to contextual resolution under the same identity.
_Avoid_: anonymous function offer, generated offer binding, function plus hidden value

**Recursive Definition Group**:
A set of top-level functions or types that may refer to one another regardless of textual order.
_Avoid_: forward declarations, hoisted statements

**Ordered Top-Level Value Scope**:
The rule that top-level immutable values may refer only to earlier available values.
_Avoid_: recursive top-level values, forward top-level value reference

**Strict Evaluation**:
The rule that an expression is evaluated when it is reached, and function arguments are evaluated before the function body runs.
_Avoid_: eager mode, non-lazy evaluation

**Keyword-Delimited Top Level**:
Top-level definitions are separated by their defining keywords rather than semicolons or MoonBit block separators.
_Avoid_: `///|` separator, semicolon-delimited top level

**MoonBit-Like Syntax**:
Lane surface syntax that follows MoonBit's expression-oriented style while excluding mutable bindings and assignment.
_Avoid_: custom syntax from scratch, MoonBit compatibility

**Type Annotation Spacing**:
The rule that a colon between a value or field name and a type is written with whitespace on both sides.
_Avoid_: compact type annotation, struct-literal field assignment

**Explicit Named Function Signature**:
A named function boundary that states every parameter type and the result type.
_Avoid_: inferred named function signature

**Generic Named Function**:
A named function whose explicit type parameter list follows `fn` and precedes the function name.
_Avoid_: name-attached type parameters

**Block Function Body**:
A function body written as a block expression rather than with an equals-sign expression body.
_Avoid_: equals body, expression-bodied function

**Arrow Return Type**:
A function result type written with `->` after the parameter list.
_Avoid_: colon return type

**Block Expression**:
A scoped expression containing local value or function bindings followed by a final value expression.
_Avoid_: statement block, local type scope

**Conditional Expression**:
An `if` expression whose condition has type `Bool`, with either a same-typed `else` branch or the **Else-Omitting Conditional Expression** form.
_Avoid_: statement if, conditional statement

**Else-Omitting Conditional Expression**:
A conditional expression without an authored `else`. Its then branch and whole expression have type `Unit`, and the omitted path denotes `()`. It may appear in any `Unit` context, and source formatting preserves the omission without collapsing an explicit `else { () }`.
_Avoid_: statement if, optional-else statement, implicit result discard

**Sequential Local Binding**:
A local binding that is visible only to later items in the same block.
_Avoid_: let-in expression, simultaneous local binding

**Sequential Local Function**:
A named local function that may call itself, is visible only to later items in the same block, and is not part of a forward-referenced group.
_Avoid_: local recursive group, local forward declaration

**Sequential Unit Expression**:
A block-local expression followed by an explicit or **Layout Semicolon**, required to have type `Unit`, and evaluated before the following local item or final expression.
_Avoid_: statement, unchecked result discard, general sequence operator

**Layout Semicolon**:
A zero-width separator inserted between newline-delimited items before parsing when the previous token can end an item, the next token can start one, and the innermost open delimiter is a brace or there is no open delimiter. Newlines before operators, closing delimiters, continuation punctuation, `else`, `with`, or `final` do not insert a separator.
The parser represents it separately from a source `;`: only item contexts may accept both, while top-level boundaries and comma-delimited lists never treat an explicit semicolon as layout.
Each item boundary consumes exactly one source or layout semicolon; repeated separators are invalid.
_Avoid_: parser recovery, newline AST node, unconditional line terminator

**Uncurried Function**:
A function that accepts its parameters as one call shape and is not automatically transformed into nested one-argument functions.
_Avoid_: curried function, automatic partial application

**First-Class Function Value**:
A function that can be stored, passed, returned, and called as a value.
_Avoid_: top-level-only function, method

**Struct Type**:
A nominal type defined by a fixed set of named fields.
_Avoid_: record type, anonymous record

**Enum Type**:
A nominal type defined by a closed set of named variants.
_Avoid_: sum type, tagged union

**Qualified Struct Literal**:
A struct value constructed with its struct type name followed by `::{ ... }`.
_Avoid_: anonymous record literal, unqualified struct literal

**Struct Field Punning**:
A struct literal shorthand where a field name alone means `field: field`.
_Avoid_: spread update, default field

**Struct Pattern Punning**:
A struct pattern shorthand where a field name alone binds that field to a variable with the same name.
_Avoid_: rest pattern, spread pattern

**Field Access**:
Reading a named field from a struct value with dot syntax.
_Avoid_: field update, copy update

**Selector Lowering**:
The compiler lowering that turns source field access into a generated Buslane function call.
_Avoid_: source-visible selector, Buslane field primitive

**Qualified Variant**:
An enum variant referred to through its enum type name using `Type::variant`.
_Avoid_: globally unique variant, dotted variant

**Unqualified Variant**:
An enum variant referred to by its variant name alone when that name resolves without ambiguity.
_Avoid_: mandatory qualified variant, inferred later variant

**Payloadless Variant Value**:
An enum variant without payload that is used as a value without call parentheses.
_Avoid_: zero-argument variant call

**Pipeline Expression**:
An expression `value |> call` that rewrites by passing `value` as the first argument to the call.
_Avoid_: core pipeline node, method call, placeholder pipeline

**Trailing Comma**:
An optional final comma in a comma-separated syntax list.
_Avoid_: comma-sensitive list ending

**Tuple Syntax**:
Parenthesized comma syntax for values and types that denotes the nominal `Tuple`
exported by `Basic.Data.Tuple`; the grammar recognizes the syntax independently
of whether that provider module is imported.
_Avoid_: structural product type, primitive tuple, opened Basic namespace

**Right-Nested Tuple Chain**:
The semantic expansion of tuple syntax with at least two elements into nested
applications and constructions of `Basic.Data.Tuple.Tuple`, associating to the
right.
_Avoid_: flat n-tuple, arity-specific tuple type, singleton tuple

**Sugar Provider ABI**:
The fixed fully qualified declarations targeted by built-in surface expansion:
`Basic.Data.Tuple.Tuple`, `Basic.Data.Tuple.Tuple::tuple`,
`Basic.Data.List.List`, `Basic.Data.List.List::empty`, and
`Basic.Data.List.List::cons`.
_Avoid_: configurable sugar provider, shape-based enum discovery, unqualified lookup

**Tuple Pattern**:
Parenthesized comma pattern syntax that destructures a Right-Nested Tuple Chain
without introducing numeric tuple projection.
_Avoid_: tuple index access, flat positional record, numeric field

**Primitive Inhabitant**:
A value belonging to a primitive type, such as an integer literal, boolean literal, string literal, or `()`.
_Avoid_: enum variant, nominal constructor

## Relationships

- A Lane source file contains **Top-Level Definitions**, not an executable entrypoint.
- Top-level functions and types may form a **Recursive Definition Group**.
- Top-level immutable values follow **Ordered Top-Level Value Scope**.
- A top-level **Immutable Value Definition** must include an explicit type annotation.
- An **Offered Function Definition** offers its own function value and does not introduce a second value binding.
- A local **Offered Function Definition** follows the sequential scope of a **Sequential Local Function**.
- An **Offered Function Definition** makes its function value available to contextual resolution inside its own recursively scoped body.
- Top-level **Offered Function Definitions** participate in the **Recursive Definition Group** and are available as offers to every top-level function body regardless of textual order.
- A function uses an **Explicit Named Function Signature**, **Arrow Return Type**, and **Block Function Body**.
- A **Block Expression** may contain **Sequential Local Bindings**, **Sequential Local Functions**, and **Sequential Unit Expressions** followed by exactly one final expression.
- An `else if` chain ending in an **Else-Omitting Conditional Expression** has type `Unit`, so every branch in the chain must have type `Unit`.
- Local value names may shadow earlier value names; ordinary value bindings in the same scope must have distinct names.
- Lane functions are **Uncurried Functions** and may still be **First-Class Function Values**.
- Enum variants in expressions may be **Qualified Variants** or unambiguous **Unqualified Variants**.
- **Field Access** is source syntax and lowers through **Selector Lowering** before Buslane.
- A **Pipeline Expression** is source syntax and does not survive into Buslane or ANF.
- **Tuple Syntax** does not open `Basic.Data.Tuple` or make its declarations
  available by unqualified name.
- Resolving **Tuple Syntax** follows ordinary module availability: without an
  import of `Basic.Data.Tuple`, its qualified nominal type and constructor
  references remain unresolved and produce diagnostics.
- Qualified, open, and selective imports of `Basic.Data.Tuple` all establish
  the module binding needed by **Tuple Syntax**; the sugar does not depend on
  which declarations the import also exposes as unqualified names.
- **Surface Sugar Expansion** targets the exact declarations in the **Sugar
  Provider ABI**. Missing imports, declarations, or incompatible signatures use
  ordinary resolution and typechecking diagnostics; the compiler neither
  configures providers nor searches for structurally similar declarations.
- A **Right-Nested Tuple Chain** makes `(A, B, C)` and `(A, (B, C))`
  semantically identical; `()` remains `Unit`, `(A)` remains grouping, and
  singleton tuple syntax is invalid.
- The formatter canonicalizes every right-nested tuple-syntax chain to flat
  source spelling in types, expressions, and patterns. It preserves left-nested
  tuple elements because flattening them would change nominal structure.
- Tuple types, expressions, and patterns use the same comma-separation policy
  as function parameter lists: commas are required between items and trailing
  commas are invalid.
- A call argument list is not **Tuple Syntax**: `f(a, b)` passes two arguments,
  while `f((a, b))` passes one tuple value.
- Tuple elements are accessed through a **Tuple Pattern** or ordinary Basic
  functions; Lane has no `.0`, `.1`, or other numeric tuple projection syntax.
- **Tuple Patterns** expand into ordinary nested nominal variant patterns and
  receive no special irrefutability or exhaustiveness rule.
- **Tuple Patterns** are accepted in every existing Pattern position, including
  local pattern bindings, match arms, nested nominal patterns, struct-pattern
  fields, and handler payloads.
- Function parameters remain named parameter declarations rather than Pattern
  positions; tuple syntax does not introduce destructuring parameters.

## Example dialogue

> **Dev:** "Can a top-level value refer to a later value?"
> **Domain expert:** "No. Top-level functions and types can be recursive, but top-level values obey **Ordered Top-Level Value Scope**."
