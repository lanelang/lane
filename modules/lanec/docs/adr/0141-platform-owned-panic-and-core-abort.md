---
status: accepted
---

# Platform-owned panic and core abort

Lane separates terminal control from diagnostic and process policy.

The compiler provides `%abort : () -> Basic.Data.Void.Void ! Panic`. Its
verified implementation is the fieldless `Fatal` terminator, which the sole
WebAssembly target emits as `unreachable`. The intrinsic introduces no host
import and carries no message or exit status.

Canonical Basic provides `panic : (String) -> Void ! { Io, Panic }`. The shipped
WASIP1 implementation writes the message to standard error, invokes
`proc_exit(1)`, and calls `%abort` as a static fallback if the host import
returns. `Io` therefore describes the external diagnostic write while `Panic`
describes possible irrecoverable termination.

This division lets another platform library define its own user-facing panic
policy without changing the language or compiler. It also keeps a direct abort
available for compiler and library invariants without falsely claiming that
every terminal path performs I/O.

`Fatal` remains distinct from ordinary unreachable code in VM CFG and the
Physical Program because it carries intentional-control provenance and has an
explicit ARC-final ownership rule. It is nevertheless fieldless and has the
same final WebAssembly instruction.

Changing intrinsic tag 18 from message-carrying `%panic` to parameterless
`%abort` changes the persisted module-object language. The module-object schema
advances from 27 to 28, and schema 27 is rejected.

This ADR supersedes the current-contract portions of ADR 0131 and ADR 0140 and
the former compiler-owned panic policy. Historical migrations described by
those ADRs remain historical facts.
