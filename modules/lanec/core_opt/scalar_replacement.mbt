///|
/// Validates and rewrites the complete lexical use closure of one local
/// constructor. Failure leaves the original allocation untouched; success
/// proves that every use was a destructuring match and records one shared field
/// family for all projections.
priv struct LocalAggregateRewriter {
  aggregate : @buslane.ValueId
  construct : @buslane.ConstructExpr
  mut fields : Array[@buslane.ValueId]?
}

///|
/// Replaces the aggregate at its original evaluation point. Payload lets keep
/// left-to-right, exactly-once evaluation even when the body projects a field
/// more than once.
fn scalar_replace_local_construct(
  value : @buslane.ValueId,
  construct : @buslane.ConstructExpr,
  body : @buslane.Expr,
) -> @buslane.Expr? {
  let rewriter : LocalAggregateRewriter = {
    aggregate: value,
    construct,
    fields: None,
  }
  guard rewriter.rewrite(body) is Some(body) &&
    rewriter.fields is Some(fields) &&
    fields.length() == construct.payloads.length() else {
    return None
  }
  let mut result = body
  for index = fields.length() - 1; index >= 0; index = index - 1 {
    result = Let(fields[index], construct.payloads[index], result)
  }
  Some(result)
}

///|
fn LocalAggregateRewriter::rewrite(
  self : LocalAggregateRewriter,
  expression : @buslane.Expr,
) -> @buslane.Expr? {
  match expression {
    Ref(value) => if value == self.aggregate { None } else { Some(expression) }
    Literal(_) => Some(expression)
    Function(function) =>
      if count_value_uses(function.body, self.aggregate) == 0 {
        Some(expression)
      } else {
        None
      }
    Call(callee, arguments) => {
      guard self.rewrite(callee) is Some(callee) else { return None }
      let rewritten_arguments = []
      for argument in arguments {
        guard self.rewrite(argument) is Some(argument) else { return None }
        rewritten_arguments.push(argument)
      }
      Some(Call(callee, rewritten_arguments))
    }
    TypeLambda(_, body) =>
      if count_value_uses(body, self.aggregate) == 0 {
        Some(expression)
      } else {
        None
      }
    TypeApply(callee, arguments) =>
      self.rewrite(callee).map(callee => TypeApply(callee, arguments))
    Construct(construct) => {
      let payloads = []
      for payload in construct.payloads {
        guard self.rewrite(payload) is Some(payload) else { return None }
        payloads.push(payload)
      }
      Some(Construct({ ..construct, payloads, }))
    }
    Let(value, initializer, body) => {
      guard self.rewrite(initializer) is Some(initializer) else { return None }
      guard self.rewrite(body) is Some(body) else { return None }
      Some(Let(value, initializer, body))
    }
    LetRec(bindings, body) => {
      if count_value_uses(expression, self.aggregate) != 0 {
        return None
      }
      Some(LetRec(bindings, body))
    }
    Match(match_) => {
      if match_.scrutinee is Ref(value) && value == self.aggregate {
        return self.rewrite_projection(match_)
      }
      guard self.rewrite(match_.scrutinee) is Some(scrutinee) else {
        return None
      }
      let alternatives = []
      for alternative in match_.alternatives {
        guard self.rewrite(alternative.body) is Some(body) else { return None }
        alternatives.push({ ..alternative, body, })
      }
      Some(Match({ ..match_, scrutinee, alternatives, }))
    }
    Perform(perform) => {
      let payloads = []
      for payload in perform.payloads {
        guard self.rewrite(payload) is Some(payload) else { return None }
        payloads.push(payload)
      }
      Some(Perform({ ..perform, payloads, }))
    }
    Handle(handle) => {
      guard self.rewrite(handle.body) is Some(body) else { return None }
      guard self.rewrite(handle.final_body) is Some(final_body) else {
        return None
      }
      let handlers = []
      for table in handle.handlers {
        let operations = []
        for operation in table.operations {
          guard self.rewrite(operation.body) is Some(body) else { return None }
          operations.push({ ..operation, body, })
        }
        handlers.push({ ..table, operations, })
      }
      Some(Handle({ ..handle, body, final_body, handlers, }))
    }
    Resume(value) =>
      if value == self.aggregate {
        None
      } else {
        Some(expression)
      }
  }
}

///|
fn LocalAggregateRewriter::rewrite_projection(
  self : LocalAggregateRewriter,
  match_ : @buslane.MatchExpr,
) -> @buslane.Expr? {
  guard find_alternative(
      match_.alternatives,
      DataCon(self.construct.data_constructor),
    )
    is Some(alternative) &&
    alternative.type_binders.is_empty() &&
    alternative.value_binders.length() == self.construct.payloads.length() &&
    count_value_uses(alternative.body, match_.binder) == 0 else {
    return None
  }
  let fields = match self.fields {
    Some(fields) => fields
    None => {
      self.fields = Some(alternative.value_binders)
      alternative.value_binders
    }
  }
  guard self.rewrite(alternative.body) is Some(body) else { return None }
  let mut result = body
  for index = fields.length() - 1; index >= 0; index = index - 1 {
    if alternative.value_binders[index] != fields[index] {
      result = Let(alternative.value_binders[index], Ref(fields[index]), result)
    }
  }
  Some(result)
}
