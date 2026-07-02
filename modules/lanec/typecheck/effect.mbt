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
  match effect {
    Empty(..) => Empty
    Singleton(symbol~, name~, arguments~, loc~) => {
      self.check_effect_arity(symbol, name, arguments.length(), loc)
      Singleton(
        symbol,
        arguments.map(fn(argument) {
          self.expect_kind(argument, Type).type_.normalize()
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
    Union(items~, ..) =>
      effect_union(items.map(fn(item) { self.check_effect(item) }))
    Unresolved(name~, arguments~, loc~) => {
      for argument in arguments {
        ignore(self.synthesize_type(argument))
      }
      self.diagnostics.push({ kind: UnresolvedType(name), loc })
      Empty
    }
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
      kind: TypeArgumentArityMismatch(name~, expected~, actual~),
      loc,
    })
  }
}

///|
fn SemanticChecker::expect_effect(
  self : SemanticChecker,
  expected : @types.Effect,
  actual : @types.Effect,
  loc : SourceSpan,
) -> Unit {
  if !effect_allowed(expected, actual) {
    self.diagnostics.push({ kind: EffectMismatch(expected~, actual~), loc })
  }
}

///|
fn effect_allowed(expected : @types.Effect, actual : @types.Effect) -> Bool {
  let expected = expected.normalize()
  let actual = actual.normalize()
  if effect_is_empty(actual) {
    return true
  }
  if effect_is_empty(expected) {
    return false
  }
  if expected == actual {
    return true
  }
  match (expected, actual) {
    (Union(expected_items), Union(actual_items)) => {
      for item in actual_items {
        if !effect_allowed(Union(expected_items), item) {
          return false
        }
      }
      true
    }
    (Union(expected_items), _) => {
      for item in expected_items {
        if effect_allowed(item, actual) {
          return true
        }
      }
      false
    }
    _ => false
  }
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
