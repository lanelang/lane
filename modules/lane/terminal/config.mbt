///|
priv enum DiagnosticColorMode {
  Auto
  Always
  Never
}

///|
pub fn diagnostic_render_config() -> @diag_render.RenderConfig {
  diagnostic_render_config_from_environment(
    @sys.get_env_var("LANE_COLOR"),
    @sys.get_env_var("NO_COLOR"),
    terminal_is_tty(1),
    terminal_width(1),
  )
}

///|
fn diagnostic_render_config_from_environment(
  color_env : String?,
  no_color : String?,
  is_tty : Bool,
  terminal_width : Int?,
) -> @diag_render.RenderConfig {
  let mode = diagnostic_color_mode_from_environment(color_env)
  {
    color: diagnostic_color_enabled(mode, no_color, is_tty),
    width: diagnostic_width(terminal_width),
  }
}

///|
fn diagnostic_color_mode_from_environment(
  color_env : String?,
) -> DiagnosticColorMode {
  match color_env {
    Some("always") => Always
    Some("never") => Never
    Some("auto") => Auto
    _ => Auto
  }
}

///|
fn diagnostic_color_enabled(
  mode : DiagnosticColorMode,
  no_color : String?,
  is_tty : Bool,
) -> Bool {
  match mode {
    Always => true
    Never => false
    Auto => no_color is None && is_tty
  }
}

///|
fn diagnostic_width(terminal_width : Int?) -> Int {
  match terminal_width {
    Some(width) if width >= 40 => width
    _ => 100
  }
}
