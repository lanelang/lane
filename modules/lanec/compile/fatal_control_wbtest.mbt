///|
test "compiler-owned fatal control has the canonical callable ABI" {
  let image = compile_test_loisvm_image(
    (
      #|module Test
      #|
      #|import Basic.Data.Void.{ Void, absurd }
      #|
      #|let panic : (String) -> Void ! Panic = builtin("%panic")
      #|
      #|fn invoke(abort : (String) -> Void ! Panic) -> Unit ! Panic {
      #|  absurd[Unit](abort("indirect"))
      #|  ()
      #|}
      #|
      #|pub fn answer() -> Unit ! Panic {
      #|  invoke(panic)
      #|  ()
      #|}
    ),
    library_sources=[
      (
        #|module Basic.Data.Void
        #|pub enum Void {}
        #|pub fn[T] absurd(value : Void) -> T { match value {} }
      ),
    ],
  )
  assert_eq(@bytecode.verify_bytecode_image(image), Ok(()))
  let mut fatal_count = 0
  let mut runtime_import_count = 0
  for entry in image.functions {
    match entry {
      BytecodeBody(body) =>
        for block in body.blocks {
          if block.terminator is Fatal(message) {
            fatal_count += 1
            guard body.callable_abi()
              is Some(
                {
                  witnesses: [],
                  parameters: [
                    {
                      representation: I32,
                      cleanup: OwnedRef,
                      kind: ByteSequenceValue,
                    },
                  ],
                  result: Value(I32, OwnedRef, DataValue(_)),
                }
              ) else {
              fail("fatal wrapper did not use the ordinary Void data ABI")
            }
            assert_eq(body.inputs, {
              environment: None,
              witnesses: [],
              user_parameters: [message],
            })
          }
        }
      RuntimeImport(_) => runtime_import_count += 1
    }
  }
  assert_eq(fatal_count, 1)
  assert_eq(runtime_import_count, 0)
}
