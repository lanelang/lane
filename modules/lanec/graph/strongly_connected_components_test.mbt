///|
test "strongly connected components preserve deterministic dependency order" {
  debug_inspect(
    strongly_connected_components([[1], [2], [1], []]),
    content=(
      #|[
      #|  { members: [3], recursive: false },
      #|  { members: [0], recursive: false },
      #|  { members: [1, 2], recursive: true },
      #|]
    ),
  )
}
