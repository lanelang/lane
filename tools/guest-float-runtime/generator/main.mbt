///|
fn main raise {
  let bytes = @fs.read_file_to_bytes("lane_ryu.wasm")
  let module_ = @parser.parse_module(bytes)
  guard module_.codes.length() == 5 &&
    module_.funcs.length() == 5 &&
    module_.imports.all(import_ => import_.desc is Memory(_)) &&
    module_.globals.length() == 1 &&
    module_.datas.length() == 1 else {
    fail(
      "the pinned Ryū build no longer has the certified five-function shape",
    )
  }
  guard module_.exports.length() == 2 &&
    module_.exports.any(export_ => {
      export_.name == "lane_f32_to_string" && export_.desc is Func(1)
    }) &&
    module_.exports.any(export_ => {
      export_.name == "lane_f64_to_string" && export_.desc is Func(3)
    }) else {
    fail("the pinned Ryū build changed its formatter function identities")
  }
  guard module_.datas[0].offset is [I32Const(data_base)] &&
    module_.globals[0].init is [I32Const(stack_top)] else {
    fail("the pinned Ryū build no longer has a static data base and stack top")
  }
  println("// Generated from Ulf Adams' Ryū implementation (Apache-2.0).")
  println("// Copyright 2018 Ulf Adams.")
  println("// Source revision: 4c0618b0e44f7ef027ebae05d2cc7812048f7c8f.")
  println(
    "// Do not edit by hand; regenerate with tools/generate-guest-float-runtime.sh.",
  )
  println("")
  println("///|")
  println("fn guest_float_codes() -> Array[@wasm_types.FunctionCode] {")
  println("  " + @debug.render(Repr(module_.codes), max_depth=10000))
  println("}")
  println("")
  println("///|")
  println("fn guest_float_data_base() -> Int { \{data_base} }")
  println("")
  println("///|")
  println("fn guest_float_stack_top() -> Int { \{stack_top} }")
  println("")
  println("///|")
  println("fn guest_float_data() -> Bytes {")
  println("  Bytes::from_array([")
  for byte in module_.datas[0].init {
    println("    0x" + byte.to_int().to_string(radix=16) + ",")
  }
  println("  ])")
  println("}")
}
