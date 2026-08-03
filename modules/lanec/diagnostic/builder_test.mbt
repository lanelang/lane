///|
test "compiler diagnostic builder applies source context" {
  let span = @basic.SourceSpan::dummy()
  let diagnostic = compiler_error(
    "example error",
    span=Some(span),
    code=Some("E0000"),
    labels=[compiler_primary_label(span, "example label")],
    notes=[],
    helps=[],
    context=DiagnosticContext(source_id="file:///main.lane"),
  )
  debug_inspect(
    diagnostic,
    content=(
      #|{
      #|  source_id: Some("file:///main.lane"),
      #|  message: "example error",
      #|  span: Some(
      #|    Source(
      #|      source_id="file:///main.lane",
      #|      span={
      #|        start_offset: 0,
      #|        end_offset: 0,
      #|        start_line: 1,
      #|        start_column: 1,
      #|        end_line: 1,
      #|        end_column: 1,
      #|      },
      #|    ),
      #|  ),
      #|  severity: Error,
      #|  code: Some("E0000"),
      #|  labels: [
      #|    {
      #|      span: Source(
      #|        source_id="file:///main.lane",
      #|        span={
      #|          start_offset: 0,
      #|          end_offset: 0,
      #|          start_line: 1,
      #|          start_column: 1,
      #|          end_line: 1,
      #|          end_column: 1,
      #|        },
      #|      ),
      #|      message: "example label",
      #|      style: Primary,
      #|    },
      #|  ],
      #|  notes: [],
      #|  helps: [],
      #|  facts: [],
      #|  suggestions: [],
      #|}
    ),
  )
}
