///|
priv struct RuntimeGenericPlan {
  metadata : @buslane.MetadataRegistry
  facts : @buslane.ExpressionFactsQuery
  live : Array[Bool]
  mut changed : Bool
}

///|
fn runtime_generic_plan(
  program : @buslane.Program,
) -> RuntimeGenericPlan raise RuntimeAnfLoweringError {
  let plan : RuntimeGenericPlan = {
    metadata: program.metadata,
    facts: @buslane.ExpressionFactsQuery::new(program),
    live: Array::make(program.metadata.type_parameters.length(), false),
    changed: false,
  }
  while true {
    plan.changed = false
    plan.observe_metadata()
    for term in program.terms {
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
    TypeLambda(_, body) | Forall(_, body) => self.observe_type(body)
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
fn RuntimeGenericPlan::retained_parameters(
  self : RuntimeGenericPlan,
  parameters : Array[@buslane.TypeParameterId],
) -> Array[@buslane.TypeParameterId] {
  parameters.filter(parameter => self.is_live(parameter))
}

///|
fn RuntimeGenericPlan::project_arguments(
  self : RuntimeGenericPlan,
  parameters : Array[@buslane.TypeParameterId],
  arguments : Array[@buslane.GenericArgument],
) -> Array[@buslane.GenericArgument] raise RuntimeAnfLoweringError {
  let projected = []
  for index in 0..<parameters.length().min(arguments.length()) {
    if self.is_live(parameters[index]) {
      projected.push(self.project_argument(arguments[index]))
    }
  }
  projected
}

///|
fn RuntimeGenericPlan::project_argument(
  self : RuntimeGenericPlan,
  argument : @buslane.GenericArgument,
) -> @buslane.GenericArgument raise RuntimeAnfLoweringError {
  match argument {
    TypeArgument(type_) => TypeArgument(self.project_type(type_))
    EffectArgument(_) => EffectArgument(Empty)
  }
}

///|
fn RuntimeGenericPlan::project_type(
  self : RuntimeGenericPlan,
  type_ : @buslane.Type,
) -> @buslane.Type raise RuntimeAnfLoweringError {
  match type_ {
    Primitive(_) | Parameter(_) | Constructor(_) => type_
    Apply(TypeLambda(_, _) as callee, arguments) => {
      let projected = @buslane.Type::Apply(
        self.project_type(callee),
        arguments.map(argument => self.project_argument(argument)),
      )
      projected.normalize() catch {
        error => raise TypeNormalizationCompilerDefect(error)
      }
    }
    Apply(callee, arguments) => {
      let projected_callee = self.project_type(callee)
      let projected_arguments = match self.type_application_parameters(callee) {
        Some(parameters) => self.project_arguments(parameters, arguments)
        None => arguments.map(argument => self.project_argument(argument))
      }
      if projected_arguments.is_empty() {
        projected_callee
      } else {
        Apply(projected_callee, projected_arguments)
      }
    }
    TypeLambda(parameters, body) =>
      TypeLambda(parameters, self.project_type(body))
    Function(parameters, result, _) =>
      Function(
        parameters.map(parameter => self.project_type(parameter)),
        self.project_type(result),
        Empty,
      )
    Forall(parameters, body) => {
      let projected_body = self.project_type(body)
      let retained = self.retained_parameters(parameters)
      if retained.is_empty() {
        projected_body
      } else {
        Forall(retained, projected_body)
      }
    }
  }
}

///|
fn RuntimeGenericPlan::project_metadata(
  self : RuntimeGenericPlan,
) -> @buslane.MetadataRegistry raise RuntimeAnfLoweringError {
  let metadata = self.metadata.snapshot()
  for index in 0..<metadata.types.length() {
    let info = metadata.types[index]
    metadata.types[index] = {
      ..info,
      parameters: self.retained_parameters(info.parameters),
    }
  }
  for index in 0..<metadata.values.length() {
    let info = metadata.values[index]
    metadata.values[index] = { ..info, type_: self.project_type(info.type_) }
  }
  for index in 0..<metadata.data_constructors.length() {
    let info = metadata.data_constructors[index]
    metadata.data_constructors[index] = {
      ..info,
      hidden_type_parameters: self.retained_parameters(
        info.hidden_type_parameters,
      ),
      payload_types: info.payload_types.map(type_ => self.project_type(type_)),
    }
  }
  metadata.effects.clear()
  metadata.operations.clear()
  metadata
}
