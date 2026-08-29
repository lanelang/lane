///|
test "compiled I32 wrapping arithmetic and conversions execute with Wasmoon" {
  let slots = [
    trivial_slot(I32),
    trivial_slot(I32),
    trivial_slot(I32),
    trivial_slot(I64),
    trivial_slot(I64),
    trivial_slot(I32),
    trivial_slot(I64),
    trivial_slot(I32),
    trivial_slot(I32),
    trivial_slot(I32),
  ]
  let entry = {
    ..body(slots~),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI32({ value: 0, }, 2147483647),
          ConstI32({ value: 1, }, 1),
          I32Add({ value: 2, }, { value: 0, }, { value: 1, }),
          I32ToI64({ value: 3, }, { value: 2, }),
          ConstI64({ value: 4, }, -2147483647L - 1L),
          I64Eq({ value: 5, }, { value: 3, }, { value: 4, }),
        ],
        terminator: BranchBool({ value: 5, }, edge(1), edge(3)),
      },
      {
        parameters: [],
        instructions: [
          ConstI64({ value: 6, }, 4294967295L),
          I64ToI32({ value: 7, }, { value: 6, }),
          ConstI32({ value: 8, }, -1),
          I32Eq({ value: 9, }, { value: 7, }, { value: 8, }),
        ],
        terminator: BranchBool({ value: 9, }, edge(2), edge(3)),
      },
      { parameters: [], instructions: [], terminator: Return(None), },
      { parameters: [], instructions: [], terminator: Unreachable, },
    ],
  }
  run_entry(entry)
}

///|
test "compiled signed I32 division remainder and comparison execute with Wasmoon" {
  let slots = Array::make(4, trivial_slot(I32))
  let entry = {
    ..body(slots~),
    blocks: [
      {
        parameters: [],
        instructions: [
          ConstI32({ value: 0, }, -7),
          ConstI32({ value: 1, }, 2),
          I32Div({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstI32({ value: 1, }, -3),
          I32Eq({ value: 3, }, { value: 2, }, { value: 1, }),
        ],
        terminator: BranchBool({ value: 3, }, edge(1), edge(3)),
      },
      {
        parameters: [],
        instructions: [
          ConstI32({ value: 1, }, 2),
          I32Rem({ value: 2, }, { value: 0, }, { value: 1, }),
          ConstI32({ value: 1, }, -1),
          I32Eq({ value: 3, }, { value: 2, }, { value: 1, }),
        ],
        terminator: BranchBool({ value: 3, }, edge(2), edge(3)),
      },
      {
        parameters: [],
        instructions: [
          ConstI32({ value: 1, }, 2),
          I32Lt({ value: 3, }, { value: 0, }, { value: 1, }),
        ],
        terminator: BranchBool({ value: 3, }, edge(4), edge(3)),
      },
      { parameters: [], instructions: [], terminator: Unreachable, },
      { parameters: [], instructions: [], terminator: Return(None), },
    ],
  }
  run_entry(entry)
}
