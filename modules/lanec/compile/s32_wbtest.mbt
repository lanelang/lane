///|
test "compiler preserves S32 literal and arithmetic through executable lowering" {
  let bytecode = compile_byte_bytes_image(
    (
      #|module Test
      #|
      #|let add : (S32, S32) -> S32 = builtin("%i32_add")
      #|let op_neg : (S32) -> S32 = builtin("%i32_neg")
      #|let to_int : (S32) -> Int = builtin("%s32_to_int")
      #|let observe : (Int) -> Unit ! Io = extern("lane.test.observe")
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  let minimum : S32 = -2147483648
      #|  match add(2147483647, 1) {
      #|    -2147483648 => observe(to_int(minimum))
      #|    _ => observe(0)
      #|  }
      #|}
    ),
  )
  debug_inspect(
    bytecode,
    content=(
      #|{
      #|  entry: { value: 1 },
      #|  initializer: None,
      #|  functions: [
      #|    BytecodeBody(
      #|      {
      #|        slots: [
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I32, cleanup: Trivial, erased_companion: None },
      #|          { representation: I64, cleanup: Trivial, erased_companion: None },
      #|          { representation: I64, cleanup: Trivial, erased_companion: None },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstS32({ value: 0 }, 2147483647),
      #|              ConstS32({ value: 1 }, 1),
      #|              S32Add({ value: 2 }, { value: 0 }, { value: 1 }),
      #|              ConstS32({ value: 3 }, -2147483648),
      #|              S32Eq({ value: 4 }, { value: 2 }, { value: 3 }),
      #|            ],
      #|            terminator: BranchBool(
      #|              { value: 4 },
      #|              { target: { value: 1 }, arguments: [] },
      #|              { target: { value: 2 }, arguments: [] },
      #|            ),
      #|          },
      #|          {
      #|            parameters: [],
      #|            instructions: [
      #|              ConstS32({ value: 7 }, -2147483648),
      #|              S32ToInt({ value: 8 }, { value: 7 }),
      #|            ],
      #|            terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 8 }]),
      #|          },
      #|          {
      #|            parameters: [],
      #|            instructions: [ConstInt({ value: 9 }, 0)],
      #|            terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 9 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        abi_major: 1,
      #|        parameters: [Int],
      #|        result: Unit,
      #|        symbol: "lane.test.observe",
      #|      },
      #|    ),
      #|  ],
      #|  globals: [],
      #|  layouts: [],
      #|  object_shapes: [],
      #|  constants: [],
      #|}
    ),
  )
}
