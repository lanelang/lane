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
  let json = diagnostic_to_json(diagnostic)
  guard json
    is {
      "severity": String("error"),
      "code": String("E4002"),
      "labels": Array(
        [
          {
            "style": String("primary"),
            "span": {
              "sourceId": Number(7, ..),
              "startOffset": Number(2, ..),
              "endOffset": Number(5, ..),
              ..
            },
            ..
          },
        ]
      ),
      "suggestions": Array(
        [{ "edits": Array([{ "replacement": String("Builtins"), .. }]), .. }]
      ),
      ..
    } else {
    fail("expected structured diagnostic JSON")
  }
  json_inspect(json, content={
    "severity": "error",
    "message": "missing imported module `Builtins`",
    "code": "E4002",
    "labels": [
      {
        "style": "primary",
        "span": { "sourceId": 7, "startOffset": 2, "endOffset": 5 },
        "message": "missing artifact",
      },
    ],
    "notes": ["note"],
    "helps": ["help"],
    "facts": [],
    "suggestions": [
      {
        "message": "replace text",
        "applicability": "maybe-incorrect",
        "edits": [
          {
            "span": { "sourceId": 7, "startOffset": 2, "endOffset": 5 },
            "replacement": "Builtins",
          },
        ],
      },
    ],
    "relatedLocations": [],
    "related": [],
  })
}
