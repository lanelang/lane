///|
fn SemanticChecker::check_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard @intrinsic_contract.type_of(name) is Some(actual) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return checked_expression_none_reported(Error)
  }
  if !self.type_matches(expected, actual, loc) {
    self.diagnostics.push({
      kind: BuiltinSignatureMismatch(name~, expected~, actual~),
      loc,
    })
  }
  checked_expression(
    @checked.CheckedExpr::CompilerIntrinsic(name~, type_=actual, loc~),
    actual,
  )
}

///|
fn SemanticChecker::synthesize_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard @intrinsic_contract.type_of(name) is Some(type_) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return checked_expression_none_reported(Error)
  }
  checked_expression(
    @checked.CheckedExpr::CompilerIntrinsic(name~, type_~, loc~),
    type_,
  )
}

///|
fn SemanticChecker::check_extern_binding(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  if extern_type_restriction(expected) is Some(restriction) {
    self.diagnostics.push({
      kind: InvalidExternType(name~, type_=expected, restriction~),
      loc,
    })
  }
  checked_expression(
    @checked.CheckedExpr::ExternBinding(name~, type_=expected, loc~),
    expected,
  )
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
fn extern_type_restriction(type_ : @types.Type) -> ExternTypeRestriction? {
  match type_ {
    Forall(_) | TypeLambda(_) => Some(MonomorphicRequired)
    Function(parameters, result, effect) => {
      for index, parameter in parameters {
        if !extern_primitive_type(parameter) {
          return Some(PrimitiveParameterRequired(index~))
        }
      }
      if !extern_primitive_type(result) {
        return Some(PrimitiveResultRequired)
      }
      match effect.canonicalize() {
        Empty | Io => None
        _ => Some(EffectMustBeEmptyOrIo)
      }
    }
    _ => Some(FunctionRequired)
  }
}

///|
fn extern_primitive_type(type_ : @types.Type) -> Bool {
  type_ is Primitive(Unit) ||
  type_ is Primitive(Bool) ||
  type_ is Primitive(Int) ||
  type_ is Primitive(Double) ||
  type_ is Primitive(String)
}
