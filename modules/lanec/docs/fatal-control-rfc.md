# Fatal control boundary

Status: implemented

The compiler owns one platform-independent terminal intrinsic:

```lane
pub let abort : () -> Basic.Data.Void.Void ! Panic = builtin("%abort")
```

The ABI contract owns its complete shape:

```text
parameters = []
result = CanonicalBasicVoid
effect = Panic
implementation = Fatal
```

Intrinsic validation resolves the canonical Void identity once. Later phases
carry the verified contract and do not rediscover `%abort` by name or rebuild
its type.

`Fatal` is a fieldless VM CFG and Physical Program terminator. It has no
successor and abandons remaining owners in the current execution instance. The
WebAssembly target emits `unreachable` and no host import. `Fatal` is retained
as an IR fact because deliberate source terminal control and an unreachable
compiler path have different provenance even though both currently lower to
the same WebAssembly instruction.

The compiler does not define a user-facing panic policy. Canonical Basic builds
the shipped operation from platform APIs:

```lane
panic : (String) -> Void ! { Io, Panic }
```

Its WASIP1 implementation writes the message to standard error, calls
`proc_exit(1)`, and then calls `%abort` as a non-returning fallback. Thus `Io`
owns external output, `Panic` owns possible irrecoverable termination, and the
platform library owns presentation and exit policy.

There is no bottom type, implicit bottom conversion, Never result ABI,
no-return call opcode, or special representation for empty enums. Callers use
the ordinary Basic `absurd` eliminator when a fatal branch appears in another
value context.

Only the verified `%abort` implementation proves a path terminal. The `Panic`
effect alone does not: an arbitrary function carrying `Panic` may return
normally.
