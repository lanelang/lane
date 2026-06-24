# Open candidate sets and operator names

Status: superseded by ADR-0052

Lane2 allows repeated names contributed by `open` and `let open` to form candidate sets that are resolved at use sites, while ordinary value bindings in the same scope remain unique. Operator syntax resolves through fixed ordinary operation names such as `op_add` rather than through compiler-recognized operation structs, so `+` follows the same candidate selection rules as `op_add`; `&&` and `||` only add their special right-hand-side thunking during lowering. This replaces anonymous preopen values with named open bindings, keeps ambiguity visible instead of choosing defaults, and preserves operation structs such as `Add[T]` as standard-library/API conventions rather than trait-like lookup machinery.
