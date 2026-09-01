///|
fn compile_instruction(
  locals : FunctionLocalPlan,
  slots : Array[@physical.SlotMetadata],
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
  instruction : @physical.Instruction,
) -> Array[@wasm_types.Instruction] {
  match instruction {
    Copy(destination, source) =>
      [
        LocalGet(locals.slot_local(source)),
        LocalSet(locals.slot_local(destination)),
      ]
    Move(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(source)),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    RetainCopy(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(source)),
        LocalSet(locals.slot_local(destination)),
      ]
      match slots[destination.value].cleanup {
        Trivial => ()
        OwnedRef => {
          result.push(LocalGet(locals.slot_local(destination)))
          result.push(function_catalog.runtime(RetainReference).call())
        }
        OwnedCallable => {
          result.push(LocalGet(locals.slot_local(destination)))
          result.push(I64Const(32L))
          result.push(I64ShrU)
          result.push(I32WrapI64)
          result.push(function_catalog.runtime(RetainReference).call())
        }
        OwnedErased => {
          let witness = slots[destination.value].erased_companion.unwrap()
          result.append(
            compile_erased_ownership_call(
              locals, wasm_module, destination, witness, 16,
            ),
          )
        }
      }
      result
    }
    Release(source) => {
      let result : Array[@wasm_types.Instruction] = match
        slots[source.value].cleanup {
        Trivial => []
        OwnedRef =>
          [
            LocalGet(locals.slot_local(source)),
            function_catalog.runtime(ReleaseReference).call(),
          ]
        OwnedCallable =>
          [
            LocalGet(locals.slot_local(source)),
            I64Const(32L),
            I64ShrU,
            I32WrapI64,
            function_catalog.runtime(ReleaseReference).call(),
          ]
        OwnedErased => {
          let witness = slots[source.value].erased_companion.unwrap()
          compile_erased_ownership_call(
            locals, wasm_module, source, witness, 20,
          )
        }
      }
      result
    }
    ConstI64(destination, value) =>
      [I64Const(value), LocalSet(locals.slot_local(destination))]
    ConstI32(destination, value) =>
      [I32Const(value), LocalSet(locals.slot_local(destination))]
    ConstChar(destination, value) =>
      [I32Const(value), LocalSet(locals.slot_local(destination))]
    ConstF64(destination, bits) =>
      [
        F64Const(bits.reinterpret_as_double()),
        LocalSet(locals.slot_local(destination)),
      ]
    ConstF32(destination, bits) =>
      [
        F32Const(Float::reinterpret_from_int(bits)),
        LocalSet(locals.slot_local(destination)),
      ]
    ConstBool(destination, value) =>
      [
        I32Const(if value { 1 } else { 0 }),
        LocalSet(locals.slot_local(destination)),
      ]
    ConstLayout(destination, layout) =>
      [I32Const(layout.value), LocalSet(locals.slot_local(destination))]
    ConstFunction(destination, target) => {
      let result : Array[@wasm_types.Instruction] = [
        I64Const(
          function_catalog.image_table_slot(target).unwrap().index.to_int64(),
        ),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    ConstString(destination, constant) => {
      let result : Array[@wasm_types.Instruction] = [
        I32Const(static_image.constant_refs[constant.value]),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    CallDirect(target, environment, witnesses, arguments, destination) => {
      let result : Array[@wasm_types.Instruction] = []
      match environment {
        Some(slot) => result.push(LocalGet(locals.slot_local(slot)))
        None => result.push(I32Const(0))
      }
      for slot in witnesses {
        result.push(LocalGet(locals.slot_local(slot)))
      }
      for slot in arguments {
        result.push(LocalGet(locals.slot_local(slot)))
      }
      result.push(function_catalog.image_function(target).call())
      if destination is Some(slot) {
        result.push(LocalSet(locals.slot_local(slot)))
      }
      result
    }
    CallRuntimeImport(target, arguments, destination) => {
      let result : Array[@wasm_types.Instruction] = [I32Const(0)]
      for argument in arguments {
        match argument {
          Direct(slot) => result.push(LocalGet(locals.slot_local(slot)))
          GuestAddress(buffer, offset) =>
            result.append([
              LocalGet(locals.slot_local(buffer)),
              function_catalog.runtime(RequireByteBufferLayout).call(),
              LocalGet(locals.slot_local(offset)),
              LocalGet(locals.slot_local(buffer)),
              I32Load(0, 2, 8L),
              I32GtU,
              If(Empty, [Unreachable], []),
              LocalGet(locals.slot_local(buffer)),
              I32Const(12),
              I32Add,
              LocalGet(locals.slot_local(offset)),
              I32Add,
            ])
        }
      }
      result.push(function_catalog.image_function(target).call())
      if destination is Some(slot) {
        result.push(LocalSet(locals.slot_local(slot)))
      }
      result
    }
    CallPackedDirect(target, callable, witnesses, arguments, destination) => {
      let result = load_packed_direct_environment(
        locals, function_catalog, callable, target,
      )
      for slot in witnesses {
        result.push(LocalGet(locals.slot_local(slot)))
      }
      for slot in arguments {
        result.push(LocalGet(locals.slot_local(slot)))
      }
      result.push(function_catalog.image_function(target).call())
      if destination is Some(slot) {
        result.push(LocalSet(locals.slot_local(slot)))
      }
      result
    }
    CallValue(callable, abi_id, witnesses, arguments, destination) => {
      let result = validate_callable_abi(
        locals, function_catalog, callable, abi_id,
      )
      result.append([
        LocalGet(locals.slot_local(callable)),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
      ])
      for slot in witnesses {
        result.push(LocalGet(locals.slot_local(slot)))
      }
      for slot in arguments {
        result.push(LocalGet(locals.slot_local(slot)))
      }
      result.push(LocalGet(locals.slot_local(callable)))
      result.push(I32WrapI64)
      let type_index = indirect_type(
        wasm_module,
        static_image.callable_abi(abi_id),
      )
      result.push(CallIndirect(type_index, 0))
      if destination is Some(slot) {
        result.push(LocalSet(locals.slot_local(slot)))
      }
      result
    }
    MakeClosure(destination, target, environment) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(environment)),
        I64ExtendI32U,
        I64Const(32L),
        I64Shl,
        I64Const(
          function_catalog.image_table_slot(target).unwrap().index.to_int64(),
        ),
        I64Or,
        LocalSet(locals.slot_local(destination)),
      ]
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
          LocalSet(locals.slot_local(destination)),
        ]
      } else {
        compile_object_construction(
          locals, static_image, function_catalog, destination, shape, layout, witnesses,
          fields,
        )
      }
      result
    }
    MakeEnv(destination, shape, layout, witnesses, captures) => {
      let result = compile_object_construction(
        locals, static_image, function_catalog, destination, shape, layout, witnesses,
        captures,
      )
      result
    }
    LoadTag(destination, object) => {
      guard slots[object.value].kind is DataValue(family) else {
        abort("verified LoadTag source lost its Data family")
      }
      let result = compile_data_family_guard(
        locals, static_image, object, family,
      )
      result.append([
        LocalGet(locals.slot_local(object)),
        I32Load(0, 2, 8L),
        LocalSet(locals.slot_local(destination)),
      ])
      result
    }
    LoadObjectWitness(destination, shape, object, ordinal) =>
      [
        LocalGet(locals.slot_local(object)),
        I32Load(
          0,
          2,
          (static_image.shape_layouts[shape.value].witness_base + ordinal * 4).to_int64(),
        ),
        LocalSet(locals.slot_local(destination)),
      ]
    BorrowField(shape, object, field_index, result) =>
      compile_projection(
        locals, static_image, shape, object, field_index, result,
      )
    BorrowCapture(shape, environment, capture_index, result) =>
      compile_projection(
        locals, static_image, shape, environment, capture_index, result,
      )
    ConsumeFields(shape, object, selections)
    | ConsumeCaptures(shape, object, selections) => {
      let result = compile_consuming_projection(
        locals, static_image, function_catalog, wasm_module, shape, object, selections,
      )
      result
    }
    ByteToI64(destination, source) =>
      [
        LocalGet(locals.slot_local(source)),
        I64ExtendI32U,
        LocalSet(locals.slot_local(destination)),
      ]
    I64ToByte(destination, source) =>
      [
        LocalGet(locals.slot_local(source)),
        I64Const(255L),
        I64And,
        I32WrapI64,
        LocalSet(locals.slot_local(destination)),
      ]
    ByteSequenceMake(destination, length, fill) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(length)),
        LocalGet(locals.slot_local(fill)),
        function_catalog.runtime(ByteSequenceMake).call(),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    ByteSequenceLength(destination, source) =>
      [
        LocalGet(locals.slot_local(source)),
        function_catalog.runtime(RequireByteSequenceLayout).call(),
        LocalGet(locals.slot_local(source)),
        I32Load(0, 2, 8L),
        I64ExtendI32U,
        LocalSet(locals.slot_local(destination)),
      ]
    ByteSequenceGet(destination, source, index) =>
      [
        LocalGet(locals.slot_local(source)),
        LocalGet(locals.slot_local(index)),
        function_catalog.runtime(ByteSequenceGet).call(),
        LocalSet(locals.slot_local(destination)),
      ]
    ByteSequenceSet(destination, source, index, value) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(source)),
        LocalGet(locals.slot_local(index)),
        LocalGet(locals.slot_local(value)),
        function_catalog.runtime(ByteSequenceSet).call(),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    ByteBufferMake(destination, length) =>
      [
        LocalGet(locals.slot_local(length)),
        function_catalog.runtime(ByteBufferMake).call(),
        LocalSet(locals.slot_local(destination)),
      ]
    ByteBufferWriteBytes(buffer, index, source) =>
      [
        LocalGet(locals.slot_local(buffer)),
        LocalGet(locals.slot_local(index)),
        LocalGet(locals.slot_local(source)),
        function_catalog.runtime(ByteBufferWriteBytes).call(),
      ]
    ByteBufferWriteI32(buffer, index, value) =>
      [
        LocalGet(locals.slot_local(buffer)),
        LocalGet(locals.slot_local(index)),
        LocalGet(locals.slot_local(value)),
        function_catalog.runtime(ByteBufferWriteI32).call(),
      ]
    ByteBufferWriteAddress(buffer, index, target, offset) =>
      [
        LocalGet(locals.slot_local(buffer)),
        LocalGet(locals.slot_local(index)),
        LocalGet(locals.slot_local(target)),
        LocalGet(locals.slot_local(offset)),
        function_catalog.runtime(ByteBufferWriteAddress).call(),
      ]
    ByteBufferReadI32(destination, buffer, index) =>
      [
        LocalGet(locals.slot_local(buffer)),
        LocalGet(locals.slot_local(index)),
        function_catalog.runtime(ByteBufferReadI32).call(),
        LocalSet(locals.slot_local(destination)),
      ]
    ByteSequenceConcat(destination, left, right) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(left)),
        LocalGet(locals.slot_local(right)),
        function_catalog.runtime(ByteSequenceConcat).call(),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    ByteSequenceSlice(destination, string, start, length) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(string)),
        LocalGet(locals.slot_local(start)),
        LocalGet(locals.slot_local(length)),
        function_catalog.runtime(ByteSequenceSlice).call(),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    ByteSequenceEqual(destination, left, right) =>
      [
        LocalGet(locals.slot_local(left)),
        LocalGet(locals.slot_local(right)),
        function_catalog.runtime(ByteSequenceEqual).call(),
        LocalSet(locals.slot_local(destination)),
      ]
    ByteSequenceIsValidUtf8(destination, source) =>
      [
        LocalGet(locals.slot_local(source)),
        function_catalog.runtime(ByteSequenceIsValidUtf8).call(),
        LocalSet(locals.slot_local(destination)),
      ]
    I32Add(destination, left, right) =>
      binary(locals, destination, left, right, I32Add)
    I32Sub(destination, left, right) =>
      binary(locals, destination, left, right, I32Sub)
    I32Mul(destination, left, right) =>
      binary(locals, destination, left, right, I32Mul)
    I32Neg(destination, source) =>
      [
        I32Const(0),
        LocalGet(locals.slot_local(source)),
        I32Sub,
        LocalSet(locals.slot_local(destination)),
      ]
    I32Div(destination, left, right) =>
      binary(locals, destination, left, right, I32DivS)
    I32Rem(destination, left, right) =>
      binary(locals, destination, left, right, I32RemS)
    I32Eq(destination, left, right) =>
      binary(locals, destination, left, right, I32Eq)
    I32Lt(destination, left, right) =>
      binary(locals, destination, left, right, I32LtS)
    I32ToI64(destination, source) =>
      unary(locals, destination, source, I64ExtendI32S)
    I64ToI32(destination, source) =>
      unary(locals, destination, source, I32WrapI64)
    I64Add(destination, left, right) =>
      binary(locals, destination, left, right, I64Add)
    I64Sub(destination, left, right) =>
      binary(locals, destination, left, right, I64Sub)
    I64Mul(destination, left, right) =>
      binary(locals, destination, left, right, I64Mul)
    I64Neg(destination, source) =>
      [
        I64Const(0L),
        LocalGet(locals.slot_local(source)),
        I64Sub,
        LocalSet(locals.slot_local(destination)),
      ]
    I64Div(destination, left, right) =>
      binary(locals, destination, left, right, I64DivS)
    I64Rem(destination, left, right) =>
      binary(locals, destination, left, right, I64RemS)
    I64And(destination, left, right) =>
      binary(locals, destination, left, right, I64And)
    I64Or(destination, left, right) =>
      binary(locals, destination, left, right, I64Or)
    I64Xor(destination, left, right) =>
      binary(locals, destination, left, right, I64Xor)
    I64Not(destination, source) =>
      [
        LocalGet(locals.slot_local(source)),
        I64Const(-1L),
        I64Xor,
        LocalSet(locals.slot_local(destination)),
      ]
    I64Shl(destination, left, right) =>
      binary(locals, destination, left, right, I64Shl)
    I64ShrS(destination, left, right) =>
      binary(locals, destination, left, right, I64ShrS)
    I64Eq(destination, left, right) =>
      binary(locals, destination, left, right, I64Eq)
    I64Ne(destination, left, right) =>
      binary(locals, destination, left, right, I64Ne)
    I64Lt(destination, left, right) =>
      binary(locals, destination, left, right, I64LtS)
    I64Le(destination, left, right) =>
      binary(locals, destination, left, right, I64LeS)
    I64Gt(destination, left, right) =>
      binary(locals, destination, left, right, I64GtS)
    I64Ge(destination, left, right) =>
      binary(locals, destination, left, right, I64GeS)
    BoolNot(destination, source) => unary(locals, destination, source, I32Eqz)
    BoolEq(destination, left, right) =>
      binary(locals, destination, left, right, I32Eq)
    BoolNe(destination, left, right) =>
      binary(locals, destination, left, right, I32Ne)
    F64Add(destination, left, right) =>
      binary(locals, destination, left, right, F64Add)
    F64Sub(destination, left, right) =>
      binary(locals, destination, left, right, F64Sub)
    F64Mul(destination, left, right) =>
      binary(locals, destination, left, right, F64Mul)
    F64Div(destination, left, right) =>
      binary(locals, destination, left, right, F64Div)
    F64Neg(destination, source) => unary(locals, destination, source, F64Neg)
    F64Eq(destination, left, right) =>
      binary(locals, destination, left, right, F64Eq)
    F64Ne(destination, left, right) =>
      binary(locals, destination, left, right, F64Ne)
    F64Lt(destination, left, right) =>
      binary(locals, destination, left, right, F64Lt)
    F64Le(destination, left, right) =>
      binary(locals, destination, left, right, F64Le)
    F64Gt(destination, left, right) =>
      binary(locals, destination, left, right, F64Gt)
    F64Ge(destination, left, right) =>
      binary(locals, destination, left, right, F64Ge)
    I64ToF64(destination, source) =>
      unary(locals, destination, source, F64ConvertI64S)
    F64ToI64(destination, source) =>
      unary(locals, destination, source, I64TruncF64S)
    F32Add(destination, left, right) =>
      binary(locals, destination, left, right, F32Add)
    F32Sub(destination, left, right) =>
      binary(locals, destination, left, right, F32Sub)
    F32Mul(destination, left, right) =>
      binary(locals, destination, left, right, F32Mul)
    F32Div(destination, left, right) =>
      binary(locals, destination, left, right, F32Div)
    F32Neg(destination, source) => unary(locals, destination, source, F32Neg)
    F32Eq(destination, left, right) =>
      binary(locals, destination, left, right, F32Eq)
    F32Ne(destination, left, right) =>
      binary(locals, destination, left, right, F32Ne)
    F32Lt(destination, left, right) =>
      binary(locals, destination, left, right, F32Lt)
    F32Le(destination, left, right) =>
      binary(locals, destination, left, right, F32Le)
    F32Gt(destination, left, right) =>
      binary(locals, destination, left, right, F32Gt)
    F32Ge(destination, left, right) =>
      binary(locals, destination, left, right, F32Ge)
    I64ToF32(destination, source) =>
      unary(locals, destination, source, F32ConvertI64S)
    F32ToI64(destination, source) =>
      unary(locals, destination, source, I64TruncF32S)
    F32ToF64(destination, source) =>
      unary(locals, destination, source, F64PromoteF32)
    F64ToF32(destination, source) =>
      unary(locals, destination, source, F32DemoteF64)
    F32ToString(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        I32Const(float_text_capacity()),
        function_catalog.runtime(ByteSequenceNew).call(),
        LocalSet(locals.slot_local(destination)),
        LocalGet(locals.slot_local(destination)),
        LocalGet(locals.slot_local(source)),
        LocalGet(locals.slot_local(destination)),
        I32Const(12),
        I32Add,
        function_catalog.builtin(FormatF32).call(),
        I32Store(0, 2, 8L),
      ]
      result
    }
    F64ToString(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        I32Const(float_text_capacity()),
        function_catalog.runtime(ByteSequenceNew).call(),
        LocalSet(locals.slot_local(destination)),
        LocalGet(locals.slot_local(destination)),
        LocalGet(locals.slot_local(source)),
        LocalGet(locals.slot_local(destination)),
        I32Const(12),
        I32Add,
        function_catalog.builtin(FormatF64).call(),
        I32Store(0, 2, 8L),
      ]
      result
    }
    EraseI32(destination, source) =>
      compile_erasure_transfer(locals, destination, source, [I64ExtendI32U])
    UneraseI32(destination, source) => {
      let result = compile_unerasure_shape_guard(
        locals, static_image, slots, destination, source,
      )
      result.append(
        compile_erasure_transfer(locals, destination, source, [I32WrapI64]),
      )
      result
    }
    EraseI64(destination, source) | UneraseI64(destination, source) => {
      let result : Array[@wasm_types.Instruction] = [
        LocalGet(locals.slot_local(source)),
        LocalSet(locals.slot_local(destination)),
      ]
      result
    }
    EraseF64(destination, source) =>
      compile_erasure_transfer(locals, destination, source, [I64ReinterpretF64])
    UneraseF64(destination, source) =>
      compile_erasure_transfer(locals, destination, source, [F64ReinterpretI64])
    EraseF32(destination, source) =>
      compile_erasure_transfer(locals, destination, source, [
        I32ReinterpretF32,
        I64ExtendI32U,
      ])
    UneraseF32(destination, source) =>
      compile_erasure_transfer(locals, destination, source, [
        I32WrapI64,
        F32ReinterpretI32,
      ])
    EraseUnit(destination) =>
      [I64Const(0L), LocalSet(locals.slot_local(destination))]
    UneraseUnit(_) => []
    InitGlobal(global, source) =>
      compile_global_initialization(locals, slots, static_image, global, source)
    BorrowGlobal(destination, global) =>
      compile_global_borrow(locals, slots, static_image, destination, global)
  }
}

///|
fn compile_erased_ownership_call(
  locals : FunctionLocalPlan,
  wasm_module : @wasm_types.Module,
  payload : @physical.SlotId,
  witness : @physical.SlotId,
  descriptor_offset : Int,
) -> Array[@wasm_types.Instruction] {
  let type_index = intern_function_type(wasm_module, [I64], [])
  [
    LocalGet(locals.slot_local(payload)),
    LocalGet(locals.slot_local(witness)),
    I32Const(5),
    I32Shl,
    GlobalGet(layout_table_base_global_index),
    I32Add,
    I32Load(0, 2, descriptor_offset.to_int64()),
    CallIndirect(type_index, 0),
  ]
}

///|
fn compile_consuming_projection(
  locals : FunctionLocalPlan,
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
  wasm_module : @wasm_types.Module,
  shape : @physical.ObjectShapeId,
  object : @physical.SlotId,
  selections : Array[@physical.ProjectionSelection],
) -> Array[@wasm_types.Instruction] {
  let schemas = match static_image.object_shapes[shape.value] {
    Data(data_shape) => data_shape.members
    Environment(environment_shape) => environment_shape.members
  }
  let instructions : Array[@wasm_types.Instruction] = []
  for selection in selections {
    instructions.append(
      compile_projection(
        locals,
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
        instructions.push(LocalGet(locals.slot_local(destination)))
        instructions.push(function_catalog.runtime(RetainReference).call())
      }
      OwnedCallable => {
        instructions.push(LocalGet(locals.slot_local(destination)))
        instructions.push(I64Const(32L))
        instructions.push(I64ShrU)
        instructions.push(I32WrapI64)
        instructions.push(function_catalog.runtime(RetainReference).call())
      }
      OwnedErased => {
        let witness = selection.result.witness_destination.unwrap()
        instructions.append(
          compile_erased_ownership_call(
            locals, wasm_module, destination, witness, 16,
          ),
        )
      }
    }
  }
  instructions.push(LocalGet(locals.slot_local(object)))
  instructions.push(function_catalog.runtime(ReleaseReference).call())
  instructions
}

///|
fn compile_layout_operand(
  locals : FunctionLocalPlan,
  operand : @physical.LayoutOperand,
) -> Array[@wasm_types.Instruction] {
  match operand {
    Immediate(layout) => [I32Const(layout.value)]
    Witness(slot) => [LocalGet(locals.slot_local(slot))]
  }
}

///|
fn compile_store(
  locals : FunctionLocalPlan,
  object : @physical.SlotId,
  source : @physical.SlotId,
  offset : Int,
  representation : @physical.Representation,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = [
    LocalGet(locals.slot_local(object)),
    LocalGet(locals.slot_local(source)),
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
  locals : FunctionLocalPlan,
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
  destination : @physical.SlotId,
  shape_id : @physical.ObjectShapeId,
  layout : @physical.LayoutOperand,
  witnesses : Array[@physical.SlotId],
  fields : Array[@physical.SlotId],
) -> Array[@wasm_types.Instruction] {
  let shape_layout = static_image.shape_layouts[shape_id.value]
  let instructions : Array[@wasm_types.Instruction] = [
    I32Const(shape_layout.size),
    function_catalog.runtime(Allocate).call(),
    LocalSet(locals.slot_local(destination)),
    LocalGet(locals.slot_local(destination)),
    I32Const(1),
    I32Store(0, 2, 0L),
    LocalGet(locals.slot_local(destination)),
  ]
  instructions.append(compile_layout_operand(locals, layout))
  instructions.push(I32Store(0, 2, 4L))
  let shape = static_image.object_shapes[shape_id.value]
  if shape is Data(data_shape) {
    instructions.push(LocalGet(locals.slot_local(destination)))
    instructions.push(I32Const(data_shape.constructor_tag))
    instructions.push(I32Store(0, 2, 8L))
  }
  for index, witness in witnesses {
    instructions.append(
      compile_store(
        locals,
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
        locals,
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
  locals : FunctionLocalPlan,
  static_image : StaticImage,
  shape : @physical.ObjectShapeId,
  object : @physical.SlotId,
  member_index : Int,
  result : @physical.ProjectionResult,
) -> Array[@wasm_types.Instruction] {
  let shape_layout = static_image.shape_layouts[shape.value]
  let schema = match static_image.object_shapes[shape.value] {
    Data(data_shape) => data_shape.members[member_index]
    Environment(environment_shape) => environment_shape.members[member_index]
  }
  let instructions : Array[@wasm_types.Instruction] = [
    LocalGet(locals.slot_local(object)),
  ]
  instructions.push(
    match schema.representation {
      I32 => I32Load(0, 2, shape_layout.member_offsets[member_index].to_int64())
      I64 => I64Load(0, 3, shape_layout.member_offsets[member_index].to_int64())
      F64 => F64Load(0, 3, shape_layout.member_offsets[member_index].to_int64())
      F32 => F32Load(0, 2, shape_layout.member_offsets[member_index].to_int64())
    },
  )
  instructions.push(LocalSet(locals.slot_local(result.value_destination)))
  if result.witness_destination is Some(destination) &&
    schema.witness_ordinal is Some(ordinal) {
    instructions.push(LocalGet(locals.slot_local(object)))
    instructions.push(
      I32Load(0, 2, (shape_layout.witness_base + ordinal * 4).to_int64()),
    )
    instructions.push(LocalSet(locals.slot_local(destination)))
  }
  instructions
}

///|
fn compile_unerasure_shape_guard(
  locals : FunctionLocalPlan,
  static_image : StaticImage,
  slots : Array[@physical.SlotMetadata],
  destination : @physical.SlotId,
  source : @physical.SlotId,
) -> Array[@wasm_types.Instruction] {
  guard @physical.statically_known_object_shape(
      static_image.object_shapes,
      slots[destination.value].kind,
    )
    is Some(shape) else {
    return []
  }
  [
    LocalGet(locals.slot_local(source)),
    I32WrapI64,
    I32Load(0, 2, 4L),
    I32Const(static_image.shape_layout_ids[shape.value]),
    I32Ne,
    If(Empty, [Unreachable], []),
  ]
}

///|
fn compile_data_family_guard(
  locals : FunctionLocalPlan,
  static_image : StaticImage,
  object : @physical.SlotId,
  family : @physical.DataFamilyId,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = []
  let mut alternatives = 0
  for shape_index, shape in static_image.object_shapes {
    if shape is Data({ family: actual, .. }) && actual == family {
      instructions.append([
        LocalGet(locals.slot_local(object)),
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
  locals : FunctionLocalPlan,
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  function_catalog : WasmFunctionCatalog,
  terminator : @physical.Terminator,
) -> Array[@wasm_types.Instruction] raise WasmCompileError {
  match terminator {
    Return(source) => {
      let instructions : Array[@wasm_types.Instruction] = []
      if source is Some(slot) {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      instructions.push(Return)
      instructions
    }
    TailCallDirect(target, environment, witnesses, arguments) => {
      let instructions : Array[@wasm_types.Instruction] = []
      match environment {
        Some(slot) => instructions.push(LocalGet(locals.slot_local(slot)))
        None => instructions.push(I32Const(0))
      }
      for slot in witnesses {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      for slot in arguments {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      instructions.push(function_catalog.image_function(target).return_call())
      instructions
    }
    TailCallPackedDirect(target, callable, witnesses, arguments) => {
      let instructions : Array[@wasm_types.Instruction] = []
      instructions.append(
        load_packed_direct_environment(
          locals, function_catalog, callable, target,
        ),
      )
      for slot in witnesses {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      for slot in arguments {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      instructions.push(function_catalog.image_function(target).return_call())
      instructions
    }
    TailCallValue(callable, abi_id, witnesses, arguments) => {
      let instructions = validate_callable_abi(
        locals, function_catalog, callable, abi_id,
      )
      instructions.append([
        LocalGet(locals.slot_local(callable)),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
      ])
      for slot in witnesses {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      for slot in arguments {
        instructions.push(LocalGet(locals.slot_local(slot)))
      }
      instructions.push(LocalGet(locals.slot_local(callable)))
      instructions.push(I32WrapI64)
      let type_index = indirect_type(
        wasm_module,
        static_image.callable_abi(abi_id),
      )
      instructions.push(ReturnCallIndirect(type_index, 0))
      instructions
    }
    Fatal => [Unreachable]
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
  locals : FunctionLocalPlan,
  destination : @physical.SlotId,
  source : @physical.SlotId,
  operations : Array[@wasm_types.Instruction],
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = [
    LocalGet(locals.slot_local(source)),
  ]
  instructions.append(operations)
  instructions.push(LocalSet(locals.slot_local(destination)))
  instructions
}

///|
fn indirect_type(
  wasm_module : @wasm_types.Module,
  abi : @physical.CallableAbi,
) -> Int {
  intern_function_type(
    wasm_module,
    wasm_callable_parameters(abi),
    wasm_function_results(abi.result),
  )
}

///|
fn validate_callable_abi(
  locals : FunctionLocalPlan,
  function_catalog : WasmFunctionCatalog,
  callable : @physical.SlotId,
  expected : @physical.CallableAbiId,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(locals.slot_local(callable)),
    I32Const(expected.value),
    function_catalog.helper(CallableAbiGuard).call(),
  ]
}

///|
fn load_packed_direct_environment(
  locals : FunctionLocalPlan,
  function_catalog : WasmFunctionCatalog,
  callable : @physical.SlotId,
  target : @physical.FunctionId,
) -> Array[@wasm_types.Instruction] {
  let target_slot = function_catalog.image_table_slot(target).unwrap()
  [
    LocalGet(locals.slot_local(callable)),
    I32Const(target_slot.index),
    function_catalog.helper(PackedCallableTargetGuard).call(),
    LocalGet(locals.slot_local(callable)),
    I64Const(32L),
    I64ShrU,
    I32WrapI64,
  ]
}

///|
fn unary(
  locals : FunctionLocalPlan,
  destination : @physical.SlotId,
  source : @physical.SlotId,
  operation : @wasm_types.Instruction,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(locals.slot_local(source)),
    operation,
    LocalSet(locals.slot_local(destination)),
  ]
}

///|
fn binary(
  locals : FunctionLocalPlan,
  destination : @physical.SlotId,
  left : @physical.SlotId,
  right : @physical.SlotId,
  operation : @wasm_types.Instruction,
) -> Array[@wasm_types.Instruction] {
  [
    LocalGet(locals.slot_local(left)),
    LocalGet(locals.slot_local(right)),
    operation,
    LocalSet(locals.slot_local(destination)),
  ]
}
