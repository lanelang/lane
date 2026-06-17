# Bidirectional local type inference

Lane2 uses bidirectional local type inference rather than Hindley-Milner-style global inference. Type information may be synthesized upward or checked downward between adjacent syntax nodes, generic binders remain explicit, polymorphic calls may instantiate type arguments locally, and the checker does not infer a binding's type from later uses.
