///|
test "parse call-shaped derive expressions" {
  let implicit = parse_string(
    "module Test\npub let point_equal : Equal[Point] = derive[Equal, Point]()",
  )
  debug_inspect(implicit.parse_errors(), content="[]")
  let explicit = parse_string(
    "module Test\npub let point_equal : Equal[Point] = derive[Equal, Point](deriver=derive_equal)",
  )
  debug_inspect(explicit.parse_errors(), content="[]")
}

///|
test "derive is reserved for call-shaped derivation" {
  let binding = parse_string("module Test\nlet derive : Int = 1")
  assert_false(binding.parse_errors().is_empty())
  let missing_call = parse_string(
    "module Test\npub let point_equal : Equal[Point] = derive[Equal, Point]",
  )
  assert_false(missing_call.parse_errors().is_empty())
  let missing_target = parse_string(
    "module Test\npub let point_equal : Equal[Point] = derive[Equal]()",
  )
  assert_false(missing_target.parse_errors().is_empty())
  let extra_type_argument = parse_string(
    "module Test\npub let point_equal : Equal[Point] = derive[Equal, Point, Unit]()",
  )
  assert_false(extra_type_argument.parse_errors().is_empty())
}
