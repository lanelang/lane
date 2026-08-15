///|
/// The native Lane command owns residual-effect admission for its runtime
/// imports and compiler-controlled fatal path. Concrete runtime-import symbols
/// remain subject to runtime-registry validation.
fn lane_command_execution_profile() -> @executable.ExecutionProfile {
  @executable.ExecutionProfile::new(
    builtin_effects=[Io, Panic],
    supports_external_effects=true,
  )
}
