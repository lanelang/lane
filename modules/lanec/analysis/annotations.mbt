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
    Struct(_) | Enum(_) | Effect(_) | ExternalType(_) | TypeAlias(_) => ()
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
    | DoubleLiteral(_)
    | StringLiteral(_)
    | BoolLiteral(_)
    | UnitLiteral(_)
    | Var(_)
    | Builtin(_) => ()
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
    _ =>
      expr.for_each_child_expr(fn(child) {
        collect_annotated_expr_values(child, symbols)
      })
  }
}
