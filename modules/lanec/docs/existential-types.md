# Existential Types

This document records the current Lane design direction for existential
types. It is a design note, not an implemented language feature.

## Goal

Lane supports universal type parameters and existential type parameters as
separate concepts.

Universal parameters are chosen by the user of a type constructor:

```lane
enum Box[T] {
  box(T)
}

struct Box[T] {
  val : T
}
```

The type of a value keeps the chosen parameter, such as `Box[Int]`.

Existential parameters are chosen by the constructor or provider and hidden
from the consumer:

```lane
enum Hide {
  hide[T](T)
}

struct Hide {
  type T : Type
  val : T
}
```

The type of a value is just `Hide`; the chosen `T` is hidden until the value is
eliminated.

## Non-Goals

Existential type members are not ordinary value fields.

Lane does not need dependent types for this feature. In particular, this
design does not introduce arbitrary term-dependent types, runtime typecase, or
general type projection from expressions.

The following are not part of this design:

```lane
h.T
(if c { h1 } else { h2 }).T
```

Hidden types are exposed only by pattern-based elimination.

## Existential Enum Constructors

An enum variant may bind type parameters that do not appear on the enum type
itself:

```lane
enum Hide {
  hide[T](T)
}
```

Construction chooses a witness type:

```lane
let h : Hide = Hide::hide[Int](5)
```

Pattern matching opens the hidden type:

```lane
match h {
  Hide::hide[T](val) => body
}
```

Inside the arm, `T : Type` is available in the type environment and
`val : T` is available in the value environment. `T` is abstract; the arm must
not assume it is `Int` unless the value was already refined by some separate
static mechanism.

## Existential Structs

Structs may declare type members before value fields:

```lane
struct Hide {
  type T : Type
  val : T
}
```

This is the codata/interface-oriented form of an existential package. The
provider chooses `T`; the consumer sees only `Hide`.

Construction supplies type-member witnesses with `=` and value fields with `:`:

```lane
let h : Hide = Hide::{ T = Int, val: 5 }
```

Elimination uses a struct pattern:

```lane
let Hide::{ T, val } = h
```

After this local item, `T : Type` is available in the type environment and
`val : T` is available in the value environment for the remaining scope.

Type members may be ignored when they are not needed:

```lane
let Hide::{ _, val } = h
```

The exact wildcard spelling is still open, but the operation must not expose a
usable hidden type name.

## Scope and Escape

Eliminating an existential introduces a fresh abstract type. The hidden type
must not escape the scope that opened it.

For a block-local elimination:

```lane
{
  let Hide::{ T, val } = h
  body
}
```

the result type of `body` must not mention `T`, unless `T` is packed again into
another existential before leaving the scope.

Allowed:

```lane
{
  let Hide::{ T, val } = h
  Hide::{ T = T, val: val }
}
```

Rejected:

```lane
{
  let Hide::{ T, val } = h
  val
}
```

The rejected block would have result type `T`, but `T` is hidden and cannot be
named outside the elimination scope.

## Higher Kinds

Type members carry explicit kinds. `type T : Type` is the first form, but the
syntax is intended to extend to higher kinds:

```lane
struct HideF {
  type F : Type -> Type
  val : F[Int]
}

let h : HideF = HideF::{ F = Option, val: Option::some(1) }

let HideF::{ F, val } = h
```

Inside the scope after elimination, `F : Type -> Type` and `val : F[Int]` are
available.

## Typing Rules

The core model is the usual existential package.

Formation:

```text
Delta, A : K |- T type
-------------------------------
Delta |- exists A : K. T type
```

Introduction:

```text
Delta |- S : K
Gamma |- v : T[S / A]
-----------------------------------------------
Gamma |- pack [S, v] as exists A : K. T
        : exists A : K. T
```

Elimination:

```text
Gamma |- e : exists A : K. T
Gamma, A : K, x : T |- body : R
A not free in R
------------------------------------------------
Gamma |- unpack e as [A, x] in body : R
```

Lane surface syntax maps to these rules:

```lane
Hide::{ T = Int, val: 5 }
```

is an existential introduction, and:

```lane
let Hide::{ T, val } = h
```

is an existential elimination over the remainder of the local scope.

## Design Boundary

Enums and structs expose hidden types differently but use the same underlying
existential idea.

Enum existentials are opened by variant patterns:

```lane
HideEnum::hide[T](val)
```

Struct existentials are opened by struct patterns:

```lane
Hide::{ T, val }
```

No hidden type is exposed by field access alone. A field whose type mentions a
hidden type cannot be safely used until the hidden type has been opened by a
pattern.
