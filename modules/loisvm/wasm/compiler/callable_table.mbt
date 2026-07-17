///|
priv struct CallableTablePlan {
  functions : Array[@bytecode.FunctionId]
  table_indices : Array[Int]
}

///|
fn plan_callable_table(image : @bytecode.BytecodeImage) -> CallableTablePlan {
  let address_taken = Array::make(image.functions.length(), false)
  for entry in image.functions {
    guard entry is BytecodeBody(body) else { continue }
    for block in body.blocks {
      for instruction in block.instructions {
        match instruction {
          ConstFunction(_, function) | MakeClosure(_, function, _) => {
            let index = function.value - 1
            if index >= 0 && index < address_taken.length() {
              address_taken[index] = true
            }
          }
          _ => ()
        }
      }
    }
  }
  let functions = []
  let table_indices = Array::make(image.functions.length(), 0)
  for index, is_address_taken in address_taken {
    if is_address_taken {
      let function : @bytecode.FunctionId = { value: index + 1 }
      functions.push(function)
      table_indices[index] = functions.length()
    }
  }
  { functions, table_indices }
}
