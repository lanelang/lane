# Primitive type constants

Lane2 represents `Int`, `Bool`, `String`, and `Unit` as primitive type constants in checked type objects rather than nominal type symbols. Their values are primitive inhabitants or literals, not enum variants or struct constructors, which keeps nominal data resolution, variant lookup, exhaustiveness checking, and primitive builtin dispatch distinct.
