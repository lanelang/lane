# Lane Runtime V1: Run Command

`lane_runtime_v1.run_command` is a synchronous Core WebAssembly host import.
It executes an executable directly with a structured argument vector. It never
parses a shell command and never invokes a shell implicitly.

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

The parameters are the request address, request byte length, and address of an
eight-byte response record. Both addresses borrow guest memory only until the
host call returns. Standard input, output, and error are inherited from the
host running the Lane program.

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

On success, the response record contains a termination tag at offset 0 and its
code at offset 4. Tag 0 is normal exit and tag 1 is signal termination. Windows
does not produce the signal form.

The operation blocks until the child terminates. Output capture, process
handles, cancellation, and asynchronous execution are not part of this
interface.
