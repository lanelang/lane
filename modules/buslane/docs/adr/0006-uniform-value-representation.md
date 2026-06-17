# Uniform value representation for v1 execution

Lane2 v1 execution targets use a uniform value representation and share generic function code instead of monomorphizing generic functions by type argument. This matches runtime type erasure and keeps the reference interpreter and portable bytecode VM simple; later optimized native, WebAssembly, or JavaScript targets may add monomorphization as a lowering strategy without changing Buslane semantics.
