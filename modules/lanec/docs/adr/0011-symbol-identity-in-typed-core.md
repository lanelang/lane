# Symbol identity in typed core

Lane2 resolved AST preserves source names for diagnostics but attaches stable symbol identities to resolved references, and typed core uses those identities rather than raw name strings or a pure de Bruijn representation. This avoids ambiguity from shadowing, contextual resolution, and contextual forwarding while keeping implementation and pretty-printing simpler than a de Bruijn-only core; display names and source spans remain available for diagnostics.
