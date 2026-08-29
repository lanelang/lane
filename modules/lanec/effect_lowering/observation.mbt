///|
using @prettyprinter {hardline, separate}

///|
priv struct EffectLoweringCode {
  terms : Array[TopTerm]
}

///|
impl @prettyprinter.Pretty for EffectLoweringCode with fn pretty(
  code : EffectLoweringCode,
) {
  separate(hardline, code.terms.map(@prettyprinter.Pretty::pretty))
}

///|
priv struct EffectLoweringScaleAccumulator {
  mut functions : Int
  mut calls : Int
}

///|
fn effect_lowering_snapshot(
  stage : EffectLoweringSnapshotStage,
  program : Program,
) -> EffectLoweringSnapshot {
  {
    stage,
    text: @prettyprinter.render(
      EffectLoweringCode::{ terms: program.terms, },
      width=100,
    ),
    scale: effect_lowering_scale(program),
  }
}

///|
fn effect_lowering_scale(program : Program) -> EffectLoweringScale {
  let accumulator : EffectLoweringScaleAccumulator = { functions: 0, calls: 0, }
  let mut nodes = 0
  for term in program.terms {
    nodes += 1
    match term {
      Let(_, expression) =>
        nodes += observe_effect_lowering_expr(expression, accumulator)
      LetRec(bindings) =>
        for binding in bindings {
          nodes += 1 + observe_effect_lowering_expr(binding.rhs, accumulator)
        }
      External(_) => ()
    }
  }
  {
    top_terms: program.terms.length(),
    functions: accumulator.functions,
    nodes,
    calls: accumulator.calls,
  }
}

///|
fn observe_effect_function(
  function : FunctionExpr,
  accumulator : EffectLoweringScaleAccumulator,
) -> Int {
  let body_nodes = observe_effect_lowering_expr(function.body, accumulator)
  accumulator.functions += 1
  body_nodes
}

///|
fn observe_effect_lowering_expr(
  expression : Expr,
  accumulator : EffectLoweringScaleAccumulator,
) -> Int {
  match expression {
    Ref(_) | Literal(_) => 1
    Function(function) => 1 + observe_effect_function(function, accumulator)
    Call(callee, arguments) => {
      accumulator.calls += 1
      1 +
      observe_effect_lowering_expr(callee, accumulator) +
      arguments.fold(init=0, fn(total, argument) {
        total + observe_effect_lowering_expr(argument, accumulator)
      })
    }
    TypeLambda(_, body) | TypeApply(body, _) =>
      1 + observe_effect_lowering_expr(body, accumulator)
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(total, payload) {
        total + observe_effect_lowering_expr(payload, accumulator)
      })
    Let(_, initializer, body) =>
      1 +
      observe_effect_lowering_expr(initializer, accumulator) +
      observe_effect_lowering_expr(body, accumulator)
    LetRec(bindings, body) => {
      let mut nodes = 1 + observe_effect_lowering_expr(body, accumulator)
      for binding in bindings {
        nodes += 1 + observe_effect_lowering_expr(binding.rhs, accumulator)
      }
      nodes
    }
    Match(match_) => {
      let mut nodes = 1 +
        observe_effect_lowering_expr(match_.scrutinee, accumulator)
      for alternative in match_.alternatives {
        nodes += 1 + observe_effect_lowering_expr(alternative.body, accumulator)
      }
      nodes
    }
    Invoke(invoke) =>
      1 +
      invoke.payloads.fold(init=0, fn(total, payload) {
        total + observe_effect_lowering_expr(payload, accumulator)
      })
    Install(install) => {
      let mut nodes = 2 +
        observe_effect_lowering_expr(install.body, accumulator) +
        observe_effect_function(install.final_clause, accumulator)
      for dictionary in install.dictionaries {
        nodes += 1
        for operation in dictionary.operations {
          let callable_nodes = match operation.callable {
            Monomorphic(function) | Polymorphic(_, function) =>
              observe_effect_function(function, accumulator)
          }
          nodes += 2 + callable_nodes
        }
      }
      nodes
    }
    Bind(bind) =>
      2 +
      observe_effect_lowering_expr(bind.computation, accumulator) +
      observe_effect_function(bind.continuation, accumulator)
    OpenContext(context) =>
      1 + observe_effect_lowering_expr(context.body, accumulator)
  }
}
