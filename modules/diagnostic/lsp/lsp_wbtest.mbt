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
  debug_inspect(
    diagnostic_to_lsp_json(diagnostic, sources),
    content=(
      #|Object(
      #|  {
      #|    "severity": Number(1),
      #|    "message": String("bad value"),
      #|    "code": String("E0001"),
      #|    "range": Object(
      #|      {
      #|        "start": Object({ "line": Number(0), "character": Number(4) }),
      #|        "end": Object({ "line": Number(0), "character": Number(10) }),
      #|      },
      #|    ),
      #|    "relatedInformation": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "location": Object(
      #|              {
      #|                "uri": String("file:///ops.lane"),
      #|                "range": Object(
      #|                  {
      #|                    "start": Object({ "line": Number(0), "character": Number(4) }),
      #|                    "end": Object({ "line": Number(0), "character": Number(10) }),
      #|                  },
      #|                ),
      #|              },
      #|            ),
      #|            "message": String("value starts here"),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|  },
      #|)
    ),
  )
}

///|
test "diagnostic can include lsp diagnostic source" {
  let sources = @source.SourceDatabase::SourceDatabase()
  let source = sources.add("let answer = 42", path="file:///ops.lane")
  let diagnostic = @core.Diagnostic::error("bad value", labels=[
    @core.Label::primary(sources.span(source, 4, 10)),
  ])
  debug_inspect(
    diagnostic_to_lsp_json(diagnostic, sources, source="lane"),
    content=(
      #|Object(
      #|  {
      #|    "severity": Number(1),
      #|    "message": String("bad value"),
      #|    "source": String("lane"),
      #|    "range": Object(
      #|      {
      #|        "start": Object({ "line": Number(0), "character": Number(4) }),
      #|        "end": Object({ "line": Number(0), "character": Number(10) }),
      #|      },
      #|    ),
      #|  },
      #|)
    ),
  )
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
  debug_inspect(
    suggestions_to_code_actions_json(diagnostic, sources),
    content=(
      #|[
      #|  Object(
      #|    {
      #|      "title": String("rename value"),
      #|      "kind": String("quickfix"),
      #|      "diagnostics": Array(
      #|        [
      #|          Object(
      #|            {
      #|              "severity": Number(1),
      #|              "message": String("bad value"),
      #|              "range": Object(
      #|                {
      #|                  "start": Object({ "line": Number(0), "character": Number(4) }),
      #|                  "end": Object({ "line": Number(0), "character": Number(10) }),
      #|                },
      #|              ),
      #|              "data": Object(
      #|                {
      #|                  "facts": Array([]),
      #|                  "suggestions": Array(
      #|                    [
      #|                      Object(
      #|                        {
      #|                          "message": String("rename value"),
      #|                          "applicability": String("machine-applicable"),
      #|                        },
      #|                      ),
      #|                    ],
      #|                  ),
      #|                },
      #|              ),
      #|            },
      #|          ),
      #|        ],
      #|      ),
      #|      "edit": Object(
      #|        {
      #|          "changes": Object(
      #|            {
      #|              "file:///ops.lane": Array(
      #|                [
      #|                  Object(
      #|                    {
      #|                      "range": Object(
      #|                        {
      #|                          "start": Object({ "line": Number(0), "character": Number(4) }),
      #|                          "end": Object({ "line": Number(0), "character": Number(10) }),
      #|                        },
      #|                      ),
      #|                      "newText": String("result"),
      #|                    },
      #|                  ),
      #|                ],
      #|              ),
      #|            },
      #|          ),
      #|        },
      #|      ),
      #|    },
      #|  ),
      #|]
    ),
  )
}
