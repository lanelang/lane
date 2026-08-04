///|
fn EffectSpecializer::planned_ambient_bindings(
  self : EffectSpecializer,
  site : SpecializationDefinitionSite,
  bindings : Array[EffectSpecializationBinding],
) -> Array[EffectSpecializationBinding] {
  for definition in self.planned_definitions {
    if definition.site == site {
      return bindings.filter(binding => {
        definition.captured_effect_parameters.contains(binding.parameter)
      })
    }
  }
  []
}

///|
fn EffectSpecializer::root_scope(
  self : EffectSpecializer,
  owner : @buslane.ValueId,
) -> EffectRewriteScope raise SpecializationError {
  let scope = EffectRewriteScope::new(owner, [])
  for definition in self.definitions {
    if self.plan.retains(self.program.metadata, TopLevel(definition.id), []) {
      scope.bind_value(definition.id, definition.id)
    }
  }
  scope
}

///|
fn EffectSpecializer::allocate_callable_instances(
  self : EffectSpecializer,
) -> Unit raise SpecializationError {
  for demand in self.plan.callable_demands {
    guard demand is Specialize(site, ambient_bindings~, instance_bindings~) else {
      continue
    }
    let source = site.value()
    guard self.program.metadata.value_info(source) is Some(info) else {
      raise AllocatorInvariant(
        specialization_error_context(
          "a planned callable specialization is missing source metadata",
          site~,
          source=Value(source),
          specialization_key=instance_bindings,
        ),
      )
    }
    let bindings = ambient_bindings.copy()
    bindings.append(instance_bindings)
    let specialized_type = self.specialize_type_scheme(info.type_, bindings)
    let target = self.program.metadata.define_value(
      "\{info.name.occurrence}%effect",
      info.kind,
      specialized_type,
    ) catch {
      error =>
        raise AllocatorInvariant(
          specialization_error_context(
            "Buslane metadata allocation failed: \{Repr(error)}",
            site~,
            source=Value(source),
            specialization_key=instance_bindings,
          ),
        )
    }
    self.instances.push({
      site,
      ambient_bindings,
      bindings: instance_bindings,
      target,
    })
  }
}

///|
fn EffectSpecializer::planned_instance(
  self : EffectSpecializer,
  site : SpecializationDefinitionSite,
  ambient_bindings : Array[EffectSpecializationBinding],
  bindings : Array[EffectSpecializationBinding],
) -> EffectSpecializationInstance raise SpecializationError {
  for instance in self.instances {
    if instance.site == site &&
      specialization_bindings_equal(
        self.program.metadata,
        instance.ambient_bindings,
        ambient_bindings,
      ) &&
      specialization_bindings_equal(
        self.program.metadata,
        instance.bindings,
        bindings,
      ) {
      return instance
    }
  }
  let specialization_key = ambient_bindings.copy()
  specialization_key.append(bindings)
  raise AllocatorInvariant(
    specialization_error_context(
      "a reachable callable specialization is missing from the immutable plan",
      site~,
      source=Value(site.value()),
      specialization_key~,
    ),
  )
}

///|
fn EffectSpecializer::specialize_type_scheme(
  self : EffectSpecializer,
  type_ : @buslane.Type,
  bindings : Array[EffectSpecializationBinding],
) -> @buslane.Type raise SpecializationError {
  let parameters = collect_forall_parameters(type_)
  let mut body = type_
  while body is Forall(_, next) {
    body = next
  }
  let retained = parameters.filter(parameter => {
    !bindings.any(binding => binding.parameter == parameter)
  })
  let specialized = self.specialize_type(body, bindings)
  if retained.is_empty() {
    specialized
  } else {
    Forall(retained, specialized)
  }
}

///|
/// Rewrites the declarations the pass keeps in place.
///
/// A data constructor or operation whose owner carries no effect parameters is
/// never copied, but its payloads can still name a type that was. Runs after
/// every instance has been requested, so each specialized target already exists.
/// The immutable plan supplies the exact reachable declaration identities;
/// this step never scans unrelated metadata tables.
///
/// Declarations whose owners carry effect parameters are absent from this set:
/// their metadata is copied and specialized by data-instance allocation.
fn EffectSpecializer::specialize_retained_declarations(
  self : EffectSpecializer,
) -> Unit raise SpecializationError {
  for declaration in self.plan.retained_declarations {
    match declaration {
      DataConstructor(data_constructor) => {
        guard self.program.metadata.data_constructor_info(data_constructor)
          is Some(info) else {
          raise RewriterInvariant(
            specialization_error_context(
              "a planned retained data constructor is missing metadata",
              source=DataConstructor(data_constructor),
            ),
          )
        }
        self.program.metadata.data_constructors[data_constructor.index] = {
          ..info,
          payload_types: info.payload_types.map(type_ => {
            self.specialize_type(type_, [])
          }),
        }
      }
      Operation(operation) => {
        guard self.program.metadata.operation_info(operation) is Some(info) else {
          raise RewriterInvariant(
            specialization_error_context(
              "a planned retained operation is missing metadata",
              source=Operation(operation),
            ),
          )
        }
        self.program.metadata.operations[operation.index] = {
          ..info,
          payload_types: info.payload_types.map(type_ => {
            self.specialize_type(type_, [])
          }),
          result_type: self.specialize_type(info.result_type, []),
        }
      }
    }
  }
}

///|
/// Rewrites the declared type of a binding the pass keeps in place.
///
/// A definition that carries no effect parameters of its own is not copied, but
/// its type can still name an effect-generic data type that was. Rewriting only
/// the body would leave the declaration describing the source type while every
/// expression around it builds the specialized one.
fn EffectSpecializer::specialize_retained_value_type(
  self : EffectSpecializer,
  id : @buslane.ValueId,
) -> Unit raise SpecializationError {
  guard self.program.metadata.value_info(id) is Some(info) else {
    raise RewriterInvariant(
      specialization_error_context(
        "a retained definition is missing metadata",
        source=Value(id),
      ),
    )
  }
  let specialized = self.specialize_type(info.type_, [])
  self.program.metadata.values[id.index] = { ..info, type_: specialized }
}

///|
fn EffectSpecializer::fresh_bound_value(
  self : EffectSpecializer,
  source : @buslane.ValueId,
  scope : EffectRewriteScope,
) -> @buslane.ValueId raise SpecializationError {
  guard self.program.metadata.value_info(source) is Some(info) else {
    raise RewriterInvariant(
      specialization_error_context(
        "a specialized local value is missing metadata",
        source=Value(source),
      ),
    )
  }
  let target = self.program.metadata.define_value(
    info.name.occurrence,
    info.kind,
    self.specialize_type(info.type_, scope.type_bindings),
  ) catch {
    error =>
      raise RewriterInvariant(
        specialization_error_context(
          "Buslane metadata allocation failed: \{Repr(error)}",
          source=Value(source),
        ),
      )
  }
  scope.bind_value(source, target)
  target
}

///|
