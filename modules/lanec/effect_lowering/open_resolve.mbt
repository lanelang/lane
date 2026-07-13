///|
pub fn resolve_open_contexts(
  program : Program,
) -> Result[Program, SynthesisError] {
  Ok(resolve_open_contexts_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn resolve_open_contexts_or_raise(
  program : Program,
) -> Program raise SynthesisError {
  validate_mon_trans_output_or_raise(program)
  let output = Program::{
    metadata: program.metadata,
    terms: program.terms.map(resolve_open_top_term),
  }
  validate_open_resolve_output_or_raise(output)
  output
}

///|
fn resolve_open_top_term(term : TopTerm) -> TopTerm {
  match term {
    Let(id, expression) => Let(id, resolve_open_expr(expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: resolve_open_expr(binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn resolve_open_expr(expression : Expr) -> Expr {
  match expression {
    Ref(_) | Literal(_) => expression
    Function(function) =>
      Function({ ..function, body: resolve_open_expr(function.body) })
    Call(callee, arguments) =>
      Call(resolve_open_expr(callee), arguments.map(resolve_open_expr))
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, resolve_open_expr(body))
    TypeApply(callee, arguments) =>
      TypeApply(resolve_open_expr(callee), arguments)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(resolve_open_expr),
      })
    Let(id, initializer, body) =>
      Let(id, resolve_open_expr(initializer), resolve_open_expr(body))
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: resolve_open_expr(binding.rhs),
        }),
        resolve_open_expr(body),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: resolve_open_expr(match_.scrutinee),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: resolve_open_expr(alternative.body),
        }),
      })
    OpenContext(open) => resolve_open_expr(open.body)
    Invoke(_) | Install(_) | Bind(_) => expression
  }
}

///|
pub fn validate_open_resolve_output(
  program : Program,
) -> Result[Unit, SynthesisError] {
  Ok(validate_open_resolve_output_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn validate_open_resolve_output_or_raise(
  program : Program,
) -> Unit raise SynthesisError {
  validate_mon_trans_output_or_raise(program)
  for term in program.terms {
    match term {
      Let(_, expression) => reject_open_expr(expression)
      LetRec(bindings) =>
        for binding in bindings {
          reject_open_expr(binding.rhs)
        }
      External(_) => ()
    }
  }
}

///|
fn reject_open_expr(expression : Expr) -> Unit raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => ()
    Function(function) => reject_open_expr(function.body)
    Call(callee, arguments) => {
      reject_open_expr(callee)
      for argument in arguments {
        reject_open_expr(argument)
      }
    }
    TypeLambda(_, body) => reject_open_expr(body)
    TypeApply(callee, _) => reject_open_expr(callee)
    Construct(construct) =>
      for payload in construct.payloads {
        reject_open_expr(payload)
      }
    Let(_, initializer, body) => {
      reject_open_expr(initializer)
      reject_open_expr(body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        reject_open_expr(binding.rhs)
      }
      reject_open_expr(body)
    }
    Match(match_) => {
      reject_open_expr(match_.scrutinee)
      for alternative in match_.alternatives {
        reject_open_expr(alternative.body)
      }
    }
    OpenContext(open) =>
      raise ResidualOpenContext(
        source=open.source_effect,
        target=open.target_effect,
      )
    Invoke(invoke) => raise ResidualInvoke(invoke.operation)
    Install(_) => raise ResidualInstall
    Bind(_) => raise ResidualBind
  }
}
