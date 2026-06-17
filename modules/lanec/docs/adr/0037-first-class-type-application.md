# First-class type application in core

Lane2 typed core type application accepts any polymorphic atom as the callee rather than only known generic function symbols. This supports local generic functions, future rank-n polymorphism, and a clean `Forall` elimination form, while runtime type erasure and direct generic-call optimizations remain later lowering concerns.
