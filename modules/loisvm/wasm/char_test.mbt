///|
test "compiled character constants execute with Wasmoon" {
  let entry = {
    ..body(slots=Array::make(3, trivial_slot(I32))),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstChar({ value: 0 }, 0x1F600),
          ConstChar({ value: 1 }, 0x1F600),
          I32Eq({ value: 2 }, { value: 0 }, { value: 1 }),
        ],
        terminator: BranchBool({ value: 2 }, edge(1), edge(2)),
      },
      { parameters: [], instructions: [], terminator: Return(None) },
      { parameters: [], instructions: [], terminator: Unreachable },
    ],
  }
  run_entry(entry)
}
