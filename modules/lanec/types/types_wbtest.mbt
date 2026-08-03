///|
test "try normalize reports type fuel exhaustion without aborting" {
  let mut left = Primitive(Unit)
  let mut right = Primitive(Bool)
  for _ in 0..<(NORMALIZATION_DEPTH_LIMIT + 6) {
    left = Function([left], left, Empty)
    right = Function([right], right, Empty)
  }
  try left.try_normalize() catch {
    error => debug_inspect(error, content="TypeNormalizationFuelExhausted")
  } noraise {
    _ => fail("expected type normalization fuel exhaustion")
  }
  try left.equals(right) catch {
    error => debug_inspect(error, content="TypeNormalizationFuelExhausted")
  } noraise {
    _ => fail("type equality must propagate normalization failure")
  }
}

///|
test "decompose nominal propagates type computation failure" {
  let mut type_ = Primitive(Unit)
  for _ in 0..<NORMALIZATION_DEPTH_LIMIT {
    type_ = Forall([], type_)
  }
  try type_.decompose_nominal() catch {
    error => debug_inspect(error, content="TypeNormalizationFuelExhausted")
  } noraise {
    _ => fail("nominal decomposition must propagate normalization failure")
  }
}

///|
test "try normalize reports effect fuel exhaustion without aborting" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let console = registry.define_effect("Console", 0, @basic.SourceSpan::dummy())
  let other = registry.define_effect("Other", 0, @basic.SourceSpan::dummy())
  let mut left = Singleton(console, [])
  let mut right = Singleton(other, [])
  for _ in 0..<(NORMALIZATION_DEPTH_LIMIT + 6) {
    left = Union([left])
    right = Union([right])
  }
  try left.try_normalize() catch {
    error => debug_inspect(error, content="EffectNormalizationFuelExhausted")
  } noraise {
    _ => fail("expected effect normalization fuel exhaustion")
  }
  try left.equals(right) catch {
    error => debug_inspect(error, content="EffectNormalizationFuelExhausted")
  } noraise {
    _ => fail("effect equality must propagate normalization failure")
  }
}

///|
test "normalization depth limit has an exact boundary" {
  let mut shallow_type = Primitive(Unit)
  let mut deep_type = Primitive(Unit)
  let mut shallow_effect = Effect::Empty
  let mut deep_effect = Effect::Empty
  for _ in 0..<(NORMALIZATION_DEPTH_LIMIT - 1) {
    shallow_type = Forall([], shallow_type)
    shallow_effect = Union([shallow_effect])
  }
  for _ in 0..<NORMALIZATION_DEPTH_LIMIT {
    deep_type = Forall([], deep_type)
    deep_effect = Union([deep_effect])
  }
  let shallow_type_error = try shallow_type.try_normalize() catch {
    error => Some(error)
  } noraise {
    _ => None
  }
  let deep_type_error = try deep_type.try_normalize() catch {
    error => Some(error)
  } noraise {
    _ => None
  }
  let shallow_effect_error = try shallow_effect.try_normalize() catch {
    error => Some(error)
  } noraise {
    _ => None
  }
  let deep_effect_error = try deep_effect.try_normalize() catch {
    error => Some(error)
  } noraise {
    _ => None
  }
  debug_inspect(
    (
      shallow_type_error, deep_type_error, shallow_effect_error, deep_effect_error,
    ),
    content=(
      #|(
      #|  None,
      #|  Some(TypeNormalizationFuelExhausted),
      #|  None,
      #|  Some(EffectNormalizationFuelExhausted),
      #|)
    ),
  )
}
