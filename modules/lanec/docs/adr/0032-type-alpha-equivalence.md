# Type alpha-equivalence

Lane2 type equality treats `Forall` types as alpha-equivalent when they differ only by bound type parameter identities or display names. Implementations may keep stable type parameter identities for diagnostics, but equality must compare bound parameters through a binder mapping while free type parameters remain identity-based.
