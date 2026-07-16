///|
fn @resolve.ResolvedSourceFile::unused_import_exposures(
  self : @resolve.ResolvedSourceFile,
  checked : @checked.CheckedSourceFile,
) -> Array[@resolve.ResolvedImportExposure] {
  let used_exposure_ids = []
  for use_ in self.import_uses {
    add_int_once(used_exposure_ids, use_.exposure_id)
  }
  let used_symbols = checked.import_used_symbols()
  for exposure_symbol in self.import_symbols {
    if used_symbols.contains(exposure_symbol.symbol) {
      add_int_once(used_exposure_ids, exposure_symbol.exposure_id)
    }
  }
  self.import_exposures.filter(fn(exposure) {
    match exposure.kind {
      ImportedModuleBinding => false
      _ => !used_exposure_ids.contains(exposure.id)
    }
  })
}

///|
fn @checked.CheckedSourceFile::import_used_symbols(
  self : @checked.CheckedSourceFile,
) -> Array[@resolve.ResolvedImportSymbol] {
  let symbols = []
  for declaration in self.declarations {
    collect_import_used_symbols_from_declaration(declaration, symbols)
  }
  symbols
}

///|
fn collect_import_used_symbols_from_declaration(
  declaration : @checked.CheckedTopLevelDeclaration,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  match declaration {
    Struct(declaration) =>
      for field in declaration.fields {
        collect_import_used_symbols_from_type(field.type_, symbols)
      }
    Enum(declaration) =>
      for variant in declaration.variants {
        for payload in variant.payload {
          collect_import_used_symbols_from_type(payload, symbols)
        }
      }
    Effect(declaration) =>
      for operation in declaration.operations {
        for payload in operation.payload {
          collect_import_used_symbols_from_type(payload, symbols)
        }
        collect_import_used_symbols_from_type(operation.result, symbols)
      }
    ExternalType(_) => ()
    Function(declaration) => {
      for parameter in declaration.parameters {
        collect_import_used_symbols_from_type(parameter.type_, symbols)
      }
      collect_import_used_symbols_from_type(declaration.return_type, symbols)
      collect_import_used_symbols_from_type(declaration.type_, symbols)
      collect_import_used_symbols_from_expr(declaration.body, symbols)
    }
    Let(declaration) => {
      collect_import_used_symbols_from_type(declaration.type_, symbols)
      collect_import_used_symbols_from_expr(declaration.initializer, symbols)
    }
  }
}

///|
fn collect_import_used_symbols_from_local_item(
  item : @checked.CheckedLocalItem,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  match item {
    Let(declaration) => {
      collect_import_used_symbols_from_type(declaration.type_, symbols)
      collect_import_used_symbols_from_expr(declaration.initializer, symbols)
    }
    PatternLet(declaration) => {
      collect_import_used_symbols_from_pattern(declaration.pattern, symbols)
      collect_import_used_symbols_from_expr(declaration.initializer, symbols)
    }
    Function(declaration) =>
      collect_import_used_symbols_from_declaration(
        Function(declaration),
        symbols,
      )
  }
}

///|
fn collect_import_used_symbols_from_expr(
  expr : @checked.CheckedExpr,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  collect_import_used_symbols_from_type(expr.type_(), symbols)
  match expr {
    FunctionLiteral(parameters~, return_type~, type_~, ..) => {
      for parameter in parameters {
        collect_import_used_symbols_from_type(parameter.type_, symbols)
      }
      collect_import_used_symbols_from_type(return_type, symbols)
      collect_import_used_symbols_from_type(type_, symbols)
    }
    GenericApplication(arguments~, ..) =>
      for argument in arguments {
        collect_import_used_symbols_from_generic_argument(argument, symbols)
      }
    Block(items~, ..) =>
      for item in items {
        collect_import_used_symbols_from_local_item(item, symbols)
      }
    Match(arms~, ..) =>
      for arm in arms {
        collect_import_used_symbols_from_pattern(arm.pattern, symbols)
      }
    OperationCall(generic_witnesses~, effect~, ..) => {
      for witness in generic_witnesses {
        collect_import_used_symbols_from_generic_argument(witness, symbols)
      }
      collect_import_used_symbols_from_effect(effect, symbols)
    }
    Handler(handlers~, ..) =>
      for handler in handlers {
        collect_import_used_symbols_from_effect(handler.handled_effect, symbols)
        for operation in handler.operations {
          for payload_type in operation.payload_types {
            collect_import_used_symbols_from_type(payload_type, symbols)
          }
          collect_import_used_symbols_from_type(operation.resume_type, symbols)
          for payload_pattern in operation.payload_patterns {
            collect_import_used_symbols_from_pattern(payload_pattern, symbols)
          }
        }
      }
    StructLiteral(symbol~, generic_arguments~, type_witnesses~, ..) => {
      add_import_symbol_once(symbols, TypeSymbol(symbol))
      for argument in generic_arguments {
        collect_import_used_symbols_from_generic_argument(argument, symbols)
      }
      for witness in type_witnesses {
        collect_import_used_symbols_from_type(witness.type_, symbols)
      }
    }
    Variant(generic_arguments~, ..) =>
      for argument in generic_arguments {
        collect_import_used_symbols_from_generic_argument(argument, symbols)
      }
    Literal(_)
    | Value(_)
    | CompilerIntrinsic(_)
    | ExternBinding(_)
    | If(_)
    | Call(_)
    | Field(_) => ()
  }
  expr.for_each_child_expr(fn(child) {
    collect_import_used_symbols_from_expr(child, symbols)
  })
}

///|
fn collect_import_used_symbols_from_pattern(
  pattern : @checked.CheckedPattern,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  collect_import_used_symbols_from_type(pattern.type_(), symbols)
  match pattern {
    Variant(generic_arguments~, arguments~, ..) => {
      for argument in generic_arguments {
        collect_import_used_symbols_from_generic_argument(argument, symbols)
      }
      for argument in arguments {
        collect_import_used_symbols_from_pattern(argument, symbols)
      }
    }
    Struct(symbol~, fields~, ..) => {
      add_import_symbol_once(symbols, TypeSymbol(symbol))
      for field in fields {
        collect_import_used_symbols_from_pattern(field.pattern, symbols)
      }
    }
    Wildcard(_) | Binding(_) | Literal(_) => ()
  }
}

///|
fn collect_import_used_symbols_from_type(
  type_ : @types.Type,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  match type_ {
    Constructor(symbol) => add_import_symbol_once(symbols, TypeSymbol(symbol))
    Apply(callee, arguments) => {
      collect_import_used_symbols_from_type(callee, symbols)
      for argument in arguments {
        collect_import_used_symbols_from_generic_argument(argument, symbols)
      }
    }
    TypeLambda(_, body) | Forall(_, body) =>
      collect_import_used_symbols_from_type(body, symbols)
    Function(parameters, result, effect) => {
      for parameter in parameters {
        collect_import_used_symbols_from_type(parameter, symbols)
      }
      collect_import_used_symbols_from_type(result, symbols)
      collect_import_used_symbols_from_effect(effect, symbols)
    }
    Error | Primitive(_) | Parameter(_) => ()
  }
}

///|
fn collect_import_used_symbols_from_effect(
  effect : @types.Effect,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  match effect {
    Singleton(symbol, arguments) => {
      add_import_symbol_once(symbols, EffectSymbol(symbol))
      for argument in arguments {
        collect_import_used_symbols_from_generic_argument(argument, symbols)
      }
    }
    Union(effects) =>
      for effect in effects {
        collect_import_used_symbols_from_effect(effect, symbols)
      }
    Empty | Io | Parameter(_) => ()
  }
}

///|
fn collect_import_used_symbols_from_generic_argument(
  argument : @types.GenericArgument,
  symbols : Array[@resolve.ResolvedImportSymbol],
) -> Unit {
  match argument {
    TypeArgument(type_) => collect_import_used_symbols_from_type(type_, symbols)
    EffectArgument(effect) =>
      collect_import_used_symbols_from_effect(effect, symbols)
  }
}

///|
fn add_import_symbol_once(
  symbols : Array[@resolve.ResolvedImportSymbol],
  symbol : @resolve.ResolvedImportSymbol,
) -> Unit {
  if !symbols.contains(symbol) {
    symbols.push(symbol)
  }
}

///|
fn add_int_once(values : Array[Int], value : Int) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}
