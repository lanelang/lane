///|
priv struct RuntimeAnfVerifier {
  metadata : RuntimeMetadata
  runtime_types : RuntimeTypeCatalog
  top_values : Array[@buslane.ValueId]
  seen_temps : Array[AnfTempId]
  seen_functions : Array[AnfFunctionId]
}

///|
priv struct RuntimeAnfScope {
  values : Array[@buslane.ValueId]
  temps : Array[(AnfTempId, RuntimeType)]
  evidence : Array[RuntimeEvidenceParameter]
}

///|
priv enum RuntimeAnfRecursiveKind {
  Closure
  Direct
  Join
} derive(Eq)

///|
fn verify_runtime_anf(
  program : AnfProgram,
) -> Unit raise RuntimeAnfLoweringError {
  let verifier : RuntimeAnfVerifier = {
    metadata: program.metadata,
    runtime_types: program.metadata.runtime_type_catalog(),
    top_values: [],
    seen_temps: [],
    seen_functions: [],
  }
  verifier.verify_metadata()
  for index, term in program.terms {
    let path = [RuntimeAnfVerificationFrame::TopTerm(index)]
    for value in anf_top_term_values(term) {
      if verifier.top_values.contains(value) {
        verifier.fail(DuplicateValue(value), path)
      }
      ignore(verifier.require_value_info(value, path))
      verifier.top_values.push(value)
    }
  }
  let mut scope : RuntimeAnfScope = { values: [], temps: [], evidence: [], }
  for index, term in program.terms {
    let path = [RuntimeAnfVerificationFrame::TopTerm(index)]
    scope = verifier.verify_top_term(term, scope, path)
  }
  verify_callable_dispositions(program)
}

///|
fn RuntimeAnfVerifier::fail(
  self : RuntimeAnfVerifier,
  kind : RuntimeAnfVerificationError,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  ignore(self)
  raise InvalidRuntimeAnf({ kind, path, })
}

///|
fn anf_top_term_values(term : AnfTopTerm) -> Array[@buslane.ValueId] {
  match term {
    Let(value, _) | External(value) => [value]
    LetRec(bindings) => bindings.map(binding => binding.id)
  }
}

///|
fn RuntimeAnfVerifier::verify_metadata(
  self : RuntimeAnfVerifier,
) -> Unit raise RuntimeAnfLoweringError {
  for index, parameter in self.metadata.evidence_parameters {
    if parameter is Some(parameter) {
      let path = [MetadataEvidence(parameter.id)]
      if parameter.id != Projected(index) || parameter.arity < 0 {
        self.fail(InvalidEvidenceParameter(parameter), path)
      }
    }
  }
  for index, info in self.metadata.values {
    let value : @buslane.ValueId = { index, }
    self.verify_type_mode(info.type_, [], true, [MetadataValue(value)])
  }
  for index, info in self.metadata.types {
    let owner : @buslane.TypeId = { index, }
    let path = [RuntimeAnfVerificationFrame::MetadataType(owner)]
    ignore(self.verify_evidence_binders(info.evidence_parameters, [], path))
    let seen = []
    for data_constructor in info.constructors {
      if seen.contains(data_constructor) {
        self.fail(InvalidDataConstructor(data_constructor), path)
      }
      seen.push(data_constructor)
      let constructor_info = self.require_data_constructor_info(
        data_constructor, path,
      )
      if info.kind is OpaqueReference || constructor_info.owner != owner {
        self.fail(InvalidDataConstructor(data_constructor), path)
      }
    }
  }
  for index, info in self.metadata.data_constructors {
    let data_constructor : @buslane.DataConId = { index, }
    let path = [MetadataDataConstructor(data_constructor)]
    let owner = self.require_type_info(info.owner, path)
    if owner.kind is OpaqueReference ||
      !owner.constructors.contains(data_constructor) {
      self.fail(InvalidDataConstructor(data_constructor), path)
    }
    let evidence = self.verify_evidence_binders(
      owner.evidence_parameters,
      [],
      path,
    )
    let evidence = self.verify_evidence_binders(
      info.hidden_evidence_parameters,
      evidence,
      path,
    )
    for payload in info.payload_types {
      self.verify_type(payload, evidence, path)
    }
  }
  for index in 0..<self.metadata.type_expressions.length() {
    let expression : RuntimeTypeExpressionId = { index, }
    ignore(
      self.type_expression_arity(expression, [], [], true, [
        MetadataTypeExpression(expression),
      ]),
    )
  }
}

///|
fn RuntimeAnfVerifier::verify_top_term(
  self : RuntimeAnfVerifier,
  term : AnfTopTerm,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeAnfScope raise RuntimeAnfLoweringError {
  match term {
    External(value) => {
      self.verify_type(self.require_value_info(value, path).type_, [], path)
      scope.with_value(value)
    }
    Let(value, expression) => {
      let expected = self.require_value_info(value, path).type_
      self.verify_type(expected, [], path)
      let actual = self.verify_expr(expression, scope, path)
      self.require_same_type(expected, actual, path)
      scope.with_value(value)
    }
    LetRec(bindings) => {
      ignore(self.verify_recursive_group(bindings, scope, path, true))
      scope.with_values(bindings.map(binding => binding.id))
    }
  }
}

///|
fn RuntimeAnfVerifier::verify_expr(
  self : RuntimeAnfVerifier,
  expression : AnfExpr,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeType raise RuntimeAnfLoweringError {
  match expression {
    Atom(atom) => self.atom_type(atom, scope, path)
    Let(binding, body) => {
      let (expected, body_scope, frame) = match binding {
        Value(id~, ..) => {
          self.claim_value(id, scope, path)
          let type_ = self.require_value_info(id, path).type_
          self.verify_type(type_, scope.evidence, path)
          (type_, scope.with_value(id), ValueBinding(id))
        }
        Temp(temp~, type_~, ..) => {
          self.claim_temp(temp, path)
          self.verify_type(type_, scope.evidence, path)
          (type_, scope.with_temp(temp, type_), TempBinding(temp))
        }
      }
      let binding_path = path + [frame]
      self.verify_rhs(
        anf_verification_binding_rhs(binding),
        expected,
        scope,
        binding_path,
      )
      self.verify_expr(body, body_scope, binding_path)
    }
    LetRec(bindings, body) => {
      let body_scope = self.verify_recursive_group(bindings, scope, path, false)
      self.verify_expr(body, body_scope, path)
    }
  }
}

///|
fn RuntimeAnfVerifier::verify_rhs(
  self : RuntimeAnfVerifier,
  rhs : AnfRhs,
  expected : RuntimeType,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  match rhs {
    Atom(atom) =>
      self.require_same_type(expected, self.atom_type(atom, scope, path), path)
    Call(callee~, arguments~) => {
      let callee_type = self.atom_type(callee, scope, path)
      guard callee_type is Callable(parameters, result) else {
        self.fail(NotCallable(callee_type), path)
        return
      }
      if parameters.length() != arguments.length() {
        self.fail(
          ArityMismatch(expected=parameters.length(), actual=arguments.length()),
          path,
        )
      }
      for index, argument in arguments {
        self.require_same_type(
          parameters[index],
          self.atom_type(argument, scope, path),
          path,
        )
      }
      self.require_same_type(expected, result, path)
    }
    ApplyEvidence(callee~, arguments~) => {
      let callee_type = self.atom_type(callee, scope, path)
      guard callee_type is Forall(parameters, body) else {
        self.fail(NotPolymorphic(callee_type), path)
        return
      }
      self.verify_arguments(arguments, parameters, scope.evidence, path)
      let actual = self.instantiate_runtime_type(
        body,
        runtime_substitution_entries(parameters, arguments),
        path,
      )
      self.require_same_type(expected, actual, path)
    }
    Construct(construct) =>
      self.verify_construct(construct, expected, scope, path)
    Match(match_) => self.verify_match(match_, expected, scope, path)
  }
}

///|
fn RuntimeAnfVerifier::verify_construct(
  self : RuntimeAnfVerifier,
  construct : AnfConstruct,
  expected : RuntimeType,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  let info = self.require_data_constructor_info(
    construct.data_constructor,
    path,
  )
  let owner = self.require_type_info(info.owner, path)
  let constructed = RuntimeType::Data(info.owner, construct.type_arguments)
  guard expected is Data(actual_owner, _) && actual_owner == info.owner else {
    self.fail(InvalidDataConstructor(construct.data_constructor), path)
    return
  }
  self.verify_arguments(
    construct.type_arguments,
    owner.evidence_parameters,
    scope.evidence,
    path,
  )
  if !self.runtime_types.types_alpha_equivalent(expected, constructed) {
    self.fail(RuntimeTypeMismatch(expected~, actual=constructed), path)
  }
  let substitutions = runtime_substitution_entries(
    info.hidden_evidence_parameters,
    construct.hidden_arguments,
  )
  substitutions.append(
    runtime_substitution_entries(
      owner.evidence_parameters,
      construct.type_arguments,
    ),
  )
  self.verify_arguments(
    construct.hidden_arguments,
    info.hidden_evidence_parameters,
    scope.evidence,
    path,
  )
  if construct.payloads.length() != info.payload_types.length() {
    self.fail(
      ArityMismatch(
        expected=info.payload_types.length(),
        actual=construct.payloads.length(),
      ),
      path,
    )
  }
  for index in 0..<construct.payloads.length().min(info.payload_types.length()) {
    let expected_payload = self.instantiate_runtime_type(
      info.payload_types[index],
      substitutions,
      path,
    )
    let actual_payload = self.atom_type(construct.payloads[index], scope, path)
    self.require_same_type(expected_payload, actual_payload, path)
  }
}

///|
fn RuntimeAnfVerifier::verify_match(
  self : RuntimeAnfVerifier,
  match_ : AnfMatch,
  expected : RuntimeType,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  self.verify_type(match_.result_type, scope.evidence, path)
  self.require_same_type(expected, match_.result_type, path)
  let scrutinee_type = self.atom_type(match_.scrutinee, scope, path)
  self.claim_value(match_.binder, scope, path)
  self.require_same_type(
    scrutinee_type,
    self.require_value_info(match_.binder, path).type_,
    path,
  )
  let seen = []
  let mut has_default = false
  for index, alternative in match_.alternatives {
    let alternative_path = path + [Alternative(index)]
    if seen.contains(alternative.alt_constructor) {
      self.fail(InvalidAlternative, alternative_path)
    }
    seen.push(alternative.alt_constructor)
    if alternative.alt_constructor is Default {
      if index + 1 != match_.alternatives.length() {
        self.fail(InvalidAlternative, alternative_path)
      }
      has_default = true
    }
    let alternative_scope = self.verify_alternative(
      alternative,
      scrutinee_type,
      scope.with_value(match_.binder),
      alternative_path,
    )
    self.require_same_type(
      match_.result_type,
      self.verify_expr(alternative.body, alternative_scope, alternative_path),
      alternative_path,
    )
  }
  if !self.match_is_exhaustive(scrutinee_type, seen, has_default, path) {
    self.fail(InvalidAlternative, path)
  }
}

///|
fn RuntimeAnfVerifier::verify_alternative(
  self : RuntimeAnfVerifier,
  alternative : AnfAlternative,
  scrutinee_type : RuntimeType,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeAnfScope raise RuntimeAnfLoweringError {
  match alternative.alt_constructor {
    Default | Literal(_) => {
      if !alternative.evidence_binders.is_empty() ||
        !alternative.value_binders.is_empty() {
        self.fail(InvalidAlternative, path)
      }
      if alternative.alt_constructor is Literal(literal) {
        self.require_same_type(
          scrutinee_type,
          runtime_literal_type(literal),
          path,
        )
      }
      scope
    }
    DataCon(data_constructor) => {
      let info = self.require_data_constructor_info(data_constructor, path)
      guard scrutinee_type is Data(owner, _) && owner == info.owner else {
        self.fail(InvalidDataConstructor(data_constructor), path)
        return scope
      }
      if alternative.evidence_binders.length() !=
        info.hidden_evidence_parameters.length() ||
        alternative.value_binders.length() != info.payload_types.length() {
        self.fail(InvalidAlternative, path)
      }
      for index, parameter in alternative.evidence_binders {
        if parameter.arity != info.hidden_evidence_parameters[index].arity {
          self.fail(InvalidEvidenceParameter(parameter), path)
        }
      }
      let evidence = self.verify_evidence_binders(
        alternative.evidence_binders,
        scope.evidence,
        path,
      )
      let mut nested = { ..scope, evidence, }
      for binder in alternative.value_binders {
        self.claim_value(binder, nested, path)
        let actual = self.require_value_info(binder, path).type_
        self.verify_type(actual, evidence, path)
        nested = nested.with_value(binder)
      }
      nested
    }
  }
}

///|
fn RuntimeAnfVerifier::match_is_exhaustive(
  self : RuntimeAnfVerifier,
  scrutinee : RuntimeType,
  alternatives : Array[@buslane.AltCon],
  has_default : Bool,
  path : Array[RuntimeAnfVerificationFrame],
) -> Bool raise RuntimeAnfLoweringError {
  if has_default {
    return true
  }
  match scrutinee {
    Unit => alternatives.contains(Literal(Unit))
    Scalar(Bool) =>
      alternatives.contains(Literal(Bool(true))) &&
      alternatives.contains(Literal(Bool(false)))
    Data(owner, _) => {
      let info = self.require_type_info(owner, path)
      info.constructors.all(data_constructor => {
        alternatives.contains(DataCon(data_constructor))
      })
    }
    Scalar(_)
    | ByteSequence
    | ByteBuffer
    | Callable(_, _)
    | Forall(_, _)
    | Erased(_, _) => false
  }
}

///|
fn RuntimeAnfVerifier::verify_recursive_group(
  self : RuntimeAnfVerifier,
  bindings : Array[AnfRecursiveBinding],
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
  top_level : Bool,
) -> RuntimeAnfScope raise RuntimeAnfLoweringError {
  if bindings.is_empty() {
    self.fail(InvalidRecursiveGroup, path)
  }
  let mut nested = scope
  for binding in bindings {
    if !top_level {
      self.claim_value(binding.id, nested, path)
    }
    ignore(self.require_value_info(binding.id, path))
    nested = nested.with_value(binding.id)
  }
  let expected_kind = runtime_recursive_kind(bindings[0].rhs)
  guard expected_kind is Some(expected_kind) else {
    self.fail(InvalidRecursiveGroup, path)
    return nested
  }
  if top_level && expected_kind != Closure {
    self.fail(InvalidTopLevelCallable, path)
  }
  let mut join_result : RuntimeType? = None
  for index, binding in bindings {
    let binding_path = path + [RecursiveBinding(index)]
    if runtime_recursive_kind(binding.rhs) != Some(expected_kind) {
      self.fail(InvalidRecursiveGroup, binding_path)
    }
    if binding.rhs is EvidenceLambda(_) &&
      !runtime_generic_atom_contains_function(binding.rhs) {
      self.fail(InvalidGenericValue, binding_path)
    }
    let expected = self.require_value_info(binding.id, binding_path).type_
    self.verify_type(expected, nested.evidence, binding_path)
    let actual = self.atom_type(binding.rhs, nested, binding_path)
    self.require_same_type(expected, actual, binding_path)
    if expected_kind is Join {
      guard actual is Callable(_, result) else {
        self.fail(InvalidRecursiveGroup, binding_path)
        return nested
      }
      match join_result {
        None => join_result = Some(result)
        Some(previous) => self.require_same_type(previous, result, binding_path)
      }
    }
  }
  nested
}

///|
fn runtime_recursive_kind(atom : AnfAtom) -> RuntimeAnfRecursiveKind? {
  match atom {
    Function(_) | EvidenceLambda(_) => Some(Closure)
    DirectFunction(_) => Some(Direct)
    JoinPoint(_) => Some(Join)
    Literal(_) | Ref(_) | Temp(_) => None
  }
}

///|
fn runtime_generic_atom_contains_function(atom : AnfAtom) -> Bool {
  match atom {
    EvidenceLambda(body~, ..) =>
      match body {
        Atom(Function(_)) => true
        Atom(atom) => runtime_generic_atom_contains_function(atom)
        Let(_) | LetRec(_) => false
      }
    Function(_) => true
    Literal(_) | Ref(_) | Temp(_) | DirectFunction(_) | JoinPoint(_) => false
  }
}

///|
fn RuntimeAnfVerifier::atom_type(
  self : RuntimeAnfVerifier,
  atom : AnfAtom,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeType raise RuntimeAnfLoweringError {
  match atom {
    Literal(literal) => runtime_literal_type(literal)
    Ref(value) => {
      if !scope.values.contains(value) {
        if self.top_values.contains(value) {
          self.fail(InitializationOrderViolation(value), path)
        } else {
          self.fail(UnboundValue(value), path)
        }
      }
      self.require_value_info(value, path).type_
    }
    Temp(temp) =>
      match scope.temp_type(temp) {
        Some(type_) => type_
        None => {
          self.fail(UnboundTemp(temp), path)
          Unit
        }
      }
    Function(function) | DirectFunction(function) | JoinPoint(function) =>
      self.verify_function(function, scope, path)
    EvidenceLambda(parameters~, body~) => {
      if !runtime_generic_atom_contains_function(atom) {
        self.fail(InvalidGenericValue, path)
      }
      let evidence = self.verify_evidence_binders(
        parameters,
        scope.evidence,
        path,
      )
      let body_scope = scope
        .with_evidence(evidence)
        .with_top_values(self.top_values)
      Forall(parameters, self.verify_expr(body, body_scope, path))
    }
  }
}

///|
fn RuntimeAnfVerifier::verify_function(
  self : RuntimeAnfVerifier,
  function : AnfFunction,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeType raise RuntimeAnfLoweringError {
  if function.id.value < 0 || self.seen_functions.contains(function.id) {
    self.fail(DuplicateFunction(function.id), path)
  }
  self.seen_functions.push(function.id)
  let function_path = path + [AnfFunction(function.id)]
  if function.source is Some(source) {
    ignore(self.require_value_info(source, function_path))
  }
  self.verify_type(function.result_type, scope.evidence, function_path)
  let parameter_types = []
  let mut body_scope = scope.with_top_values(self.top_values)
  for parameter in function.parameters {
    self.claim_value(parameter, body_scope, function_path)
    let type_ = self.require_value_info(parameter, function_path).type_
    self.verify_type(type_, scope.evidence, function_path)
    parameter_types.push(type_)
    body_scope = body_scope.with_value(parameter)
  }
  let actual = self.verify_expr(function.body, body_scope, function_path)
  self.require_same_type(function.result_type, actual, function_path)
  Callable(parameter_types, function.result_type)
}

///|
fn RuntimeAnfVerifier::verify_arguments(
  self : RuntimeAnfVerifier,
  arguments : Array[RuntimeArgument],
  parameters : Array[RuntimeEvidenceParameter],
  evidence : Array[RuntimeEvidenceParameter],
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  self.verify_arguments_mode(arguments, parameters, evidence, false, path)
}

///|
fn RuntimeAnfVerifier::verify_arguments_mode(
  self : RuntimeAnfVerifier,
  arguments : Array[RuntimeArgument],
  parameters : Array[RuntimeEvidenceParameter],
  evidence : Array[RuntimeEvidenceParameter],
  catalog : Bool,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  if arguments.length() != parameters.length() {
    self.fail(
      ArityMismatch(expected=parameters.length(), actual=arguments.length()),
      path,
    )
  }
  for index, argument in arguments {
    self.verify_argument_mode(
      argument,
      parameters[index].arity,
      evidence,
      catalog,
      path,
    )
  }
}

///|
fn RuntimeAnfVerifier::verify_argument_mode(
  self : RuntimeAnfVerifier,
  argument : RuntimeArgument,
  expected_arity : Int,
  evidence : Array[RuntimeEvidenceParameter],
  catalog : Bool,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  let expression_arity = self.type_expression_arity(
    argument.type_expression,
    evidence,
    [],
    catalog,
    path,
  )
  let evidence_arity = self.evidence_arity_mode(
    argument.evidence,
    evidence,
    catalog,
    path,
  )
  if expression_arity != expected_arity {
    self.fail(
      EvidenceArityMismatch(expected=expected_arity, actual=expression_arity),
      path,
    )
  }
  if evidence_arity != expected_arity {
    self.fail(
      EvidenceArityMismatch(expected=expected_arity, actual=evidence_arity),
      path,
    )
  }
  let consistent = self.runtime_types.argument_is_consistent(argument) catch {
    error =>
      raise InvalidRuntimeAnf({
        kind: RuntimeTypeInstantiationFailure(error),
        path,
      })
  }
  if !consistent {
    self.fail(InvalidRuntimeArgument(argument), path)
  }
}

///|
fn RuntimeAnfVerifier::verify_type(
  self : RuntimeAnfVerifier,
  type_ : RuntimeType,
  evidence : Array[RuntimeEvidenceParameter],
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  self.verify_type_mode(type_, evidence, false, path)
}

///|
fn RuntimeAnfVerifier::verify_type_mode(
  self : RuntimeAnfVerifier,
  type_ : RuntimeType,
  evidence : Array[RuntimeEvidenceParameter],
  catalog : Bool,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  match type_ {
    Unit | Scalar(_) | ByteSequence | ByteBuffer => ()
    Data(owner, arguments) => {
      let info = self.require_type_info(owner, path)
      if info.kind != Data {
        self.fail(InvalidNominalType(owner), path)
      }
      self.verify_arguments_mode(
        arguments,
        info.evidence_parameters,
        evidence,
        catalog,
        path,
      )
    }
    Callable(parameters, result) => {
      for parameter in parameters {
        self.verify_type_mode(parameter, evidence, catalog, path)
      }
      self.verify_type_mode(result, evidence, catalog, path)
    }
    Erased(expression, witness) => {
      let expression_arity = self.type_expression_arity(
        expression,
        evidence,
        [],
        catalog,
        path,
      )
      let witness_arity = self.evidence_arity_mode(
        witness, evidence, catalog, path,
      )
      if expression_arity != 0 {
        self.fail(
          EvidenceArityMismatch(expected=0, actual=expression_arity),
          path,
        )
      }
      if witness_arity != 0 {
        self.fail(EvidenceArityMismatch(expected=0, actual=witness_arity), path)
      }
    }
    Forall(parameters, body) => {
      let outer = if catalog {
        evidence.filter(available => {
          !parameters.any(parameter => parameter.id == available.id)
        })
      } else {
        evidence
      }
      let nested = self.verify_evidence_binders(parameters, outer, path)
      self.verify_type_mode(body, nested, catalog, path)
    }
  }
}

///|
fn RuntimeAnfVerifier::verify_evidence_binders(
  self : RuntimeAnfVerifier,
  parameters : Array[RuntimeEvidenceParameter],
  scope : Array[RuntimeEvidenceParameter],
  path : Array[RuntimeAnfVerificationFrame],
) -> Array[RuntimeEvidenceParameter] raise RuntimeAnfLoweringError {
  let nested = scope.copy()
  let seen = []
  for parameter in parameters {
    if parameter.arity < 0 || parameter.id is Synthetic(_) {
      self.fail(InvalidEvidenceParameter(parameter), path)
    }
    if seen.contains(parameter.id) {
      self.fail(DuplicateEvidence(parameter.id), path)
    }
    seen.push(parameter.id)
    nested.retain(existing => existing.id != parameter.id)
    nested.push(parameter)
  }
  nested
}

///|
fn RuntimeAnfVerifier::type_expression_arity(
  self : RuntimeAnfVerifier,
  expression : RuntimeTypeExpressionId,
  evidence : Array[RuntimeEvidenceParameter],
  visiting : Array[RuntimeTypeExpressionId],
  catalog : Bool,
  path : Array[RuntimeAnfVerificationFrame],
) -> Int raise RuntimeAnfLoweringError {
  if expression.index < 0 || visiting.contains(expression) {
    self.fail(InvalidTypeExpression(expression), path)
  }
  guard self.metadata.type_expression(expression) is Some(node) else {
    self.fail(MissingTypeExpression(expression), path)
    return 0
  }
  let visiting = visiting.copy()
  visiting.push(expression)
  match node {
    Static(type_) => {
      self.verify_type_mode(type_, evidence, catalog, path)
      0
    }
    Parameter(parameter) =>
      if catalog {
        match self.metadata.evidence_parameter(parameter) {
          Some(parameter) => parameter.arity
          None => {
            self.fail(MissingEvidenceParameter(parameter), path)
            0
          }
        }
      } else {
        self.evidence_parameter_arity(parameter, evidence, path)
      }
    Apply(callee, arguments) => {
      let arity = self.type_expression_arity(
        callee, evidence, visiting, catalog, path,
      )
      if arity != arguments.length() {
        self.fail(
          EvidenceArityMismatch(expected=arity, actual=arguments.length()),
          path,
        )
      }
      for argument in arguments {
        ignore(
          self.type_expression_arity(
            argument, evidence, visiting, catalog, path,
          ),
        )
      }
      0
    }
    Lambda(parameters, body) => {
      let outer = if catalog {
        evidence.filter(available => {
          !parameters.any(parameter => parameter.id == available.id)
        })
      } else {
        evidence
      }
      let nested = self.verify_evidence_binders(parameters, outer, path)
      let body_arity = self.type_expression_arity(
        body, nested, visiting, catalog, path,
      )
      if body_arity != 0 {
        self.fail(EvidenceArityMismatch(expected=0, actual=body_arity), path)
      }
      parameters.length()
    }
  }
}

///|
fn RuntimeAnfVerifier::evidence_arity_mode(
  self : RuntimeAnfVerifier,
  witness : RuntimeEvidence,
  evidence : Array[RuntimeEvidenceParameter],
  catalog : Bool,
  path : Array[RuntimeAnfVerificationFrame],
) -> Int raise RuntimeAnfLoweringError {
  match witness {
    Static(_) => 0
    Parameter(parameter) =>
      if catalog {
        match self.metadata.evidence_parameter(parameter) {
          Some(parameter) => parameter.arity
          None => {
            self.fail(MissingEvidenceParameter(parameter), path)
            0
          }
        }
      } else {
        self.evidence_parameter_arity(parameter, evidence, path)
      }
    Apply(callee, arguments) => {
      let arity = self.evidence_arity_mode(callee, evidence, catalog, path)
      if arity != arguments.length() {
        self.fail(
          EvidenceArityMismatch(expected=arity, actual=arguments.length()),
          path,
        )
      }
      for argument in arguments {
        ignore(self.evidence_arity_mode(argument, evidence, catalog, path))
      }
      0
    }
    Lambda(parameters, body) => {
      let outer = if catalog {
        evidence.filter(available => {
          !parameters.any(parameter => parameter.id == available.id)
        })
      } else {
        evidence
      }
      let nested = self.verify_evidence_binders(parameters, outer, path)
      let body_arity = self.evidence_arity_mode(body, nested, catalog, path)
      if body_arity != 0 {
        self.fail(EvidenceArityMismatch(expected=0, actual=body_arity), path)
      }
      parameters.length()
    }
  }
}

///|
fn RuntimeAnfVerifier::evidence_parameter_arity(
  self : RuntimeAnfVerifier,
  parameter : RuntimeEvidenceId,
  evidence : Array[RuntimeEvidenceParameter],
  path : Array[RuntimeAnfVerificationFrame],
) -> Int raise RuntimeAnfLoweringError {
  for available in evidence.rev_iter() {
    if available.id == parameter {
      return available.arity
    }
  }
  if self.metadata.evidence_parameter(parameter) is None {
    self.fail(MissingEvidenceParameter(parameter), path)
  } else {
    self.fail(UnboundEvidence(parameter), path)
  }
  0
}

///|
fn RuntimeAnfVerifier::require_value_info(
  self : RuntimeAnfVerifier,
  value : @buslane.ValueId,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeValueInfo raise RuntimeAnfLoweringError {
  match self.metadata.value_info(value) {
    Some(info) => info
    None => {
      self.fail(MissingValueMetadata(value), path)
      { type_: Unit, }
    }
  }
}

///|
fn RuntimeAnfVerifier::require_type_info(
  self : RuntimeAnfVerifier,
  type_ : @buslane.TypeId,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeDataInfo raise RuntimeAnfLoweringError {
  match self.metadata.type_info(type_) {
    Some(info) => info
    None => {
      self.fail(MissingTypeMetadata(type_), path)
      { kind: Data, evidence_parameters: [], constructors: [], }
    }
  }
}

///|
fn RuntimeAnfVerifier::require_data_constructor_info(
  self : RuntimeAnfVerifier,
  data_constructor : @buslane.DataConId,
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeDataConstructorInfo raise RuntimeAnfLoweringError {
  match self.metadata.data_constructor_info(data_constructor) {
    Some(info) => info
    None => {
      self.fail(MissingDataConstructorMetadata(data_constructor), path)
      {
        owner: { index: -1, },
        hidden_evidence_parameters: [],
        payload_types: [],
      }
    }
  }
}

///|
fn RuntimeAnfVerifier::require_same_type(
  self : RuntimeAnfVerifier,
  expected : RuntimeType,
  actual : RuntimeType,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  if !self.metadata.types_representation_equivalent(expected, actual) {
    self.fail(RuntimeTypeMismatch(expected~, actual~), path)
  }
}

///|
fn RuntimeAnfVerifier::instantiate_runtime_type(
  self : RuntimeAnfVerifier,
  type_ : RuntimeType,
  substitutions : Array[(RuntimeEvidenceId, RuntimeArgument)],
  path : Array[RuntimeAnfVerificationFrame],
) -> RuntimeType raise RuntimeAnfLoweringError {
  self.runtime_types.instantiate_type(type_, substitutions) catch {
    error =>
      raise InvalidRuntimeAnf({
        kind: RuntimeTypeInstantiationFailure(error),
        path,
      })
  }
}

///|
fn runtime_substitution_entries(
  parameters : Array[RuntimeEvidenceParameter],
  arguments : Array[RuntimeArgument],
) -> Array[(RuntimeEvidenceId, RuntimeArgument)] {
  let entries = []
  for index in 0..<parameters.length().min(arguments.length()) {
    entries.push((parameters[index].id, arguments[index]))
  }
  entries
}

///|
fn RuntimeAnfVerifier::claim_value(
  self : RuntimeAnfVerifier,
  value : @buslane.ValueId,
  scope : RuntimeAnfScope,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  if scope.values.contains(value) {
    self.fail(DuplicateValue(value), path)
  }
  ignore(self.require_value_info(value, path))
}

///|
fn RuntimeAnfVerifier::claim_temp(
  self : RuntimeAnfVerifier,
  temp : AnfTempId,
  path : Array[RuntimeAnfVerificationFrame],
) -> Unit raise RuntimeAnfLoweringError {
  if temp.index < 0 || self.seen_temps.contains(temp) {
    self.fail(DuplicateTemp(temp), path)
  }
  self.seen_temps.push(temp)
}

///|
fn RuntimeAnfScope::with_value(
  self : RuntimeAnfScope,
  value : @buslane.ValueId,
) -> RuntimeAnfScope {
  if self.values.contains(value) {
    return self
  }
  let values = self.values.copy()
  values.push(value)
  { ..self, values, }
}

///|
fn RuntimeAnfScope::with_values(
  self : RuntimeAnfScope,
  additions : Array[@buslane.ValueId],
) -> RuntimeAnfScope {
  let mut nested = self
  for value in additions {
    nested = nested.with_value(value)
  }
  nested
}

///|
fn RuntimeAnfScope::with_top_values(
  self : RuntimeAnfScope,
  values : Array[@buslane.ValueId],
) -> RuntimeAnfScope {
  self.with_values(values)
}

///|
fn RuntimeAnfScope::with_temp(
  self : RuntimeAnfScope,
  temp : AnfTempId,
  type_ : RuntimeType,
) -> RuntimeAnfScope {
  let temps = self.temps.copy()
  temps.push((temp, type_))
  { ..self, temps, }
}

///|
fn RuntimeAnfScope::with_evidence(
  self : RuntimeAnfScope,
  evidence : Array[RuntimeEvidenceParameter],
) -> RuntimeAnfScope {
  { ..self, evidence, }
}

///|
fn RuntimeAnfScope::temp_type(
  self : RuntimeAnfScope,
  temp : AnfTempId,
) -> RuntimeType? {
  for entry in self.temps.rev_iter() {
    if entry.0 == temp {
      return Some(entry.1)
    }
  }
  None
}

///|
fn anf_verification_binding_rhs(binding : AnfBinding) -> AnfRhs {
  match binding {
    Value(rhs~, ..) | Temp(rhs~, ..) => rhs
  }
}

///|
fn runtime_literal_type(literal : @buslane.Literal) -> RuntimeType {
  match literal {
    Unit => Unit
    Bool(_) => Scalar(Bool)
    I64(_) => Scalar(I64)
    I32(_) => Scalar(I32)
    Char(_) => Scalar(Char)
    F64(_) => Scalar(F64)
    F32(_) => Scalar(F32)
    String(_) => ByteSequence
  }
}
