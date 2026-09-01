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
test "Explore preserves source-written nested and CPS-introduced function origins" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|effect Ask {
        #|  ask() -> I64
        #|}
        #|
        #|fn[Eff : Effect] invoke(
        #|  callback : (I64) -> I64 ! Eff
        #|) -> I64 ! Eff {
        #|  callback(0)
        #|}
        #|
        #|pub extern type Host : Effect
        #|let observe : (I64) -> Unit ! Host = extern("lane.test", "observe")
        #|
        #|pub fn main() -> Unit ! Host {
        #|  let result = handle invoke[{ Ask }](fn(_value) {
        #|    let asked = Ask::ask!()
        #|    asked
        #|  }) with {
        #|    Ask::ask(resume) => resume(42)
        #|  } final value {
        #|    value
        #|  }
        #|  observe(result)
        #|}
      ),
    ),
  )
  let anf_roles = report.functions.nodes.filter_map(node => {
    if node.function.stage == Anf {
      Some(node.roles)
    } else {
      None
    }
  })
  debug_inspect(
    anf_roles,
    content=(
      #|[
      #|  [SourceFunction(value=3, name=Some("main")), RuntimeAnfTopLevelRoot],
      #|  [SelectiveCpsFunction, RuntimeAnfEscapingClosure],
      #|  [
      #|    SourceFunction(value=13, name=Some("function_literal")),
      #|    RuntimeAnfEscapingClosure,
      #|  ],
      #|  [MonadicTransformationFunction, RuntimeAnfEscapingClosure],
      #|  [HandlerElaborationFunction, RuntimeAnfEscapingClosure],
      #|]
    ),
  )
}

///|
test "explore protocol v11 exposes all eighteen ordered completed stages" {
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
      #|  11,
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
      #|      "physical",
      #|      "completed",
      #|      Some("compiler"),
      #|      Some("physical-program"),
      #|      Some("function f1 abi=abi0("),
      #|    ),
      #|    ("wasm", "completed", Some("backend"), Some("wat"), Some("(module")),
      #|  ],
      #|)
    ),
  )
}

///|
test "Explore records selective byte-buffer Wasm support" {
  let scale_keys = [
    "functionCount", "importCount", "instructionCount", "slotCount", "layoutCount",
    "localCount", "unreachableWasmSupportRoleCount",
  ]
  let pure = explore(
    explore_test_request(
      (
        #|module Pure
        #|
        #|pub fn main() -> Unit {
        #|  ()
        #|}
      ),
    ),
  )
  let pure_scales = pure.stages
    .ordered()
    .filter_map(stage => {
      if stage.id != "physical" && stage.id != "wasm" {
        return None
      }
      explore_stage_scale(stage).map(scale => {
        (scale.0, scale.1.filter(metric => scale_keys.contains(metric.0)))
      })
    })
  let pure_wasm_roles = pure.functions.nodes.filter_map(node => {
    if node.function.stage == Wasm {
      Some(node.roles)
    } else {
      None
    }
  })
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|let make : (I64) -> ByteBuffer ! Io = builtin("%byte_buffer_make")
        #|let write : (ByteBuffer, I64, I32) -> Unit ! Io =
        #|  builtin("%byte_buffer_write_i32")
        #|let read : (ByteBuffer, I64) -> I32 ! Io =
        #|  builtin("%byte_buffer_read_i32")
        #|
        #|pub fn main() -> Unit ! Io {
        #|  let buffer = make(4)
        #|  write(buffer, 0, 42i32)
        #|  let _value = read(buffer, 0)
        #|  ()
        #|}
      ),
    ),
  )
  let scales = report.stages
    .ordered()
    .filter_map(stage => {
      if stage.id != "physical" && stage.id != "wasm" {
        return None
      }
      explore_stage_scale(stage).map(scale => {
        (scale.0, scale.1.filter(metric => scale_keys.contains(metric.0)))
      })
    })
  let wasm_roles = report.functions.nodes.filter_map(node => {
    if node.function.stage == Wasm {
      Some(node.roles)
    } else {
      None
    }
  })
  debug_inspect(
    (
      pure.status,
      pure_scales,
      pure_wasm_roles,
      report.status,
      scales,
      wasm_roles,
    ),
    content=(
      #|(
      #|  Succeeded,
      #|  [
      #|    (
      #|      "physical",
      #|      [
      #|        ("functionCount", 1),
      #|        ("importCount", 0),
      #|        ("instructionCount", 0),
      #|        ("slotCount", 0),
      #|        ("layoutCount", 0),
      #|      ],
      #|    ),
      #|    (
      #|      "wasm",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 0),
      #|        ("instructionCount", 4),
      #|        ("localCount", 0),
      #|        ("unreachableWasmSupportRoleCount", 0),
      #|      ],
      #|    ),
      #|  ],
      #|  [[WasmPhysicalFunction], [EntryWrapper]],
      #|  Succeeded,
      #|  [
      #|    (
      #|      "physical",
      #|      [
      #|        ("functionCount", 1),
      #|        ("importCount", 0),
      #|        ("instructionCount", 7),
      #|        ("slotCount", 3),
      #|        ("layoutCount", 1),
      #|      ],
      #|    ),
      #|    (
      #|      "wasm",
      #|      [
      #|        ("functionCount", 14),
      #|        ("importCount", 0),
      #|        ("instructionCount", 330),
      #|        ("localCount", 17),
      #|        ("unreachableWasmSupportRoleCount", 0),
      #|      ],
      #|    ),
      #|  ],
      #|  [
      #|    [WasmPhysicalFunction],
      #|    [WasmRuntimeFunction(name="allocate")],
      #|    [WasmRuntimeFunction(name="free")],
      #|    [WasmRuntimeFunction(name="retain reference")],
      #|    [WasmRuntimeFunction(name="release reference")],
      #|    [WasmRuntimeFunction(name="byte buffer make")],
      #|    [WasmRuntimeFunction(name="require byte buffer layout")],
      #|    [WasmRuntimeFunction(name="byte buffer write i32")],
      #|    [WasmRuntimeFunction(name="byte buffer read i32")],
      #|    [WasmHelperFunction(name="retain reference erased", ordinal=None)],
      #|    [WasmHelperFunction(name="release reference erased", ordinal=None)],
      #|    [WasmHelperFunction(name="destroy noop", ordinal=None)],
      #|    [WasmHelperFunction(name="byte storage sizer", ordinal=None)],
      #|    [EntryWrapper],
      #|  ],
      #|)
    ),
  )
}

///|
test "explore attributes link growth and effect-specialization cleanup" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|import Lib.{ live, invoke }
        #|let observe : (I64) -> Unit ! Io = extern("lane.test", "observe")
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
      #|let observe : (I64) -> Unit ! Io = extern("lane.test", "observe")
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
        "physical", "wasm",
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
      #|      ("valueCount", 3),
      #|      ("directCallCount", 2),
      #|      ("indirectCallCount", 0),
      #|      ("functionReferenceCount", 0),
      #|      ("closureCount", 0),
      #|      ("environmentCount", 0),
      #|      ("genericAbiEraseCount", 0),
      #|      ("genericAbiUneraseCount", 0),
      #|      ("retainCount", 0),
      #|      ("releaseCount", 0),
      #|      ("globalCount", 0),
      #|      ("layoutCount", 0),
      #|      ("objectShapeCount", 0),
      #|      ("constantCount", 0),
      #|    ],
      #|  ),
      #|  (
      #|    "physical",
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
      #|      ("genericAbiEraseCount", 0),
      #|      ("genericAbiUneraseCount", 0),
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
      #|      ("functionCount", 4),
      #|      ("importCount", 1),
      #|      ("instructionCount", 18),
      #|      ("localCount", 3),
      #|      ("tableEntryCount", 0),
      #|      ("wasmIfCount", 0),
      #|      ("wasmUnreachableCount", 0),
      #|      ("unreachableWasmSupportRoleCount", 0),
      #|      ("wasmExpansion.physicalStorage.localCount", 3),
      #|      ("wasmExpansion.physicalOpcode.scalar.instructionCount", 2),
      #|      ("wasmExpansion.physicalOpcode.callable.instructionCount", 4),
      #|      ("wasmExpansion.physicalOpcode.controlTransfer.instructionCount", 5),
      #|      ("wasmExpansion.functionAbi.instructionCount", 2),
      #|      ("wasmExpansion.runtimeImportAdapter.instructionCount", 2),
      #|      ("wasmExpansion.entryLifecycle.instructionCount", 3),
      #|    ],
      #|  ),
      #|]
    ),
  )
  let lowered_functions = first_scales.filter_map(fn(scale) {
    if ["anf", "vmcfg.initial", "physical"].contains(scale.0) {
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
      #|      { index: 1, block_count: 1, operation_count: 2, value_count: 2 },
      #|      { index: 2, block_count: 1, operation_count: 0, value_count: 1 },
      #|    ],
      #|  ),
      #|  (
      #|    "physical",
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
test "explore lowers nested handlers through a finite recursive callable contract graph" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|effect Ask {
        #|  read() -> I64
        #|}
        #|
        #|effect Log {
        #|  write(I64) -> Unit
        #|}
        #|
        #|fn task() -> I64 ! { Ask, Log } {
        #|  let value = Ask::read!()
        #|  let _written = Log::write!(value)
        #|  value
        #|}
        #|
        #|fn run() -> I64 {
        #|  handle {
        #|    handle task() with {
        #|      Ask::read(resume) => resume(40)
        #|    } final value {
        #|      value
        #|    }
        #|  } with {
        #|    Log::write(_value, resume) => resume(())
        #|  } final value {
        #|    value
        #|  }
        #|}
        #|
        #|pub extern type Host : Effect
        #|let observe : (I64) -> Unit ! Host = extern("lane.test", "observe")
        #|
        #|pub fn main() -> Unit ! Host {
        #|  observe(run())
        #|}
      ),
    ),
  )
  assert_true(report.status is Succeeded)
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      if [
          "buslane.cps-core-optimized", "anf", "vmcfg.initial", "physical", "wasm",
        ].contains(stage.id) {
        explore_stage_scale(stage).map(scale => {
          (
            scale.0,
            scale.1.filter(metric => {
              [
                "functionCount", "callCount", "instructionCount", "directCallCount",
                "indirectCallCount", "closureCount", "environmentCount", "genericAbiEraseCount",
                "genericAbiUneraseCount", "callableAbiCount", "duplicateRuntimeAbiWorkerCount",
                "tableEntryCount",
              ].contains(metric.0)
            }),
          )
        })
      } else {
        None
      }
    })
  debug_inspect(
    selected,
    content=(
      #|[
      #|  (
      #|    "buslane.cps-core-optimized",
      #|    [("functionCount", 10), ("callCount", 10)],
      #|  ),
      #|  ("anf", [("functionCount", 10), ("callCount", 10)]),
      #|  (
      #|    "vmcfg.initial",
      #|    [
      #|      ("functionCount", 21),
      #|      ("instructionCount", 109),
      #|      ("directCallCount", 12),
      #|      ("indirectCallCount", 9),
      #|      ("closureCount", 16),
      #|      ("environmentCount", 18),
      #|      ("genericAbiEraseCount", 8),
      #|      ("genericAbiUneraseCount", 8),
      #|      ("duplicateRuntimeAbiWorkerCount", 0),
      #|    ],
      #|  ),
      #|  (
      #|    "physical",
      #|    [
      #|      ("functionCount", 21),
      #|      ("instructionCount", 118),
      #|      ("directCallCount", 12),
      #|      ("indirectCallCount", 9),
      #|      ("closureCount", 16),
      #|      ("environmentCount", 18),
      #|      ("genericAbiEraseCount", 8),
      #|      ("genericAbiUneraseCount", 8),
      #|      ("callableAbiCount", 14),
      #|      ("duplicateRuntimeAbiWorkerCount", 0),
      #|    ],
      #|  ),
      #|  (
      #|    "wasm",
      #|    [
      #|      ("functionCount", 41),
      #|      ("instructionCount", 1222),
      #|      ("tableEntryCount", 32),
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "explore records closed recursive representation specialization" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|let read_flag : () -> I32 ! Io = extern("lane.test", "read_flag")
        #|let touch : () -> Unit ! Io = extern("lane.test", "touch")
        #|let i32_equal : (I32, I32) -> Bool = builtin("%i32_equal")
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
        #|  consume[Bool](i32_equal(read_flag(), 0i32), true)
        #|  consume[I32](i32_equal(read_flag(), 0i32), 42i32)
        #|}
      ),
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard stage.id == "vmcfg.initial" || stage.id == "physical" else {
        return None
      }
      explore_stage_scale(stage)
    })
  let adapters = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is CallableAdapter(..))
  })
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      adapters.map(node => node.roles),
      selected,
    ),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [],
      #|  [
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 2),
      #|        ("blockCount", 4),
      #|        ("instructionCount", 9),
      #|        ("valueCount", 11),
      #|        ("directCallCount", 6),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 0),
      #|        ("genericAbiUneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 0),
      #|        ("objectShapeCount", 0),
      #|        ("constantCount", 0),
      #|        ("duplicateRuntimeAbiWorkerCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 1, operation_count: 8, value_count: 8 },
      #|        { index: 2, block_count: 3, operation_count: 1, value_count: 3 },
      #|      ],
      #|    ),
      #|    (
      #|      "physical",
      #|      [
      #|        ("functionCount", 2),
      #|        ("importCount", 2),
      #|        ("blockCount", 4),
      #|        ("instructionCount", 9),
      #|        ("slotCount", 5),
      #|        ("directCallCount", 6),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 0),
      #|        ("genericAbiUneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("callableAbiCount", 3),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 0),
      #|        ("objectShapeCount", 0),
      #|        ("constantCount", 0),
      #|        ("duplicateRuntimeAbiWorkerCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 1, operation_count: 8, value_count: 3 },
      #|        { index: 2, block_count: 3, operation_count: 1, value_count: 2 },
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore records elimination of concrete-answer callback representation costs" {
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
        #|let observe : (I64) -> Unit ! Host = extern("lane.test", "observe")
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
  let adapters = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is CallableAdapter(..))
  })
  let adapter_count = report.functions.nodes
    .filter(node => {
      node.function.stage == VmcfgInitial &&
      node.roles.any(role => role is CallableAdapter(..))
    })
    .length()
  let mut indirect_calls = []
  for stage in report.stages.ordered() {
    if stage.id == "vmcfg.initial" && stage.state is Completed(snapshot) {
      indirect_calls = snapshot.indirect_calls
    }
  }
  let source_calls = indirect_calls
    .filter(call => call.origins.contains(SourceBound))
    .length()
  let adapter_calls = indirect_calls
    .filter(call => call.origins.contains(CallableAdapter))
    .length()
  let exact_packed_calls = indirect_calls
    .filter(call => call.resolution is ExactTarget(_, Packed))
    .length()
  assert_eq(
    (
      indirect_calls.length(),
      source_calls,
      adapter_calls,
      exact_packed_calls,
      indirect_calls.any(call => call.boundaries.is_empty()),
    ),
    (0, 0, 0, 0, false),
  )
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      adapters.map(node => node.roles),
      adapter_count,
      selected,
    ),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  [],
      #|  0,
      #|  [
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 1),
      #|        ("importCount", 1),
      #|        ("blockCount", 1),
      #|        ("instructionCount", 1),
      #|        ("valueCount", 1),
      #|        ("directCallCount", 1),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 0),
      #|        ("genericAbiUneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 0),
      #|        ("objectShapeCount", 0),
      #|        ("constantCount", 0),
      #|      ],
      #|      [{ index: 1, block_count: 1, operation_count: 1, value_count: 1 }],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "expanding recursive generic application uses one finite worker and fallback" {
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
  let adapters = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is CallableAdapter(..))
  })
  let workers = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is RepresentationWorker)
  })
  assert_eq(
    (report.status, report.diagnostics, adapters.length(), workers.length()),
    (Succeeded, [], 0, 1),
  )
}

///|
test "explore attributes a closed effect worker nominal ABI crossing" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|
        #|effect Tick {
        #|  tick(I64) -> I64
        #|}
        #|
        #|let record_callback : () -> Unit ! Io = extern("lane.test", "record_callback")
        #|let observe : (I64) -> Unit ! Io = extern("lane.test", "observe")
        #|
        #|fn[T, R, Eff : Effect] apply(
        #|  value : T,
        #|  callback : (T) -> R ! Eff
        #|) -> R ! Eff {
        #|  callback(value)
        #|}
        #|
        #|fn[T, R, Eff : Effect] forward(
        #|  value : T,
        #|  callback : (T) -> R ! Eff
        #|) -> R ! Eff {
        #|  apply[T, R, Eff](value, callback)
        #|}
        #|
        #|fn increment_mixed(value : I64) -> I64 ! { Tick, Io } {
        #|  record_callback()
        #|  Tick::tick!(value)
        #|}
        #|
        #|pub fn main() -> Unit ! Io {
        #|  let direct = handle apply[I64, I64, { Tick, Io }](41, increment_mixed) with {
        #|    Tick::tick(value, resume) => resume(value)
        #|  } final value {
        #|    value
        #|  }
        #|  observe(direct)
        #|  let forwarded = handle forward[I64, I64, { Tick, Io }](41, increment_mixed) with {
        #|    Tick::tick(value, resume) => resume(value)
        #|  } final value {
        #|    value
        #|  }
        #|  observe(forwarded)
        #|}
      ),
    ),
  )
  let workers = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is RepresentationWorker)
  })
  let adapters = report.functions.nodes.filter(node => {
    node.function.stage == VmcfgInitial &&
    node.roles.any(role => role is CallableAdapter(..))
  })
  let mut metrics = []
  let mut worker_calls = []
  for stage in report.stages.ordered() {
    if stage.id == "vmcfg.initial" && stage.state is Completed(snapshot) {
      metrics = snapshot.scale.metrics
        .filter(metric => {
          metric.id.key() == "directCallCount" ||
          metric.id.key() == "indirectCallCount" ||
          metric.id.key() == "genericAbiEraseCount" ||
          metric.id.key() == "genericAbiUneraseCount"
        })
        .map(metric => (metric.id.key(), metric.value))
      worker_calls = snapshot.indirect_calls.filter(call => {
        call.origins.contains(RepresentationWorker)
      })
    }
  }
  debug_inspect(
    (
      report.status,
      report.diagnostics,
      workers.length(),
      adapters.length(),
      metrics,
      worker_calls.map(call => {
        (
          call.origins,
          call.resolution is ExactTarget(_, Packed),
          call.boundaries,
        )
      }),
    ),
    content=(
      #|(
      #|  Succeeded,
      #|  [],
      #|  1,
      #|  3,
      #|  [
      #|    ("directCallCount", 8),
      #|    ("indirectCallCount", 2),
      #|    ("genericAbiEraseCount", 2),
      #|    ("genericAbiUneraseCount", 2),
      #|  ],
      #|  [],
      #|)
    ),
  )
}

///|
test "explore records concrete-answer CPS cleanup after scalar replacement" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|effect Probe {
        #|  ping(I64) -> I64
        #|}
        #|
        #|let add : (I64, I64) -> I64 = extern("lane.test", "add")
        #|let observe : (I64) -> Unit ! Io = extern("lane.test", "observe")
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
        stage.id == "physical" else {
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
              "genericAbiEraseCount", "genericAbiUneraseCount",
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
      #|        ("functionCount", 1),
      #|        ("nodeCount", 13),
      #|        ("callCount", 2),
      #|      ],
      #|    ),
      #|    (
      #|      "vmcfg.initial",
      #|      [
      #|        ("functionCount", 1),
      #|        ("instructionCount", 3),
      #|        ("directCallCount", 2),
      #|        ("indirectCallCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 0),
      #|        ("genericAbiUneraseCount", 0),
      #|      ],
      #|    ),
      #|    (
      #|      "physical",
      #|      [
      #|        ("functionCount", 1),
      #|        ("instructionCount", 3),
      #|        ("directCallCount", 2),
      #|        ("indirectCallCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 0),
      #|        ("genericAbiUneraseCount", 0),
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}

///|
test "explore bounds expanding recursive specialization to one worker" {
  let report = explore(
    explore_test_request(
      (
        #|module Main
        #|let read_flag : () -> I32 ! Io = extern("lane.test", "read_flag")
        #|let i32_equal : (I32, I32) -> Bool = builtin("%i32_equal")
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
        #|  grow[I64](i32_equal(read_flag(), 0i32), 42)
        #|  grow[I64](i32_equal(read_flag(), 0i32), 7)
        #|}
      ),
    ),
  )
  let selected = report.stages
    .ordered()
    .filter_map(stage => {
      guard stage.id == "vmcfg.initial" || stage.id == "physical" else {
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
      #|        ("functionCount", 3),
      #|        ("importCount", 1),
      #|        ("blockCount", 7),
      #|        ("instructionCount", 20),
      #|        ("valueCount", 26),
      #|        ("directCallCount", 6),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 3),
      #|        ("genericAbiUneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 0),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 3),
      #|        ("objectShapeCount", 1),
      #|        ("constantCount", 0),
      #|        ("duplicateRuntimeAbiWorkerCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 3, operation_count: 5, value_count: 9 },
      #|        { index: 2, block_count: 1, operation_count: 8, value_count: 8 },
      #|        { index: 3, block_count: 3, operation_count: 7, value_count: 9 },
      #|      ],
      #|    ),
      #|    (
      #|      "physical",
      #|      [
      #|        ("functionCount", 3),
      #|        ("importCount", 1),
      #|        ("blockCount", 8),
      #|        ("instructionCount", 21),
      #|        ("slotCount", 18),
      #|        ("directCallCount", 6),
      #|        ("indirectCallCount", 0),
      #|        ("functionReferenceCount", 0),
      #|        ("closureCount", 0),
      #|        ("environmentCount", 0),
      #|        ("genericAbiEraseCount", 3),
      #|        ("genericAbiUneraseCount", 0),
      #|        ("retainCount", 0),
      #|        ("releaseCount", 1),
      #|        ("callableAbiCount", 4),
      #|        ("globalCount", 0),
      #|        ("layoutCount", 3),
      #|        ("objectShapeCount", 1),
      #|        ("constantCount", 0),
      #|        ("duplicateRuntimeAbiWorkerCount", 0),
      #|      ],
      #|      [
      #|        { index: 1, block_count: 4, operation_count: 6, value_count: 7 },
      #|        { index: 2, block_count: 1, operation_count: 8, value_count: 4 },
      #|        { index: 3, block_count: 3, operation_count: 7, value_count: 7 },
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
        #|let sink : (I64) -> Unit ! Io = extern("lane.test", "sink")
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
      node.roles.any(role => role is CallableAdapter(..)) else {
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
      #|    ("physical", "unavailable"),
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
      #|    ("physical", "unavailable"),
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
      #|    ("physical", "unavailable"),
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
      #|      ("physical", "unavailable"),
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
      #|      ("physical", "unavailable"),
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
      #|  11,
      #|  [
      #|    (
      #|      { stage: Anf, index: 0 },
      #|      [[SourceFunction(value=1, name=Some("main")), RuntimeAnfTopLevelRoot]],
      #|    ),
      #|    (
      #|      { stage: VmcfgInitial, index: 1 },
      #|      [[SourceFunction(value=1, name=Some("main"))]],
      #|    ),
      #|    (
      #|      { stage: PhysicalProgram, index: 1 },
      #|      [[SourceFunction(value=1, name=Some("main"))]],
      #|    ),
      #|    ({ stage: Wasm, index: 0 }, [[WasmPhysicalFunction]]),
      #|  ],
      #|  [{ function: { stage: Wasm, index: 1 }, roles: [EntryWrapper] }],
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
        #|let observe : (I64) -> Unit ! Io = extern("lane.test", "observe")
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
