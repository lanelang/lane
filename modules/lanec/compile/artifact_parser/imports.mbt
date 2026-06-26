///|
using @basic {type SourceSpan}

///|
fn make_document(
  version : String,
  kind : String,
  entries : Array[ArtifactEntry],
) -> ArtifactDocument {
  { version, kind, entries }
}

///|
fn[T] comma_push(items : Array[T], item : T) -> Array[T] {
  items.push(item)
  items
}

///|
fn extend_name(prefix : String, name : String) -> String {
  prefix + "." + name
}
