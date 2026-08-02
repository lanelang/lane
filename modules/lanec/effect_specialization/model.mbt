///|
priv struct EffectSpecializationInstance {
  site : SpecializationDefinitionSite
  ambient_bindings : Array[EffectSpecializationBinding]
  bindings : Array[EffectSpecializationBinding]
  target : @buslane.ValueId
}

///|
priv struct EffectLocalDefinitionGroup {
  owner : @buslane.ValueId
  definitions : Array[EffectGenericDefinition]
}

///|
priv enum EffectGenericDefinitionSite {
  TopLevel(EffectGenericDefinition)
  Local(EffectGenericDefinition, SpecializationDefinitionSite)
}

///|
priv struct EffectValueBinding {
  source : @buslane.ValueId
  target : @buslane.ValueId
}

///|
priv struct EffectRewriteScope {
  owner : @buslane.ValueId
  type_bindings : Array[EffectSpecializationBinding]
  value_bindings : Array[EffectValueBinding]
  local_definition_groups : Array[EffectLocalDefinitionGroup]
}

///|
fn EffectRewriteScope::new(
  owner : @buslane.ValueId,
  type_bindings : Array[EffectSpecializationBinding],
) -> EffectRewriteScope {
  { owner, type_bindings, value_bindings: [], local_definition_groups: [] }
}

///|
fn EffectRewriteScope::enter_scope(
  self : EffectRewriteScope,
) -> EffectRewriteScope {
  {
    owner: self.owner,
    type_bindings: self.type_bindings,
    value_bindings: self.value_bindings.copy(),
    local_definition_groups: self.local_definition_groups.copy(),
  }
}

///|
fn EffectRewriteScope::with_type_bindings(
  self : EffectRewriteScope,
  bindings : Array[EffectSpecializationBinding],
) -> EffectRewriteScope {
  let type_bindings = self.type_bindings.copy()
  type_bindings.append(bindings)
  {
    owner: self.owner,
    type_bindings,
    value_bindings: self.value_bindings.copy(),
    local_definition_groups: self.local_definition_groups.copy(),
  }
}

///|
fn EffectRewriteScope::with_owner(
  self : EffectRewriteScope,
  owner : @buslane.ValueId,
) -> EffectRewriteScope {
  {
    owner,
    type_bindings: self.type_bindings,
    value_bindings: self.value_bindings.copy(),
    local_definition_groups: self.local_definition_groups.copy(),
  }
}

///|
fn EffectRewriteScope::lookup_value(
  self : EffectRewriteScope,
  source : @buslane.ValueId,
) -> @buslane.ValueId? {
  for binding in self.value_bindings.rev_iter() {
    if binding.source == source {
      return Some(binding.target)
    }
  }
  None
}

///|
fn EffectRewriteScope::bind_value(
  self : EffectRewriteScope,
  source : @buslane.ValueId,
  target : @buslane.ValueId,
) -> Unit {
  self.value_bindings.push({ source, target })
}

///|
fn EffectRewriteScope::bind_local_definition_group(
  self : EffectRewriteScope,
  group : EffectLocalDefinitionGroup,
) -> Unit {
  self.local_definition_groups.push(group)
}

///|
fn EffectRewriteScope::find_local_definition(
  self : EffectRewriteScope,
  id : @buslane.ValueId,
) -> (EffectGenericDefinition, SpecializationDefinitionSite)? {
  for group in self.local_definition_groups.rev_iter() {
    for definition in group.definitions {
      if definition.id == id {
        return Some((definition, Local(owner=group.owner, value=definition.id)))
      }
    }
  }
  None
}

///|
priv struct EffectDataConstructorBinding {
  source : @buslane.DataConId
  target : @buslane.DataConId
}

///|
priv struct EffectDataInstance {
  source : @buslane.TypeId
  bindings : Array[EffectSpecializationBinding]
  target : @buslane.TypeId
  constructors : Array[EffectDataConstructorBinding]
}

///|
priv struct EffectSpecializer {
  program : @buslane.Program
  definitions : Array[EffectGenericDefinition]
  planned_definitions : Array[PlannedDefinition]
  instances : Array[EffectSpecializationInstance]
  data_instances : Array[EffectDataInstance]
  occurrence : @occurrence.OccurrenceSummary
  plan : SpecializationPlan
}

///|
pub fn specialize(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> @buslane.Program raise SpecializationError {
  let occurrence = @occurrence.analyze({ program, entry, roots: [] })
  let definitions = collect_effect_generic_definitions(program)
  let planned_definitions = collect_plannable_definitions(program)
  let plan = plan_effect_specializations_with_definitions(
    program, entry, planned_definitions,
  )
  let specializer = EffectSpecializer::{
    program,
    definitions,
    planned_definitions,
    instances: [],
    data_instances: [],
    occurrence,
    plan,
  }
  if specializer.find_definition(entry) is Some(_) {
    raise Unsupported(
      detail="an executable entry cannot retain effect parameters",
    )
  }
  specializer.allocate_data_instances()
  specializer.allocate_callable_instances()
  let terms : Array[@buslane.TopTerm] = []
  for term in program.terms {
    match term {
      Let(id, rhs) =>
        if specializer.is_reachable(id) &&
          (
            specializer.find_definition(id) is None ||
            specializer.plan.retains(program.metadata, TopLevel(id), [])
          ) {
          let rewritten = specializer.rewrite_expr(
            rhs,
            specializer.root_scope(id),
          )
          specializer.specialize_retained_value_type(id)
          terms.push(Let(id, rewritten))
        }
      LetRec(bindings) => {
        let rewritten : Array[@buslane.RecursiveBinding] = []
        for binding in bindings {
          if specializer.is_reachable(binding.id) &&
            (
              specializer.find_definition(binding.id) is None ||
              specializer.plan.retains(program.metadata, TopLevel(binding.id), [])
            ) {
            let rhs = specializer.rewrite_expr(
              binding.rhs,
              specializer.root_scope(binding.id),
            )
            specializer.specialize_retained_value_type(binding.id)
            rewritten.push({ id: binding.id, rhs })
          }
        }
        if !rewritten.is_empty() {
          terms.push(LetRec(rewritten))
        }
      }
      External(id) =>
        if specializer.is_reachable(id) {
          specializer.specialize_retained_value_type(id)
          terms.push(External(id))
        }
    }
  }
  let specialized_bindings : Array[@buslane.RecursiveBinding] = []
  let mut index = 0
  while index < specializer.instances.length() {
    let instance = specializer.instances[index]
    if instance.site is Local(_) {
      index += 1
      continue
    }
    guard specializer.find_definition(instance.site.value()) is Some(definition) else {
      raise Unsupported(
        detail="a requested effect specialization has no top-level definition",
      )
    }
    specialized_bindings.push({
      id: instance.target,
      rhs: specializer.rewrite_specialized_definition(definition, instance),
    })
    index = index + 1
  }
  if !specialized_bindings.is_empty() {
    terms.push(LetRec(specialized_bindings))
  }
  specializer.specialize_retained_declarations()
  { metadata: program.metadata, terms }
}

///|
fn collect_effect_generic_definitions(
  program : @buslane.Program,
) -> Array[EffectGenericDefinition] {
  let definitions = []
  for term in program.terms {
    match term {
      Let(id, rhs) =>
        if effect_scheme_parameters(program.metadata, id) is Some(parameters) {
          definitions.push({ id, parameters, rhs })
        }
      LetRec(bindings) =>
        for binding in bindings {
          if effect_scheme_parameters(program.metadata, binding.id)
            is Some(parameters) {
            definitions.push({ id: binding.id, parameters, rhs: binding.rhs })
          }
        }
      External(_) => ()
    }
  }
  definitions
}

///|
fn effect_scheme_parameters(
  metadata : @buslane.MetadataRegistry,
  id : @buslane.ValueId,
) -> Array[@buslane.TypeParameterId]? {
  guard metadata.value_info(id) is Some(info) else { return None }
  let parameters = collect_forall_parameters(info.type_)
  if parameters.any(parameter => type_parameter_is_effect(metadata, parameter)) {
    Some(parameters)
  } else {
    None
  }
}

///|
fn collect_forall_parameters(
  type_ : @buslane.Type,
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  collect_forall_parameters_into(type_, parameters)
  parameters
}

///|
fn collect_forall_parameters_into(
  type_ : @buslane.Type,
  parameters : Array[@buslane.TypeParameterId],
) -> Unit {
  if type_ is Forall(next, body) {
    parameters.append(next)
    collect_forall_parameters_into(body, parameters)
  }
}

///|
fn type_parameter_is_effect(
  metadata : @buslane.MetadataRegistry,
  parameter : @buslane.TypeParameterId,
) -> Bool {
  match metadata.type_parameter_info(parameter) {
    Some({ kind: Effect, .. }) => true
    _ => false
  }
}

///|
fn EffectSpecializer::find_definition(
  self : EffectSpecializer,
  id : @buslane.ValueId,
) -> EffectGenericDefinition? {
  for definition in self.definitions {
    if definition.id == id {
      return Some(definition)
    }
  }
  None
}

///|
fn EffectLocalDefinitionGroup::find_definition(
  self : EffectLocalDefinitionGroup,
  id : @buslane.ValueId,
) -> EffectGenericDefinition? {
  for definition in self.definitions {
    if definition.id == id {
      return Some(definition)
    }
  }
  None
}

///|
fn EffectSpecializer::resolve_definition(
  self : EffectSpecializer,
  scope : EffectRewriteScope,
  id : @buslane.ValueId,
) -> EffectGenericDefinitionSite? {
  match scope.find_local_definition(id) {
    Some((definition, site)) => Some(Local(definition, site))
    None => self.find_definition(id).map(definition => TopLevel(definition))
  }
}

///|
fn EffectSpecializer::is_reachable(
  self : EffectSpecializer,
  id : @buslane.ValueId,
) -> Bool {
  match self.occurrence.facts.get(id.index) {
    Some(fact) => fact.reachable_from_entry
    None => false
  }
}

///|
