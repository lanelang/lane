///|
/// Returns the greatest number of nested structured control instructions in
/// any function body. The query traverses each instruction exactly once and
/// does not depend on text rendering or binary encoding.
pub fn maximum_function_control_depth(module_ : @wasm_types.Module) -> Int {
  let mut maximum = 0
  for code in module_.codes {
    let depth = instruction_sequence_control_depth(code.body)
    if depth > maximum {
      maximum = depth
    }
  }
  maximum
}

///|
fn instruction_sequence_control_depth(
  instructions : Array[@wasm_types.Instruction],
) -> Int {
  let mut maximum = 0
  for instruction in instructions {
    let depth = match instruction {
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        1 + instruction_sequence_control_depth(body)
      If(_, consequent, alternate) => {
        let consequent_depth = instruction_sequence_control_depth(consequent)
        let alternate_depth = instruction_sequence_control_depth(alternate)
        let branch_depth = if consequent_depth > alternate_depth {
          consequent_depth
        } else {
          alternate_depth
        }
        1 + branch_depth
      }
      _ => 0
    }
    if depth > maximum {
      maximum = depth
    }
  }
  maximum
}
