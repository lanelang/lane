///|
test "diagnostic exports structured json" {
  let source = @core.SourceId::{ value: 7 }
  let span = @core.SourceSpan::{
    source_id: source,
    start_offset: 2,
    end_offset: 5,
  }
  let diagnostic = @core.Diagnostic::error(
    "missing imported module `Builtins`",
    code="E4002",
    labels=[@core.Label::primary(span, message="missing artifact")],
    notes=["note"],
    helps=["help"],
    suggestions=[
      {
        message: "replace text",
        edits: [{ span, replacement: "Builtins" }],
        applicability: MaybeIncorrect,
      },
    ],
  )
  debug_inspect(
    diagnostic_to_json(diagnostic),
    content=(
      #|Object(
      #|  {
      #|    "severity": String("error"),
      #|    "message": String("missing imported module `Builtins`"),
      #|    "code": String("E4002"),
      #|    "labels": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "style": String("primary"),
      #|            "span": Object(
      #|              {
      #|                "sourceId": Number(7),
      #|                "startOffset": Number(2),
      #|                "endOffset": Number(5),
      #|              },
      #|            ),
      #|            "message": String("missing artifact"),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|    "notes": Array([String("note")]),
      #|    "helps": Array([String("help")]),
      #|    "facts": Array([]),
      #|    "suggestions": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "message": String("replace text"),
      #|            "applicability": String("maybe-incorrect"),
      #|            "edits": Array(
      #|              [
      #|                Object(
      #|                  {
      #|                    "span": Object(
      #|                      {
      #|                        "sourceId": Number(7),
      #|                        "startOffset": Number(2),
      #|                        "endOffset": Number(5),
      #|                      },
      #|                    ),
      #|                    "replacement": String("Builtins"),
      #|                  },
      #|                ),
      #|              ],
      #|            ),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|    "relatedLocations": Array([]),
      #|    "related": Array([]),
      #|  },
      #|)
    ),
  )
}
