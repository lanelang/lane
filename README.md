# Lane

This repository contains the core Lane implementation workspace.

## Modules

- `modules/buslane`: Buslane typed core language, verifier, interpreter, and pretty printer.
- `modules/lanec`: Lane compiler frontend and lowering pipeline.
- `modules/lane`: native command line tool, including the `lane lsp` language server subcommand.

## Fixtures

- `examples/valid`: Lane programs that should be accepted.
- `examples/invalid`: Lane programs that should be rejected.
- `examples/fixtures`: manifests for tool-level fixture checks.

Run the workspace checks from the repository root:

```sh
moon check --target native --warn-list +73
moon fmt --check
moon test --target native
moon build --target native --release modules/lane
lane_bin="$PWD/_build/native/release/build/Milky2018/lane/lane.exe"
(cd basic && LANE_BIN="$lane_bin" ./test.sh)
tools/check-lane-run-examples.sh \
  "$PWD/_build/native/release/build/Milky2018/lane/lane.exe"
```

The final three commands build one release `lane.exe`, run the complete pinned
Basic suite, and run the examples against that exact executable.

The repository CI initializes the pinned `basic` submodule recursively. Do not
set `LANE_HOME` or `LANE_SMOKE_BIN` globally for these checks; the examples
checker supplies both values only to its child process.
