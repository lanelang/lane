///|
test "explore_json returns checked buslane and anf panes" {
  debug_inspect(
    parsed_response_json(
      (
        #|{
        #|  "source": "module Test\npub let answer : Int = 42"
        #|}
      ),
    ),
    content=(
      #|Object(
      #|  {
      #|    "status": Number(0),
      #|    "diagnostics": Array([]),
      #|    "panes": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "name": String("checked"),
      #|            "text": String("checked {\n  let answer#0 : Int = 42\n}"),
      #|          },
      #|        ),
      #|        Object(
      #|          {
      #|            "name": String("buslane"),
      #|            "text": String("buslane {\n  metadata {\n    value answer#0 : Int\n  }\n  let value#0 = 42\n}"),
      #|          },
      #|        ),
      #|        Object(
      #|          {
      #|            "name": String("anf"),
      #|            "text": String("anf {\n  let answer#0 : Int = 42\n}"),
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
test "explore_json returns diagnostics for invalid source" {
  debug_inspect(
    parsed_response_json(
      (
        #|{
        #|  "source": "module Test\npub let answer = 42"
        #|}
      ),
    ),
    content=(
      #|Object(
      #|  {
      #|    "status": Number(1),
      #|    "diagnostics": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "source": String("lane"),
      #|            "severity": String("error"),
      #|            "message": String("unexpected token"),
      #|            "range": Object(
      #|              {
      #|                "start": Object({ "line": Number(2), "column": Number(16), "offset": Number(27) }),
      #|                "end": Object({ "line": Number(2), "column": Number(17), "offset": Number(28) }),
      #|              },
      #|            ),
      #|            "sourceId": String("<root>"),
      #|            "code": String("E1100"),
      #|            "labels": Array(
      #|              [
      #|                Object(
      #|                  {
      #|                    "message": String("the parser did not expect `=`"),
      #|                    "style": String("primary"),
      #|                    "range": Object(
      #|                      {
      #|                        "start": Object({ "line": Number(2), "column": Number(16), "offset": Number(27) }),
      #|                        "end": Object({ "line": Number(2), "column": Number(17), "offset": Number(28) }),
      #|                      },
      #|                    ),
      #|                    "sourceId": String("<root>"),
      #|                  },
      #|                ),
      #|              ],
      #|            ),
      #|            "notes": Array([String("expected one of: `:`")]),
      #|            "helps": Array([String("rewrite this position so it starts with one of: `:`")]),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|    "panes": Array([]),
      #|  },
      #|)
    ),
  )
}

///|
test "explore_json rejects malformed requests" {
  debug_inspect(
    parsed_response_json("{\"text\":\"module Test\"}"),
    content=(
      #|Object(
      #|  {
      #|    "status": Number(3),
      #|    "diagnostics": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "source": String("lane_wasm"),
      #|            "severity": String("error"),
      #|            "message": String("expected request object with string field `source`"),
      #|            "range": Object(
      #|              {
      #|                "start": Object({ "line": Number(1), "column": Number(1), "offset": Number(0) }),
      #|                "end": Object({ "line": Number(1), "column": Number(1), "offset": Number(0) }),
      #|              },
      #|            ),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|    "panes": Array([]),
      #|  },
      #|)
    ),
  )
}

///|
fn parsed_response_json(request_text : String) -> Json {
  @json.parse(explore_request(request_text).json) catch {
    _ => abort("expected JSON response")
  }
}
