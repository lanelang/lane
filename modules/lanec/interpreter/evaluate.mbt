///|
using @anf {
  type AnfAtom,
  type AnfBinding,
  type AnfExpr,
  type AnfFunctionDeclaration,
  type AnfProgram,
  type AnfRhs,
}

///|
/// Evaluates an ANF program into a runtime program.
///
/// The interpreter does not choose or hard-code an entrypoint. It evaluates
/// top-level functions into the global environment first so functions are
/// mutually recursive, then evaluates top-level values in declaration order.
pub fn evaluate_anf_program(
  program : AnfProgram,
  builtins : BuiltinRuntime,
) -> RuntimeProgram raise RuntimeError {
  let globals = RuntimeEnvironment::RuntimeEnvironment()
  for declaration in program.declarations {
    if declaration is Function(function) {
      globals.bind_value(
        function.symbol,
        Closure(function~, environment=globals),
      )
    }
  }
  for declaration in program.declarations {
    if declaration is Let(declaration) {
      let value = evaluate_expr(declaration.value, globals, builtins)
      globals.bind_value(declaration.symbol, value)
    }
  }
  RuntimeProgram(globals)
}

///|
/// Evaluates an ANF expression under the current runtime environment.
fn evaluate_expr(
  expression : AnfExpr,
  environment : RuntimeEnvironment,
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  match expression {
    Atom(atom~, ..) => evaluate_atom(atom, environment, builtins)
    Let(binding~, body~, ..) => {
      let local_environment = environment.copy()
      evaluate_binding(binding, local_environment, builtins)
      evaluate_expr(body, local_environment, builtins)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      let condition = evaluate_atom(condition, environment, builtins)
      if condition is Bool(value) {
        if value {
          evaluate_expr(then_branch, environment, builtins)
        } else {
          evaluate_expr(else_branch, environment, builtins)
        }
      } else {
        raise InvalidRuntimeValue(message="if condition is not Bool")
      }
    }
    Match(scrutinee~, arms~, ..) => {
      let scrutinee = evaluate_atom(scrutinee, environment, builtins)
      for arm in arms {
        let arm_environment = environment.copy()
        if match_pattern(arm.pattern, scrutinee, arm_environment) {
          return evaluate_expr(arm.body, arm_environment, builtins)
        }
      }
      raise InvalidRuntimeValue(message="non-exhaustive match reached runtime")
    }
  }
}

///|
/// Evaluates one ANF binding and extends the supplied local environment.
fn evaluate_binding(
  binding : AnfBinding,
  environment : RuntimeEnvironment,
  builtins : BuiltinRuntime,
) -> Unit raise RuntimeError {
  match binding {
    Value(symbol~, rhs~, ..) => {
      let value = evaluate_rhs(rhs, environment, builtins)
      environment.bind_value(symbol, value)
    }
    Temp(temp~, rhs~, ..) => {
      let value = evaluate_rhs(rhs, environment, builtins)
      environment.bind_temp(temp, value)
    }
    Pattern(pattern~, initializer~, ..) => {
      let initializer = evaluate_atom(initializer, environment, builtins)
      if !match_pattern(pattern, initializer, environment) {
        raise InvalidRuntimeValue(message="pattern binding did not match")
      }
    }
  }
}

///|
/// Evaluates the right-hand side of an ANF binding.
fn evaluate_rhs(
  rhs : AnfRhs,
  environment : RuntimeEnvironment,
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  match rhs {
    Atom(atom) => evaluate_atom(atom, environment, builtins)
    Call(callee~, arguments~, ..) =>
      evaluate_call(callee, arguments, environment, builtins)
    OperationCall(..) =>
      raise InvalidRuntimeValue(
        message="effect operation evaluation is not implemented yet",
      )
    TypeApplication(callee~, ..) => {
      let callee_value = evaluate_atom(callee, environment, builtins)
      erase_type_application(callee_value, builtins)
    }
    Field(base~, field~, name~, ..) => {
      let base = evaluate_atom(base, environment, builtins)
      evaluate_field(base, field, name)
    }
    Struct(symbol~, fields~, ..) => {
      let fields = fields.map(fn(field) raise RuntimeError {
        {
          symbol: field.symbol,
          name: field.name,
          value: evaluate_atom(field.value, environment, builtins),
        }
      })
      Struct(symbol~, fields~)
    }
    Variant(symbol~, arguments~, ..) => {
      let arguments = arguments.map(fn(argument) raise RuntimeError {
        evaluate_atom(argument, environment, builtins)
      })
      Variant(symbol~, arguments~)
    }
  }
}

///|
/// Evaluates an atomic ANF expression.
fn evaluate_atom(
  atom : AnfAtom,
  environment : RuntimeEnvironment,
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  match atom {
    Literal(literal~, ..) => evaluate_literal(literal)
    Value(symbol~, ..) => environment.lookup_value(symbol)
    Temp(temp~, ..) => environment.lookup_temp(temp)
    UnsafeBuiltin(name~, type_~, ..) => builtins.invoke(name, type_, [])
    Function(..) => FunctionAtom(function=atom, environment=environment.copy())
    TypeLambda(..) =>
      FunctionAtom(function=atom, environment=environment.copy())
  }
}

///|
/// Converts a checked literal into a runtime value.
fn evaluate_literal(literal : @checked.CheckedLiteral) -> RuntimeValue {
  match literal {
    Int(literal) => Int(literal.value)
    String(value) => String(value)
    Bool(value) => Bool(value)
    Unit => Unit
  }
}

///|
/// Evaluates a call. Unsafe builtins are invoked directly with the evaluated
/// arguments; all other calls must target a runtime function value.
fn evaluate_call(
  callee : AnfAtom,
  arguments : Array[AnfAtom],
  environment : RuntimeEnvironment,
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  if callee is UnsafeBuiltin(name~, type_~, ..) {
    let arguments = arguments.map(fn(argument) raise RuntimeError {
      evaluate_atom(argument, environment, builtins)
    })
    return builtins.invoke(name, type_, arguments)
  }
  let callee = evaluate_atom(callee, environment, builtins)
  let arguments = arguments.map(fn(argument) raise RuntimeError {
    evaluate_atom(argument, environment, builtins)
  })
  apply_function(callee, arguments, builtins)
}

///|
/// Applies a runtime function value to already evaluated arguments.
fn apply_function(
  callee : RuntimeValue,
  arguments : Array[RuntimeValue],
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  match callee {
    Closure(function~, environment~) =>
      evaluate_function_body(function, environment, arguments, builtins)
    FunctionAtom(function~, environment~) =>
      apply_function_atom(function, environment, arguments, builtins)
    _ => raise InvalidRuntimeValue(message="callee is not callable")
  }
}

///|
/// Applies a function atom captured from a local function literal.
fn apply_function_atom(
  function : AnfAtom,
  environment : RuntimeEnvironment,
  arguments : Array[RuntimeValue],
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  match function {
    Function(parameters~, body~, ..) => {
      let frame = environment.copy()
      bind_parameters(parameters, arguments, frame)
      evaluate_expr(body, frame, builtins)
    }
    TypeLambda(..) => {
      let erased = erase_type_application(
        FunctionAtom(function~, environment~),
        builtins,
      )
      apply_function(erased, arguments, builtins)
    }
    _ => raise InvalidRuntimeValue(message="callee atom is not callable")
  }
}

///|
/// Evaluates a top-level function declaration body in a fresh call frame.
fn evaluate_function_body(
  function : AnfFunctionDeclaration,
  environment : RuntimeEnvironment,
  arguments : Array[RuntimeValue],
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  let frame = environment.copy()
  bind_parameters(function.parameters, arguments, frame)
  evaluate_expr(function.body, frame, builtins)
}

///|
/// Binds call arguments to value parameters in the call frame.
fn bind_parameters(
  parameters : Array[@checked.CheckedValueParameter],
  arguments : Array[RuntimeValue],
  frame : RuntimeEnvironment,
) -> Unit raise RuntimeError {
  if parameters.length() != arguments.length() {
    raise InvalidRuntimeValue(message="argument count mismatch")
  }
  for index in 0..<parameters.length() {
    frame.bind_value(parameters[index].symbol, arguments[index])
  }
}

///|
/// Erases a type application at runtime.
fn erase_type_application(
  callee : RuntimeValue,
  builtins : BuiltinRuntime,
) -> RuntimeValue raise RuntimeError {
  match callee {
    FunctionAtom(function=TypeLambda(body~, ..), environment~) =>
      evaluate_atom(body, environment, builtins)
    Closure(..) | FunctionAtom(function=Function(..), ..) => callee
    _ => raise InvalidRuntimeValue(message="type application target is invalid")
  }
}

///|
/// Reads a field from a runtime struct value by field identity.
fn evaluate_field(
  base : RuntimeValue,
  field : @symbol.FieldSymbolId,
  name : String,
) -> RuntimeValue raise RuntimeError {
  guard base is Struct(fields~, ..) else {
    raise InvalidRuntimeValue(message="field base is not a struct")
  }
  for runtime_field in fields {
    if runtime_field.symbol == field {
      return runtime_field.value
    }
  }
  raise InvalidRuntimeValue(message="missing field \{name}")
}

///|
/// Matches a checked pattern against a runtime value and extends the supplied
/// environment with value binders when the match succeeds.
fn match_pattern(
  pattern : @checked.CheckedPattern,
  value : RuntimeValue,
  environment : RuntimeEnvironment,
) -> Bool {
  match pattern {
    Wildcard(..) => true
    Binding(symbol~, ..) => {
      environment.bind_value(symbol, value)
      true
    }
    Literal(literal~, ..) => literal_matches(literal, value)
    Variant(symbol~, arguments~, ..) =>
      match_variant_pattern(symbol, arguments, value, environment)
    Struct(symbol~, fields~, ..) =>
      match_struct_pattern(symbol, fields, value, environment)
  }
}

///|
/// Compares a checked literal pattern with a runtime value.
fn literal_matches(
  literal : @checked.CheckedLiteral,
  value : RuntimeValue,
) -> Bool {
  match literal {
    Int(literal) =>
      if value is Int(actual) {
        actual == literal.value
      } else {
        false
      }
    String(expected) =>
      if value is String(actual) {
        actual == expected
      } else {
        false
      }
    Bool(expected) =>
      if value is Bool(actual) {
        actual == expected
      } else {
        false
      }
    Unit => value is Unit
  }
}

///|
/// Matches an enum variant pattern. Type arguments are checked statically and
/// erased before runtime, so only the nominal variant identity and payloads
/// participate here.
fn match_variant_pattern(
  symbol : @symbol.VariantSymbolId,
  arguments : Array[@checked.CheckedPattern],
  value : RuntimeValue,
  environment : RuntimeEnvironment,
) -> Bool {
  guard value is Variant(symbol=value_symbol, arguments=values) else {
    return false
  }
  if symbol != value_symbol || arguments.length() != values.length() {
    return false
  }
  for index in 0..<arguments.length() {
    if !match_pattern(arguments[index], values[index], environment) {
      return false
    }
  }
  true
}

///|
/// Matches a struct pattern. Hidden type binders are already represented in
/// checked types and are erased at runtime; value fields are matched by field
/// identity.
fn match_struct_pattern(
  symbol : @symbol.TypeSymbolId,
  fields : Array[@checked.CheckedStructPatternField],
  value : RuntimeValue,
  environment : RuntimeEnvironment,
) -> Bool {
  guard value is Struct(symbol=value_symbol, fields=runtime_fields) else {
    return false
  }
  if symbol != value_symbol {
    return false
  }
  for field in fields {
    guard find_runtime_field(runtime_fields, field.symbol) is Some(value) else {
      return false
    }
    if !match_pattern(field.pattern, value, environment) {
      return false
    }
  }
  true
}

///|
/// Finds a runtime struct field by field identity.
fn find_runtime_field(
  fields : Array[RuntimeStructField],
  symbol : @symbol.FieldSymbolId,
) -> RuntimeValue? {
  for field in fields {
    if field.symbol == symbol {
      return Some(field.value)
    }
  }
  None
}
