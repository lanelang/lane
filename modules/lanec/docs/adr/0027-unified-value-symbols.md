# Unified value symbols

Lane2 uses a single value symbol identity for top-level values, function names, parameters, local bindings, local functions, and pattern binders. The value symbol metadata records what kind of value introduced the symbol, while function definitions may still have separate definition metadata; expressions refer to value symbols so first-class functions and ordinary values share the same namespace representation.
