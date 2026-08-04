///|
/// A top-level value whose initializer cannot run before another one.
pub(all) struct CheckedInitializationCycleMember {
  symbol : ValueSymbolId
  name : String
  name_loc : SourceSpan
} derive(Debug, Eq)

///|
/// The order a module's top-level `let` initializers must run in, or the cycle
/// that makes no order possible.
priv enum CheckedInitializationOrder {
  Ordered(Array[ValueSymbolId])
  Cycle(Array[CheckedInitializationCycleMember])
}

///|
priv struct CheckedInitializationGraph {
  // Every top-level value and function of the module, in declaration order.
  nodes : Array[ValueSymbolId]
  // The top-level symbols each node's body or initializer references, whether
  // or not the reference is evaluated on every run.
  references : Array[Array[ValueSymbolId]]
  // The subset of nodes that are `let` values, which are the ones that carry
  // an initializer and therefore need an order.
  initialized : Array[ValueSymbolId]
}

///|
/// Returns the order a module's top-level `let` initializers must run in.
///
/// A value depends on the top-level names its initializer references, and
/// transitively on the names those referenced functions reference: calling a
/// function is how an initializer reaches a binding it never names. The edge
/// is lexical, so a function value handed to another function counts as
/// potentially called — sound, and it never asks what a value is.
///
/// Mutual recursion between functions is ordinary and stays legal; it is a
/// cycle between *initialized* values that no order can satisfy.
fn CheckedSourceFile::initialization_order(
  self : CheckedSourceFile,
) -> CheckedInitializationOrder {
  let graph = self.initialization_graph()
  let ordered : Array[ValueSymbolId] = []
  let visiting : Array[ValueSymbolId] = []
  let visited : Array[ValueSymbolId] = []
  for symbol in graph.initialized {
    let cycle = graph.visit(symbol, visiting, visited, ordered)
    if cycle is Some(cycle) {
      return Cycle(self.cycle_members(cycle))
    }
  }
  Ordered(ordered)
}

///|
/// Emits every initialized value reachable from `symbol` before `symbol`
/// itself, reporting the first cycle between initialized values instead.
fn CheckedInitializationGraph::visit(
  self : CheckedInitializationGraph,
  symbol : ValueSymbolId,
  visiting : Array[ValueSymbolId],
  visited : Array[ValueSymbolId],
  ordered : Array[ValueSymbolId],
) -> Array[ValueSymbolId]? {
  if visited.contains(symbol) {
    return None
  }
  if visiting.contains(symbol) {
    // Only initialized values need an order, so a loop that passes through
    // functions alone is mutual recursion rather than an unsatisfiable
    // constraint.
    let entered = visiting.search(symbol).unwrap()
    let members = visiting[entered:]
      .iter()
      .filter(node => self.initialized.contains(node))
      .collect()
    return if members.is_empty() { None } else { Some(members) }
  }
  guard self.nodes.search(symbol) is Some(index) else { return None }
  visiting.push(symbol)
  for reference in self.references[index] {
    let cycle = self.visit(reference, visiting, visited, ordered)
    if cycle is Some(cycle) {
      return Some(cycle)
    }
  }
  ignore(visiting.pop())
  visited.push(symbol)
  if self.initialized.contains(symbol) {
    ordered.push(symbol)
  }
  None
}

///|
fn CheckedSourceFile::initialization_graph(
  self : CheckedSourceFile,
) -> CheckedInitializationGraph {
  let nodes : Array[ValueSymbolId] = []
  let initialized : Array[ValueSymbolId] = []
  for declaration in self.declarations {
    match declaration {
      Function(declaration) => nodes.push(declaration.symbol)
      Let(declaration) => {
        nodes.push(declaration.symbol)
        initialized.push(declaration.symbol)
      }
      Struct(_) | Enum(_) | Effect(_) | ExternalType(_) => ()
    }
  }
  let references = []
  for declaration in self.declarations {
    match declaration {
      Function(declaration) =>
        references.push(referenced_nodes(declaration.body, nodes))
      Let(declaration) =>
        references.push(referenced_nodes(declaration.initializer, nodes))
      Struct(_) | Enum(_) | Effect(_) | ExternalType(_) => ()
    }
  }
  { nodes, references, initialized }
}

///|
fn referenced_nodes(
  expression : CheckedExpr,
  nodes : Array[ValueSymbolId],
) -> Array[ValueSymbolId] {
  let referenced : Array[ValueSymbolId] = []
  collect_referenced_nodes(expression, nodes, referenced)
  referenced
}

///|
fn collect_referenced_nodes(
  expression : CheckedExpr,
  nodes : Array[ValueSymbolId],
  referenced : Array[ValueSymbolId],
) -> Unit {
  if expression is Value(symbol~, ..) &&
    nodes.contains(symbol) &&
    !referenced.contains(symbol) {
    referenced.push(symbol)
  }
  expression.for_each_child_expr(child => {
    collect_referenced_nodes(child, nodes, referenced)
  })
}

///|
fn CheckedSourceFile::cycle_members(
  self : CheckedSourceFile,
  cycle : Array[ValueSymbolId],
) -> Array[CheckedInitializationCycleMember] {
  let members = []
  for declaration in self.declarations {
    if declaration is Let(declaration) && cycle.contains(declaration.symbol) {
      members.push({
        symbol: declaration.symbol,
        name: declaration.name,
        name_loc: declaration.name_loc,
      })
    }
  }
  members
}

///|
/// Returns the module with its top-level `let` declarations in initialization
/// order, so every later stage carries the order by preserving list order
/// rather than consulting a separate table.
///
/// Returns the cycle unchanged when no order exists; the caller reports it.
pub fn CheckedSourceFile::in_initialization_order(
  self : CheckedSourceFile,
) -> Result[CheckedSourceFile, Array[CheckedInitializationCycleMember]] {
  let order = match self.initialization_order() {
    Cycle(members) => return Err(members)
    Ordered(order) => order
  }
  let lets = []
  for symbol in order {
    for declaration in self.declarations {
      if declaration is Let(let_declaration) && let_declaration.symbol == symbol {
        lets.push(declaration)
      }
    }
  }
  let declarations = []
  let mut next_let = 0
  for declaration in self.declarations {
    if declaration is Let(_) {
      declarations.push(lets[next_let])
      next_let += 1
    } else {
      declarations.push(declaration)
    }
  }
  Ok({ ..self, declarations, })
}
