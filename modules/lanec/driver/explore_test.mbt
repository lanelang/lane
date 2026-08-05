///|
fn explore_test_request(
  root : String,
  libraries? : Array[String] = [],
  entry? : String = "main",
) -> ExploreRequest {
  {
    root_source: { source_id: "Main.lane", text: root },
    library_sources: libraries.mapi((index, text) => {
      source_id: "Library\{index}.lane",
      text,
    }),
    entry,
  }
}

///|
fn explore_stage_evidence(
  stage : ExploreStage,
) -> (String, String, String?, String?, String?) {
  match stage.state {
    Completed(snapshot) =>
      (
        stage.id,
        "completed",
        Some(snapshot.domain.name()),
        Some(snapshot.text_format.name()),
        snapshot.text.split("\n").next().map(StringView::to_owned),
      )
    Failed(_) => (stage.id, "failed", None, None, None)
    Unavailable => (stage.id, "unavailable", None, None, None)
  }
}

///|
test "explore protocol v1 exposes all eighteen ordered completed stages" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|pub fn main() -> Unit {
        #|  ()
        #|}
      ),
    ),
  )
  debug_inspect(
    (
      report.schema_version,
      report.compiler,
      report.root,
      report.selected_entry,
      report.status,
      report.diagnostics,
      report.stages.ordered().map(explore_stage_evidence),
    ),
    content=(
      #|(
      #|  1,
      #|  { name: "Milky2018/lanec", version: "0.1.0" },
      #|  { source_id: "Main.lane", module_path_text: Some("Main") },
      #|  Some({ module_path_text: "Main", name: "main", type_text: "() -> Unit" }),
      #|  Succeeded,
      #|  [],
      #|  [
      #|    (
      #|      "syntax",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("lane"),
      #|      Some("module Main"),
      #|    ),
      #|    (
      #|      "resolved",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("lane-resolved"),
      #|      Some("fn value#0 main() -> Unit {"),
      #|    ),
      #|    (
      #|      "checked",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("lane-checked"),
      #|      Some("fn main#0() -> Unit {"),
      #|    ),
      #|    (
      #|      "buslane.module",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.linked",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.effect-specialized",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.handlers-elaborated",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.monadic",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.selective-cps",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.open-context-resolved",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane-effect-lowering"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.monadic-lifted",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.core-optimized",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "buslane.effects-erased",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    (
      #|      "executable",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("buslane"),
      #|      Some("letrec {"),
      #|    ),
      #|    ("anf", "completed", Some("compiler"), Some("anf"), Some("letrec {")),
      #|    (
      #|      "vmcfg.initial",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("vmcfg"),
      #|      Some("function f1("),
      #|    ),
      #|    (
      #|      "loisvm.bytecode",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("loisvm-bytecode"),
      #|      Some("function f1 abi=abi0("),
      #|    ),
      #|    ("wasm", "completed", Some("backend"), Some("wat"), Some("(module")),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore parse failure marks syntax failed and later stages unavailable" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|pub fn main( -> Unit {
      ),
    ),
  )
  debug_inspect(
    (
      report.root,
      report.selected_entry,
      report.status,
      report.diagnostics,
      report.stages
      .ordered()
      .map(stage => (stage.id, explore_stage_evidence(stage).1)),
    ),
    content=(
      #|(
      #|  { source_id: "Main.lane", module_path_text: None },
      #|  None,
      #|  Failed(Syntax),
      #|  [
      #|    {
      #|      source_id: Some("Main.lane"),
      #|      message: "unexpected token",
      #|      span: Some(
      #|        Source(
      #|          source_id="Main.lane",
      #|          span={
      #|            start_offset: 25,
      #|            end_offset: 27,
      #|            start_line: 2,
      #|            start_column: 14,
      #|            end_line: 2,
      #|            end_column: 16,
      #|          },
      #|        ),
      #|      ),
      #|      severity: Error,
      #|      code: Some("E1100"),
      #|      labels: [
      #|        {
      #|          span: Source(
      #|            source_id="Main.lane",
      #|            span={
      #|              start_offset: 25,
      #|              end_offset: 27,
      #|              start_line: 2,
      #|              start_column: 14,
      #|              end_line: 2,
      #|              end_column: 16,
      #|            },
      #|          ),
      #|          message: "the parser did not expect `->`",
      #|          style: Primary,
      #|        },
      #|      ],
      #|      notes: ["expected one of: identifier, `offer`, `auto`, `)`"],
      #|      helps: ["rewrite this position so it starts with one of: identifier, `offer`, `auto`, `)`"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|  [
      #|    ("syntax", "failed"),
      #|    ("resolved", "unavailable"),
      #|    ("checked", "unavailable"),
      #|    ("buslane.module", "unavailable"),
      #|    ("buslane.linked", "unavailable"),
      #|    ("buslane.effect-specialized", "unavailable"),
      #|    ("buslane.handlers-elaborated", "unavailable"),
      #|    ("buslane.monadic", "unavailable"),
      #|    ("buslane.selective-cps", "unavailable"),
      #|    ("buslane.open-context-resolved", "unavailable"),
      #|    ("buslane.monadic-lifted", "unavailable"),
      #|    ("buslane.core-optimized", "unavailable"),
      #|    ("buslane.effects-erased", "unavailable"),
      #|    ("executable", "unavailable"),
      #|    ("anf", "unavailable"),
      #|    ("vmcfg.initial", "unavailable"),
      #|    ("loisvm.bytecode", "unavailable"),
      #|    ("wasm", "unavailable"),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore graph failure preserves syntax and fails resolved" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|import Missing.*
        #|pub fn main() -> Unit { () }
      ),
    ),
  )
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      report.stages
      .ordered()
      .map(stage => (stage.id, explore_stage_evidence(stage).1)),
    ),
    content=(
      #|(
      #|  Failed(Resolved),
      #|  [
      #|    {
      #|      source_id: Some("Main.lane"),
      #|      message: "missing imported module `Missing`",
      #|      span: Some(
      #|        Source(
      #|          source_id="Main.lane",
      #|          span={
      #|            start_offset: 19,
      #|            end_offset: 26,
      #|            start_line: 2,
      #|            start_column: 8,
      #|            end_line: 2,
      #|            end_column: 15,
      #|          },
      #|        ),
      #|      ),
      #|      severity: Error,
      #|      code: Some("E4002"),
      #|      labels: [
      #|        {
      #|          span: Source(
      #|            source_id="Main.lane",
      #|            span={
      #|              start_offset: 19,
      #|              end_offset: 26,
      #|              start_line: 2,
      #|              start_column: 8,
      #|              end_line: 2,
      #|              end_column: 15,
      #|            },
      #|          ),
      #|          message: "no explicit input provides this module",
      #|          style: Primary,
      #|        },
      #|      ],
      #|      notes: ["Lane only compiles explicitly provided source files and interface artifacts"],
      #|      helps: ["pass an input whose declared module is `Missing`, or change the import to one of the listed modules"],
      #|      facts: [{ name: "considered source module", value: "`Main`", span: None }],
      #|      suggestions: [
      #|        {
      #|          message: "check the imported module name against the listed explicit inputs",
      #|          edits: [],
      #|          applicability: MaybeIncorrect,
      #|        },
      #|      ],
      #|    },
      #|  ],
      #|  [
      #|    ("syntax", "completed"),
      #|    ("resolved", "failed"),
      #|    ("checked", "unavailable"),
      #|    ("buslane.module", "unavailable"),
      #|    ("buslane.linked", "unavailable"),
      #|    ("buslane.effect-specialized", "unavailable"),
      #|    ("buslane.handlers-elaborated", "unavailable"),
      #|    ("buslane.monadic", "unavailable"),
      #|    ("buslane.selective-cps", "unavailable"),
      #|    ("buslane.open-context-resolved", "unavailable"),
      #|    ("buslane.monadic-lifted", "unavailable"),
      #|    ("buslane.core-optimized", "unavailable"),
      #|    ("buslane.effects-erased", "unavailable"),
      #|    ("executable", "unavailable"),
      #|    ("anf", "unavailable"),
      #|    ("vmcfg.initial", "unavailable"),
      #|    ("loisvm.bytecode", "unavailable"),
      #|    ("wasm", "unavailable"),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore resolve failure preserves syntax and fails resolved" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|pub fn main() -> I64 { missing }
      ),
    ),
  )
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      report.stages
      .ordered()
      .map(stage => (stage.id, explore_stage_evidence(stage).1)),
    ),
    content=(
      #|(
      #|  Failed(Resolved),
      #|  [
      #|    {
      #|      source_id: Some("Main.lane"),
      #|      message: "cannot find value `missing`",
      #|      span: Some(
      #|        Source(
      #|          source_id="Main.lane",
      #|          span={
      #|            start_offset: 35,
      #|            end_offset: 42,
      #|            start_line: 2,
      #|            start_column: 24,
      #|            end_line: 2,
      #|            end_column: 31,
      #|          },
      #|        ),
      #|      ),
      #|      severity: Error,
      #|      code: Some("E2001"),
      #|      labels: [
      #|        {
      #|          span: Source(
      #|            source_id="Main.lane",
      #|            span={
      #|              start_offset: 35,
      #|              end_offset: 42,
      #|              start_line: 2,
      #|              start_column: 24,
      #|              end_line: 2,
      #|              end_column: 31,
      #|            },
      #|          ),
      #|          message: "no value named `missing` is visible here",
      #|          style: Primary,
      #|        },
      #|      ],
      #|      notes: ["Lane value lookup uses local bindings, top-level values, and explicitly imported public values"],
      #|      helps: ["define `missing` before this use, import it, or qualify it with its module path"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|  [
      #|    ("syntax", "completed"),
      #|    ("resolved", "failed"),
      #|    ("checked", "unavailable"),
      #|    ("buslane.module", "unavailable"),
      #|    ("buslane.linked", "unavailable"),
      #|    ("buslane.effect-specialized", "unavailable"),
      #|    ("buslane.handlers-elaborated", "unavailable"),
      #|    ("buslane.monadic", "unavailable"),
      #|    ("buslane.selective-cps", "unavailable"),
      #|    ("buslane.open-context-resolved", "unavailable"),
      #|    ("buslane.monadic-lifted", "unavailable"),
      #|    ("buslane.core-optimized", "unavailable"),
      #|    ("buslane.effects-erased", "unavailable"),
      #|    ("executable", "unavailable"),
      #|    ("anf", "unavailable"),
      #|    ("vmcfg.initial", "unavailable"),
      #|    ("loisvm.bytecode", "unavailable"),
      #|    ("wasm", "unavailable"),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore typecheck and entry-selection failures retain completed stages" {
  let typecheck = explore(
    explore_test_request(
      (
        #|module Main
        #|pub fn main() -> I64 { true }
      ),
    ),
  )
  let entry = explore(
    explore_test_request(
      (
        #|module Main
        #|pub fn main() -> Unit { () }
      ),
      entry="missing",
    ),
  )
  debug_inspect(
    [
      (
        typecheck.status,
        typecheck.stages
        .ordered()
        .map(stage => (stage.id, explore_stage_evidence(stage).1)),
      ),
      (
        entry.status,
        entry.stages
        .ordered()
        .map(stage => (stage.id, explore_stage_evidence(stage).1)),
      ),
    ],
    content=(
      #|[
      #|  (
      #|    Failed(Checked),
      #|    [
      #|      ("syntax", "completed"),
      #|      ("resolved", "completed"),
      #|      ("checked", "failed"),
      #|      ("buslane.module", "unavailable"),
      #|      ("buslane.linked", "unavailable"),
      #|      ("buslane.effect-specialized", "unavailable"),
      #|      ("buslane.handlers-elaborated", "unavailable"),
      #|      ("buslane.monadic", "unavailable"),
      #|      ("buslane.selective-cps", "unavailable"),
      #|      ("buslane.open-context-resolved", "unavailable"),
      #|      ("buslane.monadic-lifted", "unavailable"),
      #|      ("buslane.core-optimized", "unavailable"),
      #|      ("buslane.effects-erased", "unavailable"),
      #|      ("executable", "unavailable"),
      #|      ("anf", "unavailable"),
      #|      ("vmcfg.initial", "unavailable"),
      #|      ("loisvm.bytecode", "unavailable"),
      #|      ("wasm", "unavailable"),
      #|    ],
      #|  ),
      #|  (
      #|    Failed(BuslaneLinked),
      #|    [
      #|      ("syntax", "completed"),
      #|      ("resolved", "completed"),
      #|      ("checked", "completed"),
      #|      ("buslane.module", "completed"),
      #|      ("buslane.linked", "failed"),
      #|      ("buslane.effect-specialized", "unavailable"),
      #|      ("buslane.handlers-elaborated", "unavailable"),
      #|      ("buslane.monadic", "unavailable"),
      #|      ("buslane.selective-cps", "unavailable"),
      #|      ("buslane.open-context-resolved", "unavailable"),
      #|      ("buslane.monadic-lifted", "unavailable"),
      #|      ("buslane.core-optimized", "unavailable"),
      #|      ("buslane.effects-erased", "unavailable"),
      #|      ("executable", "unavailable"),
      #|      ("anf", "unavailable"),
      #|      ("vmcfg.initial", "unavailable"),
      #|      ("loisvm.bytecode", "unavailable"),
      #|      ("wasm", "unavailable"),
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "explore ignores malformed libraries unreachable from the root" {
  let request = explore_test_request(
    (
      #|module Main
      #|pub fn main() -> Unit { () }
    ),
    libraries=[
      (
        #|module Unused
        #|pub fn broken( -> Unit {
      ),
    ],
  )
  let compiled = @compile.compile_modules({
    root: request.root_source,
    libraries: request.library_sources,
  })
  let report = explore(request)
  debug_inspect(
    (
      compiled is Succeeded(_, _),
      compiled.diagnostics(),
      report.status,
      report.diagnostics,
    ),
    content="(true, [], Succeeded, [])",
  )
}
