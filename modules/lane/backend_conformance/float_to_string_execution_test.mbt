///|
fn run_float_format_wasm_interpreter(
  image : @physical.PhysicalProgram,
) -> Array[String] raise {
  let output : Array[String] = []
  let loaded = match
    load_physical(image, effect_conformance_registry(output), mode=Interpreter) {
    Ok(value) => value
    Err(error) => fail("WebAssembly interpreter load failed: \{Repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) =>
      fail("WebAssembly interpreter instantiation failed: \{Repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
  output
}

///|
test "floating-point strings are identical across all execution backends" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|
      #|let println : (String) -> Unit ! Io = extern("println")
      #|let f32_to_string : (F32) -> String = builtin("%f32_to_string")
      #|let f64_to_string : (F64) -> String = builtin("%f64_to_string")
      #|let f32_inf : F32 = builtin("%f32_inf")
      #|let f32_ninf : F32 = builtin("%f32_ninf")
      #|let f32_nan : F32 = builtin("%f32_nan")
      #|let f64_inf : F64 = builtin("%f64_inf")
      #|let f64_ninf : F64 = builtin("%f64_ninf")
      #|let f64_nan : F64 = builtin("%f64_nan")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  println(f32_to_string(0.0f32))
      #|  println(f32_to_string(-0.0f32))
      #|  println(f32_to_string(1.0f32))
      #|  println(f32_to_string(0.1f32))
      #|  println(f32_to_string(1.000000059604644775400625f32))
      #|  println(f32_to_string(3.4028235e38f32))
      #|  println(f32_to_string(f32_inf))
      #|  println(f32_to_string(f32_ninf))
      #|  println(f32_to_string(f32_nan))
      #|  println(f64_to_string(0.0f64))
      #|  println(f64_to_string(-0.0f64))
      #|  println(f64_to_string(1.0f64))
      #|  println(f64_to_string(0.1f64))
      #|  println(f64_to_string(5e-324f64))
      #|  println(f64_to_string(1.7976931348623157e308f64))
      #|  println(f64_to_string(f64_inf))
      #|  println(f64_to_string(f64_ninf))
      #|  println(f64_to_string(f64_nan))
      #|}
    ),
  )
  let expected = [
    "0.0", "-0.0", "1.0", "0.1", "1.0000001", "3.4028235e+38", "inf", "-inf", "NaN",
    "0.0", "-0.0", "1.0", "0.1", "5e-324", "1.7976931348623157e+308", "inf", "-inf",
    "NaN",
  ]
  let direct = run_effect_conformance_interpreter(image)
  let wasm_interpreter = run_float_format_wasm_interpreter(image)
  let jit = run_effect_conformance_wasm(image)
  assert_eq(direct, expected)
  assert_eq(wasm_interpreter, expected)
  assert_eq(jit, expected)
}
