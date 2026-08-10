///|
test "compiler preserves Unit calls and compiler-owned fatal control" {
  let image = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|let panic : (String) -> Unit ! Panic = builtin("%panic")
      #|
      #|fn invoke(abort : (String) -> Unit ! Panic) -> Unit ! Panic {
      #|  abort("indirect")
      #|}
      #|
      #|pub fn answer() -> Unit ! Panic {
      #|  invoke(panic)
      #|  ()
      #|}
    ),
  )
  let results = []
  let terminators = []
  let imports = []
  for entry in image.functions {
    match entry {
      BytecodeBody(body) => {
        results.push(body.result)
        for block in body.blocks {
          terminators.push(block.terminator)
        }
      }
      RuntimeImport(import_) => imports.push(import_.symbol)
    }
  }
  debug_inspect(
    (results, terminators, imports),
    content=(
      #|(
      #|  [Unit, Unit, Unit, Unit],
      #|  [
      #|    Fatal({ value: 0 }),
      #|    TailCallValue({ value: 0 }, { value: 0 }, [], [{ value: 1 }]),
      #|    TailCallDirect({ value: 2 }, None, [], [{ value: 0 }]),
      #|    TailCallValue({ value: 1 }, { value: 0 }, [], [{ value: 2 }]),
      #|  ],
      #|  [],
      #|)
    ),
  )
}
