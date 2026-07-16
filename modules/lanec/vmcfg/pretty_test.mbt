///|
test "VM CFG pretty printer exposes control flow and ownership" {
  let image : Image = {
    entry: { value: 1 },
    initializer: Some({ value: 1 }),
    functions: [
      Body({
        values: [
          {
            representation: I32,
            cleanup: OwnedRef,
            ownership: Owned,
            erased_companion: None,
          },
          {
            representation: I32,
            cleanup: OwnedRef,
            ownership: Borrowed,
            erased_companion: None,
          },
          {
            representation: I64,
            cleanup: Trivial,
            ownership: Trivial,
            erased_companion: None,
          },
        ],
        inputs: {
          environment: None,
          witnesses: [],
          user_parameters: [{ value: 2 }],
        },
        result: Unit,
        blocks: [
          {
            parameters: [],
            instructions: [
              ConstString({ value: 0 }, { value: 0 }),
              InitGlobal({ value: 0 }, { value: 0 }),
              BorrowGlobal({ value: 1 }, { value: 0 }),
              CallDirect(
                { value: 2 },
                None,
                [],
                [{ value: 1 }, { value: 2 }],
                None,
              ),
            ],
            terminator: Return(None),
          },
        ],
      }),
      RuntimeImport({
        abi_major: 1,
        parameters: [String, Int],
        result: Unit,
        symbol: "lane.test.print",
      }),
    ],
    globals: [
      { representation: I32, cleanup: OwnedRef, erased_companion: None },
    ],
    layouts: [String],
    object_shapes: [],
    constants: [b"Lane"],
  }
  inspect(
    @prettyprinter.render(image, width=100),
    content=(
      #|VM CFG
      #|entry: f1
      #|initializer: f1
      #|functions: 2
      #|globals: 1
      #|layouts: 1
      #|object shapes: 0
      #|constants: 1
      #|
      #|function f1(
      #|  environment=none,
      #|  witnesses=[],
      #|  parameters=[%v2]
      #|) -> unit {
      #|  values:
      #|    %v0: i32 + owned_ref + owned
      #|    %v1: i32 + owned_ref + borrowed
      #|    %v2: i64 + trivial + trivial
      #|  b0([]):
      #|    const_string %v0, c0
      #|    init_global g0, %v0
      #|    borrow_global %v1, g0
      #|    call_direct f2 env=none witnesses=[] arguments=[%v1, %v2]
      #|    return none
      #|}
      #|
      #|function f2 = runtime_import(
      #|  symbol="lane.test.print",
      #|  abi_major=1,
      #|  parameters=[string, int],
      #|  result=unit
      #|)
      #|
      #|instance global table:
      #|  g0 = i32 + owned_ref
      #|
      #|layout table:
      #|  l1 = string
      #|
      #|constant table:
      #|  c0 = "Lane"
      #|
    ),
  )
}
