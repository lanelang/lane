///|
fn normalize_install_resume_effects(
  program : Program,
) -> Unit raise SynthesisError {
  for term in program.terms {
    match term {
      Let(_, expression) => normalize_resume_effects_expr(program, expression)
      LetRec(bindings) =>
        for binding in bindings {
          normalize_resume_effects_expr(program, binding.rhs)
        }
      External(_) => ()
    }
  }
}

///|
fn normalize_resume_effects_expr(
  program : Program,
  expression : Expr,
) -> Unit raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => ()
    Function(function) => normalize_resume_effects_expr(program, function.body)
    Call(callee, arguments) => {
      normalize_resume_effects_expr(program, callee)
      for argument in arguments {
        normalize_resume_effects_expr(program, argument)
      }
    }
    TypeLambda(_, body) => normalize_resume_effects_expr(program, body)
    TypeApply(callee, _) => normalize_resume_effects_expr(program, callee)
    Construct(construct) =>
      for payload in construct.payloads {
        normalize_resume_effects_expr(program, payload)
      }
    Let(_, initializer, body) => {
      normalize_resume_effects_expr(program, initializer)
      normalize_resume_effects_expr(program, body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        normalize_resume_effects_expr(program, binding.rhs)
      }
      normalize_resume_effects_expr(program, body)
    }
    Match(match_) => {
      normalize_resume_effects_expr(program, match_.scrutinee)
      for alternative in match_.alternatives {
        normalize_resume_effects_expr(program, alternative.body)
      }
    }
    Invoke(invoke) =>
      for payload in invoke.payloads {
        normalize_resume_effects_expr(program, payload)
      }
    Install(install) => {
      normalize_resume_effects_expr(program, install.body)
      normalize_resume_effects_expr(program, install.final_clause.body)
      for dictionary in install.dictionaries {
        for clause in dictionary.operations {
          let function = match clause.callable {
            Monomorphic(function) | Polymorphic(_, function) => function
          }
          normalize_resume_effects_expr(program, function.body)
        }
      }
      let effect = synthesize_expr_or_raise(program.metadata, Install(install)).effect
      for dictionary in install.dictionaries {
        for clause in dictionary.operations {
          let function = match clause.callable {
            Monomorphic(function) | Polymorphic(_, function) => function
          }
          guard function.parameters.last() is Some(resume_binder) else {
            raise ArityMismatch(expected=1, actual=0)
          }
          set_source_resume_effect(program.metadata, resume_binder, effect)
        }
      }
    }
    Bind(bind) => {
      normalize_resume_effects_expr(program, bind.computation)
      normalize_resume_effects_expr(program, bind.continuation.body)
    }
    OpenContext(open) => normalize_resume_effects_expr(program, open.body)
  }
}
