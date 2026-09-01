///|
test "compiler-owned fatal control has the canonical callable ABI" {
  let image = compile_test_physical_program(
    (
      #|module Test
      #|
      #|import Basic.Data.Void.{ Void, absurd }
      #|
      #|let abort : () -> Void ! Panic = builtin("%abort")
      #|
      #|fn invoke(abort : () -> Void ! Panic) -> Unit ! Panic {
      #|  absurd[Unit](abort())
      #|  ()
      #|}
      #|
      #|pub fn answer() -> Unit ! Panic {
      #|  invoke(abort)
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
  assert_eq(@physical.verify_physical_program(image), Ok(()))
  let mut fatal_count = 0
  let mut runtime_import_count = 0
  for entry in image.functions {
    match entry {
      PhysicalBody(body) =>
        for block in body.blocks {
          if block.terminator is Fatal {
            fatal_count += 1
            guard body.callable_abi()
              is Some(
                {
                  witnesses: [],
                  parameters: [],
                  result: Value(I32, OwnedRef, DataValue(_)),
                }
              ) else {
              fail("fatal wrapper did not use the ordinary Void data ABI")
            }
            assert_eq(body.inputs, {
              environment: None,
              witnesses: [],
              user_parameters: [],
            })
          }
        }
      RuntimeImport(_) => runtime_import_count += 1
    }
  }
  assert_eq(fatal_count, 1)
  assert_eq(runtime_import_count, 0)
}
