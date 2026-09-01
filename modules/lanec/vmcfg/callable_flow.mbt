///|
priv enum CallableEnvironmentFact {
  CaptureFree
  LocalEnvironment(ValueId)
  PackedEnvironment
} derive(Eq)

///|
priv struct CallableAlternative {
  target : @physical.FunctionId
  environment : CallableEnvironmentFact
} derive(Eq)

///|
priv struct CallableFlowValueRef {
  function_index : Int
  value : ValueId
}

///|
priv struct AggregateSiteId {
  value : Int
} derive(Eq)

///|
priv struct AggregateSite {
  function_index : Int
  destination : ValueId
  shape : @physical.ObjectShapeId
  witnesses : Array[CallableFlowValueRef]
  members : Array[CallableFlowValueRef]
}

///|
priv struct AggregateReference {
  site : AggregateSiteId
  locally_available : Bool
} derive(Eq)

///|
priv enum CallableFlowFact {
  Unreached
  Unknown(Array[CallableAlternative], Array[CallableFlowBoundary])
  KnownCallables(Array[CallableAlternative], Array[CallableFlowBoundary])
  KnownAggregates(Array[AggregateReference], Array[CallableFlowBoundary])
} derive(Eq)

///|
priv struct CallableBodyFacts {
  values : Array[CallableFlowFact]
}

///|
priv struct CallableFlowAnalysis {
  bodies : Array[CallableBodyFacts?]
  globals : Array[CallableFlowFact]
  results : Array[CallableFlowFact]
  aggregate_sites : Array[AggregateSite]
  materialized_targets : Array[Bool]
  closed_callable_universe : Bool
  mut resolve_opaque_calls : Bool
}

///|
fn analyze_callable_flow(image : Image) -> CallableFlowAnalysis {
  let bodies = image.functions.map(entry => {
    match entry {
      Body(body) =>
        Some({ values: Array::make(body.values.length(), Unreached), })
      RuntimeImport(_) => None
    }
  })
  let analysis : CallableFlowAnalysis = {
    bodies,
    globals: Array::make(image.globals.length(), Unreached),
    results: Array::make(image.functions.length(), Unreached),
    aggregate_sites: collect_aggregate_sites(image),
    materialized_targets: materialized_callable_targets(image),
    closed_callable_universe: roots_have_no_runtime_inputs(image),
    resolve_opaque_calls: false,
  }
  initialize_root_callable_inputs(image, analysis, image.entry)
  if image.initializer is Some(initializer) {
    initialize_root_callable_inputs(image, analysis, initializer)
  }
  propagate_callable_flow_to_fixed_point(image, analysis)
  analysis.resolve_opaque_calls = true
  propagate_callable_flow_to_fixed_point(image, analysis)
  analysis
}

///|
fn propagate_callable_flow_to_fixed_point(
  image : Image,
  analysis : CallableFlowAnalysis,
) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    for function_index, entry in image.functions {
      guard entry is Body(body) &&
        analysis.bodies[function_index] is Some(facts) else {
        continue
      }
      if analyze_callable_body(
          image,
          body,
          facts.values,
          analysis,
          function_index,
        ) {
        changed = true
      }
    }
  }
}

///|
fn initialize_root_callable_inputs(
  image : Image,
  analysis : CallableFlowAnalysis,
  function : @physical.FunctionId,
) -> Unit {
  let function_index = function.value - 1
  guard function_index >= 0 &&
    function_index < image.functions.length() &&
    image.functions[function_index] is Body(body) &&
    analysis.bodies[function_index] is Some(facts) else {
    return
  }
  if body.inputs.environment is Some(environment) {
    facts.values[environment.value] = Unknown([], [OpaqueInput])
  }
  for witness in body.inputs.witnesses {
    facts.values[witness.value] = Unknown([], [OpaqueInput])
  }
  for parameter in body.inputs.user_parameters {
    facts.values[parameter.value] = Unknown([], [OpaqueInput])
  }
}

///|
fn analyze_callable_body(
  image : Image,
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  analysis : CallableFlowAnalysis,
  function_index : Int,
) -> Bool {
  let mut changed = false
  for block in body.blocks {
    for instruction in block.instructions {
      if analyze_callable_instruction(
          image, body, instruction, facts, analysis, function_index,
        ) {
        changed = true
      }
    }
    if analyze_callable_terminator(
        image,
        block.terminator,
        body,
        facts,
        analysis,
        function_index,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn analyze_callable_instruction(
  image : Image,
  body : FunctionBody,
  instruction : Instruction,
  facts : Array[CallableFlowFact],
  analysis : CallableFlowAnalysis,
  function_index : Int,
) -> Bool {
  match instruction {
    Copy(destination, source)
    | Move(destination, source)
    | RetainCopy(destination, source)
    | EraseI64(destination, source)
    | UneraseI64(destination, source) =>
      refine_callable_fact(
        facts,
        destination,
        facts[source.value].through(Alias),
      )
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
    MakeData(destination, _, _, _, _) | MakeEnv(destination, _, _, _, _) =>
      refine_callable_fact(
        facts,
        destination,
        known_aggregate(analysis, function_index, destination),
      )
    BorrowField(shape, source, member_index, result)
    | BorrowCapture(shape, source, member_index, result) => {
      let mut changed = refine_callable_fact(
        facts,
        result.value_destination,
        aggregate_member_fact(
          analysis,
          facts[source.value],
          shape,
          member_index,
        ),
      )
      if result.witness_destination is Some(witness) &&
        refine_callable_fact(facts, witness, Unknown([], [OpaqueOperation])) {
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
              analysis,
              facts[source.value],
              shape,
              selection.member_index,
            ),
          ) {
          changed = true
        }
        if selection.result.witness_destination is Some(witness) &&
          refine_callable_fact(facts, witness, Unknown([], [OpaqueOperation])) {
          changed = true
        }
      }
      changed
    }
    BorrowGlobal(destination, global) =>
      refine_callable_fact(
        facts,
        destination,
        if global.value >= 0 && global.value < analysis.globals.length() {
          analysis.globals[global.value]
        } else {
          Unknown([], [OpaqueOperation])
        },
      )
    InitGlobal(global, source) =>
      if global.value >= 0 && global.value < analysis.globals.length() {
        refine_callable_fact_array(
          analysis.globals,
          global.value,
          facts[source.value].through(GlobalStorage).cross_function(),
        )
      } else {
        false
      }
    CallDirect(target, environment, witnesses, arguments, destination) => {
      let mut changed = propagate_callable_inputs(
        image,
        analysis,
        target,
        environment.map(value => facts[value.value]),
        witnesses.map(value => facts[value.value]),
        arguments.map(value => facts[value.value]),
      )
      if destination is Some(destination) &&
        refine_callable_fact_array(
          facts,
          destination.value,
          function_result_fact(analysis.results, target),
        ) {
        changed = true
      }
      changed
    }
    CallPackedDirect(target, _, witnesses, arguments, destination) => {
      let mut changed = propagate_callable_inputs(
        image,
        analysis,
        target,
        Some(Unknown([], [FunctionParameter])),
        witnesses.map(value => facts[value.value]),
        arguments.map(value => facts[value.value]),
      )
      if destination is Some(destination) &&
        refine_callable_fact_array(
          facts,
          destination.value,
          function_result_fact(analysis.results, target),
        ) {
        changed = true
      }
      changed
    }
    CallValue(callable, witnesses, arguments, destination) => {
      let callable_fact = if analysis.resolve_opaque_calls {
        complete_callable_at_callsite(
          image,
          analysis,
          body,
          facts[callable.value],
          witnesses,
          arguments,
          match destination {
            Some(value) => value_result_abi(body.values[value.value])
            None => Unit
          },
        )
      } else {
        facts[callable.value]
      }
      let mut changed = false
      if propagate_callable_invocation_inputs(
          image, analysis, facts, callable_fact, witnesses, arguments,
        ) {
        changed = true
      }
      if destination is Some(destination) &&
        refine_callable_fact(
          facts,
          destination,
          callable_result_fact(callable_fact, analysis.results),
        ) {
        changed = true
      }
      changed
    }
    _ => {
      let mut changed = false
      for destination in instruction_destinations(instruction) {
        if refine_callable_fact(
            facts,
            destination,
            Unknown([], [OpaqueOperation]),
          ) {
          changed = true
        }
      }
      changed
    }
  }
}

///|
fn analyze_callable_terminator(
  image : Image,
  terminator : Terminator,
  body : FunctionBody,
  facts : Array[CallableFlowFact],
  analysis : CallableFlowAnalysis,
  function_index : Int,
) -> Bool {
  let mut changed = false
  for edge in terminator_edges(terminator) {
    let target = body.blocks[edge.target.value]
    for index, parameter in target.parameters {
      if refine_callable_fact(
          facts,
          parameter,
          facts[edge.arguments[index].value].through(BlockParameter),
        ) {
        changed = true
      }
    }
  }
  if terminator is Return(Some(value)) &&
    refine_callable_fact_array(
      analysis.results,
      function_index,
      facts[value.value].through(FunctionResult).cross_function(),
    ) {
    changed = true
  }
  match terminator {
    TailCallDirect(target, environment, witnesses, arguments) => {
      if propagate_callable_inputs(
          image,
          analysis,
          target,
          environment.map(value => facts[value.value]),
          witnesses.map(value => facts[value.value]),
          arguments.map(value => facts[value.value]),
        ) {
        changed = true
      }
      if refine_callable_fact_array(
          analysis.results,
          function_index,
          function_result_fact(analysis.results, target)
          .through(FunctionResult)
          .cross_function(),
        ) {
        changed = true
      }
    }
    TailCallPackedDirect(target, _, witnesses, arguments) => {
      if propagate_callable_inputs(
          image,
          analysis,
          target,
          Some(Unknown([], [FunctionParameter])),
          witnesses.map(value => facts[value.value]),
          arguments.map(value => facts[value.value]),
        ) {
        changed = true
      }
      if refine_callable_fact_array(
          analysis.results,
          function_index,
          function_result_fact(analysis.results, target)
          .through(FunctionResult)
          .cross_function(),
        ) {
        changed = true
      }
    }
    TailCallValue(callable, witnesses, arguments) => {
      let callable_fact = if analysis.resolve_opaque_calls {
        complete_callable_at_callsite(
          image,
          analysis,
          body,
          facts[callable.value],
          witnesses,
          arguments,
          body.result,
        )
      } else {
        facts[callable.value]
      }
      if propagate_callable_invocation_inputs(
          image, analysis, facts, callable_fact, witnesses, arguments,
        ) {
        changed = true
      }
      if refine_callable_fact_array(
          analysis.results,
          function_index,
          callable_result_fact(callable_fact, analysis.results)
          .through(FunctionResult)
          .cross_function(),
        ) {
        changed = true
      }
    }
    _ => ()
  }
  changed
}

///|
fn complete_callable_at_callsite(
  image : Image,
  analysis : CallableFlowAnalysis,
  body : FunctionBody,
  fact : CallableFlowFact,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
  result : @physical.ResultAbi,
) -> CallableFlowFact {
  guard !(fact is KnownCallables(_, _)) else { return fact }
  let callsite : @physical.CallableAbi = {
    witnesses: witnesses.map(value => value_abi(body.values[value.value])),
    parameters: arguments.map(value => value_abi(body.values[value.value])),
    result,
  }
  let compatible = []
  for index, materialized in analysis.materialized_targets {
    guard materialized &&
      function_callable_abi(image.functions[index]) is Some(abi) &&
      abi.accepts_callsite(callsite) else {
      continue
    }
    compatible.push({
      target: { value: index + 1, },
      environment: match image.functions[index] {
        Body({ inputs: { environment: Some(_), .. }, .. }) => PackedEnvironment
        Body(_) | RuntimeImport(_) => CaptureFree
      },
    })
  }
  if !analysis.closed_callable_universe {
    return Unknown(
      merge_callable_alternatives(callable_alternatives(fact), compatible),
      merge_callable_boundaries(
        callable_boundaries(fact),
        if fact is Unreached {
          [OpaqueInput]
        } else {
          []
        },
      ),
    )
  }
  match fact {
    Unreached if !compatible.is_empty() =>
      KnownCallables(compatible, [OpaqueInput])
    Unreached => Unknown([], [OpaqueInput])
    Unknown(alternatives, boundaries) => {
      let alternatives = merge_callable_alternatives(alternatives, compatible)
      if alternatives.is_empty() {
        Unknown([], boundaries)
      } else {
        KnownCallables(alternatives, boundaries)
      }
    }
    KnownAggregates(_, _) =>
      Unknown(
        compatible,
        merge_callable_boundaries(callable_boundaries(fact), [OpaqueOperation]),
      )
    KnownCallables(_, _) => fact
  }
}

///|
fn roots_have_no_runtime_inputs(image : Image) -> Bool {
  guard root_has_no_runtime_inputs(image, image.entry) else { return false }
  match image.initializer {
    Some(initializer) => root_has_no_runtime_inputs(image, initializer)
    None => true
  }
}

///|
fn root_has_no_runtime_inputs(
  image : Image,
  function : @physical.FunctionId,
) -> Bool {
  let index = function.value - 1
  guard index >= 0 && index < image.functions.length() else { return false }
  match image.functions[index] {
    Body(body) =>
      body.inputs.environment is None &&
      body.inputs.witnesses.is_empty() &&
      body.inputs.user_parameters.is_empty()
    RuntimeImport(_) => false
  }
}

///|
fn materialized_callable_targets(image : Image) -> Array[Bool] {
  let targets = Array::make(image.functions.length(), false)
  for entry in image.functions {
    guard entry is Body(body) else { continue }
    for block in body.blocks {
      for instruction in block.instructions {
        let target = match instruction {
          ConstFunction(_, target) | MakeClosure(_, target, _) => Some(target)
          _ => None
        }
        if target is Some(target) &&
          target.value > 0 &&
          target.value <= targets.length() {
          targets[target.value - 1] = true
        }
      }
    }
  }
  targets
}

///|
fn function_callable_abi(entry : FunctionEntry) -> @physical.CallableAbi? {
  match entry {
    RuntimeImport(import_) =>
      Some(@physical.runtime_import_callable_abi(import_))
    Body(body) =>
      Some({
        witnesses: body.inputs.witnesses.map(value => {
          value_abi(body.values[value.value])
        }),
        parameters: body.inputs.user_parameters.map(value => {
          value_abi(body.values[value.value])
        }),
        result: body.result,
      })
  }
}

///|
fn value_abi(metadata : ValueMetadata) -> @physical.ValueAbi {
  {
    representation: metadata.representation,
    cleanup: metadata.cleanup,
    kind: metadata.kind,
  }
}

///|
fn value_result_abi(metadata : ValueMetadata) -> @physical.ResultAbi {
  Value(metadata.representation, metadata.cleanup, metadata.kind)
}

///|
fn propagate_callable_invocation_inputs(
  image : Image,
  analysis : CallableFlowAnalysis,
  facts : Array[CallableFlowFact],
  callable : CallableFlowFact,
  witnesses : Array[ValueId],
  arguments : Array[ValueId],
) -> Bool {
  let witness_facts = witnesses.map(value => facts[value.value])
  let argument_facts = arguments.map(value => facts[value.value])
  let mut changed = false
  for alternative in callable_alternatives(callable) {
    let environment = match alternative.environment {
      CaptureFree => None
      LocalEnvironment(value) => Some(facts[value.value])
      PackedEnvironment => Some(Unknown([], [FunctionParameter]))
    }
    if propagate_callable_inputs(
        image,
        analysis,
        alternative.target,
        environment,
        witness_facts,
        argument_facts,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn propagate_callable_inputs(
  image : Image,
  analysis : CallableFlowAnalysis,
  target : @physical.FunctionId,
  environment : CallableFlowFact?,
  witnesses : Array[CallableFlowFact],
  arguments : Array[CallableFlowFact],
) -> Bool {
  let function_index = target.value - 1
  guard function_index >= 0 &&
    function_index < image.functions.length() &&
    image.functions[function_index] is Body(body) &&
    analysis.bodies[function_index] is Some(target_facts) &&
    body.inputs.witnesses.length() == witnesses.length() &&
    body.inputs.user_parameters.length() == arguments.length() else {
    return false
  }
  let mut changed = false
  if body.inputs.environment is Some(input) {
    let fact = match environment {
      Some(fact) => fact.cross_function()
      None => Unknown([], [FunctionParameter])
    }
    if refine_callable_fact(target_facts.values, input, fact) {
      changed = true
    }
  }
  for index, input in body.inputs.witnesses {
    if refine_callable_fact(
        target_facts.values,
        input,
        witnesses[index].through(FunctionParameter).cross_function(),
      ) {
      changed = true
    }
  }
  for index, input in body.inputs.user_parameters {
    if refine_callable_fact(
        target_facts.values,
        input,
        arguments[index].through(FunctionParameter).cross_function(),
      ) {
      changed = true
    }
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
    | TailCallPackedDirect(_, _, _, _)
    | TailCallValue(_, _, _)
    | Fatal
    | Unreachable => []
  }
}

///|
fn collect_aggregate_sites(image : Image) -> Array[AggregateSite] {
  let sites = []
  for function_index, entry in image.functions {
    guard entry is Body(body) else { continue }
    for block in body.blocks {
      for instruction in block.instructions {
        match instruction {
          MakeData(destination, shape, _, witnesses, members)
          | MakeEnv(destination, shape, _, witnesses, members) =>
            sites.push({
              function_index,
              destination,
              shape,
              witnesses: witnesses.map(value => { function_index, value, }),
              members: members.map(value => { function_index, value, }),
            })
          _ => ()
        }
      }
    }
  }
  sites
}

///|
fn known_aggregate(
  analysis : CallableFlowAnalysis,
  function_index : Int,
  destination : ValueId,
) -> CallableFlowFact {
  for site_index, site in analysis.aggregate_sites {
    if site.function_index == function_index && site.destination == destination {
      return KnownAggregates(
        [{ site: { value: site_index, }, locally_available: true, }],
        [],
      )
    }
  }
  Unknown([], [OpaqueOperation])
}

///|
fn aggregate_member_fact(
  analysis : CallableFlowAnalysis,
  fact : CallableFlowFact,
  shape : @physical.ObjectShapeId,
  member_index : Int,
) -> CallableFlowFact {
  match fact {
    KnownAggregates(aggregates, boundaries) => {
      let mut result = Unreached
      let mut exact = !aggregates.is_empty()
      for aggregate in aggregates {
        guard analysis.aggregate_site(aggregate.site) is Some(site) else {
          exact = false
          continue
        }
        if site.shape != shape ||
          member_index < 0 ||
          member_index >= site.members.length() {
          exact = false
          continue
        }
        let reference = site.members[member_index]
        guard analysis.body_facts(reference.function_index) is Some(body) else {
          exact = false
          continue
        }
        let field_fact = body.values[reference.value.value]
          .through(AggregateStorage)
          .cross_function()
        result = merge_callable_facts(result, field_fact)
      }
      if exact {
        result.with_boundaries(boundaries)
      } else {
        Unknown(
          callable_alternatives(result),
          merge_callable_boundaries(
            boundaries,
            merge_callable_boundaries(callable_boundaries(result), [
              AggregateStorage,
            ]),
          ),
        )
      }
    }
    Unreached => Unreached
    fact =>
      Unknown(
        callable_alternatives(fact),
        merge_callable_boundaries(callable_boundaries(fact), [AggregateStorage]),
      )
  }
}

///|
fn known_callable(
  target : @physical.FunctionId,
  environment : CallableEnvironmentFact,
) -> CallableFlowFact {
  KnownCallables([{ target, environment, }], [])
}

///|
fn function_result_fact(
  results : Array[CallableFlowFact],
  target : @physical.FunctionId,
) -> CallableFlowFact {
  let index = target.value - 1
  if index >= 0 && index < results.length() {
    results[index]
  } else {
    Unknown([], [OpaqueOperation])
  }
}

///|
fn callable_result_fact(
  callable : CallableFlowFact,
  results : Array[CallableFlowFact],
) -> CallableFlowFact {
  match callable {
    Unreached => Unreached
    KnownCallables(alternatives, _) =>
      alternatives.fold(init=Unreached, fn(result, alternative) {
        merge_callable_facts(
          result,
          function_result_fact(results, alternative.target),
        )
      })
    Unknown(alternatives, boundaries) => {
      let result = alternatives.fold(init=Unreached, fn(result, alternative) {
        merge_callable_facts(
          result,
          function_result_fact(results, alternative.target),
        )
      })
      Unknown(
        callable_alternatives(result),
        merge_callable_boundaries(boundaries, callable_boundaries(result)),
      )
    }
    KnownAggregates(_, _) =>
      Unknown(callable_alternatives(callable), callable_boundaries(callable))
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
    (Unknown(left, left_boundaries), fact)
    | (fact, Unknown(left, left_boundaries)) =>
      Unknown(
        merge_callable_alternatives(left, callable_alternatives(fact)),
        merge_callable_boundaries(left_boundaries, callable_boundaries(fact)),
      )
    (
      KnownCallables(left, left_boundaries),
      KnownCallables(right, right_boundaries),
    ) =>
      KnownCallables(
        merge_callable_alternatives(left, right),
        merge_callable_boundaries(left_boundaries, right_boundaries),
      )
    (
      KnownAggregates(left, left_boundaries),
      KnownAggregates(right, right_boundaries),
    ) =>
      KnownAggregates(
        merge_aggregate_alternatives(left, right),
        merge_callable_boundaries(left_boundaries, right_boundaries),
      )
    _ =>
      Unknown(
        merge_callable_alternatives(
          callable_alternatives(left),
          callable_alternatives(right),
        ),
        merge_callable_boundaries(
          callable_boundaries(left),
          callable_boundaries(right),
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
          merged[index] = { ..existing, environment: PackedEnvironment, }
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
fn merge_aggregate_alternatives(
  left : Array[AggregateReference],
  right : Array[AggregateReference],
) -> Array[AggregateReference] {
  let merged = left.copy()
  for alternative in right {
    let mut found = false
    for index, existing in merged {
      if existing.site == alternative.site {
        found = true
        merged[index] = {
          ..existing,
          locally_available: existing.locally_available &&
          alternative.locally_available,
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
    KnownCallables(alternatives, _) | Unknown(alternatives, _) => alternatives
    KnownAggregates(_, _) | Unreached => []
  }
}

///|
fn CallableFlowFact::cross_function(
  self : CallableFlowFact,
) -> CallableFlowFact {
  match self {
    KnownCallables(alternatives, boundaries) =>
      KnownCallables(
        alternatives.map(alternative => {
          match alternative.environment {
            LocalEnvironment(_) =>
              { ..alternative, environment: PackedEnvironment, }
            CaptureFree | PackedEnvironment => alternative
          }
        }),
        boundaries,
      )
    Unknown(alternatives, boundaries) =>
      Unknown(
        alternatives.map(alternative => {
          match alternative.environment {
            LocalEnvironment(_) =>
              { ..alternative, environment: PackedEnvironment, }
            CaptureFree | PackedEnvironment => alternative
          }
        }),
        boundaries,
      )
    Unreached => self
    KnownAggregates(aggregates, boundaries) =>
      KnownAggregates(
        aggregates.map(aggregate => { ..aggregate, locally_available: false, }),
        boundaries,
      )
  }
}

///|
fn CallableFlowFact::through(
  self : CallableFlowFact,
  boundary : CallableFlowBoundary,
) -> CallableFlowFact {
  match self {
    Unreached => Unreached
    Unknown(alternatives, boundaries) =>
      Unknown(alternatives, merge_callable_boundaries(boundaries, [boundary]))
    KnownCallables(alternatives, boundaries) =>
      KnownCallables(
        alternatives,
        merge_callable_boundaries(boundaries, [boundary]),
      )
    KnownAggregates(aggregates, boundaries) =>
      KnownAggregates(
        aggregates,
        merge_callable_boundaries(boundaries, [boundary]),
      )
  }
}

///|
fn CallableFlowFact::with_boundaries(
  self : CallableFlowFact,
  additional : Array[CallableFlowBoundary],
) -> CallableFlowFact {
  additional.fold(init=self, fn(fact, boundary) { fact.through(boundary) })
}

///|
fn callable_boundaries(fact : CallableFlowFact) -> Array[CallableFlowBoundary] {
  match fact {
    Unreached => []
    Unknown(_, boundaries) | KnownCallables(_, boundaries) => boundaries
    KnownAggregates(_, boundaries) => boundaries
  }
}

///|
fn merge_callable_boundaries(
  left : Array[CallableFlowBoundary],
  right : Array[CallableFlowBoundary],
) -> Array[CallableFlowBoundary] {
  let merged = left.copy()
  merge_callable_boundaries_into(merged, right)
  merged
}

///|
fn merge_callable_boundaries_into(
  destination : Array[CallableFlowBoundary],
  source : Array[CallableFlowBoundary],
) -> Unit {
  for boundary in source {
    if !destination.contains(boundary) {
      destination.push(boundary)
    }
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
fn CallableFlowAnalysis::aggregate_site(
  self : CallableFlowAnalysis,
  site : AggregateSiteId,
) -> AggregateSite? {
  if site.value >= 0 && site.value < self.aggregate_sites.length() {
    Some(self.aggregate_sites[site.value])
  } else {
    None
  }
}

///|
fn observe_indirect_calls(image : Image) -> Array[IndirectCallObservation] {
  let flow = analyze_callable_flow(image)
  let observations = []
  for function_index, entry in image.functions {
    guard entry is Body(body) && flow.body_facts(function_index) is Some(facts) else {
      continue
    }
    let mut ordinal = 0
    for block in body.blocks {
      for instruction in block.instructions {
        if instruction is CallValue(callable, witnesses, arguments, destination) {
          let callable = complete_callable_at_callsite(
            image,
            flow,
            body,
            facts.values[callable.value],
            witnesses,
            arguments,
            match destination {
              Some(value) => value_result_abi(body.values[value.value])
              None => Unit
            },
          )
          observations.push({
            function: { value: function_index + 1, },
            ordinal,
            resolution: indirect_call_resolution(callable),
            boundaries: observed_callable_boundaries(callable),
          })
          ordinal += 1
        }
      }
      if block.terminator is TailCallValue(callable, witnesses, arguments) {
        let callable = complete_callable_at_callsite(
          image,
          flow,
          body,
          facts.values[callable.value],
          witnesses,
          arguments,
          body.result,
        )
        observations.push({
          function: { value: function_index + 1, },
          ordinal,
          resolution: indirect_call_resolution(callable),
          boundaries: observed_callable_boundaries(callable),
        })
        ordinal += 1
      }
    }
  }
  observations
}

///|
fn observed_callable_boundaries(
  fact : CallableFlowFact,
) -> Array[CallableFlowBoundary] {
  match fact {
    Unreached | Unknown(_, []) => [OpaqueInput]
    _ => callable_boundaries(fact)
  }
}

///|
fn indirect_call_resolution(fact : CallableFlowFact) -> IndirectCallResolution {
  let alternatives = callable_alternatives(fact)
  let targets = alternatives.map(alternative => alternative.target)
  targets.sort_by((left, right) => left.value - right.value)
  match fact {
    KnownCallables([alternative], _) =>
      ExactTarget(
        alternative.target,
        match alternative.environment {
          CaptureFree => CaptureFree
          LocalEnvironment(_) => Local
          PackedEnvironment => Packed
        },
      )
    KnownCallables(_, _) if targets.length() > 1 => MultipleTargets(targets)
    Unknown(_, _) | KnownAggregates(_, _) | Unreached => UnknownTargets(targets)
    KnownCallables(_, _) => UnknownTargets(targets)
  }
}

///|
