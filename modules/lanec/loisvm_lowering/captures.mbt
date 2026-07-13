///|
fn free_capture_bindings(function : @anf.AnfFunction) -> Array[CaptureBinding] {
  let captures = []
  collect_free_expr(function.body, function.parameters.copy(), [], captures)
  captures
}

///|
fn collect_free_expr(
  expression : @anf.AnfExpr,
  bound_values : Array[@buslane.ValueId],
  bound_temps : Array[@anf.AnfTempId],
  captures : Array[CaptureBinding],
) -> Unit {
  match expression {
    Atom(atom) => collect_free_atom(atom, bound_values, bound_temps, captures)
    Let(binding, body) => {
      collect_free_rhs(binding.rhs(), bound_values, bound_temps, captures)
      let next_values = bound_values.copy()
      let next_temps = bound_temps.copy()
      match binding {
        Value(id~, ..) => next_values.push(id)
        Temp(temp~, ..) => next_temps.push(temp)
      }
      collect_free_expr(body, next_values, next_temps, captures)
    }
    LetRec(bindings, body) => {
      let next_values = bound_values.copy()
      for binding in bindings {
        next_values.push(binding.id)
      }
      for binding in bindings {
        collect_free_atom(binding.rhs, next_values, bound_temps, captures)
      }
      collect_free_expr(body, next_values, bound_temps, captures)
    }
    Match(match_) => {
      collect_free_atom(match_.scrutinee, bound_values, bound_temps, captures)
      for alternative in match_.alternatives {
        let next_values = bound_values.copy()
        next_values.push(match_.binder)
        next_values.append(alternative.value_binders)
        collect_free_expr(alternative.body, next_values, bound_temps, captures)
      }
    }
  }
}

///|
fn collect_free_rhs(
  rhs : @anf.AnfRhs,
  bound_values : Array[@buslane.ValueId],
  bound_temps : Array[@anf.AnfTempId],
  captures : Array[CaptureBinding],
) -> Unit {
  match rhs {
    Atom(atom) | TypeApply(callee=atom, ..) =>
      collect_free_atom(atom, bound_values, bound_temps, captures)
    Call(callee~, arguments~) => {
      collect_free_atom(callee, bound_values, bound_temps, captures)
      for argument in arguments {
        collect_free_atom(argument, bound_values, bound_temps, captures)
      }
    }
    Construct(construct) =>
      for payload in construct.payloads {
        collect_free_atom(payload, bound_values, bound_temps, captures)
      }
    Perform(perform) =>
      for payload in perform.payloads {
        collect_free_atom(payload, bound_values, bound_temps, captures)
      }
    Handle(handle) => {
      collect_free_expr(handle.body, bound_values, bound_temps, captures)
      let final_values = bound_values.copy()
      final_values.push(handle.result_binder)
      collect_free_expr(handle.final_body, final_values, bound_temps, captures)
      for table in handle.handlers {
        for operation in table.operations {
          let operation_values = bound_values.copy()
          operation_values.append(operation.payload_binders)
          operation_values.push(operation.resume_binder)
          collect_free_expr(
            operation.body,
            operation_values,
            bound_temps,
            captures,
          )
        }
      }
    }
  }
}

///|
fn collect_free_atom(
  atom : @anf.AnfAtom,
  bound_values : Array[@buslane.ValueId],
  bound_temps : Array[@anf.AnfTempId],
  captures : Array[CaptureBinding],
) -> Unit {
  match atom {
    Literal(_) => ()
    Ref(value) => {
      let capture = CaptureBinding::Value(value)
      if !bound_values.contains(value) && !captures.contains(capture) {
        captures.push(capture)
      }
    }
    Temp(temp) => {
      let capture = CaptureBinding::Temp(temp)
      if !bound_temps.contains(temp) && !captures.contains(capture) {
        captures.push(capture)
      }
    }
    Function(function) => {
      let next_values = bound_values.copy()
      next_values.append(function.parameters)
      collect_free_expr(function.body, next_values, bound_temps, captures)
    }
    TypeLambda(body~, ..) =>
      collect_free_expr(body, bound_values, bound_temps, captures)
  }
}
