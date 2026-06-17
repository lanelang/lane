# Primitive literal exhaustiveness

Lane2 match exhaustiveness treats primitive literal patterns according to the primitive type's inhabitant set. `Bool` and `Unit` can be exhausted by covering all primitive inhabitants, while `Int` and `String` literal patterns require a wildcard or binding fallback because their inhabitant sets are not finitely enumerable in v1.
