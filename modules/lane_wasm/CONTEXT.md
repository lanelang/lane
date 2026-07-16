# Lane Wasm

Lane Wasm is the wasm-hosted compiler bridge intended for a website-based Lane IR Explorer.

## Language

**Lane Wasm**:
The browser-compatible host adapter for compiler-owned Artifact Entry Enumeration and Executable IR Exploration.
_Avoid_: independent compiler pipeline, Lane Command, language server, execution engine

**Website IR Explorer**:
The page-driven interface that submits an Explore Source Set, enumerates artifact-defined entries, selects one entry, and presents the resulting Explore Report.
_Avoid_: compiler front end, native command wrapper, runtime debugger

**Explorer JSON**:
The JSON encoding of Artifact Entry Enumeration requests and the versioned Explore Report Protocol.
_Avoid_: stable IR syntax, compiler debug object, HTML report

**Explorer Streaming ABI**:
The wasm1 boundary that transfers UTF-8 Explorer JSON through bulk request-read and response-write callbacks instead of placing a complete request or response in a fixed linear-memory arena.
_Avoid_: direct String ABI, wasm-gc string interop, fixed whole-report arena, per-byte accessor protocol

**Explorer Transport State**:
Temporary request, response, or chunk state used by the Explorer Streaming ABI. The public result of a request depends only on that request even when an implementation retains bounded transport state or reusable internal caches.
_Avoid_: execution instance, semantically stateful compilation session, fixed report buffer

**Explorer JavaScript Wrapper**:
The website helper that supplies request chunks, consumes response chunks, and performs UTF-8 encoding and decoding around the Explorer Streaming ABI.
_Avoid_: compiler API, language server, MoonBit runtime

## Relationships

- Lane Wasm and the native Lane Command consume the same `lanec/driver` orchestration, Explore Stage order, diagnostics, and Partial Explore Report semantics.
- The website supplies a complete in-memory Explore Source Set; Lane Wasm does not discover project files.
- Artifact Entry Enumeration returns the root module artifact's existing entries and does not define a second entry model.
- The website selects an entry before requesting an Explore Report.
- Lane Wasm generates the same compiler and backend snapshots as `lane explore`, including Wasm text produced by the Pure Wasm Compiler Package.
- Lane Wasm does not load, instantiate, JIT-compile, or execute the generated Wasm module.
- Explorer JSON is the semantic website API; the Explorer Streaming ABI is its physical wasm1 transport.
- Streaming chunks are byte sequences and may split UTF-8 code points; the JavaScript wrapper decodes only the assembled response stream.
- Transport or callback failure never turns a truncated response into a successful Explore Report.
- Lane Wasm remains separate from the native Lane Command and does not become a Lane source-language module.

## Example dialogue

> **Dev:** "Does the website need its own compiler pipeline?"
> **Domain expert:** "No. Lane Wasm hosts the same compiler-owned exploration workflow as the Lane Command and differs only in input and output transport."
