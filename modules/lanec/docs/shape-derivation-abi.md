# Shape Derivation ABI

This document is the compiler-facing reference for implementing custom
derivation support in Basic. The compiler recognizes only the two intrinsic
strings described below. `Shape`, `ShapeAlgebra`, `Equal`, `Show`, `Pair`, and
`Sum` remain ordinary Lane declarations; their names and module paths are not
recognized by the compiler.

## Compile-time declarations

Declare a unary nominal capability type for Shape:

```lane
pub struct Shape[_T] {}
```

A Shape witness is produced by `%shape` under a complete expected type:

```lane
pub offer point_shape : Shape[Point] = builtin("%shape")

pub offer fn[T] list_shape() -> Shape[List[T]] {
  builtin("%shape")
}
```

The witness records the represented type argument. It has no runtime
representation. A declaration whose entire body or initializer is `%shape` is
kept in the module interface but omitted from the module object. Any witness
that remains in ordinary runtime code is rejected with E3032.

Declare the fold as a pure two-argument generic function whose result is one
unary result constructor applied to the represented type:

```lane
pub fn[F : [Type] -> Type, T] shape_fold(
  _shape : Shape[T],
  _algebra : ShapeAlgebra[F]
) -> F[T] {
  builtin("%shape_fold")
}
```

The body is erased like `%shape`. Compile-time intrinsic identity is stored in
the module interface artifact, so imported declarations work after binary
artifact round-tripping. No runtime value or object export is generated for
either intrinsic.

## Algebra contract

The algebra is an ordinary struct value. The compiler accesses fields by the
following names and typechecks every generated call normally:

```lane
pub struct ShapeAlgebra[F : [Type] -> Type] {
  unit : F[Unit]
  product : [A, B](F[A], F[B]) -> F[Pair[A, B]]
  sum : [A, B](F[A], F[B]) -> F[Sum[A, B]]
  field : [A](String, F[A]) -> F[A]
  variant : [A](String, F[A]) -> F[A]
  iso : [T, R](String, (T) -> R, (R) -> T, F[R]) -> F[T]
  fix : [T](((F[T]) -> F[T])) -> F[T]
}
```

`Pair` is not a recognized name. The result argument of `product` must be a
nominal struct with exactly two fields; declaration order identifies head and
tail. `Sum` is likewise not a recognized name. The result argument of `sum`
must be a nominal enum with exactly two variants, each with one payload;
declaration order identifies left and right.

An algebra used only for non-recursive structs may omit `sum`, `variant`, and
`fix`; missing operations are diagnosed only when the folded Shape requires
them. In practice Basic should publish the complete contract above.

## Structural mapping

Struct fields and enum variants retain declaration order.

- A struct with fields `A, B, C` uses
  `Pair[A, Pair[B, Pair[C, Unit]]]`.
- An empty struct uses `Unit`.
- Each field component is wrapped with `field(field_name, evidence)`.
- An enum variant payload uses the same right-nested Product encoding.
- Variants `R0, R1, R2` use `Sum[R0, Sum[R1, R2]]`.
- A one-variant enum uses its payload Product directly.
- Each variant component is wrapped with
  `variant(variant_name, evidence)`.
- `iso(type_name, to, from, representation)` converts between the nominal type
  and the generated representation.

For a non-recursive component `A`, the expansion creates an ordinary omitted
contextual argument of type `F[A]`. Shape Fold itself never reads a lexical
offer scope. Existing Contextual Resolution performs exact lookup, lexical
shadowing, Contextual Provider composition, ambiguity reporting, and cycle
rejection. Missing evidence therefore remains the ordinary
`MissingContextualOffer(F[A])` diagnostic.

A component exactly equal to the current root type is a direct recursive
back-edge. The compiler builds `(F[T]) -> F[T]` and passes it to `fix`.
Recursion nested inside another constructor is not unfolded by Shape; it is an
ordinary `F[Container[T]]` component goal and may be satisfied by an ordinary
Contextual Provider.

Empty enums, structs with type members, and variants with local type parameters
do not fit this sum-of-products ABI and are rejected with E3033. A library may
still provide the desired `F[T]` manually.

## Example: Point equality

Assuming ordinary `Equal`, `Pair`, and algebra declarations:

```lane
struct Point {
  x : Int
  y : Int
}

offer point_shape : Shape[Point] = builtin("%shape")

offer point_equal : Equal[Point] =
  shape_fold(point_shape, equal_algebra)
```

The generated fold requests ordinary `Equal[Int]` evidence twice, labels the
two components `"x"` and `"y"`, combines them as
`Pair[Int, Pair[Int, Unit]]`, and applies the generated `Point` Iso.

## Example: List equality

```lane
enum List[A] {
  empty()
  cons(A, List[A])
}

offer fn[A] list_shape() -> Shape[List[A]] {
  builtin("%shape")
}

pub offer fn[A] list_equal(
  auto element : Equal[A]
) -> Equal[List[A]] {
  shape_fold(list_shape(), equal_algebra)
}
```

The one-layer representation is:

```text
Sum[Unit, Pair[A, Pair[List[A], Unit]]]
```

The `A` component creates the ordinary `Equal[A]` contextual requirement. The
direct `List[A]` back-edge uses `equal_algebra.fix`. The resulting
`list_equal` is an ordinary Contextual Provider: when `Equal[List[Int]]` is
requested, general contextual resolution infers `A = Int`, resolves
`Equal[Int]`, and calls the provider. No Shape-specific offer search occurs.
