# Define custom derivation as a library use of compile-time Shape

Lane supports custom derivation without a derive clause, compiler plugins,
traits, or a registry of derivable capabilities. The compiler exposes one
compile-time-only structural capability, `Shape[T]`, and one general Shape Fold.
Libraries define `Equal`, `Show`, `Decode`, `Schema`, and other derivations with
ordinary Lane types, functions, builtins, and offers. The compiler never
recognizes those capability names.

A Shape is an opaque capability for a type of kind `Type`. Programs introduce
Shapes explicitly as ordinary named values or offers, including generic
constructors for applications of a fixed higher-kinded constructor:

```lane
offer point_shape : Shape[Point] = builtin(...)

offer fn[T] list_shape() -> Shape[List[T]] {
  builtin(...)
}
```

The compiler does not inject Shape offers. `Shape[List[T]]` does not require
`Shape[T]`: a Shape describes exactly one nominal layer, and its type parameters
remain atomic components. Lane does not make Shape kind-polymorphic.

Shape metadata contains declaration, field, and variant names in declaration
order together with type-safe structural operations. It excludes source spans,
comments, visibility spelling, import spelling, and transparent-alias surface
presentation. Shape is erased after compile-time folding; Lane provides no
runtime Shape value, type registry, dynamic typecase, or reflection API.

The standard library expresses Shape structure with ordinary, arity-independent
sum-of-products types and a bidirectional `Iso[T, Repr]`. Observation-oriented
derivations use the projection direction, while construction-oriented
derivations use reconstruction. Labels remain available to algebras such as
`Show` and `Schema`; an `Equal` algebra may ignore them.

The general fold is parameterized by a fixed result constructor
`F : [Type] -> Type` and a user-defined Shape Algebra. Conceptually, the algebra
provides operations for Unit, Product, Sum, Iso, labels, and a recursive
strategy. A library constructs a derived offer by applying the fold directly:

```lane
offer point_equal : Equal[Point] =
  shape_fold(point_shape, equal_algebra)

fn[T] list_equal(auto offer element : Equal[T]) -> Equal[List[T]] {
  shape_fold(list_shape(), equal_algebra)
}

offer int_list_equal : Equal[List[Int]] = list_equal()
```

The compiler knows only the abstract `F`. It never branches on whether `F` is
`Equal`, `Show`, or another library type.

## Component evidence

Shape Fold unfolds exactly one layer. For every non-recursive component `A`, it
performs ordinary contextual resolution for `F[A]`. Failure to find `F[A]` is a
derivation error even when `Shape[A]` is visible. There is no fallback from
missing `F[A]` to recursively folding `Shape[A]`.

For example, deriving `Equal[User]` for a `User` containing `Address` requires
an explicit `Equal[Address]`. The presence of `Shape[Address]` records
structural access, not authorization to select structural equality. The
`Equal[Address]` offer may itself be handwritten or explicitly constructed by
another Shape Fold.

This rule keeps generic dependencies expressible. Deriving `Equal[List[T]]`
has the ordinary requirement:

```text
Equal[T] -> Equal[List[T]]
```

It does not introduce a hidden `Equal[T] or Shape[T]` constraint. A generic
builder remains an ordinary function and must be called explicitly to create
an exact offered value.

Shape Fold does not inspect the caller's lexical offer scope. Its expansion
introduces ordinary omitted contextual arguments of type `F[A]`; the existing
exact-only Contextual Resolution mechanism alone performs lexical lookup,
shadowing, and missing or ambiguity reporting. This preserves one semantic
owner for contextual lookup.

## Recursive derivation

A genuine back-edge to the current derivation root is not a missing component.
Shape Fold constructs a builder of type:

```text
(F[T]) -> F[T]
```

and gives it to the recursive strategy supplied by the algebra. The ordinary
operation for an algebra that supports recursion is:

```text
fix : [T]((F[T]) -> F[T]) -> F[T]
```

For `List[T]`, whose one-layer representation is conceptually:

```text
Sum[Unit, Product[T, List[T]]]
```

an Equal fold constructs:

```text
X = IsoEqual(
  ListIso,
  SumEqual(UnitEqual, ProductEqual(Equal[T], X)),
)
```

The Equal algebra interprets this equation with a recursive comparison worker
and returns an ordinary, standalone `Equal[List[T]]`. It does not return
`() -> Equal[List[T]]`, change auto-parameter evaluation, or require a
`delay`/`lazy` keyword. A Show algebra may similarly generate a recursive
renderer; a graph-like Schema algebra may generate explicit reference nodes.
An algebra with no lawful recursive result may reject a recursive fold while
remaining usable for non-recursive types.

The compiler is responsible for recognizing the structural back-edge and for
issuing a generic diagnostic when the chosen recursion policy rejects it. The
library is responsible for the meaning and implementation of `fix`. Contextual
resolution does not infer a universal lazy dictionary fixed point.

## Runtime and optimization

Product, Sum, Iso, and every derived artifact have ordinary Lane semantics.
Custom derivations may intentionally produce runtime data such as field names
inside `Schema[T]`, but they cannot retain Shape or access runtime reflection.

Standard derivations must not pay avoidable representation-allocation costs.
This is an optimization obligation of general inlining, escape analysis, and
scalar replacement, not an `Equal`- or Shape-specific runtime representation.
Escaping sum-of-products values retain their ordinary nominal semantics.

## Consequences

- Derivation remains explicit: users write ordinary offers for Shape and for
  the resulting capability.
- Shape does not imply any particular derived semantics.
- User-defined field capabilities are never replaced by implicit structural
  derivation.
- Generic derivation functions expose their component requirements in their
  ordinary function types.
- Direct recursion is interpreted by the selected Shape Algebra rather than by
  lazy contextual dictionaries.
- Missing component evidence, unsupported recursion, and unavailable Shape are
  distinct diagnostics.
- The compiler owns structural inspection, back-edge recognition, compile-time
  folding, and Shape erasure.
- Libraries own all capability-specific combinators, fixed-point
  implementations, and runtime artifacts.
- The compiler Shape Fold ABI fixes the required algebra operation names and
  structural result contracts. The standard library supplies ordinary Lane
  declarations conforming to that ABI.
