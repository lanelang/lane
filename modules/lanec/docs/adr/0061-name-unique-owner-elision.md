# Name-unique owner elision

Lane permits omitting enum variant and effect operation owners only when the visible variant or operation namespace contains exactly one matching member name. After that symbol is selected, local type inference may instantiate the owner arguments and member-level witnesses, but expected value types, handled effects, payload types, and latent effects must not choose between same-name members.

This deliberately rejects overload-style disambiguation: `same(1)` remains ambiguous if two visible enum variants are named `same`, even when the expected result type would identify one owner. The same rule applies to effect operation calls and handler arms, so an unqualified `suspend![A](...)` can infer `Async[Schedule]` owner arguments only after `suspend` has already resolved to a unique operation symbol.
