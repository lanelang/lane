///|
priv struct HelperFunctions {
  count : Int
  noop_erased_wasm : Int
  retain_ref_erased_wasm : Int
  release_ref_erased_wasm : Int
  retain_callable_wasm : Int
  release_callable_wasm : Int
  destroy_noop_wasm : Int
  destroy_host_object_wasm : Int
  destroy_shape_wasm_base : Int
  string_sizer_wasm : Int
  noop_erased_table : Int
  retain_ref_erased_table : Int
  release_ref_erased_table : Int
  retain_callable_table : Int
  release_callable_table : Int
  destroy_noop_table : Int
  destroy_host_object_table : Int
  destroy_shape_table_base : Int
  string_sizer_table : Int
}

///|
fn helper_function_indices(
  lane_function_count : Int,
  shape_count : Int,
  runtime_wasm_base : Int,
) -> HelperFunctions {
  let wasm_base = runtime_wasm_base + 9
  let table_base = lane_function_count + 1
  {
    count: 8 + shape_count,
    noop_erased_wasm: wasm_base,
    retain_ref_erased_wasm: wasm_base + 1,
    release_ref_erased_wasm: wasm_base + 2,
    retain_callable_wasm: wasm_base + 3,
    release_callable_wasm: wasm_base + 4,
    destroy_noop_wasm: wasm_base + 5,
    destroy_host_object_wasm: wasm_base + 6,
    destroy_shape_wasm_base: wasm_base + 7,
    string_sizer_wasm: wasm_base + 7 + shape_count,
    noop_erased_table: table_base,
    retain_ref_erased_table: table_base + 1,
    release_ref_erased_table: table_base + 2,
    retain_callable_table: table_base + 3,
    release_callable_table: table_base + 4,
    destroy_noop_table: table_base + 5,
    destroy_host_object_table: table_base + 6,
    destroy_shape_table_base: table_base + 7,
    string_sizer_table: table_base + 7 + shape_count,
  }
}

///|
fn HelperFunctions::wasm_indices(self : HelperFunctions) -> Array[Int] {
  let result = [
    self.noop_erased_wasm,
    self.retain_ref_erased_wasm,
    self.release_ref_erased_wasm,
    self.retain_callable_wasm,
    self.release_callable_wasm,
    self.destroy_noop_wasm,
    self.destroy_host_object_wasm,
  ]
  for index in 0..<(self.count - 8) {
    result.push(self.destroy_shape_wasm_base + index)
  }
  result.push(self.string_sizer_wasm)
  result
}

///|
fn append_helper_functions(
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
  runtime : RuntimeFunctions,
  helpers : HelperFunctions,
  host_objects_enabled : Bool,
  host_object_release_import : Int,
) -> Unit {
  append_runtime_function(wasm_module, [I64], [], [], [])
  append_runtime_function(wasm_module, [I64], [], [], [
    LocalGet(0),
    I32WrapI64,
    Call(runtime.retain_ref),
  ])
  append_runtime_function(wasm_module, [I64], [], [], [
    LocalGet(0),
    I32WrapI64,
    Call(runtime.release_ref),
  ])
  append_runtime_function(wasm_module, [I64], [], [], [
    LocalGet(0),
    I64Const(32L),
    I64ShrU,
    I32WrapI64,
    Call(runtime.retain_ref),
  ])
  append_runtime_function(wasm_module, [I64], [], [], [
    LocalGet(0),
    I64Const(32L),
    I64ShrU,
    I32WrapI64,
    Call(runtime.release_ref),
  ])
  append_runtime_function(wasm_module, [I32], [], [], [])
  append_runtime_function(
    wasm_module,
    [I32],
    [],
    [],
    if host_objects_enabled {
      [LocalGet(0), I64Load(0, 3, 8L), Call(host_object_release_import)]
    } else {
      []
    },
  )
  let erased_release_type = intern_function_type(wasm_module, [I64], [])
  for shape_index in 0..<static_image.object_shapes.length() {
    append_runtime_function(
      wasm_module,
      [I32],
      [],
      [],
      destroy_shape_body(
        static_image, runtime, erased_release_type, shape_index,
      ),
    )
  }
  append_runtime_function(wasm_module, [I32], [I32], [], [
    LocalGet(0),
    I32Load(0, 2, 8L),
    I32Const(19),
    I32Add,
    I32Const(-8),
    I32And,
  ])
  ignore(helpers)
}

///|
fn destroy_shape_body(
  static_image : StaticImage,
  runtime : RuntimeFunctions,
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
        instructions.push(Call(runtime.release_ref))
      }
      OwnedCallable => {
        instructions.push(LocalGet(0))
        instructions.push(I64Load(0, 3, offset))
        instructions.push(I64Const(32L))
        instructions.push(I64ShrU)
        instructions.push(I32WrapI64)
        instructions.push(Call(runtime.release_ref))
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
