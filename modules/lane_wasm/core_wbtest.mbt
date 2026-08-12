///|
priv struct ResponseSummary {
  schema_version : Int
  compiler : String
  root : String
  selected_entry : String?
  status : String
  failed_stage : String?
  stages : Array[(String, String, String?, String?)]
  diagnostic_messages : Array[String]
} derive(Debug)

///|
priv struct EntryResponseSummary {
  schema_version : Int
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
      #|{
      #|  schema_version: 1,
      #|  status: 0,
      #|  entries: ["Main.main"],
      #|  diagnostic_messages: [],
      #|}
    ),
  )
}

///|
test "explore request returns the complete protocol v3 report" {
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
      #|  schema_version: 3,
      #|  compiler: "Milky2018/lanec@0.1.0",
      #|  root: "main.lane:Main",
      #|  selected_entry: Some("Main.main"),
      #|  status: "succeeded",
      #|  failed_stage: None,
      #|  stages: [
      #|    ("syntax", "completed", Some("compiler"), Some("lane")),
      #|    ("resolved", "completed", Some("compiler"), Some("lane-resolved")),
      #|    ("checked", "completed", Some("compiler"), Some("lane-checked")),
      #|    ("buslane.module", "completed", Some("compiler"), Some("buslane")),
      #|    ("buslane.linked", "completed", Some("compiler"), Some("buslane")),
      #|    (
      #|      "buslane.effect-specialized",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    (
      #|      "buslane.core-optimized",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    (
      #|      "buslane.handlers-elaborated",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.monadic",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.selective-cps",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.open-context-resolved",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.monadic-lifted",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    (
      #|      "buslane.effects-erased",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    ("executable", "completed", Some("compiler"), Some("buslane")),
      #|    ("anf", "completed", Some("compiler"), Some("anf")),
      #|    ("vmcfg.initial", "completed", Some("compiler"), Some("vmcfg")),
      #|    (
      #|      "loisvm.bytecode",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("loisvm-bytecode"),
      #|    ),
      #|    ("wasm", "completed", Some("backend"), Some("wat")),
      #|  ],
      #|  diagnostic_messages: [],
      #|}
    ),
  )
}

///|
test "protocol v3 encodes ordered metrics and structured function lineage" {
  let response = parsed_response_json(
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
  )
  guard response
    is {
      "schemaVersion": Number(schema_version, ..),
      "stages": Array(stages),
      "functions": { "nodes": Array(nodes), "edges": Array(edges), .. },
      ..
    } else {
    fail("missing protocol v3 observability fields")
  }
  let anf_observations = stages.filter_map(stage => {
    match stage {
      {
        "id": String("anf"),
        "metrics": Array(metrics),
        "functions": Array(functions),
        ..
      } => Some((metrics, functions))
      _ => None
    }
  })
  let selected_nodes = nodes.filter(node => {
    guard node is { "roles": Array(roles), .. } else { return false }
    roles.any(role => {
      role is { "kind": String("source"), "name": String("main"), .. } ||
      role is { "kind": String("entryWrapper"), .. }
    })
  })
  debug_inspect(
    (schema_version.to_int(), anf_observations, selected_nodes, edges.length()),
    content=(
      #|(
      #|  3,
      #|  [
      #|    (
      #|      [
      #|        Object({ "id": String("topTermCount"), "value": Number(1) }),
      #|        Object({ "id": String("functionCount"), "value": Number(1) }),
      #|        Object({ "id": String("nodeCount"), "value": Number(5) }),
      #|        Object({ "id": String("callCount"), "value": Number(0) }),
      #|      ],
      #|      [
      #|        Object(
      #|          {
      #|            "index": Number(0),
      #|            "blockCount": Number(0),
      #|            "operationCount": Number(2),
      #|            "valueCount": Number(0),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|  ],
      #|  [
      #|    Object(
      #|      {
      #|        "function": Object({ "stage": String("anf"), "index": Number(0) }),
      #|        "roles": Array(
      #|          [
      #|            Object(
      #|              {
      #|                "kind": String("source"),
      #|                "value": Number(0),
      #|                "name": String("main"),
      #|              },
      #|            ),
      #|          ],
      #|        ),
      #|      },
      #|    ),
      #|    Object(
      #|      {
      #|        "function": Object({ "stage": String("vmcfg.initial"), "index": Number(1) }),
      #|        "roles": Array(
      #|          [
      #|            Object(
      #|              {
      #|                "kind": String("source"),
      #|                "value": Number(0),
      #|                "name": String("main"),
      #|              },
      #|            ),
      #|          ],
      #|        ),
      #|      },
      #|    ),
      #|    Object(
      #|      {
      #|        "function": Object({ "stage": String("loisvm.bytecode"), "index": Number(1) }),
      #|        "roles": Array(
      #|          [
      #|            Object(
      #|              {
      #|                "kind": String("source"),
      #|                "value": Number(0),
      #|                "name": String("main"),
      #|              },
      #|            ),
      #|          ],
      #|        ),
      #|      },
      #|    ),
      #|    Object(
      #|      {
      #|        "function": Object({ "stage": String("wasm"), "index": Number(24) }),
      #|        "roles": Array([Object({ "kind": String("entryWrapper") })]),
      #|      },
      #|    ),
      #|  ],
      #|  3,
      #|)
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
          #|    "text": "module Main\nimport Lib.{value}\npub let copied : I64 = value\npub fn main() -> Unit { () }"
          #|  },
          #|  "libraries": [
          #|    {
          #|      "sourceId": "lib.lane",
          #|      "text": "module Lib\npub let value : I64 = 42"
          #|    }
          #|  ],
          #|  "entry": "main"
          #|}
        ),
      ),
    ),
    content=(
      #|{
      #|  schema_version: 3,
      #|  compiler: "Milky2018/lanec@0.1.0",
      #|  root: "main.lane:Main",
      #|  selected_entry: Some("Main.main"),
      #|  status: "succeeded",
      #|  failed_stage: None,
      #|  stages: [
      #|    ("syntax", "completed", Some("compiler"), Some("lane")),
      #|    ("resolved", "completed", Some("compiler"), Some("lane-resolved")),
      #|    ("checked", "completed", Some("compiler"), Some("lane-checked")),
      #|    ("buslane.module", "completed", Some("compiler"), Some("buslane")),
      #|    ("buslane.linked", "completed", Some("compiler"), Some("buslane")),
      #|    (
      #|      "buslane.effect-specialized",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    (
      #|      "buslane.core-optimized",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    (
      #|      "buslane.handlers-elaborated",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.monadic",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.selective-cps",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.open-context-resolved",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|    ),
      #|    (
      #|      "buslane.monadic-lifted",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    (
      #|      "buslane.effects-erased",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|    ),
      #|    ("executable", "completed", Some("compiler"), Some("buslane")),
      #|    ("anf", "completed", Some("compiler"), Some("anf")),
      #|    ("vmcfg.initial", "completed", Some("compiler"), Some("vmcfg")),
      #|    (
      #|      "loisvm.bytecode",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("loisvm-bytecode"),
      #|    ),
      #|    ("wasm", "completed", Some("backend"), Some("wat")),
      #|  ],
      #|  diagnostic_messages: [],
      #|}
    ),
  )
}

///|
test "explore request preserves failed and unavailable stage states" {
  debug_inspect(
    response_summary(
      parsed_response_json(
        (
          #|{
          #|  "root": {
          #|    "sourceId": "main.lane",
          #|    "text": "module Main\npub fn main() -> I64 { true }"
          #|  },
          #|  "libraries": [],
          #|  "entry": "main"
          #|}
        ),
      ),
    ),
    content=(
      #|{
      #|  schema_version: 3,
      #|  compiler: "Milky2018/lanec@0.1.0",
      #|  root: "main.lane:Main",
      #|  selected_entry: None,
      #|  status: "failed",
      #|  failed_stage: Some("checked"),
      #|  stages: [
      #|    ("syntax", "completed", Some("compiler"), Some("lane")),
      #|    ("resolved", "completed", Some("compiler"), Some("lane-resolved")),
      #|    ("checked", "failed", None, None),
      #|    ("buslane.module", "unavailable", None, None),
      #|    ("buslane.linked", "unavailable", None, None),
      #|    ("buslane.effect-specialized", "unavailable", None, None),
      #|    ("buslane.core-optimized", "unavailable", None, None),
      #|    ("buslane.handlers-elaborated", "unavailable", None, None),
      #|    ("buslane.monadic", "unavailable", None, None),
      #|    ("buslane.selective-cps", "unavailable", None, None),
      #|    ("buslane.open-context-resolved", "unavailable", None, None),
      #|    ("buslane.monadic-lifted", "unavailable", None, None),
      #|    ("buslane.effects-erased", "unavailable", None, None),
      #|    ("executable", "unavailable", None, None),
      #|    ("anf", "unavailable", None, None),
      #|    ("vmcfg.initial", "unavailable", None, None),
      #|    ("loisvm.bytecode", "unavailable", None, None),
      #|    ("wasm", "unavailable", None, None),
      #|  ],
      #|  diagnostic_messages: ["type mismatch"],
      #|}
    ),
  )
}

///|
test "explore request rejects malformed requests" {
  debug_inspect(
    parsed_response_json("{\"text\":\"module Test\"}"),
    content=(
      #|Object(
      #|  {
      #|    "schemaVersion": Number(3),
      #|    "status": Number(3),
      #|    "diagnostics": Array(
      #|      [
      #|        Object(
      #|          {
      #|            "source": String("lane_wasm"),
      #|            "severity": String("error"),
      #|            "message": String("expected `root`, `libraries`, and `entry` fields in the request object"),
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
      #|    "stages": Array([]),
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
      "schemaVersion": Number(schema_version, ..),
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
  {
    schema_version: schema_version.to_int(),
    status: status.to_int(),
    entries: entry_names,
    diagnostic_messages,
  }
}

///|
fn response_summary(response : Json) -> ResponseSummary {
  guard response
    is {
      "schemaVersion": Number(schema_version, ..),
      "compiler": {
        "name": String(compiler_name),
        "version": String(compiler_version),
        ..
      },
      "root": root_json,
      "status": status_json,
      "diagnostics": Array(diagnostics),
      "stages": Array(stages),
      ..
    } else {
    abort("expected explorer response object")
  }
  guard root_json is { "sourceId": String(source_id), .. } else {
    abort("expected root identity")
  }
  let module_path = match root_json {
    { "module": String(module_path), .. } => module_path
    _ => "<unavailable>"
  }
  guard status_json is { "kind": String(status), .. } else {
    abort("expected report status")
  }
  let selected_entry = match response {
    {
      "selectedEntry": { "module": String(module_), "name": String(name), .. },
      ..
    } => Some("\{module_}.\{name}")
    _ => None
  }
  let failed_stage = match status_json {
    { "stage": String(stage), .. } => Some(stage)
    _ => None
  }
  let stage_summaries = stages.map(stage => {
    guard stage is { "id": String(id), "status": String(stage_status), .. } else {
      abort("expected stage identity and status")
    }
    let domain = match stage {
      { "domain": String(domain), .. } => Some(domain)
      _ => None
    }
    let format = match stage {
      { "format": String(format), .. } => Some(format)
      _ => None
    }
    (id, stage_status, domain, format)
  })
  let diagnostic_messages = diagnostics.map(diagnostic => {
    guard diagnostic is { "message": String(message), .. } else {
      abort("expected diagnostic message")
    }
    message
  })
  {
    schema_version: schema_version.to_int(),
    compiler: "\{compiler_name}@\{compiler_version}",
    root: "\{source_id}:\{module_path}",
    selected_entry,
    status,
    failed_stage,
    stages: stage_summaries,
    diagnostic_messages,
  }
}
