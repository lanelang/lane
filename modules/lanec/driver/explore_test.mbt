///|
fn explore_test_request(
  root : String,
  libraries? : Array[String] = [],
  entry? : String = "main",
) -> ExploreRequest {
  {
    root_source: { source_id: "Main.lane", text: root, },
    library_sources: libraries.mapi((index, text) => {
      source_id: "Library\{index}.lane",
      text,
    }),
    entry,
    execution_profile: @executable.ExecutionProfile::new(
      builtin_effects=[Io, Panic],
      supports_external_effects=true,
    ),
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
fn explore_stage_scale(
  stage : ExploreStage,
) -> (String, Array[(String, Int)], Array[ExploreFunctionScale])? {
  guard stage.state is Completed(snapshot) else { return None }
  if snapshot.scale.metrics.is_empty() {
    None
  } else {
    Some(
      (
        stage.id,
        snapshot.scale.metrics.map(metric => (metric.id.key(), metric.value)),
        snapshot.scale.functions,
      ),
    )
  }
}

///|
test "explore protocol v6 exposes all eighteen ordered completed stages" {
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
      #|  6,
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
      #|      "buslane.core-optimized",
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
      #|      "buslane.cps-core-optimized",
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
      #|      Some("executable {"),
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
test "explore attributes link growth and specialization cleanup" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|import Lib.{ live, invoke }
        #|let observe : (I64) -> Unit ! Io = extern("observe")
        #|fn pure() -> Unit { () }
        #|pub fn main() -> Unit ! Io {
        #|  invoke[{}](pure)
        #|  observe(live())
        #|}
      ),
      libraries=[
        (
          #|module Lib
          #|pub enum Box[E : Effect] {
          #|  box(() -> Unit ! E)
          #|}
          #|pub fn live() -> I64 { 42 }
          #|pub fn[E : Effect] invoke(action : () -> Unit ! E) -> Unit ! E {
          #|  action()
          #|}
        ),
      ],
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard [
        "syntax", "resolved", "checked", "buslane.module", "buslane.linked", "buslane.effect-specialized",
      ].contains(stage.id) else {
        return None
      }
      guard stage.state is Completed(snapshot) else { return None }
      Some(
        (
          stage.id,
          snapshot.scale.metrics.map(metric => (metric.id.key(), metric.value)),
          snapshot.scale.modules,
        ),
      )
    })
  debug_inspect(
    (report.status, report.diagnostics, selected),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [
      #|    (
      #|      "syntax",
      #|      [
      #|        ("declarationCount", 3),
      #|        ("importCount", 1),
      #|        ("functionCount", 2),
      #|        ("nodeCount", 15),
      #|        ("callCount", 3),
      #|        ("sourceGenericBinderCount", 0),
      #|        ("sourceTypeApplicationCount", 1),
      #|      ],
      #|      [],
      #|    ),
      #|    (
      #|      "resolved",
      #|      [
      #|        ("declarationCount", 3),
      #|        ("importCount", 1),
      #|        ("functionCount", 2),
      #|        ("nodeCount", 15),
      #|        ("callCount", 3),
      #|        ("sourceGenericBinderCount", 0),
      #|        ("sourceTypeApplicationCount", 1),
      #|      ],
      #|      [],
      #|    ),
      #|    (
      #|      "checked",
      #|      [
      #|        ("declarationCount", 3),
      #|        ("importCount", 1),
      #|        ("functionCount", 2),
      #|        ("nodeCount", 15),
      #|        ("callCount", 3),
      #|        ("sourceGenericBinderCount", 0),
      #|        ("sourceTypeApplicationCount", 1),
      #|      ],
      #|      [],
      #|    ),
      #|    (
      #|      "buslane.module",
      #|      [
      #|        ("topTermCount", 3),
      #|        ("functionCount", 2),
      #|        ("nodeCount", 18),
      #|        ("callCount", 3),
      #|        ("genericBinderCount", 0),
      #|        ("typeApplicationCount", 1),
      #|        ("externalCount", 1),
      #|      ],
      #|      [],
      #|    ),
      #|    (
      #|      "buslane.linked",
      #|      [
      #|        ("topTermCount", 4),
      #|        ("functionCount", 4),
      #|        ("nodeCount", 27),
      #|        ("callCount", 4),
      #|        ("genericBinderCount", 1),
      #|        ("typeApplicationCount", 1),
      #|        ("externalCount", 1),
      #|      ],
      #|      [
      #|        {
      #|          module_path_text: "Lib",
      #|          input_top_terms: 1,
      #|          retained_top_terms: 1,
      #|          input_value_bindings: 2,
      #|          retained_value_bindings: 2,
      #|        },
      #|        {
      #|          module_path_text: "Main",
      #|          input_top_terms: 3,
      #|          retained_top_terms: 3,
      #|          input_value_bindings: 4,
      #|          retained_value_bindings: 4,
      #|        },
      #|      ],
      #|    ),
      #|    (
      #|      "buslane.effect-specialized",
      #|      [
      #|        ("topTermCount", 5),
      #|        ("functionCount", 4),
      #|        ("nodeCount", 26),
      #|        ("callCount", 4),
      #|        ("genericBinderCount", 0),
      #|        ("typeApplicationCount", 0),
      #|        ("externalCount", 1),
      #|      ],
      #|      [],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore reports deterministic typed scale metrics" {
  let request = explore_test_request(
    (
      #|module Main
      #|let observe : (I64) -> Unit ! Io = extern("observe")
      #|
      #|fn apply(f : (I64) -> I64, value : I64) -> I64 {
      #|  f(value)
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  observe(apply(fn(value) { value }, 42))
      #|}
    ),
  )
  let first = explore(request)
  let second = explore(request)
  let first_scales = first.stages.ordered().filter_map(explore_stage_scale)
  let second_scales = second.stages.ordered().filter_map(explore_stage_scale)
  assert_eq(first_scales, second_scales)
  let selected = first_scales.filter_map(fn(scale) {
    if [
        "buslane.effect-specialized", "buslane.core-optimized", "anf", "vmcfg.initial",
        "loisvm.bytecode", "wasm",
      ].contains(scale.0) {
      Some((scale.0, scale.1))
    } else {
      None
    }
  })
  debug_inspect(
    selected,
    content=(
      #|[
      #|  (
      #|    "buslane.effect-specialized",
      #|    [
      #|      ("topTermCount", 3),
      #|      ("functionCount", 3),
      #|      ("nodeCount", 21),
      #|      ("callCount", 3),
      #|      ("genericBinderCount", 0),
      #|      ("typeApplicationCount", 0),
      #|      ("externalCount", 1),
      #|    ],
      #|  ),
      #|  (
      #|    "buslane.core-optimized",
      #|    [
      #|      ("topTermCount", 2),
      #|      ("functionCount", 2),
      #|      ("nodeCount", 13),
      #|      ("callCount", 2),
      #|      ("genericBinderCount", 0),
      #|      ("typeApplicationCount", 0),
      #|      ("externalCount", 1),
      #|    ],
      #|  ),
      #|  (
      #|    "anf",
      #|    [
      #|      ("topTermCount", 2),
      #|      ("functionCount", 2),
      #|      ("nodeCount", 19),
      #|      ("callCount", 2),
      #|      ("genericBinderCount", 0),
      #|      ("typeApplicationCount", 0),
      #|    ],
      #|  ),
      #|  (
      #|    "vmcfg.initial",
      #|    [
      #|      ("functionCount", 2),
      #|      ("importCount", 1),
      #|      ("blockCount", 2),
      #|      ("instructionCount", 2),
      #|      ("valueCount", 4),
      #|      ("directCallCount", 2),
      #|      ("indirectCallCount", 0),
      #|      ("functionReferenceCount", 0),
      #|      ("closureCount", 0),
      #|      ("environmentCount", 0),
      #|      ("eraseCount", 0),
      #|      ("uneraseCount", 0),
      #|      ("retainCount", 0),
      #|      ("releaseCount", 0),
      #|      ("globalCount", 0),
      #|      ("layoutCount", 0),
      #|      ("objectShapeCount", 0),
      #|      ("constantCount", 0),
      #|    ],
      #|  ),
      #|  (
      #|    "loisvm.bytecode",
      #|    [
      #|      ("functionCount", 2),
      #|      ("importCount", 1),
      #|      ("blockCount", 2),
      #|      ("instructionCount", 2),
      #|      ("slotCount", 3),
      #|      ("directCallCount", 2),
      #|      ("indirectCallCount", 0),
      #|      ("functionReferenceCount", 0),
      #|      ("closureCount", 0),
      #|      ("environmentCount", 0),
      #|      ("eraseCount", 0),
      #|      ("uneraseCount", 0),
      #|      ("retainCount", 0),
      #|      ("releaseCount", 0),
      #|      ("callableAbiCount", 3),
      #|      ("globalCount", 0),
      #|      ("layoutCount", 0),
      #|      ("objectShapeCount", 0),
      #|      ("constantCount", 0),
      #|    ],
      #|  ),
      #|  (
      #|    "wasm",
      #|    [
      #|      ("functionCount", 27),
      #|      ("importCount", 1),
      #|      ("instructionCount", 806),
      #|      ("localCount", 34),
      #|      ("tableEntryCount", 8),
      #|    ],
      #|  ),
      #|]
    ),
  )
  let lowered_functions = first_scales.filter_map(fn(scale) {
    if ["anf", "vmcfg.initial", "loisvm.bytecode"].contains(scale.0) {
      Some((scale.0, scale.2))
    } else {
      None
    }
  })
  debug_inspect(
    lowered_functions,
    content=(
      #|[
      #|  (
      #|    "anf",
      #|    [
      #|      { index: 0, block_count: 0, operation_count: 15, value_count: 0 },
      #|      { index: 1, block_count: 0, operation_count: 2, value_count: 1 },
      #|    ],
      #|  ),
      #|  (
      #|    "vmcfg.initial",
      #|    [
      #|      { index: 1, block_count: 1, operation_count: 2, value_count: 3 },
      #|      { index: 2, block_count: 1, operation_count: 0, value_count: 1 },
      #|    ],
      #|  ),
      #|  (
      #|    "loisvm.bytecode",
      #|    [
      #|      { index: 1, block_count: 1, operation_count: 2, value_count: 2 },
      #|      { index: 2, block_count: 1, operation_count: 0, value_count: 1 },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "explore gates direct generic representation specialization" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|let read_flag : () -> Bool ! Io = extern("read_flag")
        #|let touch : () -> Unit ! Io = extern("touch")
        #|
        #|fn[T] consume(flag : Bool, value : T) -> Unit ! Io {
        #|  if flag {
        #|    touch()
        #|  } else {
        #|    consume[T](true, value)
        #|  }
        #|}
        #|
        #|pub fn main() -> Unit ! Io {
        #|  consume[Bool](read_flag(), true)
        #|  consume[I32](read_flag(), 42i32)
        #|}
      ),
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard stage.id == "vmcfg.initial" || stage.id == "loisvm.bytecode" else {
        return None
      }
      explore_stage_scale(stage)
    })
  let workers = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is RepresentationWorker(..))
  })
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      workers.map(node => node.roles),
      selected,
    ),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [[RepresentationWorker(value=Some(2), name=Some("consume"))]],
      #|  [
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 2),
      #|        ("blockCount", 4),
      #|        ("instructionCount", 6),
      #|        ("valueCount", 7),
      #|        ("directCallCount", 6),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 0),
      #|        ("uneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 0),
      #|        ("objectShapeCount", 0),
      #|        ("constantCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 1, operation_count: 5, value_count: 4 },
      #|        { index: 2, block_count: 3, operation_count: 1, value_count: 3 },
      #|      ],
      #|    ),
      #|    (
      #|      "loisvm.bytecode",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 2),
      #|        ("blockCount", 4),
      #|        ("instructionCount", 6),
      #|        ("slotCount", 4),
      #|        ("directCallCount", 6),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 0),
      #|        ("uneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("callableAbiCount", 3),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 0),
      #|        ("objectShapeCount", 0),
      #|        ("constantCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 1, operation_count: 5, value_count: 2 },
      #|        { index: 2, block_count: 3, operation_count: 1, value_count: 2 },
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore records concrete-answer CPS callback representation costs" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|effect Ask {
        #|  ask() -> I64
        #|}
        #|
        #|struct Apply {
        #|  call : [T, Eff : Effect](T, (T) -> T ! Eff) -> T ! Eff
        #|}
        #|
        #|fn[T, Eff : Effect] apply_call(
        #|  value : T,
        #|  callback : (T) -> T ! Eff
        #|) -> T ! Eff {
        #|  callback(value)
        #|}
        #|
        #|fn answer_callback(_value : I64) -> I64 ! Ask {
        #|  Ask::ask!()
        #|}
        #|
        #|fn[Eff : Effect] forwarded(
        #|  callback : (I64) -> I64 ! Eff
        #|) -> I64 ! Eff {
        #|  let apply = Apply::{ call: apply_call }
        #|  apply.call[I64, Eff](0, callback)
        #|}
        #|
        #|pub extern type Host : Effect
        #|let observe : (I64) -> Unit ! Host = extern("observe")
        #|
        #|pub fn main() -> Unit ! Host {
        #|  let result = handle forwarded[{ Ask }](answer_callback) with {
        #|    Ask::ask(resume) => resume(42)
        #|  } final value {
        #|    value
        #|  }
        #|  observe(result)
        #|}
      ),
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard stage.id == "vmcfg.initial" else { return None }
      explore_stage_scale(stage)
    })
  let workers = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is RepresentationWorker(..))
  })
  let adapter_count = report.functions.nodes
    .filter(node => {
      node.function.stage == VmcfgInitial &&
      node.roles.any(role => role is CallableAdapter)
    })
    .length()
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      workers.map(node => node.roles),
      adapter_count,
      selected,
    ),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [
      #|    [AnonymousFunction, RepresentationWorker(value=None, name=None)],
      #|    [RepresentationWorker(value=Some(5), name=Some("apply_call"))],
      #|    [RepresentationWorker(value=Some(26), name=Some("resume"))],
      #|    [RepresentationWorker(value=Some(8), name=Some("answer_callback"))],
      #|  ],
      #|  0,
      #|  [
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 7),
      #|        ("importCount", 1),
      #|        ("blockCount", 7),
      #|        ("instructionCount", 7),
      #|        ("valueCount", 31),
      #|        ("directCallCount", 5),
      #|        ("indirectCallCount", 2),
      #|        ("functionReferenceCount", 3),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 0),
      #|        ("uneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 3),
      #|        ("objectShapeCount", 2),
      #|        ("constantCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 1, operation_count: 1, value_count: 6 },
      #|        { index: 2, block_count: 1, operation_count: 5, value_count: 6 },
      #|        { index: 3, block_count: 1, operation_count: 1, value_count: 5 },
      #|        { index: 4, block_count: 1, operation_count: 0, value_count: 1 },
      #|        { index: 5, block_count: 1, operation_count: 0, value_count: 5 },
      #|        { index: 6, block_count: 1, operation_count: 0, value_count: 4 },
      #|        { index: 7, block_count: 1, operation_count: 0, value_count: 4 },
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "expanding recursive generic demand retains one finite fallback" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|enum Box[T] {
        #|  box(T)
        #|}
        #|
        #|fn[T] expand(value : T) -> Unit {
        #|  expand[Box[T]](Box::box(value))
        #|}
        #|
        #|pub fn main() -> Unit {
        #|  expand[I64](0)
        #|}
      ),
    ),
  )
  let workers = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is RepresentationWorker(..))
  })
  debug_inspect(
    (report.status, report.diagnostics, workers),
    content="(Succeeded, [], [])",
  )
}

///|
test "explore records concrete-answer CPS normalization costs" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|effect Probe {
        #|  ping(I64) -> I64
        #|}
        #|
        #|let add : (I64, I64) -> I64 = extern("add")
        #|let observe : (I64) -> Unit ! Io = extern("observe")
        #|
        #|fn computation() -> I64 ! Probe {
        #|  Probe::ping!(40)
        #|}
        #|
        #|pub fn main() -> Unit ! Io {
        #|  let result = handle computation() with {
        #|    Probe::ping(value, resume) => resume(add(value, 2))
        #|  } final value {
        #|    value
        #|  }
        #|  observe(result)
        #|}
      ),
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard stage.id == "buslane.monadic-lifted" ||
        stage.id == "buslane.cps-core-optimized" ||
        stage.id == "vmcfg.initial" ||
        stage.id == "loisvm.bytecode" else {
        return None
      }
      guard explore_stage_scale(stage) is Some((id, metrics, _)) else {
        return None
      }
      Some(
        (
          id,
          metrics.filter(metric => {
            [
              "topTermCount", "nodeCount", "callCount", "functionCount", "instructionCount",
              "directCallCount", "indirectCallCount", "closureCount", "environmentCount",
              "eraseCount", "uneraseCount",
            ].contains(metric.0)
          }),
        ),
      )
    })
  debug_inspect(
    (report.status, report.diagnostics, selected),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [
      #|    (
      #|      "buslane.monadic-lifted",
      #|      [
      #|        ("topTermCount", 3),
      #|        ("functionCount", 7),
      #|        ("nodeCount", 40),
      #|        ("callCount", 8),
      #|      ],
      #|    ),
      #|    (
      #|      "buslane.cps-core-optimized",
      #|      [
      #|        ("topTermCount", 3),
      #|        ("functionCount", 4),
      #|        ("nodeCount", 31),
      #|        ("callCount", 5),
      #|      ],
      #|    ),
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 4),
      #|        ("instructionCount", 5),
      #|        ("directCallCount", 4),
      #|        ("indirectCallCount", 1),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 0),
      #|        ("uneraseCount", 0),
      #|      ],
      #|    ),
      #|    (
      #|      "loisvm.bytecode",
      #|      [
      #|        ("functionCount", 4),
      #|        ("instructionCount", 5),
      #|        ("directCallCount", 4),
      #|        ("indirectCallCount", 1),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 0),
      #|        ("uneraseCount", 0),
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore keeps expanding recursive representation SCC generic" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|let read_flag : () -> Bool ! Io = extern("read_flag")
        #|
        #|enum Box[T] {
        #|  box(T)
        #|}
        #|
        #|fn[T] grow(flag : Bool, value : T) -> Unit {
        #|  if flag {
        #|    ()
        #|  } else {
        #|    grow[Box[T]](true, Box::box(value))
        #|  }
        #|}
        #|
        #|pub fn main() -> Unit ! Io {
        #|  grow[I64](read_flag(), 42)
        #|}
      ),
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard stage.id == "vmcfg.initial" || stage.id == "loisvm.bytecode" else {
        return None
      }
      explore_stage_scale(stage)
    })
  debug_inspect(
    (report.status, report.diagnostics, selected),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 1),
      #|        ("blockCount", 4),
      #|        ("instructionCount", 10),
      #|        ("valueCount", 16),
      #|        ("directCallCount", 3),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 2),
      #|        ("uneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 3),
      #|        ("objectShapeCount", 1),
      #|        ("constantCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 3, operation_count: 5, value_count: 10 },
      #|        { index: 2, block_count: 1, operation_count: 5, value_count: 6 },
      #|      ],
      #|    ),
      #|    (
      #|      "loisvm.bytecode",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 1),
      #|        ("blockCount", 5),
      #|        ("instructionCount", 11),
      #|        ("slotCount", 12),
      #|        ("directCallCount", 3),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("eraseCount", 2),
      #|        ("uneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 1),
      #|        ("callableAbiCount", 3),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 3),
      #|        ("objectShapeCount", 1),
      #|        ("constantCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 4, operation_count: 6, value_count: 7 },
      #|        { index: 2, block_count: 1, operation_count: 5, value_count: 5 },
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore removes alpha-renamed adapters during CPS core normalization" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|struct Left[T] {
        #|  apply : (T, T) -> T
        #|}
        #|
        #|struct Right[T] {
        #|  apply : (T, T) -> T
        #|}
        #|
        #|let add : (I64, I64) -> I64 = builtin("%i64_add")
        #|let sink : (I64) -> Unit ! Io = extern("sink")
        #|
        #|let left : Left[I64] = Left::{ apply: add }
        #|let right : Right[I64] = Right::{ apply: add }
        #|
        #|pub fn main() -> Unit ! Io {
        #|  sink(add(left.apply(20, 1), right.apply(20, 1)))
        #|}
      ),
    ),
  )
  let adapter_roles = report.functions.nodes.filter_map(node => {
    guard node.function.stage == VmcfgInitial &&
      node.roles.any(role => role is CallableAdapter) else {
      return None
    }
    Some(node.roles)
  })
  debug_inspect(
    (report.status, report.diagnostics, adapter_roles),
    content=(
      #|(Succeeded, [], [])
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
      #|    ("buslane.core-optimized", "unavailable"),
      #|    ("buslane.handlers-elaborated", "unavailable"),
      #|    ("buslane.monadic", "unavailable"),
      #|    ("buslane.selective-cps", "unavailable"),
      #|    ("buslane.open-context-resolved", "unavailable"),
      #|    ("buslane.monadic-lifted", "unavailable"),
      #|    ("buslane.cps-core-optimized", "unavailable"),
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
      #|    ("buslane.core-optimized", "unavailable"),
      #|    ("buslane.handlers-elaborated", "unavailable"),
      #|    ("buslane.monadic", "unavailable"),
      #|    ("buslane.selective-cps", "unavailable"),
      #|    ("buslane.open-context-resolved", "unavailable"),
      #|    ("buslane.monadic-lifted", "unavailable"),
      #|    ("buslane.cps-core-optimized", "unavailable"),
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
      #|    ("buslane.core-optimized", "unavailable"),
      #|    ("buslane.handlers-elaborated", "unavailable"),
      #|    ("buslane.monadic", "unavailable"),
      #|    ("buslane.selective-cps", "unavailable"),
      #|    ("buslane.open-context-resolved", "unavailable"),
      #|    ("buslane.monadic-lifted", "unavailable"),
      #|    ("buslane.cps-core-optimized", "unavailable"),
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
      #|      ("buslane.core-optimized", "unavailable"),
      #|      ("buslane.handlers-elaborated", "unavailable"),
      #|      ("buslane.monadic", "unavailable"),
      #|      ("buslane.selective-cps", "unavailable"),
      #|      ("buslane.open-context-resolved", "unavailable"),
      #|      ("buslane.monadic-lifted", "unavailable"),
      #|      ("buslane.cps-core-optimized", "unavailable"),
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
      #|      ("buslane.core-optimized", "unavailable"),
      #|      ("buslane.handlers-elaborated", "unavailable"),
      #|      ("buslane.monadic", "unavailable"),
      #|      ("buslane.selective-cps", "unavailable"),
      #|      ("buslane.open-context-resolved", "unavailable"),
      #|      ("buslane.monadic-lifted", "unavailable"),
      #|      ("buslane.cps-core-optimized", "unavailable"),
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

///|
test "explore traces a named function and preserves synthetic roots" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|fn helper() -> Unit { () }
        #|pub fn main() -> Unit { helper() }
      ),
    ),
  )
  let source_nodes = report.functions.nodes.filter(node => {
    node.roles.any(role => role is SourceFunction(name=Some("main"), ..))
  })
  guard source_nodes is [source, ..] else {
    fail("missing named source provenance root")
  }
  let lineage = [source.function]
  for edge in report.functions.edges {
    if lineage.contains(edge.source) && !lineage.contains(edge.target) {
      lineage.push(edge.target)
    }
  }
  let traced = lineage.map(function => {
    let roles = report.functions.nodes.filter_map(node => {
      if node.function == function {
        Some(node.roles)
      } else {
        None
      }
    })
    (function, roles)
  })
  let entry_wrappers = report.functions.nodes.filter(node => {
    node.roles.contains(EntryWrapper)
  })
  debug_inspect(
    (
      report.schema_version,
      traced,
      entry_wrappers,
      report.functions.edges.any(edge => {
        entry_wrappers.any(node => edge.target == node.function)
      }),
    ),
    content=(
      #|(
      #|  6,
      #|  [
      #|    (
      #|      { stage: Anf, index: 0 },
      #|      [[SourceFunction(value=1, name=Some("main"))]],
      #|    ),
      #|    (
      #|      { stage: VmcfgInitial, index: 1 },
      #|      [[SourceFunction(value=1, name=Some("main"))]],
      #|    ),
      #|    (
      #|      { stage: LoisvmBytecode, index: 1 },
      #|      [[SourceFunction(value=1, name=Some("main"))]],
      #|    ),
      #|    ({ stage: Wasm, index: 0 }, [[WasmBytecodeFunction]]),
      #|  ],
      #|  [{ function: { stage: Wasm, index: 24 }, roles: [EntryWrapper] }],
      #|  false,
      #|)
    ),
  )
}

///|
test "every Explore function scale consumes an IR-owned identity" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|let observe : (I64) -> Unit ! Io = extern("observe")
        #|fn apply(f : (I64) -> I64, value : I64) -> I64 { f(value) }
        #|pub fn main() -> Unit ! Io {
        #|  observe(apply(fn(value) { value }, 42))
        #|}
      ),
    ),
  )
  let missing = []
  for stage in report.stages.ordered() {
    guard stage.state is Completed(snapshot) else { continue }
    for function in snapshot.scale.functions {
      if !report.functions.nodes.any(node => {
          node.function.stage.key() == stage.id &&
          node.function.index == function.index
        }) {
        missing.push((stage.id, function.index))
      }
    }
  }
  debug_inspect(missing, content="[]")
  let identityless_stages = [
    "buslane.module", "buslane.linked", "buslane.effect-specialized", "buslane.core-optimized",
    "buslane.handlers-elaborated", "buslane.monadic", "buslane.selective-cps", "buslane.open-context-resolved",
    "buslane.monadic-lifted", "buslane.cps-core-optimized", "executable",
  ]
  let identityless_function_scales = report.stages
    .ordered()
    .filter_map(stage => {
      guard identityless_stages.contains(stage.id) else { return None }
      guard stage.state is Completed(snapshot) else { return None }
      Some((stage.id, snapshot.scale.functions))
    })
  debug_inspect(
    identityless_function_scales,
    content=(
      #|[
      #|  ("buslane.module", []),
      #|  ("buslane.linked", []),
      #|  ("buslane.effect-specialized", []),
      #|  ("buslane.core-optimized", []),
      #|  ("buslane.handlers-elaborated", []),
      #|  ("buslane.monadic", []),
      #|  ("buslane.selective-cps", []),
      #|  ("buslane.open-context-resolved", []),
      #|  ("buslane.monadic-lifted", []),
      #|  ("buslane.cps-core-optimized", []),
      #|  ("executable", []),
      #|]
    ),
  )
}
