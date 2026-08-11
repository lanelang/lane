///|
test "compiler-owned fatal control has the canonical callable ABI" {
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
  assert_eq(@bytecode.verify_bytecode_image(image), Ok(()))
  let string_slot : @bytecode.SlotMetadata = {
    representation: I32,
    cleanup: OwnedRef,
    kind: ByteSequenceValue,
    erased_companion: None,
  }
  let fatal_abi = @bytecode.CallableAbi::from_slot_metadata(
    [],
    [string_slot],
    Unit,
  )
  assert_true(image.callable_abis.contains(fatal_abi))
  let mut fatal_count = 0
  let mut runtime_import_count = 0
  for entry in image.functions {
    match entry {
      BytecodeBody(body) =>
        for block in body.blocks {
          if block.terminator is Fatal(message) {
            fatal_count += 1
            assert_eq(body.callable_abi(), Some(fatal_abi))
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
