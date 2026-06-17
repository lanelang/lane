# Runtime type erasure

Lane2 v1 has no runtime typecase, so generic type arguments are kept for type checking and diagnostics but erased before execution targets. This keeps the reference interpreter and future portable bytecode VM parametric and avoids requiring Idris-style runtime type constructors or implicit type evidence; reflection or dynamic typing can introduce explicit runtime evidence later if the language needs it.
