# Explicit-only contextual offers

Lane removes field-level contextual offer forwarding. A contextual offer is only an explicit offered value definition or an offered parameter. Struct fields cannot be marked with `offer`, and a value offered at type `Compare[T]` does not implicitly offer any field such as `Equal[T]`.

The removed forwarding rule made contextual resolution depend on hidden field paths. That caused surprising ambiguity: providing a `Compare[Int]` value could also provide `Equal[Int]`, so adding an explicit `Equal[Int]` offer could make `==` ambiguous instead of clearer. It also conflicted with the language model that contextual resolution is not trait instance search and only matches visible named offers by exact type equality.

`auto` and `offer` remain orthogonal. An `auto` parameter may be filled at a call site, but it is not available inside the function body for contextual resolution unless it is also marked `offer`. Code that directly uses both comparison and equality operations should request both capabilities explicitly, for example `auto offer compare : Compare[T]` and `auto offer equal : Equal[T]`.

Operation values may still contain ordinary fields that reuse other operation values internally. For example `Compare[T]` may store an `equal_impl : Equal[T]` field, but that field is an implementation detail of the `Compare[T]` value and is not a contextual offer.
