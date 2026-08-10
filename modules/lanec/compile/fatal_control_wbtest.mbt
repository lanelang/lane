///|
test "compiler preserves one Never ABI through direct and first-class fatal calls" {
  let image = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|pub enum Void {}
      #|let panic : (String) -> Void ! Io = builtin("%panic")
      #|
      #|fn invoke(abort : (String) -> Void ! Io) -> Void ! Io {
      #|  abort("indirect")
      #|}
      #|
      #|pub fn answer() -> Unit ! Io {
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
      #|  [Never, Never, Unit, Never],
      #|  [
      #|    Fatal({ value: 0 }),
      #|    CallNeverValue({ value: 0 }, { value: 0 }, [], [{ value: 1 }]),
      #|    CallNeverDirect({ value: 2 }, None, [], [{ value: 0 }]),
      #|    CallNeverValue({ value: 1 }, { value: 0 }, [], [{ value: 2 }]),
      #|  ],
      #|  [],
      #|)
    ),
  )
}
