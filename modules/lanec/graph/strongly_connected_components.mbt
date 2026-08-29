///|
pub(all) struct StronglyConnectedComponent {
  members : Array[Int]
  recursive : Bool
} derive(Debug, Eq)

///|
/// Returns deterministic strongly-connected components in caller-before-callee
/// order for the supplied adjacency lists.
pub fn strongly_connected_components(
  adjacency : Array[Array[Int]],
) -> Array[StronglyConnectedComponent] {
  let reverse : Array[Array[Int]] = Array::makei(adjacency.length(), _ => [])
  for caller, callees in adjacency {
    for callee in callees {
      reverse[callee].push(caller)
    }
  }
  let visited = Array::make(adjacency.length(), false)
  let order : Array[Int] = []
  for index in 0..<adjacency.length() {
    finish_node(index, adjacency, visited, order)
  }
  let assigned = Array::make(adjacency.length(), false)
  let components = []
  for index in order.rev_iter() {
    if assigned[index] {
      continue
    }
    let members = []
    collect_component(index, reverse, assigned, members)
    components.push({
      members,
      recursive: members.length() > 1 || adjacency[index].contains(index),
    })
  }
  components
}

///|
fn finish_node(
  index : Int,
  adjacency : Array[Array[Int]],
  visited : Array[Bool],
  order : Array[Int],
) -> Unit {
  if visited[index] {
    return
  }
  visited[index] = true
  for successor in adjacency[index] {
    finish_node(successor, adjacency, visited, order)
  }
  order.push(index)
}

///|
fn collect_component(
  index : Int,
  reverse : Array[Array[Int]],
  assigned : Array[Bool],
  members : Array[Int],
) -> Unit {
  if assigned[index] {
    return
  }
  assigned[index] = true
  members.push(index)
  for predecessor in reverse[index] {
    collect_component(predecessor, reverse, assigned, members)
  }
}
