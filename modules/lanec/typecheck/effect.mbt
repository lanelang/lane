///|
fn SemanticChecker::check_effect(
  self : SemanticChecker,
  effect : @resolve.ResolvedEffectTerm,
) -> @types.Effect {
  check_resolved_effect_with_imported_environment(
    self.resolved_source,
    self.imported_environment,
    self.diagnostics,
    effect,
  )
}

///|
fn check_resolved_effect_with_imported_environment(
  source : @resolve.ResolvedSourceFile,
  imported_environment : @module_interface.ImportedEnvironment,
  diagnostics : Array[TypeCheckDiagnostic],
  effect : @resolve.ResolvedEffectTerm,
) -> @types.Effect {
  TypeExpressionChecker::{
    source,
    imported_environment,
    diagnostics,
    expanding: [],
  }.check_effect(effect)
}

///|
fn TypeExpressionChecker::check_effect(
  self : TypeExpressionChecker,
  effect : @resolve.ResolvedEffectTerm,
) -> @types.Effect {
  // Effect checking judgment:
  //
  //   Gamma |- effect => Eff
  //
  // The result is normalized by constructors such as `effect_union` and alias
  // expansion. A type parameter in effect position must have kind `Effect`;
  // this is not value-level capability lookup.
  match effect {
    Empty(..) => Empty
    Singleton(symbol~, name~, arguments~, loc~) => {
      self.check_effect_arity(symbol, name, arguments.length(), loc)
      let parameters = self.effect_type_parameters(symbol)
      Singleton(
        symbol,
        arguments.mapi(fn(index, argument) {
          if index < parameters.length() {
            self.check_generic_argument(parameters[index].kind, argument)
          } else {
            self.check_generic_argument(Type, argument)
          }
        }),
      )
    }
    Parameter(symbol~, loc~, ..) => {
      let kind = match self.find_type_parameter_kind(symbol) {
        Some(kind) => kind
        None => Effect
      }
      if kind != Effect {
        self.diagnostics.push({
          kind: KindMismatch(expected=Effect, actual=kind),
          loc,
        })
      }
      Parameter(symbol)
    }
    Alias(name~, arguments~, loc~) =>
      self.expand_effect_alias(name, arguments, loc)
    Union(items~, ..) =>
      effect_union(items.map(fn(item) { self.check_effect(item) }))
    Unresolved(name~, arguments~, loc~) => {
      for argument in arguments {
        ignore(self.check_generic_argument(Type, argument))
      }
      self.diagnostics.push({ kind: UnresolvedType(name), loc })
      Empty
    }
  }
}

///|
priv struct EffectSubstitutionEntry {
  parameter : TypeParameterId
  replacement : @types.Effect
}

///|
priv struct EffectSubstitution {
  entries : Array[EffectSubstitutionEntry]
}

///|
fn EffectSubstitution::EffectSubstitution() -> EffectSubstitution {
  { entries: [] }
}

///|
fn EffectSubstitution::insert(
  self : EffectSubstitution,
  parameter : TypeParameterId,
  replacement : @types.Effect,
) -> Unit {
  self.entries.push({ parameter, replacement })
}

///|
fn EffectSubstitution::lookup(
  self : EffectSubstitution,
  parameter : TypeParameterId,
  bound : Array[TypeParameterId],
) -> @types.Effect? {
  if bound.contains(parameter) {
    return None
  }
  for entry in self.entries {
    if entry.parameter == parameter {
      return Some(entry.replacement)
    }
  }
  None
}

///|
fn TypeExpressionChecker::expand_effect_alias(
  self : TypeExpressionChecker,
  name : String,
  arguments : Array[@resolve.ResolvedEffectAliasArgument],
  loc : SourceSpan,
) -> @types.Effect {
  // Transparent effect-alias expansion:
  //
  //   type A[P...] : Effect = Body
  //   Gamma |- args_i : kind(P_i)
  //   Gamma |- Body[args/P] => Eff
  //   ----------------------------
  //   Gamma |- A[args] => Eff
  //
  // Effect aliases are not nominal effects. After checking arguments, both type
  // and effect parameters are substituted into the body and normalized.
  if self.expanding.contains(name) {
    self.diagnostics.push({ kind: TypeAliasCycle(name~), loc })
    return Empty
  }
  match self.find_alias(name) {
    Some(type_alias) => {
      let next = {
        source: self.source,
        imported_environment: self.imported_environment,
        diagnostics: self.diagnostics,
        expanding: self.expanding.copy(),
      }
      next.expanding.push(name)
      let checked_parameters = check_type_parameters(
        self.diagnostics,
        type_alias.type_parameters,
      )
      let (type_substitution, effect_substitution, has_error) = self.check_effect_alias_arguments(
        checked_parameters, arguments, name, loc,
      )
      if has_error {
        return Empty
      }
      match type_alias.body {
        EffectBody(effect) => {
          let expanded = next.check_effect(effect).substitute(type_substitution)
          self.normalize_effect_or_empty(
            expanded.substitute_effect_parameters(effect_substitution),
            loc,
            context="effect alias expansion",
          )
        }
        TypeBody(body) => {
          let result = next.synthesize_type(body)
          self.diagnostics.push({
            kind: KindMismatch(expected=Effect, actual=result.kind),
            loc,
          })
          Empty
        }
      }
    }
    None =>
      match self.find_interface_alias(name) {
        Some(type_alias) =>
          match type_alias.body {
            EffectBody(effect) => {
              let (type_substitution, effect_substitution, has_error) = self.check_effect_alias_arguments(
                type_alias.type_parameters,
                arguments,
                name,
                loc,
              )
              if has_error {
                return Empty
              }
              let expanded = effect.substitute(type_substitution)
              self.normalize_effect_or_empty(
                expanded.substitute_effect_parameters(effect_substitution),
                loc,
                context="imported effect alias expansion",
              )
            }
            TypeBody(_) => {
              self.diagnostics.push({
                kind: KindMismatch(expected=Effect, actual=type_alias.kind),
                loc,
              })
              Empty
            }
          }
        None => {
          for argument in arguments {
            self.check_effect_alias_argument(argument)
          }
          self.diagnostics.push({ kind: UnresolvedType(name), loc })
          Empty
        }
      }
  }
}

///|
fn TypeExpressionChecker::check_effect_alias_arguments(
  self : TypeExpressionChecker,
  parameters : Array[@types.TypeParameter],
  arguments : Array[@resolve.ResolvedEffectAliasArgument],
  name : String,
  loc : SourceSpan,
) -> (@types.TypeSubstitution, EffectSubstitution, Bool) {
  let mut has_error = false
  if parameters.length() != arguments.length() {
    self.diagnostics.push({
      kind: GenericArgumentArityMismatch(
        subject=Named(name~),
        expected=parameters.length(),
        actual=arguments.length(),
      ),
      loc,
    })
    has_error = true
  }
  let type_substitution = @types.TypeSubstitution::TypeSubstitution()
  let effect_substitution = EffectSubstitution::EffectSubstitution()
  for index in 0..<arguments.length() {
    if index < parameters.length() {
      if self.check_effect_alias_argument_for_parameter(
          parameters[index],
          arguments[index],
          type_substitution,
          effect_substitution,
        ) {
        has_error = true
      }
    } else {
      self.check_effect_alias_argument(arguments[index])
      has_error = true
    }
  }
  (type_substitution, effect_substitution, has_error)
}

///|
fn TypeExpressionChecker::check_effect_alias_argument_for_parameter(
  self : TypeExpressionChecker,
  parameter : @types.TypeParameter,
  argument : @resolve.ResolvedEffectAliasArgument,
  type_substitution : @types.TypeSubstitution,
  effect_substitution : EffectSubstitution,
) -> Bool {
  // Alias arguments are kind-directed. `Effect` parameters receive checked
  // effect terms, while `Type` and higher-kinded parameters receive checked type
  // terms. Crossing those channels is a kind mismatch, not an implicit coercion.
  match (parameter.kind, argument) {
    (Effect, EffectArgument(effect)) => {
      effect_substitution.insert(parameter.id, self.check_effect(effect))
      false
    }
    (Effect, TypeArgument(type_)) => {
      let result = self.synthesize_type(type_)
      self.diagnostics.push({
        kind: KindMismatch(expected=Effect, actual=result.kind),
        loc: resolved_type_loc(type_),
      })
      true
    }
    (expected, TypeArgument(type_)) => {
      let result = self.synthesize_type(type_)
      let mut has_error = false
      if result.kind != expected {
        self.diagnostics.push({
          kind: KindMismatch(expected~, actual=result.kind),
          loc: resolved_type_loc(type_),
        })
        has_error = true
      }
      type_substitution.insert(
        parameter.id,
        self.normalize_type_or_error(
          result.type_,
          resolved_type_loc(type_),
          context="effect alias type argument",
        ),
      )
      has_error
    }
    (expected, EffectArgument(effect)) => {
      ignore(self.check_effect(effect))
      self.diagnostics.push({
        kind: KindMismatch(expected~, actual=Effect),
        loc: resolved_effect_alias_argument_loc(argument),
      })
      true
    }
  }
}

///|
fn TypeExpressionChecker::check_effect_alias_argument(
  self : TypeExpressionChecker,
  argument : @resolve.ResolvedEffectAliasArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => ignore(self.synthesize_type(type_))
    EffectArgument(effect) => ignore(self.check_effect(effect))
  }
}

///|
fn @types.Effect::substitute_effect_parameters(
  self : @types.Effect,
  substitution : EffectSubstitution,
) -> @types.Effect {
  self.substitute_effect_parameters_with_bound(substitution, [])
}

///|
fn @types.Effect::substitute_effect_parameters_with_bound(
  self : @types.Effect,
  substitution : EffectSubstitution,
  bound : Array[TypeParameterId],
) -> @types.Effect {
  match self {
    Empty => Empty
    Singleton(symbol, arguments) =>
      Singleton(
        symbol,
        arguments.map(fn(argument) {
          argument.substitute_effect_parameters_with_bound(substitution, bound)
        }),
      )
    Parameter(id) =>
      match substitution.lookup(id, bound) {
        Some(replacement) => replacement
        None => self
      }
    Union(effects) =>
      Union(
        effects.map(fn(effect) {
          effect.substitute_effect_parameters_with_bound(substitution, bound)
        }),
      )
  }
}

///|
fn @types.GenericArgument::substitute_effect_parameters_with_bound(
  self : @types.GenericArgument,
  substitution : EffectSubstitution,
  bound : Array[TypeParameterId],
) -> @types.GenericArgument {
  match self {
    TypeArgument(type_) =>
      TypeArgument(
        type_.substitute_effect_parameters_with_bound(substitution, bound),
      )
    EffectArgument(effect) =>
      EffectArgument(
        effect.substitute_effect_parameters_with_bound(substitution, bound),
      )
  }
}

///|
fn @types.Type::substitute_effect_parameters_with_bound(
  self : @types.Type,
  substitution : EffectSubstitution,
  bound : Array[TypeParameterId],
) -> @types.Type {
  match self {
    Error | Primitive(_) | Constructor(_) | Parameter(_) => self
    Apply(callee, arguments) =>
      Apply(
        callee.substitute_effect_parameters_with_bound(substitution, bound),
        arguments.map(fn(argument) {
          argument.substitute_effect_parameters_with_bound(substitution, bound)
        }),
      )
    TypeLambda(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter.id)
      }
      TypeLambda(
        type_parameters,
        body.substitute_effect_parameters_with_bound(substitution, next_bound),
      )
    }
    Function(parameters, result, effect) =>
      Function(
        parameters.map(fn(parameter) {
          parameter.substitute_effect_parameters_with_bound(substitution, bound)
        }),
        result.substitute_effect_parameters_with_bound(substitution, bound),
        effect.substitute_effect_parameters_with_bound(substitution, bound),
      )
    Forall(type_parameters, body) => {
      let next_bound = bound.copy()
      for parameter in type_parameters {
        next_bound.push(parameter.id)
      }
      Forall(
        type_parameters,
        body.substitute_effect_parameters_with_bound(substitution, next_bound),
      )
    }
  }
}

///|
fn resolved_effect_alias_argument_loc(
  argument : @resolve.ResolvedEffectAliasArgument,
) -> SourceSpan {
  match argument {
    TypeArgument(type_) => resolved_type_loc(type_)
    EffectArgument(effect) => resolved_effect_loc(effect)
  }
}

///|
fn resolved_effect_loc(effect : @resolve.ResolvedEffectTerm) -> SourceSpan {
  match effect {
    Empty(loc~) => loc
    Singleton(loc~, ..) => loc
    Parameter(loc~, ..) => loc
    Alias(loc~, ..) => loc
    Union(loc~, ..) => loc
    Unresolved(loc~, ..) => loc
  }
}

///|
fn TypeExpressionChecker::check_effect_arity(
  self : TypeExpressionChecker,
  symbol : EffectSymbolId,
  name : String,
  actual : Int,
  loc : SourceSpan,
) -> Unit {
  let mut expected : Int? = None
  if self.source.symbols.effect_metadata(symbol) is Some(metadata) {
    expected = Some(metadata.arity)
  }
  for module_ in self.imported_environment.modules {
    for effect in module_.effects {
      if effect.symbol == symbol {
        expected = Some(effect.type_parameters.length())
      }
    }
  }
  if expected is Some(expected) && expected != actual {
    self.diagnostics.push({
      kind: GenericArgumentArityMismatch(
        subject=Named(name~),
        expected~,
        actual~,
      ),
      loc,
    })
  }
}

///|
fn TypeExpressionChecker::effect_type_parameters(
  self : TypeExpressionChecker,
  symbol : EffectSymbolId,
) -> Array[@types.TypeParameter] {
  for declaration in self.source.declarations {
    match declaration {
      Effect(declaration) if declaration.symbol == symbol =>
        return check_type_parameters(
          self.diagnostics,
          declaration.type_parameters,
        )
      _ => ()
    }
  }
  for module_ in self.imported_environment.modules {
    for effect in module_.effects {
      if effect.symbol == symbol {
        return effect.type_parameters
      }
    }
  }
  []
}

///|
fn SemanticChecker::expect_effect(
  self : SemanticChecker,
  expected : @types.Effect,
  actual : @types.Effect,
  loc : SourceSpan,
) -> Unit {
  if !self.effect_allowed(expected, actual, loc) {
    self.diagnostics.push({ kind: EffectMismatch(expected~, actual~), loc })
  }
}

///|
fn SemanticChecker::effect_allowed(
  self : SemanticChecker,
  expected : @types.Effect,
  actual : @types.Effect,
  loc : SourceSpan,
) -> Bool {
  self
  .normalize_effect_or_empty(expected, loc, context="expected effect")
  .alpha_equal(
    self.normalize_effect_or_empty(actual, loc, context="actual effect"),
  )
}

///|
fn effect_is_empty(effect : @types.Effect) -> Bool {
  match effect {
    Empty => true
    Union(items) => {
      for item in items {
        if !effect_is_empty(item) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn effect_union(effects : Array[@types.Effect]) -> @types.Effect {
  let items = []
  for effect in effects {
    match effect.normalize() {
      Empty => ()
      Union(nested) =>
        for item in nested {
          if !effect_is_empty(item) {
            items.push(item)
          }
        }
      item => items.push(item)
    }
  }
  match items.length() {
    0 => Empty
    1 => items[0]
    _ => Union(items)
  }
}
