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
    DestroyPlan(plan~) =>
      destroy_plan_body(
        catalog.destructors.plan(plan),
        catalog,
        intern_function_type(wasm_module, [I64], []),
      )
    ByteStorageSizer =>
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
fn destroy_plan_body(
  plan : WasmDestructorPlan,
  catalog : WasmFunctionCatalog,
  erased_release_type : Int,
) -> Array[@wasm_types.Instruction] {
  let instructions : Array[@wasm_types.Instruction] = []
  for action in plan.actions {
    match action {
      ReleaseReference(offset~) => {
        instructions.push(LocalGet(0))
        instructions.push(I32Load(0, 2, offset.to_int64()))
        instructions.push(catalog.runtime(ReleaseReference).call())
      }
      ReleaseCallable(offset~) => {
        instructions.push(LocalGet(0))
        instructions.push(I64Load(0, 3, offset.to_int64()))
        instructions.push(I64Const(32L))
        instructions.push(I64ShrU)
        instructions.push(I32WrapI64)
        instructions.push(catalog.runtime(ReleaseReference).call())
      }
      ReleaseErased(value_offset~, witness_offset~) => {
        instructions.push(LocalGet(0))
        instructions.push(I64Load(0, 3, value_offset.to_int64()))
        instructions.push(LocalGet(0))
        instructions.push(I32Load(0, 2, witness_offset.to_int64()))
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
