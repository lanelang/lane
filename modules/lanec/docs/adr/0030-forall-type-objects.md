# Forall type objects

Lane2 checked type objects use an explicit `Forall` type constructor for polymorphism instead of storing type parameters directly on function types. Generic function type syntax such as `[A](A) -> A` elaborates to `Forall([A], Function([A], A))`, which keeps rank-n types expressible in the future and leaves room for higher-kinded type parameters while v1 can restrict kinds to `Type`.
