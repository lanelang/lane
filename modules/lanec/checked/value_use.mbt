///|
pub(all) enum CheckedValueUseBinderKind {
  LocalLet
  LocalFunction
  FunctionParameter
  FunctionLiteralParameter
  PatternBinder
  HandlerResumeBinder
  HandlerFinalBinder
} derive(Debug, Eq)

///|
pub(all) struct CheckedValueUseBinder {
  symbol : ValueSymbolId
  name : String
  loc : SourceSpan
  kind : CheckedValueUseBinderKind
} derive(Debug, Eq)

///|
pub(all) struct CheckedValueUseReference {
  target : ValueSymbolId
  origin_binder : ValueSymbolId?
  loc : SourceSpan
} derive(Debug, Eq)

///|
pub(all) struct CheckedValueUseAnalysis {
  binders : Array[CheckedValueUseBinder]
  references : Array[CheckedValueUseReference]
} derive(Debug, Eq)

///|
priv struct CheckedValueUseCollector {
  binders : Array[CheckedValueUseBinder]
  references : Array[CheckedValueUseReference]
}

///|
pub fn CheckedSourceFile::value_use_analysis(
  self : CheckedSourceFile,
) -> CheckedValueUseAnalysis {
  let collector = CheckedValueUseCollector::{ binders: [], references: [] }
  for declaration in self.declarations {
    collector.collect_top_level_declaration(declaration)
  }
  { binders: collector.binders, references: collector.references }
}

///|
pub fn CheckedValueUseAnalysis::unused_binders(
  self : CheckedValueUseAnalysis,
) -> Array[CheckedValueUseBinder] {
  let component_ids = self.component_ids()
  let used_components = self.used_components(component_ids)
  let unused = []
  for index, binder in self.binders {
    if !used_components[component_ids[index]] {
      unused.push(binder)
    }
  }
  unused.sort_by(fn(left, right) {
    let by_start = left.loc.start_offset - right.loc.start_offset
    if by_start != 0 {
      by_start
    } else {
      left.loc.end_offset - right.loc.end_offset
    }
  })
  unused
}

///|
fn CheckedValueUseAnalysis::component_ids(
  self : CheckedValueUseAnalysis,
) -> Array[Int] {
  let component_ids = []
  for _ in self.binders {
    component_ids.push(-1)
  }
  let mut next_component = 0
  for index, binder in self.binders {
    if component_ids[index] != -1 {
      continue
    }
    component_ids[index] = next_component
    for other_index in (index + 1)..<self.binders.length() {
      if component_ids[other_index] == -1 &&
        self.reaches(binder.symbol, self.binders[other_index].symbol) &&
        self.reaches(self.binders[other_index].symbol, binder.symbol) {
        component_ids[other_index] = next_component
      }
    }
    next_component += 1
  }
  component_ids
}

///|
fn CheckedValueUseAnalysis::used_components(
  self : CheckedValueUseAnalysis,
  component_ids : Array[Int],
) -> Array[Bool] {
  let components = []
  for id in component_ids {
    if id >= components.length() {
      components.push(false)
    }
  }
  for reference in self.references {
    guard self.binder_index(reference.target) is Some(target_index) else {
      continue
    }
    let target_component = component_ids[target_index]
    match reference.origin_binder {
      Some(origin) =>
        match self.binder_index(origin) {
          Some(origin_index) =>
            if component_ids[origin_index] != target_component {
              components[target_component] = true
            }
          None => components[target_component] = true
        }
      None => components[target_component] = true
    }
  }
  components
}

///|
fn CheckedValueUseAnalysis::reaches(
  self : CheckedValueUseAnalysis,
  origin : ValueSymbolId,
  target : ValueSymbolId,
) -> Bool {
  self.reaches_from(origin, target, [])
}

///|
fn CheckedValueUseAnalysis::reaches_from(
  self : CheckedValueUseAnalysis,
  current : ValueSymbolId,
  target : ValueSymbolId,
  visited : Array[ValueSymbolId],
) -> Bool {
  if visited.contains(current) {
    return false
  }
  let visited = visited.copy()
  visited.push(current)
  for reference in self.references {
    if reference.origin_binder == Some(current) {
      if reference.target == target {
        return true
      }
      if self.binder_index(reference.target) is Some(_) &&
        self.reaches_from(reference.target, target, visited) {
        return true
      }
    }
  }
  false
}

///|
fn CheckedValueUseAnalysis::binder_index(
  self : CheckedValueUseAnalysis,
  symbol : ValueSymbolId,
) -> Int? {
  for index, binder in self.binders {
    if binder.symbol == symbol {
      return Some(index)
    }
  }
  None
}

///|
fn CheckedValueUseCollector::collect_top_level_declaration(
  self : CheckedValueUseCollector,
  declaration : CheckedTopLevelDeclaration,
) -> Unit {
  match declaration {
    Function(declaration) => {
      for parameter in declaration.parameters {
        self.add_binder(
          parameter.symbol,
          parameter.name,
          parameter.loc,
          FunctionParameter,
        )
      }
      self.collect_expr(declaration.body, None)
    }
    Let(declaration) => self.collect_expr(declaration.initializer, None)
    Struct(_) | Enum(_) | Effect(_) | ExternalType(_) => ()
  }
}

///|
fn CheckedValueUseCollector::collect_local_item(
  self : CheckedValueUseCollector,
  item : CheckedLocalItem,
  current_origin : ValueSymbolId?,
) -> Unit {
  match item {
    Let(declaration) =>
      match declaration.name {
        Some(name) => {
          self.add_binder(declaration.symbol, name, declaration.loc, LocalLet)
          self.collect_expr(declaration.initializer, Some(declaration.symbol))
        }
        None => self.collect_expr(declaration.initializer, current_origin)
      }
    PatternLet(declaration) => {
      self.collect_expr(declaration.initializer, current_origin)
      self.collect_pattern(declaration.pattern)
    }
    Function(declaration) => {
      self.add_binder(
        declaration.symbol,
        declaration.name,
        declaration.loc,
        LocalFunction,
      )
      for parameter in declaration.parameters {
        self.add_binder(
          parameter.symbol,
          parameter.name,
          parameter.loc,
          FunctionParameter,
        )
      }
      self.collect_expr(declaration.body, Some(declaration.symbol))
    }
  }
}

///|
fn CheckedValueUseCollector::collect_expr(
  self : CheckedValueUseCollector,
  expr : CheckedExpr,
  current_origin : ValueSymbolId?,
) -> Unit {
  match expr {
    Literal(_) | CompilerIntrinsic(_) | ExternBinding(_) => ()
    Value(symbol~, loc~, ..) =>
      self.references.push({
        target: symbol,
        origin_binder: current_origin,
        loc,
      })
    FunctionLiteral(parameters~, body~, ..) => {
      for parameter in parameters {
        self.add_binder(
          parameter.symbol,
          parameter.name,
          parameter.loc,
          FunctionLiteralParameter,
        )
      }
      self.collect_expr(body, current_origin)
    }
    GenericApplication(callee~, ..) => self.collect_expr(callee, current_origin)
    Block(items~, result~, ..) => {
      for item in items {
        self.collect_local_item(item, current_origin)
      }
      self.collect_expr(result, current_origin)
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      self.collect_expr(condition, current_origin)
      self.collect_expr(then_branch, current_origin)
      self.collect_expr(else_branch, current_origin)
    }
    Match(scrutinee~, arms~, ..) => {
      self.collect_expr(scrutinee, current_origin)
      for arm in arms {
        self.collect_pattern(arm.pattern)
        self.collect_expr(arm.body, current_origin)
      }
    }
    Call(callee~, arguments~, ..) => {
      self.collect_expr(callee, current_origin)
      for argument in arguments {
        self.collect_expr(argument.value, current_origin)
      }
    }
    OperationCall(arguments~, ..) =>
      for argument in arguments {
        self.collect_expr(argument, current_origin)
      }
    Handler(body~, handlers~, final_branch~, ..) => {
      if body is Some(body) {
        self.collect_expr(body, current_origin)
      }
      for handler in handlers {
        for arm in handler.operations {
          for pattern in arm.payload_patterns {
            self.collect_pattern(pattern)
          }
          self.add_binder(
            arm.resume_symbol,
            arm.resume_binder,
            arm.resume_loc,
            HandlerResumeBinder,
          )
          if arm.body is Some(body) {
            self.collect_expr(body, current_origin)
          }
        }
      }
      self.add_binder(
        final_branch.binder_symbol,
        final_branch.binder,
        final_branch.binder_loc,
        HandlerFinalBinder,
      )
      if final_branch.body is Some(body) {
        self.collect_expr(body, current_origin)
      }
    }
    Field(base~, ..) => self.collect_expr(base, current_origin)
    StructLiteral(fields~, ..) =>
      for field in fields {
        self.collect_expr(field.value, current_origin)
      }
    Variant(arguments~, ..) =>
      for argument in arguments {
        self.collect_expr(argument, current_origin)
      }
  }
}

///|
fn CheckedValueUseCollector::collect_pattern(
  self : CheckedValueUseCollector,
  pattern : CheckedPattern,
) -> Unit {
  match pattern {
    Wildcard(_) | Literal(_) => ()
    Binding(name~, symbol~, loc~, ..) =>
      self.add_binder(symbol, name, loc, PatternBinder)
    Variant(arguments~, ..) =>
      for argument in arguments {
        self.collect_pattern(argument)
      }
    Struct(fields~, ..) =>
      for field in fields {
        self.collect_pattern(field.pattern)
      }
  }
}

///|
fn CheckedValueUseCollector::add_binder(
  self : CheckedValueUseCollector,
  symbol : ValueSymbolId,
  name : String,
  loc : SourceSpan,
  kind : CheckedValueUseBinderKind,
) -> Unit {
  self.binders.push({ symbol, name, loc, kind })
}
