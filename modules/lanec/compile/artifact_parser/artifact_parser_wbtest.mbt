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
  assert_eq(document.kind, "interface")
  assert_eq(document.entries.length(), 4)
  assert_true(document.entries[0] == Value("schema_version", Atom("1")))
  assert_true(
    document.entries[1] == Value("module_path_text", Text("Examples.Valid01")),
  )
  assert_true(document.entries[2] == Tag("lane_type.function"))
  assert_true(document.entries[3] == Value("escaped", Text("a\nb\"c")))
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
  assert_eq(
    message,
    (
      #|error[E5003]: unsupported artifact text version
      #|  = label: found `lane-artifact-text-v0`, expected `lane-artifact-text-v1`
      #|  = note: artifact text versions are compiler format contracts
      #|  = help: recompile or relink the artifact with the current Lane compiler
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
