# Separated symbol identities

Lane2 compiler IR uses distinct symbol identity wrapper types for separated namespaces such as type, value, field, and variant symbols rather than a single kind-tagged universal symbol id. This mirrors the language's separated namespaces and lets the MoonBit type checker catch accidental cross-namespace use, while sum types can still be introduced where a genuinely heterogeneous symbol reference is needed.
