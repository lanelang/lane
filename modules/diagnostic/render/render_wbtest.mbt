///|
fn sample_sources() -> (@source.SourceDatabase, @core.SourceId) {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add(
    (
      #|module Ops
      #|
      #|import Builtins.{
      #|  int_add,
      #|}
    ),
    path="ops.lane",
  )
  (sources, source)
}

///|
test "render single primary label with notes and helps" {
  let (sources, source) = sample_sources()
  let diagnostic = @core.Diagnostic::error(
    "missing imported module `Builtins`",
    code="E4002",
    labels=[
      @core.Label::primary(
        sources.span(source, 19, 27),
        message="no interface artifact was provided for this module",
      ),
    ],
    notes=["Lane does not search the file system by module name"],
    helps=[
      "pass the interface explicitly: `lane compile ops.lane -i builtins.lmi`",
    ],
  )
  inspect(
    render_for_test(diagnostic, sources),
    content=(
      #|error[E4002]: missing imported module `Builtins`
      #|  --> ops.lane:3:8
      #|   |
      #| 3 | import Builtins.{
      #|   |        ^^^^^^^^ no interface artifact was provided for this module
      #|   |
      #|  = note: Lane does not search the file system by module name
      #|  = help: pass the interface explicitly: `lane compile ops.lane -i builtins.lmi`
    ),
  )
}

///|
test "render multiline primary label and secondary label" {
  let (sources, source) = sample_sources()
  let diagnostic = @core.Diagnostic::error("bad import list", labels=[
    @core.Label::primary(
      sources.span(source, 19, 40),
      message="import starts here",
    ),
    @core.Label::secondary(
      sources.span(source, 32, 39),
      message="imported value appears here",
    ),
  ])
  inspect(
    render_for_test(diagnostic, sources),
    content=(
      #|error: bad import list
      #|  --> ops.lane:3:8
      #|   |
      #| 3 | import Builtins.{
      #|   |        ^^^^^^^^^^ import starts here
      #| 4 |   int_add,
      #|   | ^^^^^^^^^^
      #| 4 |   int_add,
      #|   |   ------- imported value appears here
      #|   |
    ),
  )
}

///|
test "render suggestions" {
  let (sources, source) = sample_sources()
  let diagnostic = @core.Diagnostic::error("missing semicolon", suggestions=[
    {
      message: "insert `;`",
      edits: [{ span: sources.span(source, 10, 10), replacement: ";" }],
      applicability: MachineApplicable,
    },
  ])
  inspect(
    render_for_test(diagnostic, sources),
    content=(
      #|error: missing semicolon
      #|  = suggestion: insert `;` (machine-applicable)
      #|    = edit: ops.lane:1:11-1:11 replace with `;`
    ),
  )
}

///|
test "render facts and related locations" {
  let (sources, source) = sample_sources()
  let diagnostic = @core.Diagnostic::error(
    "missing imported module `Builtins`",
    facts=[
      {
        name: "considered interface artifact",
        value: "declares module `builtins`",
        span: None,
      },
    ],
    related_locations=[
      { span: sources.span(source, 19, 27), message: "import requested here" },
    ],
  )
  inspect(
    render_for_test(diagnostic, sources),
    content=(
      #|error: missing imported module `Builtins`
      #|  = considered interface artifact: declares module `builtins`
      #|  = related: ops.lane:3:8: import requested here
    ),
  )
}

///|
test "render labels from multiple source files" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let left = sources.add("let left = right", path="left.lane")
  let right = sources.add("pub let right = 1", path="right.lane")
  let diagnostic = @core.Diagnostic::error("cross-file mismatch", labels=[
    @core.Label::primary(sources.span(left, 4, 8), message="used here"),
    @core.Label::secondary(sources.span(right, 8, 13), message="defined here"),
  ])
  inspect(
    render_for_test(diagnostic, sources),
    content=(
      #|error: cross-file mismatch
      #|  --> left.lane:1:5
      #|   |
      #| 1 | let left = right
      #|   |     ^^^^ used here
      #|   |
      #|  --> right.lane:1:9
      #|   |
      #| 1 | pub let right = 1
      #|   |         ----- defined here
      #|   |
    ),
  )
}

///|
test "render truncates source lines by configured width" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add("let very_long_name = 1", path="wide.lane")
  let diagnostic = @core.Diagnostic::error("wide line", labels=[
    @core.Label::primary(sources.span(source, 4, 18)),
  ])
  inspect(
    render_diagnostic(diagnostic, sources, config={ color: false, width: 12 }),
    content=(
      #|error: wide line
      #|  --> wide.lane:1:5
      #|   |
      #| 1 | let very_...
      #|   |     ^^^^^^^^
      #|   |
    ),
  )
}

///|
test "render can color severity" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let diagnostic = @core.Diagnostic::error("colored")
  inspect(
    render_diagnostic(diagnostic, sources, config={ color: true, width: 100 }),
    content="\u{1b}[31merror\u{1b}[0m: colored",
  )
}
