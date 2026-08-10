///|
fn @syntax.EffectTerm::resolve_effect_term(
  self : @syntax.EffectTerm,
  resolver : Resolver,
  scope : ResolveScope,
) -> ResolvedEffectTerm {
  match self {
    Empty(loc~) => Empty(loc~)
    Term(type_~, ..) => type_.resolve_effect_type(resolver, scope, type_.loc())
    Union(items~, loc~) =>
      Union(
        items=items.map(fn(item) {
          item.resolve_effect_type(resolver, scope, item.loc())
        }),
        loc~,
      )
  }
}

///|
fn @syntax.Type::resolve_effect_type(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
  loc : SourceSpan,
) -> ResolvedEffectTerm {
  let (base, arguments) = self.effect_type_parts()
  match base {
    Name(name="Io", ..) =>
      Io(
        arguments=resolve_default_generic_arguments(arguments, resolver, scope),
        loc~,
      )
    Name(name="Panic", ..) =>
      Panic(
        arguments=resolve_default_generic_arguments(arguments, resolver, scope),
        loc~,
      )
    Name(name~, ..) =>
      match scope.type_parameter_info(name) {
        Some(parameter) =>
          Parameter(symbol=parameter.symbol, name=parameter.name, loc~)
        None =>
          match resolver.effect_binding(name) {
            Some(binding) => {
              resolver.record_import_use(binding.import_origin, loc)
              let resolved_arguments = resolve_generic_arguments(
                arguments,
                binding.parameter_kinds,
                resolver,
                scope,
              )
              Singleton(
                symbol=binding.symbol,
                name=Unqualified(name),
                arguments=resolved_arguments,
                loc~,
              )
            }
            None =>
              match resolver.type_alias_binding(name) {
                Some(binding) => {
                  resolver.record_import_use(binding.import_origin, loc)
                  let resolved_arguments = resolve_effect_alias_arguments(
                    arguments,
                    binding.parameter_kinds,
                    resolver,
                    scope,
                  )
                  Alias(
                    symbol=binding.symbol,
                    owner_module_path=binding.owner_module_path,
                    name=Unqualified(name),
                    arguments=resolved_arguments,
                    loc~,
                  )
                }
                None => {
                  let resolved_arguments = arguments.map(fn(argument) {
                    argument.resolve_default_generic_argument(resolver, scope)
                  })
                  resolver.report(UnresolvedType(name), loc)
                  Unresolved(name~, arguments=resolved_arguments, loc~)
                }
              }
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      resolver.resolve_module_qualified_effect_type(
        module_path, name, arguments, scope, loc,
      )
    _ => {
      let resolved = self.resolve_type(resolver, scope)
      Unresolved(
        name=@prettyprinter.render(resolved.pretty(), width=100),
        arguments=[],
        loc~,
      )
    }
  }
}

///|
fn @syntax.Type::effect_type_parts(
  self : @syntax.Type,
) -> (@syntax.Type, Array[@syntax.GenericArgument]) {
  match self {
    Apply(callee~, arguments~, ..) => (callee, arguments)
    Grouped(type_~, ..) => type_.effect_type_parts()
    _ => (self, [])
  }
}

///|
fn Resolver::resolve_module_qualified_effect_type(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
  arguments : Array[@syntax.GenericArgument],
  scope : ResolveScope,
  loc : SourceSpan,
) -> ResolvedEffectTerm {
  let resolved_name = ResolvedNominalName::Qualified({
    module_binding: @module_interface.module_path_text(module_path),
    name,
  })
  let full_name = resolved_name.display_text()
  guard self.resolve_authored_module_namespace(
      @module_interface.module_path_text(module_path),
      module_path.loc,
    )
    is Some(source) else {
    let arguments = resolve_default_generic_arguments(arguments, self, scope)
    self.report(UnresolvedType(full_name), loc)
    return Unresolved(name=full_name, arguments~, loc~)
  }
  match source.type_binding(name) {
    Some(binding) => {
      self.record_import_uses(binding.import_origins, loc)
      match binding.kind {
        EffectType(symbol) => {
          let arguments = resolve_generic_arguments(
            arguments,
            binding.parameter_kinds,
            self,
            scope,
          )
          return Singleton(symbol~, name=resolved_name, arguments~, loc~)
        }
        TypeAlias(symbol~, is_effect=true) => {
          let arguments = resolve_effect_alias_arguments(
            arguments,
            binding.parameter_kinds,
            self,
            scope,
          )
          return Alias(
            symbol~,
            owner_module_path=Some(binding.owner_module_path),
            name=resolved_name,
            arguments~,
            loc~,
          )
        }
        NominalType(_) | TypeAlias(is_effect=false, ..) => ()
      }
    }
    None => ()
  }
  let arguments = resolve_default_generic_arguments(arguments, self, scope)
  self.report(UnresolvedType(full_name), loc)
  Unresolved(name=full_name, arguments~, loc~)
}

///|
fn resolve_effect_alias_arguments(
  arguments : Array[@syntax.GenericArgument],
  parameter_kinds : Array[@types.Kind],
  resolver : Resolver,
  scope : ResolveScope,
) -> Array[ResolvedEffectAliasArgument] {
  arguments.mapi(fn(index, argument) {
    match argument {
      EffectTerm(effect) =>
        EffectArgument(effect.resolve_effect_term(resolver, scope))
      TypeTerm(type_) =>
        if index < parameter_kinds.length() &&
          parameter_kinds[index] == Effect &&
          type_.should_resolve_as_effect_alias_argument(resolver, scope) {
          EffectArgument(
            type_.resolve_effect_type(resolver, scope, type_.loc()),
          )
        } else {
          TypeArgument(type_.resolve_type(resolver, scope))
        }
    }
  })
}

///|
fn @syntax.Type::should_resolve_as_effect_alias_argument(
  self : @syntax.Type,
  resolver : Resolver,
  scope : ResolveScope,
) -> Bool {
  let (base, _) = self.effect_type_parts()
  match base {
    Name(name~, ..) =>
      match scope.type_parameter_info(name) {
        Some(parameter) =>
          match parameter.kind {
            Some(Effect(_)) => true
            _ => false
          }
        None =>
          if resolver.effect_symbol_opt(name) is Some(_) {
            true
          } else {
            match resolver.type_alias_binding(name) {
              Some(binding) => binding.is_effect
              None => false
            }
          }
      }
    QualifiedName(module_path~, name~, ..) =>
      resolver.module_qualified_name_can_be_effect_alias_argument(
        module_path, name,
      )
    _ => false
  }
}

///|
fn Resolver::module_qualified_name_can_be_effect_alias_argument(
  self : Resolver,
  module_path : @syntax.ModulePath,
  name : String,
) -> Bool {
  match
    self.module_type_binding(
      @module_interface.module_path_text(module_path),
      name,
    ) {
    Some({ kind: EffectType(_) | TypeAlias(is_effect=true, ..), .. }) => true
    _ => false
  }
}
