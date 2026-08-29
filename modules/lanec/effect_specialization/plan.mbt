///|
/// Immutable source-demand planning for effect specialization.
pub(all) enum SpecializationDefinitionSite {
  TopLevel(@buslane.ValueId)
  Local(owner~ : @buslane.ValueId, value~ : @buslane.ValueId)
} derive(Debug, Eq)

///|
fn SpecializationDefinitionSite::value(
  self : SpecializationDefinitionSite,
) -> @buslane.ValueId {
  match self {
    TopLevel(value) | Local(value~, ..) => value
  }
}

///|
priv struct PlannedDefinition {
  site : SpecializationDefinitionSite
  captured_effect_parameters : Array[@buslane.TypeParameterId]
  effect_parameters : Array[@buslane.TypeParameterId]
  rhs : @buslane.Expr
}

///|
priv enum CallableSpecializationDemand {
  RetainGeneric(
    SpecializationDefinitionSite,
    Array[EffectSpecializationBinding]
  )
  Specialize(
    SpecializationDefinitionSite,
    ambient_bindings~ : Array[EffectSpecializationBinding],
    instance_bindings~ : Array[EffectSpecializationBinding]
  )
} derive(Debug, Eq)

///|
priv struct DataInstanceDemand {
  source : @buslane.TypeId
  bindings : Array[EffectSpecializationBinding]
  constructors : Array[@buslane.DataConId]
} derive(Debug, Eq)

///|
priv enum PlannedTopTerm {
  RetainedLet(source_index~ : Int, value~ : @buslane.ValueId)
  RetainedLetRec(source_index~ : Int, values~ : Array[@buslane.ValueId])
  RetainedExternal(source_index~ : Int, value~ : @buslane.ValueId)
} derive(Debug, Eq)

///|
fn PlannedTopTerm::source_index(self : PlannedTopTerm) -> Int {
  match self {
    RetainedLet(source_index~, ..)
    | RetainedLetRec(source_index~, ..)
    | RetainedExternal(source_index~, ..) => source_index
  }
}

///|
priv enum RetainedDeclaration {
  DataConstructor(@buslane.DataConId)
  Operation(@buslane.OperationId)
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct SpecializationPlan {
  callable_demands : Array[CallableSpecializationDemand]
  data_demands : Array[DataInstanceDemand]
  retained_top_terms : Array[PlannedTopTerm]
  retained_declarations : Array[RetainedDeclaration]
} derive(Debug, Eq)

///|
fn SpecializationPlan::add_retained_top_term(
  self : SpecializationPlan,
  term : PlannedTopTerm,
) -> Unit {
  self.retained_top_terms.push(term)
  self.retained_top_terms.sort_by(fn(left, right) {
    left.source_index().compare(right.source_index())
  })
}

///|
fn SpecializationPlan::retains(
  self : SpecializationPlan,
  metadata : @buslane.MetadataRegistry,
  site : SpecializationDefinitionSite,
  ambient_bindings : Array[EffectSpecializationBinding],
) -> Bool raise SpecializationError {
  self.callable_demands.any(demand => {
    match demand {
      RetainGeneric(candidate, candidate_ambient) =>
        candidate == site &&
        specialization_bindings_equal(
          metadata, candidate_ambient, ambient_bindings,
        )
      _ => false
    }
  })
}

///|
priv struct PlannedDefinitionVisit {
  site : SpecializationDefinitionSite
  bindings : Array[EffectSpecializationBinding]
}

///|
priv struct SpecializationPlanner {
  program : @buslane.Program
  definitions : Array[PlannedDefinition]
  visits : Array[PlannedDefinitionVisit]
  plan : SpecializationPlan
}

///|
#warnings("-unused_value")
fn plan_effect_specializations(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> SpecializationPlan raise SpecializationError {
  let definitions = collect_plannable_definitions(program)
  plan_effect_specializations_with_definitions(program, entry, definitions)
}

///|
fn plan_effect_specializations_with_definitions(
  program : @buslane.Program,
  entry : @buslane.ValueId,
  definitions : Array[PlannedDefinition],
) -> SpecializationPlan raise SpecializationError {
  let planner = SpecializationPlanner::{
    program,
    definitions,
    visits: [],
    plan: {
      callable_demands: [],
      data_demands: [],
      retained_top_terms: [],
      retained_declarations: [],
    },
  }
  guard planner.find_definition(entry) is Some(entry_definition) else {
    if planner.retain_top_value(entry) {
      planner.visit_value_type(entry, [])
    }
    return planner.plan
  }
  if entry_definition.effect_parameters.is_empty() {
    ignore(planner.retain_top_value(entry))
  }
  planner.enqueue_visit(entry_definition.site, [])
  let mut index = 0
  while index < planner.visits.length() {
    let visit = planner.visits[index]
    guard planner.find_definition(visit.site.value()) is Some(definition) else {
      raise PlannerInvariant(
        specialization_error_context(
          "a queued specialization visit has no planned definition",
          site=visit.site,
          source=Value(visit.site.value()),
          specialization_key=visit.bindings,
        ),
      )
    }
    try {
      planner.visit_value_type(definition.site.value(), visit.bindings)
      planner.visit_expr(definition.rhs, visit.bindings)
    } catch {
      error =>
        raise contextualize_planner_error(
          error,
          definition.site,
          visit.bindings,
        )
    }
    index += 1
  }
  planner.plan
}

///|
fn SpecializationPlanner::retain_top_value(
  self : SpecializationPlanner,
  id : @buslane.ValueId,
) -> Bool raise SpecializationError {
  for source_index, source_term in self.program.terms {
    match source_term {
      Let(source, _) if source == id => {
        if self.plan.retained_top_terms.any(planned => {
            planned.source_index() == source_index
          }) {
          return false
        }
        self.plan.add_retained_top_term(RetainedLet(source_index~, value=id))
        return true
      }
      External(source) if source == id => {
        if self.plan.retained_top_terms.any(planned => {
            planned.source_index() == source_index
          }) {
          return false
        }
        self.plan.add_retained_top_term(
          RetainedExternal(source_index~, value=id),
        )
        return true
      }
      LetRec(source_bindings) => {
        guard source_bindings.any(binding => binding.id == id) else { continue }
        for planned_index, planned in self.plan.retained_top_terms {
          guard planned.source_index() == source_index else { continue }
          guard planned is RetainedLetRec(values=retained_values, ..) else {
            raise PlannerInvariant(
              specialization_error_context(
                "one source top-level term has conflicting retention plans",
                source=Value(id),
              ),
            )
          }
          if retained_values.contains(id) {
            return false
          }
          let retained_ids = retained_values.copy()
          retained_ids.push(id)
          self.plan.retained_top_terms[planned_index] = RetainedLetRec(
            source_index~,
            values=source_bindings
              .filter(binding => retained_ids.contains(binding.id))
              .map(binding => binding.id),
          )
          return true
        }
        self.plan.add_retained_top_term(
          RetainedLetRec(source_index~, values=[id]),
        )
        return true
      }
      _ => ()
    }
  }
  false
}

///|
fn collect_plannable_definitions(
  program : @buslane.Program,
) -> Array[PlannedDefinition] {
  let definitions = []
  for term in program.terms {
    match term {
      Let(id, rhs) => {
        let definition = planned_definition(
          program.metadata,
          TopLevel(id),
          [],
          rhs,
        )
        definitions.push(definition)
        collect_nested_definitions(
          program.metadata,
          rhs,
          id,
          definition.effect_parameters,
          definitions,
        )
      }
      LetRec(bindings) =>
        for binding in bindings {
          let definition = planned_definition(
            program.metadata,
            TopLevel(binding.id),
            [],
            binding.rhs,
          )
          definitions.push(definition)
          collect_nested_definitions(
            program.metadata,
            binding.rhs,
            binding.id,
            definition.effect_parameters,
            definitions,
          )
        }
      External(_) => ()
    }
  }
  definitions
}

///|
fn planned_definition(
  metadata : @buslane.MetadataRegistry,
  site : SpecializationDefinitionSite,
  captured_effect_parameters : Array[@buslane.TypeParameterId],
  rhs : @buslane.Expr,
) -> PlannedDefinition {
  {
    site,
    captured_effect_parameters,
    effect_parameters: match effect_scheme_parameters(metadata, site.value()) {
      Some(parameters) => parameters
      None => []
    },
    rhs,
  }
}

///|
fn collect_nested_definitions(
  metadata : @buslane.MetadataRegistry,
  expression : @buslane.Expr,
  owner : @buslane.ValueId,
  captured_effect_parameters : Array[@buslane.TypeParameterId],
  definitions : Array[PlannedDefinition],
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) =>
      collect_nested_definitions(
        metadata,
        function.body,
        owner,
        captured_effect_parameters,
        definitions,
      )
    Call(callee, arguments) => {
      collect_nested_definitions(
        metadata, callee, owner, captured_effect_parameters, definitions,
      )
      for argument in arguments {
        collect_nested_definitions(
          metadata, argument, owner, captured_effect_parameters, definitions,
        )
      }
    }
    TypeLambda(_, body) =>
      collect_nested_definitions(
        metadata, body, owner, captured_effect_parameters, definitions,
      )
    TypeApply(callee, _) =>
      collect_nested_definitions(
        metadata, callee, owner, captured_effect_parameters, definitions,
      )
    Construct(construct) =>
      for payload in construct.payloads {
        collect_nested_definitions(
          metadata, payload, owner, captured_effect_parameters, definitions,
        )
      }
    Let(id, initializer, body) => {
      let site = SpecializationDefinitionSite::Local(owner~, value=id)
      let definition = planned_definition(
        metadata, site, captured_effect_parameters, initializer,
      )
      definitions.push(definition)
      let nested_effect_parameters = captured_effect_parameters.copy()
      nested_effect_parameters.append(definition.effect_parameters)
      collect_nested_definitions(
        metadata, initializer, id, nested_effect_parameters, definitions,
      )
      collect_nested_definitions(
        metadata, body, owner, captured_effect_parameters, definitions,
      )
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        let site = SpecializationDefinitionSite::Local(owner~, value=binding.id)
        let definition = planned_definition(
          metadata,
          site,
          captured_effect_parameters,
          binding.rhs,
        )
        definitions.push(definition)
        let nested_effect_parameters = captured_effect_parameters.copy()
        nested_effect_parameters.append(definition.effect_parameters)
        collect_nested_definitions(
          metadata,
          binding.rhs,
          binding.id,
          nested_effect_parameters,
          definitions,
        )
      }
      collect_nested_definitions(
        metadata, body, owner, captured_effect_parameters, definitions,
      )
    }
    Match(match_) => {
      collect_nested_definitions(
        metadata,
        match_.scrutinee,
        owner,
        captured_effect_parameters,
        definitions,
      )
      for alternative in match_.alternatives {
        collect_nested_definitions(
          metadata,
          alternative.body,
          owner,
          captured_effect_parameters,
          definitions,
        )
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        collect_nested_definitions(
          metadata, payload, owner, captured_effect_parameters, definitions,
        )
      }
    Handle(handle) => {
      collect_nested_definitions(
        metadata,
        handle.body,
        owner,
        captured_effect_parameters,
        definitions,
      )
      collect_nested_definitions(
        metadata,
        handle.final_body,
        owner,
        captured_effect_parameters,
        definitions,
      )
      for table in handle.handlers {
        for operation in table.operations {
          collect_nested_definitions(
            metadata,
            operation.body,
            owner,
            captured_effect_parameters,
            definitions,
          )
        }
      }
    }
  }
}

///|
fn SpecializationPlanner::find_definition(
  self : SpecializationPlanner,
  id : @buslane.ValueId,
) -> PlannedDefinition? {
  for definition in self.definitions {
    if definition.site.value() == id {
      return Some(definition)
    }
  }
  None
}

///|
fn SpecializationPlanner::enqueue_visit(
  self : SpecializationPlanner,
  site : SpecializationDefinitionSite,
  bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  if self.visits.any(visit => {
      visit.site == site &&
      specialization_bindings_equal(
        self.program.metadata,
        visit.bindings,
        bindings,
      )
    }) {
    return
  }
  self.visits.push({ site, bindings, })
}

///|
fn SpecializationPlanner::add_demand(
  self : SpecializationPlanner,
  demand : CallableSpecializationDemand,
) -> Unit raise SpecializationError {
  if self.plan.callable_demands.any(existing => {
      callable_demands_equal(self.program.metadata, existing, demand)
    }) {
    return
  }
  self.plan.callable_demands.push(demand)
}

///|
fn SpecializationPlanner::add_data_demand(
  self : SpecializationPlanner,
  demand : DataInstanceDemand,
) -> Bool raise SpecializationError {
  for existing in self.plan.data_demands {
    if existing.source == demand.source &&
      specialization_bindings_equal(
        self.program.metadata,
        existing.bindings,
        demand.bindings,
      ) {
      if existing.constructors != demand.constructors {
        raise PlannerInvariant(
          specialization_error_context(
            "one data specialization key resolved to different constructor families",
            source=Type(demand.source),
            specialization_key=demand.bindings,
          ),
        )
      }
      return false
    }
  }
  self.plan.data_demands.push(demand)
  true
}

///|
fn SpecializationPlanner::add_retained_declaration(
  self : SpecializationPlanner,
  declaration : RetainedDeclaration,
) -> Bool {
  if self.plan.retained_declarations.contains(declaration) {
    false
  } else {
    self.plan.retained_declarations.push(declaration)
    true
  }
}

///|
fn SpecializationPlanner::retain_data_constructor(
  self : SpecializationPlanner,
  data_constructor : @buslane.DataConId,
) -> Unit raise SpecializationError {
  guard self.program.metadata.data_constructor_info(data_constructor)
    is Some(info) &&
    self.program.metadata.type_info(info.owner) is Some(owner) else {
    raise InvalidInputMetadata(
      specialization_error_context(
        "a reachable data constructor is missing metadata",
        source=DataConstructor(data_constructor),
      ),
    )
  }
  if owner.parameters.any(parameter => {
      type_parameter_is_effect(self.program.metadata, parameter)
    }) {
    return
  }
  if self.add_retained_declaration(DataConstructor(data_constructor)) {
    for payload_type in info.payload_types {
      self.visit_type(payload_type, [])
    }
  }
}

///|
fn SpecializationPlanner::retain_operation(
  self : SpecializationPlanner,
  operation : @buslane.OperationId,
) -> Unit raise SpecializationError {
  guard self.program.metadata.operation_info(operation) is Some(info) &&
    self.program.metadata.effect_info(info.owner) is Some(owner) else {
    raise InvalidInputMetadata(
      specialization_error_context(
        "a reachable operation is missing metadata",
        source=Operation(operation),
      ),
    )
  }
  if owner.parameters.any(parameter => {
      type_parameter_is_effect(self.program.metadata, parameter)
    }) {
    return
  }
  if self.add_retained_declaration(Operation(operation)) {
    for payload_type in info.payload_types {
      self.visit_type(payload_type, [])
    }
    self.visit_type(info.result_type, [])
  }
}

///|
fn callable_demands_equal(
  metadata : @buslane.MetadataRegistry,
  left : CallableSpecializationDemand,
  right : CallableSpecializationDemand,
) -> Bool raise SpecializationError {
  match (left, right) {
    (
      RetainGeneric(left_site, left_ambient),
      RetainGeneric(right_site, right_ambient),
    ) =>
      left_site == right_site &&
      specialization_bindings_equal(metadata, left_ambient, right_ambient)
    (
      Specialize(
        left_site,
        ambient_bindings=left_ambient,
        instance_bindings=left_instance
      ),
      Specialize(
        right_site,
        ambient_bindings=right_ambient,
        instance_bindings=right_instance
      ),
    ) =>
      left_site == right_site &&
      specialization_bindings_equal(metadata, left_ambient, right_ambient) &&
      specialization_bindings_equal(metadata, left_instance, right_instance)
    _ => false
  }
}

///|
fn SpecializationPlanner::record_generic_use(
  self : SpecializationPlanner,
  definition : PlannedDefinition,
  arguments : Array[@buslane.GenericArgument],
  enclosing_bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  let classified = classify_effect_generic_use(
    self.program.metadata,
    definition.effect_parameters,
    arguments,
  )
  let ambient_bindings = enclosing_bindings.filter(binding => {
    definition.captured_effect_parameters.contains(binding.parameter)
  })
  match classified.mode {
    Incomplete | Symbolic => {
      self.add_demand(RetainGeneric(definition.site, ambient_bindings))
      if definition.site is TopLevel(value) {
        ignore(self.retain_top_value(value))
      }
      self.enqueue_visit(definition.site, ambient_bindings)
    }
    Concrete(instance_bindings) => {
      self.add_demand(
        Specialize(definition.site, ambient_bindings~, instance_bindings~),
      )
      let bindings = ambient_bindings.copy()
      bindings.append(instance_bindings)
      self.enqueue_visit(definition.site, bindings)
    }
  }
}

///|
fn SpecializationPlanner::visit_reference(
  self : SpecializationPlanner,
  id : @buslane.ValueId,
  ambient_bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  match self.find_definition(id) {
    Some(definition) =>
      if definition.effect_parameters.is_empty() {
        if definition.site is TopLevel(value) {
          ignore(self.retain_top_value(value))
        }
        self.enqueue_visit(
          definition.site,
          ambient_bindings.filter(binding => {
            definition.captured_effect_parameters.contains(binding.parameter)
          }),
        )
      } else {
        self.record_generic_use(definition, [], ambient_bindings)
      }
    None =>
      if self.retain_top_value(id) {
        self.visit_value_type(id, ambient_bindings)
      }
  }
}

///|
fn SpecializationPlanner::visit_value_type(
  self : SpecializationPlanner,
  value : @buslane.ValueId,
  ambient_bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  guard self.program.metadata.value_info(value) is Some(info) else {
    raise InvalidInputMetadata(
      specialization_error_context(
        "a reachable value is missing metadata",
        source=Value(value),
      ),
    )
  }
  let mut body = info.type_
  while body is Forall(_, next) {
    body = next
  }
  self.visit_type(body, ambient_bindings)
}

///|
fn SpecializationPlanner::visit_argument(
  self : SpecializationPlanner,
  argument : @buslane.GenericArgument,
) -> Unit raise SpecializationError {
  match argument {
    TypeArgument(type_) => self.visit_type(type_, [])
    EffectArgument(effect) => self.visit_effect(effect, [])
  }
}

///|
fn SpecializationPlanner::visit_effect(
  self : SpecializationPlanner,
  effect : @buslane.Effect,
  ambient_bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  let effect = raw_substitute_specialized_effect(effect, ambient_bindings)
  match effect {
    Empty | Builtin(_) | Parameter(_) => ()
    Singleton(id, arguments) => {
      guard self.program.metadata.effect_info(id) is Some(info) else {
        raise InvalidInputMetadata(
          specialization_error_context(
            "a reachable effect is missing metadata",
            source=Effect(id),
          ),
        )
      }
      for operation in info.operations {
        self.retain_operation(operation)
      }
      for argument in arguments {
        self.visit_argument(argument)
      }
    }
    Union(effects) =>
      for effect_term in effects {
        self.visit_effect(effect_term, [])
      }
  }
}

///|
fn SpecializationPlanner::visit_type(
  self : SpecializationPlanner,
  type_ : @buslane.Type,
  ambient_bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  let type_ = normalize_specialization_input_type(
    raw_substitute_specialized_type(type_, ambient_bindings),
  )
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => ()
    Apply(Constructor(source), arguments) => {
      guard self.program.metadata.type_info(source) is Some(info) else {
        for argument in arguments {
          self.visit_argument(argument)
        }
        return
      }
      if info.parameters.any(parameter => {
          type_parameter_is_effect(self.program.metadata, parameter)
        }) {
        self.record_data_application(source, arguments)
      }
      for argument in arguments {
        self.visit_argument(argument)
      }
    }
    Apply(callee, arguments) => {
      self.visit_type(callee, [])
      for argument in arguments {
        self.visit_argument(argument)
      }
    }
    TypeLambda(_, body) | Forall(_, body) => self.visit_type(body, [])
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.visit_type(parameter, [])
      }
      self.visit_type(result, [])
      self.visit_effect(effect, [])
    }
  }
}

///|
fn SpecializationPlanner::record_data_application(
  self : SpecializationPlanner,
  source : @buslane.TypeId,
  arguments : Array[@buslane.GenericArgument],
) -> Unit raise SpecializationError {
  let bindings = data_instance_bindings(
    self.program.metadata,
    source,
    arguments,
  )
  guard self.program.metadata.type_info(source) is Some(info) else {
    raise InvalidInputMetadata(
      specialization_error_context(
        "effect-parameterized data metadata is missing",
        source=Type(source),
      ),
    )
  }
  if self.add_data_demand({
      source,
      bindings,
      constructors: info.constructors.copy(),
    }) {
    for data_constructor in info.constructors {
      guard self.program.metadata.data_constructor_info(data_constructor)
        is Some(constructor_info) else {
        raise InvalidInputMetadata(
          specialization_error_context(
            "an effect-parameterized data constructor is missing metadata",
            source=DataConstructor(data_constructor),
            specialization_key=bindings,
          ),
        )
      }
      for payload_type in constructor_info.payload_types {
        self.visit_type(payload_type, bindings)
      }
    }
  }
}

///|
fn SpecializationPlanner::visit_expr(
  self : SpecializationPlanner,
  expression : @buslane.Expr,
  ambient_bindings : Array[EffectSpecializationBinding],
) -> Unit raise SpecializationError {
  match expression {
    Ref(id) => self.visit_reference(id, ambient_bindings)
    Literal(_) | Resume(_) => ()
    Function(function) => {
      for parameter in function.parameters {
        self.visit_value_type(parameter, ambient_bindings)
      }
      self.visit_type(function.result_type, ambient_bindings)
      self.visit_expr(function.body, ambient_bindings)
    }
    Call(callee, arguments) => {
      self.visit_expr(callee, ambient_bindings)
      for argument in arguments {
        self.visit_expr(argument, ambient_bindings)
      }
    }
    TypeLambda(_, body) => self.visit_expr(body, ambient_bindings)
    TypeApply(_, _) => {
      let groups = []
      let base = collect_type_application_groups(expression, groups)
      let arguments = []
      for group in groups {
        for argument in group {
          arguments.push(
            raw_substitute_specialized_argument(argument, ambient_bindings),
          )
        }
      }
      for argument in arguments {
        self.visit_argument(argument)
      }
      if base is Ref(source) &&
        self.find_definition(source) is Some(definition) &&
        !definition.effect_parameters.is_empty() {
        self.record_generic_use(definition, arguments, ambient_bindings)
      } else {
        self.visit_expr(base, ambient_bindings)
      }
    }
    Construct(construct) => {
      self.retain_data_constructor(construct.data_constructor)
      let arguments = construct.type_arguments.map(argument => {
        raw_substitute_specialized_argument(argument, ambient_bindings)
      })
      if self.program.metadata.data_constructor_info(construct.data_constructor)
        is Some(info) &&
        self.program.metadata.type_info(info.owner) is Some(owner) &&
        owner.parameters.any(parameter => {
          type_parameter_is_effect(self.program.metadata, parameter)
        }) {
        self.record_data_application(info.owner, arguments)
      }
      for argument in arguments {
        self.visit_argument(argument)
      }
      for witness in construct.hidden_witnesses {
        self.visit_argument(
          raw_substitute_specialized_argument(witness, ambient_bindings),
        )
      }
      for payload in construct.payloads {
        self.visit_expr(payload, ambient_bindings)
      }
    }
    Let(id, _, body) => {
      self.visit_value_type(id, ambient_bindings)
      if self.find_definition(id) is Some(definition) &&
        definition.effect_parameters.is_empty() {
        self.enqueue_visit(
          definition.site,
          ambient_bindings.filter(binding => {
            definition.captured_effect_parameters.contains(binding.parameter)
          }),
        )
      }
      self.visit_expr(body, ambient_bindings)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.visit_value_type(binding.id, ambient_bindings)
        if self.find_definition(binding.id) is Some(definition) &&
          definition.effect_parameters.is_empty() {
          self.enqueue_visit(
            definition.site,
            ambient_bindings.filter(binding => {
              definition.captured_effect_parameters.contains(binding.parameter)
            }),
          )
        }
      }
      self.visit_expr(body, ambient_bindings)
    }
    Match(match_) => {
      self.visit_value_type(match_.binder, ambient_bindings)
      self.visit_type(match_.result_type, ambient_bindings)
      self.visit_expr(match_.scrutinee, ambient_bindings)
      for alternative in match_.alternatives {
        if alternative.alt_constructor is DataCon(data_constructor) {
          self.retain_data_constructor(data_constructor)
        }
        for binder in alternative.value_binders {
          self.visit_value_type(binder, ambient_bindings)
        }
        self.visit_expr(alternative.body, ambient_bindings)
      }
    }
    Perform(perform) => {
      self.retain_operation(perform.operation)
      for argument in perform.effect_arguments {
        self.visit_argument(
          raw_substitute_specialized_argument(argument, ambient_bindings),
        )
      }
      for witness in perform.hidden_witnesses {
        self.visit_argument(
          raw_substitute_specialized_argument(witness, ambient_bindings),
        )
      }
      for payload in perform.payloads {
        self.visit_expr(payload, ambient_bindings)
      }
    }
    Handle(handle) => {
      self.visit_value_type(handle.result_binder, ambient_bindings)
      self.visit_type(handle.result_type, ambient_bindings)
      self.visit_expr(handle.body, ambient_bindings)
      self.visit_expr(handle.final_body, ambient_bindings)
      for table in handle.handlers {
        self.visit_effect(table.handled_effect, ambient_bindings)
        for operation in table.operations {
          self.retain_operation(operation.operation)
          for binder in operation.payload_binders {
            self.visit_value_type(binder, ambient_bindings)
          }
          self.visit_value_type(operation.resume_binder, ambient_bindings)
          self.visit_expr(operation.body, ambient_bindings)
        }
      }
    }
  }
}
