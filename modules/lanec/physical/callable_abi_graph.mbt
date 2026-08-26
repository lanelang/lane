///|
/// A nominal identity for one recursively nested physical callable ABI.
pub(all) struct CallableAbiNodeId {
  value : Int
} derive(Debug, Eq, Compare)

///|
/// The physical ABI of a value position inside a callable ABI node.
pub(all) enum CallableValueAbi {
  Unit
  Value(ValueAbi)
  Callable(CallableAbiNodeId)
} derive(Debug, Eq)

///|
/// One node in the finite graph of recursively nested callable ABIs.
pub(all) struct CallableAbiNode {
  witnesses : Array[ValueAbi]
  parameters : Array[CallableValueAbi]
  result : CallableValueAbi
} derive(Debug, Eq)

///|
/// Owns physical callable ABI identity while a program is being elaborated.
/// Nodes are interned by complete physical structure; semantic binder identity
/// and specialization demand never enter this graph.
pub(all) struct CallableAbiGraph {
  priv nodes : Array[CallableAbiNode]
}

///|
pub fn CallableAbiGraph::new() -> CallableAbiGraph {
  { nodes: [], }
}

///|
pub fn CallableAbiGraph::intern(
  self : CallableAbiGraph,
  node : CallableAbiNode,
) -> CallableAbiNodeId {
  for index, existing in self.nodes {
    if existing == node {
      return { value: index, }
    }
  }
  let id : CallableAbiNodeId = { value: self.nodes.length(), }
  self.nodes.push(node)
  id
}
