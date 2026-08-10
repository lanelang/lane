///|
fn compile_instruction(
  parameter_count : Int,
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  internal_imports : InternalRuntimeImports,
  instruction : @bytecode.Instruction,
) -> Array[@wasm_types.Instruction] {
  match instruction {
    Copy(destination, source) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    Move(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, source)),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_dead(live_base, slots, source))
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    RetainCopy(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, source)),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      match slots[destination.value].cleanup {
        Trivial => ()
        OwnedRef => {
          result.push(LocalGet(slot_local(parameter_count, destination)))
          result.push(Call(runtime_functions.retain_ref))
        }
        OwnedCallable => {
          result.push(LocalGet(slot_local(parameter_count, destination)))
          result.push(I64Const(32L))
          result.push(I64ShrU)
          result.push(I32WrapI64)
          result.push(Call(runtime_functions.retain_ref))
        }
        OwnedErased => {
          let witness = slots[destination.value].erased_companion.unwrap()
          result.append(
            compile_erased_ownership_call(
              parameter_count, wasm_module, destination, witness, 16,
            ),
          )
        }
      }
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    Release(source) => {
      let result : Array[@wasm_types.Instruction] = match
        slots[source.value].cleanup {
        Trivial => []
        OwnedRef =>
          [
            LocalGet(slot_local(parameter_count, source)),
            Call(runtime_functions.release_ref),
          ]
        OwnedCallable =>
          [
            LocalGet(slot_local(parameter_count, source)),
            I64Const(32L),
            I64ShrU,
            I32WrapI64,
            Call(runtime_functions.release_ref),
          ]
        OwnedErased => {
          let witness = slots[source.value].erased_companion.unwrap()
          compile_erased_ownership_call(
            parameter_count, wasm_module, source, witness, 20,
          )
        }
      }
      result.append(mark_slot_dead(live_base, slots, source))
      result
    }
    ConstI64(destination, value) =>
      [I64Const(value), LocalSet(slot_local(parameter_count, destination))]
    ConstI32(destination, value) =>
      [I32Const(value), LocalSet(slot_local(parameter_count, destination))]
    ConstChar(destination, value) =>
      [I32Const(value), LocalSet(slot_local(parameter_count, destination))]
    ConstF64(destination, bits) =>
      [
        F64Const(bits.reinterpret_as_double()),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ConstF32(destination, bits) =>
      [
        F32Const(Float::reinterpret_from_int(bits)),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ConstBool(destination, value) =>
      [
        I32Const(if value { 1 } else { 0 }),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ConstLayout(destination, layout) =>
      [
        I32Const(layout.value),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ConstFunction(destination, target) => {
      let result : Array[@wasm_types.Instruction] = [
        I64Const(static_image.callable_table_index(target).to_int64()),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    ConstString(destination, constant) => {
      let result : Array[@wasm_types.Instruction] = [
        I32Const(static_image.constant_refs[constant.value]),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    CallDirect(target, environment, witnesses, arguments, destination) => {
      let result : Array[@wasm_types.Instruction] = []
      match environment {
        Some(slot) => result.push(LocalGet(slot_local(parameter_count, slot)))
        None => result.push(I32Const(0))
      }
      for slot in witnesses {
        result.push(LocalGet(slot_local(parameter_count, slot)))
      }
      for slot in arguments {
        result.push(LocalGet(slot_local(parameter_count, slot)))
      }
      if environment is Some(slot) {
        result.append(mark_slot_dead(live_base, slots, slot))
      }
      for slot in arguments {
        result.append(mark_slot_dead(live_base, slots, slot))
      }
      result.push(Call(static_image.wasm_function_offset + target.value - 1))
      if destination is Some(slot) {
        result.push(LocalSet(slot_local(parameter_count, slot)))
        result.append(mark_slot_live(live_base, slots, slot))
      }
      result
    }
    CallValue(callable, abi_id, witnesses, arguments, destination) => {
      let result = validate_callable_abi(
        parameter_count, static_image, callable, abi_id,
      )
      result.append([
        LocalGet(slot_local(parameter_count, callable)),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
      ])
      for slot in witnesses {
        result.push(LocalGet(slot_local(parameter_count, slot)))
      }
      for slot in arguments {
        result.push(LocalGet(slot_local(parameter_count, slot)))
      }
      result.push(LocalGet(slot_local(parameter_count, callable)))
      result.push(I32WrapI64)
      result.append(mark_slot_dead(live_base, slots, callable))
      for slot in arguments {
        result.append(mark_slot_dead(live_base, slots, slot))
      }
      let type_index = indirect_type(
        wasm_module,
        static_image.callable_abi(abi_id),
      )
      result.push(CallIndirect(type_index, 0))
      if destination is Some(slot) {
        result.push(LocalSet(slot_local(parameter_count, slot)))
        result.append(mark_slot_live(live_base, slots, slot))
      }
      result
    }
    MakeClosure(destination, target, environment) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, environment)),
        I64ExtendI32U,
        I64Const(32L),
        I64Shl,
        I64Const(static_image.callable_table_index(target).to_int64()),
        I64Or,
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_dead(live_base, slots, environment))
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    MakeData(destination, shape, layout, witnesses, fields) => {
      let use_singleton = match layout {
        Immediate(layout_id) =>
          witnesses.is_empty() &&
          fields.is_empty() &&
          static_image.singleton_refs[shape.value] != 0 &&
          static_image.singleton_layout_ids[shape.value] == layout_id.value
        _ => false
      }
      let result : Array[@wasm_types.Instruction] = if use_singleton {
        [
          I32Const(static_image.singleton_refs[shape.value]),
          LocalSet(slot_local(parameter_count, destination)),
        ]
      } else {
        compile_object_construction(
          parameter_count, static_image, runtime_functions, destination, shape, layout,
          witnesses, fields,
        )
      }
      for field in fields {
        result.append(mark_slot_dead(live_base, slots, field))
      }
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    MakeEnv(destination, shape, layout, witnesses, captures) => {
      let result = compile_object_construction(
        parameter_count, static_image, runtime_functions, destination, shape, layout,
        witnesses, captures,
      )
      for capture in captures {
        result.append(mark_slot_dead(live_base, slots, capture))
      }
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    LoadTag(destination, object) => {
      guard slots[object.value].kind is DataValue(family) else {
        abort("verified LoadTag source lost its Data family")
      }
      let result = compile_data_family_guard(
        parameter_count, static_image, object, family,
      )
      result.append([
        LocalGet(slot_local(parameter_count, object)),
        I32Load(0, 2, 8L),
        LocalSet(slot_local(parameter_count, destination)),
      ])
      result
    }
    LoadObjectWitness(destination, shape, object, ordinal) =>
      [
        LocalGet(slot_local(parameter_count, object)),
        I32Load(
          0,
          2,
          (static_image.shape_layouts[shape.value].witness_base + ordinal * 4).to_int64(),
        ),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    BorrowField(shape, object, field_index, result) =>
      compile_projection(
        parameter_count, static_image, shape, object, field_index, result,
      )
    BorrowCapture(shape, environment, capture_index, result) =>
      compile_projection(
        parameter_count, static_image, shape, environment, capture_index, result,
      )
    ConsumeFields(shape, object, selections)
    | ConsumeCaptures(shape, object, selections) => {
      let result = compile_consuming_projection(
        parameter_count, static_image, runtime_functions, wasm_module, shape, object,
        selections,
      )
      result.append(mark_slot_dead(live_base, slots, object))
      for selection in selections {
        result.append(
          mark_slot_live(live_base, slots, selection.result.value_destination),
        )
      }
      result
    }
    ByteToI64(destination, source) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        I64ExtendI32U,
        LocalSet(slot_local(parameter_count, destination)),
      ]
    I64ToByte(destination, source) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        I64Const(255L),
        I64And,
        I32WrapI64,
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ByteSequenceMake(destination, length, fill) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, length)),
        LocalGet(slot_local(parameter_count, fill)),
        Call(runtime_functions.byte_sequence_make),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    ByteSequenceLength(destination, source) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        Call(runtime_functions.require_byte_sequence_layout),
        LocalGet(slot_local(parameter_count, source)),
        I32Load(0, 2, 8L),
        I64ExtendI32U,
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ByteSequenceGet(destination, source, index) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        LocalGet(slot_local(parameter_count, index)),
        Call(runtime_functions.byte_sequence_get),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ByteSequenceSet(destination, source, index, value) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, source)),
        LocalGet(slot_local(parameter_count, index)),
        LocalGet(slot_local(parameter_count, value)),
        Call(runtime_functions.byte_sequence_set),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_dead(live_base, slots, source))
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    ByteSequenceConcat(destination, left, right) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, left)),
        LocalGet(slot_local(parameter_count, right)),
        Call(runtime_functions.byte_sequence_concat),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_dead(live_base, slots, left))
      result.append(mark_slot_dead(live_base, slots, right))
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    ByteSequenceSlice(destination, string, start, length) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, string)),
        LocalGet(slot_local(parameter_count, start)),
        LocalGet(slot_local(parameter_count, length)),
        Call(runtime_functions.byte_sequence_slice),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_dead(live_base, slots, string))
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    ByteSequenceEqual(destination, left, right) =>
      [
        LocalGet(slot_local(parameter_count, left)),
        LocalGet(slot_local(parameter_count, right)),
        Call(runtime_functions.byte_sequence_equal),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    ByteSequenceIsValidUtf8(destination, source) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        Call(runtime_functions.byte_sequence_is_valid_utf8),
        LocalSet(slot_local(parameter_count, destination)),
      ]
    I32Add(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32Add)
    I32Sub(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32Sub)
    I32Mul(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32Mul)
    I32Neg(destination, source) =>
      [
        I32Const(0),
        LocalGet(slot_local(parameter_count, source)),
        I32Sub,
        LocalSet(slot_local(parameter_count, destination)),
      ]
    I32Div(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32DivS)
    I32Rem(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32RemS)
    I32Eq(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32Eq)
    I32Lt(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32LtS)
    I32ToI64(destination, source) =>
      unary(parameter_count, destination, source, I64ExtendI32S)
    I64ToI32(destination, source) =>
      unary(parameter_count, destination, source, I32WrapI64)
    I64Add(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Add)
    I64Sub(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Sub)
    I64Mul(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Mul)
    I64Neg(destination, source) =>
      [
        I64Const(0L),
        LocalGet(slot_local(parameter_count, source)),
        I64Sub,
        LocalSet(slot_local(parameter_count, destination)),
      ]
    I64Div(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64DivS)
    I64Rem(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64RemS)
    I64And(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64And)
    I64Or(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Or)
    I64Xor(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Xor)
    I64Not(destination, source) =>
      [
        LocalGet(slot_local(parameter_count, source)),
        I64Const(-1L),
        I64Xor,
        LocalSet(slot_local(parameter_count, destination)),
      ]
    I64Shl(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Shl)
    I64ShrS(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64ShrS)
    I64Eq(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Eq)
    I64Ne(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64Ne)
    I64Lt(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64LtS)
    I64Le(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64LeS)
    I64Gt(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64GtS)
    I64Ge(destination, left, right) =>
      binary(parameter_count, destination, left, right, I64GeS)
    BoolNot(destination, source) =>
      unary(parameter_count, destination, source, I32Eqz)
    BoolEq(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32Eq)
    BoolNe(destination, left, right) =>
      binary(parameter_count, destination, left, right, I32Ne)
    F64Add(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Add)
    F64Sub(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Sub)
    F64Mul(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Mul)
    F64Div(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Div)
    F64Neg(destination, source) =>
      unary(parameter_count, destination, source, F64Neg)
    F64Eq(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Eq)
    F64Ne(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Ne)
    F64Lt(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Lt)
    F64Le(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Le)
    F64Gt(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Gt)
    F64Ge(destination, left, right) =>
      binary(parameter_count, destination, left, right, F64Ge)
    I64ToF64(destination, source) =>
      unary(parameter_count, destination, source, F64ConvertI64S)
    F64ToI64(destination, source) =>
      unary(parameter_count, destination, source, I64TruncF64S)
    F32Add(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Add)
    F32Sub(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Sub)
    F32Mul(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Mul)
    F32Div(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Div)
    F32Neg(destination, source) =>
      unary(parameter_count, destination, source, F32Neg)
    F32Eq(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Eq)
    F32Ne(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Ne)
    F32Lt(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Lt)
    F32Le(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Le)
    F32Gt(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Gt)
    F32Ge(destination, left, right) =>
      binary(parameter_count, destination, left, right, F32Ge)
    I64ToF32(destination, source) =>
      unary(parameter_count, destination, source, F32ConvertI64S)
    F32ToI64(destination, source) =>
      unary(parameter_count, destination, source, I64TruncF32S)
    F32ToF64(destination, source) =>
      unary(parameter_count, destination, source, F64PromoteF32)
    F64ToF32(destination, source) =>
      unary(parameter_count, destination, source, F32DemoteF64)
    F32ToString(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, source)),
        Call(internal_imports.f32_to_string.unwrap()),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    F64ToString(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, source)),
        Call(internal_imports.f64_to_string.unwrap()),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    EraseI32(destination, source) =>
      compile_erasure_transfer(
        parameter_count,
        live_base,
        slots,
        destination,
        source,
        [I64ExtendI32U],
      )
    UneraseI32(destination, source) => {
      let result = compile_unerasure_shape_guard(
        parameter_count, static_image, slots, destination, source,
      )
      result.append(
        compile_erasure_transfer(
          parameter_count,
          live_base,
          slots,
          destination,
          source,
          [I32WrapI64],
        ),
      )
      result
    }
    EraseI64(destination, source) | UneraseI64(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(slot_local(parameter_count, source)),
        LocalSet(slot_local(parameter_count, destination)),
      ]
      result.append(mark_slot_dead(live_base, slots, source))
      result.append(mark_slot_live(live_base, slots, destination))
      result
    }
    EraseF64(destination, source) =>
      compile_erasure_transfer(
        parameter_count,
        live_base,
        slots,
        destination,
        source,
        [I64ReinterpretF64],
      )
    UneraseF64(destination, source) =>
      compile_erasure_transfer(
        parameter_count,
        live_base,
        slots,
        destination,
        source,
        [F64ReinterpretI64],
      )
    EraseF32(destination, source) =>
      compile_erasure_transfer(
        parameter_count,
        live_base,
        slots,
        destination,
        source,
        [I32ReinterpretF32, I64ExtendI32U],
      )
    UneraseF32(destination, source) =>
      compile_erasure_transfer(
        parameter_count,
        live_base,
        slots,
        destination,
        source,
        [I32WrapI64, F32ReinterpretI32],
      )
    EraseUnit(destination) =>
      [I64Const(0L), LocalSet(slot_local(parameter_count, destination))]
    UneraseUnit(_) => []
    InitGlobal(global, source) =>
      compile_global_initialization(
        parameter_count, live_base, slots, static_image, global, source,
      )
    BorrowGlobal(destination, global) =>
      compile_global_borrow(
        parameter_count, slots, static_image, destination, global,
      )
  }
}

///|
fn compile_erased_ownership_call(
  parameter_count : Int,
  wasm_module : @wasm_types.Module,
  payload : @bytecode.SlotId,
  witness : @bytecode.SlotId,
  descriptor_offset : Int,
) -> Array[@wasm_types.Instruction] {
  let type_index = intern_function_type(wasm_module, [I64], [])
  [
    LocalGet(slot_local(parameter_count, payload)),
    LocalGet(slot_local(parameter_count, witness)),
    I32Const(5),
    I32Shl,
    GlobalGet(layout_table_base_global_index),
    I32Add,
    I32Load(0, 2, descriptor_offset.to_int64()),
    CallIndirect(type_index, 0),
  ]
}

///|
fn compile_frame_cleanup(
  parameter_count : Int,
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  wasm_module : @wasm_types.Module,
  runtime_functions : RuntimeFunctions,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = []
  for index, slot in slots {
    if !(slot.cleanup is Trivial) {
      let slot_id : @bytecode.SlotId = { value: index }
      instructions.push(LocalGet(live_local(live_base, slot_id)))
      instructions.push(
        If(
          Empty,
          compile_slot_release(
            parameter_count, slots, wasm_module, runtime_functions, slot_id,
          ),
          [],
        ),
      )
    }
  }
  instructions
}

///|
fn compile_slot_release(
  parameter_count : Int,
  slots : Array[@bytecode.SlotMetadata],
  wasm_module : @wasm_types.Module,
  runtime_functions : RuntimeFunctions,
  source : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  match slots[source.value].cleanup {
    Trivial => []
    OwnedRef =>
      [
        LocalGet(slot_local(parameter_count, source)),
        Call(runtime_functions.release_ref),
      ]
    OwnedCallable =>
      [
        LocalGet(slot_local(parameter_count, source)),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
        Call(runtime_functions.release_ref),
      ]
    OwnedErased => {
      let witness = slots[source.value].erased_companion.unwrap()
      compile_erased_ownership_call(
        parameter_count, wasm_module, source, witness, 20,
      )
    }
  }
}

///|
fn compile_consuming_projection(
  parameter_count : Int,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  wasm_module : @wasm_types.Module,
  shape : @bytecode.ObjectShapeId,
  object : @bytecode.SlotId,
  selections : Array[@bytecode.ProjectionSelection],
) -> Array[@wasm_types.Instruction] {
  let schemas = match static_image.object_shapes[shape.value] {
    Data(data_shape) => data_shape.members
    Environment(environment_shape) => environment_shape.members
  }
  let instructions : Array[@wasm_types.Instruction] = []
  for selection in selections {
    instructions.append(
      compile_projection(
        parameter_count,
        static_image,
        shape,
        object,
        selection.member_index,
        selection.result,
      ),
    )
    let destination = selection.result.value_destination
    match schemas[selection.member_index].cleanup {
      Trivial => ()
      OwnedRef => {
        instructions.push(LocalGet(slot_local(parameter_count, destination)))
        instructions.push(Call(runtime_functions.retain_ref))
      }
      OwnedCallable => {
        instructions.push(LocalGet(slot_local(parameter_count, destination)))
        instructions.push(I64Const(32L))
        instructions.push(I64ShrU)
        instructions.push(I32WrapI64)
        instructions.push(Call(runtime_functions.retain_ref))
      }
      OwnedErased => {
        let witness = selection.result.witness_destination.unwrap()
        instructions.append(
          compile_erased_ownership_call(
            parameter_count, wasm_module, destination, witness, 16,
          ),
        )
      }
    }
  }
  instructions.push(LocalGet(slot_local(parameter_count, object)))
  instructions.push(Call(runtime_functions.release_ref))
  instructions
}

///|
fn compile_layout_operand(
  parameter_count : Int,
  operand : @bytecode.LayoutOperand,
) -> Array[@wasm_types.Instruction] {
  match operand {
    Immediate(layout) => [I32Const(layout.value)]
    Witness(slot) => [LocalGet(slot_local(parameter_count, slot))]
  }
}

///|
fn compile_store(
  parameter_count : Int,
  object : @bytecode.SlotId,
  source : @bytecode.SlotId,
  offset : Int,
  representation : @bytecode.Representation,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = [
    LocalGet(slot_local(parameter_count, object)),
    LocalGet(slot_local(parameter_count, source)),
  ]
  instructions.push(
    match representation {
      I32 => I32Store(0, 2, offset.to_int64())
      I64 => I64Store(0, 3, offset.to_int64())
      F64 => F64Store(0, 3, offset.to_int64())
      F32 => F32Store(0, 2, offset.to_int64())
    },
  )
  instructions
}

///|
fn compile_object_construction(
  parameter_count : Int,
  static_image : StaticImage,
  runtime_functions : RuntimeFunctions,
  destination : @bytecode.SlotId,
  shape_id : @bytecode.ObjectShapeId,
  layout : @bytecode.LayoutOperand,
  witnesses : Array[@bytecode.SlotId],
  fields : Array[@bytecode.SlotId],
) -> Array[@wasm_types.Instruction] {
  let shape_layout = static_image.shape_layouts[shape_id.value]
  let instructions : Array[@wasm_types.Instruction] = [
    I32Const(shape_layout.size),
    Call(runtime_functions.allocate),
    LocalSet(slot_local(parameter_count, destination)),
    LocalGet(slot_local(parameter_count, destination)),
    I32Const(1),
    I32Store(0, 2, 0L),
    LocalGet(slot_local(parameter_count, destination)),
  ]
  instructions.append(compile_layout_operand(parameter_count, layout))
  instructions.push(I32Store(0, 2, 4L))
  let shape = static_image.object_shapes[shape_id.value]
  if shape is Data(data_shape) {
    instructions.push(LocalGet(slot_local(parameter_count, destination)))
    instructions.push(I32Const(data_shape.constructor_tag))
    instructions.push(I32Store(0, 2, 8L))
  }
  for index, witness in witnesses {
    instructions.append(
      compile_store(
        parameter_count,
        destination,
        witness,
        shape_layout.witness_base + index * 4,
        I32,
      ),
    )
  }
  let schemas = match shape {
    Data(data_shape) => data_shape.members
    Environment(environment_shape) => environment_shape.members
  }
  for index, field in fields {
    instructions.append(
      compile_store(
        parameter_count,
        destination,
        field,
        shape_layout.member_offsets[index],
        schemas[index].representation,
      ),
    )
  }
  instructions
}

///|
fn compile_projection(
  parameter_count : Int,
  static_image : StaticImage,
  shape : @bytecode.ObjectShapeId,
  object : @bytecode.SlotId,
  member_index : Int,
  result : @bytecode.ProjectionResult,
) -> Array[@wasm_types.Instruction] {
  let shape_layout = static_image.shape_layouts[shape.value]
  let schema = match static_image.object_shapes[shape.value] {
    Data(data_shape) => data_shape.members[member_index]
    Environment(environment_shape) => environment_shape.members[member_index]
  }
  let instructions : Array[@wasm_types.Instruction] = [
    LocalGet(slot_local(parameter_count, object)),
  ]
  instructions.push(
    match schema.representation {
      I32 => I32Load(0, 2, shape_layout.member_offsets[member_index].to_int64())
      I64 => I64Load(0, 3, shape_layout.member_offsets[member_index].to_int64())
      F64 => F64Load(0, 3, shape_layout.member_offsets[member_index].to_int64())
      F32 => F32Load(0, 2, shape_layout.member_offsets[member_index].to_int64())
    },
  )
  instructions.push(
    LocalSet(slot_local(parameter_count, result.value_destination)),
  )
  if result.witness_destination is Some(destination) &&
    schema.witness_ordinal is Some(ordinal) {
    instructions.push(LocalGet(slot_local(parameter_count, object)))
    instructions.push(
      I32Load(0, 2, (shape_layout.witness_base + ordinal * 4).to_int64()),
    )
    instructions.push(LocalSet(slot_local(parameter_count, destination)))
  }
  instructions
}

///|
fn compile_unerasure_shape_guard(
  parameter_count : Int,
  static_image : StaticImage,
  slots : Array[@bytecode.SlotMetadata],
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
) -> Array[@wasm_types.Instruction] {
  guard @bytecode.statically_known_object_shape(
      static_image.object_shapes,
      slots[destination.value].kind,
    )
    is Some(shape) else {
    return []
  }
  [
    LocalGet(slot_local(parameter_count, source)),
    I32WrapI64,
    I32Load(0, 2, 4L),
    I32Const(static_image.shape_layout_ids[shape.value]),
    I32Ne,
    If(Empty, [Unreachable], []),
  ]
}

///|
fn compile_data_family_guard(
  parameter_count : Int,
  static_image : StaticImage,
  object : @bytecode.SlotId,
  family : @bytecode.DataFamilyId,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = []
  let mut alternatives = 0
  for shape_index, shape in static_image.object_shapes {
    if shape is Data({ family: actual, .. }) && actual == family {
      instructions.append([
        LocalGet(slot_local(parameter_count, object)),
        I32Load(0, 2, 4L),
        I32Const(static_image.shape_layout_ids[shape_index]),
        I32Eq,
      ])
      if alternatives > 0 {
        instructions.push(I32Or)
      }
      alternatives += 1
    }
  }
  if alternatives == 0 {
    abort("verified Data family has no object shape")
  }
  instructions.append([I32Eqz, If(Empty, [Unreachable], [])])
  instructions
}

///|
fn compile_terminator(
  function_id : Int,
  parameter_count : Int,
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  terminator : @bytecode.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  match terminator {
    Return(source) => {
      let instructions : Array[@wasm_types.Instruction] = [
        GlobalGet(call_depth_global_index),
        I32Const(1),
        I32Sub,
        GlobalSet(call_depth_global_index),
      ]
      if source is Some(slot) {
        instructions.push(LocalGet(slot_local(parameter_count, slot)))
      }
      instructions.push(Return)
      instructions
    }
    TailCallDirect(target, environment, witnesses, arguments) => {
      let instructions : Array[@wasm_types.Instruction] = [
        GlobalGet(call_depth_global_index),
        I32Const(1),
        I32Sub,
        GlobalSet(call_depth_global_index),
      ]
      match environment {
        Some(slot) =>
          instructions.push(LocalGet(slot_local(parameter_count, slot)))
        None => instructions.push(I32Const(0))
      }
      for slot in witnesses {
        instructions.push(LocalGet(slot_local(parameter_count, slot)))
      }
      for slot in arguments {
        instructions.push(LocalGet(slot_local(parameter_count, slot)))
      }
      if environment is Some(slot) {
        instructions.append(mark_slot_dead(live_base, slots, slot))
      }
      for slot in arguments {
        instructions.append(mark_slot_dead(live_base, slots, slot))
      }
      instructions.push(
        ReturnCall(static_image.wasm_function_offset + target.value - 1),
      )
      instructions
    }
    TailCallValue(callable, abi_id, witnesses, arguments) => {
      let instructions = validate_callable_abi(
        parameter_count, static_image, callable, abi_id,
      )
      instructions.append([
        GlobalGet(call_depth_global_index),
        I32Const(1),
        I32Sub,
        GlobalSet(call_depth_global_index),
        LocalGet(slot_local(parameter_count, callable)),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
      ])
      for slot in witnesses {
        instructions.push(LocalGet(slot_local(parameter_count, slot)))
      }
      for slot in arguments {
        instructions.push(LocalGet(slot_local(parameter_count, slot)))
      }
      instructions.push(LocalGet(slot_local(parameter_count, callable)))
      instructions.push(I32WrapI64)
      instructions.append(mark_slot_dead(live_base, slots, callable))
      for slot in arguments {
        instructions.append(mark_slot_dead(live_base, slots, slot))
      }
      let type_index = indirect_type(
        wasm_module,
        static_image.callable_abi(abi_id),
      )
      instructions.push(ReturnCallIndirect(type_index, 0))
      instructions
    }
    Unreachable => [Unreachable]
    unsupported =>
      raise UnsupportedInstruction(
        function_id~,
        instruction="\{Repr(unsupported)}",
      )
  }
}

///|
fn compile_erasure_transfer(
  parameter_count : Int,
  live_base : Int,
  slots : Array[@bytecode.SlotMetadata],
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  operations : Array[@wasm_types.Instruction],
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = [
    LocalGet(slot_local(parameter_count, source)),
  ]
  instructions.append(operations)
  instructions.push(LocalSet(slot_local(parameter_count, destination)))
  instructions.append(mark_slot_dead(live_base, slots, source))
  instructions.append(mark_slot_live(live_base, slots, destination))
  instructions
}

///|
fn indirect_type(
  wasm_module : @wasm_types.Module,
  abi : @bytecode.CallableAbi,
) -> Int {
  intern_function_type(
    wasm_module,
    wasm_callable_parameters(abi),
    wasm_function_results(abi.result),
  )
}

///|
fn validate_callable_abi(
  parameter_count : Int,
  static_image : StaticImage,
  callable : @bytecode.SlotId,
  expected : @bytecode.CallableAbiId,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(slot_local(parameter_count, callable)),
    I32WrapI64,
    I32Eqz,
    LocalGet(slot_local(parameter_count, callable)),
    I32WrapI64,
    I32Const(static_image.callable_table_size),
    I32GeU,
    I32Or,
    If(Empty, [Unreachable], []),
    I32Const(static_image.callable_abi_table_base),
    LocalGet(slot_local(parameter_count, callable)),
    I32WrapI64,
    I32Const(static_image.callable_abis.length()),
    I32Mul,
    I32Const(expected.value),
    I32Add,
    I32Const(2),
    I32Shl,
    I32Add,
    I32Load(0, 2, 0L),
    I32Eqz,
    If(Empty, [Unreachable], []),
  ]
}

///|
fn unary(
  parameter_count : Int,
  destination : @bytecode.SlotId,
  source : @bytecode.SlotId,
  operation : @wasm_types.Instruction,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(slot_local(parameter_count, source)),
    operation,
    LocalSet(slot_local(parameter_count, destination)),
  ]
}

///|
fn binary(
  parameter_count : Int,
  destination : @bytecode.SlotId,
  left : @bytecode.SlotId,
  right : @bytecode.SlotId,
  operation : @wasm_types.Instruction,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(slot_local(parameter_count, left)),
    LocalGet(slot_local(parameter_count, right)),
    operation,
    LocalSet(slot_local(parameter_count, destination)),
  ]
}
