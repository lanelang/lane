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
  { owner, type_bindings, value_bindings: [], local_definition_groups: [], }
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
  self.value_bindings.push({ source, target, })
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
  plan : SpecializationPlan
}

///|
pub fn specialize(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> @buslane.Program raise SpecializationError {
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
    plan,
  }
  if specializer.find_definition(entry) is Some(_) {
    raise UnsupportedProgram(
      specialization_error_context(
        "an executable entry cannot retain effect parameters",
        site=TopLevel(entry),
        source=Value(entry),
      ),
    )
  }
  specializer.allocate_data_instances()
  specializer.allocate_callable_instances()
  let terms : Array[@buslane.TopTerm] = []
  for planned in specializer.plan.retained_top_terms {
    guard program.terms.get(planned.source_index()) is Some(source_term) else {
      raise RewriterInvariant(
        specialization_error_context(
          "a retained top-level term is missing from the source program",
        ),
      )
    }
    match (planned, source_term) {
      (RetainedLet(value=id, ..), Let(source, rhs)) if source == id => {
        let rewritten = specializer.rewrite_expr(
          rhs,
          specializer.root_scope(id),
        )
        specializer.specialize_retained_value_type(id)
        terms.push(Let(id, rewritten))
      }
      (RetainedLetRec(values=retained_values, ..), LetRec(source_bindings)) => {
        let rewritten : Array[@buslane.RecursiveBinding] = []
        for binding in source_bindings {
          guard retained_values.contains(binding.id) else { continue }
          let rhs = specializer.rewrite_expr(
            binding.rhs,
            specializer.root_scope(binding.id),
          )
          specializer.specialize_retained_value_type(binding.id)
          rewritten.push({ id: binding.id, rhs, })
        }
        if rewritten.length() != retained_values.length() {
          raise RewriterInvariant(
            specialization_error_context(
              "a retained recursive binding is missing from the source program",
            ),
          )
        }
        terms.push(LetRec(rewritten))
      }
      (RetainedExternal(value=id, ..), External(source)) if source == id => {
        specializer.specialize_retained_value_type(id)
        terms.push(External(id))
      }
      _ =>
        raise RewriterInvariant(
          specialization_error_context(
            "a retained top-level term does not match the source program",
          ),
        )
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
      raise RewriterInvariant(
        specialization_error_context(
          "a requested effect specialization has no top-level definition",
          site=instance.site,
          source=Value(instance.site.value()),
          specialization_key=instance.bindings,
        ),
      )
    }
    specialized_bindings.push({
      id: instance.target,
      rhs: specializer.rewrite_specialized_definition(definition, instance),
    })
    index = index + 1
  }
  specializer.specialize_retained_declarations()
  if specialized_bindings.is_empty() {
    return { metadata: program.metadata, terms, }
  }
  // Specialized definitions are function implementations, so binding them as
  // one recursive group installs closures without evaluating anything. They
  // lead the program because a retained value initializer may call one, and
  // top-level bindings are established in order.
  {
    metadata: program.metadata,
    terms: [LetRec(specialized_bindings), ..terms],
  }
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
          definitions.push({ id, parameters, rhs, })
        }
      LetRec(bindings) =>
        for binding in bindings {
          if effect_scheme_parameters(program.metadata, binding.id)
            is Some(parameters) {
            definitions.push({ id: binding.id, parameters, rhs: binding.rhs, })
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
