///|
fn verify_callable_dispositions(
  program : AnfProgram,
) -> Unit raise RuntimeAnfLoweringError {
  for term in program.terms {
    match term {
      Let(_, expression) => verify_callable_expr(expression)
      LetRec(bindings) =>
        for binding in bindings {
          verify_top_callable_atom(binding.rhs)
        }
      External(_) => ()
    }
  }
}

///|
fn verify_top_callable_atom(
  atom : AnfAtom,
) -> Unit raise RuntimeAnfLoweringError {
  match atom {
    Function(function) => verify_callable_expr(function.body)
    EvidenceLambda(body~, ..) => verify_callable_expr(body)
    DirectFunction(_) | JoinPoint(_) =>
      raise InvalidCallableDisposition(
        detail="a top-level callable has a lexical disposition",
      )
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn verify_callable_expr(
  expression : AnfExpr,
) -> Unit raise RuntimeAnfLoweringError {
  match expression {
    Atom(atom) => verify_value_atom(atom)
    Let(Value(id~, rhs=Atom(atom)), body) =>
      if anf_atom_function(atom) is Some(function) {
        let collector = CallableUseCollector::new(
          id,
          function.parameters.length(),
        )
        collector.collect_expr(body, true)
        require_callable_disposition(atom, collector.disposition())
        verify_callable_expr(function.body)
        verify_callable_expr(body)
      } else {
        verify_callable_rhs(Atom(atom))
        verify_callable_expr(body)
      }
    Let(binding, body) => {
      verify_callable_rhs(binding.rhs())
      verify_callable_expr(body)
    }
    LetRec(bindings, body) => {
      let functions = bindings.map(binding => anf_atom_function(binding.rhs))
      let expected = lexical_group_disposition(bindings, body, functions)
      for index, binding in bindings {
        match expected {
          Closure =>
            if binding.rhs is DirectFunction(_) || binding.rhs is JoinPoint(_) {
              raise InvalidCallableDisposition(
                detail="an escaping recursive group has a restricted callable",
              )
            }
          Direct | Join => require_callable_disposition(binding.rhs, expected)
        }
        match functions[index] {
          Some(function) => verify_callable_expr(function.body)
          None => verify_value_atom(binding.rhs)
        }
      }
      verify_callable_expr(body)
    }
  }
}

///|
fn require_callable_disposition(
  atom : AnfAtom,
  expected : LexicalCallableDisposition,
) -> Unit raise RuntimeAnfLoweringError {
  let matches = match (atom, expected) {
    (Function(_), Closure)
    | (DirectFunction(_), Direct)
    | (JoinPoint(_), Join) => true
    _ => false
  }
  if !matches {
    raise InvalidCallableDisposition(
      detail="a lexical callable's stored disposition disagrees with its uses",
    )
  }
}

///|
fn verify_callable_rhs(rhs : AnfRhs) -> Unit raise RuntimeAnfLoweringError {
  match rhs {
    Atom(atom) => verify_value_atom(atom)
    Call(callee~, arguments~) => {
      match callee {
        DirectFunction(function) =>
          if function.parameters.length() != arguments.length() {
            raise InvalidCallableDisposition(
              detail="an immediate direct callable is not saturated",
            )
          }
        JoinPoint(_) =>
          raise InvalidCallableDisposition(
            detail="an unbound join point appears as a call target",
          )
        _ => verify_value_atom(callee)
      }
      for argument in arguments {
        verify_value_atom(argument)
      }
    }
    ApplyEvidence(callee~, ..) => verify_value_atom(callee)
    Construct(construct) =>
      for payload in construct.payloads {
        verify_value_atom(payload)
      }
    Match(match_) => {
      verify_value_atom(match_.scrutinee)
      for alternative in match_.alternatives {
        verify_callable_expr(alternative.body)
      }
    }
  }
}

///|
fn verify_value_atom(atom : AnfAtom) -> Unit raise RuntimeAnfLoweringError {
  match atom {
    Function(function) => verify_callable_expr(function.body)
    EvidenceLambda(body~, ..) => verify_callable_expr(body)
    DirectFunction(_) | JoinPoint(_) =>
      raise InvalidCallableDisposition(
        detail="a restricted callable appears in first-class position",
      )
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}
