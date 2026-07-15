///|
pub fn ResolvedExpr::loc(self : ResolvedExpr) -> SourceSpan {
  match self {
    IntLiteral(_, loc~)
    | DoubleLiteral(_, loc~)
    | StringLiteral(_, loc~)
    | BoolLiteral(_, loc~)
    | UnitLiteral(loc~)
    | Var(loc~, ..)
    | QualifiedVariant(loc~, ..)
    | UnqualifiedVariant(loc~, ..)
    | StructLiteral(loc~, ..)
    | ListLiteral(loc~, ..)
    | Builtin(_, loc~)
    | Extern(_, loc~)
    | FunctionLiteral(loc~, ..)
    | EffectOperationCall(loc~, ..)
    | GenericApplication(loc~, ..)
    | Handler(loc~, ..)
    | Block(loc~, ..)
    | If(loc~, ..)
    | Match(loc~, ..)
    | Call(loc~, ..)
    | Field(loc~, ..)
    | Unary(loc~, ..)
    | Binary(loc~, ..)
    | Pipeline(loc~, ..) => loc
  }
}

///|
pub fn ResolvedExpr::for_each_child_expr(
  self : ResolvedExpr,
  visit : (ResolvedExpr) -> Unit,
) -> Unit {
  match self {
    IntLiteral(_)
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Var(_)
    | Builtin(_)
    | Extern(_) => ()
    QualifiedVariant(arguments~, ..) | UnqualifiedVariant(arguments~, ..) =>
      for argument in arguments {
        visit(argument)
      }
    ListLiteral(items~, ..) =>
      for item in items {
        visit(item)
      }
    StructLiteral(fields~, ..) =>
      for field in fields {
        if field is Value(value=Some(value), ..) {
          visit(value)
        }
      }
    FunctionLiteral(body~, ..) => visit(body)
    EffectOperationCall(arguments~, ..) =>
      for argument in arguments {
        visit(argument)
      }
    GenericApplication(callee~, ..) => visit(callee)
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
        argument.for_each_child_expr(visit)
      }
    }
    Field(base~, ..) => visit(base)
    Unary(operand~, ..) => visit(operand)
    Binary(left~, right~, ..) | Pipeline(left~, right~, ..) => {
      visit(left)
      visit(right)
    }
  }
}

///|
pub fn ResolvedLocalItem::for_each_child_expr(
  self : ResolvedLocalItem,
  visit : (ResolvedExpr) -> Unit,
) -> Unit {
  match self {
    Let(declaration) => visit(declaration.initializer)
    PatternLet(declaration) => visit(declaration.initializer)
    Function(declaration) => visit(declaration.body)
    Offer(declaration) => visit(declaration.initializer)
  }
}

///|
pub fn ResolvedCallArgument::for_each_child_expr(
  self : ResolvedCallArgument,
  visit : (ResolvedExpr) -> Unit,
) -> Unit {
  match self {
    Positional(value~, ..) | Named(value~, ..) => visit(value)
  }
}
