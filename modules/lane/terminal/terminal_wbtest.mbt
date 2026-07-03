///|
test "diagnostic terminal color policy honors env and tty" {
  debug_inspect(
    diagnostic_render_config_from_environment(None, None, true, Some(72)),
    content="{ color: true, width: 72 }",
  )
  debug_inspect(
    diagnostic_render_config_from_environment(None, Some("1"), true, Some(72)),
    content="{ color: false, width: 72 }",
  )
  debug_inspect(
    diagnostic_render_config_from_environment(
      Some("always"),
      Some("1"),
      false,
      Some(20),
    ),
    content="{ color: true, width: 100 }",
  )
  debug_inspect(
    diagnostic_render_config_from_environment(Some("never"), None, true, None),
    content="{ color: false, width: 100 }",
  )
}
