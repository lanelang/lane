///|
fn candidate(type_ : @types.Type) -> TypedCandidate {
  { reference: Unresolved("candidate"), type_ }
}

///|
test "select candidate by expected type" {
  let selected = select_by_expected(
    "value",
    [candidate(Primitive(Bool)), candidate(Primitive(Int))],
    Primitive(Int),
  )
  debug_inspect(
    selected,
    content="Selected({ reference: Unresolved(\"candidate\"), type_: Primitive(Int) })",
  )
}

///|
test "keep ambiguity when expected type matches more than one candidate" {
  let selected = select_by_expected(
    "value",
    [candidate(Primitive(Int)), candidate(Primitive(Int))],
    Primitive(Int),
  )
  debug_inspect(
    selected,
    content=(
      #|Ambiguous(
      #|  name="value",
      #|  candidates=[
      #|    { reference: Unresolved("candidate"), type_: Primitive(Int) },
      #|    { reference: Unresolved("candidate"), type_: Primitive(Int) },
      #|  ],
      #|)
    ),
  )
}
