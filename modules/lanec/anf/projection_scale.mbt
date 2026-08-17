///|
priv struct GenericStructureScale {
  mut binders : Int
  mut applications : Int
}

///|
fn runtime_anf_projection_scale(
  source : @buslane.Program,
  runtime : AnfProgram,
) -> RuntimeAnfProjectionScale {
  let source_scale : GenericStructureScale = { binders: 0, applications: 0 }
  for term in source.terms {
    observe_source_generic_structure(term, source_scale)
  }
  let runtime_scale : GenericStructureScale = { binders: 0, applications: 0 }
  for term in runtime.terms {
    observe_runtime_generic_structure(term, runtime_scale)
  }
  {
    source_generic_binders: source_scale.binders,
    runtime_generic_binders: runtime_scale.binders,
    source_type_applications: source_scale.applications,
    runtime_type_applications: runtime_scale.applications,
  }
}

///|
fn observe_source_generic_structure(
  term : @buslane.TopTerm,
  scale : GenericStructureScale,
) -> Unit {
  match term {
    Let(_, expression) =>
      observe_source_expr_generic_structure(expression, scale)
    LetRec(bindings) =>
      for binding in bindings {
        observe_source_expr_generic_structure(binding.rhs, scale)
      }
    External(_) => ()
  }
}

///|
fn observe_source_expr_generic_structure(
  expression : @buslane.Expr,
  scale : GenericStructureScale,
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) => {
      observe_type_generic_structure(function.result_type, scale)
      observe_source_expr_generic_structure(function.body, scale)
    }
    Call(callee, arguments) => {
      observe_source_expr_generic_structure(callee, scale)
      for argument in arguments {
        observe_source_expr_generic_structure(argument, scale)
      }
    }
    TypeLambda(parameters, body) => {
      scale.binders += parameters.length()
      observe_source_expr_generic_structure(body, scale)
    }
    TypeApply(callee, arguments) => {
      scale.applications += 1
      observe_source_expr_generic_structure(callee, scale)
      for argument in arguments {
        observe_argument_generic_structure(argument, scale)
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments {
        observe_argument_generic_structure(argument, scale)
      }
      for witness in construct.hidden_witnesses {
        observe_argument_generic_structure(witness, scale)
      }
      for payload in construct.payloads {
        observe_source_expr_generic_structure(payload, scale)
      }
    }
    Let(_, initializer, body) => {
      observe_source_expr_generic_structure(initializer, scale)
      observe_source_expr_generic_structure(body, scale)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        observe_source_expr_generic_structure(binding.rhs, scale)
      }
      observe_source_expr_generic_structure(body, scale)
    }
    Match(match_) => {
      observe_source_expr_generic_structure(match_.scrutinee, scale)
      observe_type_generic_structure(match_.result_type, scale)
      for alternative in match_.alternatives {
        scale.binders += alternative.type_binders.length()
        observe_source_expr_generic_structure(alternative.body, scale)
      }
    }
    Perform(perform) => {
      for argument in perform.effect_arguments {
        observe_argument_generic_structure(argument, scale)
      }
      for witness in perform.hidden_witnesses {
        observe_argument_generic_structure(witness, scale)
      }
      for payload in perform.payloads {
        observe_source_expr_generic_structure(payload, scale)
      }
    }
    Handle(handle) => {
      observe_source_expr_generic_structure(handle.body, scale)
      observe_type_generic_structure(handle.result_type, scale)
      observe_source_expr_generic_structure(handle.final_body, scale)
      for table in handle.handlers {
        observe_effect_generic_structure(table.handled_effect, scale)
        for alternative in table.operations {
          scale.binders += alternative.type_binders.length()
          observe_source_expr_generic_structure(alternative.body, scale)
        }
      }
    }
  }
}

///|
fn observe_runtime_generic_structure(
  term : AnfTopTerm,
  scale : GenericStructureScale,
) -> Unit {
  match term {
    Let(_, expression) =>
      observe_runtime_expr_generic_structure(expression, scale)
    LetRec(bindings) =>
      for binding in bindings {
        observe_runtime_atom_generic_structure(binding.rhs, scale)
      }
    External(_) => ()
  }
}

///|
fn observe_runtime_expr_generic_structure(
  expression : AnfExpr,
  scale : GenericStructureScale,
) -> Unit {
  match expression {
    Atom(atom) => observe_runtime_atom_generic_structure(atom, scale)
    Let(binding, body) => {
      match binding {
        Value(rhs~, ..) | Temp(rhs~, ..) =>
          observe_runtime_rhs_generic_structure(rhs, scale)
      }
      observe_runtime_expr_generic_structure(body, scale)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        observe_runtime_atom_generic_structure(binding.rhs, scale)
      }
      observe_runtime_expr_generic_structure(body, scale)
    }
  }
}

///|
fn observe_runtime_rhs_generic_structure(
  rhs : AnfRhs,
  scale : GenericStructureScale,
) -> Unit {
  match rhs {
    Atom(atom) => observe_runtime_atom_generic_structure(atom, scale)
    Call(callee~, arguments~) => {
      observe_runtime_atom_generic_structure(callee, scale)
      for argument in arguments {
        observe_runtime_atom_generic_structure(argument, scale)
      }
    }
    TypeApply(callee~, arguments~) => {
      scale.applications += 1
      observe_runtime_atom_generic_structure(callee, scale)
      for argument in arguments {
        observe_argument_generic_structure(argument, scale)
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments {
        observe_argument_generic_structure(argument, scale)
      }
      for witness in construct.hidden_witnesses {
        observe_argument_generic_structure(witness, scale)
      }
      for payload in construct.payloads {
        observe_runtime_atom_generic_structure(payload, scale)
      }
    }
    Match(match_) => {
      observe_runtime_atom_generic_structure(match_.scrutinee, scale)
      observe_type_generic_structure(match_.result_type, scale)
      for alternative in match_.alternatives {
        scale.binders += alternative.type_binders.length()
        observe_runtime_expr_generic_structure(alternative.body, scale)
      }
    }
  }
}

///|
fn observe_runtime_atom_generic_structure(
  atom : AnfAtom,
  scale : GenericStructureScale,
) -> Unit {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => ()
    Function(function) => {
      observe_type_generic_structure(function.result_type, scale)
      observe_runtime_expr_generic_structure(function.body, scale)
    }
    TypeLambda(type_parameters~, body~) => {
      scale.binders += type_parameters.length()
      observe_runtime_expr_generic_structure(body, scale)
    }
  }
}

///|
fn observe_type_generic_structure(
  type_ : @buslane.Type,
  scale : GenericStructureScale,
) -> Unit {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => ()
    Apply(callee, arguments) => {
      scale.applications += 1
      observe_type_generic_structure(callee, scale)
      for argument in arguments {
        observe_argument_generic_structure(argument, scale)
      }
    }
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      scale.binders += parameters.length()
      observe_type_generic_structure(body, scale)
    }
    Function(parameters, result, effect) => {
      for parameter in parameters {
        observe_type_generic_structure(parameter, scale)
      }
      observe_type_generic_structure(result, scale)
      observe_effect_generic_structure(effect, scale)
    }
  }
}

///|
fn observe_argument_generic_structure(
  argument : @buslane.GenericArgument,
  scale : GenericStructureScale,
) -> Unit {
  match argument {
    TypeArgument(type_) => observe_type_generic_structure(type_, scale)
    EffectArgument(effect) => observe_effect_generic_structure(effect, scale)
  }
}

///|
fn observe_effect_generic_structure(
  effect : @buslane.Effect,
  scale : GenericStructureScale,
) -> Unit {
  match effect {
    Empty | Builtin(_) | Parameter(_) => ()
    Singleton(_, arguments) =>
      for argument in arguments {
        observe_argument_generic_structure(argument, scale)
      }
    Union(effects) =>
      for effect in effects {
        observe_effect_generic_structure(effect, scale)
      }
  }
}
