# Runtime error reports

Lane2 execution targets report interpreter and builtin-plugin failures through runtime error reports rather than panicking, but these reports are not Lane2 language-level exceptions. Unknown builtins, arity mismatches, representation mismatches, and plugin-defined failures are useful for tools and tests while incorrect unsafe builtin use remains outside Lane2's safety guarantee.
