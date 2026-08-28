///|
fn array_lowering_source(body : String) -> String {
  (
    #|module Test
    #|
    #|let array_empty : [Element]() -> Array[Element] = builtin("%array_empty")
    #|let array_make : [Element](I64, Element) -> Array[Element] = builtin("%array_make")
    #|let array_length : [Element](Array[Element]) -> I64 = builtin("%array_length")
    #|let array_get : [Element](Array[Element], I64) -> Element = builtin("%array_get")
    #|let array_set : [Element](Array[Element], I64, Element) -> Array[Element] = builtin("%array_set")
    #|let observe : (I64) -> Unit ! Io = extern("lane.test", "observe_i64")
    #|
  ) +
  body
}

///|
fn array_physical_instructions(
  image : @physical.PhysicalProgram,
) -> Array[@physical.Instruction] {
  let instructions = []
  for entry in image.functions {
    if entry is PhysicalBody(body) {
      for block in body.blocks {
        for instruction in block.instructions {
          match instruction {
            ArrayEmpty(_, _)
            | ArrayMake(_, _, _)
            | ArrayLength(_, _)
            | ArrayGet(_, _, _)
            | ArraySet(_, _, _, _) => instructions.push(instruction)
            _ => ()
          }
        }
      }
    }
  }
  instructions
}

///|
test "direct generic Array calls lower to explicit Physical operations" {
  let image = compile_test_physical_program(
    array_lowering_source(
      (
        #|pub fn answer() -> Unit ! Io {
        #|  let empty = array_empty[I64]()
        #|  observe(array_length[I64](empty))
        #|  let nested = array_empty[Array[I64]]()
        #|  observe(array_length[Array[I64]](nested))
        #|  let values = array_make[I64](2, 7)
        #|  let values = array_set[I64](values, 0, 9)
        #|  observe(array_length[I64](values))
        #|  observe(array_get[I64](values, 0))
        #|}
      ),
    ),
  )
  let instructions = array_physical_instructions(image)
  assert_true(instructions.any(instruction => instruction is ArrayEmpty(_, _)))
  assert_true(
    instructions.any(instruction => instruction is ArrayMake(_, _, _)),
  )
  assert_true(instructions.any(instruction => instruction is ArrayLength(_, _)))
  assert_true(instructions.any(instruction => instruction is ArrayGet(_, _, _)))
  assert_true(
    instructions.any(instruction => instruction is ArraySet(_, _, _, _)),
  )
  assert_true(image.layouts.contains(Array))
}

///|
test "first-class generic Array intrinsic lowers to the same Physical operation" {
  let image = compile_test_physical_program(
    array_lowering_source(
      (
        #|struct Maker {
        #|  make : (I64, I64) -> Array[I64]
        #|}
        #|
        #|pub fn answer() -> Unit ! Io {
        #|  let maker = Maker::{ make: array_make[I64] }
        #|  let empty = array_empty[I64]()
        #|  observe(array_length[I64](empty))
        #|  let values = array_set[I64](maker.make(2, 7), 0, 9)
        #|  observe(array_get[I64](values, 0))
        #|}
      ),
    ),
  )
  assert_true(
    array_physical_instructions(image).any(instruction => {
      instruction is ArrayMake(_, _, _)
    }),
  )
}
