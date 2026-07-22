# Offeredness is binding metadata

Lane models contextual offeredness as metadata on a named value binding rather than as a separate declaration kind. Function and immutable-value definitions retain their own binding kind and carry `is_offered`; an offered function therefore exports, resolves, and diagnoses the same symbol as its ordinary function value. This rejects both a synthetic hidden offer binding and a sequential `Function` plus `Offer` expansion, which would introduce a second identity or make recursively visible offered functions depend on declaration ordering.

## Consequences

- `offer fn` follows function scope: top-level functions participate in the unordered recursive function group, while local functions become visible sequentially and are self-recursive.
- Offeredness alone is not a use and does not suppress unused-binding diagnostics.
- Generic functions are offered by their complete forall type; contextual resolution does not specialize them while matching an offer.
- Module interfaces preserve function kind and offeredness independently. The interface artifact schema is raised to 4 because the serialized value record now carries offeredness.
