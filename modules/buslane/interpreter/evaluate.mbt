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
  externals.validate_effect_handlers(program.metadata)
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
type BuslaneHandlerStack = Array[ActiveBuslaneHandler]

///|
priv struct ActiveBuslaneHandler {
  id : Int
  handle : @buslane.HandleExpr
  environment : BuslaneRuntimeEnvironment
}

///|
priv enum Kont {
  DoneKont
  LetKont(
    id~ : @buslane.ValueId,
    body~ : @buslane.Expr,
    environment~ : BuslaneRuntimeEnvironment,
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  CallCalleeKont(
    arguments~ : Array[@buslane.Expr],
    environment~ : BuslaneRuntimeEnvironment,
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  CallArgumentKont(
    callee~ : BuslaneRuntimeValue,
    arguments~ : Array[@buslane.Expr],
    index~ : Int,
    values~ : Array[BuslaneRuntimeValue],
    environment~ : BuslaneRuntimeEnvironment,
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  TypeApplyKont(handlers~ : BuslaneHandlerStack, next~ : Kont)
  ApplyErasedFunctionKont(
    arguments~ : Array[BuslaneRuntimeValue],
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  ConstructKont(
    construct~ : @buslane.ConstructExpr,
    index~ : Int,
    values~ : Array[BuslaneRuntimeValue],
    environment~ : BuslaneRuntimeEnvironment,
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  PerformPayloadKont(
    perform~ : @buslane.PerformExpr,
    index~ : Int,
    values~ : Array[BuslaneRuntimeValue],
    environment~ : BuslaneRuntimeEnvironment,
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  MatchKont(
    match_~ : @buslane.MatchExpr,
    environment~ : BuslaneRuntimeEnvironment,
    handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
  HandleBodyKont(
    id~ : Int,
    handle~ : @buslane.HandleExpr,
    environment~ : BuslaneRuntimeEnvironment,
    outer_handlers~ : BuslaneHandlerStack,
    next~ : Kont
  )
}

///|
priv struct KontSplit {
  captured : Kont
  outer : Kont
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
  evaluate_buslane_expr_kont(expr, environment, externals, [], DoneKont)
}

///|
fn evaluate_buslane_expr_kont(
  expr : @buslane.Expr,
  environment : BuslaneRuntimeEnvironment,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  kont : Kont,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match expr {
    Ref(id) => apply_buslane_kont(environment.lookup(id), externals, kont)
    Literal(literal) =>
      apply_buslane_kont(evaluate_buslane_literal(literal), externals, kont)
    Function(function) =>
      apply_buslane_kont(
        BuslaneRuntimeValue::runtime(
          Closure(
            parameters=function.parameters,
            body=function.body,
            environment~,
          ),
        ),
        externals,
        kont,
      )
    Call(callee, arguments) =>
      evaluate_buslane_expr_kont(
        callee,
        environment,
        externals,
        handlers,
        CallCalleeKont(arguments~, environment~, handlers~, next=kont),
      )
    TypeLambda(_, body) =>
      apply_buslane_kont(
        BuslaneRuntimeValue::runtime(TypeClosure(body~, environment~)),
        externals,
        kont,
      )
    TypeApply(callee, _) =>
      evaluate_buslane_expr_kont(
        callee,
        environment,
        externals,
        handlers,
        TypeApplyKont(handlers~, next=kont),
      )
    Construct(construct) =>
      if construct.payloads.is_empty() {
        apply_buslane_kont(
          BuslaneRuntimeValue::runtime(
            Data(data_constructor=construct.data_constructor, arguments=[]),
          ),
          externals,
          kont,
        )
      } else {
        evaluate_buslane_expr_kont(
          construct.payloads[0],
          environment,
          externals,
          handlers,
          ConstructKont(
            construct~,
            index=0,
            values=[],
            environment~,
            handlers~,
            next=kont,
          ),
        )
      }
    Let(id, initializer, body) =>
      evaluate_buslane_expr_kont(
        initializer,
        environment,
        externals,
        handlers,
        LetKont(id~, body~, environment~, handlers~, next=kont),
      )
    LetRec(bindings, body) => {
      let frame = environment.child()
      bind_buslane_recursive_group(bindings, frame)
      evaluate_buslane_expr_kont(body, frame, externals, handlers, kont)
    }
    Match(match_) =>
      evaluate_buslane_expr_kont(
        match_.scrutinee,
        environment,
        externals,
        handlers,
        MatchKont(match_~, environment~, handlers~, next=kont),
      )
    Perform(perform) =>
      if perform.payloads.is_empty() {
        dispatch_buslane_perform(perform, [], externals, handlers, kont)
      } else {
        evaluate_buslane_expr_kont(
          perform.payloads[0],
          environment,
          externals,
          handlers,
          PerformPayloadKont(
            perform~,
            index=0,
            values=[],
            environment~,
            handlers~,
            next=kont,
          ),
        )
      }
    Handle(handle) => {
      let id = handlers.length()
      let active = ActiveBuslaneHandler::{ id, handle, environment }
      let next_handlers = handlers.copy()
      next_handlers.push(active)
      evaluate_buslane_expr_kont(
        handle.body,
        environment,
        externals,
        next_handlers,
        HandleBodyKont(
          id~,
          handle~,
          environment~,
          outer_handlers=handlers,
          next=kont,
        ),
      )
    }
    Resume(id) => apply_buslane_kont(environment.lookup(id), externals, kont)
  }
}

///|
fn apply_buslane_kont(
  value : BuslaneRuntimeValue,
  externals : BuslaneExternalRuntime,
  kont : Kont,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match kont {
    DoneKont => value
    LetKont(id~, body~, environment~, handlers~, next~) => {
      let frame = environment.child()
      frame.bind(id, value)
      evaluate_buslane_expr_kont(body, frame, externals, handlers, next)
    }
    CallCalleeKont(arguments~, environment~, handlers~, next~) =>
      if arguments.is_empty() {
        apply_buslane_function(value, [], externals, handlers, next)
      } else {
        evaluate_buslane_expr_kont(
          arguments[0],
          environment,
          externals,
          handlers,
          CallArgumentKont(
            callee=value,
            arguments~,
            index=0,
            values=[],
            environment~,
            handlers~,
            next~,
          ),
        )
      }
    CallArgumentKont(
      callee~,
      arguments~,
      index~,
      values~,
      environment~,
      handlers~,
      next~
    ) => {
      let next_values = values.copy()
      next_values.push(value)
      let next_index = index + 1
      if next_index == arguments.length() {
        apply_buslane_function(callee, next_values, externals, handlers, next)
      } else {
        evaluate_buslane_expr_kont(
          arguments[next_index],
          environment,
          externals,
          handlers,
          CallArgumentKont(
            callee~,
            arguments~,
            index=next_index,
            values=next_values,
            environment~,
            handlers~,
            next~,
          ),
        )
      }
    }
    TypeApplyKont(handlers~, next~) =>
      erase_buslane_type_application(value, externals, handlers, next)
    ApplyErasedFunctionKont(arguments~, handlers~, next~) =>
      apply_buslane_function(value, arguments, externals, handlers, next)
    ConstructKont(construct~, index~, values~, environment~, handlers~, next~) => {
      let next_values = values.copy()
      next_values.push(value)
      let next_index = index + 1
      if next_index == construct.payloads.length() {
        apply_buslane_kont(
          BuslaneRuntimeValue::runtime(
            Data(
              data_constructor=construct.data_constructor,
              arguments=next_values,
            ),
          ),
          externals,
          next,
        )
      } else {
        evaluate_buslane_expr_kont(
          construct.payloads[next_index],
          environment,
          externals,
          handlers,
          ConstructKont(
            construct~,
            index=next_index,
            values=next_values,
            environment~,
            handlers~,
            next~,
          ),
        )
      }
    }
    PerformPayloadKont(
      perform~,
      index~,
      values~,
      environment~,
      handlers~,
      next~
    ) => {
      let next_values = values.copy()
      next_values.push(value)
      let next_index = index + 1
      if next_index == perform.payloads.length() {
        dispatch_buslane_perform(
          perform, next_values, externals, handlers, next,
        )
      } else {
        evaluate_buslane_expr_kont(
          perform.payloads[next_index],
          environment,
          externals,
          handlers,
          PerformPayloadKont(
            perform~,
            index=next_index,
            values=next_values,
            environment~,
            handlers~,
            next~,
          ),
        )
      }
    }
    MatchKont(match_~, environment~, handlers~, next~) => {
      for alternative in match_.alternatives {
        let branch = environment.child()
        branch.bind(match_.binder, value)
        if bind_buslane_alternative(alternative, value, branch) {
          return evaluate_buslane_expr_kont(
            alternative.body,
            branch,
            externals,
            handlers,
            next,
          )
        }
      }
      raise InvalidValue(message="non-exhaustive Buslane match reached runtime")
    }
    HandleBodyKont(handle~, environment~, outer_handlers~, next~, ..) => {
      let frame = environment.child()
      frame.bind(handle.result_binder, value)
      evaluate_buslane_expr_kont(
        handle.final_body,
        frame,
        externals,
        outer_handlers,
        next,
      )
    }
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
fn apply_buslane_function(
  callee : BuslaneRuntimeValue,
  arguments : Array[BuslaneRuntimeValue],
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  kont : Kont,
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
      evaluate_buslane_expr_kont(body, frame, externals, handlers, kont)
    }
    TypeClosure(..) =>
      erase_buslane_type_application(
        callee,
        externals,
        handlers,
        ApplyErasedFunctionKont(arguments~, handlers~, next=kont),
      )
    NativeFunction(handler) =>
      apply_buslane_kont(handler(arguments), externals, kont)
    ResumeContinuation(resume_continuation) => {
      if arguments.length() != 1 {
        raise InvalidValue(message="resume argument count mismatch")
      }
      apply_buslane_kont(
        arguments[0],
        externals,
        append_kont(resume_continuation.kont, kont),
      )
    }
    _ => raise InvalidValue(message="callee is not callable")
  }
}

///|
/// Calls a runtime function value at the host boundary.
pub fn BuslaneRuntimeValue::call(
  callee : BuslaneRuntimeValue,
  arguments : Array[BuslaneRuntimeValue],
  externals : BuslaneExternalRuntime,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  apply_buslane_function(callee, arguments, externals, [], DoneKont)
}

///|
fn append_kont(kont : Kont, tail : Kont) -> Kont {
  match kont {
    DoneKont => tail
    LetKont(id~, body~, environment~, handlers~, next~) =>
      LetKont(id~, body~, environment~, handlers~, next=append_kont(next, tail))
    CallCalleeKont(arguments~, environment~, handlers~, next~) =>
      CallCalleeKont(
        arguments~,
        environment~,
        handlers~,
        next=append_kont(next, tail),
      )
    CallArgumentKont(
      callee~,
      arguments~,
      index~,
      values~,
      environment~,
      handlers~,
      next~
    ) =>
      CallArgumentKont(
        callee~,
        arguments~,
        index~,
        values~,
        environment~,
        handlers~,
        next=append_kont(next, tail),
      )
    TypeApplyKont(handlers~, next~) =>
      TypeApplyKont(handlers~, next=append_kont(next, tail))
    ApplyErasedFunctionKont(arguments~, handlers~, next~) =>
      ApplyErasedFunctionKont(
        arguments~,
        handlers~,
        next=append_kont(next, tail),
      )
    ConstructKont(construct~, index~, values~, environment~, handlers~, next~) =>
      ConstructKont(
        construct~,
        index~,
        values~,
        environment~,
        handlers~,
        next=append_kont(next, tail),
      )
    PerformPayloadKont(
      perform~,
      index~,
      values~,
      environment~,
      handlers~,
      next~
    ) =>
      PerformPayloadKont(
        perform~,
        index~,
        values~,
        environment~,
        handlers~,
        next=append_kont(next, tail),
      )
    MatchKont(match_~, environment~, handlers~, next~) =>
      MatchKont(match_~, environment~, handlers~, next=append_kont(next, tail))
    HandleBodyKont(id~, handle~, environment~, outer_handlers~, next~) =>
      HandleBodyKont(
        id~,
        handle~,
        environment~,
        outer_handlers~,
        next=append_kont(next, tail),
      )
  }
}

///|
fn erase_buslane_type_application(
  callee : BuslaneRuntimeValue,
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  kont : Kont,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  match callee.kind {
    TypeClosure(body~, environment~) =>
      evaluate_buslane_expr_kont(body, environment, externals, handlers, kont)
    Closure(..) | NativeFunction(_) | ResumeContinuation(_) | External(_) =>
      apply_buslane_kont(callee, externals, kont)
    _ => raise InvalidValue(message="type application target is invalid")
  }
}

///|
fn dispatch_buslane_perform(
  perform : @buslane.PerformExpr,
  payloads : Array[BuslaneRuntimeValue],
  externals : BuslaneExternalRuntime,
  handlers : BuslaneHandlerStack,
  kont : Kont,
) -> BuslaneRuntimeValue raise BuslaneRuntimeError {
  guard find_operation_dispatch(handlers, perform.operation) is Some(dispatch) else {
    if externals.effect_handler(perform.operation) is Some(handler) {
      return apply_buslane_kont(handler(payloads), externals, kont)
    }
    raise UnhandledOperation(perform.operation)
  }
  guard split_kont_at_handler(kont, dispatch.handler.id) is Some(split) else {
    raise InvalidValue(message="handler delimiter is not in continuation")
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
    BuslaneRuntimeValue::resume_continuation(split.captured),
  )
  evaluate_buslane_expr_kont(
    dispatch.alternative.body,
    arm_environment,
    externals,
    handler_stack_prefix(handlers, dispatch.handler_index),
    split.outer,
  )
}

///|
fn split_kont_at_handler(kont : Kont, handler_id : Int) -> KontSplit? {
  match kont {
    DoneKont => None
    LetKont(id~, body~, environment~, handlers~, next~) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: LetKont(
            id~,
            body~,
            environment~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    CallCalleeKont(arguments~, environment~, handlers~, next~) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: CallCalleeKont(
            arguments~,
            environment~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    CallArgumentKont(
      callee~,
      arguments~,
      index~,
      values~,
      environment~,
      handlers~,
      next~
    ) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: CallArgumentKont(
            callee~,
            arguments~,
            index~,
            values~,
            environment~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    TypeApplyKont(handlers~, next~) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: TypeApplyKont(handlers~, next=split.captured),
          outer: split.outer,
        })
      } else {
        None
      }
    ApplyErasedFunctionKont(arguments~, handlers~, next~) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: ApplyErasedFunctionKont(
            arguments~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    ConstructKont(construct~, index~, values~, environment~, handlers~, next~) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: ConstructKont(
            construct~,
            index~,
            values~,
            environment~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    PerformPayloadKont(
      perform~,
      index~,
      values~,
      environment~,
      handlers~,
      next~
    ) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: PerformPayloadKont(
            perform~,
            index~,
            values~,
            environment~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    MatchKont(match_~, environment~, handlers~, next~) =>
      if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: MatchKont(
            match_~,
            environment~,
            handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
    HandleBodyKont(id~, handle~, environment~, outer_handlers~, next~) =>
      if id == handler_id {
        Some({
          captured: HandleBodyKont(
            id~,
            handle~,
            environment~,
            outer_handlers~,
            next=DoneKont,
          ),
          outer: next,
        })
      } else if split_kont_at_handler(next, handler_id) is Some(split) {
        Some({
          captured: HandleBodyKont(
            id~,
            handle~,
            environment~,
            outer_handlers~,
            next=split.captured,
          ),
          outer: split.outer,
        })
      } else {
        None
      }
  }
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
