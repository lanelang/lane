///|
/// The certified output of effect lowering.
///
/// Buslane remains the representation; this certificate adds the stronger CPS
/// Core postcondition and owns the matching function provenance. Consumers may
/// inspect the verified Buslane program, but only this module can construct the
/// initial certificate.
pub struct CpsCoreProgram {
  priv program : @buslane.VerifiedProgram
  priv function_origins : @function_origin.FunctionOriginCatalog
  priv eliminated_effect_parameters : Array[@buslane.TypeParameterId]
} derive(Debug, Eq)

///|
/// A compiler-internal violation of the CPS Core postcondition.
pub(all) suberror CpsCoreVerificationError {
  MissingFunctionOrigin(owner~ : @buslane.ValueId?)
  ResidualPerform(owner~ : @buslane.ValueId?, operation~ : @buslane.OperationId)
  ResidualHandle(owner~ : @buslane.ValueId?)
  ResidualResume(owner~ : @buslane.ValueId?, value~ : @buslane.ValueId)
  EscapedSourceEffectParameter(@buslane.TypeParameterId)
  AlgebraicLatentEffect(owner~ : @buslane.ValueId?, effect~ : @buslane.Effect)
} derive(Debug, Eq)

///|
/// Returns the verified Buslane representation carried by this certificate.
pub fn CpsCoreProgram::program(
  self : CpsCoreProgram,
) -> @buslane.VerifiedProgram {
  self.program
}

///|
/// Returns an isolated snapshot of the transformation-owned provenance carried
/// by this certificate. Rewriters may extend the result without mutating the
/// input certificate.
pub fn CpsCoreProgram::function_origins(
  self : CpsCoreProgram,
) -> @function_origin.FunctionOriginCatalog {
  self.function_origins.snapshot()
}

///|
/// Returns an isolated Buslane snapshot and the provenance snapshot aligned to
/// its function identities. The certificate, rather than each consumer, owns
/// provenance transfer across the Buslane snapshot boundary.
pub fn CpsCoreProgram::snapshot(
  self : CpsCoreProgram,
) -> (@buslane.Program, @function_origin.FunctionOriginCatalog) {
  let function_origins = self.function_origins.snapshot()
  let (program, function_clones) = self.program.program_with_function_clones()
  for clone in function_clones {
    // Certification proves every source identity has an origin and snapshot
    // targets are fresh, so transfer cannot fail at this boundary.
    ignore(function_origins.transfer(clone.source, clone.target))
  }
  (program, function_origins)
}

///|
/// Re-certifies a semantics-preserving rewrite of an existing CPS Core
/// program. Possession of the input certificate preserves the original source
/// effect boundary; a generic Buslane program cannot invent that fact.
pub fn CpsCoreProgram::recertify(
  self : CpsCoreProgram,
  program : @buslane.VerifiedProgram,
  function_origins : @function_origin.FunctionOriginCatalog,
) -> Result[CpsCoreProgram, CpsCoreVerificationError] {
  certify_cps_core_program(
    program,
    function_origins,
    self.eliminated_effect_parameters,
  )
}

///|
fn source_effect_parameters(
  metadata : @buslane.MetadataRegistry,
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  for index, info in metadata.type_parameters {
    if info.kind == Effect {
      parameters.push(@buslane.TypeParameterId::{ index, })
    }
  }
  parameters
}

///|
fn certify_initial_cps_core_program(
  program : @buslane.VerifiedProgram,
  function_origins : @function_origin.FunctionOriginCatalog,
  eliminated_effect_parameters : Array[@buslane.TypeParameterId],
) -> Result[CpsCoreProgram, CpsCoreVerificationError] {
  certify_cps_core_program(
    program, function_origins, eliminated_effect_parameters,
  )
}

///|
fn certify_cps_core_program(
  program : @buslane.VerifiedProgram,
  function_origins : @function_origin.FunctionOriginCatalog,
  eliminated_effect_parameters : Array[@buslane.TypeParameterId],
) -> Result[CpsCoreProgram, CpsCoreVerificationError] {
  try {
    let function_origins = function_origins.snapshot()
    let (snapshot, function_clones) = program.program_with_function_clones()
    for clone in function_clones {
      ignore(function_origins.transfer(clone.source, clone.target))
    }
    verify_cps_core_program(
      snapshot, function_origins, eliminated_effect_parameters,
    )
    Ok({
      program,
      function_origins,
      eliminated_effect_parameters: eliminated_effect_parameters.copy(),
    })
  } catch {
    error => Err(error)
  }
}

///|
priv struct CpsCoreVerifier {
  program : @buslane.Program
  function_origins : @function_origin.FunctionOriginCatalog
  eliminated_effect_parameters : Array[@buslane.TypeParameterId]
}

///|
fn verify_cps_core_program(
  program : @buslane.Program,
  function_origins : @function_origin.FunctionOriginCatalog,
  eliminated_effect_parameters : Array[@buslane.TypeParameterId],
) -> Unit raise CpsCoreVerificationError {
  let verifier = CpsCoreVerifier::{
    program,
    function_origins,
    eliminated_effect_parameters,
  }
  let declarations = collect_program_declarations(elaborate_handlers(program))
  for value in declarations.value_ids() {
    if program.metadata.value_info(value) is Some(info) {
      verifier.verify_type(info.type_, Some(value))
    }
  }
  for type_id in declarations.type_ids() {
    if program.metadata.type_info(type_id) is Some(info) {
      for parameter in info.parameters {
        verifier.verify_parameter(parameter)
      }
    }
  }
  for data_constructor in declarations.data_constructor_ids() {
    if program.metadata.data_constructor_info(data_constructor) is Some(info) {
      for parameter in info.hidden_type_parameters {
        verifier.verify_parameter(parameter)
      }
      for payload in info.payload_types {
        verifier.verify_type(payload, None)
      }
    }
  }
  for term in program.terms {
    match term {
      Let(owner, expression) => verifier.verify_expr(expression, Some(owner))
      LetRec(bindings) =>
        for binding in bindings {
          verifier.verify_expr(binding.rhs, Some(binding.id))
        }
      External(_) => ()
    }
  }
}

///|
fn CpsCoreVerifier::verify_parameter(
  self : CpsCoreVerifier,
  parameter : @buslane.TypeParameterId,
) -> Unit raise CpsCoreVerificationError {
  if self.eliminated_effect_parameters.contains(parameter) {
    raise EscapedSourceEffectParameter(parameter)
  }
}

///|
fn CpsCoreVerifier::verify_type(
  self : CpsCoreVerifier,
  type_ : @buslane.Type,
  owner : @buslane.ValueId?,
) -> Unit raise CpsCoreVerificationError {
  match type_ {
    Primitive(_) | Constructor(_) => ()
    Parameter(parameter) => self.verify_parameter(parameter)
    Apply(callee, arguments) => {
      self.verify_type(callee, owner)
      for argument in arguments {
        self.verify_argument(argument, owner)
      }
    }
    TypeLambda(parameters, body) | Forall(parameters, body) => {
      for parameter in parameters {
        self.verify_parameter(parameter)
      }
      self.verify_type(body, owner)
    }
    Function(parameters, result, effect) => {
      for parameter in parameters {
        self.verify_type(parameter, owner)
      }
      self.verify_type(result, owner)
      self.verify_effect(effect, owner)
      if self.program.metadata.effect_term_is_algebraic(effect) {
        raise AlgebraicLatentEffect(owner~, effect~)
      }
    }
  }
}

///|
fn CpsCoreVerifier::verify_argument(
  self : CpsCoreVerifier,
  argument : @buslane.GenericArgument,
  owner : @buslane.ValueId?,
) -> Unit raise CpsCoreVerificationError {
  match argument {
    TypeArgument(type_) => self.verify_type(type_, owner)
    EffectArgument(effect) => self.verify_effect(effect, owner)
  }
}

///|
fn CpsCoreVerifier::verify_effect(
  self : CpsCoreVerifier,
  effect : @buslane.Effect,
  owner : @buslane.ValueId?,
) -> Unit raise CpsCoreVerificationError {
  match effect {
    Empty | Builtin(_) => ()
    Parameter(parameter) => self.verify_parameter(parameter)
    Singleton(_, arguments) =>
      for argument in arguments {
        self.verify_argument(argument, owner)
      }
    Union(effects) =>
      for effect in effects {
        self.verify_effect(effect, owner)
      }
  }
}

///|
fn CpsCoreVerifier::verify_expr(
  self : CpsCoreVerifier,
  expression : @buslane.Expr,
  owner : @buslane.ValueId?,
) -> Unit raise CpsCoreVerificationError {
  match expression {
    Ref(_) | Literal(_) => ()
    Function(function) => {
      if self.function_origins.origin(function) is None {
        raise MissingFunctionOrigin(owner~)
      }
      self.verify_type(function.result_type, owner)
      self.verify_expr(function.body, owner)
    }
    Call(callee, arguments) => {
      self.verify_expr(callee, owner)
      for argument in arguments {
        self.verify_expr(argument, owner)
      }
    }
    TypeLambda(parameters, body) => {
      for parameter in parameters {
        self.verify_parameter(parameter)
      }
      self.verify_expr(body, owner)
    }
    TypeApply(callee, arguments) => {
      self.verify_expr(callee, owner)
      for argument in arguments {
        self.verify_argument(argument, owner)
      }
    }
    Construct(construct) => {
      for argument in construct.type_arguments {
        self.verify_argument(argument, owner)
      }
      for witness in construct.hidden_witnesses {
        self.verify_argument(witness, owner)
      }
      for payload in construct.payloads {
        self.verify_expr(payload, owner)
      }
    }
    Let(_, initializer, body) => {
      self.verify_expr(initializer, owner)
      self.verify_expr(body, owner)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.verify_expr(binding.rhs, owner)
      }
      self.verify_expr(body, owner)
    }
    Match(match_) => {
      self.verify_expr(match_.scrutinee, owner)
      self.verify_type(match_.result_type, owner)
      for alternative in match_.alternatives {
        for parameter in alternative.type_binders {
          self.verify_parameter(parameter)
        }
        self.verify_expr(alternative.body, owner)
      }
    }
    Perform(perform) =>
      raise ResidualPerform(owner~, operation=perform.operation)
    Handle(_) => raise ResidualHandle(owner~)
    Resume(value) => raise ResidualResume(owner~, value~)
  }
}
