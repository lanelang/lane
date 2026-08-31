///|
priv struct RuntimeGenericPlan {
  metadata : @buslane.MetadataRegistry
  facts : @buslane.ExpressionFactsQuery
  live : Array[Bool]
  type_expressions : Array[RuntimeTypeExpression]
  mut changed : Bool
}

///|
fn runtime_generic_plan(
  program : @buslane.Program,
  retained_terms : Array[@buslane.TopTerm],
) -> RuntimeGenericPlan raise RuntimeAnfLoweringError {
  let plan : RuntimeGenericPlan = {
    metadata: program.metadata,
    facts: @buslane.ExpressionFactsQuery::new(program),
    live: Array::make(program.metadata.type_parameters.length(), false),
    type_expressions: [],
    changed: false,
  }
  while true {
    plan.changed = false
    plan.observe_metadata()
    for term in retained_terms {
      plan.observe_top_term(term)
    }
    if !plan.changed {
      break
    }
  }
  plan
}

///|
fn RuntimeGenericPlan::is_live(
  self : RuntimeGenericPlan,
  parameter : @buslane.TypeParameterId,
) -> Bool {
  if parameter.index < 0 {
    true
  } else {
    match self.live.get(parameter.index) {
      Some(live) => live
      None => true
    }
  }
}

///|
fn RuntimeGenericPlan::mark_live(
  self : RuntimeGenericPlan,
  parameter : @buslane.TypeParameterId,
) -> Unit {
  guard parameter.index >= 0 && parameter.index < self.live.length() else {
    return
  }
  if !self.live[parameter.index] {
    self.live[parameter.index] = true
    self.changed = true
  }
}

///|
fn RuntimeGenericPlan::observe_metadata(self : RuntimeGenericPlan) -> Unit {
  for info in self.metadata.values {
    self.observe_type(info.type_)
  }
  for info in self.metadata.data_constructors {
    for type_ in info.payload_types {
      self.observe_type(type_)
    }
  }
}

///|
fn RuntimeGenericPlan::observe_top_term(
  self : RuntimeGenericPlan,
  term : @buslane.TopTerm,
) -> Unit raise RuntimeAnfLoweringError {
  match term {
    Let(value, expression) => {
      self.link_value_abstraction(value, expression)
      self.observe_expr(expression)
    }
    LetRec(bindings) =>
      for binding in bindings {
        self.link_value_abstraction(binding.id, binding.rhs)
        self.observe_expr(binding.rhs)
      }
    External(_) => ()
  }
}

///|
fn RuntimeGenericPlan::link_value_abstraction(
  self : RuntimeGenericPlan,
  value : @buslane.ValueId,
  expression : @buslane.Expr,
) -> Unit {
  guard self.metadata.value_info(value) is Some(info) else { return }
  let declared = outer_forall_parameters(info.type_)
  let implemented = outer_type_lambda_parameters(expression)
  for index in 0..<declared.length().min(implemented.length()) {
    let left = declared[index]
    let right = implemented[index]
    if self.is_live(left) {
      self.mark_live(right)
    }
    if self.is_live(right) {
      self.mark_live(left)
    }
  }
}

///|
fn outer_forall_parameters(
  type_ : @buslane.Type,
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  let mut current = type_
  while current is Forall(bound, body) {
    parameters.append(bound)
    current = body
  }
  parameters
}

///|
fn outer_type_lambda_parameters(
  expression : @buslane.Expr,
) -> Array[@buslane.TypeParameterId] {
  let parameters = []
  let mut current = expression
  while current is TypeLambda(bound, body) {
    parameters.append(bound)
    current = body
  }
  parameters
}

///|
fn RuntimeGenericPlan::observe_expr(
  self : RuntimeGenericPlan,
  expression : @buslane.Expr,
) -> Unit raise RuntimeAnfLoweringError {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) => {
      self.observe_type(function.result_type)
      self.observe_expr(function.body)
    }
    Call(callee, arguments) => {
      self.observe_expr(callee)
      for argument in arguments {
        self.observe_expr(argument)
      }
    }
    TypeLambda(_, body) => self.observe_expr(body)
    TypeApply(callee, arguments) => {
      self.observe_expr(callee)
      let parameters = self.expression_type_parameters(callee)
      self.observe_generic_arguments(parameters, arguments)
    }
    Construct(construct) => {
      guard self.metadata.data_constructor_info(construct.data_constructor)
        is Some(info) else {
        return
      }
      guard self.metadata.type_info(info.owner) is Some(owner) else { return }
      self.observe_generic_arguments(owner.parameters, construct.type_arguments)
      self.observe_generic_arguments(
        info.hidden_type_parameters,
        construct.hidden_witnesses,
      )
      for payload in construct.payloads {
        self.observe_expr(payload)
      }
    }
    Let(value, initializer, body) => {
      self.link_value_abstraction(value, initializer)
      self.observe_expr(initializer)
      self.observe_expr(body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.link_value_abstraction(binding.id, binding.rhs)
        self.observe_expr(binding.rhs)
      }
      self.observe_expr(body)
    }
    Match(match_) => {
      self.observe_type(match_.result_type)
      self.observe_expr(match_.scrutinee)
      for alternative in match_.alternatives {
        self.link_alternative_binders(alternative)
        self.observe_expr(alternative.body)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.observe_expr(payload)
      }
    Handle(handle) => {
      self.observe_type(handle.result_type)
      self.observe_expr(handle.body)
      self.observe_expr(handle.final_body)
      for table in handle.handlers {
        for alternative in table.operations {
          self.observe_expr(alternative.body)
        }
      }
    }
  }
}

///|
fn RuntimeGenericPlan::expression_type_parameters(
  self : RuntimeGenericPlan,
  expression : @buslane.Expr,
) -> Array[@buslane.TypeParameterId] raise RuntimeAnfLoweringError {
  let type_ = match self.facts.synthesize(expression) {
    Ok(facts) => facts.type_()
    Err(result) => raise InvalidExpressionMetadata(result)
  }
  match type_ {
    Forall(parameters, _) => parameters
    _ => []
  }
}

///|
fn RuntimeGenericPlan::runtime_expression_type(
  self : RuntimeGenericPlan,
  expression : @buslane.Expr,
) -> RuntimeType raise RuntimeAnfLoweringError {
  match self.facts.synthesize(expression) {
    Ok(facts) => self.runtime_type(facts.type_())
    Err(result) => raise InvalidExpressionMetadata(result)
  }
}

///|
fn RuntimeGenericPlan::observe_generic_arguments(
  self : RuntimeGenericPlan,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Unit {
  for index in 0..<parameters.length().min(arguments.length()) {
    if self.is_live(parameters[index]) {
      self.observe_argument(arguments[index])
    }
  }
}

///|
fn RuntimeGenericPlan::observe_argument(
  self : RuntimeGenericPlan,
  argument : @buslane.GenericArgument,
) -> Unit {
  match argument {
    TypeArgument(type_) => self.observe_type(type_)
    EffectArgument(_) => ()
  }
}

///|
fn RuntimeGenericPlan::observe_type(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> Unit {
  match type_ {
    Primitive(_) | Constructor(_) => ()
    Parameter(parameter) => self.mark_live(parameter)
    Apply(callee, arguments) => {
      self.observe_type(callee)
      match self.type_application_parameters(callee) {
        Some(parameters) =>
          self.observe_generic_arguments(parameters, arguments)
        None =>
          for argument in arguments {
            self.observe_argument(argument)
          }
      }
    }
    TypeLambda(parameters, body) => {
      // A type-level lambda is a runtime layout constructor. Its callable
      // arity is fixed by its kind even when the body ignores an argument.
      for parameter in parameters {
        guard self.metadata.type_parameter_info(parameter) is Some(info) else {
          continue
        }
        if runtime_kind_requires_evidence(info.kind) {
          self.mark_live(parameter)
        }
      }
      self.observe_type(body)
    }
    Forall(_, body) => self.observe_type(body)
    Function(parameters, result, _) => {
      for parameter in parameters {
        self.observe_type(parameter)
      }
      self.observe_type(result)
    }
  }
}

///|
fn RuntimeGenericPlan::type_application_parameters(
  self : RuntimeGenericPlan,
  callee : @buslane.Type,
) -> Array[@buslane.TypeParameterId]? {
  match callee {
    Constructor(type_) =>
      self.metadata.type_info(type_).map(info => info.parameters)
    TypeLambda(parameters, _) => Some(parameters)
    _ => None
  }
}

///|
fn RuntimeGenericPlan::link_alternative_binders(
  self : RuntimeGenericPlan,
  alternative : @buslane.Alternative,
) -> Unit {
  guard alternative.alt_constructor is DataCon(data_constructor) else { return }
  guard self.metadata.data_constructor_info(data_constructor) is Some(info) else {
    return
  }
  for
    index in 0..<info.hidden_type_parameters
    .length()
    .min(alternative.type_binders.length()) {
    let declared = info.hidden_type_parameters[index]
    let opened = alternative.type_binders[index]
    if self.is_live(declared) {
      self.mark_live(opened)
    }
    if self.is_live(opened) {
      self.mark_live(declared)
    }
  }
}

///|
fn RuntimeGenericPlan::runtime_evidence_parameter(
  self : RuntimeGenericPlan,
  parameter : @buslane.TypeParameterId,
) -> RuntimeEvidenceParameter? {
  guard self.is_live(parameter) else { return None }
  self.runtime_lambda_parameter(parameter)
}

///|
fn RuntimeGenericPlan::runtime_lambda_parameter(
  self : RuntimeGenericPlan,
  parameter : @buslane.TypeParameterId,
) -> RuntimeEvidenceParameter? {
  guard self.metadata.type_parameter_info(parameter) is Some(info) else {
    return None
  }
  let arity = match info.kind {
    Type => 0
    Function(parameters, Type) => runtime_kind_evidence_arity(parameters)
    Effect | Function(_, Effect) | Function(_, Function(_, _)) => return None
  }
  Some({ id: Projected(parameter.index), arity, })
}

///|
fn RuntimeGenericPlan::runtime_evidence_parameters(
  self : RuntimeGenericPlan,
  parameters : Array[@buslane.TypeParameterId],
) -> Array[RuntimeEvidenceParameter] {
  parameters.filter_map(parameter => self.runtime_evidence_parameter(parameter))
}

///|
fn RuntimeGenericPlan::runtime_lambda_parameters(
  self : RuntimeGenericPlan,
  parameters : Array[@buslane.TypeParameterId],
) -> Array[RuntimeEvidenceParameter] {
  parameters.filter_map(parameter => self.runtime_lambda_parameter(parameter))
}

///|
fn runtime_kind_requires_evidence(kind : @buslane.Kind) -> Bool {
  match kind {
    Type | Function(_, Type) => true
    Effect | Function(_, Effect) | Function(_, Function(_, _)) => false
  }
}

///|
fn runtime_kind_evidence_arity(kinds : Array[@buslane.Kind]) -> Int {
  kinds.fold(init=0, fn(total, kind) {
    if runtime_kind_requires_evidence(kind) {
      total + 1
    } else {
      total
    }
  })
}

///|
fn RuntimeGenericPlan::runtime_arguments(
  self : RuntimeGenericPlan,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Array[RuntimeArgument] raise RuntimeAnfLoweringError {
  let evidence = []
  for index in 0..<parameters.length().min(arguments.length()) {
    if self.runtime_evidence_parameter(parameters[index]) is Some(_) {
      guard arguments[index] is TypeArgument(type_) else { continue }
      evidence.push(self.runtime_argument(type_))
    }
  }
  evidence
}

///|
fn RuntimeGenericPlan::intern_type_expression(
  self : RuntimeGenericPlan,
  expression : RuntimeTypeExpression,
) -> RuntimeTypeExpressionId {
  for index, existing in self.type_expressions {
    if existing == expression {
      return { index, }
    }
  }
  let id : RuntimeTypeExpressionId = { index: self.type_expressions.length(), }
  self.type_expressions.push(expression)
  id
}

///|
fn RuntimeGenericPlan::runtime_argument(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> RuntimeArgument raise RuntimeAnfLoweringError {
  {
    type_expression: self.runtime_type_expression(type_),
    evidence: self.runtime_layout_evidence(type_),
  }
}

///|
fn RuntimeGenericPlan::runtime_type_expression(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> RuntimeTypeExpressionId raise RuntimeAnfLoweringError {
  let normalized = type_.normalize() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
  let normalized = self.eta_expand_runtime_constructor(normalized)
  match normalized {
    Parameter(parameter) =>
      self.intern_type_expression(Parameter(Projected(parameter.index)))
    Apply(Parameter(parameter), arguments) => {
      guard self.metadata.type_parameter_info(parameter) is Some(info) else {
        return self.intern_type_expression(
          Parameter(Projected(parameter.index)),
        )
      }
      guard info.kind is Function(kinds, _) else {
        return self.intern_type_expression(
          Parameter(Projected(parameter.index)),
        )
      }
      let callee = self.intern_type_expression(
        Parameter(Projected(parameter.index)),
      )
      let runtime_arguments = []
      for index in 0..<kinds.length().min(arguments.length()) {
        if runtime_kind_requires_evidence(kinds[index]) {
          guard arguments[index] is TypeArgument(argument) else { continue }
          runtime_arguments.push(self.runtime_type_expression(argument))
        }
      }
      self.intern_type_expression(Apply(callee, runtime_arguments))
    }
    TypeLambda(parameters, body) =>
      self.intern_type_expression(
        Lambda(
          self.runtime_lambda_parameters(parameters),
          self.runtime_type_expression(body),
        ),
      )
    type_ => {
      let runtime = self.runtime_type(type_)
      match runtime {
        Erased(expression, _) => expression
        _ => self.intern_type_expression(Static(runtime))
      }
    }
  }
}

///|
fn RuntimeGenericPlan::runtime_kind_arguments(
  self : RuntimeGenericPlan,
  kinds : Array[@buslane.Kind],
  arguments : Array[@buslane.GenericArgument],
) -> Array[RuntimeEvidence] raise RuntimeAnfLoweringError {
  let evidence = []
  for index in 0..<kinds.length().min(arguments.length()) {
    if runtime_kind_requires_evidence(kinds[index]) {
      guard arguments[index] is TypeArgument(type_) else { continue }
      evidence.push(self.runtime_layout_evidence(type_))
    }
  }
  evidence
}

///|
fn RuntimeGenericPlan::runtime_layout_evidence(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> RuntimeEvidence raise RuntimeAnfLoweringError {
  let normalized = type_.normalize() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
  let normalized = self.eta_expand_runtime_constructor(normalized)
  match normalized {
    Parameter(parameter) => Parameter(Projected(parameter.index))
    Apply(Parameter(parameter), arguments) => {
      guard self.metadata.type_parameter_info(parameter) is Some(info) else {
        return Parameter(Projected(parameter.index))
      }
      guard info.kind is Function(kinds, _) else {
        return Parameter(Projected(parameter.index))
      }
      Apply(
        Parameter(Projected(parameter.index)),
        self.runtime_kind_arguments(kinds, arguments),
      )
    }
    TypeLambda(parameters, body) =>
      Lambda(
        self.runtime_lambda_parameters(parameters),
        self.runtime_layout_evidence(body),
      )
    type_ => {
      let runtime = self.runtime_type(type_)
      match runtime {
        Erased(_, evidence) => evidence
        _ =>
          match runtime.layout() {
            Some(layout) => Static(layout)
            None =>
              raise InvalidRuntimeProjection(
                detail="runtime value has neither a concrete layout nor erased evidence",
              )
          }
      }
    }
  }
}

///|
fn RuntimeGenericPlan::eta_expand_runtime_constructor(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> @buslane.Type {
  let (owner, supplied) = match type_ {
    Constructor(owner) => (owner, [])
    Apply(Constructor(owner), arguments) => (owner, arguments)
    _ => return type_
  }
  guard self.metadata.type_info(owner) is Some(info) &&
    supplied.length() < info.parameters.length() else {
    return type_
  }
  let arguments = supplied.copy()
  let remaining = []
  for index in supplied.length()..<info.parameters.length() {
    let parameter = info.parameters[index]
    remaining.push(parameter)
    guard self.metadata.type_parameter_info(parameter) is Some(parameter_info) else {
      return type_
    }
    match parameter_info.kind {
      Effect => arguments.push(EffectArgument(Parameter(parameter)))
      _ => arguments.push(TypeArgument(Parameter(parameter)))
    }
  }
  TypeLambda(remaining, Apply(Constructor(owner), arguments))
}

///|
fn RuntimeGenericPlan::runtime_type(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> RuntimeType raise RuntimeAnfLoweringError {
  let normalized = type_.normalize() catch {
    error => raise TypeNormalizationCompilerDefect(error)
  }
  self.normalized_runtime_type(normalized)
}

///|
fn RuntimeGenericPlan::normalized_runtime_type(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> RuntimeType raise RuntimeAnfLoweringError {
  match type_ {
    Primitive(Unit) => Unit
    Primitive(Bool) => Scalar(Bool)
    Primitive(I64) => Scalar(I64)
    Primitive(I32) => Scalar(I32)
    Primitive(Char) => Scalar(Char)
    Primitive(F64) => Scalar(F64)
    Primitive(F32) => Scalar(F32)
    Primitive(Byte) => Scalar(Byte)
    Primitive(String) | Primitive(Bytes) => ByteSequence
    Primitive(ByteBuffer) => ByteBuffer
    Parameter(parameter) => {
      let expression = self.intern_type_expression(
        Parameter(Projected(parameter.index)),
      )
      Erased(expression, Parameter(Projected(parameter.index)))
    }
    Constructor(owner) | Apply(Constructor(owner), _) => {
      guard self.metadata.type_info(owner) is Some(info) else {
        raise MissingType(owner)
      }
      match info.flavor {
        Data => {
          let arguments = match type_ {
            Apply(_, arguments) =>
              self.runtime_arguments(info.parameters, arguments)
            _ => []
          }
          Data(owner, arguments)
        }
        External =>
          raise InvalidRuntimeProjection(
            detail="external nominal values have no WebAssembly representation",
          )
      }
    }
    Apply(Parameter(parameter), arguments) => {
      guard self.metadata.type_parameter_info(parameter) is Some(info) else {
        let expression = self.intern_type_expression(
          Parameter(Projected(parameter.index)),
        )
        return Erased(expression, Parameter(Projected(parameter.index)))
      }
      guard info.kind is Function(kinds, _) else {
        let expression = self.intern_type_expression(
          Parameter(Projected(parameter.index)),
        )
        return Erased(expression, Parameter(Projected(parameter.index)))
      }
      let expression = self.runtime_type_expression(type_)
      Erased(
        expression,
        Apply(
          Parameter(Projected(parameter.index)),
          self.runtime_kind_arguments(kinds, arguments),
        ),
      )
    }
    Function(parameters, result, _) =>
      Callable(
        parameters.map(parameter => self.runtime_type(parameter)),
        self.runtime_type(result),
      )
    Forall(parameters, body) => {
      let evidence = self.runtime_evidence_parameters(parameters)
      let body = self.runtime_type(body)
      if evidence.is_empty() {
        body
      } else {
        Forall(evidence, body)
      }
    }
    Apply(_, _) | TypeLambda(_, _) =>
      raise InvalidRuntimeProjection(
        detail="normalized runtime type retained type-level computation",
      )
  }
}

///|
fn RuntimeGenericPlan::runtime_metadata(
  self : RuntimeGenericPlan,
) -> RuntimeMetadata raise RuntimeAnfLoweringError {
  let values = self.metadata.values.map(info => {
    type_: self.runtime_type(info.type_),
  })
  let types = self.metadata.types.map(info => {
    kind: match info.flavor {
      Data => Data
      External => OpaqueReference
    },
    evidence_parameters: self.runtime_evidence_parameters(info.parameters),
    constructors: info.constructors,
  })
  let data_constructors = self.metadata.data_constructors.map(info => {
    owner: info.owner,
    hidden_evidence_parameters: self.runtime_evidence_parameters(
      info.hidden_type_parameters,
    ),
    payload_types: info.payload_types.map(type_ => self.runtime_type(type_)),
  })
  let evidence_parameters = []
  for index in 0..<self.metadata.type_parameters.length() {
    let parameter = self.runtime_evidence_parameter({ index, })
    if parameter is Some(parameter) {
      ignore(self.intern_type_expression(Parameter(parameter.id)))
    }
    evidence_parameters.push(parameter)
  }
  for info in self.metadata.values {
    ignore(self.runtime_type_expression(info.type_))
  }
  for info in self.metadata.data_constructors {
    for type_ in info.payload_types {
      ignore(self.runtime_type_expression(type_))
    }
  }
  {
    values,
    types,
    data_constructors,
    evidence_parameters,
    type_expressions: self.type_expressions.copy(),
  }
}
