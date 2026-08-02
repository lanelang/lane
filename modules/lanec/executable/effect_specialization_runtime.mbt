///|
priv struct EffectForwardingEdge {
  source : @buslane.ValueId
  target : @buslane.ValueId
}

///|
fn collect_runtime_polymorphic_definitions(
  program : @buslane.Program,
  occurrence : @occurrence.OccurrenceSummary,
) -> Array[Bool] {
  // A bare or incomplete application is the seed. If such a definition
  // forwards a symbolic effect to another generic definition, specializing
  // the callee would require inventing a concrete residual effect. Retain the
  // whole forwarding closure instead.
  let retained = occurrence.facts.map(fact => {
    fact.has_incomplete_type_application
  })
  let edges = []
  for term in program.terms {
    match term {
      Let(id, rhs) =>
        collect_effect_forwarding_edges(
          program.metadata,
          rhs,
          definition_owner(program.metadata, id, None),
          edges,
        )
      LetRec(bindings) =>
        for binding in bindings {
          collect_effect_forwarding_edges(
            program.metadata,
            binding.rhs,
            definition_owner(program.metadata, binding.id, None),
            edges,
          )
        }
      External(_) => ()
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for edge in edges {
      if retained[edge.source.index] && !retained[edge.target.index] {
        retained[edge.target.index] = true
        changed = true
      }
    }
  }
  retained
}

///|
fn definition_owner(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
  enclosing : @buslane.ValueId?,
) -> @buslane.ValueId? {
  // A nested effect-generic binding owns its forwarding dependencies. An
  // ordinary local expression executes as part of its enclosing definition.
  if effect_scheme_parameters(metadata, id) is Some(_) {
    Some(id)
  } else {
    enclosing
  }
}

///|
fn collect_effect_forwarding_edges(
  metadata : @buslane.MetadataRegistry,
  expression : @buslane.Expr,
  owner : @buslane.ValueId?,
  edges : Array[EffectForwardingEdge],
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) =>
      collect_effect_forwarding_edges(metadata, function.body, owner, edges)
    Call(callee, arguments) => {
      collect_effect_forwarding_edges(metadata, callee, owner, edges)
      for argument in arguments {
        collect_effect_forwarding_edges(metadata, argument, owner, edges)
      }
    }
    TypeLambda(_, body) =>
      collect_effect_forwarding_edges(metadata, body, owner, edges)
    TypeApply(_, _) => {
      record_effect_forwarding_edge(metadata, expression, owner, edges)
      let groups = []
      let base = collect_type_application_groups(expression, groups)
      collect_effect_forwarding_edges(metadata, base, owner, edges)
    }
    Construct(construct) =>
      for payload in construct.payloads {
        collect_effect_forwarding_edges(metadata, payload, owner, edges)
      }
    Let(id, initializer, body) => {
      collect_effect_forwarding_edges(
        metadata,
        initializer,
        definition_owner(metadata, id, owner),
        edges,
      )
      collect_effect_forwarding_edges(metadata, body, owner, edges)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        collect_effect_forwarding_edges(
          metadata,
          binding.rhs,
          definition_owner(metadata, binding.id, owner),
          edges,
        )
      }
      collect_effect_forwarding_edges(metadata, body, owner, edges)
    }
    Match(match_) => {
      collect_effect_forwarding_edges(metadata, match_.scrutinee, owner, edges)
      for alternative in match_.alternatives {
        collect_effect_forwarding_edges(
          metadata,
          alternative.body,
          owner,
          edges,
        )
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        collect_effect_forwarding_edges(metadata, payload, owner, edges)
      }
    Handle(handle) => {
      collect_effect_forwarding_edges(metadata, handle.body, owner, edges)
      collect_effect_forwarding_edges(metadata, handle.final_body, owner, edges)
      for table in handle.handlers {
        for operation in table.operations {
          collect_effect_forwarding_edges(
            metadata,
            operation.body,
            owner,
            edges,
          )
        }
      }
    }
  }
}

///|
fn record_effect_forwarding_edge(
  metadata : @buslane.MetadataRegistry,
  expression : @buslane.Expr,
  owner : @buslane.ValueId?,
  edges : Array[EffectForwardingEdge],
) -> Unit {
  guard owner is Some(source) else { return }
  let groups = []
  guard collect_type_application_groups(expression, groups) is Ref(target) else {
    return
  }
  guard effect_scheme_parameters(metadata, target) is Some(parameters) else {
    return
  }
  let arguments = []
  for group in groups {
    arguments.append(group)
  }
  let count = arguments.length().min(parameters.length())
  for index in 0..<count {
    if type_parameter_is_effect(metadata, parameters[index]) &&
      arguments[index] is EffectArgument(effect) &&
      effect_contains_parameter(effect) {
      if !edges.any(edge => edge.source == source && edge.target == target) {
        edges.push({ source, target })
      }
      return
    }
  }
}
