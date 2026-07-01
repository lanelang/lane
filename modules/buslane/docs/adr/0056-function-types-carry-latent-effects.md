# Function Types Carry Latent Effects

Buslane function types carry a latent effect as part of the core type shape, matching the Lane effect model rather than treating effects as a verifier-only side table. Existing pure functions migrate to the same function type form with the empty effect, so there is one function type constructor instead of separate pure and effectful function type variants.

## Consequences

- Buslane type equality, pretty printing, text parsing, verification, lowering, and interpretation must treat function latent effects as part of the function type.
- Pure functions remain the common case, but purity is represented by an empty latent effect rather than by omitting the effect field.
