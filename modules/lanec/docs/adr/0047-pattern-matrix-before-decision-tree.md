# Pattern matrix before decision tree

Superseded in part by ADR-0053. Lane2 uses a pattern matrix as the semantic model for exhaustiveness and usefulness checking, then lowers checked source patterns before Buslane. Buslane uses one-level matches rather than preserving source-shaped checked patterns, and decision trees remain reserved for later execution IR or bytecode VM work.
