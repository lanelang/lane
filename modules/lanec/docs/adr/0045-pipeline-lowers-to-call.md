# Pipeline lowers to call

Lane2 typed core does not preserve pipeline expressions. Semantic lowering rewrites `value |> call` into an ordinary first-class call with `value` passed as the first argument, so pipeline remains source-level syntax rather than a core or runtime construct.
