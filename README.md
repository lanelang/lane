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
tools/check-lane-integration.sh
```

The integration gate builds `lane.exe` once, then runs the examples/Basic and
LSP CLI checkers against that exact executable. The two checkers can also be
run independently by passing an existing `lane.exe` path to
`tools/check-lane-run-examples.sh` or `tools/check-lane-lsp-cli.sh`.

The repository CI initializes the pinned `basic` submodule recursively. Do not
set `LANE_HOME` or `LANE_SMOKE_BIN` globally for these checks; the integration
gate supplies both values only to the examples checker process.
