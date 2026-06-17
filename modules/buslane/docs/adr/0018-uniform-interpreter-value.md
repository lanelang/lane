# Uniform interpreter value

Lane2's reference interpreter uses a uniform interpreter value representation for primitives, nominal data, closures, and builtins rather than introducing unboxed primitive special cases. This keeps the interpreter focused on defining semantics while allowing later bytecode, native, WebAssembly, or JavaScript execution targets to choose optimized layouts.
