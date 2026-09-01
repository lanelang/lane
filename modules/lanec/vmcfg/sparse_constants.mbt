///|
priv enum SparseConstant {
  I64(Int64)
  I32(Int)
  Char(Int)
  F64(Int64)
  F32(Int)
  Bool(Bool)
  Layout(@physical.LayoutId)
  Function(@physical.FunctionId)
} derive(Eq)

///|
priv enum SparseValueState {
  Unknown
  Constant(SparseConstant)
  Overdefined
} derive(Eq)

///|
priv struct SparseConstantAnalysis {
  states : Array[SparseValueState]
  reachable : Array[Bool]
}

///|
fn propagate_sparse_constants(body : FunctionBody) -> FunctionBody {
  let analysis = analyze_sparse_constants(body)
  {
    ..body,
    blocks: body.blocks.mapi(fn(block_index, block) {
      if !analysis.reachable[block_index] {
        return block
      }
      {
        ..block,
        instructions: block.instructions.map(instruction => {
          fold_sparse_instruction(body.values, analysis.states, instruction)
        }),
        terminator: fold_sparse_terminator(analysis.states, block.terminator),
      }
    }),
  }
}

///|
fn analyze_sparse_constants(body : FunctionBody) -> SparseConstantAnalysis {
  let states = Array::make(body.values.length(), SparseValueState::Unknown)
  let reachable = Array::make(body.blocks.length(), false)
  if body.blocks.is_empty() {
    return { states, reachable, }
  }
  reachable[0] = true
  if body.inputs.environment is Some(value) {
    states[value.value] = Overdefined
  }
  for value in body.inputs.witnesses {
    states[value.value] = Overdefined
  }
  for value in body.inputs.user_parameters {
    states[value.value] = Overdefined
  }
  let mut changed = true
  while changed {
    changed = false
    for block_index, block in body.blocks {
      if !reachable[block_index] {
        continue
      }
      for instruction in block.instructions {
        let destinations = instruction_destinations(instruction)
        guard destinations is [destination] else { continue }
        let evaluated = evaluate_sparse_instruction(
          body.values,
          states,
          instruction,
        )
        let merged = merge_sparse_state(states[destination.value], evaluated)
        if merged != states[destination.value] {
          states[destination.value] = merged
          changed = true
        }
      }
      for edge in sparse_executable_edges(states, block.terminator) {
        let target_index = edge.target.value
        if !reachable[target_index] {
          reachable[target_index] = true
          changed = true
        }
        let parameters = body.blocks[target_index].parameters
        for index, parameter in parameters {
          let merged = merge_sparse_state(
            states[parameter.value],
            states[edge.arguments[index].value],
          )
          if merged != states[parameter.value] {
            states[parameter.value] = merged
            changed = true
          }
        }
      }
    }
  }
  { states, reachable, }
}

///|
fn merge_sparse_state(
  current : SparseValueState,
  incoming : SparseValueState,
) -> SparseValueState {
  match (current, incoming) {
    (Overdefined, _) | (_, Overdefined) => Overdefined
    (Unknown, value) => value
    (value, Unknown) => value
    (Constant(left), Constant(right)) if left == right => Constant(left)
    (Constant(_), Constant(_)) => Overdefined
  }
}

///|
fn sparse_executable_edges(
  states : Array[SparseValueState],
  terminator : Terminator,
) -> Array[Edge] {
  match terminator {
    Jump(edge) => [edge]
    BranchBool(condition, if_true, if_false) =>
      match states[condition.value] {
        Constant(Bool(true)) => [if_true]
        Constant(Bool(false)) => [if_false]
        Unknown => []
        Constant(_) | Overdefined => [if_true, if_false]
      }
    SwitchTag(tag, cases, default) =>
      match states[tag.value] {
        Constant(I64(value)) if value >= 0L && value < cases.length().to_int64() =>
          [cases[value.to_int()]]
        Constant(I64(_)) => [default]
        Unknown => []
        Constant(_) | Overdefined => cases + [default]
      }
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallPackedDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal
    | Unreachable => []
  }
}

///|
fn evaluate_sparse_instruction(
  values : Array[ValueMetadata],
  states : Array[SparseValueState],
  instruction : Instruction,
) -> SparseValueState {
  match instruction {
    ConstI64(_, value) => Constant(I64(value))
    ConstI32(_, value) => Constant(I32(value))
    ConstChar(_, value) => Constant(Char(value))
    ConstF64(_, bits) => Constant(F64(bits))
    ConstF32(_, bits) => Constant(F32(bits))
    ConstBool(_, value) => Constant(Bool(value))
    ConstLayout(_, layout) => Constant(Layout(layout))
    ConstFunction(_, function) => Constant(Function(function))
    Copy(destination, source) if compatible_trivial_values(
        values, destination, source,
      ) => states[source.value]
    I32Add(_, left, right) =>
      sparse_i32_binary(states, left, right, fn(a, b) { I32(a + b) })
    I32Sub(_, left, right) =>
      sparse_i32_binary(states, left, right, fn(a, b) { I32(a - b) })
    I32Mul(_, left, right) =>
      sparse_i32_binary(states, left, right, fn(a, b) { I32(a * b) })
    I32Neg(_, source) => sparse_i32_unary(states, source, value => I32(-value))
    I32Div(_, left, right) => sparse_i32_div(states, left, right)
    I32Rem(_, left, right) => sparse_i32_rem(states, left, right)
    I32Eq(_, left, right) =>
      sparse_i32_binary(states, left, right, fn(a, b) { Bool(a == b) })
    I32Lt(_, left, right) =>
      sparse_i32_binary(states, left, right, fn(a, b) { Bool(a < b) })
    I32ToI64(_, source) =>
      sparse_i32_unary(states, source, value => I64(value.to_int64()))
    I64ToI32(_, source) =>
      sparse_i64_unary(states, source, value => I32(value.to_int()))
    I64Add(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a + b) })
    I64Sub(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a - b) })
    I64Mul(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a * b) })
    I64Neg(_, source) => sparse_i64_unary(states, source, value => I64(-value))
    I64Div(_, left, right) => sparse_i64_div(states, left, right)
    I64Rem(_, left, right) => sparse_i64_rem(states, left, right)
    I64And(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a & b) })
    I64Or(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a | b) })
    I64Xor(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a ^ b) })
    I64Not(_, source) =>
      sparse_i64_unary(states, source, value => I64(value.lnot()))
    I64Shl(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a << b.to_int()) })
    I64ShrS(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { I64(a >> b.to_int()) })
    I64Eq(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { Bool(a == b) })
    I64Ne(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { Bool(a != b) })
    I64Lt(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { Bool(a < b) })
    I64Le(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { Bool(a <= b) })
    I64Gt(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { Bool(a > b) })
    I64Ge(_, left, right) =>
      sparse_i64_binary(states, left, right, fn(a, b) { Bool(a >= b) })
    BoolNot(_, source) =>
      sparse_bool_unary(states, source, value => Bool(!value))
    BoolEq(_, left, right) =>
      sparse_bool_binary(states, left, right, fn(a, b) { Bool(a == b) })
    BoolNe(_, left, right) =>
      sparse_bool_binary(states, left, right, fn(a, b) { Bool(a != b) })
    _ => Overdefined
  }
}

///|
fn sparse_i32_unary(
  states : Array[SparseValueState],
  source : ValueId,
  evaluate : (Int) -> SparseConstant,
) -> SparseValueState {
  match states[source.value] {
    Constant(I32(value)) | Constant(Char(value)) => Constant(evaluate(value))
    Unknown => Unknown
    Constant(_) | Overdefined => Overdefined
  }
}

///|
fn sparse_i32_binary(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
  evaluate : (Int, Int) -> SparseConstant,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(I32(a)), Constant(I32(b)))
    | (Constant(Char(a)), Constant(Char(b))) => Constant(evaluate(a, b))
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn sparse_i64_unary(
  states : Array[SparseValueState],
  source : ValueId,
  evaluate : (Int64) -> SparseConstant,
) -> SparseValueState {
  match states[source.value] {
    Constant(I64(value)) => Constant(evaluate(value))
    Unknown => Unknown
    Constant(_) | Overdefined => Overdefined
  }
}

///|
fn sparse_i64_binary(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
  evaluate : (Int64, Int64) -> SparseConstant,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(I64(a)), Constant(I64(b))) => Constant(evaluate(a, b))
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn sparse_bool_unary(
  states : Array[SparseValueState],
  source : ValueId,
  evaluate : (Bool) -> SparseConstant,
) -> SparseValueState {
  match states[source.value] {
    Constant(Bool(value)) => Constant(evaluate(value))
    Unknown => Unknown
    Constant(_) | Overdefined => Overdefined
  }
}

///|
fn sparse_bool_binary(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
  evaluate : (Bool, Bool) -> SparseConstant,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(Bool(a)), Constant(Bool(b))) => Constant(evaluate(a, b))
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn sparse_i32_div(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(I32(a)), Constant(I32(b))) if b != 0 &&
      !(a == -2147483648 && b == -1) => Constant(I32(a / b))
    (Constant(I32(_)), Constant(I32(_))) => Overdefined
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn sparse_i32_rem(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(I32(a)), Constant(I32(b))) if b != 0 => Constant(I32(a % b))
    (Constant(I32(_)), Constant(I32(_))) => Overdefined
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn sparse_i64_div(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(I64(a)), Constant(I64(b))) if b != 0L &&
      !(a == -9223372036854775808L && b == -1L) => Constant(I64(a / b))
    (Constant(I64(_)), Constant(I64(_))) => Overdefined
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn sparse_i64_rem(
  states : Array[SparseValueState],
  left : ValueId,
  right : ValueId,
) -> SparseValueState {
  match (states[left.value], states[right.value]) {
    (Constant(I64(a)), Constant(I64(b))) if b != 0L => Constant(I64(a % b))
    (Constant(I64(_)), Constant(I64(_))) => Overdefined
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Overdefined
  }
}

///|
fn fold_sparse_instruction(
  values : Array[ValueMetadata],
  states : Array[SparseValueState],
  instruction : Instruction,
) -> Instruction {
  guard instruction_destinations(instruction) is [destination] &&
    evaluate_sparse_instruction(values, states, instruction) is Constant(value) else {
    return instruction
  }
  sparse_constant_instruction(destination, value)
}

///|
fn sparse_constant_instruction(
  destination : ValueId,
  value : SparseConstant,
) -> Instruction {
  match value {
    I64(value) => ConstI64(destination, value)
    I32(value) => ConstI32(destination, value)
    Char(value) => ConstChar(destination, value)
    F64(bits) => ConstF64(destination, bits)
    F32(bits) => ConstF32(destination, bits)
    Bool(value) => ConstBool(destination, value)
    Layout(layout) => ConstLayout(destination, layout)
    Function(function) => ConstFunction(destination, function)
  }
}

///|
fn fold_sparse_terminator(
  states : Array[SparseValueState],
  terminator : Terminator,
) -> Terminator {
  match terminator {
    BranchBool(condition, if_true, if_false) =>
      match states[condition.value] {
        Constant(Bool(true)) => Jump(if_true)
        Constant(Bool(false)) => Jump(if_false)
        _ => terminator
      }
    SwitchTag(tag, cases, default) =>
      match states[tag.value] {
        Constant(I64(value)) if value >= 0L && value < cases.length().to_int64() =>
          Jump(cases[value.to_int()])
        Constant(I64(_)) => Jump(default)
        _ => terminator
      }
    _ => terminator
  }
}
