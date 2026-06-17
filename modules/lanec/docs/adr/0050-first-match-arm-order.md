# First-match arm order

Lane2 match evaluation uses source-order first-match semantics. Semantic analysis rejects unreachable arms, but the reference interpreter still evaluates checked arms in order, and later decision-tree lowering must preserve the same first-match behavior.
