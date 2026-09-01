///|
let layout_table_base_global_index = 0

///|
let heap_base_global_index = 1

///|
let heap_cursor_global_index = 2

///|
let free_list_head_global_index = 3

///|
let live_heap_bytes_global_index = 4

///|
let initialized_owned_root_count_global_index = 5

///|
fn append_runtime_globals(
  wasm_module : @wasm_types.Module,
  static_image : StaticImage,
) -> Unit {
  append_i32_global(
    wasm_module,
    index=layout_table_base_global_index,
    is_mutable=false,
    initial=static_image.layout_table_base,
  )
  append_i32_global(
    wasm_module,
    index=heap_base_global_index,
    is_mutable=false,
    initial=static_image.heap_base,
  )
  append_i32_global(
    wasm_module,
    index=heap_cursor_global_index,
    is_mutable=true,
    initial=static_image.heap_base,
  )
  append_i32_global(
    wasm_module,
    index=free_list_head_global_index,
    is_mutable=true,
    initial=0,
  )
  append_i32_global(
    wasm_module,
    index=live_heap_bytes_global_index,
    is_mutable=true,
    initial=0,
  )
  append_i32_global(
    wasm_module,
    index=initialized_owned_root_count_global_index,
    is_mutable=true,
    initial=0,
  )
  if static_image.guest_float_stack_pointer != 0 {
    append_i32_global(
      wasm_module,
      index=guest_float_stack_global_index,
      is_mutable=true,
      initial=static_image.guest_float_stack_pointer,
    )
  }
}

///|
fn append_i32_global(
  wasm_module : @wasm_types.Module,
  index~ : Int,
  is_mutable~ : Bool,
  initial~ : Int,
) -> Unit {
  if wasm_module.globals.length() != index {
    abort("WebAssembly runtime global layout is inconsistent at index \{index}")
  }
  wasm_module.globals.push({
    type_: { value_type: I32, mutable: is_mutable, },
    init: [I32Const(initial)],
  })
}
