///|
fn @syntax.Type::resolve_type_application_arguments(
  self : @syntax.Type,
  _resolved_callee : ResolvedType,
  arguments : Array[@syntax.GenericArgument],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  match self {
    Name(name~, ..) =>
      match resolver.type_binding(name) {
        Some(binding) =>
          resolve_generic_arguments(
            arguments,
            binding.parameter_kinds,
            resolver,
            scope,
          )
        None =>
          match resolver.type_alias_binding(name) {
            Some(binding) =>
              resolve_generic_arguments(
                arguments,
                binding.parameter_kinds,
                resolver,
                scope,
              )
            None =>
              resolve_default_generic_arguments(arguments, resolver, scope)
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      match
        resolver.module_type_binding(
          @module_interface.module_path_text(module_path),
          name,
        ) {
        Some(binding) =>
          resolve_generic_arguments(
            arguments,
            binding.parameter_kinds,
            resolver,
            scope,
          )
        None => resolve_default_generic_arguments(arguments, resolver, scope)
      }
    _ => resolve_default_generic_arguments(arguments, resolver, scope)
  }
}

///|
fn resolve_default_generic_arguments(
  arguments : Array[@syntax.GenericArgument],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  arguments.map(fn(argument) {
    argument.resolve_default_generic_argument(resolver, scope)
  })
}

///|
fn resolve_generic_arguments(
  arguments : Array[@syntax.GenericArgument],
  parameter_kinds : Array[@types.Kind],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  arguments.mapi(fn(index, argument) {
    if index < parameter_kinds.length() {
      argument.resolve_generic_argument_with_kind(
        parameter_kinds[index],
        resolver,
        scope,
      )
    } else {
      argument.resolve_default_generic_argument(resolver, scope)
    }
  })
}

///|
fn resolve_type_name_arguments(
  type_name : String,
  arguments : Array[@syntax.GenericArgument],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedGenericArgument] {
  match resolver.type_binding(type_name) {
    Some(binding) => {
      resolver.record_import_use(
        binding.import_origin,
        @basic.SourceSpan::dummy(),
      )
      resolve_generic_arguments(
        arguments,
        binding.parameter_kinds,
        resolver,
        scope,
      )
    }
    None =>
      match resolver.type_alias_binding(type_name) {
        Some(binding) => {
          resolver.record_import_use(
            binding.import_origin,
            @basic.SourceSpan::dummy(),
          )
          resolve_generic_arguments(
            arguments,
            binding.parameter_kinds,
            resolver,
            scope,
          )
        }
        None =>
          match split_qualified_name(type_name) {
            Some(qualified) =>
              match
                resolver.module_type_binding(
                  qualified.module_path,
                  qualified.name,
                ) {
                Some(binding) =>
                  resolve_generic_arguments(
                    arguments,
                    binding.parameter_kinds,
                    resolver,
                    scope,
                  )
                None =>
                  resolve_default_generic_arguments(arguments, resolver, scope)
              }
            None =>
              resolve_default_generic_arguments(arguments, resolver, scope)
          }
      }
  }
}

///|
priv struct ResolvedOwnerArguments {
  type_name : String
  arguments : Array[ResolvedGenericArgument]
}

///|
fn owner_type_name(owner : @syntax.Type) -> String {
  match owner {
    Name(name~, ..) => name
    QualifiedName(module_path~, name~, ..) =>
      module_path.components.join(".") + "." + name
    _ => abort("expected nominal owner type")
  }
}

///|
fn resolve_owner_generic_arguments(
  owner : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedOwnerArguments {
  match owner {
    Apply(callee~, arguments~, ..) => {
      let type_name = owner_type_name(callee)
      {
        type_name,
        arguments: resolve_type_name_arguments(
          type_name, arguments, resolver, scope,
        ),
      }
    }
    _ => {
      let type_name = owner_type_name(owner)
      { type_name, arguments: [] }
    }
  }
}

///|
fn split_qualified_name(type_name : String) -> QualifiedNameText? {
  let parts = type_name.split(".").map(StringView::to_owned).collect()
  if parts.length() < 2 {
    return None
  }
  let module_parts = []
  for index in 0..<(parts.length() - 1) {
    module_parts.push(parts[index])
  }
  Some({ module_path: module_parts.join("."), name: parts[parts.length() - 1] })
}

///|
fn @syntax.GenericArgument::resolve_generic_argument(
  self : @syntax.GenericArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedGenericArgument {
  match self {
    TypeTerm(type_) =>
      if type_.should_resolve_as_effect_alias_argument(resolver, scope) {
        EffectArgument(type_.resolve_effect_type(resolver, scope, type_.loc()))
      } else {
        TypeArgument(type_.resolve_type(resolver, scope))
      }
    EffectTerm(effect) =>
      EffectArgument(effect.resolve_effect_term(resolver, scope))
  }
}

///|
fn @syntax.GenericArgument::resolve_default_generic_argument(
  self : @syntax.GenericArgument,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedGenericArgument {
  match self {
    TypeTerm(type_) => TypeArgument(type_.resolve_type(resolver, scope))
    EffectTerm(effect) =>
      EffectArgument(effect.resolve_effect_term(resolver, scope))
  }
}

///|
fn @syntax.GenericArgument::resolve_generic_argument_with_kind(
  self : @syntax.GenericArgument,
  kind : @types.Kind,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedGenericArgument {
  match (self, kind) {
    (EffectTerm(effect), _) =>
      EffectArgument(effect.resolve_effect_term(resolver, scope))
    (TypeTerm(type_), Effect) =>
      EffectArgument(type_.resolve_effect_type(resolver, scope, type_.loc()))
    (TypeTerm(type_), _) => TypeArgument(type_.resolve_type(resolver, scope))
  }
}
