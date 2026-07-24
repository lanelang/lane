# Recursive Generic Derivation in GHC and Scala 3

This note compares how GHC.Generics and Scala 3 Mirrors support recursive
`Eq`/`Show`-style derivation. It is background research for Lane's proposed
one-layer `Shape[T]`; it is not a Lane design decision.

## Summary

Neither system recursively embeds the complete generic representation or the
derived capability of every child inside its structural evidence.

- GHC's `Generic` representation is a one-layer sum of products. A recursive
  field remains an ordinary `K1` field containing the recursive source type.
  A generic consumer requests the target class for that field through normal
  type-class resolution. GHC's solver can tie a lazy recursive dictionary knot.
- Scala's `Mirror` records one layer of element types and labels. A derivation
  implementation summons the target type class for product fields. The
  reference implementation delays the child-instance collection with a
  `lazy val` and passes it by name, so a recursive field can refer back to the
  generated root given without eagerly expanding forever.

The reusable structural lesson is therefore not “make Shape recursively contain
Shape”. Both systems keep structural evidence one-layer and resolve field
capabilities separately. Their lazy evidence fixed points are one possible
recursion strategy, not a requirement that Lane must copy.

## GHC.Generics

### Representation

`Generic` associates a source type with a sum-of-products `Rep` and bidirectional
`from`/`to` conversions. In GHC's official `UserTree` example, fields of type
`UserTree a` appear as `K1 R (UserTree a)`; their representations are not
expanded recursively, and no child `Generic` dictionary is stored in `Rep`.
[`Generic` and the generated `UserTree` representation][ghc-rep]

`Generic1` can distinguish the parameter (`Par1`), a recursive occurrence of
the represented type constructor (`Rec1`), and composition (`:.:`). These are
typed representation wrappers, not recursively embedded `Generic1` evidence.
[`Generic1`, `Rec1`, and composition][ghc-generic1]

### Where recursion happens

A generic consumer defines cases for the representation constructors. GHC's
serialization example gives the field case the constraint `Serialize a`:

```haskell
instance Serialize a => GSerialize (K1 i a) where
  gput (K1 x) = put x
```

The generic default then calls `gput . from`, and the recursive tree instance is
written with only its external parameter constraint:

```haskell
instance Serialize a => Serialize (UserTree a)
```

Thus a recursive field re-enters the ordinary `Serialize (UserTree a)`
instance; `Generic` itself does not recursively derive another representation.
[`GSerialize` and generic defaults][ghc-consumer]

GHC's solver explicitly supports such recursive dictionaries. It caches the
result of applying a top-level instance before solving that instance's
prerequisites. A later identical wanted constraint can reuse the cached
dictionary, producing a recursive binding. This is sound only because the
instance dictionary function immediately returns a dictionary constructor that
is lazy in its arguments. [GHC source, `Note [Solved dictionaries]`][ghc-solved]

The same source note gives a container-recursive example:

```haskell
data D r = ZeroD | SuccD (r (D r))
instance Eq (r (D r)) => Eq (D r)
```

Solving `Eq (D [])` asks for `Eq [D []]`; the list instance asks again for
`Eq (D [])`; the solver closes that final wanted with the dictionary already
being constructed. [GHC source, `Note [Example of recursive dictionaries]`][ghc-example]

Consequently:

- direct recursion uses the instance currently being constructed;
- recursion under a container composes through the container's ordinary
  instance;
- mutual recursion can form the same kind of multi-dictionary knot across the
  ordinary instances for the participating types. This last point follows from
  the one-layer field representation and the general solved-dictionary
  mechanism; GHC's cited example demonstrates a cycle through a container
  rather than a dedicated two-datatype example.

GHC still restricts instance declarations with the Paterson conditions, under
which each instance reduction gets structurally smaller. Derived instances are
subject to the same rules. `UndecidableInstances` lifts those checks and can
permit type-checker nontermination. [GHC instance termination rules][ghc-termination]
These compile-time rules do not guarantee that comparing or showing an
infinite runtime value terminates.

## Scala 3 Mirrors

### Representation

The compiler generates `Mirror.Product` or `Mirror.Sum` evidence with associated
types for the mirrored type, one tuple of element types, the type label, and one
tuple of element labels. Products expose `fromProduct`; sums expose `ordinal`.
The element types are in declaration order, and there is no separate recursive
HList/coproduct representation. The Mirror contains structural information,
not `Eq`/`Show` evidence for its children. [Scala 3 `Mirror` reference][scala-mirror]

A `derives Eq` clause creates an ordinary generated given whose body calls
`Eq.derived`; for the official recursive `Tree[T]` example, the generated
signature requires only `Eq[T]`. [Scala 3 derivation translation][scala-translation]

### Where recursion happens

The official low-level implementation collects `Eq` instances for
`MirroredElemTypes`. It recursively derives the product Mirrors for sum cases,
but product fields use `summonInline[Eq[Field]]`. A field that refers back to
the root therefore summons the generated root given instead of recursively
expanding `Eq.derived` for the root again. [Scala 3 low-level derivation][scala-derived]

The implementation deliberately declares the child-instance list as `lazy` and
passes it by name to the sum/product consumers. The reference explicitly says
this is necessary to avoid infinite recursion and shows the generated code for
a recursive list ADT containing `summon[Eq[Lst[T]]]`.
[Scala 3 recursive derivation example][scala-recursive]

The same composition applies to other recursive shapes:

- for `children: List[Node]`, field lookup summons `Eq[List[Node]]`; a normal
  list given can in turn require the generated `Eq[Node]`;
- for mutually recursive `A` and `B`, each field lookup can summon the other
  generated given;
- the delayed child-instance table prevents eager dictionary construction from
  traversing those cycles before an operation uses the relevant field.

These two cases are consequences of the documented algorithm, not separate
Mirror features. The algorithm also includes an explicit
`"infinite recursive derivation"` error for an inline derivation path that
would expand the same type again, so arbitrary recursive derivation is not
accepted merely because a Mirror exists. For more general recursive implicit
synthesis, Scala provides by-name context parameters; their search algorithm
can synthesize a local recursive given when the recursive reference occurs
under another by-name request. [Scala 3 by-name context parameters][scala-by-name]

Like GHC, Scala's mechanism makes finite recursive values practical but does
not make operations on cyclic or infinite runtime values terminate.

## Implication for Lane

The common structural model supports these conclusions:

1. `Shape[T]` can describe exactly one nominal layer and leave every field at
   its original type.
2. Folding a field can request ordinary `F[Field]` evidence; a container field
   can therefore compose through an ordinary provider such as
   `F[A] -> F[List[A]]`.
3. Recursive construction needs an explicit semantic boundary somewhere, but
   it need not be a lazy contextual dictionary. Lane's subsequent design in
   [ADR 0120][lane-adr] makes recursion a Shape Algebra operation
   `fix : ((F[T]) -> F[T]) -> F[T]`. An Equal algebra can implement it with a
   recursive comparison worker, while a Schema algebra can use reference
   nodes.
4. Under that design, the resulting `F[T]` remains an ordinary standalone
   value. Contextual resolution neither changes it to a thunk nor synthesizes a
   universal lazy fixed point.

[ghc-rep]: https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/generics.html#deriving-representations
[ghc-generic1]: https://ghc.gitlab.haskell.org/ghc/doc/libraries/base-4.22.0.0-inplace/GHC-Generics.html#the-generic1-class
[ghc-consumer]: https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/generics.html#writing-generic-functions
[ghc-solved]: https://downloads.haskell.org/ghc/9.0.1/docs/html/libraries/ghc-9.0.1/src/GHC-Tc-Solver-Monad.html
[ghc-example]: https://downloads.haskell.org/ghc/9.0.1/docs/html/libraries/ghc-9.0.1/src/GHC-Tc-Solver-Monad.html
[ghc-termination]: https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/instances.html#instance-termination-rules
[scala-mirror]: https://docs.scala-lang.org/scala3/reference/contextual/derivation.html#mirror
[scala-translation]: https://docs.scala-lang.org/scala3/reference/contextual/derivation.html#exact-mechanism
[scala-derived]: https://docs.scala-lang.org/scala3/reference/contextual/derivation.html#how-to-write-a-type-class-derived-method-using-low-level-mechanisms
[scala-recursive]: https://docs.scala-lang.org/scala3/reference/contextual/derivation.html#how-to-write-a-type-class-derived-method-using-low-level-mechanisms
[scala-by-name]: https://docs.scala-lang.org/scala3/reference/contextual/by-name-context-parameters.html
[lane-adr]: ../adr/0120-library-defined-custom-derivation-through-shape.md
