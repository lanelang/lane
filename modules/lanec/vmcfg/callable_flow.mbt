///|
priv enum CallableEnvironmentFact {
  CaptureFree
  LocalEnvironment(ValueId)
  PackedEnvironment
} derive(Debug, Eq)

///|
priv struct CallableAlternative {
  target : @bytecode.FunctionId
  environment : CallableEnvironmentFact
} derive(Debug, Eq)

///|
priv enum CallableFlowFact {
  Unreached
  Unknown(Array[CallableAlternative])
  KnownCallables(Array[CallableAlternative])
  KnownAggregate(
    @bytecode.ObjectShapeId,
    Array[CallableFlowFact],
    Array[CallableFlowFact],
    Array[ValueId]?,
    Array[ValueId]?
  )
} derive(Debug, Eq)

///|
priv struct CallableBodyFacts {
  values : Array[CallableFlowFact]
}

///|
priv struct CallableFlowAnalysis {
  bodies : Array[CallableBodyFacts?]
  globals : Array[CallableFlowFact]
  results : Array[CallableFlowFact]
}

///|
fn analyze_callable_flow(image : Image) -> CallableFlowAnalysis {
  let bodies = image.functions.map(entry => {
    match entry {
      Body(body) =>
        Some({ values: Array::make(body.values.length(), Unreached) })
      RuntimeImport(_) => None
    }
  })
  let analysis : CallableFlowAnalysis = {
    bodies,
    globals: Array::make(image.globals.length(), Unreached),
    results: Array::make(image.functions.length(), Unreached),
  }
  for index, entry in image.functions {
    guard entry is Body(body) && analysis.bodies[index] is Some(facts) else {
      continue
    }
    initialize_callable_inputs(body, facts.values)
  }
  let mut changed = true
  while changed {
    changed = false
    for function_index, entry in image.functions {
      guard entry is Body(body) &&
        analysis.bodies[function_index] is Some(facts) else {
        continue
      }
      if analyze_callable_body(
          body,
          facts.values,
          analysis.globals,
          analysis.results,
          function_index,
        ) {
        changed = true
      }
    }
  }
  analysis
}

///|
fn initialize_callable_inputs(
  body : FunctionBody,
  facts : Array[CallableFlowFact],
) -> Unit {
  if body.inputs.environment is Some(environment) {
    facts[environment.value] = Unknown([])
  }
  for witness in body.inputs.witnesses {
    facts[witness.value] = Unknown([])
  }
  for parameter in body.inputs.user_parameters {
    facts[parameter.value] = Unknown([])
  }
}

///|
fn analyze_callable_body(
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  globals : Array[CallableFlowFact],
  results : Array[CallableFlowFact],
  function_index : Int,
) -> Bool {
  let mut changed = false
  for block in body.blocks {
    for instruction in block.instructions {
      if analyze_callable_instruction(instruction, facts, globals, results) {
        changed = true
      }
    }
    if analyze_callable_terminator(
        block.terminator,
        body,
        facts,
        results,
        function_index,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn analyze_callable_instruction(
  instruction : Instruction,
  facts : Array[CallableFlowFact],
  globals : Array[CallableFlowFact],
  results : Array[CallableFlowFact],
) -> Bool {
  match instruction {
    Copy(destination, source)
    | Move(destination, source)
    | RetainCopy(destination, source)
    | EraseI64(destination, source)
    | UneraseI64(destination, source) =>
      refine_callable_fact(facts, destination, facts[source.value])
    ConstFunction(destination, target) =>
      refine_callable_fact(
        facts,
        destination,
        known_callable(target, CaptureFree),
      )
    MakeClosure(destination, target, environment) =>
      refine_callable_fact(
        facts,
        destination,
        known_callable(target, LocalEnvironment(environment)),
      )
    MakeData(destination, shape, _, witnesses, fields)
    | MakeEnv(destination, shape, _, witnesses, fields) =>
      refine_callable_fact(
        facts,
        destination,
        KnownAggregate(
          shape,
          witnesses.map(value => facts[value.value]),
          fields.map(value => facts[value.value]),
          Some(witnesses),
          Some(fields),
        ),
      )
    BorrowField(shape, source, member_index, result)
    | BorrowCapture(shape, source, member_index, result) => {
      let mut changed = refine_callable_fact(
        facts,
        result.value_destination,
        aggregate_member_fact(facts[source.value], shape, member_index),
      )
      if result.witness_destination is Some(witness) &&
        refine_callable_fact(facts, witness, Unknown([])) {
        changed = true
      }
      changed
    }
    ConsumeFields(shape, source, selections)
    | ConsumeCaptures(shape, source, selections) => {
      let mut changed = false
      for selection in selections {
        if refine_callable_fact(
            facts,
            selection.result.value_destination,
            aggregate_member_fact(
              facts[source.value],
              shape,
              selection.member_index,
            ),
          ) {
          changed = true
        }
        if selection.result.witness_destination is Some(witness) &&
          refine_callable_fact(facts, witness, Unknown([])) {
          changed = true
        }
      }
      changed
    }
    BorrowGlobal(destination, global) =>
      refine_callable_fact(
        facts,
        destination,
        if global.value >= 0 && global.value < globals.length() {
          globals[global.value]
        } else {
          Unknown([])
        },
      )
    InitGlobal(global, source) =>
      if global.value >= 0 && global.value < globals.length() {
        refine_callable_fact_array(
          globals,
          global.value,
          facts[source.value].cross_function(),
        )
      } else {
        false
      }
    CallDirect(target, _, _, _, Some(destination)) =>
      refine_callable_fact_array(
        facts,
        destination.value,
        function_result_fact(results, target),
      )
    CallValue(callable, _, _, Some(destination)) =>
      refine_callable_fact(
        facts,
        destination,
        callable_result_fact(facts[callable.value], results),
      )
    _ => {
      let mut changed = false
      for destination in instruction_destinations(instruction) {
        if refine_callable_fact(facts, destination, Unknown([])) {
          changed = true
        }
      }
      changed
    }
  }
}

///|
fn analyze_callable_terminator(
  terminator : Terminator,
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  results : Array[CallableFlowFact],
  function_index : Int,
) -> Bool {
  let mut changed = false
  for edge in terminator_edges(terminator) {
    let target = body.blocks[edge.target.value]
    for index, parameter in target.parameters {
      if refine_callable_fact(
          facts,
          parameter,
          facts[edge.arguments[index].value],
        ) {
        changed = true
      }
    }
  }
  if terminator is Return(Some(value)) &&
    refine_callable_fact_array(
      results,
      function_index,
      facts[value.value].cross_function(),
    ) {
    changed = true
  }
  changed
}

///|
fn terminator_edges(terminator : Terminator) -> Array[Edge] {
  match terminator {
    Jump(edge) => [edge]
    BranchBool(_, if_true, if_false) => [if_true, if_false]
    SwitchTag(_, cases, default) => cases + [default]
    Return(_)
    | TailCallDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal(_)
    | Unreachable => []
  }
}

///|
fn aggregate_member_fact(
  fact : CallableFlowFact,
  shape : @bytecode.ObjectShapeId,
  member_index : Int,
) -> CallableFlowFact {
  match fact {
    KnownAggregate(selected, _, members, _, _) if selected == shape &&
      member_index >= 0 &&
      member_index < members.length() => members[member_index]
    Unreached => Unreached
    fact => Unknown(callable_alternatives(fact))
  }
}

///|
fn known_callable(
  target : @bytecode.FunctionId,
  environment : CallableEnvironmentFact,
) -> CallableFlowFact {
  KnownCallables([{ target, environment }])
}

///|
fn function_result_fact(
  results : Array[CallableFlowFact],
  target : @bytecode.FunctionId,
) -> CallableFlowFact {
  let index = target.value - 1
  if index >= 0 && index < results.length() {
    results[index]
  } else {
    Unknown([])
  }
}

///|
fn callable_result_fact(
  callable : CallableFlowFact,
  results : Array[CallableFlowFact],
) -> CallableFlowFact {
  match callable {
    Unreached => Unreached
    KnownCallables(alternatives) =>
      alternatives.fold(init=Unreached, fn(result, alternative) {
        merge_callable_facts(
          result,
          function_result_fact(results, alternative.target),
        )
      })
    Unknown(alternatives) => {
      let result = alternatives.fold(init=Unreached, fn(result, alternative) {
        merge_callable_facts(
          result,
          function_result_fact(results, alternative.target),
        )
      })
      Unknown(callable_alternatives(result))
    }
    KnownAggregate(_, _, _, _, _) => Unknown(callable_alternatives(callable))
  }
}

///|
fn refine_callable_fact(
  facts : Array[CallableFlowFact],
  destination : ValueId,
  fact : CallableFlowFact,
) -> Bool {
  refine_callable_fact_array(facts, destination.value, fact)
}

///|
fn refine_callable_fact_array(
  facts : Array[CallableFlowFact],
  index : Int,
  fact : CallableFlowFact,
) -> Bool {
  let merged = merge_callable_facts(facts[index], fact)
  if merged == facts[index] {
    false
  } else {
    facts[index] = merged
    true
  }
}

///|
fn merge_callable_facts(
  left : CallableFlowFact,
  right : CallableFlowFact,
) -> CallableFlowFact {
  match (left, right) {
    (Unreached, fact) | (fact, Unreached) => fact
    (Unknown(left), fact) | (fact, Unknown(left)) =>
      Unknown(merge_callable_alternatives(left, callable_alternatives(fact)))
    (KnownCallables(left), KnownCallables(right)) =>
      KnownCallables(merge_callable_alternatives(left, right))
    (
      KnownAggregate(
        left_shape,
        left_witnesses,
        left_members,
        left_witness_ids,
        left_member_ids
      ),
      KnownAggregate(
        right_shape,
        right_witnesses,
        right_members,
        right_witness_ids,
        right_member_ids
      ),
    ) if left_shape == right_shape &&
      left_witnesses.length() == right_witnesses.length() &&
      left_members.length() == right_members.length() =>
      KnownAggregate(
        left_shape,
        merge_callable_fact_arrays(left_witnesses, right_witnesses),
        merge_callable_fact_arrays(left_members, right_members),
        if left_witness_ids == right_witness_ids {
          left_witness_ids
        } else {
          None
        },
        if left_member_ids == right_member_ids {
          left_member_ids
        } else {
          None
        },
      )
    _ =>
      Unknown(
        merge_callable_alternatives(
          callable_alternatives(left),
          callable_alternatives(right),
        ),
      )
  }
}

///|
fn merge_callable_alternatives(
  left : Array[CallableAlternative],
  right : Array[CallableAlternative],
) -> Array[CallableAlternative] {
  let merged = left.copy()
  for alternative in right {
    let mut found = false
    for index, existing in merged {
      if existing.target == alternative.target {
        found = true
        if existing.environment != alternative.environment {
          merged[index] = { ..existing, environment: PackedEnvironment }
        }
        break
      }
    }
    if !found {
      merged.push(alternative)
    }
  }
  merged
}

///|
fn callable_alternatives(fact : CallableFlowFact) -> Array[CallableAlternative] {
  match fact {
    KnownCallables(alternatives) | Unknown(alternatives) => alternatives
    KnownAggregate(_, witnesses, members, _, _) => {
      let mut alternatives = []
      for nested in witnesses {
        alternatives = merge_callable_alternatives(
          alternatives,
          callable_alternatives(nested),
        )
      }
      for nested in members {
        alternatives = merge_callable_alternatives(
          alternatives,
          callable_alternatives(nested),
        )
      }
      alternatives
    }
    Unreached => []
  }
}

///|
fn merge_callable_fact_arrays(
  left : Array[CallableFlowFact],
  right : Array[CallableFlowFact],
) -> Array[CallableFlowFact] {
  left.mapi(fn(index, fact) { merge_callable_facts(fact, right[index]) })
}

///|
fn CallableFlowFact::cross_function(
  self : CallableFlowFact,
) -> CallableFlowFact {
  match self {
    KnownCallables(alternatives) =>
      KnownCallables(
        alternatives.map(alternative => {
          match alternative.environment {
            LocalEnvironment(_) =>
              { ..alternative, environment: PackedEnvironment }
            CaptureFree | PackedEnvironment => alternative
          }
        }),
      )
    Unknown(alternatives) =>
      Unknown(
        alternatives.map(alternative => {
          match alternative.environment {
            LocalEnvironment(_) =>
              { ..alternative, environment: PackedEnvironment }
            CaptureFree | PackedEnvironment => alternative
          }
        }),
      )
    Unreached => self
    KnownAggregate(shape, witnesses, members, _, _) =>
      KnownAggregate(
        shape,
        witnesses.map(fact => fact.cross_function()),
        members.map(fact => fact.cross_function()),
        None,
        None,
      )
  }
}

///|
fn CallableFlowAnalysis::body_facts(
  self : CallableFlowAnalysis,
  function_index : Int,
) -> CallableBodyFacts? {
  self.bodies[function_index]
}

///|
