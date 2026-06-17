# Separate type parameter identities

Lane2 separates nominal type symbols from type parameter identities. Declared struct and enum constructors use nominal type symbols with arity and data metadata, while generic binders introduce type parameter identities that participate in type checking and are erased before execution.
