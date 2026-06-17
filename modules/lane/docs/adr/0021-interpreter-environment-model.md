# Interpreter environment model

Lane2's reference interpreter separates global environment, call frames, and closure environments. This keeps top-level initialization, function calls, local ANF bindings, match binders, and captured lexical variables distinct while using symbol identities for lookup, and it gives the later bytecode VM a compatible conceptual model for frames and closures.
