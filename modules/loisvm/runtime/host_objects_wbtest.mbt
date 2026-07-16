///|
test "Host Object handle validates its slot index" {
  let runtime = ExecutionRuntime::new()
  let handle : HostObjectHandle = {
    identity: runtime.context.state.host_objects.identity,
    slot: 0,
    generation: 1,
  }
  let result : Result[BorrowedHostObject, HostObjectFailure] = Ok(
    runtime.resolve_host_object(handle),
  ) catch {
    error => Err(error)
  }
  debug_inspect(
    result,
    content=(
      #|Err(InvalidHostObjectHandle(detail="handle slot is out of range"))
    ),
  )
}
