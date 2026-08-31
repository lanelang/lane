///|
fn SemanticChecker::check_compiler_intrinsic(
  self : SemanticChecker,
  name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionCheck {
  guard @abi.Intrinsic::from_name(name) is Some(intrinsic) else {
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc, })
    return undetermined_checked_expression(Error)
  }
  guard self.compiler_intrinsic_type(intrinsic, loc) is Some(actual) else {
    return undetermined_checked_expression(Error)
  }
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
    self.diagnostics.push({ kind: UnknownBuiltin(name~), loc, })
    return checked_expression_none_reported(Error)
  }
  guard self.compiler_intrinsic_type(intrinsic, loc) is Some(type_) else {
    return checked_expression_none_reported(Error)
  }
  checked_expression(CompilerIntrinsic(intrinsic~, type_~, loc~), type_)
}

///|
fn SemanticChecker::compiler_intrinsic_type(
  self : SemanticChecker,
  intrinsic : @abi.Intrinsic,
  loc : SourceSpan,
) -> @types.Type? {
  match intrinsic.signature() {
    Value(kind) => self.intrinsic_value_type(kind, loc)
    Function(parameters~, result~, effect~, ..) => {
      let checked_parameters = []
      for parameter in parameters {
        guard self.intrinsic_value_type(parameter, loc) is Some(type_) else {
          return None
        }
        checked_parameters.push(type_)
      }
      guard self.intrinsic_value_type(result, loc) is Some(result_type) else {
        return None
      }
      Some(
        Function(
          checked_parameters,
          result_type,
          match effect {
            Pure => Empty
            BuiltinIo => Builtin(Io)
            BuiltinPanic => Builtin(Panic)
          },
        ),
      )
    }
  }
}

///|
fn SemanticChecker::intrinsic_value_type(
  self : SemanticChecker,
  kind : @abi.IntrinsicType,
  loc : SourceSpan,
) -> @types.Type? {
  match kind {
    Unit => Some(Primitive(Unit))
    Bool => Some(Primitive(Bool))
    I64 => Some(Primitive(I64))
    I32 => Some(Primitive(I32))
    Char => Some(Primitive(Char))
    F32 => Some(Primitive(F32))
    F64 => Some(Primitive(F64))
    String => Some(Primitive(String))
    Byte => Some(Primitive(Byte))
    Bytes => Some(Primitive(Bytes))
    ByteBuffer => Some(Primitive(ByteBuffer))
    CanonicalBasicVoid => self.canonical_basic_void_type(loc)
  }
}

///|
fn SemanticChecker::check_extern_binding(
  self : SemanticChecker,
  module_name : String,
  field_name : String,
  expected : @types.Type,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let name = "\{module_name}.\{field_name}"
  match self.validate_extern_contract(module_name, field_name, expected, loc) {
    Ok(contract) =>
      checked_expression(
        ExternBinding(contract~, type_=expected, loc~),
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
  module_name : String,
  field_name : String,
  loc : SourceSpan,
) -> CheckedExpressionSynthesis {
  let name = "\{module_name}.\{field_name}"
  self.diagnostics.push({ kind: ExternNeedsExpectedType(name~), loc, })
  checked_expression_none_reported(Error)
}

///|
fn SemanticChecker::validate_extern_contract(
  self : SemanticChecker,
  module_name : String,
  field_name : String,
  type_ : @types.Type,
  loc : SourceSpan,
) -> Result[@wasm_abi.ImportContract, ExternTypeRestriction] {
  match type_ {
    Forall(_) | TypeLambda(_) => Err(MonomorphicRequired)
    Function(parameters, result, effect) => {
      let parameter_contracts = []
      for index, parameter in parameters {
        guard self.extern_parameter_contract(parameter, loc) is Some(contract) else {
          return Err(DirectParameterRequired(index~))
        }
        parameter_contracts.push(contract)
      }
      guard self.extern_result_contract(result, loc) is Some(result_contract) else {
        return Err(DirectResultRequired)
      }
      if !self.extern_effect_row(effect.canonicalize()) {
        return Err(ExternalEffectRowRequired)
      }
      let contract : @wasm_abi.ImportContract = {
        module_name,
        field_name,
        parameters: parameter_contracts,
        result: result_contract,
      }
      if module_name == "wasi_snapshot_preview1" {
        guard @wasm_abi.wasi_preview1_contract(field_name) is Some(canonical) else {
          return Err(UnknownWasiPreview1Import(field_name~))
        }
        if contract != canonical {
          return Err(WasiPreview1ContractMismatch(expected=canonical))
        }
      }
      Ok(contract)
    }
    _ => Err(FunctionRequired)
  }
}

///|
fn SemanticChecker::extern_parameter_contract(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
) -> @wasm_abi.ImportParameter? {
  match
    normalize_type_or_error(
      self.diagnostics,
      type_,
      loc,
      context="external value type",
    ) {
    Primitive(Unit) => Some(ErasedUnit)
    Primitive(I32) => Some(Direct(I32))
    Primitive(I64) => Some(Direct(I64))
    Primitive(F32) => Some(Direct(F32))
    Primitive(F64) => Some(Direct(F64))
    Constructor(symbol) => {
      guard self.resolved_source.canonical_basic_abi.type_symbol(WasmAddress) ==
        Some(symbol) else {
        return None
      }
      match self.canonical_basic_abi.validate_provider(WasmAddress) {
        Ok(_) => Some(GuestAddress)
        Err(error) => {
          self.report_canonical_basic_abi_diagnostic(error.at(loc))
          None
        }
      }
    }
    _ => None
  }
}

///|
fn SemanticChecker::extern_result_contract(
  self : SemanticChecker,
  type_ : @types.Type,
  loc : SourceSpan,
) -> @wasm_abi.ImportResult? {
  match
    normalize_type_or_error(
      self.diagnostics,
      type_,
      loc,
      context="external result type",
    ) {
    Primitive(Unit) => Some(Unit)
    Primitive(I32) => Some(Direct(I32))
    Primitive(I64) => Some(Direct(I64))
    Primitive(F32) => Some(Direct(F32))
    Primitive(F64) => Some(Direct(F64))
    _ => None
  }
}

///|
fn SemanticChecker::extern_effect_row(
  self : SemanticChecker,
  effect : @types.Effect,
) -> Bool {
  match effect {
    Empty | Builtin(_) => true
    Singleton(symbol, _) =>
      self.declarations.checked_effect(symbol) is Some(declaration) &&
      declaration.flavor is External
    Union(items) => items.all(fn(item) { self.extern_effect_row(item) })
    Parameter(_) => false
  }
}
