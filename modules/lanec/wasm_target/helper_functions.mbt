///|
fn compile_helper_function(
  role : WasmHelperFunctionRole,
  static_image : StaticImage,
  catalog : WasmFunctionCatalog,
  wasm_module : @wasm_types.Module,
) -> @wasm_types.FunctionCode {
  let body : Array[@wasm_types.Instruction] = match role {
    CallableAbiGuard =>
      [
        LocalGet(0),
        I32WrapI64,
        I32Eqz,
        LocalGet(0),
        I32WrapI64,
        I32Const(static_image.callable_table_size),
        I32GeU,
        I32Or,
        If(Empty, [Unreachable], []),
        I32Const(static_image.callable_target_abi_table_base),
        LocalGet(0),
        I32WrapI64,
        I32Const(2),
        I32Shl,
        I32Add,
        I32Load(0, 2, 0L),
        LocalGet(1),
        I32Const(1),
        I32Add,
        I32Ne,
        If(Empty, [Unreachable], []),
      ]
    PackedCallableTargetGuard =>
      [
        LocalGet(0),
        I32WrapI64,
        LocalGet(1),
        I32Ne,
        If(Empty, [Unreachable], []),
      ]
    NoopErased | DestroyNoop => []
    RetainReferenceErased =>
      [LocalGet(0), I32WrapI64, catalog.runtime(RetainReference).call()]
    ReleaseReferenceErased =>
      [LocalGet(0), I32WrapI64, catalog.runtime(ReleaseReference).call()]
    RetainCallable =>
      [
        LocalGet(0),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
        catalog.runtime(RetainReference).call(),
      ]
    ReleaseCallable =>
      [
        LocalGet(0),
        I64Const(32L),
        I64ShrU,
        I32WrapI64,
        catalog.runtime(ReleaseReference).call(),
      ]
    DestroyShape(shape~) =>
      destroy_shape_body(
        static_image,
        catalog,
        intern_function_type(wasm_module, [I64], []),
        shape,
      )
    ByteSequenceSizer =>
      [
        LocalGet(0),
        I32Load(0, 2, 8L),
        I32Const(19),
        I32Add,
        I32Const(-8),
        I32And,
      ]
  }
  { locals: [], body, }
}

///|
fn destroy_shape_body(
  static_image : StaticImage,
  catalog : WasmFunctionCatalog,
  erased_release_type : Int,
  shape_index : Int,
) -> Array[@wasm_types.Instruction] {
  let shape = static_image.object_shapes[shape_index]
  let shape_layout = static_image.shape_layouts[shape_index]
  let schemas = match shape {
    Data(data_shape) => data_shape.members
    Environment(environment_shape) => environment_shape.members
  }
  let instructions : Array[@wasm_types.Instruction] = []
  for index, schema in schemas {
    let offset = shape_layout.member_offsets[index].to_int64()
    match schema.cleanup {
      Trivial => ()
      OwnedRef => {
        instructions.push(LocalGet(0))
        instructions.push(I32Load(0, 2, offset))
        instructions.push(catalog.runtime(ReleaseReference).call())
      }
      OwnedCallable => {
        instructions.push(LocalGet(0))
        instructions.push(I64Load(0, 3, offset))
        instructions.push(I64Const(32L))
        instructions.push(I64ShrU)
        instructions.push(I32WrapI64)
        instructions.push(catalog.runtime(ReleaseReference).call())
      }
      OwnedErased => {
        instructions.push(LocalGet(0))
        instructions.push(I64Load(0, 3, offset))
        instructions.push(LocalGet(0))
        let ordinal = schema.witness_ordinal.unwrap()
        instructions.push(
          I32Load(0, 2, (shape_layout.witness_base + ordinal * 4).to_int64()),
        )
        instructions.push(I32Const(5))
        instructions.push(I32Shl)
        instructions.push(GlobalGet(layout_table_base_global_index))
        instructions.push(I32Add)
        instructions.push(I32Load(0, 2, 20L))
        instructions.push(CallIndirect(erased_release_type, 0))
      }
    }
  }
  instructions
}
