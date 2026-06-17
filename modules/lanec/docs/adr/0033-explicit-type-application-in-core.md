# Explicit type application in core

Lane2 typed core preserves explicit type application nodes for instantiating polymorphic values, even though type arguments are erased before execution. Keeping instantiation visible in typed core supports diagnostics, pretty printing, rank-n polymorphism, and a clear boundary between type checking and runtime type erasure.
