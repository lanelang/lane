# F-Omega Type-Level Computation

Lane2 supports higher-kinded types and type-level computation with a
System F-omega-style type language. This replaces the earlier model where the
type representation was only higher-kind-ready.

Lane2 type-level expressions include nominal type constructors, type
parameters, type application, type-level lambdas, primitive types, function
types, and forall types. Type application is uniform and left-associative.
Nominal constructors and type application are separate type objects; there is
no argument-carrying nominal type object.

Kinds use parameter-list syntax, such as `[Type] -> Type` and
`[Type, Type] -> Type`. They are n-ary, non-curried, and compared
structurally. Type parameter binders use `A` or `A : K`; omitted kind
annotations default to `Type`.

Type-level lambdas use `type[A1 : K1, ..., An : Kn] => T`. They are ordinary
type-level expressions and may appear anywhere a type-level expression is
allowed. A single binder list is n-ary and non-curried; nested type-level
lambdas express staged type functions. Lambda application uses capture-avoiding
beta reduction. Lambda equality uses alpha-equivalence, but not eta equality.

Top-level type aliases use `type Name = TypeExpr`. The left side is name-only,
and alias functions are expressed by putting a type-level lambda on the right
side. Alias right-hand sides may have any well-formed kind. Aliases are
transparent, top-level only, order-independent, and acyclic; dependency
analysis uses free alias references.

Definitional type equality uses transparent alias expansion plus full
beta-normalization. Eta equality is not part of this decision. Normalization
fuel is an implementation safeguard; exhausting it indicates an internal
compiler bug rather than a user-facing type error.

Buslane is upgraded with the F-omega constructs required to preserve
higher-kinded polymorphic values: higher kinds, type-level lambdas, and
type-level application. Source type alias names do not become Buslane
identities. Lowering produces alias-free Buslane type terms. Diagnostics should
preserve source type presentation when possible, even though semantic type
terms are alias-free.

This keeps the source language, the checker, and Buslane aligned. A value whose
type is polymorphic over a type constructor, such as
`[F : [Type] -> Type](F[Int]) -> F[Int]`, can cross the Buslane boundary without
being erased into a weaker System F representation.

Rejected alternatives:

- Keep Buslane as plain System F and normalize all higher-kinded structure away
  before Buslane. This fails for higher-kinded polymorphic values that must
  remain first-class across the core boundary.
- Add automatic currying or implicit partial type application. This conflicts
  with Lane2's parameter-list design and explicit ambiguity principles.
- Use declaration-specific multi-layer alias binders such as
  `type Result[E][A] = ...`. Ordinary type-level lambdas are more orthogonal
  and can appear in any type expression position.
- Add eta equality for type-level functions. This is deferred to keep
  definitional equality tractable.
