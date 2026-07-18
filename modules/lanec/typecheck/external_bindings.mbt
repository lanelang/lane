///|
fn SemanticChecker::check_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard compiler_intrinsic_type(name) is Some(actual) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return checked_expression_none_reported(Error)
  }
  if !self.type_matches(expected, actual, loc) {
    self.diagnostics.push({
      kind: BuiltinSignatureMismatch(name~, expected~, actual~),
      loc,
    })
  }
  checked_expression(CompilerIntrinsic(name~, type_=actual, loc~), actual)
}

///|
fn SemanticChecker::synthesize_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard compiler_intrinsic_type(name) is Some(type_) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return checked_expression_none_reported(Error)
  }
  checked_expression(CompilerIntrinsic(name~, type_~, loc~), type_)
}

///|
fn compiler_intrinsic_type(name : String) -> @types.Type? {
  match name {
    "%i64_add" | "%i64_sub" | "%i64_mul" | "%i64_div" | "%i64_rem" =>
      Some(compiler_intrinsic_binary(Int, Int))
    "%i64_neg" => Some(compiler_intrinsic_unary(Int, Int))
    "%i64_equal" | "%i64_less" => Some(compiler_intrinsic_binary(Int, Bool))
    "%f64_add" | "%f64_sub" | "%f64_mul" | "%f64_div" =>
      Some(compiler_intrinsic_binary(Double, Double))
    "%f64_neg" => Some(compiler_intrinsic_unary(Double, Double))
    "%f64_equal" | "%f64_less" => Some(compiler_intrinsic_binary(Double, Bool))
    "%f64_inf" | "%f64_ninf" | "%f64_nan" => Some(Primitive(Double))
    "%string_equal" => Some(compiler_intrinsic_binary(String, Bool))
    _ => None
  }
}

///|
fn compiler_intrinsic_unary(
  parameter : @types.PrimitiveType,
  result : @types.PrimitiveType,
) -> @types.Type {
  Function([Primitive(parameter)], Primitive(result), Empty)
}

///|
fn compiler_intrinsic_binary(
  parameter : @types.PrimitiveType,
  result : @types.PrimitiveType,
) -> @types.Type {
  Function(
    [Primitive(parameter), Primitive(parameter)],
    Primitive(result),
    Empty,
  )
}

///|
fn SemanticChecker::check_extern_binding(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  if self.extern_type_restriction(expected) is Some(restriction) {
    self.diagnostics.push({
      kind: InvalidExternType(name~, type_=expected, restriction~),
      loc,
    })
  }
  checked_expression(ExternBinding(name~, type_=expected, loc~), expected)
}

///|
fn SemanticChecker::synthesize_extern_binding(
  self : SemanticChecker,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  self.diagnostics.push({ kind: ExternNeedsExpectedType(name~), loc })
  checked_expression_none_reported(Error)
}

///|
fn SemanticChecker::extern_type_restriction(
  self : SemanticChecker,
  type_ : @types.Type,
) -> ExternTypeRestriction? {
  match type_ {
    Forall(_) | TypeLambda(_) => Some(MonomorphicRequired)
    Function(parameters, result, effect) => {
      for index, parameter in parameters {
        if !self.extern_direct_type(parameter) {
          return Some(DirectParameterRequired(index~))
        }
      }
      if !self.extern_direct_type(result) {
        return Some(DirectResultRequired)
      }
      if self.extern_effect_row(effect.canonicalize()) {
        None
      } else {
        Some(ExternalEffectRowRequired)
      }
    }
    _ => Some(FunctionRequired)
  }
}

///|
fn SemanticChecker::extern_direct_type(
  self : SemanticChecker,
  type_ : @types.Type,
) -> Bool {
  match type_.normalize() {
    Primitive(Unit)
    | Primitive(Bool)
    | Primitive(Int)
    | Primitive(Double)
    | Primitive(String) => true
    Constructor(symbol) =>
      self.declarations.checked_external_type(symbol) is Some(_)
    _ => false
  }
}

///|
fn SemanticChecker::extern_effect_row(
  self : SemanticChecker,
  effect : @types.Effect,
) -> Bool {
  match effect {
    Empty | Io => true
    Singleton(symbol, _) =>
      self.declarations.checked_effect(symbol) is Some(declaration) &&
      declaration.flavor is External
    Union(items) => items.all(fn(item) { self.extern_effect_row(item) })
    Parameter(_) => false
  }
}
