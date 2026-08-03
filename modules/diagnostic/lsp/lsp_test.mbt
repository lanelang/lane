///|
test "diagnostic converts to lsp diagnostic json" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add("let answer = 42", path="file:///ops.lane")
  let diagnostic = @core.Diagnostic::error("bad value", code="E0001", labels=[
    @core.Label::primary(
      sources.span(source, 4, 10),
      message="value starts here",
    ),
  ])
  let json = diagnostic_to_lsp_json(diagnostic, sources)
  guard json
    is {
      "severity": Number(1, ..),
      "message": String("bad value\nvalue starts here"),
      "range": {
        "start": { "line": Number(0, ..), "character": Number(4, ..), .. },
        ..
      },
      ..
    } else {
    fail("expected LSP diagnostic JSON")
  }
  json_inspect(json, content={
    "severity": 1,
    "message": "bad value\nvalue starts here",
    "code": "E0001",
    "range": {
      "start": { "line": 0, "character": 4 },
      "end": { "line": 0, "character": 10 },
    },
  })
}

///|
test "lsp related information only carries independent source locations" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add("let answer = value", path="file:///ops.lane")
  let other = sources.add("let value = 1", path="file:///lib.lane")
  let primary = sources.span(source, 4, 10)
  let secondary = sources.span(source, 13, 18)
  let related = sources.span(other, 4, 9)
  let diagnostic = @core.Diagnostic::error(
    "bad value",
    code="E0001",
    labels=[
      @core.Label::primary(primary, message="value starts here"),
      @core.Label::secondary(secondary, message="value used here"),
    ],
    notes=["notes belong to the diagnostic body"],
    helps=["fix the value"],
    facts=[{ name: "expected type", value: "`Int`", span: Some(primary) }],
    related_locations=[{ span: related, message: "definition is here" }],
  )
  json_inspect(diagnostic_to_lsp_json(diagnostic, sources), content={
    "severity": 1,
    "message": "bad value\nvalue starts here",
    "code": "E0001",
    "range": {
      "start": { "line": 0, "character": 4 },
      "end": { "line": 0, "character": 10 },
    },
    "data": {
      "notes": ["notes belong to the diagnostic body"],
      "helps": ["fix the value"],
      "facts": [{ "name": "expected type", "value": "`Int`", "hasSpan": true }],
    },
    "relatedInformation": [
      {
        "location": {
          "uri": "file:///ops.lane",
          "range": {
            "start": { "line": 0, "character": 13 },
            "end": { "line": 0, "character": 18 },
          },
        },
        "message": "value used here",
      },
      {
        "location": {
          "uri": "file:///lib.lane",
          "range": {
            "start": { "line": 0, "character": 4 },
            "end": { "line": 0, "character": 9 },
          },
        },
        "message": "definition is here",
      },
    ],
  })
}

///|
test "diagnostic can include lsp diagnostic source" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add("let answer = 42", path="file:///ops.lane")
  let diagnostic = @core.Diagnostic::error("bad value", labels=[
    @core.Label::primary(sources.span(source, 4, 10)),
  ])
  let json = diagnostic_to_lsp_json(diagnostic, sources, source="lane")
  guard json is { "source": String("lane"), .. } else {
    fail("expected LSP diagnostic source")
  }
  json_inspect(json, content={
    "severity": 1,
    "message": "bad value",
    "source": "lane",
    "range": {
      "start": { "line": 0, "character": 4 },
      "end": { "line": 0, "character": 10 },
    },
  })
}

///|
test "diagnostic without labels still includes required lsp range" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let diagnostic = @core.Diagnostic::error("workspace failure", code="E9999", notes=[
    "no source location is available",
  ])
  json_inspect(diagnostic_to_lsp_json(diagnostic, sources, source="lane"), content={
    "severity": 1,
    "message": "workspace failure",
    "source": "lane",
    "code": "E9999",
    "range": {
      "start": { "line": 0, "character": 0 },
      "end": { "line": 0, "character": 0 },
    },
    "data": { "notes": ["no source location is available"] },
  })
}

///|
test "suggestions convert to lsp code actions" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add("let answer = 42", path="file:///ops.lane")
  let span = sources.span(source, 4, 10)
  let diagnostic = @core.Diagnostic::error(
    "bad value",
    labels=[@core.Label::primary(span)],
    suggestions=[
      {
        message: "rename value",
        edits: [{ span, replacement: "result" }],
        applicability: MachineApplicable,
      },
    ],
  )
  let actions = suggestions_to_code_actions_json(diagnostic, sources)
  guard actions
    is [
      {
        "title": String("rename value"),
        "edit": {
          "changes": {
            "file:///ops.lane": Array([{ "newText": String("result"), .. }]),
            ..
          },
          ..
        },
        ..
      },
    ] else {
    fail("expected LSP quick-fix JSON")
  }
  json_inspect(actions, content=[
    {
      "title": "rename value",
      "kind": "quickfix",
      "diagnostics": [
        {
          "severity": 1,
          "message": "bad value",
          "range": {
            "start": { "line": 0, "character": 4 },
            "end": { "line": 0, "character": 10 },
          },
          "data": {
            "suggestions": [
              {
                "message": "rename value",
                "applicability": "machine-applicable",
              },
            ],
          },
        },
      ],
      "edit": {
        "changes": {
          "file:///ops.lane": [
            {
              "range": {
                "start": { "line": 0, "character": 4 },
                "end": { "line": 0, "character": 10 },
              },
              "newText": "result",
            },
          ],
        },
      },
    },
  ])
}
