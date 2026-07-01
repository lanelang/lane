///|
/// Evaluates a Buslane program into a runtime program.
///
/// The evaluator first runs the Buslane verifier. External values are installed
/// as runtime external references, recursive groups install closures before
/// evaluating later terms, and top-level `let` terms are evaluated in order.
pub fn evaluate_buslane_program(
  program : @buslane.Program,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeProgram raise BuslaneRuntimeError {
  let verify_result = @buslane.verify_program(program)
  if !verify_result.is_ok() {
    raise InvalidProgram(verify_result.diagnostics)
  }
  let globals = BuslaneRuntimeEnvironment::BuslaneRuntimeEnvironment()
  for term in program.terms {
    match term {
      External(id) =>
        globals.bind(
          id,
          external_runtime_value(program.metadata, id, externals),
        )
      LetRec(bindings) => bind_buslane_recursive_group(bindings, globals)
      Let(id, initializer) => {
        let value = evaluate_buslane_expr(initializer, globals, externals)
        globals.bind(id, value)
      }
    }
  }
  BuslaneRuntimeProgram(globals)
}

///|
fn external_runtime_value(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  guard metadata.value_info(id) is Some(info) else { raise MissingExternal(id) }
  externals.resolve(id, info.type_)
}

///|
fn bind_buslane_recursive_group(
  bindings : Array[@buslane.RecursiveBinding],
  environment : BuslaneRuntimeEnvironment,
) -> Unit raise BuslaneRuntimeError {
  for binding in bindings {
    environment.bind(
      binding.id,
      recursive_runtime_value(binding.rhs, environment),
    )
  }
}

///|
fn recursive_runtime_value(
  rhs : @buslane.Expr,
  environment : BuslaneRuntimeEnvironment,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match rhs {
    Function(function) =>
      BuslaneRuntimeValue::runtime(
        Closure(
          parameters=function.parameters,
          body=function.body,
          environment~,
        ),
      )
    TypeLambda(_, body) =>
      BuslaneRuntimeValue::runtime(TypeClosure(body~, environment~))
    _ => raise InvalidValue(message="letrec rhs is not a function")
  }
}

///|
fn evaluate_buslane_expr(
  expr : @buslane.Expr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match expr {
    Ref(id) => environment.lookup(id)
    Literal(literal) => evaluate_buslane_literal(literal)
    Function(function) =>
      BuslaneRuntimeValue::runtime(
        Closure(
          parameters=function.parameters,
          body=function.body,
          environment~,
        ),
      )
    Call(callee, arguments) =>
      evaluate_buslane_call(callee, arguments, environment, externals)
    TypeLambda(_, body) =>
      BuslaneRuntimeValue::runtime(TypeClosure(body~, environment~))
    TypeApply(callee, _) =>
      erase_buslane_type_application(
        evaluate_buslane_expr(callee, environment, externals),
        externals,
      )
    Construct(construct) =>
      BuslaneRuntimeValue::runtime(
        Data(
          data_constructor=construct.data_constructor,
          arguments=construct.payloads.map(fn(
            payload,
          ) raise BuslaneRuntimeError {
            evaluate_buslane_expr(payload, environment, externals)
          }),
        ),
      )
    Let(id, initializer, body) => {
      let frame = environment.child()
      let value = evaluate_buslane_expr(initializer, environment, externals)
      frame.bind(id, value)
      evaluate_buslane_expr(body, frame, externals)
    }
    LetRec(bindings, body) => {
      let frame = environment.child()
      bind_buslane_recursive_group(bindings, frame)
      evaluate_buslane_expr(body, frame, externals)
    }
    Match(match_) => evaluate_buslane_match(match_, environment, externals)
    Perform(_) =>
      raise InvalidValue(message="perform evaluation is not implemented yet")
    Handle(_) =>
      raise InvalidValue(message="handler evaluation is not implemented yet")
    Resume(id) => environment.lookup(id)
  }
}

///|
fn evaluate_buslane_literal(literal : @buslane.Literal) -> BuslaneRuntimeValue {
  match literal {
    Int(value) => BuslaneRuntimeValue::int(value)
    Bool(value) => BuslaneRuntimeValue::bool(value)
    String(value) => BuslaneRuntimeValue::string(value)
    Unit => BuslaneRuntimeValue::unit()
  }
}

///|
fn evaluate_buslane_call(
  callee : @buslane.Expr,
  arguments : Array[@buslane.Expr],
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  let callee_value = evaluate_buslane_expr(callee, environment, externals)
  let argument_values = arguments.map(fn(argument) raise BuslaneRuntimeError {
    evaluate_buslane_expr(argument, environment, externals)
  })
  apply_buslane_function(callee_value, argument_values, externals)
}

///|
fn apply_buslane_function(
  callee : BuslaneRuntimeValue,
  arguments : Array[BuslaneRuntimeValue],
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match callee.kind {
    Closure(parameters~, body~, environment~) => {
      if parameters.length() != arguments.length() {
        raise InvalidValue(message="argument count mismatch")
      }
      let frame = environment.child()
      for index in 0..<parameters.length() {
        frame.bind(parameters[index], arguments[index])
      }
      evaluate_buslane_expr(body, frame, externals)
    }
    TypeClosure(..) => {
      let erased = erase_buslane_type_application(callee, externals)
      apply_buslane_function(erased, arguments, externals)
    }
    NativeFunction(handler) => handler(arguments)
    _ => raise InvalidValue(message="callee is not callable")
  }
}

///|
fn erase_buslane_type_application(
  callee : BuslaneRuntimeValue,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match callee.kind {
    TypeClosure(body~, environment~) =>
      evaluate_buslane_expr(body, environment, externals)
    Closure(..) | NativeFunction(_) | External(_) => callee
    _ => raise InvalidValue(message="type application target is invalid")
  }
}

///|
fn evaluate_buslane_match(
  match_ : @buslane.MatchExpr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  let scrutinee = evaluate_buslane_expr(
    match_.scrutinee,
    environment,
    externals,
  )
  for alternative in match_.alternatives {
    let branch = environment.child()
    branch.bind(match_.binder, scrutinee)
    if bind_buslane_alternative(alternative, scrutinee, branch) {
      return evaluate_buslane_expr(alternative.body, branch, externals)
    }
  }
  raise InvalidValue(message="non-exhaustive Buslane match reached runtime")
}

///|
fn bind_buslane_alternative(
  alternative : @buslane.Alternative,
  scrutinee : BuslaneRuntimeValue,
  environment : BuslaneRuntimeEnvironment,
) -> Bool {
  match alternative.alt_constructor {
    Default => true
    Literal(literal) => buslane_literal_matches(literal, scrutinee)
    DataCon(data_constructor) =>
      bind_buslane_data_alternative(
        data_constructor,
        alternative.value_binders,
        scrutinee,
        environment,
      )
  }
}

///|
fn bind_buslane_data_alternative(
  data_constructor : @buslane.DataConId,
  value_binders : Array[@buslane.ValueId],
  scrutinee : BuslaneRuntimeValue,
  environment : BuslaneRuntimeEnvironment,
) -> Bool {
  guard scrutinee.kind is Data(data_constructor=actual, arguments~) else {
    return false
  }
  if actual != data_constructor || arguments.length() != value_binders.length() {
    return false
  }
  for index in 0..<value_binders.length() {
    environment.bind(value_binders[index], arguments[index])
  }
  true
}

///|
fn buslane_literal_matches(
  literal : @buslane.Literal,
  value : BuslaneRuntimeValue,
) -> Bool {
  match literal {
    Unit => value.kind is Unit
    Bool(expected) =>
      if value.kind is Bool(actual) {
        actual == expected
      } else {
        false
      }
    Int(expected) =>
      if value.kind is Int(actual) {
        actual == expected
      } else {
        false
      }
    String(expected) =>
      if value.kind is String(actual) {
        actual == expected
      } else {
        false
      }
  }
}
