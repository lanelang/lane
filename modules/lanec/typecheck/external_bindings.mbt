///|
fn SemanticChecker::check_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  guard @abi.Intrinsic::from_name(name) is Some(intrinsic) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return undetermined_checked_expression(Error)
  }
  let actual = compiler_intrinsic_type(intrinsic)
  let synthesis = checked_expression(
    CompilerIntrinsic(intrinsic~, type_=actual, loc~),
    actual,
  )
  match self.type_compatibility(expected, actual, loc) {
    Some(ExactType) => synthesis.with_expectation_match(MatchesExpectation)
    Some(FunctionEffectWidening) =>
      self.check_synthesis_against_expectation(
        synthesis,
        checked_expectation(expected),
        loc,
      )
    Some(IncompatibleType) => {
      self.diagnostics.push({
        kind: BuiltinSignatureMismatch(name~, expected~, actual~),
        loc,
      })
      synthesis.with_expectation_match(MismatchesExpectation)
    }
    None => synthesis.with_expectation_match(UndeterminedExpectationMatch)
  }
}

///|
fn SemanticChecker::synthesize_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard @abi.Intrinsic::from_name(name) is Some(intrinsic) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return checked_expression_none_reported(Error)
  }
  let type_ = compiler_intrinsic_type(intrinsic)
  checked_expression(CompilerIntrinsic(intrinsic~, type_~, loc~), type_)
}

///|
fn compiler_intrinsic_type(intrinsic : @abi.Intrinsic) -> @types.Type {
  match intrinsic.signature() {
    Value(kind) => Primitive(intrinsic_primitive_type(kind))
    Function(parameters~, result~) =>
      Function(
        parameters.map(fn(kind) { Primitive(intrinsic_primitive_type(kind)) }),
        Primitive(intrinsic_primitive_type(result)),
        Empty,
      )
  }
}

///|
fn intrinsic_primitive_type(
  kind : @abi.IntrinsicValueKind,
) -> @types.PrimitiveType {
  match kind {
    Unit => Unit
    Bool => Bool
    I64 => I64
    I32 => I32
    Char => Char
    F32 => F32
    F64 => F64
    String => String
    Byte => Byte
    Bytes => Bytes
  }
}

///|
fn SemanticChecker::check_extern_binding(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  match self.validate_extern_signature(expected, loc) {
    Ok(signature) =>
      checked_expression(
        ExternBinding(name~, signature~, type_=expected, loc~),
        expected,
      )
    Err(restriction) => {
      self.diagnostics.push({
        kind: InvalidExternType(name~, type_=expected, restriction~),
        loc,
      })
      checked_expression(ErrorRecovery(type_=expected, loc~), expected)
    }
  }
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
fn SemanticChecker::validate_extern_signature(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
) -> Result[@abi.HostSignature, ExternTypeRestriction] {
  match type_ {
    Forall(_) | TypeLambda(_) => Err(MonomorphicRequired)
    Function(parameters, result, effect) => {
      let parameter_kinds = []
      for index, parameter in parameters {
        guard self.extern_value_kind(parameter, loc) is Some(kind) else {
          return Err(DirectParameterRequired(index~))
        }
        parameter_kinds.push(kind)
      }
      guard self.extern_value_kind(result, loc) is Some(result) else {
        return Err(DirectResultRequired)
      }
      if self.extern_effect_row(effect.canonicalize()) {
        Ok({ parameters: parameter_kinds, result })
      } else {
        Err(ExternalEffectRowRequired)
      }
    }
    _ => Err(FunctionRequired)
  }
}

///|
fn SemanticChecker::extern_value_kind(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
) -> @abi.ValueKind? {
  match
    normalize_type_or_error(
      self.diagnostics,
      type_,
      loc,
      context="external value type",
    ) {
    Primitive(Unit) => Some(Unit)
    Primitive(Bool) => Some(Bool)
    Primitive(I64) => Some(I64)
    Primitive(F32) => Some(F32)
    Primitive(F64) => Some(F64)
    Primitive(String) => Some(String)
    Constructor(symbol) =>
      if self.declarations.checked_external_type(symbol) is Some(_) {
        Some(Opaque)
      } else {
        None
      }
    _ => None
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
