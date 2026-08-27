///|
priv struct CallableUseCollector {
  target : @buslane.ValueId
  arity : Int
  mut direct_calls : Int
  mut first_class : Bool
  mut all_saturated : Bool
  mut all_tail : Bool
}

///|
priv enum LexicalCallableDisposition {
  Closure
  Direct
  Join
}

///|
fn classify_anf_callables(program : AnfProgram) -> AnfProgram {
  {
    metadata: program.metadata,
    terms: program.terms.map(classify_top_term_callables),
  }
}

///|
fn classify_top_term_callables(term : AnfTopTerm) -> AnfTopTerm {
  match term {
    Let(value, expression) => Let(value, classify_top_expression(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          ..binding,
          rhs: classify_top_atom(binding.rhs),
        }),
      )
    External(_) => term
  }
}

///|
fn classify_top_expression(expression : AnfExpr) -> AnfExpr {
  match expression {
    Atom(atom) => Atom(classify_top_atom(atom))
    _ => classify_lexical_expr(expression)
  }
}

///|
fn classify_top_atom(atom : AnfAtom) -> AnfAtom {
  match atom {
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      Function(classify_function_body(function))
    EvidenceLambda(parameters~, body~) =>
      EvidenceLambda(parameters~, body=classify_top_expression(body))
    Literal(_) | Ref(_) | Temp(_) => atom
  }
}

///|
fn classify_function_body(function : AnfFunction) -> AnfFunction {
  { ..function, body: classify_lexical_expr(function.body), }
}

///|
fn classify_lexical_expr(expression : AnfExpr) -> AnfExpr {
  match expression {
    Atom(atom) => Atom(classify_first_class_atom(atom))
    Let(binding, body) => classify_lexical_let(binding, body)
    LetRec(bindings, body) => classify_lexical_letrec(bindings, body)
  }
}

///|
fn classify_lexical_let(binding : AnfBinding, body : AnfExpr) -> AnfExpr {
  match binding {
    Value(id~, rhs=Atom(atom)) =>
      match anf_atom_function(atom) {
        Some(function) => {
          let collector = CallableUseCollector::new(
            id,
            function.parameters.length(),
          )
          collector.collect_expr(body, true)
          let disposition = collector.disposition()
          Let(
            Value(
              id~,
              rhs=Atom(
                callable_atom_with_disposition(
                  classify_function_body(function),
                  disposition,
                ),
              ),
            ),
            classify_lexical_expr(body),
          )
        }
        None =>
          Let(
            Value(id~, rhs=classify_rhs_callables(Atom(atom))),
            classify_lexical_expr(body),
          )
      }
    _ =>
      Let(
        binding.with_rhs(classify_rhs_callables(binding.rhs())),
        classify_lexical_expr(body),
      )
  }
}

///|
fn classify_lexical_letrec(
  bindings : Array[AnfRecursiveBinding],
  body : AnfExpr,
) -> AnfExpr {
  let functions = bindings.map(binding => anf_atom_function(binding.rhs))
  let disposition = lexical_group_disposition(bindings, body, functions)
  LetRec(
    bindings.mapi((index, binding) => {
      guard functions[index] is Some(function) else {
        return { ..binding, rhs: classify_first_class_atom(binding.rhs), }
      }
      {
        ..binding,
        rhs: callable_atom_with_disposition(
          classify_function_body(function),
          disposition,
        ),
      }
    }),
    classify_lexical_expr(body),
  )
}

///|
fn lexical_group_disposition(
  bindings : Array[AnfRecursiveBinding],
  body : AnfExpr,
  functions : Array[AnfFunction?],
) -> LexicalCallableDisposition {
  let mut disposition = LexicalCallableDisposition::Join
  for index, binding in bindings {
    guard functions[index] is Some(function) else {
      disposition = Closure
      break
    }
    let collector = CallableUseCollector::new(
      binding.id,
      function.parameters.length(),
    )
    collector.collect_expr(body, true)
    for candidate in functions {
      if candidate is Some(candidate) {
        collector.collect_expr(candidate.body, true)
      }
    }
    match collector.disposition() {
      Closure => {
        disposition = Closure
        break
      }
      Direct => disposition = Direct
      Join => ()
    }
  }
  disposition
}

///|
fn CallableUseCollector::new(
  target : @buslane.ValueId,
  arity : Int,
) -> CallableUseCollector {
  {
    target,
    arity,
    direct_calls: 0,
    first_class: false,
    all_saturated: true,
    all_tail: true,
  }
}

///|
fn CallableUseCollector::disposition(
  self : CallableUseCollector,
) -> LexicalCallableDisposition {
  if self.first_class || !self.all_saturated || self.direct_calls == 0 {
    Closure
  } else if self.all_tail {
    Join
  } else {
    Direct
  }
}

///|
fn CallableUseCollector::collect_expr(
  self : CallableUseCollector,
  expression : AnfExpr,
  tail : Bool,
) -> Unit {
  match expression {
    Atom(atom) => self.collect_atom(atom)
    Let(binding, body) => {
      let rhs_tail = tail && binding_result_is_returned(binding, body)
      self.collect_rhs(binding.rhs(), rhs_tail)
      self.collect_expr(body, tail)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.collect_atom(binding.rhs)
      }
      self.collect_expr(body, tail)
    }
  }
}

///|
fn CallableUseCollector::collect_rhs(
  self : CallableUseCollector,
  rhs : AnfRhs,
  tail : Bool,
) -> Unit {
  match rhs {
    Atom(atom) => self.collect_atom(atom)
    Call(callee~, arguments~) => {
      match callee {
        Ref(value) if value == self.target => {
          self.direct_calls += 1
          self.all_saturated = self.all_saturated &&
            arguments.length() == self.arity
          self.all_tail = self.all_tail && tail
        }
        _ => self.collect_atom(callee)
      }
      for argument in arguments {
        self.collect_atom(argument)
      }
    }
    ApplyEvidence(callee~, ..) => self.collect_atom(callee)
    Construct(construct) =>
      for payload in construct.payloads {
        self.collect_atom(payload)
      }
    Match(match_) => {
      self.collect_atom(match_.scrutinee)
      for alternative in match_.alternatives {
        self.collect_expr(alternative.body, tail)
      }
    }
  }
}

///|
fn CallableUseCollector::collect_atom(
  self : CallableUseCollector,
  atom : AnfAtom,
) -> Unit {
  match atom {
    Ref(value) if value == self.target => self.first_class = true
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      if anf_expr_mentions_value(function.body, self.target) {
        self.first_class = true
      }
    EvidenceLambda(body~, ..) =>
      if anf_expr_mentions_value(body, self.target) {
        self.first_class = true
      }
    Literal(_) | Ref(_) | Temp(_) => ()
  }
}

///|
fn binding_result_is_returned(binding : AnfBinding, body : AnfExpr) -> Bool {
  match (binding, body) {
    (Value(id~, ..), Atom(Ref(result))) => id == result
    (Temp(temp~, ..), Atom(Temp(result))) => temp == result
    _ => false
  }
}

///|
fn anf_atom_function(atom : AnfAtom) -> AnfFunction? {
  match atom {
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      Some(function)
    Literal(_) | Ref(_) | Temp(_) | EvidenceLambda(_) => None
  }
}

///|
fn callable_atom_with_disposition(
  function : AnfFunction,
  disposition : LexicalCallableDisposition,
) -> AnfAtom {
  match disposition {
    Closure => Function(function)
    Direct => DirectFunction(function)
    Join => JoinPoint(function)
  }
}

///|
fn classify_first_class_atom(atom : AnfAtom) -> AnfAtom {
  match atom {
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      Function(classify_function_body(function))
    EvidenceLambda(parameters~, body~) =>
      EvidenceLambda(parameters~, body=classify_lexical_expr(body))
    Literal(_) | Ref(_) | Temp(_) => atom
  }
}

///|
fn classify_direct_callee_atom(atom : AnfAtom, arity : Int) -> AnfAtom {
  match atom {
    Function(function) | DirectFunction(function) | JoinPoint(function) if function.parameters.length() ==
      arity => DirectFunction(classify_function_body(function))
    _ => classify_first_class_atom(atom)
  }
}

///|
fn classify_rhs_callables(rhs : AnfRhs) -> AnfRhs {
  match rhs {
    Atom(atom) => Atom(classify_first_class_atom(atom))
    Call(callee~, arguments~) =>
      Call(
        callee=classify_direct_callee_atom(callee, arguments.length()),
        arguments=arguments.map(classify_first_class_atom),
      )
    ApplyEvidence(callee~, arguments~) =>
      ApplyEvidence(callee=classify_first_class_atom(callee), arguments~)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(classify_first_class_atom),
      })
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: classify_first_class_atom(match_.scrutinee),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: classify_lexical_expr(alternative.body),
        }),
      })
  }
}

///|
fn anf_expr_mentions_value(
  expression : AnfExpr,
  target : @buslane.ValueId,
) -> Bool {
  match expression {
    Atom(atom) => anf_atom_mentions_value(atom, target)
    Let(binding, body) =>
      anf_rhs_mentions_value(binding.rhs(), target) ||
      anf_expr_mentions_value(body, target)
    LetRec(bindings, body) =>
      bindings.any(binding => anf_atom_mentions_value(binding.rhs, target)) ||
      anf_expr_mentions_value(body, target)
  }
}

///|
fn anf_rhs_mentions_value(rhs : AnfRhs, target : @buslane.ValueId) -> Bool {
  match rhs {
    Atom(atom) | ApplyEvidence(callee=atom, ..) =>
      anf_atom_mentions_value(atom, target)
    Call(callee~, arguments~) =>
      anf_atom_mentions_value(callee, target) ||
      arguments.any(argument => anf_atom_mentions_value(argument, target))
    Construct(construct) =>
      construct.payloads.any(payload => anf_atom_mentions_value(payload, target))
    Match(match_) =>
      anf_atom_mentions_value(match_.scrutinee, target) ||
      match_.alternatives.any(alternative => {
        anf_expr_mentions_value(alternative.body, target)
      })
  }
}

///|
fn anf_atom_mentions_value(atom : AnfAtom, target : @buslane.ValueId) -> Bool {
  match atom {
    Ref(value) => value == target
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      anf_expr_mentions_value(function.body, target)
    EvidenceLambda(body~, ..) => anf_expr_mentions_value(body, target)
    Literal(_) | Temp(_) => false
  }
}
