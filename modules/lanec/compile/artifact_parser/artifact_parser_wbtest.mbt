///|
test "parse readable artifact text document" {
  let parsed = parse_text(
    (
      #|lane-artifact-text-v1 interface {
      #|  schema_version: 1;
      #|  module_path_text: "Examples.Valid01";
      #|  lane_type.function;
      #|  escaped: "a\nb\"c";
      #|}
    ),
  )
  guard parsed is Ok(document) else { abort("expected parsed artifact") }
  debug_inspect(
    document,
    content=(
      #|{
      #|  version: "lane-artifact-text-v1",
      #|  kind: "interface",
      #|  entries: [
      #|    Value("schema_version", Atom("1")),
      #|    Value("module_path_text", Text("Examples.Valid01")),
      #|    Tag("lane_type.function"),
      #|    Value("escaped", Text("a\nb\"c")),
      #|  ],
      #|}
    ),
  )
}

///|
test "reject unsupported artifact text version" {
  let parsed = parse_text(
    (
      #|lane-artifact-text-v0 interface {
      #|  schema_version: 1;
      #|}
    ),
  )
  guard parsed is Err(message) else { abort("expected parse failure") }
  inspect(
    message,
    content=(
      #|error[E5003]: unsupported artifact text version
      #|  problem: found `lane-artifact-text-v0`, expected `lane-artifact-text-v1`
      #|  context: artifact text versions are compiler format contracts
      #|  recovery: recompile or relink the artifact with the current Lane compiler
    ),
  )
}

///|
test "parse linked program artifact kind" {
  let parsed = parse_text(
    (
      #|lane-artifact-text-v1 program {
      #|  schema_version: 1;
      #|}
    ),
  )
  guard parsed is Ok(document) else { abort("expected parsed artifact") }
  assert_eq(document.kind, "program")
}
