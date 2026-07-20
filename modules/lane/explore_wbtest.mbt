///|
test "explorer HTML escaping covers markup and attributes" {
  inspect(escape_html("<&>\"'"), content="&lt;&amp;&gt;&quot;&#39;")
}

///|
test "explorer HTML body contains only stage navigation and code" {
  let report : @driver.ExploreReport = {
    schema_version: 99,
    entry: "<hidden-entry>",
    stages: [
      { id: "stage<one", title: "Stage & One", text: "let answer = 42\n<&>" },
      { id: "stage-two", title: "Stage Two", text: "return answer" },
    ],
    diagnostics: [],
    failure: Some("hidden failure"),
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
      #|@media(max-width:760px){main{grid-template-columns:1fr}nav{border-right:0;border-bottom:1px solid var(--line)}}
      #|</style>
      #|</head>
      #|<body>
      #|<main><nav><button type="button" role="tab" aria-selected="true" data-stage="stage&lt;one">Stage &amp; One</button><button type="button" role="tab" aria-selected="false" data-stage="stage-two">Stage Two</button></nav><div class="content"><section class="stage active" data-stage="stage&lt;one"><pre>let answer = 42
      #|&lt;&amp;&gt;</pre></section><section class="stage" data-stage="stage-two"><pre>return answer</pre></section></div></main>
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
