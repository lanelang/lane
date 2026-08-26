///|
/// Physical-Lowering-owned arena for runtime type expressions derived while substituting
/// and beta-reducing Runtime ANF. The immutable Runtime ANF catalog seeds this
/// arena but is never extended by a backend consumer.
priv struct RuntimeTypeArena {
  expressions : Array[@anf.RuntimeTypeExpression]
}

///|
fn RuntimeTypeArena::from_metadata(
  metadata : @anf.RuntimeMetadata,
) -> RuntimeTypeArena {
  let expressions = []
  for expression in metadata.type_expressions() {
    expressions.push(expression)
  }
  { expressions, }
}

///|
fn RuntimeTypeArena::type_expression(
  self : RuntimeTypeArena,
  expression : @anf.RuntimeTypeExpressionId,
) -> @anf.RuntimeTypeExpression? {
  self.expressions.get(expression.index)
}

///|
fn RuntimeTypeArena::intern(
  self : RuntimeTypeArena,
  expression : @anf.RuntimeTypeExpression,
) -> @anf.RuntimeTypeExpressionId {
  for index, existing in self.expressions {
    if existing == expression {
      return { index, }
    }
  }
  let id : @anf.RuntimeTypeExpressionId = { index: self.expressions.length(), }
  self.expressions.push(expression)
  id
}
