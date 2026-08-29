///|
/// Stable aggregate structure owned by Buslane. Tree-shaped Buslane has no
/// function identity, so this observation deliberately contains no per-function
/// records.
pub(all) struct ProgramScale {
  top_terms : Int
  functions : Int
  nodes : Int
  calls : Int
  generic_binders : Int
  type_applications : Int
  externals : Int
} derive(Debug, Eq)

///|
priv struct ProgramScaleAccumulator {
  mut functions : Int
  mut calls : Int
  mut generic_binders : Int
  mut type_applications : Int
}

///|
pub fn Program::structural_scale(self : Program) -> ProgramScale {
  let accumulator : ProgramScaleAccumulator = {
    functions: 0,
    calls: 0,
    generic_binders: 0,
    type_applications: 0,
  }
  let mut nodes = 0
  let mut externals = 0
  for term in self.terms {
    nodes += 1
    match term {
      Let(_, expression) => nodes += expression.scale_nodes(accumulator)
      LetRec(bindings) =>
        for binding in bindings {
          nodes += 1 + binding.rhs.scale_nodes(accumulator)
        }
      External(_) => externals += 1
    }
  }
  {
    top_terms: self.terms.length(),
    functions: accumulator.functions,
    nodes,
    calls: accumulator.calls,
    generic_binders: accumulator.generic_binders,
    type_applications: accumulator.type_applications,
    externals,
  }
}

///|
fn Expr::scale_nodes(self : Expr, accumulator : ProgramScaleAccumulator) -> Int {
  match self {
    Ref(_) | Literal(_) | Resume(_) => 1
    Function(function) => {
      accumulator.functions += 1
      1 + function.body.scale_nodes(accumulator)
    }
    Call(callee, arguments) => {
      accumulator.calls += 1
      1 +
      callee.scale_nodes(accumulator) +
      arguments.fold(init=0, fn(total, argument) {
        total + argument.scale_nodes(accumulator)
      })
    }
    TypeLambda(parameters, body) => {
      accumulator.generic_binders += parameters.length()
      1 + body.scale_nodes(accumulator)
    }
    TypeApply(body, _) => {
      accumulator.type_applications += 1
      1 + body.scale_nodes(accumulator)
    }
    Construct(construct) =>
      1 +
      construct.payloads.fold(init=0, fn(total, payload) {
        total + payload.scale_nodes(accumulator)
      })
    Let(_, initializer, body) =>
      1 + initializer.scale_nodes(accumulator) + body.scale_nodes(accumulator)
    LetRec(bindings, body) => {
      let mut nodes = 1 + body.scale_nodes(accumulator)
      for binding in bindings {
        nodes += 1 + binding.rhs.scale_nodes(accumulator)
      }
      nodes
    }
    Match(match_) => {
      let mut nodes = 1 + match_.scrutinee.scale_nodes(accumulator)
      for alternative in match_.alternatives {
        nodes += 1 + alternative.body.scale_nodes(accumulator)
      }
      nodes
    }
    Perform(perform) =>
      1 +
      perform.payloads.fold(init=0, fn(total, payload) {
        total + payload.scale_nodes(accumulator)
      })
    Handle(handle) => {
      let mut nodes = 1 +
        handle.body.scale_nodes(accumulator) +
        handle.final_body.scale_nodes(accumulator)
      for table in handle.handlers {
        nodes += 1
        for operation in table.operations {
          nodes += 1 + operation.body.scale_nodes(accumulator)
        }
      }
      nodes
    }
  }
}
