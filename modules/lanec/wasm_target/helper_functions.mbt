///|
fn compile_helper_function(
  role : WasmHelperFunctionRole,
  static_image : StaticImage,
  catalog : WasmFunctionCatalog,
) -> @wasm_types.FunctionCode {
  let retain_ref = catalog.runtime(RetainReference)
  let release_ref = catalog.runtime(ReleaseReference)
  let body : Array[@wasm_types.Instruction] = match role {
    NoopErased | DestroyNoop => []
    RetainReferenceErased => [LocalGet(0), I32WrapI64, retain_ref.call()]
    ReleaseReferenceErased => [LocalGet(0), I32WrapI64, release_ref.call()]
    RetainCallable =>
      [LocalGet(0), I64Const(32L), I64ShrU, I32WrapI64, retain_ref.call()]
    ReleaseCallable =>
      [LocalGet(0), I64Const(32L), I64ShrU, I32WrapI64, release_ref.call()]
    DestroyHostObject =>
      match catalog.find(InternalRuntimeImport(HostObjectRelease)) {
        Some(import_) => [LocalGet(0), I64Load(0, 3, 8L), import_.call()]
        None => []
      }
    DestroyShape(shape~) =>
      destroy_shape_body(
        static_image,
        catalog,
        catalog.entry(catalog.helper(ReleaseReferenceErased)).type_index,
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
