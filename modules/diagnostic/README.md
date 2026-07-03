# MoonBit Diagnostic Reporting

Structured diagnostics for MoonBit compilers, language servers, and static
analysis tools.

## Packages

- `Milky2018/diagnostic/core`: diagnostic data model, labels, spans,
  suggestions, and edits.
- `Milky2018/diagnostic/source`: source database and offset-to-position mapping.
- `Milky2018/diagnostic/render`: Rust-like CLI snippet renderer and test
  helpers.
- `Milky2018/diagnostic/json`: structured JSON export.
- `Milky2018/diagnostic/lsp`: LSP diagnostic and quick-fix JSON conversion.

## Example

```mbt
let sources = @source.SourceDatabase::SourceDatabase()
let source = sources.add("import Builtins.{\n  int_add,\n}", path="ops.lane")
let diagnostic = @core.Diagnostic::error(
  "missing imported module `Builtins`",
  code="E4002",
  labels=[
    @core.Label::primary(
      sources.span(source, 7, 15),
      message="no interface artifact was provided for this module",
    ),
  ],
  notes=["Lane does not search the file system by module name"],
  helps=["pass the interface explicitly: `lane compile ops.lane -i builtins.lmi`"],
)
let text = @render.render_for_test(diagnostic, sources)
```

CLI rendering is intentionally separate from JSON and LSP conversion. Projects
should construct `Diagnostic` values and choose a renderer at the boundary.
Terminal color is also a boundary decision: CLI tools may enable ANSI color
after checking their own terminal policy, but JSON and LSP diagnostics must
remain color-free structured data.
