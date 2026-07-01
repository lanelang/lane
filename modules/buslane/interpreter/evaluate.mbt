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
type BuslaneValueContinuation = (BuslaneRuntimeValue) -> BuslaneRuntimeValue raise BuslaneRuntimeError

///|
type BuslaneValuesContinuation = (Array[BuslaneRuntimeValue]) -> BuslaneRuntimeValue raise BuslaneRuntimeError

///|
type BuslaneHandlerStack = Array[ActiveBuslaneHandler]

///|
priv struct ActiveBuslaneHandler {
  handle : @buslane.HandleExpr
  environment : BuslaneRuntimeEnvironment
  result_continuation : BuslaneValueContinuation
}

///|
priv struct OperationDispatch {
  handler_index : Int
  handler : ActiveBuslaneHandler
  alternative : @buslane.OperationAlternative
}

///|
fn evaluate_buslane_expr(
  expr : @buslane.Expr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  evaluate_buslane_expr_cps(
    expr,
    environment,
    externals,
    [],
    buslane_delimited_identity,
  )
}

///|
fn buslane_delimited_identity(
  value : BuslaneRuntimeValue,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  // MoonBit does not coerce noraise functions to raising continuations.
  if false {
    raise InvalidValue(message="unreachable delimited continuation")
  }
  value
}

///|
fn evaluate_buslane_expr_cps(
  expr : @buslane.Expr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match expr {
    Ref(id) => continuation(environment.lookup(id))
    Literal(literal) => continuation(evaluate_buslane_literal(literal))
    Function(function) =>
      continuation(
        BuslaneRuntimeValue::runtime(
          Closure(
            parameters=function.parameters,
            body=function.body,
            environment~,
          ),
        ),
      )
    Call(callee, arguments) =>
      evaluate_buslane_call(
        callee, arguments, environment, externals, handlers, continuation,
      )
    TypeLambda(_, body) =>
      continuation(
        BuslaneRuntimeValue::runtime(TypeClosure(body~, environment~)),
      )
    TypeApply(callee, _) =>
      evaluate_buslane_expr_cps(callee, environment, externals, handlers, callee_value => {
        erase_buslane_type_application(
          callee_value, externals, handlers, continuation,
        )
      })
    Construct(construct) =>
      evaluate_buslane_exprs(
        construct.payloads,
        environment,
        externals,
        handlers,
        arguments => {
          continuation(
            BuslaneRuntimeValue::runtime(
              Data(data_constructor=construct.data_constructor, arguments~),
            ),
          )
        },
      )
    Let(id, initializer, body) =>
      evaluate_buslane_expr_cps(initializer, environment, externals, handlers, value => {
        let frame = environment.child()
        frame.bind(id, value)
        evaluate_buslane_expr_cps(
          body, frame, externals, handlers, continuation,
        )
      })
    LetRec(bindings, body) => {
      let frame = environment.child()
      bind_buslane_recursive_group(bindings, frame)
      evaluate_buslane_expr_cps(body, frame, externals, handlers, continuation)
    }
    Match(match_) =>
      evaluate_buslane_match(
        match_, environment, externals, handlers, continuation,
      )
    Perform(perform) =>
      evaluate_buslane_perform(
        perform, environment, externals, handlers, continuation,
      )
    Handle(handle) =>
      evaluate_buslane_handle(
        handle, environment, externals, handlers, continuation,
      )
    Resume(id) => continuation(environment.lookup(id))
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
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  evaluate_buslane_expr_cps(callee, environment, externals, handlers, callee_value => {
    evaluate_buslane_exprs(arguments, environment, externals, handlers, argument_values => {
      apply_buslane_function(
        callee_value, argument_values, externals, handlers, continuation,
      )
    })
  })
}

///|
fn evaluate_buslane_exprs(
  expressions : Array[@buslane.Expr],
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValuesContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  evaluate_buslane_exprs_loop(
    expressions,
    0,
    [],
    environment,
    externals,
    handlers,
    continuation,
  )
}

///|
fn evaluate_buslane_exprs_loop(
  expressions : Array[@buslane.Expr],
  index : Int,
  values : Array[BuslaneRuntimeValue],
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValuesContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  if index == expressions.length() {
    return continuation(values)
  }
  evaluate_buslane_expr_cps(
    expressions[index],
    environment,
    externals,
    handlers,
    value => {
      let next_values = values.copy()
      next_values.push(value)
      evaluate_buslane_exprs_loop(
        expressions,
        index + 1,
        next_values,
        environment,
        externals,
        handlers,
        continuation,
      )
    },
  )
}

///|
fn apply_buslane_function(
  callee : BuslaneRuntimeValue,
  arguments : Array[BuslaneRuntimeValue],
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
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
      evaluate_buslane_expr_cps(body, frame, externals, handlers, continuation)
    }
    TypeClosure(..) =>
      erase_buslane_type_application(callee, externals, handlers, erased => {
        apply_buslane_function(
          erased, arguments, externals, handlers, continuation,
        )
      })
    NativeFunction(handler) => continuation(handler(arguments))
    ResumeContinuation(resume_continuation) => {
      if arguments.length() != 1 {
        raise InvalidValue(message="resume argument count mismatch")
      }
      continuation((resume_continuation.continue_with)(arguments[0]))
    }
    _ => raise InvalidValue(message="callee is not callable")
  }
}

///|
fn erase_buslane_type_application(
  callee : BuslaneRuntimeValue,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match callee.kind {
    TypeClosure(body~, environment~) =>
      evaluate_buslane_expr_cps(
        body, environment, externals, handlers, continuation,
      )
    Closure(..) | NativeFunction(_) | ResumeContinuation(_) | External(_) =>
      continuation(callee)
    _ => raise InvalidValue(message="type application target is invalid")
  }
}

///|
fn evaluate_buslane_match(
  match_ : @buslane.MatchExpr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  evaluate_buslane_expr_cps(
    match_.scrutinee,
    environment,
    externals,
    handlers,
    scrutinee => {
      for alternative in match_.alternatives {
        let branch = environment.child()
        branch.bind(match_.binder, scrutinee)
        if bind_buslane_alternative(alternative, scrutinee, branch) {
          return evaluate_buslane_expr_cps(
            alternative.body,
            branch,
            externals,
            handlers,
            continuation,
          )
        }
      }
      raise InvalidValue(message="non-exhaustive Buslane match reached runtime")
    },
  )
}

///|
fn evaluate_buslane_handle(
  handle : @buslane.HandleExpr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  let active = ActiveBuslaneHandler::{
    handle,
    environment,
    result_continuation: continuation,
  }
  let next_handlers = handlers.copy()
  next_handlers.push(active)
  let result = evaluate_buslane_expr_cps(
    handle.body,
    environment,
    externals,
    next_handlers,
    value => {
      let frame = environment.child()
      frame.bind(handle.result_binder, value)
      evaluate_buslane_expr_cps(
        handle.final_body,
        frame,
        externals,
        handlers,
        buslane_delimited_identity,
      )
    },
  )
  continuation(result)
}

///|
fn evaluate_buslane_perform(
  perform : @buslane.PerformExpr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  continuation : BuslaneValueContinuation,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  evaluate_buslane_exprs(perform.payloads, environment, externals, handlers, payloads => {
    guard find_operation_dispatch(handlers, perform.operation) is Some(dispatch) else {
      raise UnhandledOperation(perform.operation)
    }
    let arm_environment = dispatch.handler.environment.child()
    for index in 0..<dispatch.alternative.payload_binders.length() {
      arm_environment.bind(
        dispatch.alternative.payload_binders[index],
        payloads[index],
      )
    }
    arm_environment.bind(
      dispatch.alternative.resume_binder,
      BuslaneRuntimeValue::resume_continuation(continuation),
    )
    evaluate_buslane_expr_cps(
      dispatch.alternative.body,
      arm_environment,
      externals,
      handler_stack_prefix(handlers, dispatch.handler_index),
      dispatch.handler.result_continuation,
    )
  })
}

///|
fn find_operation_dispatch(
  handlers : BuslaneHandlerStack,
  operation : @buslane.OperationId,
) -> OperationDispatch? {
  for offset in 0..<handlers.length() {
    let index = handlers.length() - offset - 1
    let handler = handlers[index]
    for table in handler.handle.handlers {
      for alternative in table.operations {
        if alternative.operation == operation {
          return Some({ handler_index: index, handler, alternative })
        }
      }
    }
  }
  None
}

///|
fn handler_stack_prefix(
  handlers : BuslaneHandlerStack,
  length : Int,
) -> BuslaneHandlerStack {
  let prefix = []
  for index in 0..<length {
    prefix.push(handlers[index])
  }
  prefix
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
