///|
type RuntimeValue = @buslane_interpreter.BuslaneRuntimeValue

///|
fn external_runtime(
  external_map : @elaborate.BuslaneExternalMap,
) -> @buslane_interpreter.BuslaneExternalRuntime {
  let runtime = @buslane_interpreter.BuslaneExternalRuntime()
  runtime.add_handler((id, arguments) => {
    guard find_builtin_external(external_map, id) is Some(external) else {
      raise @buslane_interpreter.missing_external(id)
    }
    invoke_builtin(external, arguments)
  })
  runtime
}

///|
fn find_builtin_external(
  external_map : @elaborate.BuslaneExternalMap,
  id : @buslane.ValueId,
) -> @elaborate.BuslaneBuiltinExternal? {
  for external in external_map.builtins {
    if external.value == id {
      return Some(external)
    }
  }
  None
}

///|
fn invoke_builtin(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  match external.name {
    "%i64_add" => int_binary(external, arguments, (a, b) => a + b)
    "%i64_sub" => int_binary(external, arguments, (a, b) => a - b)
    "%i64_mul" => int_binary(external, arguments, (a, b) => a * b)
    "%i64_div" => int_binary(external, arguments, (a, b) => a / b)
    "%i64_rem" => int_binary(external, arguments, (a, b) => a % b)
    "%i64_neg" => int_unary(external, arguments, a => -a)
    "%i64_equal" => int_compare(external, arguments, (a, b) => a == b)
    "%i64_less" => int_compare(external, arguments, (a, b) => a < b)
    "%string_equal" => string_compare(external, arguments, (a, b) => a == b)
    name => builtin_failure(external, "unsupported builtin " + name)
  }
}

///|
fn int_binary(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Int64, Int64) -> Int64,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_ints(external, arguments)
  RuntimeValue::int(op(a, b))
}

///|
fn int_unary(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Int64) -> Int64,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 1 {
    return builtin_failure(external, "expected one integer argument")
  }
  guard arguments[0].as_int() is Some(value) else {
    return builtin_failure(external, "expected one integer argument")
  }
  RuntimeValue::int(op(value))
}

///|
fn int_compare(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (Int64, Int64) -> Bool,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_ints(external, arguments)
  RuntimeValue::bool(op(a, b))
}

///|
fn string_compare(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
  op : (String, String) -> Bool,
) -> RuntimeValue raise @buslane_interpreter.BuslaneRuntimeError {
  let (a, b) = expect_two_strings(external, arguments)
  RuntimeValue::bool(op(a, b))
}

///|
fn expect_two_ints(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
) -> (Int64, Int64) raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 2 {
    return builtin_failure(external, "expected two integer arguments")
  }
  guard arguments[0].as_int() is Some(a) else {
    return builtin_failure(external, "expected two integer arguments")
  }
  guard arguments[1].as_int() is Some(b) else {
    return builtin_failure(external, "expected two integer arguments")
  }
  (a, b)
}

///|
fn expect_two_strings(
  external : @elaborate.BuslaneBuiltinExternal,
  arguments : Array[RuntimeValue],
) -> (String, String) raise @buslane_interpreter.BuslaneRuntimeError {
  if arguments.length() != 2 {
    return builtin_failure(external, "expected two string arguments")
  }
  guard arguments[0].as_string() is Some(a) else {
    return builtin_failure(external, "expected two string arguments")
  }
  guard arguments[1].as_string() is Some(b) else {
    return builtin_failure(external, "expected two string arguments")
  }
  (a, b)
}

///|
fn[T] builtin_failure(
  external : @elaborate.BuslaneBuiltinExternal,
  message : String,
) -> T raise @buslane_interpreter.BuslaneRuntimeError {
  raise @buslane_interpreter.external_failure(external.value, message)
}
