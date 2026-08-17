///|
priv struct SourceScaleAccumulator {
  mut functions : Int
  mut nodes : Int
  mut calls : Int
  mut generic_binders : Int
  mut type_applications : Int
}

///|
fn source_scale_accumulator(declarations : Int) -> SourceScaleAccumulator {
  {
    functions: 0,
    nodes: declarations,
    calls: 0,
    generic_binders: 0,
    type_applications: 0,
  }
}

///|
fn syntax_stage_scale(
  source : @syntax.SourceFile,
  imports : Int,
) -> SourceStageScale {
  let accumulator = source_scale_accumulator(source.declarations.length())
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      Enum(declaration) => {
        accumulator.generic_binders += declaration.type_parameters.length()
        for variant in declaration.variants {
          accumulator.generic_binders += variant.type_parameters.length()
        }
      }
      Effect(declaration) => {
        accumulator.generic_binders += declaration.type_parameters.length()
        for operation in declaration.operations {
          accumulator.generic_binders += operation.type_parameters.length()
        }
      }
      ExternalType(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      TypeAlias(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      Function(declaration) => {
        accumulator.functions += 1
        accumulator.generic_binders += declaration.type_parameters.length()
        observe_syntax_expr(declaration.body, accumulator)
      }
      Let(declaration) =>
        observe_syntax_expr(declaration.initializer, accumulator)
    }
  }
  finish_source_stage_scale(source.declarations.length(), imports, accumulator)
}

///|
fn observe_syntax_expr(
  expression : @syntax.Expr,
  accumulator : SourceScaleAccumulator,
) -> Unit {
  accumulator.nodes += 1
  match expression {
    FunctionLiteral(type_parameters~, ..) => {
      accumulator.functions += 1
      accumulator.generic_binders += type_parameters.length()
    }
    Call(_) | EffectOperationCall(_) => accumulator.calls += 1
    TypeApplication(_) => accumulator.type_applications += 1
    Block(items~, ..) =>
      for item in items {
        if item is Function(declaration) {
          accumulator.functions += 1
          accumulator.generic_binders += declaration.type_parameters.length()
        }
      }
    _ => ()
  }
  expression.for_each_child_expr(fn(child) {
    observe_syntax_expr(child, accumulator)
  })
}

///|
fn resolved_stage_scale(
  source : @resolve.ResolvedSourceFile,
  imports : Int,
) -> SourceStageScale {
  let accumulator = source_scale_accumulator(source.declarations.length())
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      Enum(declaration) => {
        accumulator.generic_binders += declaration.type_parameters.length()
        for variant in declaration.variants {
          accumulator.generic_binders += variant.type_parameters.length()
        }
      }
      Effect(declaration) => {
        accumulator.generic_binders += declaration.type_parameters.length()
        for operation in declaration.operations {
          accumulator.generic_binders += operation.type_parameters.length()
        }
      }
      ExternalType(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      TypeAlias(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      Function(declaration) => {
        accumulator.functions += 1
        accumulator.generic_binders += declaration.type_parameters.length()
        observe_resolved_expr(declaration.body, accumulator)
      }
      Let(declaration) =>
        observe_resolved_expr(declaration.initializer, accumulator)
    }
  }
  finish_source_stage_scale(source.declarations.length(), imports, accumulator)
}

///|
fn observe_resolved_expr(
  expression : @resolve.ResolvedExpr,
  accumulator : SourceScaleAccumulator,
) -> Unit {
  accumulator.nodes += 1
  match expression {
    FunctionLiteral(type_parameters~, ..) => {
      accumulator.functions += 1
      accumulator.generic_binders += type_parameters.length()
    }
    Call(_) | EffectOperationCall(_) => accumulator.calls += 1
    GenericApplication(_) => accumulator.type_applications += 1
    Block(items~, ..) =>
      for item in items {
        if item is Function(declaration) {
          accumulator.functions += 1
          accumulator.generic_binders += declaration.type_parameters.length()
        }
      }
    _ => ()
  }
  expression.for_each_child_expr(fn(child) {
    observe_resolved_expr(child, accumulator)
  })
}

///|
fn checked_stage_scale(
  source : @checked.CheckedSourceFile,
  imports : Int,
) -> SourceStageScale {
  let accumulator = source_scale_accumulator(source.declarations.length())
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) =>
        accumulator.generic_binders += declaration.type_parameters.length()
      Enum(declaration) => {
        accumulator.generic_binders += declaration.type_parameters.length()
        for variant in declaration.variants {
          accumulator.generic_binders += variant.type_parameters.length()
        }
      }
      Effect(declaration) => {
        accumulator.generic_binders += declaration.type_parameters.length()
        for operation in declaration.operations {
          accumulator.generic_binders += operation.type_parameters.length()
        }
      }
      ExternalType(_) => ()
      Function(declaration) => {
        accumulator.functions += 1
        accumulator.generic_binders += declaration.type_parameters.length()
        observe_checked_expr(declaration.body, accumulator)
      }
      Let(declaration) =>
        observe_checked_expr(declaration.initializer, accumulator)
    }
  }
  finish_source_stage_scale(source.declarations.length(), imports, accumulator)
}

///|
fn observe_checked_expr(
  expression : @checked.CheckedExpr,
  accumulator : SourceScaleAccumulator,
) -> Unit {
  accumulator.nodes += 1
  match expression {
    FunctionLiteral(type_parameters~, ..) => {
      accumulator.functions += 1
      accumulator.generic_binders += type_parameters.length()
    }
    Call(_) | OperationCall(_) => accumulator.calls += 1
    GenericApplication(_) => accumulator.type_applications += 1
    Block(items~, ..) =>
      for item in items {
        if item is Function(declaration) {
          accumulator.functions += 1
          accumulator.generic_binders += declaration.type_parameters.length()
        }
      }
    _ => ()
  }
  expression.for_each_child_expr(fn(child) {
    observe_checked_expr(child, accumulator)
  })
}

///|
fn finish_source_stage_scale(
  declarations : Int,
  imports : Int,
  accumulator : SourceScaleAccumulator,
) -> SourceStageScale {
  {
    declarations,
    imports,
    functions: accumulator.functions,
    nodes: accumulator.nodes,
    calls: accumulator.calls,
    generic_binders: accumulator.generic_binders,
    type_applications: accumulator.type_applications,
  }
}
