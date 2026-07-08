///|
type RuntimeValue = @buslane_interpreter.BuslaneRuntimeValue

///|
/// Creates a Buslane external runtime for the standard Lane intrinsic set.
pub fn standard_external_runtime(
  external_map : @buslane_lowering.BuslaneExternalMap,
) -> @buslane_interpreter.BuslaneExternalRuntime {
  let runtime = @buslane_interpreter.BuslaneExternalRuntime()
  runtime.add_resolver((id, type_) => {
    guard find_builtin_external(external_map, id) is Some(external) else {
      raise @buslane_interpreter.missing_external(id)
    }
    resolve_standard_intrinsic(external, type_)
  })
  runtime
}

///|
fn find_builtin_external(
  external_map : @buslane_lowering.BuslaneExternalMap,
  id : @buslane.ValueId,
) -> @buslane_lowering.BuslaneBuiltinExternal? {
  for external in external_map.builtins {
    if external.value == id {
      return Some(external)
    }
  }
  None
}

///|
fn resolve_standard_intrinsic(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  type_ : @buslane.Type,
) -> RuntimeValue {
  match external.name {
    "%i64_add" =>
      native(type_, arguments => {
        int_binary(external, arguments, (a, b) => a + b)
      })
    "%i64_sub" =>
      native(type_, arguments => {
        int_binary(external, arguments, (a, b) => a - b)
      })
    "%i64_mul" =>
      native(type_, arguments => {
        int_binary(external, arguments, (a, b) => a * b)
      })
    "%i64_div" =>
      native(type_, arguments => {
        int_binary(external, arguments, (a, b) => a / b)
      })
    "%i64_rem" =>
      native(type_, arguments => {
        int_binary(external, arguments, (a, b) => a % b)
      })
    "%i64_neg" =>
      native(type_, arguments => int_unary(external, arguments, a => -a))
    "%i64_equal" =>
      native(type_, arguments => {
        int_compare(external, arguments, (a, b) => a == b)
      })
    "%i64_less" =>
      native(type_, arguments => {
        int_compare(external, arguments, (a, b) => a < b)
      })
    "%f64_add" =>
      native(type_, arguments => {
        double_binary(external, arguments, (a, b) => a + b)
      })
    "%f64_sub" =>
      native(type_, arguments => {
        double_binary(external, arguments, (a, b) => a - b)
      })
    "%f64_mul" =>
      native(type_, arguments => {
        double_binary(external, arguments, (a, b) => a * b)
      })
    "%f64_div" =>
      native(type_, arguments => {
        double_binary(external, arguments, (a, b) => a / b)
      })
    "%f64_neg" =>
      native(type_, arguments => double_unary(external, arguments, a => -a))
    "%f64_equal" =>
      native(type_, arguments => {
        double_compare(external, arguments, (a, b) => a == b)
      })
    "%f64_less" =>
      native(type_, arguments => {
        double_compare(external, arguments, (a, b) => a < b)
      })
    "%f64_inf" => RuntimeValue::double(1.0 / 0.0)
    "%f64_ninf" => RuntimeValue::double(-1.0 / 0.0)
    "%f64_nan" => RuntimeValue::double(0.0 / 0.0)
    "%string_equal" =>
      native(type_, arguments => {
        string_compare(external, arguments, (a, b) => a == b)
      })
    _ => RuntimeValue::external(external.value)
  }
}

///|
fn native(
  _type : @buslane.Type,
  handler : @buslane_interpreter.BuslaneNativeFunction,
) -> RuntimeValue {
  RuntimeValue::native_function(handler)
}

///|
fn int_binary(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Int64, Int64) -> Int64,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_ints(external, arguments)
  RuntimeValue::int(op(a, b))
}

///|
fn int_unary(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Int64) -> Int64,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 1 {
    return intrinsic_failure(external, "expected one integer argument")
  }
  guard arguments[0].as_int() is Some(value) else {
    return intrinsic_failure(external, "expected one integer argument")
  }
  RuntimeValue::int(op(value))
}

///|
fn int_compare(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Int64, Int64) -> Bool,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_ints(external, arguments)
  RuntimeValue::bool(op(a, b))
}

///|
fn double_binary(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Double, Double) -> Double,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_doubles(external, arguments)
  RuntimeValue::double(op(a, b))
}

///|
fn double_unary(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Double) -> Double,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 1 {
    return intrinsic_failure(external, "expected one double argument")
  }
  guard arguments[0].as_double() is Some(value) else {
    return intrinsic_failure(external, "expected one double argument")
  }
  RuntimeValue::double(op(value))
}

///|
fn double_compare(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Double, Double) -> Bool,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_doubles(external, arguments)
  RuntimeValue::bool(op(a, b))
}

///|
fn string_compare(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (String, String) -> Bool,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_strings(external, arguments)
  RuntimeValue::bool(op(a, b))
}

///|
fn expect_two_doubles(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
) -> (Double, Double) raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 2 {
    return intrinsic_failure(external, "expected two double arguments")
  }
  guard arguments[0].as_double() is Some(a) else {
    return intrinsic_failure(external, "expected two double arguments")
  }
  guard arguments[1].as_double() is Some(b) else {
    return intrinsic_failure(external, "expected two double arguments")
  }
  (a, b)
}

///|
fn expect_two_ints(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
) -> (Int64, Int64) raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 2 {
    return intrinsic_failure(external, "expected two integer arguments")
  }
  guard arguments[0].as_int() is Some(a) else {
    return intrinsic_failure(external, "expected two integer arguments")
  }
  guard arguments[1].as_int() is Some(b) else {
    return intrinsic_failure(external, "expected two integer arguments")
  }
  (a, b)
}

///|
fn expect_two_strings(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
) -> (String, String) raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 2 {
    return intrinsic_failure(external, "expected two string arguments")
  }
  guard arguments[0].as_string() is Some(a) else {
    return intrinsic_failure(external, "expected two string arguments")
  }
  guard arguments[1].as_string() is Some(b) else {
    return intrinsic_failure(external, "expected two string arguments")
  }
  (a, b)
}

///|
fn[T] intrinsic_failure(
  external : @buslane_lowering.BuslaneBuiltinExternal,
  message : String,
) -> T raise @buslane_interpreter.BuslaneRuntimeError {
  raise @buslane_interpreter.external_failure(external.value, message)
}
