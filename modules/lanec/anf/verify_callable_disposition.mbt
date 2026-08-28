///|
fn verify_callable_dispositions(
  program : AnfProgram,
) -> Unit raise RuntimeAnfLoweringError {
  for index, term in program.terms {
    let path = [RuntimeAnfVerificationFrame::TopTerm(index)]
    match term {
      Let(value, expression) =>
        verify_callable_expr(expression, path + [ValueBinding(value)])
      LetRec(bindings) =>
        for index, binding in bindings {
          verify_top_callable_atom(
            binding.rhs,
            path + [RecursiveBinding(index)],
          )
        }
      External(_) => ()
    }
  }
}

///|
fn verify_top_callable_atom(
  atom : AnfAtom,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  match atom {
    Function(function) =>
      verify_callable_expr(function.body, path + [AnfFunction(function.id)])
    EvidenceLambda(body~, ..) => verify_callable_expr(body, path)
    DirectFunction(_) | JoinPoint(_) =>
      invalid_callable_disposition(
        "a top-level callable has a lexical disposition", path,
      )
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn verify_callable_expr(
  expression : AnfExpr,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  match expression {
    Atom(atom) => verify_value_atom(atom, path)
    Let(Value(id~, rhs=Atom(atom)), body) =>
      if anf_atom_function(atom) is Some(function) {
        let binding_path = path + [ValueBinding(id)]
        let collector = CallableUseCollector::new(
          id,
          function.parameters.length(),
        )
        collector.collect_expr(body, true)
        require_callable_disposition(
          atom,
          collector.disposition(),
          binding_path,
        )
        verify_callable_expr(
          function.body,
          binding_path + [AnfFunction(function.id)],
        )
        verify_callable_expr(body, binding_path)
      } else {
        verify_callable_rhs(Atom(atom), path)
        verify_callable_expr(body, path)
      }
    Let(binding, body) => {
      let binding_path = match binding {
        Value(id~, ..) => path + [ValueBinding(id)]
        Temp(temp~, ..) => path + [TempBinding(temp)]
      }
      verify_callable_rhs(binding.rhs(), binding_path)
      verify_callable_expr(body, binding_path)
    }
    LetRec(bindings, body) => {
      let functions = bindings.map(binding => anf_atom_function(binding.rhs))
      let expected = lexical_group_disposition(bindings, body, functions)
      for index, binding in bindings {
        let binding_path = path + [RecursiveBinding(index)]
        match expected {
          Closure =>
            if binding.rhs is DirectFunction(_) || binding.rhs is JoinPoint(_) {
              invalid_callable_disposition(
                "an escaping recursive group has a restricted callable", binding_path,
              )
            }
          Direct | Join =>
            require_callable_disposition(binding.rhs, expected, binding_path)
        }
        match functions[index] {
          Some(function) =>
            verify_callable_expr(
              function.body,
              binding_path + [AnfFunction(function.id)],
            )
          None => verify_value_atom(binding.rhs, binding_path)
        }
      }
      verify_callable_expr(body, path)
    }
  }
}

///|
fn require_callable_disposition(
  atom : AnfAtom,
  expected : LexicalCallableDisposition,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  let matches = match (atom, expected) {
    (Function(_), Closure)
    | (DirectFunction(_), Direct)
    | (JoinPoint(_), Join) => true
    _ => false
  }
  if !matches {
    invalid_callable_disposition(
      "a lexical callable's stored disposition disagrees with its uses", path,
    )
  }
}

///|
fn verify_callable_rhs(
  rhs : AnfRhs,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  match rhs {
    Atom(atom) => verify_value_atom(atom, path)
    Call(callee~, arguments~) => {
      match callee {
        DirectFunction(function) =>
          if function.parameters.length() != arguments.length() {
            invalid_callable_disposition(
              "an immediate direct callable is not saturated", path,
            )
          }
        JoinPoint(_) =>
          invalid_callable_disposition(
            "an unbound join point appears as a call target", path,
          )
        _ => verify_value_atom(callee, path)
      }
      for argument in arguments {
        verify_value_atom(argument, path)
      }
    }
    ApplyEvidence(callee~, ..) => verify_value_atom(callee, path)
    Construct(construct) =>
      for payload in construct.payloads {
        verify_value_atom(payload, path)
      }
    Match(match_) => {
      verify_value_atom(match_.scrutinee, path)
      for index, alternative in match_.alternatives {
        verify_callable_expr(alternative.body, path + [Alternative(index)])
      }
    }
  }
}

///|
fn verify_value_atom(
  atom : AnfAtom,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  match atom {
    Function(function) =>
      verify_callable_expr(function.body, path + [AnfFunction(function.id)])
    EvidenceLambda(body~, ..) => verify_callable_expr(body, path)
    DirectFunction(_) | JoinPoint(_) =>
      invalid_callable_disposition(
        "a restricted callable appears in first-class position", path,
      )
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn invalid_callable_disposition(
  detail : String,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  raise InvalidRuntimeAnf({ kind: CallableDispositionMismatch(detail~), path, })
}
