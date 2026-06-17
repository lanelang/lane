# No required TCO in v1

Lane2 v1 does not require tail-call optimization from the reference interpreter. Tail-call optimization remains a future execution-target optimization for lowered IR or bytecode VM design, and the v1 language should not promise tail-recursive space behavior before that execution model is specified.
