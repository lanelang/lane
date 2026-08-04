# Capture-Rejecting Core Substitution

Lane source type-level beta reduction has the ordinary capture-avoiding
semantics. Buslane represents binders with `TypeParameterId`, and one identity
denotes one logical binder throughout a program. A producer must not reuse an
identity for distinct binders that can meet through generic instantiation or
beta reduction.

Buslane substitution is therefore simultaneous and capture-rejecting. When a
replacement has a free parameter whose identity equals a binder crossed by the
substitution, the operation reports `CapturedTypeParameter`. The verifier turns
that refusal into a blocking invalid-IR diagnostic. It is a backstop for a
broken producer freshness invariant, not a source-language restriction.

For Buslane programs produced by `lanec`, capture-rejecting substitution is
observationally equivalent to capture-avoiding substitution: source binders are
allocated as distinct identities before lowering, so the rejection case is
unreachable. Repeated occurrences of one identity may quote the same logical
binder in related metadata and implementation types; they do not introduce a
second binder entity.

This decision keeps semantic queries pure. Substitution and normalization do
not allocate into `MetadataRegistry`, and normalized types never contain
unregistered synthetic identities. Alpha-equivalence remains responsible for
comparing consistently renamed binders; it does not repair invalid identity
reuse while substituting.

Rejected alternatives:

- Allocate fresh metadata identities during normalization. Equality and
  consumability queries would mutate their input registry, making results
  depend on query order.
- Emit normalization-local synthetic identities. A Buslane binder's kind and
  effect flavor live in `MetadataRegistry`; an unregistered identity would not
  be a well-formed Buslane type at the next verifier boundary.
- Treat capture rejection as an unsupported Lane program. The source calculus
  is capture-avoiding, so reaching this case is a compiler or hand-authored IR
  defect.
