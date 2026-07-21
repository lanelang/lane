///|
priv enum SnapshotTree[T] {
  Empty
  Leaf(T)
  Branch(length~ : Int, left~ : SnapshotTree[T], right~ : SnapshotTree[T])
}

///|
fn[T] SnapshotTree::from_array(items : Array[T]) -> SnapshotTree[T] {
  SnapshotTree::from_array_range(items, 0, items.length())
}

///|
fn[T] SnapshotTree::from_array_range(
  items : Array[T],
  start : Int,
  end : Int,
) -> SnapshotTree[T] {
  let length = end - start
  if length <= 0 {
    Empty
  } else if length == 1 {
    Leaf(items[start])
  } else {
    let middle = start + length / 2
    Branch(
      length~,
      left=SnapshotTree::from_array_range(items, start, middle),
      right=SnapshotTree::from_array_range(items, middle, end),
    )
  }
}

///|
fn[T] SnapshotTree::length(self : SnapshotTree[T]) -> Int {
  match self {
    Empty => 0
    Leaf(_) => 1
    Branch(length~, ..) => length
  }
}

///|
fn[T] SnapshotTree::get(self : SnapshotTree[T], index : Int) -> T? {
  match self {
    Empty => None
    Leaf(value) => if index == 0 { Some(value) } else { None }
    Branch(left~, right~, ..) => {
      let left_length = left.length()
      if index < 0 {
        None
      } else if index < left_length {
        left.get(index)
      } else {
        right.get(index - left_length)
      }
    }
  }
}

///|
fn[T] SnapshotTree::set(
  self : SnapshotTree[T],
  index : Int,
  value : T,
) -> SnapshotTree[T] {
  match self {
    Empty => abort("snapshot tree index is out of range")
    Leaf(_) =>
      if index == 0 {
        Leaf(value)
      } else {
        abort("snapshot tree index is out of range")
      }
    Branch(length~, left~, right~) => {
      let left_length = left.length()
      if index < 0 || index >= length {
        abort("snapshot tree index is out of range")
      } else if index < left_length {
        Branch(length~, left=left.set(index, value), right~)
      } else {
        Branch(length~, left~, right=right.set(index - left_length, value))
      }
    }
  }
}

///|
fn[T] SnapshotTree::each(self : SnapshotTree[T], visit : (T) -> Unit) -> Unit {
  match self {
    Empty => ()
    Leaf(value) => visit(value)
    Branch(left~, right~, ..) => {
      left.each(visit)
      right.each(visit)
    }
  }
}
