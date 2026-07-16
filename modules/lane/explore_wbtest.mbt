///|
test "explorer HTML escaping covers markup and attributes" {
  inspect(escape_html("<&>\"'"), content="&lt;&amp;&gt;&quot;&#39;")
}
