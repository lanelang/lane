///|
pub fn CheckedExpr::for_each_child_expr(
  self : CheckedExpr,
  visit : (CheckedExpr) -> Unit,
) -> Unit {
  match self {
    Literal(_) | Value(_) | CompilerIntrinsic(_) | ExternBinding(_) => ()
    FunctionLiteral(body~, ..) => visit(body)
    GenericApplication(callee~, ..) => visit(callee)
    Block(items~, result~, ..) => {
      for item in items {
        item.for_each_child_expr(visit)
      }
      visit(result)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      visit(condition)
      visit(then_branch)
      visit(else_branch)
    }
    Match(scrutinee~, arms~, ..) => {
      visit(scrutinee)
      for arm in arms {
        visit(arm.body)
      }
    }
    Call(callee~, arguments~, ..) => {
      visit(callee)
      for argument in arguments {
        visit(argument.value)
      }
    }
    OperationCall(arguments~, ..) =>
      for argument in arguments {
        visit(argument)
      }
    Handler(body~, handlers~, final_branch~, ..) => {
      if body is Some(body) {
        visit(body)
      }
      for handler in handlers {
        for operation in handler.operations {
          if operation.body is Some(body) {
            visit(body)
          }
        }
      }
      if final_branch.body is Some(body) {
        visit(body)
      }
    }
    Field(base~, ..) => visit(base)
    StructLiteral(fields~, ..) =>
      for field in fields {
        visit(field.value)
      }
    Variant(arguments~, ..) =>
      for argument in arguments {
        visit(argument)
      }
  }
}

///|
pub fn CheckedLocalItem::for_each_child_expr(
  self : CheckedLocalItem,
  visit : (CheckedExpr) -> Unit,
) -> Unit {
  match self {
    Let(declaration) => visit(declaration.initializer)
    PatternLet(declaration) => visit(declaration.initializer)
    Function(declaration) => visit(declaration.body)
    Expression(expression) => visit(expression)
  }
}
