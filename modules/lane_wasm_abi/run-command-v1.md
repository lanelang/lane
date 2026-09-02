# Lane Runtime V1: Run Command

Lane Runtime V1 uses two Core WebAssembly host imports with blocking guest
semantics. `lane_runtime_v1.run_command` executes an executable directly with a
structured argument vector and captures its output. It never parses a shell
command and never invokes a shell implicitly. `lane_runtime_v1.take_command_output`
copies one completed command's captured bytes into guest memory.

The Basic wrapper is the guest-side encoder for this protocol. Runtime hosts
consume the catalog decoder and wire projections; they do not independently
choose import identities, function types, status codes, or response tags.

Its source-facing Lane contract is:

```lane
(WasmAddress, I32, WasmAddress) -> I32 ! Io
```

After projecting both guest addresses, its Core Wasm type is:

```text
(i32, i32, i32) -> i32
```

The parameters are the request address, request byte length, and address of a
20-byte response record. Both addresses borrow guest memory while the Wasm
invocation is parked and only until the host call returns. Standard input is
read from the request frame. Standard output and standard error are captured
separately.

The output-transfer source contract is:

```lane
(I32, WasmAddress, I32) -> I32 ! Io
```

Its Core Wasm type is `(i32, i32, i32) -> i32`. The parameters are the output
handle, destination address, and exact combined output length.

## Request frame

Every integer is a signed little-endian `i32`. String and table offsets are
relative to the start of the request frame.

| Offset | Field |
| ---: | --- |
| 0 | Flags; bit 0 means inherit the host environment |
| 4 | Executable UTF-8 offset |
| 8 | Executable byte length |
| 12 | Argument table offset |
| 16 | Argument count |
| 20 | Working-directory UTF-8 offset, or `-1` when absent |
| 24 | Working-directory byte length; zero when absent |
| 28 | Environment table offset |
| 32 | Environment entry count |
| 36 | Standard-input byte offset |
| 40 | Standard-input byte length |

Each argument-table entry contains an offset followed by a byte length. Each
environment-table entry contains key offset, key length, value offset, and
value length. Environment entries are applied in order; a later entry replaces
an earlier entry with the same platform environment-key identity.

The executable must be non-empty. A present working directory must be
non-empty. Every string must be valid UTF-8 and contain no NUL byte.
Environment keys must additionally be non-empty and contain no `=`. Unknown
flag bits, negative counts, truncated tables, and out-of-frame ranges make the
request invalid.

## Result

The import result classifies the host operation:

| Value | Meaning |
| ---: | --- |
| 0 | The process terminated; the response record is initialized |
| 1 | Invalid request frame |
| 2 | Executable not found |
| 3 | Permission denied |
| 4 | Other host process failure |

On success, the response record contains:

| Offset | Field |
| ---: | --- |
| 0 | Termination tag: 0 for exit, 1 for signal |
| 4 | Exit code or signal number |
| 8 | Output handle |
| 12 | Standard-output byte length |
| 16 | Standard-error byte length |

Windows does not produce the signal form. The guest allocates exactly the sum
of the two output lengths and calls `take_command_output`. The host writes
standard output followed immediately by standard error. A successful transfer
consumes the handle; an unknown handle, an incorrect length, or an out-of-range
destination returns `InvalidRequest`. A host retains no guest-memory address
after either import returns.

The guest call completes only after the child terminates, but the host process
operation suspends the Wasm continuation or JIT native fiber instead of
blocking the host thread. Cancelling the surrounding host task cancels the
child process through structured concurrency.
