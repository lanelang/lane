---
status: accepted
---

# Explicit structural derivation

Lane supports library-defined structural derivation through the call-shaped `derive` expression and the ordinary typed algebra `Deriver[C]`. The compiler elaborates one visible nominal layer into typed calls, while standard-library and user code define capability semantics, recursive wiring, and lifting through type constructors.

## Surface syntax

`derive` is a reserved keyword with this declaration-shaped interface:

```lane
derive[C : [Type] -> Type, T : Type](
  auto deriver : Deriver[C],
) -> C[T]
```

Both type arguments and the argument list are mandatory:

```lane
derive[C, T]()
derive[C, T](deriver=expression)
```

The empty form resolves one exact visible offer of type `Deriver[C]`. The explicit form checks `expression` as an ordinary `Deriver[C]` value. An explicit auto argument is named `deriver`.

The result is an ordinary `C[T]` value. It becomes contextually visible when bound by an ordinary offered value definition:

```lane
pub offer point_impl_equal : Equal[Point] =
  derive[Equal, Point]()
```

## Structural interface

The canonical structural interface lives in `Basic.Trait.Derive`:

```lane
module Basic.Trait.Derive

import Basic.Data.Void.{ Void }

pub struct Deriver[C : [Type] -> Type] {
  unit : () -> C[Unit]
  product : [A, B](C[A], C[B]) -> C[Product[A, B]]
  void : () -> C[Void]
  sum : [A, B](C[A], C[B]) -> C[Sum[A, B]]
  field : [A](FieldInfo, C[A]) -> C[A]
  variant : [A](VariantInfo, C[A]) -> C[A]
  record : [T, R](TypeInfo, Iso[T, R], C[R]) -> C[T]
  enumeration : [T, R](TypeInfo, Iso[T, R], C[R]) -> C[T]
}

pub struct Recursive[C : [Type] -> Type] {
  defer : [T](() -> C[T]) -> C[T]
}

pub struct Lift[
  C : [Type] -> Type,
  F : [Type] -> Type,
] {
  lift : [A](C[A]) -> C[F[A]]
}

pub struct Product[A, B] {
  head : A
  tail : B
}

pub enum Sum[A, B] {
  here(A)
  there(B)
}

pub struct Iso[T, R] {
  to : (T) -> R
  from : (R) -> T
}

pub struct TypeInfo {
  name : String
  qualified_name : String
}

pub struct FieldInfo {
  name : String
}

pub struct VariantInfo {
  name : String
}
```

`Deriver[C]` is an ordinary value. The compiler obtains `Deriver`, `Product`, `Sum`, `Iso`, `TypeInfo`, `FieldInfo`, and `VariantInfo` by their canonical declarations in the configured `Basic.Trait.Derive` Module interface and calls them according to the target declaration. The `derive` keyword does not require a source import. Source code follows ordinary import rules only when it names these declarations directly, and deriver offers follow ordinary lexical visibility. A conforming Basic library provides the canonical interface; the compiler does not select declarations by unqualified name or by structural similarity.

`Deriver[C]` has no compiler-assumed algebraic laws. Every generated call and its canonical nesting are observable ordinary Lane semantics. The compiler does not reassociate or remove structural calls based on their `Deriver[C]` type and applies only optimizations justified for the generated ordinary program.

`Recursive[C]` is an ordinary standard-library interface. A capability supplies its own adapter when it can defer access to a `C[T]`. The compiler does not inspect or invoke this interface.

`Lift[C,F]` is an ordinary standard-library interface for lifting a capability through a unary type constructor. The compiler does not inspect or invoke it.

## Canonical representation

Struct fields, enum variants, and variant payloads retain source declaration order. Products and sums associate to the right:

```text
struct {}                     => Unit
struct { a : A }              => Product[A, Unit]
struct { a : A, b : B }       => Product[A, Product[B, Unit]]
enum {}                       => Void
enum { a() }                  => Sum[Unit, Void]
enum { a(A), b(B) }           => Sum[Product[A, Unit], Sum[Product[B, Unit], Void]]
enum { a(A, B) }              => Sum[Product[A, Product[B, Unit]], Void]
```

`TypeInfo.name` is the declared name of the normalized nominal type. `TypeInfo.qualified_name` is its canonical Module path followed by its declared name. Transparent type aliases and import aliases do not affect either value, generic arguments are not included, and renaming the declaration or its Module changes the corresponding value. `FieldInfo.name` and `VariantInfo.name` are their declaration names within the enclosing type. Product and sum position already records declaration order.

Tuple syntax resolves to the canonical nominal `Basic.Data.Tuple.Tuple` enum before structural derivation. Tuple types therefore follow the ordinary enum derivation path, and tuple syntax and the explicit nominal type have identical derivation semantics. Because tuple syntax associates to the right, deriving `(A, B, C)` derives one outer `Tuple[A, Tuple[B, C]]` layer and requires component evidence `C[A]` and `C[Tuple[B, C]]`.

## Target normalization

The compiler fully normalizes `T` before selecting its structural declaration. Transparent aliases contribute no nominal derivation layer:

```lane
pub type Position = Point

derive[Equal, Position](deriver=derive_equal)
derive[Equal, Point](deriver=derive_equal)
```

Both expressions derive the same nominal declaration and use its `Point` name and canonical qualified name.

Structural derivation is defined exactly when the normalized `T` identifies a nominal struct or enum and the compiler can construct a well-formed canonical representation type `R` and a complete `Iso[T,R]` using the type variables available at the derive site. Empty structs and enums are representable by `Unit` and `Void`. A hidden existential member declared directly by the target prevents representation because its witness is not available at the derive site. A closed nominal field or payload type that internally contains existential members remains an ordinary component type and is representable when exact `C[A]` evidence is visible.

The derive site uses the same checked nominal declarations and module-interface shapes available to ordinary construction, projection, and pattern matching.

## Component evidence

Generated calls for a field or payload of type `A` receive `C[A]` through Lane's ordinary contextual resolution at the derive site. Both derive forms use the same contextual environment.

## Defining a deriver

A capability and its structural semantics are ordinary user code:

```lane
import Basic.Data.Void.{ Void, absurd }

pub struct Equal[T] {
  equal : (T, T) -> Bool
}

fn equal_unit() -> Equal[Unit] {
  Equal::{
    equal: fn(_left, _right) {
      true
    },
  }
}

fn[A, B] equal_product(
  equal_a : Equal[A],
  equal_b : Equal[B],
) -> Equal[Product[A, B]] {
  Equal::{
    equal: fn(left, right) {
      if equal_a.equal(left.head, right.head) {
        equal_b.equal(left.tail, right.tail)
      } else {
        false
      }
    },
  }
}

fn equal_void() -> Equal[Void] {
  Equal::{
    equal: fn(left, _right) {
      absurd[Bool](left)
    },
  }
}

fn[A, B] equal_sum(
  equal_a : Equal[A],
  equal_b : Equal[B],
) -> Equal[Sum[A, B]] {
  Equal::{
    equal: fn(left, right) {
      match left {
        here(left) =>
          match right {
            here(right) => equal_a.equal(left, right)
            there(_) => false
          }
        there(left) =>
          match right {
            here(_) => false
            there(right) => equal_b.equal(left, right)
          }
      }
    },
  }
}

fn[T, R] equal_iso(
  iso : Iso[T, R],
  equal_repr : Equal[R],
) -> Equal[T] {
  Equal::{
    equal: fn(left, right) {
      equal_repr.equal(iso.to(left), iso.to(right))
    },
  }
}

pub offer derive_equal : Deriver[Equal] = Deriver::{
  unit: equal_unit,
  product: equal_product,
  void: equal_void,
  sum: equal_sum,
  field: fn[A](_info, equal) {
    equal
  },
  variant: fn[A](_info, equal) {
    equal
  },
  record: fn[T, R](_info, iso, equal_repr) {
    equal_iso(iso, equal_repr)
  },
  enumeration: fn[T, R](_info, iso, equal_repr) {
    equal_iso(iso, equal_repr)
  },
}
```

Given the nominal declaration `Geometry.Point` and an ordinary contextual `Equal[Int]` value:

```lane
pub struct Point {
  x : Int
  y : Int
}

pub offer point_impl_equal : Equal[Point] =
  derive[Equal, Point]()
```

## Diagnostics

Missing and ambiguous component evidence is grouped by its normalized required type `C[A]`. Each diagnostic is anchored at the derive expression and lists every field or variant-payload path that requires that type. Ambiguous groups also list every matching contextual offer. Checking collects all independent component-evidence groups for one derive expression.

An omitted deriver uses the ordinary missing or ambiguous contextual-argument diagnostic for `Deriver[C]`. An explicit `deriver=expression` uses ordinary argument type checking.

When target normalization does not produce a representable nominal declaration, the diagnostic is anchored at the derive expression and identifies the target or hidden member that prevents construction of the canonical representation and `Iso`.

## Explicit recursive wiring

Recursive fields follow the same exact component-evidence rule. Ordinary recursive functions create deferred capability values through `Recursive[C]`, and local offers make those values available to the one-layer derive call. A conforming `defer` adapter returns a `C[T]` without invoking its thunk during construction. It may invoke the thunk while executing capability-specific operations.

For `Equal`, the adapter delays access to the underlying equality capability until a comparison occurs:

```lane
pub let recursive_equal : Recursive[Equal] = Recursive::{
  defer: fn[T](get_equal) {
    Equal::{
      equal: fn(left, right) {
        let equal = get_equal()
        equal.equal(left, right)
      },
    }
  },
}
```

For a recursive value behind a container, ordinary lifting constructs the exact field capability:

```lane
pub struct Tree {
  children : List[Tree]
}

fn build_tree_equal() -> Equal[Tree] {
  offer recursive_tree_equal : Equal[Tree] =
    recursive_equal.defer(fn() {
      build_tree_equal()
    })

  offer children_equal : Equal[List[Tree]] =
    list_equal_lift.lift(recursive_tree_equal)

  derive[Equal, Tree](deriver=derive_equal)
}

pub offer tree_impl_equal : Equal[Tree] =
  build_tree_equal()
```

Here `list_equal_lift` is an ordinary `Lift[Equal,List]` value. The recursive thunk may capture generic component evidence and a selected deriver as ordinary closure values.

Mutually recursive capabilities use a recursive function group. Each builder creates deferred capabilities whose thunks call the other builders, exposes the exact capabilities needed by its own derive expression as local offers, and derives one nominal layer.

`Recursive[C]` does not guarantee memoization or a fixed number of thunk invocations. A recursive operation may rebuild a capability layer each time it follows a recursive edge. Only capabilities that can return a `C[T]` without immediately forcing the thunk provide a `Recursive[C]` adapter.

## Elaboration

The compiler constructs deriver calls using these right folds:

```text
fields([])        = deriver.unit()
fields(f :: fs)   = deriver.product(deriver.field(info(f), evidence(f)), fields(fs))
record(T)         = deriver.record(info(T), iso(T), fields(T.fields))

payloads([])      = deriver.unit()
payloads(A :: as) = deriver.product(evidence(A), payloads(as))
variant(v)        = deriver.variant(info(v), payloads(v.payloads))
variants([])      = deriver.void()
variants(v :: vs) = deriver.sum(variant(v), variants(vs))
enumeration(T)    = deriver.enumeration(info(T), iso(T), variants(T.variants))
```

For `Geometry.Point`, the compiler selects `Product[Int,Product[Int,Unit]]`, constructs the corresponding `Iso`, and elaborates the capability composition conceptually to the expression below. `point_product_iso` denotes that compiler-generated ordinary `Iso[Point,Product[Int,Product[Int,Unit]]]` value.

```lane
derive_equal.record(
  TypeInfo::{
    name: "Point",
    qualified_name: "Geometry.Point",
  },
  point_product_iso,
  derive_equal.product(
    derive_equal.field(
      FieldInfo::{ name: "x" },
      int_impl_equal,
    ),
    derive_equal.product(
      derive_equal.field(
        FieldInfo::{ name: "y" },
        int_impl_equal,
      ),
      derive_equal.unit(),
    ),
  ),
)
```

The checked derive plan records the selected capability, normalized target, validated canonical ABI identities, deriver operand, and metadata. Its checked shape uniquely owns the canonical representation, every typed `Product`/`Sum` suffix, and the component evidence attached to each corresponding product step, forming the complete recipe for constructing the generated `Iso` without storing a generated expression tree. Lowering before Buslane only consumes that recipe to emit ordinary struct and enum construction, pattern matching, field access, closures, and function calls; it does not reconstruct the representation algebra.

## Evaluation

Evaluating a derive expression evaluates its selected deriver once and then evaluates the generated combinator calls using ordinary strict Lane semantics. A top-level derive expression runs during module initialization, while a derive expression inside a function runs on each execution of that expression.

The canonical `Product` and `Sum` values are ordinary values. Inlining and scalar replacement may eliminate their construction while preserving the ordinary value semantics described by the generated expression.

The runtime executes the lowered ordinary values, closures, constructors, matches, and calls.
