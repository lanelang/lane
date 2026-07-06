# Lane Wasm

Lane Wasm is the browser-facing Lane tool surface for exploring compiler and
core-language artifacts from a page.

## Language

**Lane Wasm**:
The wasm-hosted Lane tool surface for page-driven inspection workflows.
_Avoid_: Lane Module, Lane Command, LSP server

**IR Explorer**:
A page-driven inspection workflow that turns Lane source input into readable
intermediate representations.
_Avoid_: compiler front end, command-line runner, language server

**Single-File IR Exploration**:
An **IR Explorer** mode that inspects exactly one Lane **Source File** without
library inputs or project discovery.
_Avoid_: project explorer, workspace compilation, multi-module explorer

**Explorer Source**:
The complete Lane **Source File** submitted to **Single-File IR Exploration**.
_Avoid_: anonymous snippet, synthetic module, partial source

**IR Pane**:
A named display-ready text view produced by **Single-File IR Exploration**.
_Avoid_: stable IR JSON schema, compiler artifact, editor diagnostic

**Explorer Diagnostic**:
A compiler diagnostic returned as part of a normal **IR Explorer** result.
_Avoid_: wasm exception, API failure, JavaScript error

**Explorer Overflow**:
An **Explorer Arena** capacity failure reported to the **Explorer JavaScript
Wrapper** without trapping the wasm instance.
_Avoid_: compiler diagnostic, wasm trap, silent truncation

**Explorer JSON**:
The JSON request and response format used by the **IR Explorer**.
_Avoid_: MoonBit ABI, stable IR JSON schema, internal compiler object

**Explorer Byte Buffer ABI**:
The wasm1 import/export boundary that moves UTF-8 encoded **Explorer JSON**
between JavaScript and **Lane Wasm** through linear memory.
_Avoid_: direct String ABI, wasm-gc string interop, JavaScript object ABI,
per-byte accessor protocol

**Explorer Arena**:
A fixed-size linear-memory region used by the **Explorer Byte Buffer ABI** for
one-at-a-time request and response buffers.
_Avoid_: general allocator, concurrent session storage, unbounded output buffer

**Explorer JavaScript Wrapper**:
The JavaScript helper that encodes **Explorer JSON** into the **Explorer Byte
Buffer ABI** and decodes the result back into JavaScript strings or objects.
_Avoid_: compiler API, language server, MoonBit runtime

## Relationships

- **Lane Wasm** supports the **IR Explorer** workflow.
- **Single-File IR Exploration** is the first supported **IR Explorer** mode.
- An **Explorer Source** must contain a **Module Declaration**.
- The first **IR Explorer** panes are checked source, Buslane core, and
  Buslane ANF.
- **Explorer Diagnostics** do not prevent returning earlier available **IR
  Panes**.
- **Lane Wasm** reports compilation failure as an **IR Explorer** result rather
  than as a wasm exception.
- **Explorer Overflow** is reported as a wrapper-handled fallback failure rather
  than as a wasm trap.
- **Explorer JSON** is the semantic API format for **Single-File IR
  Exploration**.
- **Explorer Byte Buffer ABI** is the physical wasm1 boundary for **Explorer
  JSON**.
- **Explorer Arena** is the first memory model for the **Explorer Byte Buffer
  ABI**.
- **Explorer JavaScript Wrapper** owns UTF-8 encoding and decoding across the
  **Explorer Byte Buffer ABI**.
- **Lane Wasm** is separate from the native **Lane Command**.
- **Lane Wasm** consumes compiler and core-language artifacts without becoming
  a Lane source-language **Module**.

## Example dialogue

> **Dev:** "Should the page call the Lane Command to inspect IR?"
> **Domain expert:** "No — the **IR Explorer** belongs to **Lane Wasm**, while
> the **Lane Command** remains the native command-line surface."
