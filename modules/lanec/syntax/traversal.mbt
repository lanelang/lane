///|
fn Expr::for_each_child_expr(self : Expr, visit : (Expr) -> Unit) -> Unit {
  match self {
    IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Var(_)
    | Builtin(_)
    | Extern(_) => ()
    QualifiedVariant(arguments~, ..)
    | ListLiteral(items=arguments, ..)
    | TupleLiteral(items=arguments, ..) =>
      for argument in arguments {
        visit(argument)
      }
    StructLiteral(fields~, ..) =>
      for field in fields {
        if field is Value(value=Some(value), ..) {
          visit(value)
        }
      }
    Derive(arguments~, ..) =>
      for argument in arguments {
        argument.for_each_child_expr(visit)
      }
    FunctionLiteral(body~, ..) => visit(body)
    EffectOperationCall(arguments~, ..) =>
      for argument in arguments {
        visit(argument)
      }
    TypeApplication(callee~, ..) => visit(callee)
    Handler(body~, handlers~, final_branch~, ..) => {
      visit(body)
      for handler in handlers {
        for arm in handler.arms {
          visit(arm.body)
        }
      }
      visit(final_branch.body)
    }
    Block(items~, result~, ..) => {
      for item in items {
        item.for_each_child_expr(visit)
      }
      visit(result)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      visit(condition)
      visit(then_branch)
      if else_branch is Some(branch) {
        visit(branch)
      }
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
        argument.for_each_child_expr(visit)
      }
    }
    Field(base~, ..) => visit(base)
    Unary(operand~, ..) | Grouped(expression=operand, ..) => visit(operand)
    Binary(left~, right~, ..) | Pipeline(left~, right~, ..) => {
      visit(left)
      visit(right)
    }
  }
}

///|
fn LocalItem::for_each_child_expr(
  self : LocalItem,
  visit : (Expr) -> Unit,
) -> Unit {
  match self {
    Let(declaration) => visit(declaration.initializer)
    PatternLet(declaration) => visit(declaration.initializer)
    Function(declaration) => visit(declaration.body)
    Expression(expression~) => visit(expression)
  }
}

///|
fn CallArgument::for_each_child_expr(
  self : CallArgument,
  visit : (Expr) -> Unit,
) -> Unit {
  match self {
    Positional(value~, ..) | Named(value~, ..) => visit(value)
  }
}

///|
/// Returns the first authored `derive` expression location, including
/// expressions nested inside declarations.
pub fn SourceFile::first_derive_loc(self : SourceFile) -> SourceSpan? {
  let found : Ref[SourceSpan?] = { val: None }
  fn visit(expression : Expr, found : Ref[SourceSpan?]) -> Unit {
    if found.val is Some(_) {
      return
    }
    if expression is Derive(source~, ..) {
      found.val = Some(source.loc)
      return
    }
    expression.for_each_child_expr(fn(child) { visit(child, found) })
  }
  for declaration in self.declarations {
    if found.val is Some(_) {
      break
    }
    match declaration {
      Function(declaration) => visit(declaration.body, found)
      Let(declaration) => visit(declaration.initializer, found)
      Struct(_) | Enum(_) | Effect(_) | ExternalType(_) | TypeAlias(_) => ()
    }
  }
  found.val
}
