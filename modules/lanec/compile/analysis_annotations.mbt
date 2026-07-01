///|
fn annotated_value_symbols(
  source : @resolve.ResolvedSourceFile,
) -> Array[@symbol.ValueSymbolId] {
  let symbols = []
  for declaration in source.declarations {
    collect_annotated_top_level_values(declaration, symbols)
  }
  symbols
}

///|
fn collect_annotated_top_level_values(
  declaration : @resolve.ResolvedTopLevelDeclaration,
  symbols : Array[@symbol.ValueSymbolId],
) -> Unit {
  match declaration {
    Function(declaration) => {
      for parameter in declaration.parameters {
        symbols.push(parameter.symbol)
      }
      collect_annotated_expr_values(declaration.body, symbols)
    }
    Let(declaration) => {
      if declaration.type_annotation is Some(_) {
        symbols.push(declaration.symbol)
      }
      collect_annotated_expr_values(declaration.initializer, symbols)
    }
    Offer(declaration) => {
      symbols.push(declaration.symbol)
      collect_annotated_expr_values(declaration.initializer, symbols)
    }
    Struct(_) | Enum(_) | Effect(_) | TypeAlias(_) => ()
  }
}

///|
fn collect_annotated_local_values(
  item : @resolve.ResolvedLocalItem,
  symbols : Array[@symbol.ValueSymbolId],
) -> Unit {
  match item {
    Let(declaration) => {
      if declaration.type_annotation is Some(_) {
        symbols.push(declaration.symbol)
      }
      collect_annotated_expr_values(declaration.initializer, symbols)
    }
    PatternLet(declaration) =>
      collect_annotated_expr_values(declaration.initializer, symbols)
    Function(declaration) => {
      for parameter in declaration.parameters {
        symbols.push(parameter.symbol)
      }
      collect_annotated_expr_values(declaration.body, symbols)
    }
    Offer(declaration) => {
      symbols.push(declaration.symbol)
      collect_annotated_expr_values(declaration.initializer, symbols)
    }
  }
}

///|
fn collect_annotated_expr_values(
  expr : @resolve.ResolvedExpr,
  symbols : Array[@symbol.ValueSymbolId],
) -> Unit {
  match expr {
    IntLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Var(_)
    | Builtin(_) => ()
    QualifiedVariant(arguments~, ..) | UnqualifiedVariant(arguments~, ..) =>
      for argument in arguments {
        collect_annotated_expr_values(argument, symbols)
      }
    StructLiteral(fields~, ..) =>
      for field in fields {
        match field {
          Value(value~, ..) =>
            match value {
              Some(value) => collect_annotated_expr_values(value, symbols)
              None => ()
            }
          TypeWitness(_) => ()
        }
      }
    FunctionLiteral(parameters~, body~, ..) => {
      for parameter in parameters {
        if parameter.type_annotation is Some(_) {
          symbols.push(parameter.symbol)
        }
      }
      collect_annotated_expr_values(body, symbols)
    }
    Block(items~, result~, ..) => {
      for item in items {
        collect_annotated_local_values(item, symbols)
      }
      collect_annotated_expr_values(result, symbols)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      collect_annotated_expr_values(condition, symbols)
      collect_annotated_expr_values(then_branch, symbols)
      collect_annotated_expr_values(else_branch, symbols)
    }
    Match(scrutinee~, arms~, ..) => {
      collect_annotated_expr_values(scrutinee, symbols)
      for arm in arms {
        collect_annotated_expr_values(arm.body, symbols)
      }
    }
    Call(callee~, arguments~, ..) => {
      collect_annotated_expr_values(callee, symbols)
      for argument in arguments {
        match argument {
          Positional(argument) =>
            collect_annotated_expr_values(argument, symbols)
          Named(value~, ..) => collect_annotated_expr_values(value, symbols)
        }
      }
    }
    Field(base~, ..) => collect_annotated_expr_values(base, symbols)
    Unary(operand~, ..) => collect_annotated_expr_values(operand, symbols)
    Binary(left~, right~, ..) | Pipeline(left~, right~, ..) => {
      collect_annotated_expr_values(left, symbols)
      collect_annotated_expr_values(right, symbols)
    }
  }
}
