///|
fn SemanticChecker::check_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  guard @abi.Intrinsic::from_name(name) is Some(intrinsic) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc })
    return checked_expression_none_reported(Error)
  }
  let actual = compiler_intrinsic_type(intrinsic)
  if !self.type_matches(expected, actual, loc) {
    self.diagnostics.push({
      kind: BuiltinSignatureMismatch(name~, expected~, actual~),
      loc,
    })
  }
  checked_expression(CompilerIntrinsic(intrinsic~, type_=actual, loc~), actual)
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
fn intrinsic_primitive_type(kind : @abi.ValueKind) -> @types.PrimitiveType {
  match kind {
    Unit => Unit
    Bool => Bool
    Int => Int
    Double => Double
    String => String
    Opaque => abort("compiler intrinsic cannot use an opaque ABI value")
  }
}

///|
fn SemanticChecker::check_extern_binding(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let signature = match self.extern_type_restriction(expected) {
    Some(restriction) => {
      self.diagnostics.push({
        kind: InvalidExternType(name~, type_=expected, restriction~),
        loc,
      })
      None
    }
    None => self.extern_signature(expected)
  }
  checked_expression(
    ExternBinding(name~, signature~, type_=expected, loc~),
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
fn SemanticChecker::extern_signature(
  self : SemanticChecker,
  type_ : @types.Type,
) -> @abi.HostSignature? {
  guard type_.normalize() is Function(parameters, result, _) else {
    return None
  }
  let parameter_kinds = []
  for parameter in parameters {
    guard self.extern_value_kind(parameter) is Some(kind) else { return None }
    parameter_kinds.push(kind)
  }
  guard self.extern_value_kind(result) is Some(result) else { return None }
  Some({ parameters: parameter_kinds, result })
}

///|
fn SemanticChecker::extern_value_kind(
  self : SemanticChecker,
  type_ : @types.Type,
) -> @abi.ValueKind? {
  match type_.normalize() {
    Primitive(Unit) => Some(Unit)
    Primitive(Bool) => Some(Bool)
    Primitive(Int) => Some(Int)
    Primitive(Double) => Some(Double)
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
