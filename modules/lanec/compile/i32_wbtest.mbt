///|
test "compiler preserves I32 literal and arithmetic through executable lowering" {
  let physical_program = compile_test_physical_program(
    (
      #|module Test
      #|
      #|let add : (I32, I32) -> I32 = builtin("%i32_add")
      #|let to_int : (I32) -> I64 = builtin("%i32_to_i64")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test", "lane.test.observe")
      #|
      #|pub fn answer() -> Unit ! Io {
      #|  let minimum : I32 = -2147483648i32
      #|  match add(2147483647i32, 1i32) {
      #|    -2147483648i32 => observe(to_int(minimum))
      #|    _ => observe(0)
      #|  }
      #|}
    ),
  )
  debug_inspect(
    physical_program,
    content=(
      #|{
      #|  entry: { value: 1 },
      #|  initializer: None,
      #|  callable_abis: [
      #|    { witnesses: [], parameters: [], result: Unit },
      #|    {
      #|      witnesses: [],
      #|      parameters: [{ representation: I64, cleanup: Trivial, kind: ScalarValue }],
      #|      result: Unit,
      #|    },
      #|  ],
      #|  data_family_count: 0,
      #|  functions: [
      #|    PhysicalBody(
      #|      {
      #|        slots: [
      #|          {
      #|            representation: I64,
      #|            cleanup: Trivial,
      #|            kind: ScalarValue,
      #|            erased_companion: None,
      #|          },
      #|        ],
      #|        inputs: { environment: None, witnesses: [], user_parameters: [] },
      #|        result: Unit,
      #|        blocks: [
      #|          {
      #|            parameters: [],
      #|            instructions: [ConstI64({ value: 0 }, -2147483648)],
      #|            terminator: TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
      #|          },
      #|        ],
      #|      },
      #|    ),
      #|    RuntimeImport(
      #|      {
      #|        module_name: "lane.test",
      #|        field_name: "lane.test.observe",
      #|        parameters: [Direct(I64)],
      #|        result: Unit,
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
