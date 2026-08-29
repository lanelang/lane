///|
fn resolve_open_contexts_or_raise(
  program : Program,
) -> Program raise SynthesisError {
  validate_mon_trans_output_or_raise(program)
  let output = Program::{
    metadata: program.metadata,
    terms: program.terms.map(term => {
      resolve_open_top_term(program.metadata, term)
    }),
  }
  validate_open_resolve_output_or_raise(output)
  output
}

///|
fn resolve_open_top_term(
  metadata : @buslane.MetadataRegistry,
  term : TopTerm,
) -> TopTerm raise SynthesisError {
  match term {
    Let(id, expression) => Let(id, resolve_open_expr(metadata, expression))
    LetRec(bindings) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: resolve_open_expr(metadata, binding.rhs),
        }),
      )
    External(id) => External(id)
  }
}

///|
fn resolve_open_expr(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> Expr raise SynthesisError {
  match expression {
    Ref(_) | Literal(_) => expression
    Function(function) =>
      Function({ ..function, body: resolve_open_expr(metadata, function.body), })
    Call(callee, arguments) =>
      Call(
        resolve_open_expr(metadata, callee),
        arguments.map(argument => resolve_open_expr(metadata, argument)),
      )
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, resolve_open_expr(metadata, body))
    TypeApply(callee, arguments) =>
      TypeApply(resolve_open_expr(metadata, callee), arguments)
    Construct(construct) =>
      Construct({
        ..construct,
        payloads: construct.payloads.map(payload => {
          resolve_open_expr(metadata, payload)
        }),
      })
    Let(id, initializer, body) =>
      Let(
        id,
        resolve_open_expr(metadata, initializer),
        resolve_open_expr(metadata, body),
      )
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => {
          id: binding.id,
          rhs: resolve_open_expr(metadata, binding.rhs),
        }),
        resolve_open_expr(metadata, body),
      )
    Match(match_) =>
      Match({
        ..match_,
        scrutinee: resolve_open_expr(metadata, match_.scrutinee),
        alternatives: match_.alternatives.map(alternative => {
          ..alternative,
          body: resolve_open_expr(metadata, alternative.body),
        }),
      })
    OpenContext(open) => {
      require_open_contexts(metadata, open.source_effect, open.target_effect)
      resolve_open_expr(metadata, open.body)
    }
    Invoke(_) | Install(_) | Bind(_) => expression
  }
}

///|
fn require_open_contexts(
  metadata : @buslane.MetadataRegistry,
  source : @buslane.Effect,
  target : @buslane.Effect,
) -> Unit raise SynthesisError {
  let available = effect_terms(metadata, target)
  for required in effect_terms(metadata, source) {
    let mut found = false
    for context in available {
      if effects_definitionally_equal(metadata, context, required) {
        found = true
        break
      }
    }
    if !found {
      raise MissingEffectContext(required)
    }
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
