///|
test "explorer HTML escaping covers markup and attributes" {
  inspect(escape_html("<&>\"'"), content="&lt;&amp;&gt;&quot;&#39;")
}

///|
test "explorer HTML renders stage navigation and escaped code" {
  let report : @driver.ExploreReport = {
    schema_version: 4,
    compiler: { name: "Milky2018/lanec", version: "0.1.0" },
    root: { source_id: "<root>", module_path_text: Some("Main") },
    selected_entry: None,
    status: Failed(Resolved),
    diagnostics: [],
    functions: { nodes: [], edges: [] },
    stages: {
      syntax: Completed({
        domain: Compiler,
        text_format: Lane,
        text: "let answer = 42\n<&>",
        diagnostics: [],
        scale: { metrics: [], functions: [] },
      }),
      resolved: Failed([]),
      checked: Unavailable,
      buslane_module: Unavailable,
      buslane_linked: Unavailable,
      buslane_effect_specialized: Unavailable,
      buslane_handlers_elaborated: Unavailable,
      buslane_monadic: Unavailable,
      buslane_selective_cps: Unavailable,
      buslane_open_context_resolved: Unavailable,
      buslane_monadic_lifted: Unavailable,
      buslane_core_optimized: Unavailable,
      buslane_cps_core_optimized: Unavailable,
      executable: Unavailable,
      anf: Unavailable,
      vmcfg_initial: Unavailable,
      loisvm_bytecode: Unavailable,
      wasm: Unavailable,
    },
  }
  inspect(
    render_explore_html(report),
    content=(
      #|<!doctype html>
      #|<html lang="en">
      #|<head>
      #|<meta charset="utf-8">
      #|<meta name="viewport" content="width=device-width, initial-scale=1">
      #|<title>Lane IR Explorer</title>
      #|<style>
      #|:root{color-scheme:dark;--bg:#0b1020;--panel:#111831;--line:#263152;--text:#e7ecff;--accent:#8aa4ff}
      #|*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 ui-sans-serif,system-ui,sans-serif}
      #|main{display:grid;grid-template-columns:minmax(220px,300px) 1fr;min-height:100vh}nav{padding:16px;border-right:1px solid var(--line);overflow:auto}
      #|button{display:block;width:100%;margin:0 0 8px;padding:10px 12px;border:1px solid var(--line);border-radius:8px;background:var(--panel);color:var(--text);text-align:left;cursor:pointer}
      #|button[aria-selected="true"]{border-color:var(--accent);color:#fff}.content{min-width:0;padding:20px 24px}.stage{display:none}.stage.active{display:block}
      #|pre{margin:0;padding:18px;border:1px solid var(--line);border-radius:10px;background:#080d1a;color:#dce5ff;overflow:auto;white-space:pre;tab-size:2}
      #|.observations{display:grid;gap:14px;margin:0 0 16px}.metrics{display:flex;flex-wrap:wrap;gap:8px}.metric{padding:7px 10px;border:1px solid var(--line);border-radius:8px;background:var(--panel)}
      #|table{width:100%;border-collapse:collapse;background:var(--panel)}th,td{padding:8px 10px;border:1px solid var(--line);text-align:left;vertical-align:top}th{color:var(--accent)}
      #|@media(max-width:760px){main{grid-template-columns:1fr}nav{border-right:0;border-bottom:1px solid var(--line)}}
      #|</style>
      #|</head>
      #|<body>
      #|<main><nav><button type="button" role="tab" aria-selected="true" data-stage="syntax" data-status="completed">Syntax AST</button><button type="button" role="tab" aria-selected="false" data-stage="resolved" data-status="failed">Resolved AST</button><button type="button" role="tab" aria-selected="false" data-stage="checked" data-status="unavailable">Checked Source AST</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.module" data-status="unavailable">Buslane (Module Lowering)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.linked" data-status="unavailable">Buslane (Linking)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.effect-specialized" data-status="unavailable">Buslane (Reachable Effect Specialization)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.core-optimized" data-status="unavailable">Buslane (Effect-Aware Core Optimization)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.handlers-elaborated" data-status="unavailable">Buslane (Handler Elaboration)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.monadic" data-status="unavailable">Buslane (Monadic Transformation)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.selective-cps" data-status="unavailable">Buslane (Selective CPS)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.open-context-resolved" data-status="unavailable">Buslane (Open Context Resolution)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.monadic-lifted" data-status="unavailable">Buslane (Monadic Lift)</button><button type="button" role="tab" aria-selected="false" data-stage="buslane.cps-core-optimized" data-status="unavailable">Buslane (CPS Core Optimized)</button><button type="button" role="tab" aria-selected="false" data-stage="executable" data-status="unavailable">Executable Program (Effect-Aware CPS Core)</button><button type="button" role="tab" aria-selected="false" data-stage="anf" data-status="unavailable">Runtime ANF (Effect Projection)</button><button type="button" role="tab" aria-selected="false" data-stage="vmcfg.initial" data-status="unavailable">VM CFG (Initial Lowering)</button><button type="button" role="tab" aria-selected="false" data-stage="loisvm.bytecode" data-status="unavailable">LoisVM Bytecode (ARC and Slot Finalization)</button><button type="button" role="tab" aria-selected="false" data-stage="wasm" data-status="unavailable">Wasm (LoisVM Backend Lowering)</button></nav><div class="content"><section class="stage active" data-stage="syntax"><pre>let answer = 42
      #|&lt;&amp;&gt;</pre></section><section class="stage" data-stage="resolved"><pre>Stage failed. See compiler diagnostics.</pre></section><section class="stage" data-stage="checked"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.module"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.linked"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.effect-specialized"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.core-optimized"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.handlers-elaborated"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.monadic"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.selective-cps"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.open-context-resolved"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.monadic-lifted"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="buslane.cps-core-optimized"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="executable"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="anf"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="vmcfg.initial"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="loisvm.bytecode"><pre>Unavailable because an earlier stage failed.</pre></section><section class="stage" data-stage="wasm"><pre>Unavailable because an earlier stage failed.</pre></section></div></main>
      #|<script>
      #|const buttons=[...document.querySelectorAll('button[data-stage]')];
      #|const stages=[...document.querySelectorAll('.stage[data-stage]')];
      #|for(const button of buttons){button.addEventListener('click',()=>{const id=button.dataset.stage;for(const item of buttons)item.setAttribute('aria-selected',String(item===button));for(const stage of stages)stage.classList.toggle('active',stage.dataset.stage===id);});}
      #|</script>
      #|</body>
      #|</html>
    ),
  )
}

///|
test "explorer renders typed metrics and explicit function lineage" {
  let html = StringBuilder::new()
  let stage : @driver.ExploreStage = {
    id: "anf",
    title: "ANF",
    state: Completed({
      domain: Compiler,
      text_format: Anf,
      text: "",
      diagnostics: [],
      scale: {
        metrics: [{ id: FunctionCount, value: 1 }],
        functions: [
          { index: 7, block_count: 0, operation_count: 3, value_count: 1 },
        ],
      },
    }),
  }
  let source : @driver.ExploreFunctionRef = { stage: Anf, index: 7 }
  render_stage_observations(html, stage, {
    nodes: [
      { function: source, roles: [SourceFunction(value=4, name=Some("main"))] },
    ],
    edges: [{ source: { stage: Executable, index: 4 }, target: source }],
  })
  inspect(
    html.to_string(),
    content=(
      #|<div class="observations"><div class="metrics"><span class="metric">functionCount: 1</span></div><table><thead><tr><th>Function</th><th>Blocks</th><th>Operations</th><th>Values/locals</th></tr></thead><tbody><tr><td>7</td><td>0</td><td>3</td><td>1</td></tr></tbody></table><table><thead><tr><th>Function lineage</th><th>Role</th><th>From</th></tr></thead><tbody><tr><td>anf#7</td><td>source main (value#4)</td><td>executable#4</td></tr></tbody></table></div>
    ),
  )
}
