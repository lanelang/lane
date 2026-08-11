# Lane Wasm

Lane Wasm is the browser host adapter for compiler-owned executable IR
exploration.

## Language

**Lane Wasm**:
The wasm-hosted adapter that exposes the same compiler exploration workflow as
the native Lane Command.
_Avoid_: browser compiler fork, execution engine

**Website IR Explorer**:
A browser interface that supplies an in-memory source set, selects an entry,
and presents an Explore Report.
_Avoid_: runtime debugger, filesystem workspace

**Explorer JSON**:
The versioned request and response representation for entry enumeration and
Explore Reports.
_Avoid_: canonical IR syntax, HTML report

**Explore Function Graph**:
The schema-version-2 set of stage-local function nodes and explicit
transformation-owned lineage edges.
_Avoid_: function-index arithmetic, rendered-name correlation

**Explorer Streaming ABI**:
The physical wasm boundary that transfers Explorer JSON in byte chunks through
host callbacks.
_Avoid_: semantic compiler API, fixed whole-report buffer

**Explorer Transport State**:
Temporary request and response state whose lifetime is limited to transport and
does not define a semantic compilation session.
_Avoid_: compiler workspace, execution instance

**Explorer JavaScript Wrapper**:
The browser helper that performs chunk transfer and UTF-8 conversion around the
Explorer Streaming ABI.
_Avoid_: compiler implementation, language server
