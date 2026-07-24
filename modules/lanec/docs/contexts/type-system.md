# Lane Type System

This context names type-level concepts used by the checker, specification, and
later IRs.

## Language

**Type Object**:
A checked type representation shared by semantic analysis, Buslane Core Language, and execution contracts.
_Avoid_: source type syntax, parser type node

**Kind**:
A classifier of type-level expressions, including ordinary type kind `Type` and constructor kinds written with bracketed parameter lists such as `[Type] -> Type`.
_Avoid_: runtime type, trait constraint

**Higher-Kinded Type Parameter**:
A type parameter whose kind may accept type arguments before producing an ordinary type, such as `F : [Type] -> Type`.
_Avoid_: unkinded parameter, value-level function

**Type Constructor Application**:
A type-level application that applies a type constructor of kind `[K1, ..., Kn] -> K` to type arguments of kinds `K1, ..., Kn`.
_Avoid_: value call, runtime application

**Type Alias Function**:
A named source-level type function written as a transparent top-level `type` alias.
_Avoid_: runtime alias, value function, nominal type constructor

**Type-Level Lambda**:
A type-level abstraction expression that introduces type parameter binders and returns a type-level expression.
_Avoid_: value-level lambda, implicit curry, separate alias-header semantics

**Type-Level Lambda Alpha-Equivalence**:
The rule that type-level lambdas differing only by consistent renaming of bound type parameters are equal.
_Avoid_: binder identity equality, display-name equality

**Capture-Avoiding Type Substitution**:
The substitution rule used by type-level beta reduction and generic instantiation so replacement type expressions are not captured by nested binders.
_Avoid_: textual substitution, capture-prone beta reduction

**Parameter-List Type Lambda**:
A non-curried type-level lambda whose bracketed binder list introduces all parameters at once.
_Avoid_: implicit curried type lambda, automatic partial type abstraction

**Top-Level Type Alias**:
A type alias declaration that is allowed only at the top level.
_Avoid_: local type alias, block-scoped type function

**Arbitrary-Kind Type Alias**:
A top-level type alias whose right-hand side may have any well-formed kind.
_Avoid_: value-level-only alias, Type-only alias

**Type Alias Parameter Header**:
An optional single non-empty bracketed type-parameter binder list on a top-level type alias declaration. Source syntax preserves the header; semantic typing and export treat it as a type-level lambda on the right-hand side.
_Avoid_: nominal type parameter header, empty alias parameter header, multi-layer alias parameter header, separate alias identity

**Type Alias Declaration Syntax**:
The top-level source forms `type Name = TypeExpr` and `type Name[Params] = TypeExpr`.
_Avoid_: type alias block syntax, local type alias syntax

**Unified Type Namespace**:
The source namespace shared by primitive type names, nominal type constructors, type aliases, and in-scope type parameters.
_Avoid_: separate alias namespace, nominal-only type lookup

**Acyclic Type Alias Graph**:
The top-level dependency graph among transparent type aliases, which must contain no cycles.
_Avoid_: recursive transparent alias, cyclic type-level reduction

**Free Alias Dependency**:
A type alias dependency caused only by a free reference to another top-level type alias.
_Avoid_: shadowed binder reference, nominal constructor reference

**Order-Independent Type Alias Collection**:
The top-level collection rule that gathers all type alias names before checking alias bodies and dependency cycles.
_Avoid_: textual type alias order, local alias dependency

**Definitional Type Equality**:
Type equality after transparent expansion and reduction of type-level definitions such as type alias functions.
_Avoid_: nominal alias equality, syntactic equality only

**Beta Definitional Equality**:
Definitional type equality based on transparent alias expansion and beta reduction of type-level lambda application, without eta equality.
_Avoid_: beta-eta equality, purely syntactic equality

**Full Type Normalization**:
The semantic normalization strategy that recursively expands transparent type aliases and beta-reduces type-level lambda applications throughout a type-level expression.
_Avoid_: weak-head-only type normalization, user-visible fuel semantics

**Type Normalization Fuel**:
An implementation safeguard against compiler bugs or accidental nontermination during full type normalization.
_Avoid_: language recursion limit, user program error

**Type-Level Lambda Kind**:
The constructor kind formed from a type-level lambda's binder kinds and body kind.
_Avoid_: value function type, inferred value parameter type

**System F-Omega Core**:
The typed core model with kinds, forall, type-level functions, type application, and type-level computation.
_Avoid_: plain System F, kinded System F without computation

**Buslane F-Omega Constructs**:
The Buslane core type-language constructs needed to preserve higher-kinded polymorphism: higher kinds, type-level lambda, and type-level application.
_Avoid_: source type alias syntax, front-end-only higher kinds

**Alias-Free Buslane Type Term**:
A Buslane type-level expression after source type aliases have been transparently expanded before or during lowering.
_Avoid_: source alias reference in Buslane metadata, nominal alias identity

**Source Type Presentation**:
The diagnostic-facing source spelling or origin information for a type-level expression.
_Avoid_: semantic alias identity, Buslane alias metadata

**General Type Application Callee**:
The rule that the callee of a type-level application may be any type-level expression with constructor kind.
_Avoid_: name-only type application, nominal-only application callee

**Left-Associative Type Application**:
The parsing rule that repeated type-argument postfixes group to the left.
_Avoid_: special chained application form, right-associative type application

**Higher-Kinded Type Argument**:
A type argument whose kind is itself a constructor kind, such as passing `Option : [Type] -> Type` to a parameter expecting `[Type] -> Type`.
_Avoid_: value argument, runtime constructor argument

**Uniform Type Application**:
The rule that all type-level application is represented by one application form, including nominal type instantiation and higher-kinded parameter instantiation.
_Avoid_: nominal-only type arguments, compatibility wrapper, duplicated application encodings

**Nominal Type Constructor Object**:
The type object for a declared nominal type constructor before it is applied to type arguments.
_Avoid_: nominal type application, argument-carrying nominal type

**Nominal Constructor Kind**:
The kind of a declared nominal type constructor, computed from its type parameter binders and returning `Type`.
_Avoid_: nominal arity only, all nominal names are value-level types

**Type-Level Expression**:
A type syntax form after resolution and kind checking, which may have kind `Type` or a higher kind.
_Avoid_: value expression, runtime expression

**Effect-Level Expression**:
A type-level expression whose kind is **Effect Kind** and whose value denotes an effect set.
_Avoid_: effect operation invocation, handler expression, effect declaration body

**Kinded Alias Body**:
The right-hand side of a top-level alias, parsed as a type-level form that may have ordinary type kind, constructor kind, or effect kind.
_Avoid_: value expression body, declaration block, runtime expression

**Value-Level Type**:
A type-level expression whose kind is exactly `Type` and is therefore valid as the type of a runtime value.
_Avoid_: higher-kinded constructor, type-level expression of any kind

**Kind Mismatch**:
A diagnostic condition where a type-level expression is well-formed but has a kind different from the kind required by its position.
_Avoid_: type argument arity mismatch, unresolved type

**Parameter-List Kind**:
A non-curried constructor kind written with a bracketed parameter list followed by `->`, such as `[Type, Type] -> Type`.
_Avoid_: curried kind arrow, bare kind arrow chain

**Position-Directed Bracket Parsing**:
The rule that bracket syntax is interpreted by grammar position: kind parameter lists in kind positions, type application postfixes in type positions, and forall binder lists in generic function type positions.
_Avoid_: lexical bracket overloading, context-free bracket meaning

**Type Lambda Precedence**:
The parsing rule that type-level lambda binds less tightly than postfix type application and extends to the right.
_Avoid_: implicit lambda callee, application-lower-than-lambda parsing

**Structural Kind Equality**:
The rule that kinds are equal exactly when their syntax trees match recursively after parsing.
_Avoid_: kind normalization, kind alpha-equivalence

**Kind-Annotated Type Parameter**:
A type parameter binder that explicitly declares its kind. Omitted kind annotations default to `Type`; Lane does not infer higher kinds from later use.
_Avoid_: type member only kind annotation, inferred higher kind

**Type Parameter Binder**:
The uniform source binder form for generic type parameters, written either as `A` or `A : K`.
_Avoid_: bare string type parameter, declaration-specific generic syntax

**Type Parameter Shadowing**:
The lexical rule that an inner type parameter binder may reuse and hide an outer type name.
_Avoid_: global type parameter uniqueness, display-name identity

**Duplicate Type Parameter Binder**:
A repeated type parameter name in one binder list.
_Avoid_: shadowing across nested binder lists

**Buslane Type Parameter Identity**:
A globally unique Buslane identity for a type parameter introduced by a forall or type lambda binder.
_Avoid_: source generic parameter name, de Bruijn index, compiler-front-end type variable

**Primitive Type**:
A built-in type provided by the language core: `Int`, `Bool`, `String`, or `Unit`.
_Avoid_: Basic library type, numeric tower

**Primitive Literal**:
A direct inhabitant of a primitive type, such as `true`, `42`, `"abc"`, or `()`.
_Avoid_: enum variant, nominal constructor

**Normalized Int Literal**:
A Buslane integer literal stored as a signed 64-bit value.
_Avoid_: decimal source spelling, arbitrary precision literal

**ASCII String**:
An immutable sequence of ASCII bytes.
_Avoid_: Unicode string, UTF-16 string

**Normalized String Literal**:
A Buslane string literal stored as an ASCII byte sequence rather than source spelling.
_Avoid_: escaped source spelling, Unicode string literal

**Nominal Type**:
A type whose identity comes from its declaration name rather than from having the same structure as another type.
_Avoid_: structural type, shape-compatible type

**Generic Type Definition**:
A struct or enum declaration whose explicit type parameter list follows the type name.
_Avoid_: keyword-attached type parameters

**Nominal Type Parameter Header**:
The type parameter binder list on a nominal struct or enum declaration, used to determine the nominal constructor kind.
_Avoid_: transparent alias parameter list, type-level lambda body

**Generic Type Application**:
A use of a generic type name with explicit type arguments in brackets.
_Avoid_: inferred type constructor use, angle-bracket type application

**Parameter-List Function Type**:
A function type written with a parenthesized parameter list followed by `->` and a result type.
_Avoid_: curried function type, bare arrow chain

**Generic Function Type**:
A function type whose explicit type parameter list precedes its parenthesized value parameter list.
_Avoid_: implicit forall, top-level-only polymorphic type

**Forall Type**:
A type object that binds Buslane type parameter identities over another type.
_Avoid_: function-owned generic parameter list, implicit polymorphic wrapper, separate type-object binder identity

**Kinded Forall Binder**:
A forall-bound type parameter with an explicit or defaulted kind.
_Avoid_: unkinded forall parameter, function-only generic binder

**Rank-N Type**:
A type where a forall may appear below another type constructor or function boundary.
_Avoid_: top-level-only polymorphism, implicit generic lifting

**Nominal Existential Member**:
A hidden type member declared inside a nominal struct or enum declaration.
_Avoid_: structural existential type, anonymous package field

**Higher-Kinded Existential Witness**:
A witness supplied for an existential type member whose declared kind is higher than `Type`.
_Avoid_: runtime type constructor value, existential value field

**Type Alpha-Equivalence**:
The rule that types differing only by consistent renaming of bound type parameter identities are equal.
_Avoid_: display-name equality, raw binder identity equality

**Buslane Type Logic**:
The Buslane-owned implementation of type well-formedness, kind checking, equality, and alpha-equivalence.
_Avoid_: compiler-front-end type checker, source type syntax

**Core Coercion**:
A proof or expression that converts between types not equal by ordinary Buslane type equality.
_Avoid_: alpha-equivalence, nominal type equality

**Local Type Inference**:
The bidirectional rule that type information may be synthesized upward or checked downward between adjacent syntax nodes without global constraint solving.
_Avoid_: global inference, HM flattening, use-site backpropagation

**Direct Context Inference**:
The rule that an omitted local type may be inferred only from the expression's immediate expected type, not from later uses of a bound name.
_Avoid_: use-site backpropagation, whole-scope inference

**Implicit Generic Instantiation**:
The rule that type parameters of a generic function or data constructor are inferred at the use site unless ambiguity requires explicit type arguments.
_Avoid_: mandatory type application, global generic inference

**Higher-Kinded Generic Instantiation**:
Implicit generic instantiation that may solve a higher-kinded type parameter from type-application structure.
_Avoid_: higher-order unification

**Type Occurs Check**:
The rule that an inferred type-parameter substitution may not bind a parameter to a type-level expression that mentions the same parameter free.
_Avoid_: recursive type inference, cyclic type substitution

**Higher-Kinded Contextual Match**:
A contextual resolution match whose offered value type contains higher-kinded type arguments or parameters.
_Avoid_: higher-order unification, offer-driven type inference

**Local Generic Function**:
A function defined inside an expression or definition that may introduce its own type parameters.
_Avoid_: top-level-only polymorphism, lifted generic function

**Generic Function Literal**:
A function literal that introduces its own type parameters where the function is written.
_Avoid_: generic binding, inferred generic let

**Type Application**:
A Buslane operation that instantiates a polymorphic value with type arguments.
_Avoid_: runtime type argument, erased substitution only

**First-Class Type Application**:
A Buslane type application whose callee is any polymorphic value rather than only a known generic function symbol.
_Avoid_: direct generic call only, runtime typecase

**Type Lambda**:
A Buslane value form that abstracts over type parameters to create a polymorphic value.
_Avoid_: generic ordinary lambda, runtime type function

**Runtime Typecase**:
A runtime branch whose behavior depends on inspecting a type argument or type constructor.
_Avoid_: ordinary pattern match, implicit reflection

**Runtime Type Erasure**:
The rule that generic type arguments used for checking are not represented in execution targets.
_Avoid_: runtime generic metadata, implicit type evidence

**Uniform Value Representation**:
A runtime representation where values share one execution-level value model rather than being specialized by generic type arguments.
_Avoid_: monomorphized value layout, type-specialized runtime

## Relationships

- **Type Objects** are distinct from source type syntax.
- Every **Buslane Type Parameter Identity** has a **Kind**.
- **Buslane Type Parameter Identities** are globally unique; source-level generic parameter shadowing is resolved before Buslane.
- A **Higher-Kinded Type Parameter** may be instantiated by **Type Constructor Application**.
- V1 supports **Type Constructor Application** and uses **Type Alias Functions** for type-level functions and computation.
- Lane preserves higher-kinded polymorphic values through **Buslane F-Omega Constructs** rather than erasing them before Buslane.
- **Type Alias Functions** are transparent and participate in **Definitional Type Equality**.
- Buslane type metadata uses **Alias-Free Buslane Type Terms**; source type alias names are not Buslane identities.
- Public and private **Top-Level Type Aliases** share the same **Type Alias Declaration Syntax**; `pub` controls module-interface visibility only.
- A public **Type Alias Parameter Header** is exported through the module interface as the equivalent transparent **Type-Level Lambda** body.
- Diagnostics may use **Source Type Presentation** to show user-written alias names even when semantic type equality is alias-free.
- Source pretty printing and parser fixtures preserve a user-written **Type Alias Parameter Header**; semantic debug output and module interfaces may print the equivalent **Type-Level Lambda** form.
- Diagnostics for a **Type Alias Parameter Header** use source locations and source terminology for the header and right-hand side, not the synthetic desugared **Type-Level Lambda**.
- **Definitional Type Equality** is **Beta Definitional Equality**; v1 does not use eta equality for type-level functions.
- **Beta Definitional Equality** compares **Full Type Normalization** results.
- Exhausting **Type Normalization Fuel** is an internal compiler bug, not a user-facing type error.
- A **Top-Level Type Alias** binds a name to a type-level expression; a **Type Alias Parameter Header** desugars to a **Type-Level Lambda** on the right-hand side.
- **Type-Level Lambdas** are ordinary **Type-Level Expressions** and may appear anywhere a type-level expression is syntactically allowed; enclosing positions still check the resulting kind.
- A **Type-Level Lambda** may be used directly as a type argument or existential witness when its kind matches the required kind.
- **Type-Level Lambdas** use **Type Parameter Binders**.
- **Type-Level Lambdas** use **Type-Level Lambda Alpha-Equivalence**.
- Type-level beta reduction uses **Capture-Avoiding Type Substitution**.
- A **Type-Level Lambda Kind** is `[K1, ..., Kn] -> K` when the lambda binders have kinds `K1, ..., Kn` and the body has kind `K`.
- A **Type-Level Lambda** body may have any well-formed kind.
- A **Parameter-List Type Lambda** is not implicitly curried; nested type lambdas express staged type-level functions.
- Every **Type Alias Function** is a **Top-Level Type Alias**; Lane does not support local type alias declarations.
- Every **Top-Level Type Alias** may use a **Type Alias Parameter Header**.
- Syntax trees preserve a user-written **Type Alias Parameter Header**; semantic analysis observes the desugared **Type-Level Lambda** form.
- A **Type Alias Parameter Header** is single-layer; staged type-level functions use nested **Type-Level Lambdas** on the right-hand side.
- A **Type Alias Parameter Header** composes with right-hand-side **Type-Level Lambdas** by adding the outermost type-level lambda layer.
- A **Type Alias Parameter Header** uses ordinary **Type Parameter Binders**; nested binders may shadow it, but duplicate binders in the same header are invalid.
- **Acyclic Type Alias Graph** and **Free Alias Dependency** analysis observe the desugared body of a **Type Alias Parameter Header**.
- **Type Alias Declaration Syntax** includes `type Name = TypeExpr` and `type Name[Params] = TypeExpr`.
- A **Top-Level Type Alias** may be an **Arbitrary-Kind Type Alias**.
- **Top-Level Type Aliases** share the **Unified Type Namespace** with structs, enums, and primitive type names.
- A **Top-Level Type Alias** may bind an **Effect-Level Expression** such as an effect set literal when its inferred kind is **Effect Kind**.
- An **Effect-Level Expression** may use **Effect Kind** type parameters and transparent alias application with the existing **Type Constructor Application** syntax.
- A **Kinded Alias Body** may be an ordinary **Type-Level Expression** or an **Effect-Level Expression**; ordinary value expressions are not valid alias bodies.
- Transparent type alias declarations form an **Acyclic Type Alias Graph**.
- **Effect-Level Expressions** from transparent aliases are expanded before Buslane lowering; Buslane does not retain source **Effect Set Alias** identities.
- **Top-Level Type Aliases** use **Order-Independent Type Alias Collection** and may reference later aliases when the alias graph remains acyclic.
- The **Acyclic Type Alias Graph** is built from **Free Alias Dependencies**.
- A **Higher-Kinded Type Argument** is valid when its kind exactly matches the corresponding type-application parameter kind.
- Type constructor applications use **General Type Application Callee** syntax; the callee is not restricted to a nominal name or type parameter name.
- Repeated type-argument postfixes use **Left-Associative Type Application**.
- A **Nominal Type Constructor Object** and **Uniform Type Application** are separate type objects; `Option[Int]` is an application of the `Option` constructor.
- A **Nominal Constructor Kind** is `[K1, ..., Kn] -> Type` for a declaration with binders `A1 : K1, ..., An : Kn`; a declaration with no type parameters has kind `Type`.
- Lane kind arrows use **Parameter-List Kind** syntax and are not curried.
- Bracket syntax follows **Position-Directed Bracket Parsing**.
- Type syntax follows **Type Lambda Precedence**; a type-level lambda used as an application callee must be parenthesized.
- Kind equality is **Structural Kind Equality**; there are no kind variables, kind aliases, or kind-level reductions in v1.
- Every type parameter binder may be a **Kind-Annotated Type Parameter**; omitted kind annotations default to `Type`, with no kind inference from later applications.
- Every generic type parameter list uses **Type Parameter Binders** rather than declaration-specific bare name lists.
- The `K` in a **Type Parameter Binder** is parsed by the full kind grammar; `F : [Type] -> Type` needs no extra parentheses.
- **Type Parameter Shadowing** is allowed across nested scopes.
- A **Duplicate Type Parameter Binder** in the same binder list is invalid.
- Type constructors are **Type-Level Expressions**, not value-level values.
- Value parameter types, return types, fields, payloads, let annotations, contextual offers, and Buslane value metadata require **Value-Level Types**.
- A bare non-nullary nominal constructor is a valid **Type-Level Expression** but produces a **Kind Mismatch** in a **Value-Level Type** position.
- Lane v1 has four **Primitive Types**: `Int`, `Bool`, `String`, and `Unit`.
- **Primitive Literals** are not nominal data constructors.
- Buslane stores primitive literals as normalized values rather than source spelling.
- A **Normalized Int Literal** is a signed 64-bit value.
- A **Normalized String Literal** is an ASCII byte sequence.
- **Enum Types** and **Struct Types** create **Nominal Types**.
- A generic struct or enum uses **Generic Type Definition** syntax and is used with **Generic Type Application** syntax.
- Structs and enums keep a **Nominal Type Parameter Header**; type alias parameter headers are pure sugar for **Type-Level Lambdas**.
- Lane function types use **Parameter-List Function Type** syntax.
- Every function type, including a unary function type, uses a parenthesized
  parameter list; bare `A -> B` syntax is invalid.
- `(A, B) -> C` has two value parameters, while `((A, B)) -> C` has one
  tuple-typed value parameter.
- **Generic Function Type** syntax elaborates to a **Forall Type**.
- **Forall Types** bind **Kinded Forall Binders**; omitted kinds default to `Type`.
- **Forall Types** and **Type Lambdas** use the same **Buslane Type Parameter Identity** model.
- **Forall Types** use **Type Alpha-Equivalence** for equality; globally unique identities do not make raw binder identity equality the type-equality rule.
- **Type Alpha-Equivalence** for **Forall Types** requires corresponding binders to have structurally equal kinds.
- **Buslane Type Logic** is owned by Buslane and does not depend on compiler-front-end type objects.
- V1 has no **Core Coercion**; type conversion requires ordinary Buslane type equality.
- Buslane can represent **Rank-N Types** by allowing **Forall Types** in ordinary type positions.
- A **Type Lambda** may be bound by an ordinary Buslane value binding; Buslane does not perform implicit let-generalization.
- Runtime type erasure happens after Buslane, not during Buslane construction.
- **Nominal Existential Members** do not create a standalone `Exists` type constructor.
- A **Higher-Kinded Existential Witness** is valid when its kind exactly matches the declared existential member kind.
- Existential escape checking treats higher-kinded hidden members like ordinary hidden members; a result type mentioning `F[Int]` still mentions hidden `F`.
- **Local Type Inference** uses **Direct Context Inference** and does not infer a local function's parameters from later calls.
- Generic functions and data constructors use **Implicit Generic Instantiation**.
- **Higher-Kinded Generic Instantiation** may bind an unsolved type parameter to a same-kind type-level expression by structural matching.
- **Higher-Kinded Generic Instantiation** uses the **Type Occurs Check** before accepting a substitution.
- **Higher-Kinded Contextual Matches** use ordinary type equality only; contextual resolution does not infer higher-kinded parameters from the offer set.
- Lane v1 has no **Runtime Typecase**.
- Generic type arguments use **Runtime Type Erasure** before execution.
- Execution targets use **Uniform Value Representation** for generic code.

## Example dialogue

> **Dev:** "Can we infer a local function parameter type from a later call?"
> **Domain expert:** "No. **Local Type Inference** only moves through adjacent syntax; later uses do not back-propagate into the binding."
