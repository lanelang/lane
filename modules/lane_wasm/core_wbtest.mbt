///|
priv struct ResponseSummary {
  status : Int
  stage_ids : Array[String]
  diagnostic_messages : Array[String]
  failure : String?
} derive(Debug)

///|
priv struct EntryResponseSummary {
  status : Int
  entries : Array[String]
  diagnostic_messages : Array[String]
} derive(Debug)

///|
test "entry request enumerates artifact-defined entries" {
  debug_inspect(
    entry_response_summary(
      parsed_entries_json(
        (
          #|{
          #|  "root": {
          #|    "sourceId": "main.lane",
          #|    "text": "module Main\npub fn main() -> Unit { () }"
          #|  },
          #|  "libraries": []
          #|}
        ),
      ),
    ),
    content=(
      #|{ status: 0, entries: ["Main.main"], diagnostic_messages: [] }
    ),
  )
}

///|
test "explore request returns every curated stage" {
  debug_inspect(
    response_summary(
      parsed_response_json(
        (
          #|{
          #|  "root": {
          #|    "sourceId": "main.lane",
          #|    "text": "module Main\npub fn main() -> Unit { () }"
          #|  },
          #|  "libraries": [],
          #|  "entry": "main"
          #|}
        ),
      ),
    ),
    content=(
      #|{
      #|  status: 0,
      #|  stage_ids: [
      #|    "syntax",
      #|    "resolved",
      #|    "checked",
      #|    "buslane.module",
      #|    "buslane.linked",
      #|    "buslane.effect-specialized",
      #|    "buslane.handlers-elaborated",
      #|    "buslane.monadic",
      #|    "buslane.selective-cps",
      #|    "buslane.open-context-resolved",
      #|    "buslane.monadic-lifted",
      #|    "buslane.core-optimized",
      #|    "buslane.effects-erased",
      #|    "executable",
      #|    "anf",
      #|    "vmcfg.initial",
      #|    "loisvm.bytecode",
      #|    "wasm",
      #|  ],
      #|  diagnostic_messages: [],
      #|  failure: None,
      #|}
    ),
  )
}

///|
test "explore request accepts multiple source files" {
  debug_inspect(
    response_summary(
      parsed_response_json(
        (
          #|{
          #|  "root": {
          #|    "sourceId": "main.lane",
          #|    "text": "module Main\nimport Lib.{value}\npub let copied : Int = value\npub fn main() -> Unit { () }"
          #|  },
          #|  "libraries": [
          #|    {
          #|      "sourceId": "lib.lane",
          #|      "text": "module Lib\npub let value : Int = 42"
          #|    }
          #|  ],
          #|  "entry": "main"
          #|}
        ),
      ),
    ),
    content=(
      #|{
      #|  status: 0,
      #|  stage_ids: [
      #|    "syntax",
      #|    "resolved",
      #|    "checked",
      #|    "buslane.module",
      #|    "buslane.linked",
      #|    "buslane.effect-specialized",
      #|    "buslane.handlers-elaborated",
      #|    "buslane.monadic",
      #|    "buslane.selective-cps",
      #|    "buslane.open-context-resolved",
      #|    "buslane.monadic-lifted",
      #|    "buslane.core-optimized",
      #|    "buslane.effects-erased",
      #|    "executable",
      #|    "anf",
      #|    "vmcfg.initial",
      #|    "loisvm.bytecode",
      #|    "wasm",
      #|  ],
      #|  diagnostic_messages: [],
      #|  failure: None,
      #|}
    ),
  )
}

///|
test "explore request preserves partial stages on diagnostics" {
  debug_inspect(
    response_summary(
      parsed_response_json(
        (
          #|{
          #|  "root": {
          #|    "sourceId": "main.lane",
          #|    "text": "module Main\npub let answer = 42"
          #|  },
          #|  "libraries": [],
          #|  "entry": "answer"
          #|}
        ),
      ),
    ),
    content=(
      #|{
      #|  status: 1,
      #|  stage_ids: [],
      #|  diagnostic_messages: ["declaration needs a type annotation"],
      #|  failure: None,
      #|}
    ),
  )
}

///|
test "explore request rejects malformed requests" {
  debug_inspect(
    response_summary(parsed_response_json("{\"text\":\"module Test\"}")),
    content=(
      #|{
      #|  status: 3,
      #|  stage_ids: [],
      #|  diagnostic_messages: ["expected `root`, `libraries`, and `entry` fields in the request object"],
      #|  failure: None,
      #|}
    ),
  )
}

///|
fn parsed_response_json(request_text : String) -> Json {
  @json.parse(explore_request(request_text).json) catch {
    _ => abort("expected JSON response")
  }
}

///|
fn parsed_entries_json(request_text : String) -> Json {
  @json.parse(entries_request(request_text).json) catch {
    _ => abort("expected JSON response")
  }
}

///|
fn entry_response_summary(response : Json) -> EntryResponseSummary {
  guard response
    is {
      "status": Number(status, ..),
      "diagnostics": Array(diagnostics),
      "entries": Array(entries),
      ..
    } else {
    abort("expected entry response object")
  }
  let entry_names = entries.map(entry => {
    guard entry is { "module": String(module_), "name": String(name), .. } else {
      abort("expected entry object")
    }
    "\{module_}.\{name}"
  })
  let diagnostic_messages = diagnostics.map(diagnostic => {
    guard diagnostic is { "message": String(message), .. } else {
      abort("expected diagnostic message")
    }
    message
  })
  { status: status.to_int(), entries: entry_names, diagnostic_messages }
}

///|
fn response_summary(response : Json) -> ResponseSummary {
  guard response
    is {
      "status": Number(status, ..),
      "diagnostics": Array(diagnostics),
      "stages": Array(stages),
      ..
    } else {
    abort("expected explorer response object")
  }
  let stage_ids = stages.map(stage => {
    guard stage is { "id": String(id), .. } else { abort("expected stage id") }
    id
  })
  let diagnostic_messages = diagnostics.map(diagnostic => {
    guard diagnostic is { "message": String(message), .. } else {
      abort("expected diagnostic message")
    }
    message
  })
  let failure = match response {
    { "failure": String(message), .. } => Some(message)
    _ => None
  }
  { status: status.to_int(), stage_ids, diagnostic_messages, failure }
}
